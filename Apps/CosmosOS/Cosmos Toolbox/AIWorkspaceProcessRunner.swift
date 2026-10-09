import Foundation
import Darwin

// MARK: - Command runner
//
// Runs exactly one absolute-path executable with fixed arguments. It never
// goes through a shell, closes stdin, uses a controlled environment, caps the
// captured output, and always ends: a timeout or a cancelled task terminates
// the child (SIGTERM, then SIGKILL after a grace period).

nonisolated enum AIWorkspaceCommandOutcome: Sendable, Equatable {
    case finished(exitCode: Int32, output: String)
    case launchFailed(String)
    case timedOut
    case cancelled
}


nonisolated protocol AIWorkspaceCommandRunning: Sendable {
    func run(executable: String, arguments: [String]) async -> AIWorkspaceCommandOutcome
}


nonisolated struct AIWorkspaceProcessRunner: AIWorkspaceCommandRunning {

    var homeDirectory: String
    var timeout: TimeInterval = 5
    var killGrace: TimeInterval = 1
    var outputLimit: Int = 64 * 1024

    func run(executable: String, arguments: [String]) async -> AIWorkspaceCommandOutcome {
        // Only the executable's own directory is added, so a script with an
        // `env` shebang can find its sibling interpreter. Nothing is inherited
        // from the App's environment (no tokens, no CLAUDE_* / ANTHROPIC_*).
        let directory = URL(fileURLWithPath: executable).deletingLastPathComponent().path
        let environment = [
            "PATH": "\(directory):/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": homeDirectory,
            "LANG": "en_US.UTF-8",
            "NO_COLOR": "1"
        ]
        let session = AIWorkspaceProcessSession(
            executable: executable,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            killGrace: killGrace,
            outputLimit: outputLimit
        )
        return await session.run()
    }
}


nonisolated final class AIWorkspaceProcessSession: @unchecked Sendable {

    private let executable: String
    private let arguments: [String]
    private let environment: [String: String]
    private let timeout: TimeInterval
    private let killGrace: TimeInterval
    private let outputLimit: Int

    private let lock = NSLock()
    private let process = Process()
    private let pipe = Pipe()
    private let readerGroup = DispatchGroup()

    private var continuation: CheckedContinuation<AIWorkspaceCommandOutcome, Never>?
    private var delivered = false
    private var cancelled = false
    private var timedOut = false
    private var launched = false
    private var exited = false
    private var terminating = false
    private var stopReading = false
    private var exitCode: Int32 = 0
    private var buffer = Data()

    init(
        executable: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval,
        killGrace: TimeInterval,
        outputLimit: Int
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.timeout = timeout
        self.killGrace = killGrace
        self.outputLimit = outputLimit
    }


    func run() async -> AIWorkspaceCommandOutcome {
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<AIWorkspaceCommandOutcome, Never>) in
                lock.lock()
                self.continuation = continuation
                lock.unlock()
                launch()
            }
        } onCancel: {
            requestCancel()
        }
    }


    // MARK: Launch

    private func launch() {
        // Launching happens under the lock so a concurrent cancel either sees
        // "not launched yet" (and this method then refuses to start) or sees a
        // fully launched process it can terminate.
        lock.lock()
        if cancelled || delivered {
            lock.unlock()
            deliver(.cancelled)
            return
        }

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = pipe
        process.terminationHandler = { [self] finished in
            processDidExit(status: finished.terminationStatus)
        }

        readerGroup.enter()
        do {
            try process.run()
            launched = true
        } catch {
            readerGroup.leave()
            lock.unlock()
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
            process.terminationHandler = nil
            deliver(.launchFailed(error.localizedDescription))
            return
        }
        lock.unlock()

        // The parent must drop its copy of the write end, or EOF never arrives.
        try? pipe.fileHandleForWriting.close()
        let descriptor = pipe.fileHandleForReading.fileDescriptor
        DispatchQueue.global(qos: .utility).async { [self] in
            readLoop(descriptor)
            readerGroup.leave()
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { [self] in
            timeoutFired()
        }
    }


    // MARK: Output

    private func readLoop(_ descriptor: Int32) {
        var chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            lock.lock()
            let stop = stopReading
            let processEnded = exited
            lock.unlock()
            if stop { return }

            var watched = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
            let ready = poll(&watched, 1, 50)
            if ready > 0 {
                let count = read(descriptor, &chunk, chunk.count)
                if count > 0 {
                    append(chunk, count: count)
                } else if count == 0 {
                    return
                } else if errno != EINTR && errno != EAGAIN {
                    return
                }
            } else if ready == 0 {
                // Process is gone and nothing is pending.
                if processEnded { return }
            } else if errno != EINTR {
                return
            }
        }
    }

    private func append(_ chunk: [UInt8], count: Int) {
        lock.lock()
        // Keep draining past the limit so the child never blocks on a full
        // pipe, but stop storing.
        let room = outputLimit - buffer.count
        if room > 0 {
            buffer.append(contentsOf: chunk.prefix(min(count, room)))
        }
        lock.unlock()
    }


    // MARK: Termination

    private func processDidExit(status: Int32) {
        lock.lock()
        exited = true
        exitCode = status
        lock.unlock()

        if readerGroup.wait(timeout: .now() + 1) == .timedOut {
            lock.lock()
            stopReading = true
            lock.unlock()
            _ = readerGroup.wait(timeout: .now() + 0.5)
        }
        try? pipe.fileHandleForReading.close()

        lock.lock()
        let wasCancelled = cancelled
        let didTimeOut = timedOut
        let code = exitCode
        let data = buffer
        lock.unlock()

        if wasCancelled {
            deliver(.cancelled)
        } else if didTimeOut {
            deliver(.timedOut)
        } else {
            deliver(.finished(exitCode: code, output: String(decoding: data, as: UTF8.self)))
        }
    }

    private func timeoutFired() {
        lock.lock()
        let alive = launched && !exited && !delivered
        if alive { timedOut = true }
        lock.unlock()
        if alive { terminateThenKill() }
    }

    private func requestCancel() {
        lock.lock()
        cancelled = true
        let alive = launched && !exited
        let notStarted = !launched && continuation != nil
        lock.unlock()

        if alive {
            terminateThenKill()
        } else if notStarted {
            // launch() has not run yet (or refused); it will see the flag.
            deliver(.cancelled)
        }
    }

    private func terminateThenKill() {
        lock.lock()
        let first = !terminating
        terminating = true
        let pid = process.processIdentifier
        lock.unlock()
        guard first else { return }

        process.terminate()

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + killGrace) { [self] in
            lock.lock()
            let stillAlive = !exited
            lock.unlock()
            if stillAlive { kill(pid, SIGKILL) }
        }
        // Last resort: never leave the caller waiting on an unkillable child.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + killGrace + 1) { [self] in
            lock.lock()
            let wasCancelled = cancelled
            lock.unlock()
            deliver(wasCancelled ? .cancelled : .timedOut)
        }
    }

    private func deliver(_ outcome: AIWorkspaceCommandOutcome) {
        lock.lock()
        if delivered {
            lock.unlock()
            return
        }
        delivered = true
        let pending = continuation
        continuation = nil
        lock.unlock()
        process.terminationHandler = nil
        pending?.resume(returning: outcome)
    }
}
