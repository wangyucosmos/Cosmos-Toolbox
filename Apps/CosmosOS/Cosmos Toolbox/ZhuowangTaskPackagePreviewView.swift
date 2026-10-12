import SwiftUI
import AppKit

struct ZhuowangTaskPackagePreviewView: View {

    let taskPackage: ZhuowangAITaskPackage
    let provider: ZhuowangAIProvider?
    let connection: ZhuowangAIConnection?
    let tool: ZhuowangExternalToolIntegration?
    let route: ZhuowangAgentToolRoute?

    let onAdoptResult: (
        String,
        ZhuowangWorkflowExecutionResult?
    ) -> ZhuowangArtifactAdoptionPresentationResult

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

    @State private var workflowExecutionResult:
        ZhuowangWorkflowExecutionResult?

    @State private var artifactDraft:
        ZhuowangArtifactDraft?


    var body: some View {
        NavigationStack {


            VStack(spacing: 0) {

                ScrollView {

                    VStack(
                        alignment: .leading,
                        spacing: CosmosDesign.spacingL
                    ) {

                        summaryCard
                            .cosmosScrollReveal()

                        executionSection
                            .cosmosScrollReveal()

                        instructionSection
                            .cosmosScrollReveal()

                        ViewThatFits(in: .horizontal) {

                            HStack(
                                alignment: .top,
                                spacing: CosmosDesign.spacingL
                            ) {
                                contextSection
                                outputSection
                            }

                            VStack(
                                alignment: .leading,
                                spacing: CosmosDesign.spacingL
                            ) {
                                contextSection
                                outputSection
                            }
                        }
                        .cosmosScrollReveal()
                    }
                    .padding(
                        .horizontal,
                        CosmosDesign.spacingXL + 4
                    )
                    .padding(
                        .vertical,
                        CosmosDesign.spacingXL
                    )
                    .frame(
                        maxWidth: 860
                    )
                    .frame(maxWidth: .infinity)
                }.scrollEdgeEffectStyle(.soft, for: .top)
            }
            .frame(
                minWidth: 780,
                minHeight: 720
            )
            .background(Color(nsColor: .windowBackgroundColor))
            .modifier(CosmosMotionPolicy())
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
                    artifactDraft:
                        artifactDraft,
                    resultText:
                        executionResultText,
                    errorText:
                        executionErrorText,
                    state:
                        executionState,
                    onAdopt: {

                        let result = onAdoptResult(
                            executionResultText,
                            workflowExecutionResult
                        )

                        if result.succeeded {
                            showExecutionResult = false
                            dismiss()
                        }

                        return result
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

    .navigationTitle("任务预览")
    .toolbar {
    ToolbarItem(placement: .cancellationAction) { Button("返回") { dismiss() } }
    ToolbarItem(placement: .primaryAction) {
        Button(copied ? "已复制" : "复制任务", systemImage: copied ? "checkmark" : "doc.on.doc") { copyTaskPackage() }
    }
    ToolbarItem(placement: .confirmationAction) {
        Button(confirmationButtonTitle, systemImage: "arrow.right") { runSelectedConnection() }
            .buttonStyle(.glassProminent).disabled(!canContinue)
    }
    }
        }
    }


    // MARK: - Header


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
                        .font(.system(size: 20, weight: .semibold))

                    Text("Cosmos OS AI Task Package")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {

                    CampaignUIChip(
                        caption: "AI",
                        value: provider?.name,
                        icon: provider?.kind.systemImage ?? "sparkles"
                    )

                    if !(taskPackage.executionSnapshot == nil && tool == nil) {
                        CampaignUIChip(
                            caption: "工具",
                            value: tool?.name,
                            icon: "wrench.and.screwdriver"
                        )
                    }
                }
            }

            Divider()

