import Foundation
import Darwin

// MARK: - Whitelisted commands

/// 服务只能发出这些命令；没有任何路径可以构造 commit / push / merge / rebase / stash / reset / clean / checkout。
nonisolated enum KnowledgeGitCommand: Equatable, Sendable {
    case status, lastCommit, gitDirectory, fetch, pullFastForwardOnly

    /// 追加在全局选项之后的参数。
    var arguments: [String] {
        switch self {
        case .status: return ["status", "--porcelain=v2", "--branch", "--untracked-files=normal"]
        case .lastCommit: return ["log", "-1", "--format=%H%x1f%ct%x1f%s"]
        case .gitDirectory: return ["rev-parse", "--absolute-git-dir"]
        case .fetch: return ["fetch", "--no-recurse-submodules", "origin"]
        case .pullFastForwardOnly: return ["pull", "--ff-only", "--no-rebase", "--no-recurse-submodules"]
        }
    }
    /// 只有这两个命令会写仓库（用户点击触发）。
    var writesRepository: Bool { self == .fetch || self == .pullFastForwardOnly }

    /// 所有调用共用的全局选项：不取可选锁（status 不刷新索引）、关闭 fsmonitor（不执行仓库配置里的命令）。
    static let globalOptions = ["--no-optional-locks", "-c", "core.fsmonitor=false", "-c", "core.quotepath=false"]
}

nonisolated struct KnowledgeProcessResult: Equatable, Sendable {
    var exitCode: Int32
    var stdout: String
    var stderr: String
    var timedOut = false
    var cancelled = false
    var launchError: String? = nil
}

nonisolated protocol KnowledgeProcessRunning: Sendable {
    func run(executable: URL, arguments: [String], directory: URL, environment: [String: String], timeout: TimeInterval) async -> KnowledgeProcessResult
}

/// 以参数数组启动子进程（不经过 shell），限时、可取消、输出有上限。
nonisolated struct KnowledgeProcessRunner: KnowledgeProcessRunning {
    static let outputLimit = 1024 * 1024

    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var out = Data(), err = Data(), timedOut = false, cancelled = false, finished = false
        func append(_ data: Data, toError: Bool) {
            lock.lock(); defer { lock.unlock() }
            if toError { if err.count < KnowledgeProcessRunner.outputLimit { err.append(data.prefix(KnowledgeProcessRunner.outputLimit - err.count)) } }
            else if out.count < KnowledgeProcessRunner.outputLimit { out.append(data.prefix(KnowledgeProcessRunner.outputLimit - out.count)) }
        }
    }

    func run(executable: URL, arguments: [String], directory: URL, environment: [String: String], timeout: TimeInterval) async -> KnowledgeProcessResult {
        let state = State()
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe; process.standardError = errPipe
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil } else { state.append(data, toError: false) }
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil } else { state.append(data, toError: true) }
        }
        func terminate() {
            guard process.isRunning else { return }
            process.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { if process.isRunning { kill(process.processIdentifier, SIGKILL) } }
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<KnowledgeProcessResult, Never>) in
                process.terminationHandler = { finished in
                    outPipe.fileHandleForReading.readabilityHandler = nil; errPipe.fileHandleForReading.readabilityHandler = nil
                    // 排空管道里剩余的数据。
                    state.append((try? outPipe.fileHandleForReading.readToEnd()) ?? Data(), toError: false)
                    state.append((try? errPipe.fileHandleForReading.readToEnd()) ?? Data(), toError: true)
                    state.lock.lock()
                    let result = KnowledgeProcessResult(exitCode: finished.terminationStatus,
                        stdout: String(decoding: state.out, as: UTF8.self), stderr: String(decoding: state.err, as: UTF8.self),
                        timedOut: state.timedOut, cancelled: state.cancelled)
                    state.finished = true
                    state.lock.unlock()
                    continuation.resume(returning: result)
                }
                do { try process.run() }
                catch {
                    outPipe.fileHandleForReading.readabilityHandler = nil; errPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: KnowledgeProcessResult(exitCode: -1, stdout: "", stderr: "", launchError: error.localizedDescription))
                    return
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    state.lock.lock(); let done = state.finished; if !done { state.timedOut = true }; state.lock.unlock()
                    if !done { terminate() }
                }
                if Task.isCancelled { state.lock.lock(); state.cancelled = true; state.lock.unlock(); terminate() }
            }
        } onCancel: {
            state.lock.lock(); state.cancelled = true; state.lock.unlock()
            terminate()
        }
    }
}

