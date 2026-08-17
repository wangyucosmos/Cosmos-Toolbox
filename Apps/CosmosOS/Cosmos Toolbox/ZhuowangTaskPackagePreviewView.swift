import SwiftUI
import AppKit

struct ZhuowangTaskPackagePreviewView: View {

    let taskPackage: ZhuowangAITaskPackage
    let provider: ZhuowangAIProvider?
    let connection: ZhuowangAIConnection?

    @Environment(\.dismiss)
    private var dismiss

    @State private var copied = false

    // MARK: - Execution State

    @State private var showExecutionResult = false

    @State private var executionState:
        ZhuowangAIExecutionViewState = .running

    @State private var executionResultText = ""

    @State private var executionErrorText = ""

    @State private var currentRevisionFeedback = ""


    var body: some View {

        VStack(spacing: 0) {

            header

            Divider()

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: CosmosDesign.spacingXL
                ) {

                    summaryCard

                    instructionSection

                    contextSection

                    outputSection

                    executionSection
                }
                .padding(
                    .horizontal,
                    CosmosDesign.pagePadding
                )
                .padding(
                    .vertical,
                    CosmosDesign.spacingXL
                )
                .frame(
                    maxWidth: 820,
                    alignment: .leading
                )
            }

            Divider()

            footer
        }
        .frame(
            minWidth: 780,
            minHeight: 720
        )
        .sheet(
            isPresented:
                $showExecutionResult
        ) {

            ZhuowangAIExecutionResultView(
                taskPackage:
                    taskPackage,
                provider:
                    provider,
                connection:
                    connection,
                resultText:
                    executionResultText,
                errorText:
                    executionErrorText,
                state:
                    executionState,
                onAdopt: {

                    showExecutionResult =
                        false

                    dismiss()
                },
                onRequestRevision: {
                    feedback in

                    runRevision(
                        feedback:
                            feedback
                    )
                },
                onRegenerate: {

                    runSelectedConnection()
                }
            )
        }
    }


    // MARK: - Header

    private var header: some View {

        HStack(
            spacing: CosmosDesign.spacingM
        ) {

            ZStack {

                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
                .fill(
                    Color.accentColor.opacity(0.09)
                )
                .frame(
                    width: 38,
                    height: 38
                )

                Image(
                    systemName: "doc.text.magnifyingglass"
                )
                .font(
                    .system(
                        size: 16,
                        weight: .medium
                    )
                )
                .foregroundStyle(.tint)
            }

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text("任务预览")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Task Package Preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("关闭") {
                dismiss()
            }
        }
        .padding(
            .horizontal,
            CosmosDesign.spacingL
        )
        .padding(
            .vertical,
            CosmosDesign.spacingM
        )
    }


    // MARK: - Summary

    private var summaryCard: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {

            HStack(
                alignment: .top,
                spacing: CosmosDesign.spacingL
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(taskPackage.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Cosmos OS AI Task Package")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let provider {

                    HStack(spacing: 7) {

                        Image(
                            systemName:
                                provider.kind.systemImage
                        )

                        Text(provider.name)
                            .fontWeight(.medium)
                    }
                    .font(.callout)
                    .padding(
                        .horizontal,
                        11
                    )
                    .padding(
                        .vertical,
                        7
                    )
                    .background(
                        Color.accentColor.opacity(0.08)
                    )
                    .clipShape(Capsule())
                }
            }

            Divider()

            HStack(
                spacing: CosmosDesign.spacingXL
            ) {

                summaryItem(
                    title: "工作流步骤",
                    value:
                        taskPackage
                        .destinationHint
                        .components(
                            separatedBy: "/"
                        )
                        .last
                        ?? "当前步骤"
                )

                summaryItem(
                    title: "执行 AI",
                    value:
                        provider?.name
                        ?? "未选择"
                )

                summaryItem(
                    title: "连接方式",
                    value:
                        connectionDisplayName
                )
            }
        }
        .padding(
            CosmosDesign.cardPadding
        )
        .background(.thinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusLarge,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusLarge,
                style: .continuous
            )
            .stroke(
                Color.primary.opacity(0.06),
                lineWidth: 1
            )
        }
    }


    // MARK: - Summary Item

    private func summaryItem(
        title: String,
        value: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 4
        ) {

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(2)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }


    // MARK: - Instruction

    private var instructionSection: some View {

        sectionCard(
            title: "任务正文",
            subtitle: "Instruction",
            icon: "text.alignleft"
        ) {

            Text(taskPackage.instruction)
                .font(
                    .system(
                        size: 13,
                        design: .monospaced
                    )
                )
                .textSelection(.enabled)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(14)
                .background(
                    Color.primary.opacity(0.025)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            CosmosDesign.cornerRadiusSmall,
                        style: .continuous
                    )
                )
        }
    }


    // MARK: - Context

    private var contextSection: some View {

        sectionCard(
            title: "参考上下文",
            subtitle: "Context",
            icon: "books.vertical"
        ) {

            VStack(
                alignment: .leading,
                spacing: 10
            ) {

                ForEach(
                    taskPackage.contextReferences,
                    id: \.self
                ) { reference in

                    HStack(
                        spacing: 9
                    ) {

                        Image(
                            systemName: "checkmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text(reference)
                            .font(.callout)
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
    }


    // MARK: - Outputs

    private var outputSection: some View {

        sectionCard(
            title: "预期输出",
            subtitle: "Expected Outputs",
            icon: "square.and.arrow.down"
        ) {

            VStack(
                alignment: .leading,
                spacing: 10
            ) {

                ForEach(
                    taskPackage.expectedOutputs,
                    id: \.self
                ) { output in

                    HStack(
                        spacing: 9
                    ) {

                        Circle()
                            .fill(
                                Color.accentColor.opacity(0.75)
                            )
                            .frame(
                                width: 5,
                                height: 5
                            )

                        Text(output)
                            .font(.callout)
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
    }


    // MARK: - Execution

    private var executionSection: some View {

        sectionCard(
            title: "执行方式",
            subtitle: "Execution",
            icon: "bolt.horizontal.circle"
        ) {

            VStack(
                alignment: .leading,
                spacing: CosmosDesign.spacingM
            ) {

                HStack {

                    Text("AI Provider")

                    Spacer()

                    Text(
                        provider?.name
                        ?? "未选择"
                    )
                    .fontWeight(.medium)
                }

                Divider()

                HStack {

                    Text("Connection")

                    Spacer()

                    Text(connectionDisplayName)
                        .fontWeight(.medium)
                }

                Divider()

                HStack {

                    Text("Execution Style")

                    Spacer()

                    Text(executionStyleText)
                        .fontWeight(.medium)
                }

                Divider()

                connectionNotice
            }
            .font(.callout)
        }
    }


    // MARK: - Connection Notice

    @ViewBuilder
    private var connectionNotice:
        some View {

        if connection == nil {

            Label(
                "当前还没有绑定具体 Connection。",
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

        } else if isDeepSeekHarnessConnection {

            Label(
                "该任务可以由 Cosmos OS 直接调用本机 DeepSeek Harness 执行，并在完成后自动返回结果。",
                systemImage:
                    "checkmark.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

        } else {

            Label(
                "当前连接已识别，但该执行器尚未接入自动执行。ChatGPT、Codex、Claude 等连接将在后续阶段接入。",
                systemImage:
                    "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }


    // MARK: - Section Card

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {

            HStack(
                spacing: 8
            ) {

                Image(systemName: icon)
                    .foregroundStyle(.secondary)

                VStack(
                    alignment: .leading,
                    spacing: 1
                ) {

                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            content()
        }
        .padding(
            CosmosDesign.spacingL
        )
        .background(
            Color.primary.opacity(0.015)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusLarge,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusLarge,
                style: .continuous
            )
            .stroke(
                Color.primary.opacity(0.055),
                lineWidth: 1
            )
        }
    }


    // MARK: - Footer

    private var footer: some View {

        HStack(
            spacing: CosmosDesign.spacingM
        ) {

            Button {

                copyTaskPackage()

            } label: {

                Label(
                    copied
                    ? "已复制"
                    : "复制任务",
                    systemImage:
                        copied
                        ? "checkmark"
                        : "doc.on.doc"
                )
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("返回") {
                dismiss()
            }

            Button {

                runSelectedConnection()

            } label: {

                Label(
                    confirmationButtonTitle,
                    systemImage:
                        "arrow.right"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                !canContinue
            )
        }
        .padding(
            .horizontal,
            CosmosDesign.spacingL
        )
        .padding(
            .vertical,
            CosmosDesign.spacingM
        )
    }


    // MARK: - Execute Selected Connection

    private func runSelectedConnection() {

        guard
            provider != nil,
            connection != nil
        else {
            return
        }

        executionResultText = ""
        executionErrorText = ""
        currentRevisionFeedback = ""
        executionState = .running
        showExecutionResult = true

        guard isDeepSeekHarnessConnection else {

            executionState = .failed
            executionErrorText =
                """
                当前 Connection 已经被 Cosmos OS 识别，但尚未接入自动执行器。

                当前连接：\(connectionDisplayName)

                目前第一条已经接通的自动执行链是 DeepSeek Harness。
                ChatGPT、Codex、Claude Work、Claude Code 和 Figma 会在后续阶段分别接入适合它们的执行方式。
                """

            return
        }

        Task {

            do {

                let result =
                    try await
                    DeepSeekHarnessAdapter
                    .shared
                    .execute(
                        taskPackage:
                            taskPackage
                    )

                await MainActor.run {

                    executionResultText =
                        result.output

                    executionErrorText =
                        result.errorOutput

                    executionState =
                        .succeeded
                }

            } catch {

                await MainActor.run {

                    executionResultText = ""

                    executionErrorText =
                        error.localizedDescription

                    executionState =
                        .failed
                }
            }
        }
    }


    // MARK: - Revision Execution

    private func runRevision(
        feedback: String
    ) {

        let cleanFeedback =
            feedback
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard
            !cleanFeedback.isEmpty
        else {
            return
        }

        guard isDeepSeekHarnessConnection else {

            executionState = .failed
            executionErrorText =
                "当前连接暂不支持自动修改任务。"

            return
        }

        currentRevisionFeedback =
            cleanFeedback

        let previousResult =
            executionResultText
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        executionState = .running
        executionErrorText = ""

        let revisionTask =
            """
            \(taskPackage.title)

            你正在修改上一轮 AI 生成结果。

            【原始任务】
            \(taskPackage.instruction)

            【上一轮结果】
            \(previousResult.isEmpty ? "暂无上一轮可用结果。" : previousResult)

            【用户修改意见】
            \(cleanFeedback)

            【参考上下文】
            \(taskPackage.contextReferences.joined(separator: "\n"))

            【预期输出】
            \(taskPackage.expectedOutputs.joined(separator: "\n"))

            请严格根据用户修改意见重新生成完整结果。
            不要只解释如何修改，直接输出修改后的完整版本。
            """

        Task {

            do {

                let result =
                    try await
                    DeepSeekHarnessAdapter
                    .shared
                    .execute(
                        task:
                            revisionTask
                    )

                await MainActor.run {

                    executionResultText =
                        result.output

                    executionErrorText =
                        result.errorOutput

                    executionState =
                        .succeeded
                }

            } catch {

                await MainActor.run {

                    executionErrorText =
                        error.localizedDescription

                    executionState =
                        .failed
                }
            }
        }
    }


    // MARK: - Copy

    private func copyTaskPackage() {

        let text =
            """
            \(taskPackage.title)

            \(taskPackage.instruction)

            【参考上下文】
            \(taskPackage.contextReferences.joined(separator: "\n"))

            【预期输出】
            \(taskPackage.expectedOutputs.joined(separator: "\n"))

            【建议保存位置】
            \(taskPackage.destinationHint)
            """

        NSPasteboard.general.clearContents()

        NSPasteboard.general.setString(
            text,
            forType: .string
        )

        copied = true

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1.5
        ) {
            copied = false
        }
    }


    // MARK: - Execution Helpers

    private var isDeepSeekHarnessConnection:
        Bool {

        if provider?.kind
            == .deepSeekHarness {

            return true
        }

        if connection?
            .adapterIdentifier
            == "deepseek-harness" {

            return true
        }

        return false
    }


    private var canContinue: Bool {

        guard
            provider != nil,
            connection != nil
        else {
            return false
        }

        return true
    }


    private var confirmationButtonTitle:
        String {

        if isDeepSeekHarnessConnection {
            return "确认并执行"
        }

        return "确认并继续"
    }


    // MARK: - Connection Text

    private var connectionDisplayName:
        String {

        guard let connection else {
            return "待选择"
        }

        return "\(connection.name) · \(connection.mode.title)"
    }


    private var executionStyleText:
        String {

        guard let connection else {
            return "待确定"
        }

        switch connection.executionStyle {

        case .direct:
            return "直接执行"

        case .localProcess:
            return "本地进程"

        case .assistedManual:
            return "辅助式手动执行"

        case .externalTool:
            return "外部工具"

        case .custom:
            return "自定义"
        }
    }
}