            HStack(
                spacing: CosmosDesign.spacingXL
            ) {

                CampaignUIKeyValue(
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

                CampaignUIKeyValue(
                    title: "执行 AI",
                    value:
                        provider?.name
                        ?? "未选择"
                )

                CampaignUIKeyValue(
                    title: "连接方式",
                    value:
                        connectionDisplayName
                )
            }
        }
        .campaignUICardSurface()
    }


    // MARK: - Instruction

    private var instructionSection: some View {

        CampaignUICard(
            title: "任务正文",
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
                    Color.primary.opacity(0.025),
                    in: RoundedRectangle(
                        cornerRadius:
                            CosmosDesign.cornerRadiusSmall,
                        style: .continuous
                    )
                )
        }
    }


    // MARK: - Context

    private var contextSection: some View {

        CampaignUICard(
            title: "参考上下文",
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
                        alignment: .firstTextBaseline,
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
        .frame(minWidth: 300)
    }


    // MARK: - Outputs

    private var outputSection: some View {

        CampaignUICard(
            title: "预期输出",
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
                        alignment: .firstTextBaseline,
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
        .frame(minWidth: 300)
    }


    // MARK: - Execution

    private var executionSection: some View {

        CampaignUICard(
            title: "执行方式",
            icon: "bolt.horizontal.circle",
            info: "AI Provider 负责推理与生成，Tool 负责产出或操作外部成果，两者是独立的。Connection 与 Route 决定任务如何送达执行器。"
        ) {

            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                executionRow("AI Provider", provider?.name ?? "未选择")

                executionRow("Tool", tool?.name ?? "未选择")

                executionRow("Connection", connectionDisplayName)

                executionRow("Capability", capabilityDisplayName)

                executionRow("Route", routeDisplayName)

                if let profile =
                    taskPackage.executionSnapshot?
                        .prototypeExecutionProfile {

                    executionRow("Prototype Fidelity", profile.fidelity.title)

                    executionRow("Prototype Style", profile.style.title)
                }

                executionRow("Execution Style", executionStyleText)
            }
            .font(.callout)

            connectionNotice
        }
    }

    private func executionRow(
        _ title: String,
        _ value: String
    ) -> some View {

        HStack(alignment: .firstTextBaseline) {

            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.6)
        }
    }


    // MARK: - Connection Notice

    @ViewBuilder
    private var connectionNotice:
        some View {

        if connection == nil {

            CampaignUINotice(
                text: "当前还没有绑定具体 Connection。",
                icon: "info.circle"
            )

        } else if taskPackage.executionSnapshot != nil {

            CampaignUINotice(
                text: "Provider、Connection、Tool、Route、Capability、Fidelity 与 Style 已冻结为本次执行快照，将通过 Coordinator 和 Adapter Registry 执行。",
                icon: "checkmark.shield",
                tone: .success
            )

        } else if isDeepSeekHarnessConnection {

            CampaignUINotice(
                text: "该任务可以由 Cosmos OS 直接调用本机 DeepSeek Harness 执行，并在完成后自动返回结果。",
                icon: "checkmark.circle",
                tone: .success
            )

        } else {

            CampaignUINotice(
                text: "当前连接已识别，但该执行器尚未接入自动执行。ChatGPT、Codex、Claude 等连接将在后续阶段接入。",
                icon: "info.circle"
            )
        }
    }


    // MARK: - Footer


    // MARK: - Execute Selected Connection

    private func runSelectedConnection() {

        guard
            provider != nil
        else {
            return
        }

        if connection == nil
            && !isDeepSeekHarnessConnection {

            return
        }

        executionResultText = ""
        executionErrorText = ""
        currentRevisionFeedback = ""
        workflowExecutionResult = nil
        artifactDraft = nil
        executionState = .running
        showExecutionResult = true

        if taskPackage.executionSnapshot != nil {

            Task {
                do {
                    let result = try await
                        ZhuowangWorkflowExecutionCoordinator()
                        .execute(taskPackage: taskPackage)

                    await MainActor.run {
                        workflowExecutionResult = result
                        artifactDraft = result.artifactDraft
                        executionResultText =
                            result.artifactDraft.content
                        executionState = .succeeded
                    }
                } catch {
                    await MainActor.run {
                        workflowExecutionResult = nil
                        artifactDraft = nil
                        executionResultText = ""
                        executionErrorText =
                            error.localizedDescription
                        executionState = .failed
                    }
                }
            }

            return
        }

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

                    artifactDraft =
                        ZhuowangCustomerServiceArtifact
                        .makeDraft(
                            taskPackage: taskPackage,
                            outputText: result.output
                        )

                    executionErrorText =
                        result.errorOutput

                    executionState =
                        .succeeded
                }

            } catch {

                await MainActor.run {

                    executionResultText = ""
                    artifactDraft = nil

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

                if taskPackage.executionSnapshot != nil {

                    var revisionPackage = taskPackage
                    revisionPackage.instruction = revisionTask

                    let result = try await
                        ZhuowangWorkflowExecutionCoordinator()
                        .execute(taskPackage: revisionPackage)

                    await MainActor.run {
                        workflowExecutionResult = result
                        artifactDraft = result.artifactDraft
                        executionResultText =
                            result.artifactDraft.content
                        executionErrorText = ""
                        executionState = .succeeded
                    }

                    return
                }

                let result = try await DeepSeekHarnessAdapter
                    .shared
                    .executeRevision(
                        taskPackage: taskPackage,
                        revisionTask: revisionTask
                    )

                await MainActor.run {

                    executionResultText =
                        result.output

                    workflowExecutionResult = nil
                    artifactDraft = taskPackage.workflowStepKind == .customerService
                        ? ZhuowangCustomerServiceArtifact.makeDraft(
                            taskPackage: taskPackage,
                            outputText: result.output
                        ) : nil

                    executionErrorText =
                        result.errorOutput

                    executionState =
                        .succeeded
                }

            } catch {

                await MainActor.run {

                    executionErrorText =
                        error.localizedDescription

                    artifactDraft = nil

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

        guard provider != nil else {
            return false
        }

        // DeepSeek Harness is already a direct local executor.
        // A temporarily missing rehydrated Connection must not
        // force the user to re-select the AI.
        if isDeepSeekHarnessConnection {
            return true
        }

        return connection != nil
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

            if provider?.kind
                == .deepSeekHarness {

                return "DeepSeek Harness · 本地 Agent"
            }

            return "待选择"
        }

        return "\(connection.name) · \(connection.mode.title)"
    }


    private var capabilityDisplayName: String {

        guard let capability =
            taskPackage.executionSnapshot?.capability
        else {
            return "未冻结"
        }

        return "\(capability.rawValue)（\(capability.title)）"
    }


    private var routeDisplayName: String {

        guard let route else {
            return "未冻结"
        }

        if let connection,
           let tool {
            return "\(connection.name) → \(tool.name)"
        }

        return route.adapterIdentifier
            ?? route.id.uuidString
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