// MARK: - Status

nonisolated struct KnowledgeGitCommit: Equatable, Sendable {
    let hash: String
    let date: Date
    let subject: String
    var shortHash: String { String(hash.prefix(8)) }
}

nonisolated struct KnowledgeGitStatus: Equatable, Sendable {
    var isRepository = false
    var branch: String?
    var detached = false
    var upstream: String?
    var ahead = 0
    var behind = 0
    /// 已修改 / 已暂存 / 冲突的跟踪文件数（去重后的条目数）。
    var changedTracked = 0
    var stagedTracked = 0
    var unmerged = 0
    var untracked = 0
    var lastCommit: KnowledgeGitCommit?
    var lastFetch: Date?
    /// merge / rebase / cherry-pick 进行中。
    var operationInProgress: String?
    /// 状态读取失败的原因（非 git 仓库时为 nil）。
    var failure: String?

    var hasTrackedChanges: Bool { changedTracked > 0 || stagedTracked > 0 || unmerged > 0 }
    var totalChanged: Int { changedTracked + untracked }
}

nonisolated enum KnowledgeGitStatusParser {
    /// 解析 `git status --porcelain=v2 --branch` 输出。
    static func parse(_ output: String) -> KnowledgeGitStatus {
        var status = KnowledgeGitStatus(isRepository: true)
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("# branch.head ") {
                let name = String(line.dropFirst("# branch.head ".count))
                if name == "(detached)" { status.detached = true } else { status.branch = name }
            } else if line.hasPrefix("# branch.upstream ") {
                status.upstream = String(line.dropFirst("# branch.upstream ".count))
            } else if line.hasPrefix("# branch.ab ") {
                let parts = line.dropFirst("# branch.ab ".count).split(separator: " ")
                if parts.count == 2, let a = Int(parts[0].dropFirst()), let b = Int(parts[1].dropFirst()) { status.ahead = a; status.behind = b }
            } else if line.hasPrefix("1 ") || line.hasPrefix("2 ") {
                let fields = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false)
                guard fields.count >= 2, fields[1].count == 2 else { continue }
                let xy = Array(fields[1])
                if xy[0] != "." { status.stagedTracked += 1 }
                if xy[1] != "." { status.changedTracked += 1 }
            } else if line.hasPrefix("u ") {
                status.unmerged += 1
            } else if line.hasPrefix("? ") {
                status.untracked += 1
            }
        }
        return status
    }

    static func parseCommit(_ output: String) -> KnowledgeGitCommit? {
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\u{1F}", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, let seconds = TimeInterval(parts[1]), parts[0].count >= 7 else { return nil }
        return KnowledgeGitCommit(hash: String(parts[0]), date: Date(timeIntervalSince1970: seconds), subject: String(parts[2]))
    }
}

// MARK: - Preconditions

nonisolated struct KnowledgeGitPullDecision: Equatable, Sendable {
    let allowed: Bool
    /// 置灰原因（allowed == false 时）。
    let reason: String?
    /// 允许时仍需提示的事项。
    let warnings: [String]
}

