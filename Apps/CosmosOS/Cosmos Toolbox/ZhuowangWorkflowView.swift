import SwiftUI

private struct ZhuowangTaskPreviewContext:
    Identifiable {

    let id = UUID()

    let taskPackage:
        ZhuowangAITaskPackage

    let provider:
        ZhuowangAIProvider?

    let connection:
        ZhuowangAIConnection?

    let tool:
        ZhuowangExternalToolIntegration?

    let route:
        ZhuowangAgentToolRoute?

    let workflowID: UUID
    let stepID: UUID
}

/// A request from outside the Workflow tab to select one step.
/// `serial` makes two requests for the same step distinguishable.
struct ZhuowangWorkflowFocusRequest: Equatable {
    let stepID: UUID
    let serial: Int
}

/// Read-only lookups into the AI connection / tool registry. The live view
/// reads them from `ZhuowangAIConnectionStore`; tests and fixtures pass
/// synthetic values so rendering never touches the production registry.
struct ZhuowangWorkflowConnections {
    var recommendedConnection: (UUID) -> ZhuowangAIConnection?
    var route: (UUID, UUID) -> ZhuowangAgentToolRoute?
    var availableTools: (ZhuowangWorkflowCapability) -> [ZhuowangExternalToolIntegration]
    var toolIntegration: (UUID) -> ZhuowangExternalToolIntegration?

    static func live(
        _ store: ZhuowangAIConnectionStore
    ) -> ZhuowangWorkflowConnections {
        ZhuowangWorkflowConnections(
            recommendedConnection: { store.recommendedConnection(forProviderID: $0) },
            route: { store.route(connectionID: $0, toolIntegrationID: $1) },
            availableTools: { store.availableTools(for: $0) },
            toolIntegration: { store.toolIntegration(id: $0) }
        )
    }
}

/// The Workflow tab. Without injected `connections` it owns the live
/// `ZhuowangAIConnectionStore`, exactly as before.
struct ZhuowangWorkflowView: View {

    @ObservedObject var store: ZhuowangWorkflowStore

    let campaign: ZhuowangCampaign
    let province: ZhuowangProvince?
    let module: ZhuowangModule?

    /// Selects a step when the tab opens from the overview "下一步" button.
    var focusRequest: ZhuowangWorkflowFocusRequest?

    /// Opens the artifact window owned by the Campaign window.
    var onOpenArtifact: (ZhuowangArtifact) -> Void = { _ in }

    /// Synthetic registry for tests / fixtures; `nil` uses the live store.
    var connections: ZhuowangWorkflowConnections?

    var body: some View {
        if let connections {
            ZhuowangWorkflowContent(
                store: store, campaign: campaign, province: province, module: module,
                focusRequest: focusRequest, onOpenArtifact: onOpenArtifact,
                connections: connections
            )
        } else {
            ZhuowangWorkflowLiveHost(
                store: store, campaign: campaign, province: province, module: module,
                focusRequest: focusRequest, onOpenArtifact: onOpenArtifact
            )
        }
    }
}

private struct ZhuowangWorkflowLiveHost: View {

    @ObservedObject var store: ZhuowangWorkflowStore
    let campaign: ZhuowangCampaign
    let province: ZhuowangProvince?
    let module: ZhuowangModule?
    let focusRequest: ZhuowangWorkflowFocusRequest?
    let onOpenArtifact: (ZhuowangArtifact) -> Void

    @StateObject
    private var connectionStore =
        ZhuowangAIConnectionStore()

    var body: some View {
        ZhuowangWorkflowContent(
            store: store, campaign: campaign, province: province, module: module,
            focusRequest: focusRequest, onOpenArtifact: onOpenArtifact,
            connections: .live(connectionStore)
        )
    }
}

struct ZhuowangWorkflowContent: View {

    @ObservedObject var store: ZhuowangWorkflowStore

