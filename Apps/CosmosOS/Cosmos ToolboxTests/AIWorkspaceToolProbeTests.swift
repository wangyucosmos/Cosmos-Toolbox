import XCTest
import Foundation
import SwiftUI
import AppKit
@testable import Cosmos_Toolbox

/// AI 工作台 Phase 1: runner safety (timeout, cancellation, output cap, controlled
/// environment), candidate discovery, shim handling and view-model concurrency.
/// Fake executables live in a temporary directory; no production data is read.
@MainActor
final class AIWorkspaceToolProbeTests: XCTestCase {

    // MARK: Helpers

    var roots: [URL] = []

    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots = []
        super.tearDown()
    }

    func tempRoot() throws -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosAIWorkspace-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        roots.append(root)
        return root
    }

    @discardableResult
    func script(_ path: URL, _ body: String, executable: Bool = true) throws -> URL {
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ("#!/bin/sh\n" + body + "\n").write(to: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: executable ? 0o755 : 0o644], ofItemAtPath: path.path)
        return path
    }

    func runner(timeout: TimeInterval = 3, limit: Int = 64 * 1024) -> AIWorkspaceProcessRunner {
        AIWorkspaceProcessRunner(homeDirectory: NSHomeDirectory(), timeout: timeout, killGrace: 0.3, outputLimit: limit)
    }

    func probe(
        home: URL,
        path: [URL] = [],
        common: [URL]? = nil,
        apps: [URL] = [],
        shims: Set<String> = [],
        xcodeSelect: String = "/nonexistent/xcode-select",
        timeout: TimeInterval = 3
    ) -> AIWorkspaceToolProbe {
        var probe = AIWorkspaceToolProbe(
            runner: runner(timeout: timeout),
            homeDirectory: home.path,
            pathEntries: path.map(\.path),
            commonDirectories: (common ?? [home.appendingPathComponent(".local/bin")]).map(\.path),
            applicationDirectories: apps.map(\.path),
            systemShimPaths: shims
        )
        probe.xcodeSelectPath = xcodeSelect
        probe.commandTimeoutSeconds = Int(timeout)
        return probe
    }

    func isAlive(_ pid: pid_t) -> Bool { kill(pid, 0) == 0 }

    /// Waits until the fake child has written its pid, i.e. it is really running.
    func waitForFile(_ file: URL) async {
        var attempts = 0
        while !FileManager.default.fileExists(atPath: file.path) && attempts < 500 {
            try? await Task.sleep(nanoseconds: 10_000_000)
            attempts += 1
        }
    }

    func readPID(_ file: URL) throws -> pid_t {
        let text = try String(contentsOf: file, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        return try XCTUnwrap(pid_t(text))
    }

    // MARK: Runner

    func testRunnerCapturesVersionOutputAndExitCode() async throws {
        let dir = try tempRoot()
        let ok = try script(dir.appendingPathComponent("ok"), "echo 'tool 1.2.3'")
        let bad = try script(dir.appendingPathComponent("bad"), "echo oops >&2; exit 3")

        let good = await runner().run(executable: ok.path, arguments: ["--version"])
        XCTAssertEqual(good, .finished(exitCode: 0, output: "tool 1.2.3\n"))

        let failed = await runner().run(executable: bad.path, arguments: ["--version"])
        XCTAssertEqual(failed, .finished(exitCode: 3, output: "oops\n"))
    }

    func testRunnerTimeoutTerminatesChildAndReturnsPromptly() async throws {
        let dir = try tempRoot()
        let pidFile = dir.appendingPathComponent("pid")
        // A shell that spawns a sleeping grandchild: the pipe stays open after the shell dies.
        let hang = try script(dir.appendingPathComponent("hang"), "echo $$ > '\(pidFile.path)'\nsleep 30\n")

        let started = Date()
        let outcome = await runner(timeout: 1.5).run(executable: hang.path, arguments: [])
        XCTAssertEqual(outcome, .timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(started), 4)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(isAlive(try readPID(pidFile)), "the shell must be gone")
    }

    func testRunnerKillsChildThatIgnoresSIGTERM() async throws {
        let dir = try tempRoot()
        let pidFile = dir.appendingPathComponent("pid")
        let stubborn = try script(
            dir.appendingPathComponent("stubborn"),
            "trap '' TERM\necho $$ > '\(pidFile.path)'\nwhile true; do :; done")

        let started = Date()
        let outcome = await runner(timeout: 1.5).run(executable: stubborn.path, arguments: [])
        XCTAssertEqual(outcome, .timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(started), 4)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertFalse(isAlive(try readPID(pidFile)), "SIGKILL must follow the grace period")
    }

    func testRunnerCancellationTerminatesChild() async throws {
        let dir = try tempRoot()
        let pidFile = dir.appendingPathComponent("pid")
        let hang = try script(dir.appendingPathComponent("hang"), "echo $$ > '\(pidFile.path)'\nexec sleep 30")
        let runner = runner(timeout: 20)

        let task = Task { await runner.run(executable: hang.path, arguments: []) }
        await waitForFile(pidFile)
        let started = Date()
        task.cancel()
        let outcome = await task.value

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(isAlive(try readPID(pidFile)))
    }

    func testRunnerDoesNotLaunchWhenAlreadyCancelled() async throws {
        let dir = try tempRoot()
        let marker = dir.appendingPathComponent("ran")
        let tool = try script(dir.appendingPathComponent("tool"), "touch '\(marker.path)'")
        let runner = runner()

        let task = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)   // returns at once once cancelled
            return await runner.run(executable: tool.path, arguments: [])
        }
        task.cancel()
        let outcome = await task.value

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testRunnerCapsOutputWithoutBlockingTheChild() async throws {
        let dir = try tempRoot()
        let flood = try script(dir.appendingPathComponent("flood"), "head -c 600000 /dev/zero | tr '\\0' a")

        let outcome = await runner(timeout: 5, limit: 1024).run(executable: flood.path, arguments: [])
        guard case .finished(let code, let output) = outcome else { return XCTFail("\(outcome)") }
        XCTAssertEqual(code, 0)
        XCTAssertEqual(output.utf8.count, 1024)
    }

    func testRunnerUsesControlledEnvironmentAndClosedStdin() async throws {
        let dir = try tempRoot()
        setenv("CLAUDE_CODE_TEST_SECRET", "must-not-leak", 1)
        setenv("ANTHROPIC_API_KEY", "must-not-leak", 1)
        defer { unsetenv("CLAUDE_CODE_TEST_SECRET"); unsetenv("ANTHROPIC_API_KEY") }
        let probeEnv = try script(dir.appendingPathComponent("probe"), "env\ncat\necho stdin-closed")

        let outcome = await runner(timeout: 3).run(executable: probeEnv.path, arguments: [])
        guard case .finished(let code, let output) = outcome else { return XCTFail("\(outcome)") }
        XCTAssertEqual(code, 0)
        XCTAssertFalse(output.contains("must-not-leak"))
        XCTAssertFalse(output.contains("CLAUDE_CODE_TEST_SECRET"))
        XCTAssertTrue(output.contains("PATH=\(dir.path):/usr/bin:/bin:/usr/sbin:/sbin"))
        XCTAssertTrue(output.contains("stdin-closed"), "cat must see EOF immediately")
    }

    func testRunnerReportsLaunchFailure() async throws {
        let dir = try tempRoot()
        let broken = try script(dir.appendingPathComponent("broken"), "")
        try "#!/nonexistent/interpreter\n".write(to: broken, atomically: true, encoding: .utf8)

        let outcome = await runner().run(executable: broken.path, arguments: [])
        guard case .launchFailed = outcome else { return XCTFail("\(outcome)") }
    }

    // MARK: Discovery

    func testDiscoveryRecordsActualSourceForEveryTool() async throws {
        let root = try tempRoot()
        let home = root.appendingPathComponent("home")
        let apps = root.appendingPathComponent("Apps")
        let pathDir = root.appendingPathComponent("pathbin")

        try script(pathDir.appendingPathComponent("git"), "echo 'git version 2.54.0 (Apple Git-157)'")
        try script(home.appendingPathComponent(".local/bin/python3"), "echo 'Python 3.12.1'")
        try script(home.appendingPathComponent(".nvm/versions/node/v18.0.0/bin/node"), "echo v18.0.0")
        try script(home.appendingPathComponent(".nvm/versions/node/v22.4.1/bin/node"), "echo v22.4.1")
        try script(apps.appendingPathComponent("ChatGPT.app/Contents/Resources/codex-cli/bin/codex"),
                   "echo 'codex-cli 0.162.0-alpha.17.2'")
        let claudeRoot = home.appendingPathComponent("Library/Application Support/Claude/claude-code")
        try script(claudeRoot.appendingPathComponent("2.1.289/aaa/claude.app/Contents/MacOS/claude"),
                   "echo '2.1.289 (Claude Code)'")
        try script(claudeRoot.appendingPathComponent("2.1.293/bbb/claude.app/Contents/MacOS/claude"),
                   "echo '2.1.293 (Claude Code)'")

        let detected = await probe(home: home, path: [pathDir], apps: [apps]).detectAll()
        let snapshot = try XCTUnwrap(detected)
        XCTAssertEqual(snapshot.results.map(\.tool), AIWorkspaceToolID.allCases)

        func result(_ tool: AIWorkspaceToolID) throws -> AIWorkspaceToolResult {
            try XCTUnwrap(snapshot.results.first { $0.tool == tool })
        }
        let git = try result(.git)
        XCTAssertEqual(git.status, .ready)
        XCTAssertEqual(git.version, "2.54.0")
        XCTAssertEqual(git.source, .currentPath)

        let python = try result(.python)
        XCTAssertEqual(python.version, "3.12.1")
        XCTAssertEqual(python.source, .commonLocation)

        let node = try result(.node)
        XCTAssertEqual(node.version, "22.4.1", "newest nvm version, numerically")
        XCTAssertEqual(node.source, .commonLocation)

        let codex = try result(.codex)
        XCTAssertEqual(codex.version, "0.162.0-alpha.17.2")
        XCTAssertEqual(codex.source, .chatGPTDesktopBundle)

        let claude = try result(.claudeCode)
        XCTAssertEqual(claude.version, "2.1.293", "highest bundled version wins")
        XCTAssertEqual(claude.source, .claudeDesktopBundle)
    }

    func testMissingToolAndSamePathKeepsFirstSource() async throws {
        let root = try tempRoot()
        let home = root.appendingPathComponent("home")
        let both = home.appendingPathComponent(".local/bin")
        try script(both.appendingPathComponent("node"), "echo v20.1.0")

        let probe = probe(home: home, path: [both])
        let raw1 = await probe.detect(.node, developerToolsAvailable: true)
        let node = try XCTUnwrap(raw1)
        XCTAssertEqual(node.source, .currentPath, "found through PATH first, so labelled as PATH")
        XCTAssertEqual(probe.candidates(for: .node).filter { $0.path == both.appendingPathComponent("node").path }.count, 1)

        let raw2 = await probe.detect(.claudeCode, developerToolsAvailable: true)

        let claude = try XCTUnwrap(raw2)
        XCTAssertEqual(claude.status, .missing)
        XCTAssertEqual(claude.failure, .notFound)
        XCTAssertNil(claude.path)
    }

    func testResolvedSymlinkPathIsReportedSeparately() async throws {
        let root = try tempRoot()
        let home = root.appendingPathComponent("home")
        let real = try script(root.appendingPathComponent("real/node"), "echo v22.1.0")
        let bin = home.appendingPathComponent(".local/bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: bin.appendingPathComponent("node"), withDestinationURL: real)

        let raw3 = await probe(home: home).detect(.node, developerToolsAvailable: true)

        let node = try XCTUnwrap(raw3)
        XCTAssertEqual(node.path, bin.appendingPathComponent("node").path)
        XCTAssertEqual(node.resolvedPath, URL(fileURLWithPath: real.path).resolvingSymlinksInPath().path)
    }

    // MARK: Failures

    func testFailuresAreExplainedAndDoNotBlockALaterGoodCandidate() async throws {
        let root = try tempRoot()
        let home = root.appendingPathComponent("home")
        let broken = root.appendingPathComponent("broken")
        let hang = root.appendingPathComponent("hang")
        let plain = root.appendingPathComponent("plain")

        try script(broken.appendingPathComponent("git"), "echo bad >&2; exit 7")
        try script(hang.appendingPathComponent("python3"), "exec sleep 30")
        try script(plain.appendingPathComponent("node"), "echo v1.0.0", executable: false)

        let probe = probe(home: home, path: [broken, hang, plain], timeout: 2)

        let raw4 = await probe.detect(.git, developerToolsAvailable: true)

        let git = try XCTUnwrap(raw4)
        XCTAssertEqual(git.status, .warning)
        XCTAssertEqual(git.failure, .nonZeroExit(code: 7, detail: "bad"))
        XCTAssertEqual(git.path, broken.appendingPathComponent("git").path)

        let raw5 = await probe.detect(.python, developerToolsAvailable: true)

        let python = try XCTUnwrap(raw5)
        XCTAssertEqual(python.failure, .timedOut(seconds: 2))

        let raw6 = await probe.detect(.node, developerToolsAvailable: true)

        let node = try XCTUnwrap(raw6)
        XCTAssertEqual(node.failure, .notExecutable(path: plain.appendingPathComponent("node").path))
        XCTAssertEqual(node.status, .warning)

        // A working candidate later in the order wins over an earlier failure.
        let good = home.appendingPathComponent(".local/bin")
        try script(good.appendingPathComponent("git"), "echo 'git version 2.40.0'")
        let raw7 = await probe.detect(.git, developerToolsAvailable: true)
        let recovered = try XCTUnwrap(raw7)
        XCTAssertEqual(recovered.status, .ready)
        XCTAssertEqual(recovered.version, "2.40.0")
        XCTAssertNil(recovered.failure)
    }

    func testOutputWithoutAVersionNumberIsStillRunnable() async throws {
        let root = try tempRoot()
        let home = root.appendingPathComponent("home")
        let bin = root.appendingPathComponent("bin")
        try script(bin.appendingPathComponent("codex"), "echo 'hello from codex'")

        let raw8 = await probe(home: home, path: [bin]).detect(.codex, developerToolsAvailable: true)

        let codex = try XCTUnwrap(raw8)
        XCTAssertEqual(codex.status, .ready)
        XCTAssertNil(codex.version)
        XCTAssertEqual(codex.versionLine, "hello from codex")
    }

    // MARK: System shims

    func testShimIsNotRunWithoutDeveloperTools() async throws {
        let root = try tempRoot()
        let home = root.appendingPathComponent("home")
        let marker = root.appendingPathComponent("shim-ran")
        let shim = try script(root.appendingPathComponent("usr-bin/git"), "touch '\(marker.path)'; echo 'git version 2.0'")
        let noTools = try script(root.appendingPathComponent("xcode-select-none"), "exit 2")

        let probe = probe(home: home, path: [shim.deletingLastPathComponent()],
                          shims: [shim.path], xcodeSelect: noTools.path)
        let available = await probe.developerToolsAvailable()
        XCTAssertFalse(available)

        let raw9 = await probe.detect(.git, developerToolsAvailable: available)

        let git = try XCTUnwrap(raw9)
        XCTAssertEqual(git.failure, .developerToolsMissing)
        XCTAssertEqual(git.status, .missing)
        XCTAssertTrue(git.isSystemShim)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path), "the shim must never be launched")
    }

    func testShimRunsWhenDeveloperToolsAreSelected() async throws {
        let root = try tempRoot()
        let home = root.appendingPathComponent("home")
        let developerDir = root.appendingPathComponent("Developer")
        try FileManager.default.createDirectory(at: developerDir, withIntermediateDirectories: true)
        let shim = try script(root.appendingPathComponent("usr-bin/git"), "echo 'git version 2.54.0 (Apple Git-157)'")
        let selected = try script(root.appendingPathComponent("xcode-select-ok"), "echo '\(developerDir.path)'")

        let probe = probe(home: home, path: [shim.deletingLastPathComponent()],
                          shims: [shim.path], xcodeSelect: selected.path)
        let available = await probe.developerToolsAvailable()
        XCTAssertTrue(available)

        let raw10 = await probe.detect(.git, developerToolsAvailable: available)

        let git = try XCTUnwrap(raw10)
        XCTAssertEqual(git.status, .ready)
        XCTAssertEqual(git.version, "2.54.0")
        XCTAssertTrue(git.isSystemShim)
    }

    // MARK: Parsing

    func testVersionParsing() {
        let cases: [(String, String?)] = [
            ("2.1.293 (Claude Code)\n", "2.1.293"),
            ("codex-cli 0.162.0-alpha.17.2", "0.162.0-alpha.17.2"),
            ("git version 2.54.0 (Apple Git-157)", "2.54.0"),
            ("Python 3.9.6", "3.9.6"),
            ("v22.23.1", "22.23.1"),
            ("\n\n  hello  \nsecond", nil)
        ]
        for (output, expected) in cases {
            XCTAssertEqual(AIWorkspaceToolProbe.parseVersion(from: output).version, expected, output)
        }
        XCTAssertEqual(AIWorkspaceToolProbe.parseVersion(from: "\n\n  hello  \nsecond").line, "hello")
        XCTAssertNil(AIWorkspaceToolProbe.parseVersion(from: "").line)
        XCTAssertLessThanOrEqual(
            AIWorkspaceToolProbe.parseVersion(from: String(repeating: "x", count: 500)).line?.count ?? 0, 120)
    }

    func testVersionSortingIsNumeric() {
        XCTAssertEqual(
            AIWorkspaceToolProbe.versionSorted(["2.1.289", "2.1.293", "abc", "10.0.1", "2.1.1000", "v3.0.0"]),
            ["10.0.1", "v3.0.0", "2.1.1000", "2.1.293", "2.1.289"])
    }

    // MARK: View model

    private actor Gate {
        private var waiters: [CheckedContinuation<Void, Never>] = []
        private var isOpen = false
        func wait() async {
            if isOpen { return }
            await withCheckedContinuation { waiters.append($0) }
        }
        func open() {
            isOpen = true
            let pending = waiters
            waiters = []
            for waiter in pending { waiter.resume() }
        }
    }

    private actor Counter {
        private(set) var value = 0
        func next() -> Int { value += 1; return value }
    }

    func snapshot(_ marker: String) -> AIWorkspaceSnapshot {
        AIWorkspaceSnapshot(
            results: [AIWorkspaceToolResult(
                tool: .git, failure: nil, version: marker, versionLine: nil, path: "/usr/bin/git",
                resolvedPath: nil, source: .currentPath, isSystemShim: false, checkedAt: Date())],
            completedAt: Date())
    }

    func waitUntil(_ condition: @escaping () -> Bool) async {
        var attempts = 0
        while !condition() && attempts < 300 {
            try? await Task.sleep(nanoseconds: 10_000_000)
            attempts += 1
        }
    }

    func testRepeatedRefreshWhileDetectingStartsOnlyOneRun() async {
        let counter = Counter()
        let gate = Gate()
        let model = AIWorkspaceViewModel(cache: AIWorkspaceResultCache()) { [snap = snapshot("A")] in
            _ = await counter.next()
            await gate.wait()
            return snap
        }
        model.refresh()
        model.refresh()
        model.refresh()
        XCTAssertTrue(model.isDetecting)
        await gate.open()
        await waitUntil { !model.isDetecting }

        let calls = await counter.value
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(model.snapshot?.results.first?.version, "A")
    }

    func testCancelledRunCanNeverOverwriteALaterResult() async {
        let counter = Counter()
        let firstGate = Gate()
        let cache = AIWorkspaceResultCache()
        let a = snapshot("A"), b = snapshot("B")
        let model = AIWorkspaceViewModel(cache: cache) {
            if await counter.next() == 1 {
                await firstGate.wait()      // ignores cancellation on purpose: a late, stale finisher
                return a
            }
            return b
        }

        model.refresh()                     // run 1, stays suspended
        model.cancel()                      // user left the page
        XCTAssertFalse(model.isDetecting)
        XCTAssertNil(model.snapshot)

        model.refresh()                     // run 2, finishes at once
        await waitUntil { model.snapshot != nil }
        XCTAssertEqual(model.snapshot?.results.first?.version, "B")

        await firstGate.open()              // run 1 finishes late
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(model.snapshot?.results.first?.version, "B")
        XCTAssertEqual(cache.snapshot?.results.first?.version, "B")
        XCTAssertFalse(model.isDetecting)
    }

    func testFinishedResultSurvivesLeavingAndReturning() async {
        let cache = AIWorkspaceResultCache()
        let first = AIWorkspaceViewModel(cache: cache) { [snap = snapshot("A")] in snap }
        first.refresh()
        await waitUntil { first.snapshot != nil }
        first.cancel()                      // page left after a finished run
        XCTAssertEqual(first.snapshot?.results.first?.version, "A")

        let returned = AIWorkspaceViewModel(cache: cache) { nil }
        XCTAssertEqual(returned.snapshot?.results.first?.version, "A")
        XCTAssertFalse(returned.isDetecting)
    }

    func testCancelledDetectionLeavesPreviousResultInPlace() async {
        let gate = Gate()
        let cache = AIWorkspaceResultCache()
        cache.snapshot = snapshot("old")
        let model = AIWorkspaceViewModel(cache: cache) {
            await gate.wait()
            return nil                      // what the probe returns when cancelled
        }
        model.refresh()
        model.cancel()
        await gate.open()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(model.snapshot?.results.first?.version, "old")
        XCTAssertFalse(model.isDetecting)
    }

    func testCancellingTheProbeReturnsNilAndStopsChildren() async throws {
        let root = try tempRoot()
        let home = root.appendingPathComponent("home")
        let bin = root.appendingPathComponent("bin")
        let pidFile = root.appendingPathComponent("pid")
        try script(bin.appendingPathComponent("node"), "echo $$ > '\(pidFile.path)'\nexec sleep 30")
        let probe = probe(home: home, path: [bin], timeout: 20)

        let task = Task { await probe.detectAll() }
        await waitForFile(pidFile)
        task.cancel()
        let result = await task.value
        XCTAssertNil(result)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertFalse(isAlive(try readPID(pidFile)))
    }

    // MARK: Live smoke and rendering

    func testLiveProbeReturnsAllFiveToolsInOrder() async throws {
        let detected = await AIWorkspaceToolProbe.live().detectAll()
        let snapshot = try XCTUnwrap(detected)
        XCTAssertEqual(snapshot.results.map(\.tool), AIWorkspaceToolID.allCases)
        for result in snapshot.results {
            XCTAssertEqual(result.status == .ready, result.failure == nil)
            if result.status == .ready { XCTAssertNotNil(result.path) }
        }
    }

    func testRealViewRendersIdleAndAllResultStates() throws {
        let now = Date()
        func result(_ tool: AIWorkspaceToolID, _ failure: AIWorkspaceToolFailure?, version: String? = nil,
                    line: String? = nil, path: String? = nil, resolved: String? = nil,
                    source: AIWorkspaceDiscoverySource? = nil, shim: Bool = false) -> AIWorkspaceToolResult {
            AIWorkspaceToolResult(tool: tool, failure: failure, version: version, versionLine: line, path: path,
                                  resolvedPath: resolved, source: source, isSystemShim: shim, checkedAt: now)
        }
        let cache = AIWorkspaceResultCache()
        cache.snapshot = AIWorkspaceSnapshot(results: [
            result(.claudeCode, nil, version: "2.1.293", line: "2.1.293 (Claude Code)",
                   path: "/Users/x/Library/Application Support/Claude/claude-code/2.1.293/id/claude.app/Contents/MacOS/claude",
                   source: .claudeDesktopBundle),
            result(.codex, .timedOut(seconds: 5), path: "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
                   source: .chatGPTDesktopBundle),
            result(.git, .developerToolsMissing, path: "/usr/bin/git", source: .currentPath, shim: true),
            result(.node, nil, version: "22.23.1", line: "v22.23.1", path: "/Users/x/.local/bin/node",
                   resolved: "/Users/x/.hermes/node/bin/node", source: .commonLocation),
            result(.python, .notFound)
        ], completedAt: now)

        let outDir = URL(fileURLWithPath: "/private/tmp/CosmosAIWorkspace-Screens", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        for (name, model) in [
            ("idle", AIWorkspaceViewModel(cache: AIWorkspaceResultCache()) { nil }),
            ("results", AIWorkspaceViewModel(cache: cache) { nil })
        ] {
            let host = NSHostingView(rootView: AIWorkspaceView(model: model).frame(width: 900, height: 820))
            host.frame = NSRect(x: 0, y: 0, width: 900, height: 820)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            XCTAssertGreaterThan(png.count, 5_000)
            try png.write(to: outDir.appendingPathComponent("ai-workspace-\(name).png"))
        }
    }
}