nonisolated enum KnowledgeGitPullPolicy {
    static func evaluate(_ status: KnowledgeGitStatus) -> KnowledgeGitPullDecision {
        func blocked(_ reason: String) -> KnowledgeGitPullDecision { .init(allowed: false, reason: reason, warnings: []) }
        guard status.isRepository else { return blocked("该来源不是 Git 仓库。") }
        if let failure = status.failure { return blocked("无法读取仓库状态：\(failure)") }
        if status.detached { return blocked("当前处于游离 HEAD，不在分支上。") }
        guard status.branch != nil else { return blocked("无法确定当前分支。") }
        guard status.upstream != nil else { return blocked("当前分支没有跟踪的远端分支。") }
        if let operation = status.operationInProgress { return blocked("仓库正处于\(operation)状态，请先在终端完成。") }
        if status.unmerged > 0 { return blocked("有 \(status.unmerged) 个未解决冲突的文件。") }
        if status.stagedTracked > 0 || status.changedTracked > 0 {
            var parts: [String] = []
            if status.changedTracked > 0 { parts.append("\(status.changedTracked) 个已修改") }
            if status.stagedTracked > 0 { parts.append("\(status.stagedTracked) 个已暂存") }
            return blocked("有\(parts.joined(separator: "、"))的跟踪文件；为避免覆盖，请先在终端处理。")
        }
        var warnings: [String] = []
        if status.untracked > 0 { warnings.append("有 \(status.untracked) 个未跟踪文件；若与远端文件同名，Git 会拒绝更新。") }
        if status.ahead > 0 { warnings.append("本地有 \(status.ahead) 个未推送的提交；若远端同时有更新，将无法快进并被拒绝。") }
        return .init(allowed: true, reason: nil, warnings: warnings)
    }
}

// MARK: - Output hygiene

nonisolated enum KnowledgeGitOutput {
    /// 摘要：去掉 URL 中的认证片段、常见令牌，限制行数与长度。
    static func summary(_ text: String, maxLines: Int = 12, maxCharacters: Int = 1500) -> String {
        var cleaned = redact(text)
        cleaned = cleaned.split(separator: "\n", omittingEmptySubsequences: true).prefix(maxLines)
            .map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        return cleaned.count > maxCharacters ? String(cleaned.prefix(maxCharacters)) + "…" : cleaned
    }
    static func redact(_ text: String) -> String {
        var result = text
        let patterns: [(String, String)] = [
            ("([A-Za-z][A-Za-z0-9+.\\-]*://)[^/\\s@]+@", "$1***@"),
            ("gh[pousr]_[A-Za-z0-9]{16,}", "***"),
            ("github_pat_[A-Za-z0-9_]{16,}", "***"),
            ("glpat-[A-Za-z0-9_\\-]{12,}", "***"),
            ("(?i)(authorization:\\s*(basic|bearer)\\s+)\\S+", "$1***"),
        ]
        for (pattern, template) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: template)
            }
        }
        return result
    }
}

nonisolated struct KnowledgeGitOperationResult: Equatable, Sendable {
    enum Outcome: Equatable, Sendable { case success, failed, timedOut, cancelled, blocked }
    let outcome: Outcome
    /// 脱敏后的摘要。
    let message: String
}

// MARK: - Service

