import Foundation
import OSLog

// MARK: - DeepSeek Harness Runtime Compatibility

struct DeepSeekHarnessRuntime {
    let executableURL: URL?
    let version: String
    let dshHomePath: String
    let supportsHeadless: Bool
    let source: String

    var isDiscoveredRuntime: Bool {
        executableURL != nil && supportsHeadless
    }
}


struct DeepSeekHarnessRuntimeCompatibility {

    private let fileManager: FileManager
    private let environment: [String: String]

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        self.environment = environment
    }


    func discover() -> DeepSeekHarnessRuntime {
        let dshHomePath = discoverDSHHome()

        for candidate in executableCandidates() {
            guard fileManager.isExecutableFile(atPath: candidate) else {
                continue
            }

            let executableURL = URL(fileURLWithPath: candidate)
                .resolvingSymlinksInPath()
            let version = commandOutput(
                executableURL: executableURL,
                arguments: ["--version"]
            )
            let help = commandOutput(
                executableURL: executableURL,
                arguments: ["--help"]
            )
            let supportsHeadless = help.contains("--profile headless")

            guard !version.isEmpty, supportsHeadless else {
                continue
            }

            return DeepSeekHarnessRuntime(
                executableURL: executableURL,
                version: version,
                dshHomePath: dshHomePath,
                supportsHeadless: true,
                source: "本机 dsh"
            )
        }

        return DeepSeekHarnessRuntime(
            executableURL: nil,
            version: "由 npx 环境解析",
            dshHomePath: dshHomePath,
            supportsHeadless: true,
            source: "兼容 fallback"
        )
    }


    func discoverDSHHome() -> String {
        if let configured = nonempty(environment["DSH_HOME"]) {
            return NSString(string: configured).expandingTildeInPath
        }

        let homePath = nonempty(environment["HOME"])
            ?? fileManager.homeDirectoryForCurrentUser.path
        let launchAgentURL = URL(fileURLWithPath: homePath)
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("ai.deepseek.harness.server.plist")

        if
            let data = try? Data(contentsOf: launchAgentURL),
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any],
            let variables = plist["EnvironmentVariables"]
                as? [String: String],
            let configured = nonempty(variables["DSH_HOME"])
        {
            return NSString(string: configured).expandingTildeInPath
        }

        return URL(fileURLWithPath: homePath)
            .appendingPathComponent(".dsh", isDirectory: true)
            .path
    }


    func executableCandidates() -> [String] {
        let homePath = nonempty(environment["HOME"])
            ?? fileManager.homeDirectoryForCurrentUser.path
        var candidates: [String] = []

        if let configured = nonempty(environment["COSMOS_DSH_EXECUTABLE"]) {
            candidates.append(
                NSString(string: configured).expandingTildeInPath
            )
        }

        if let path = environment["PATH"] {
            candidates.append(
                contentsOf: path
                    .split(separator: ":")
                    .map {
                        URL(fileURLWithPath: String($0))
                            .appendingPathComponent("dsh")
                            .path
                    }
            )
        }

        candidates.append(
            contentsOf: [
                URL(fileURLWithPath: homePath)
                    .appendingPathComponent(".local/bin/dsh")
                    .path,
                "/opt/homebrew/bin/dsh",
                "/usr/local/bin/dsh"
            ]
        )

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }


    private func commandOutput(
        executableURL: URL,
        arguments: [String]
    ) -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return ""
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
    }


    private func nonempty(_ value: String?) -> String? {
        let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned?.isEmpty == false ? cleaned : nil
    }
}

// MARK: - DeepSeek Harness Execution Result

struct DeepSeekHarnessExecutionResult {
    let output: String
    let errorOutput: String
    let exitCode: Int32

    var isSuccess: Bool {
        exitCode == 0
        && !output
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
    }
}


// MARK: - DeepSeek Harness Error

enum DeepSeekHarnessAdapterError:
    LocalizedError {

    case emptyTask
    case executionFailed(
        exitCode: Int32,
        message: String
    )
    case noOutput

    var errorDescription: String? {
        switch self {

        case .emptyTask:
            return "任务内容为空，无法交给 DeepSeek Harness 执行。"

        case let .executionFailed(
            exitCode,
            message
        ):
            return """
            DeepSeek Harness 执行失败。
            Exit Code: \(exitCode)
            \(message)
            """

        case .noOutput:
            return "DeepSeek Harness 已结束，但没有返回有效结果。"
        }
    }
}


// MARK: - DeepSeek Harness Adapter

final class DeepSeekHarnessAdapter {

    static let shared =
        DeepSeekHarnessAdapter()