    let campaign: ZhuowangCampaign
    let province: ZhuowangProvince?
    let module: ZhuowangModule?
    let focusRequest: ZhuowangWorkflowFocusRequest?
    let onOpenArtifact: (ZhuowangArtifact) -> Void
    let connections: ZhuowangWorkflowConnections

    @State private var selectedStepID: UUID?

    @State
    private var previewContext:
        ZhuowangTaskPreviewContext?

    @State private var step06ProviderSession =
        ZhuowangStep06ProviderSession()

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingL
        ) {

            if let workflow {

                let steps = ZhuowangWorkflowUIModel.enabledSteps(in: workflow)

                workflowHeader(workflow, steps)

                ViewThatFits(in: .horizontal) {

                    HStack(
                        alignment: .top,
                        spacing: CosmosDesign.spacingXL
                    ) {
                        timelineColumn(workflow, steps)
                            .frame(width: 372)

                        detailColumn(workflow, steps)
                            .frame(minWidth: 430, maxWidth: .infinity)
                    }

                    VStack(
                        alignment: .leading,
                        spacing: CosmosDesign.spacingXL
                    ) {
                        timelineColumn(workflow, steps)

                        detailColumn(workflow, steps)
                    }
                }

            } else {
                loadingState
            }
        }
        .onAppear {
            ensureWorkflowExists()
            applyFocus()
        }
        .onChange(of: focusRequest) {
            applyFocus()
        }
        .sheet(item: $previewContext) {
            context in

            ZhuowangTaskPackagePreviewView(
                taskPackage:
                    context.taskPackage,
                provider:
                    context.provider,
                connection:
                    context.connection,
                tool:
                    context.tool,
                route:
                    context.route,
                onAdoptResult: {
                    resultText,
                    executionResult in

                    adoptPreviewResult(
                        context:
                            context,
                        resultText:
                            resultText,
                        executionResult:
                            executionResult
                    )
                }
            )
        }
    }


    private func applyFocus() {
        if let focusRequest {
            selectedStepID = focusRequest.stepID
        }
    }

    /// The explicit selection, else the next open step, else the first step.
    private func effectiveStep(
        in steps: [ZhuowangWorkflowStep]
    ) -> ZhuowangWorkflowStep? {
        ZhuowangWorkflowUIModel.effectiveStep(selectedID: selectedStepID, in: steps)
    }


    // MARK: - Header

    private func workflowHeader(
        _ workflow: ZhuowangCampaignWorkflow,
        _ steps: [ZhuowangWorkflowStep]
    ) -> some View {

        HStack(
            alignment: .center,
            spacing: CosmosDesign.spacingM
        ) {

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                HStack(spacing: 6) {

                    Text("AI Workflow")
                        .font(CosmosDesign.font(.section))

                    CosmosInfoButton(
                        text: "为每一个工作步骤选择不同的 AI，并由你决定什么时候生成、修改和确认。AI 不会自动进入下一步；确认一步后才会解锁后续步骤。"
                    )
                }

                Text("为每一步选择 AI，由你决定何时生成、修改和确认")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            CampaignUIChip(
                caption: "已选择 AI",
                value: "\(configuredProviderCount(in: workflow)) / \(steps.count)",
                icon: "sparkles"
            )

            CampaignUIChip(
                caption: "工作产物",
                value: "\(workflow.artifacts.count)",
                icon: "doc.on.doc"
            )
        }
    }


    // MARK: - Timeline

    private func timelineColumn(
        _ workflow: ZhuowangCampaignWorkflow,
        _ steps: [ZhuowangWorkflowStep]
    ) -> some View {

        let items = ZhuowangWorkflowUIModel.timelineItems(
            steps: steps,
            artifacts: workflow.artifacts,
            providerName: { selectedProvider(for: $0)?.name },
            toolName: { selectedTool(for: $0)?.name },
            canAct: { step in
                isDone(step)
                    ? ZhuowangWorkflowUIModel.adoptedArtifact(
                        for: step,
                        in: workflow.artifacts
                    ) != nil
                    : canPrepareTask(
                        workflowID: workflow.id,
                        step: step
                    )
            },
            actionTitle: { step in
                switch step.status {
                case .ready, .needsRevision, .failed, .waitingForApproval:
                    return "准备任务"
                case .approved, .completed, .skipped:
                    return ZhuowangWorkflowUIModel.adoptedArtifact(
                        for: step,
                        in: workflow.artifacts
                    ) == nil ? nil : "查看产物"
                case .notStarted, .running:
                    return nil
                }
            }
        )

        return CampaignUITimeline(
            items: items,
            selection: Binding(
                get: { effectiveStep(in: steps)?.id },
                set: { newValue in
                    withAnimation(CosmosDesign.motion) {
                        selectedStepID = newValue
                    }
                }
            ),
            onAction: { stepID in
                guard let step = steps.first(where: { $0.id == stepID }) else {
                    return
                }

                selectedStepID = stepID

                if isDone(step) {
                    if let artifact = ZhuowangWorkflowUIModel.adoptedArtifact(
                        for: step,
                        in: workflow.artifacts
                    ) {
                        onOpenArtifact(artifact)
                    }
                } else {
                    prepareTask(workflow: workflow, step: step)
                }
            }
        )
    }

    private func isDone(_ step: ZhuowangWorkflowStep) -> Bool {
        ZhuowangWorkflowUIModel.doneStatuses.contains(step.status)
    }


    // MARK: - Step Detail

    @ViewBuilder
    private func detailColumn(
        _ workflow: ZhuowangCampaignWorkflow,
        _ steps: [ZhuowangWorkflowStep]
    ) -> some View {

        if let step = effectiveStep(in: steps) {

            VStack(
                alignment: .leading,
                spacing: CosmosDesign.spacingM
            ) {

                stepHeaderCard(step, steps)

                executionCard(workflow: workflow, step: step)

                adoptedArtifactCard(workflow: workflow, step: step)
            }
            .id(step.id)
            .transition(.opacity)

        } else {

            CosmosEmptyState(
                icon: "list.number",
                title: "没有已启用的步骤"
            )
            .campaignUICardSurface()
        }
    }

    private func stepHeaderCard(
        _ step: ZhuowangWorkflowStep,
        _ steps: [ZhuowangWorkflowStep]
    ) -> some View {

        let look = ZhuowangWorkflowUIModel.presentation(for: step.status)
        let position = (steps.firstIndex { $0.id == step.id } ?? 0) + 1

        return VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {

            HStack(spacing: CosmosDesign.spacingM) {

                Text(String(format: "%02d", position))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(look.tone.color)
                    .frame(width: 40, height: 40)
                    .background(
                        look.tone.color.opacity(0.13),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title)
                        .font(.system(size: 18, weight: .semibold))

                    if !step.englishTitle.isEmpty {
                        Text(step.englishTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                CampaignUIStatusPill(
                    text: step.status.title,
                    icon: look.icon,
                    tone: look.tone
                )
            }

            Text(stepDescription(step))
                .font(CosmosDesign.font(.body))
                .foregroundStyle(.secondary)

            if let reason = ZhuowangWorkflowUIModel.lockedReason(for: step, in: steps) {
                CampaignUINotice(
                    text: reason + "。上一步确认后会自动解锁。",
                    icon: "lock"
                )
            }
        }
        .campaignUICardSurface()
    }


    // MARK: Execution card

    private func executionCard(
        workflow: ZhuowangCampaignWorkflow,
        step: ZhuowangWorkflowStep
    ) -> some View {

        CampaignUICard(
            title: "执行配置",
            icon: "slider.horizontal.3",
            info: "AI Provider 负责推理与生成；Tool 负责产出或操作外部成果（例如 HTML 原型、Figma）。两者独立选择，原型步骤不绑定具体工具。"
        ) {

            VStack(alignment: .leading, spacing: 10) {

                configRow("执行 AI") {
                    HStack(spacing: 6) {
                        providerPicker(workflow: workflow, step: step)

                        if step.kind == .customerService {
                            CosmosInfoButton(
                                text: "本步骤的 AI 选择在采用结果之前只在本次会话内有效，不会写入 Workflow；采用结果时才会记录所用的 AI。"
                            )
                        }
                    }
                }

                configRow("使用工具") {
                    if step.requiredCapabilities.isEmpty {
                        Text(selectedToolSummary(for: step))
                            .font(.callout)
                    } else {
                        toolPicker(workflow: workflow, step: step)
                    }
                }

                configRow("所需能力") {
                    Text(capabilitySummary(for: step))
                        .font(.callout)
                }

                configRow("执行方式") {
                    Text(executionModeText(for: step))
                        .font(.callout)
                }

                configRow("人工确认") {
                    Label(
                        step.requiresApproval
                        ? "需要你的确认"
                        : "无需确认",
                        systemImage:
                            step.requiresApproval
                            ? "person.crop.circle.badge.checkmark"
                            : "bolt.circle"
                    )
                    .font(.callout)
                }

                if step.requiredCapabilities.contains(.prototypeDesign) {
                    prototypeExecutionProfileControls(
                        workflow: workflow,
                        step: step
                    )
                }
            }

            Divider()

            HStack(spacing: CosmosDesign.spacingM) {

                if selectedProvider(for: step) == nil {

                    Label(
                        "先选择这一环节使用的 AI",
                        systemImage:
                            "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                } else {

                    Label(
                        "AI 已选择，后续可接入实际执行器",
                        systemImage:
                            "checkmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button {

                    prepareTask(
                        workflow: workflow,
                        step: step
                    )

                } label: {

                    Label(
                        "准备任务",
                        systemImage:
                            "arrow.right.circle"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    !canPrepareTask(
                        workflowID: workflow.id,
                        step: step
                    )
                )
            }
        }
    }

    private func configRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        HStack(alignment: .center, spacing: CosmosDesign.spacingM) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            content()

            Spacer(minLength: 0)
        }
        .frame(minHeight: 26)
    }


    // MARK: Adopted artifact card

    private func adoptedArtifactCard(
        workflow: ZhuowangCampaignWorkflow,
        step: ZhuowangWorkflowStep
    ) -> some View {

        let adopted = workflow.artifacts
            .filter { $0.stepID == step.id && $0.isApprovedVersion }
            .sorted { $0.updatedAt > $1.updatedAt }

        return CampaignUICard(
            title: "当前采用产物",
            icon: "checkmark.seal"
        ) {

            if adopted.isEmpty {

                Text("这一步还没有采用的产物。采用 AI 结果后会出现在这里，并解锁下一步。")
                    .font(CosmosDesign.font(.body))
                    .foregroundStyle(.secondary)

            } else {

                VStack(spacing: 0) {

                    ForEach(Array(adopted.enumerated()), id: \.element.id) { index, artifact in

                        let versionCount = workflow.artifacts
                            .filter { $0.versionGroupKey == artifact.versionGroupKey }
                            .count

                        Button {
                            onOpenArtifact(artifact)
                        } label: {
                            HStack(spacing: 10) {

                                Image(systemName: CampaignUIFormat.artifactIcon(artifact.type))
                                    .frame(width: 22)
                                    .foregroundStyle(.tint)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artifact.name).lineLimit(1)
                                    Text(
                                        versionCount > 1
                                        ? "\(artifact.type.title) · 共 \(versionCount) 个版本"
                                        : artifact.type.title
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 6)

                                CampaignUIVersionBadge(
                                    version: artifact.version,
                                    isCurrent: true
                                )

                                CampaignUIFilePill(
                                    state: artifactFileExists(artifact) ? .present : .missing
                                )

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("查看工作产物")

                        if index < adopted.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func artifactFileExists(
        _ artifact: ZhuowangArtifact
    ) -> Bool {

        let path = artifact.location
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !path.isEmpty else {
            return false
        }

        return store.workspaceFileManager.fileExists(atPath: path)
    }


    // MARK: - Prototype Execution Profile

    private func prototypeExecutionProfileControls(
        workflow: ZhuowangCampaignWorkflow,
        step: ZhuowangWorkflowStep
    ) -> some View {
        let profile = step.prototypeExecutionProfile.normalized

        return VStack(alignment: .leading, spacing: 10) {
            configRow("原型保真度") {
                Menu(profile.fidelity.title) {
                    ForEach(ZhuowangPrototypeFidelity.allCases) { fidelity in
                        Button(fidelity.title) {
                            let supportedStyles =
                                ZhuowangPrototypeExecutionProfile
                                    .supportedStyles(for: fidelity)
                            let style = supportedStyles.contains(profile.style)
                                ? profile.style
                                : ZhuowangPrototypeExecutionProfile
                                    .recommendedStyle(for: fidelity)

                            store.selectPrototypeExecutionProfile(
                                workflowID: workflow.id,
                                stepID: step.id,
                                profile: ZhuowangPrototypeExecutionProfile(
                                    fidelity: fidelity,
                                    style: style
                                )
                            )
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            configRow("原型风格") {
                Menu(profile.style.title) {
                    ForEach(
                        ZhuowangPrototypeExecutionProfile
                            .supportedStyles(for: profile.fidelity)
                    ) { style in
                        Button(style.title) {
                            store.selectPrototypeExecutionProfile(
                                workflowID: workflow.id,
                                stepID: step.id,
                                profile: ZhuowangPrototypeExecutionProfile(
                                    fidelity: profile.fidelity,
                                    style: style
                                )
                            )
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }


    // MARK: - Pickers

    private func pickerLabel(
        icon: String,
        title: String,
        detail: String? = nil
    ) -> some View {

        HStack(spacing: 8) {

            Image(systemName: icon)

            Text(title)
                .lineLimit(1)

            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(
                cornerRadius: CosmosDesign.cornerRadiusSmall,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: CosmosDesign.cornerRadiusSmall,
                style: .continuous
            )
            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func toolPicker(
        workflow: ZhuowangCampaignWorkflow,
        step: ZhuowangWorkflowStep
    ) -> some View {

        Menu {

            // 下一阶段直接读取 AIConnectionStore 的 Tool Registry。
            // 当前先使用已注册工具作为展示入口。
            ForEach(
                availableTools(
                    for: step
                )
            ) { tool in

                Button {

                    store.selectTools(
                        workflowID: workflow.id,
                        stepID: step.id,
                        toolIDs: [tool.id]
                    )

                } label: {

                    Label(
                        tool.name,
                        systemImage:
                            "wrench.and.screwdriver"
                    )
                }
            }

        } label: {

            pickerLabel(
                icon: "wrench.and.screwdriver",
                title: selectedToolSummary(for: step)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func providerPicker(
        workflow: ZhuowangCampaignWorkflow,
        step: ZhuowangWorkflowStep
    ) -> some View {

        Menu {

            Button {

                if step.kind == .customerService {
                    step06ProviderSession.select(nil, for: step.id)
                } else {
                    store.selectProvider(
                        workflowID: workflow.id,
                        stepID: step.id,
                        providerID: nil
                    )
                }

            } label: {

                Label(
                    "暂不选择",
                    systemImage:
                        "minus.circle"
                )
            }

            Divider()

            ForEach(
                store
                    .visibleProviders()
            ) { provider in

                Button {

                    if step.kind == .customerService {
                        step06ProviderSession.select(
                            provider.id,
                            for: step.id
                        )
                    } else {
                        store.selectProvider(
                            workflowID: workflow.id,
                            stepID: step.id,
                            providerID: provider.id
                        )
                    }

                } label: {

                    Label(
                        provider.name,
                        systemImage:
                            provider
                            .kind
                            .systemImage
                    )
                }
                .disabled(
                    !provider.isEnabled
                )
            }

        } label: {

            if let provider =
                selectedProvider(
                    workflowID:
                        workflow.id,
                    stepID:
                        step.id,
                    fallback:
                        step
                ) {

                pickerLabel(
                    icon: provider.kind.systemImage,
                    title: provider.name,
                    detail: provider.isEnabled ? nil : "未启用"
                )

            } else {

                pickerLabel(
                    icon: "sparkles",
                    title: "选择 AI"
                )
            }
        }
        .menuStyle(
            .borderlessButton
        )
        .fixedSize()
    }


    // MARK: - Loading

    private var loadingState: some View {

        VStack(spacing: 12) {

            ProgressView()

            Text("正在准备活动工作流…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 260
        )
    }

    // MARK: - Prepare Task

    private func prepareTask(
        workflow: ZhuowangCampaignWorkflow,
        step: ZhuowangWorkflowStep
    ) {

        let latestStep =
            store.step(
                workflowID:
                    workflow.id,
                stepID:
                    step.id
            )
            ?? step

        let provider =
            selectedProvider(
                for: latestStep
            )

        let connection = provider.flatMap {
            connections.recommendedConnection(
                $0.id
            )
        }

        let tool = selectedTool(
            for: latestStep
        )

        let route = connection.flatMap { connection in
            tool.flatMap { tool in
                connections.route(
                    connection.id,
                    tool.id
                )
            }
        }

        let executionSnapshot:
            ZhuowangWorkflowExecutionSnapshot?

        if let capability = latestStep.requiredCapabilities.first {
            guard
                let provider,
                let connection,
                let tool,
                let route,
                tool.capabilities.contains(capability),
                route.status == .available,
                route.supportsDirectExecution,
                route.supportsAutomaticResultReturn,
                let adapterIdentifier = route.adapterIdentifier
            else {
                return
            }

            executionSnapshot =
                ZhuowangWorkflowExecutionSnapshot(
                    workflowID: workflow.id,
                    workflowStepID: latestStep.id,
                    providerID: provider.id,
                    connectionID: connection.id,
                    toolIntegrationID: tool.id,
                    routeID: route.id,
                    capability: capability,
                    adapterIdentifier: adapterIdentifier,
                    prototypeExecutionProfile:
                        capability == .prototypeDesign
                        ? latestStep.prototypeExecutionProfile.normalized
                        : nil
                )
        } else {
            executionSnapshot = nil
        }

        let latestWorkflow =
            store.workflow(
                forCampaignID:
                    campaign.id
            )
            ?? workflow

        let taskPackage =
            ZhuowangTaskPackageBuilder.build(
                campaign: campaign,
                province: province,
                module: module,
                workflow: latestWorkflow,
                step: latestStep,
                provider: provider,
                executionSnapshot:
                    executionSnapshot
            )

        previewContext =
            ZhuowangTaskPreviewContext(
                taskPackage:
                    taskPackage,
                provider:
                    provider,
                connection:
                    connection,
                tool:
                    tool,
                route:
                    route,
                workflowID:
                    latestWorkflow.id,
                stepID:
                    latestStep.id
            )
    }


    // MARK: - Adopt Preview Result

    private func adoptPreviewResult(
        context: ZhuowangTaskPreviewContext,
        resultText: String,
        executionResult: ZhuowangWorkflowExecutionResult?
    ) -> ZhuowangArtifactAdoptionPresentationResult {

        guard
            let providerID =
                context.provider?.id,
            let currentStep =
                store.step(
                    workflowID:
                        context.workflowID,
                    stepID:
                        context.stepID
                )
        else {
            return .failure(
                "当前 Workflow 或 Provider 已不可用，未保存任何修改。"
            )
        }

        let inputText =
            """
            \(context.taskPackage.title)

            \(context.taskPackage.instruction)

            【参考上下文】
            \(context.taskPackage.contextReferences.joined(separator: "\n"))

            【预期输出】
            \(context.taskPackage.expectedOutputs.joined(separator: "\n"))
            """

        let adoptionResult:
            ZhuowangArtifactAdoptionPresentationResult

        if currentStep.kind == .customerService,
           let provider = context.provider {

            let result =
                store.adoptCustomerServiceResult(
                    workflowID: context.workflowID,
                    campaignID: campaign.id,
                    campaignName: campaign.name,
                    provinceName: province?.pathName,
                    stepID: context.stepID,
                    provider: provider,
                    connectionID:
                        context.connection?.id
                        ?? ZhuowangBuiltInIntegrationIDs
                            .deepSeekConnection,
                    adapterIdentifier:
                        context.connection?
                            .adapterIdentifier
                        ?? "deepseek-harness",
                    inputText: inputText,
                    outputText: resultText
                )

            adoptionResult =
                ZhuowangArtifactAdoptionPresentationResult(
                    customerServiceResult: result
                )

        } else if let executionResult,
           let provider = context.provider {

            let adopted = store.adoptExecutionResult(
                workflowID:
                    context.workflowID,
                campaignID:
                    campaign.id,
                campaignName:
                    campaign.name,
                provinceName:
                    province?.pathName,
                stepID: context.stepID,
                provider: provider,
                inputText:
                    inputText,
                    executionResult:
                    executionResult
            )

            adoptionResult = adopted
                ? .success
                : .failure(
                    "Artifact 文件或 Workflow metadata 未能安全保存，请检查后重试。"
                )

        } else {

            let artifactName =
                "\(currentStep.title) · AI 采用结果"

            let adopted = store.adoptAIResult(
                workflowID: context.workflowID,
                campaignID: campaign.id,
                campaignName: campaign.name,
                provinceName: province?.pathName,
                stepID: context.stepID,
                providerID: providerID,
                inputText: inputText,
                outputText: resultText,
                artifactName: artifactName
            )

            adoptionResult = adopted
                ? .success
                : .failure(
                    "Artifact 文件或 Workflow metadata 未能安全保存，请检查后重试。"
                )
        }

        if adoptionResult.succeeded {
            selectedStepID =
                context.stepID
        }

        return adoptionResult
    }


    // MARK: - Data

    private var workflow:
        ZhuowangCampaignWorkflow? {

        store.workflow(
            forCampaignID:
                campaign.id
        )
    }


    private func ensureWorkflowExists() {

        _ =
            store.getOrCreateWorkflow(
                forCampaignID:
                    campaign.id
            )
    }


    private func selectedProvider(
        for step:
            ZhuowangWorkflowStep
    ) -> ZhuowangAIProvider? {

        let providerID: UUID?
        if step.kind == .customerService {
            providerID = step06ProviderSession.providerID(for: step)
        } else {
            providerID = step.selectedProviderID
        }

        guard let providerID else {
            return nil
        }

        return store.provider(
            id: providerID
        )
    }


    private func currentProviderID(
        workflowID: UUID,
        stepID: UUID
    ) -> UUID? {

        store.step(
            workflowID: workflowID,
            stepID: stepID
        )?
        .selectedProviderID
    }


    private func selectedProvider(
        workflowID: UUID,
        stepID: UUID,
        fallback: ZhuowangWorkflowStep
    ) -> ZhuowangAIProvider? {

        let latestStep =
            store.step(
                workflowID:
                    workflowID,
                stepID:
                    stepID
            )
            ?? fallback

        return selectedProvider(
            for: latestStep
        )
    }


    // MARK: - Counts

    private func configuredProviderCount(
        in workflow:
            ZhuowangCampaignWorkflow
    ) -> Int {

        ZhuowangWorkflowUIModel.enabledSteps(
            in: workflow
        )
        .filter {
            selectedProvider(for: $0) != nil
        }
        .count
    }


    // MARK: - Description

    private func stepDescription(
        _ step:
            ZhuowangWorkflowStep
    ) -> String {

        switch step.kind {

        case .brief:
            return "整理需求、目标、用户、奖品和业务背景"

        case .idea:
            return "让 AI 提供活动主题、玩法和整体策划方向"

        case .plan:
            return "基于确认后的思路生成完整活动策划方案"

        case .pageStructure:
            return "梳理页面模块、用户路径和核心交互"

        case .prototype:
            return "确认页面结构后生成可编辑的活动原型"

        case .customerService:
            return "根据最终方案生成客服 FAQ 与统一口径"

        case .prompt:
            return "沉淀活动相关可复用 Prompt"

        case .flowchart:
            return "生成业务流程和用户路径流程图"

        case .asset:
            return "生成或整理活动相关视觉与运营素材"

        case .review:
            return "检查方案、页面和上线内容"

        case .custom:
            return "自定义工作步骤"
        }
    }


    // MARK: - Capability & Tool Summary

    private func capabilitySummary(
        for step: ZhuowangWorkflowStep
    ) -> String {

        if step.requiredCapabilities.isEmpty {
            return "无需指定"
        }

        return step.requiredCapabilities
            .map {
                $0.title
            }
            .joined(separator: "、")
    }


    private func toolSummary(
        for step: ZhuowangWorkflowStep
    ) -> String {

        if step.requiredCapabilities.isEmpty {
            return "由 AI 自行选择"
        }

        if step.requiredCapabilities.contains(where: {
            String(describing: $0)
                .lowercased()
                .contains("prototype")
        }) {

            return "根据已连接工具自动匹配"
        }

        return "根据能力自动匹配"
    }


    private func selectedToolSummary(
        for step: ZhuowangWorkflowStep
    ) -> String {

        if let tool = selectedTool(for: step) {
            return tool.name
        }

        return toolSummary(for: step)
    }


    private func availableTools(
        for step: ZhuowangWorkflowStep
    ) -> [ZhuowangExternalToolIntegration] {

        var seen = Set<UUID>()

        return step.requiredCapabilities
            .flatMap {
                connections.availableTools(
                    $0
                )
            }
            .filter {
                seen.insert($0.id).inserted
            }
    }


    private func selectedTool(
        for step: ZhuowangWorkflowStep
    ) -> ZhuowangExternalToolIntegration? {

        step.selectedToolIDs.lazy
            .compactMap {
                connections.toolIntegration(
                    $0
                )
            }
            .first
    }


    private func canPrepareTask(
        workflowID: UUID,
        step: ZhuowangWorkflowStep
    ) -> Bool {

        let latestStep = store.step(
            workflowID: workflowID,
            stepID: step.id
        ) ?? step

        guard let provider = selectedProvider(
            for: latestStep
        ) else {
            return false
        }

        guard let capability =
            latestStep.requiredCapabilities.first
        else {
            return true
        }

        guard
            let connection = connections
                .recommendedConnection(
                    provider.id
                ),
            let tool = selectedTool(for: latestStep),
            tool.capabilities.contains(capability),
            let route = connections.route(
                connection.id,
                tool.id
            )
        else {
            return false
        }

        return route.status == .available
            && route.supportsDirectExecution
            && route.supportsAutomaticResultReturn
            && route.adapterIdentifier != nil
    }



    // MARK: - Execution Mode

    private func executionModeText(
        for step:
            ZhuowangWorkflowStep
    ) -> String {

        guard
            let provider =
                selectedProvider(
                    for: step
                )
        else {
            return "选择 AI 后确定"
        }

        switch provider.kind {

        case .openAI:
            return "ChatGPT / OpenAI"

        case .codex:
            return "Codex 本地执行"

        case .deepSeekHarness:
            return "DeepSeek Harness"

        case .claude:
            return "Claude Desktop"

        case .figma:
            return "工具连接"

        case .custom:
            return "自定义连接"
        }
    }
}
