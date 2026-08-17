import Foundation

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

    private init() { }


    // MARK: - Configuration

    private let shellPath =
        "/bin/zsh"

    private let npxPath =
        "/Users/rainiesmac-15/.local/bin/npx"

    private let nodeBinDirectory =
        "/Users/rainiesmac-15/.local/bin"

    private let dshPackage =
        "@deepseek-ai/dsh@0.1.0-rc.6"


    // MARK: - Execute Task Package

    func execute(
        taskPackage: ZhuowangAITaskPackage
    ) async throws
        -> DeepSeekHarnessExecutionResult {

        let taskText =
            buildExecutionText(
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

        process.executableURL =
            URL(
                fileURLWithPath:
                    shellPath
            )

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

            let command =
                """
                "\(npxPath)" -y \(dshPackage) --profile headless "$COSMOS_DSH_TASK"
                """

        process.arguments = [
            "-l",
            "-c",
            command
        ]


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

        // Preserve the user's real HOME so
        // DeepSeek Harness continues reading:
        //
        // ~/.dsh
        // ~/.dsh/.credentials.yaml
        // ~/.dsh/settings.yaml
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


    // MARK: - Task Package → DSH Text

    private func buildExecutionText(
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

        return """
        \(taskPackage.title)

        \(taskPackage.instruction)

        【参考上下文】
        \(context)

        【预期输出】
        \(outputs)

        【建议保存位置】
        \(taskPackage.destinationHint)

        请只完成当前任务要求，并返回最终结果。
        """
    }
}
#if DEBUG

extension DeepSeekHarnessAdapter {

    static func runSelfTest() async {
        do {
            let result =
                try await DeepSeekHarnessAdapter.shared.execute(
                    task: "只回复这一句话：Cosmos Adapter OK"
                )

            print("=== Cosmos DSH Adapter Self Test ===")
            print("Exit Code:", result.exitCode)
            print("Output:", result.output)

            if !result.errorOutput.isEmpty {
                print("Error Output:", result.errorOutput)
            }

            print("===================================")

        } catch {
            print("=== Cosmos DSH Adapter Self Test FAILED ===")
            print(error.localizedDescription)
            print("==========================================")
        }
    }
}

#endif
