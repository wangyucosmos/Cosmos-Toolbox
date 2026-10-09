import Foundation

// MARK: - Tool probe
//
// Finds candidate executables for the five Phase 1 tools (current process PATH,
// a short list of common locations, and the two desktop apps' bundled CLIs),
// then runs `<candidate> --version` through the controlled runner. It does not
// use a login or interactive shell, scans no unrelated directories, and writes
// nothing.

nonisolated struct AIWorkspaceToolProbe: Sendable {

    struct Candidate: Equatable, Sendable {
        let path: String
        let source: AIWorkspaceDiscoverySource
    }

    let runner: any AIWorkspaceCommandRunning
    var homeDirectory: String
    /// Absolute directories taken from the current process PATH.
    var pathEntries: [String]
    /// Fixed directories tried after the PATH entries.
    var commonDirectories: [String]
    var applicationDirectories: [String]
    /// `/usr/bin` entry points that are xcode-select shims.
    var systemShimPaths: Set<String>
    var xcodeSelectPath: String = "/usr/bin/xcode-select"
    /// Upper bound for trying candidates of one tool.
    var perToolBudget: TimeInterval = 8
    /// Shown in the timeout message; matches the runner's per-command limit.
    var commandTimeoutSeconds: Int = 5
    var now: @Sendable () -> Date = { Date() }

    static func live() -> AIWorkspaceToolProbe {
        let home = NSHomeDirectory()
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return AIWorkspaceToolProbe(
            runner: AIWorkspaceProcessRunner(homeDirectory: home),
            homeDirectory: home,
            pathEntries: path.split(separator: ":").map(String.init),
            commonDirectories: ["/opt/homebrew/bin", "/usr/local/bin", home + "/.local/bin", "/usr/bin"],
            applicationDirectories: ["/Applications", home + "/Applications"],
            systemShimPaths: ["/usr/bin/git", "/usr/bin/python3"]
        )
    }


    // MARK: Detect all

    /// Returns nil when the surrounding task was cancelled.
    func detectAll() async -> AIWorkspaceSnapshot? {
        let developerTools = await developerToolsAvailable()
        if Task.isCancelled { return nil }

        let results = await withTaskGroup(of: AIWorkspaceToolResult?.self) { group in
            for tool in AIWorkspaceToolID.allCases {
                group.addTask { await detect(tool, developerToolsAvailable: developerTools) }
            }
            var collected: [AIWorkspaceToolResult] = []
            for await result in group {
                if let result { collected.append(result) }
            }
            return collected
        }

        guard !Task.isCancelled, results.count == AIWorkspaceToolID.allCases.count else { return nil }
        let ordered = AIWorkspaceToolID.allCases.compactMap { tool in
            results.first { $0.tool == tool }
        }
        return AIWorkspaceSnapshot(results: ordered, completedAt: now())
    }


    // MARK: Detect one

    func detect(_ tool: AIWorkspaceToolID, developerToolsAvailable: Bool) async -> AIWorkspaceToolResult? {
        let started = now()
        let fileManager = FileManager.default
        var firstFailure: (failure: AIWorkspaceToolFailure, candidate: Candidate)?
        var skippedShim: Candidate?

        for candidate in candidates(for: tool) {
            if Task.isCancelled { return nil }
            if now().timeIntervalSince(started) > perToolBudget {
                if firstFailure == nil { firstFailure = (.timedOut(seconds: Int(perToolBudget)), candidate) }
                break
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else { continue }

            guard fileManager.isExecutableFile(atPath: candidate.path) else {
                if firstFailure == nil { firstFailure = (.notExecutable(path: candidate.path), candidate) }
                continue
            }

            let isShim = systemShimPaths.contains(candidate.path)
            if isShim && !developerToolsAvailable {
                if skippedShim == nil { skippedShim = candidate }
                continue
            }

            switch await runner.run(executable: candidate.path, arguments: ["--version"]) {
            case .cancelled:
                return nil

            case .finished(let code, let output) where code == 0:
                let parsed = Self.parseVersion(from: output)
                return result(tool, candidate, isShim: isShim, failure: nil,
                              version: parsed.version, line: parsed.line)

            case .finished(let code, let output):
                let detail = Self.parseVersion(from: output).line ?? ""
                if firstFailure == nil {
                    firstFailure = (.nonZeroExit(code: code, detail: detail), candidate)
                }

            case .timedOut:
                if firstFailure == nil {
                    firstFailure = (.timedOut(seconds: commandTimeoutSeconds), candidate)
                }

            case .launchFailed(let reason):
                if firstFailure == nil { firstFailure = (.launchFailed(reason), candidate) }
            }
        }

        if let firstFailure {
            return result(tool, firstFailure.candidate,
                          isShim: systemShimPaths.contains(firstFailure.candidate.path),
                          failure: firstFailure.failure, version: nil, line: nil)
        }
        if let skippedShim {
            return result(tool, skippedShim, isShim: true, failure: .developerToolsMissing,
                          version: nil, line: nil)
        }
        return AIWorkspaceToolResult(
            tool: tool, failure: .notFound, version: nil, versionLine: nil, path: nil,
            resolvedPath: nil, source: nil, isSystemShim: false, checkedAt: now()
        )
    }

    private func result(
        _ tool: AIWorkspaceToolID,
        _ candidate: Candidate,
        isShim: Bool,
        failure: AIWorkspaceToolFailure?,
        version: String?,
        line: String?
    ) -> AIWorkspaceToolResult {
        let resolved = URL(fileURLWithPath: candidate.path).resolvingSymlinksInPath().path
        return AIWorkspaceToolResult(
            tool: tool,
            failure: failure,
            version: version,
            versionLine: line,
            path: candidate.path,
            resolvedPath: resolved == candidate.path ? nil : resolved,
            source: candidate.source,
            isSystemShim: isShim,
            checkedAt: now()
        )
    }


    // MARK: Developer tools

    /// `/usr/bin/git` and `/usr/bin/python3` are shims that pop up an install
    /// dialog when no developer tools are selected, so they are only run after
    /// `xcode-select -p` (which never installs anything) confirms a directory.
    func developerToolsAvailable() async -> Bool {
        guard !systemShimPaths.isEmpty else { return true }
        guard FileManager.default.isExecutableFile(atPath: xcodeSelectPath) else { return false }
        guard case .finished(let code, let output) = await runner.run(
            executable: xcodeSelectPath, arguments: ["-p"]
        ), code == 0 else { return false }

        let directory = output.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return !directory.isEmpty && FileManager.default.fileExists(atPath: directory)
    }


    // MARK: Candidates

    func candidates(for tool: AIWorkspaceToolID) -> [Candidate] {
        let name = tool.commandName
        var list: [Candidate] = []

        func add(_ directory: String, _ source: AIWorkspaceDiscoverySource) {
            list.append(Candidate(
                path: URL(fileURLWithPath: directory).appendingPathComponent(name).path,
                source: source
            ))
        }

        for entry in pathEntries where entry.hasPrefix("/") { add(entry, .currentPath) }

        for directory in commonDirectories { add(directory, .commonLocation) }

        switch tool {
        case .claudeCode:
            add(homeDirectory + "/.claude/local", .commonLocation)
            for directory in claudeDesktopDirectories() { add(directory, .claudeDesktopBundle) }

        case .codex:
            for applications in applicationDirectories {
                add(applications + "/ChatGPT.app/Contents/Resources/codex-cli/bin", .chatGPTDesktopBundle)
            }

        case .node:
            add(homeDirectory + "/.volta/bin", .commonLocation)
            add(homeDirectory + "/.asdf/shims", .commonLocation)
            if let newest = Self.newestVersionDirectory(in: homeDirectory + "/.nvm/versions/node") {
                add(newest + "/bin", .commonLocation)
            }

        case .git, .python:
            break
        }

        var seen = Set<String>()
        return list.filter { seen.insert($0.path).inserted }
    }

    /// `~/Library/Application Support/Claude/claude-code/<version>/<id>/claude.app/Contents/MacOS`,
    /// highest numeric version first (old versions linger after updates).
    private func claudeDesktopDirectories() -> [String] {
        let root = homeDirectory + "/Library/Application Support/Claude/claude-code"
        let versions = Self.versionSorted(Self.listDirectory(root)).prefix(3)
        var directories: [String] = []
        for version in versions {
            let versionRoot = root + "/" + version
            for identifier in Self.listDirectory(versionRoot).sorted() {
                directories.append(versionRoot + "/" + identifier + "/claude.app/Contents/MacOS")
            }
        }
        return directories
    }


    // MARK: Helpers

    private static func listDirectory(_ path: String) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    }

    /// Numeric components, highest first; names that are not versions are dropped.
    static func versionSorted(_ names: [String]) -> [String] {
        func components(_ name: String) -> [Int]? {
            let trimmed = name.hasPrefix("v") ? String(name.dropFirst()) : name
            let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
            guard !parts.isEmpty, !parts.contains(nil) else { return nil }
            return parts.compactMap { $0 }
        }
        return names
            .compactMap { name in components(name).map { (name, $0) } }
            .sorted { lhs, rhs in
                for (a, b) in zip(lhs.1, rhs.1) where a != b { return a > b }
                return lhs.1.count > rhs.1.count
            }
            .map(\.0)
    }

    private static func newestVersionDirectory(in root: String) -> String? {
        versionSorted(listDirectory(root)).first.map { root + "/" + $0 }
    }

    /// Recognises a version number in the first non-empty line, e.g.
    /// "2.1.293 (Claude Code)", "git version 2.54.0 (Apple Git-157)", "v22.23.1".
    static func parseVersion(from output: String) -> (version: String?, line: String?) {
        let line = output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        guard let line else { return (nil, nil) }
        let shortened = String(line.prefix(120))
        let version = shortened.firstMatch(of: /[0-9]+(?:\.[0-9]+)+[0-9A-Za-z.+\-]*/).map { String($0.output) }
        return (version, shortened)
    }
}