/// 所有 git 系统调用集中于此：`/usr/bin/git`，参数数组，`GIT_TERMINAL_PROMPT=0`，60 秒超时，可取消。
/// 凭据完全依赖用户电脑上已有的 git 配置；本服务不读取、不保存、不记录任何凭据。
nonisolated struct KnowledgeSourceGitService: Sendable {
    static let gitExecutable = URL(fileURLWithPath: "/usr/bin/git")
    static let defaultTimeout: TimeInterval = 60

    let runner: any KnowledgeProcessRunning
    var timeout: TimeInterval = KnowledgeSourceGitService.defaultTimeout
    var executable: URL = KnowledgeSourceGitService.gitExecutable

    init(runner: any KnowledgeProcessRunning = KnowledgeProcessRunner(), timeout: TimeInterval = defaultTimeout,
         executable: URL = KnowledgeSourceGitService.gitExecutable) {
        self.runner = runner; self.timeout = timeout; self.executable = executable
    }

    static var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["GIT_PAGER"] = "cat"
        env["GCM_INTERACTIVE"] = "never"
        env["LANG"] = "en_US.UTF-8"; env["LC_ALL"] = "en_US.UTF-8"
        env["GIT_OPTIONAL_LOCKS"] = "0"
        return env
    }

    func arguments(for command: KnowledgeGitCommand) -> [String] { KnowledgeGitCommand.globalOptions + command.arguments }

    private func run(_ command: KnowledgeGitCommand, in root: URL) async -> KnowledgeProcessResult {
        await runner.run(executable: executable, arguments: arguments(for: command), directory: root,
                         environment: Self.environment, timeout: timeout)
    }

    /// 来源是否为 Git 仓库根（根下存在 `.git`，目录或文件）。不会执行 git。
    static func isRepository(_ root: URL) -> Bool { KnowledgeSourceScanner.hasGitEntry(root.path) }

    func status(root: URL) async -> KnowledgeGitStatus {
        guard Self.isRepository(root) else { return KnowledgeGitStatus() }
        let result = await run(.status, in: root)
        guard result.launchError == nil, !result.timedOut, !result.cancelled, result.exitCode == 0 else {
            var failed = KnowledgeGitStatus(isRepository: true)
            failed.failure = result.launchError ?? (result.timedOut ? "读取超时" : result.cancelled ? "已取消" : KnowledgeGitOutput.summary(result.stderr, maxLines: 3))
            return failed
        }
        var status = KnowledgeGitStatusParser.parse(result.stdout)
        let commit = await run(.lastCommit, in: root)
        if commit.exitCode == 0 { status.lastCommit = KnowledgeGitStatusParser.parseCommit(commit.stdout) }
        let dir = await run(.gitDirectory, in: root)
        if dir.exitCode == 0 {
            let gitDir = dir.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if gitDir.hasPrefix("/") {
                var info = stat()
                if lstat(gitDir + "/FETCH_HEAD", &info) == 0 { status.lastFetch = Date(timeIntervalSince1970: TimeInterval(info.st_mtimespec.tv_sec)) }
                for (marker, label) in [("MERGE_HEAD", "合并"), ("rebase-merge", "变基"), ("rebase-apply", "变基/应用补丁"),
                                         ("CHERRY_PICK_HEAD", "拣选"), ("REVERT_HEAD", "还原")] where KnowledgeSourceScanner.kind(gitDir + "/" + marker) != nil {
                    status.operationInProgress = label; break
                }
            }
        }
        return status
    }

    /// 用户点击“检查远端更新”：`git fetch origin`。
    func fetch(root: URL) async -> KnowledgeGitOperationResult {
        guard Self.isRepository(root) else { return .init(outcome: .blocked, message: "该来源不是 Git 仓库。") }
        return Self.interpret(await run(.fetch, in: root), success: "已检查远端更新。")
    }

    /// 用户确认后：先用最新状态再次核对前置条件，满足才执行 `git pull --ff-only`。
    func pull(root: URL) async -> KnowledgeGitOperationResult {
        let fresh = await status(root: root)
        let decision = KnowledgeGitPullPolicy.evaluate(fresh)
        guard decision.allowed else { return .init(outcome: .blocked, message: decision.reason ?? "不满足拉取条件。") }
        return Self.interpret(await run(.pullFastForwardOnly, in: root), success: "拉取完成。")
    }

    static func interpret(_ result: KnowledgeProcessResult, success: String) -> KnowledgeGitOperationResult {
        if let error = result.launchError { return .init(outcome: .failed, message: "无法启动 git：" + error) }
        if result.cancelled { return .init(outcome: .cancelled, message: "已取消。") }
        if result.timedOut { return .init(outcome: .timedOut, message: "操作超过 60 秒已中止（可能是网络或凭据问题）。") }
        let detail = KnowledgeGitOutput.summary(result.stderr.isEmpty ? result.stdout : result.stderr + "\n" + result.stdout)
        if result.exitCode == 0 { return .init(outcome: .success, message: detail.isEmpty ? success : detail) }
        return .init(outcome: .failed, message: detail.isEmpty ? "git 以状态 \(result.exitCode) 退出。" : detail)
    }
}