    private let runtime: DeepSeekHarnessRuntime

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CosmosToolbox",
        category: "DeepSeekHarnessRuntime"
    )

    private init() {
        runtime = DeepSeekHarnessRuntimeCompatibility().discover()
        logRuntime()
    }


    // MARK: - Configuration

    private let shellPath =
        "/bin/zsh"

    private let npxPath =
        "/Users/rainiesmac-15/.local/bin/npx"

    private let nodeBinDirectory =
        "/Users/rainiesmac-15/.local/bin"

    private let dshPackage =
        "@deepseek-ai/dsh"


    // MARK: - Execute Task Package

    func execute(
        taskPackage: ZhuowangAITaskPackage
    ) async throws
        -> DeepSeekHarnessExecutionResult {

        let taskText =
            Self.buildExecutionText(
                from: taskPackage
            )

        return try await execute(
            task: taskText
        )
    }


    // MARK: - Execute Raw Task

    func execute(
        task: String
    ) async throws
        -> DeepSeekHarnessExecutionResult {

        let cleanTask =
            task.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanTask.isEmpty else {
            throw DeepSeekHarnessAdapterError
                .emptyTask
        }

        return try await withCheckedThrowingContinuation {
            continuation in

            DispatchQueue.global(
                qos: .userInitiated
            )
            .async {

                do {
                    let result =
                        try self.runProcess(
                            task: cleanTask
                        )

                    continuation.resume(
                        returning: result
                    )

                } catch {
                    continuation.resume(
                        throwing: error
                    )
                }
            }
        }
    }


    // MARK: - Process

    private func runProcess(
        task: String
    ) throws
        -> DeepSeekHarnessExecutionResult {

        let process =
            Process()

        let stdoutPipe =
            Pipe()

        let stderrPipe =
            Pipe()

        process.standardOutput =
            stdoutPipe

        process.standardError =
            stderrPipe


        // Important:
        //
        // We use zsh -l -c instead of directly
        // launching `npx`.
        //
        // Xcode-launched macOS apps may not
        // inherit the same PATH as Terminal.
        //
        // A login shell gives us a much better
        // chance of seeing the same node / npm /
        // npx environment that already works
        // in the user's Terminal.

        if let executableURL = runtime.executableURL {
            process.executableURL = executableURL
            process.arguments = [
                "--profile",
                "headless",
                task
            ]
        } else {
            process.executableURL = URL(fileURLWithPath: shellPath)
            let command =
                """
                "\(npxPath)" -y \(dshPackage) --profile headless "$COSMOS_DSH_TASK"
                """
            process.arguments = [
                "-l",
                "-c",
                command
            ]
        }


        // MARK: Environment

        var environment =
            ProcessInfo.processInfo
                .environment
            let existingPath =
                environment["PATH"] ?? ""

            environment["PATH"] =
                "\(nodeBinDirectory):\(existingPath)"

        environment[
            "COSMOS_DSH_TASK"
        ] = task

        environment[
            "DSH_HOME"
        ] = runtime.dshHomePath

        // Preserve the user's real HOME so
        // DeepSeek Harness can resolve paths
        // outside its explicit DSH_HOME.
        //
        // The Harness data and credentials store
        // are selected by DSH_HOME above.
        //
        // Cosmos OS does not rewrite these files.

        if environment["HOME"] == nil {

            environment["HOME"] =
                FileManager.default
                    .homeDirectoryForCurrentUser
                    .path
        }

        process.environment =
            environment


        // MARK: Launch

        do {
            try process.run()

        } catch {

            throw
                DeepSeekHarnessAdapterError
                .executionFailed(
                    exitCode: -1,
                    message:
                        """
                        无法启动 DeepSeek Harness。
                        \(error.localizedDescription)
                        """
                )
        }


        process.waitUntilExit()


        // MARK: Read Output

        let stdoutData =
            stdoutPipe
            .fileHandleForReading
            .readDataToEndOfFile()

        let stderrData =
            stderrPipe
            .fileHandleForReading
            .readDataToEndOfFile()


        let output =
            String(
                data: stdoutData,
                encoding: .utf8
            )
            ?? ""

        let errorOutput =
            String(
                data: stderrData,
                encoding: .utf8
            )
            ?? ""

        let exitCode =
            process.terminationStatus


        let result =
            DeepSeekHarnessExecutionResult(
                output:
                    output
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
                errorOutput:
                    errorOutput
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
                exitCode:
                    exitCode
            )


        // MARK: Validate

        guard exitCode == 0 else {

            let errorMessage =
                result.errorOutput.isEmpty
                ? result.output
                : result.errorOutput

            throw
                DeepSeekHarnessAdapterError
                .executionFailed(
                    exitCode: exitCode,
                    message:
                        errorMessage
                )
        }


        guard
            !result.output.isEmpty
        else {

            throw
                DeepSeekHarnessAdapterError
                .noOutput
        }


        return result
    }


    // MARK: - Runtime Log

    private func logRuntime() {
        let path = runtime.executableURL?.path ?? npxPath

        logger.notice(
            "当前使用 Runtime：\(self.runtime.source, privacy: .public)"
        )
        logger.notice("路径：\(path, privacy: .public)")
        logger.notice("版本：\(self.runtime.version, privacy: .public)")
        logger.notice(
            "DSH_HOME：\(self.runtime.dshHomePath, privacy: .public)"
        )
    }


    // MARK: - Task Package → DSH Text

    static func buildExecutionText(
        from taskPackage:
            ZhuowangAITaskPackage
    ) -> String {

        let context =
            taskPackage
            .contextReferences
            .map {
                "- \($0)"
            }
            .joined(
                separator: "\n"
            )

        let outputs =
            taskPackage
            .expectedOutputs
            .map {
                "- \($0)"
            }
            .joined(
                separator: "\n"
            )

        let resultDelivery =
            Self.resultDeliveryText(
                for: taskPackage
            )

        return """
        \(taskPackage.title)

        \(taskPackage.instruction)

        【参考上下文】
        \(context)

        【预期输出】
        \(outputs)

        \(resultDelivery)

        请只完成当前任务要求，并返回最终结果。
        """
    }


    private static func resultDeliveryText(
        for taskPackage: ZhuowangAITaskPackage
    ) -> String {

        if ZhuowangTaskExecutionSpecificationResolver.resolve(
            snapshot: taskPackage.executionSnapshot
        ) != nil {
            return """
            【结果回传约束】
            本次为自动结果回传，不提供正式 Workspace 保存路径。
            不要创建、修改、复制或管理任何正式 Artifact 文件。
            stdout 必须且只能包含完整 HTML 源码；不要返回文件路径或交付说明。
            """
        }

        return """
        【建议保存位置】
        \(taskPackage.destinationHint)
        """
    }
}
