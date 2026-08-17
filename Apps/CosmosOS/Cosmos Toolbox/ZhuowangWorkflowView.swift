import SwiftUI

struct ZhuowangWorkflowView: View {

    @ObservedObject var store: ZhuowangWorkflowStore

    let campaignID: UUID
    let campaignName: String

    @State private var expandedStepID: UUID?

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingXL
        ) {

            workflowHeader

            if let workflow {
                workflowOverview(workflow)

                workflowSteps(workflow)

            } else {
                loadingState
            }
        }
        .onAppear {
            ensureWorkflowExists()
        }
    }


    // MARK: - Header

    private var workflowHeader: some View {

        HStack(
            alignment: .top,
            spacing: CosmosDesign.spacingXL
        ) {

            VStack(
                alignment: .leading,
                spacing: 6
            ) {

                HStack(spacing: 9) {

                    Image(
                        systemName: "sparkles.rectangle.stack"
                    )
                    .font(
                        .system(
                            size: 19,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(.tint)

                    Text("AI Workflow")
                        .font(
                            .system(
                                size: 25,
                                weight: .semibold
                            )
                        )
                }

                Text("AI 工作流中控台")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(
                    "为每一个工作步骤选择不同的 AI，并由你决定什么时候生成、修改和确认。"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }

            Spacer()

            if let workflow {

                workflowProgressBadge(
                    workflow
                )
            }
        }
    }


    // MARK: - Overview

    private func workflowOverview(
        _ workflow: ZhuowangCampaignWorkflow
    ) -> some View {

        HStack(
            spacing: CosmosDesign.spacingM
        ) {

            workflowMetric(
                value:
                    "\(enabledSteps(in: workflow).count)",
                title: "工作步骤",
                subtitle: "Workflow Steps",
                icon: "list.number"
            )

            workflowMetric(
                value:
                    "\(approvedStepCount(in: workflow))",
                title: "已确认",
                subtitle: "Approved",
                icon: "checkmark.circle"
            )

            workflowMetric(
                value:
                    "\(configuredProviderCount(in: workflow))",
                title: "已选择 AI",
                subtitle: "AI Assigned",
                icon: "sparkles"
            )

            workflowMetric(
                value:
                    "\(workflow.artifacts.count)",
                title: "工作产物",
                subtitle: "Artifacts",
                icon: "doc.on.doc"
            )
        }
    }


    // MARK: - Metric

    private func workflowMetric(
        value: String,
        title: String,
        subtitle: String,
        icon: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {

            HStack {

                Image(systemName: icon)
                    .font(
                        .system(
                            size: 15,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(.secondary)

                Spacer()

                Text(value)
                    .font(
                        .system(
                            size: 24,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
            }

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text(title)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 92,
            alignment: .topLeading
        )
        .padding(
            CosmosDesign.spacingM
        )
        .background(
            Color.primary.opacity(0.018)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusMedium,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusMedium,
                style: .continuous
            )
            .stroke(
                Color.primary.opacity(0.055),
                lineWidth: 1
            )
        }
    }


    // MARK: - Steps

    private func workflowSteps(
        _ workflow: ZhuowangCampaignWorkflow
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {

            HStack {

                CosmosSectionTitle(
                    title: "工作流程",
                    subtitle: "Workflow"
                )

                Spacer()

                Text(
                    "你可以为每一步单独选择 AI"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {

                let steps =
                    enabledSteps(
                        in: workflow
                    )

                ForEach(
                    Array(
                        steps.enumerated()
                    ),
                    id: \.element.id
                ) { index, step in

                    workflowStepRow(
                        workflow: workflow,
                        step: step,
                        index: index
                    )

                    if index
                        < steps.count - 1 {

                        Divider()
                            .padding(
                                .leading,
                                72
                            )
                    }
                }
            }
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
    }


    // MARK: - Step Row

    private func workflowStepRow(
        workflow: ZhuowangCampaignWorkflow,
        step: ZhuowangWorkflowStep,
        index: Int
    ) -> some View {

        VStack(spacing: 0) {

            Button {

                withAnimation(
                    .easeInOut(
                        duration:
                            CosmosDesign.animationFast
                    )
                ) {

                    if expandedStepID
                        == step.id {

                        expandedStepID = nil

                    } else {

                        expandedStepID =
                            step.id
                    }
                }

            } label: {

                HStack(
                    spacing:
                        CosmosDesign.spacingM
                ) {

                    stepNumber(
                        index: index,
                        step: step
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {

                        HStack(spacing: 7) {

                            Text(step.title)
                                .fontWeight(.medium)

                            if !step
                                .englishTitle
                                .isEmpty {

                                Text(
                                    step.englishTitle
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }

                        Text(
                            stepDescription(
                                step
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(1)
                    }

                    Spacer()

                    providerSummary(
                        step: step
                    )

                    workflowStatusBadge(
                        step.status
                    )

                    Image(
                        systemName:
                            expandedStepID
                            == step.id
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .tertiary
                    )
                    .frame(width: 16)
                }
                .padding(
                    .horizontal,
                    CosmosDesign.spacingL
                )
                .padding(
                    .vertical,
                    CosmosDesign.spacingM
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedStepID
                == step.id {

                stepExpandedContent(
                    workflow: workflow,
                    step: step
                )
                .transition(
                    .opacity
                    .combined(
                        with:
                            .move(
                                edge: .top
                            )
                    )
                )
            }
        }
    }


    // MARK: - Step Number

    private func stepNumber(
        index: Int,
        step: ZhuowangWorkflowStep
    ) -> some View {

        ZStack {

            Circle()
                .fill(
                    stepCircleColor(
                        step.status
                    )
                )
                .frame(
                    width: 38,
                    height: 38
                )

            if step.status
                == .approved
                || step.status
                == .completed {

                Image(
                    systemName:
                        "checkmark"
                )
                .font(
                    .system(
                        size: 13,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    Color.accentColor
                )

            } else {

                Text(
                    String(
                        format:
                            "%02d",
                        index + 1
                    )
                )
                .font(
                    .system(
                        size: 11,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    step.status
                    == .ready
                    ? Color.accentColor
                    : Color.secondary
                )
            }
        }
    }


    // MARK: - Expanded Step

    private func stepExpandedContent(
        workflow: ZhuowangCampaignWorkflow,
        step: ZhuowangWorkflowStep
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingL
        ) {

            Divider()

            HStack(
                alignment: .top,
                spacing:
                    CosmosDesign.spacingXL
            ) {

                VStack(
                    alignment: .leading,
                    spacing:
                        CosmosDesign.spacingS
                ) {

                    Text("执行 AI")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    providerPicker(
                        workflow: workflow,
                        step: step
                    )
                }
                .frame(
                    maxWidth: 270,
                    alignment: .leading
                )

                VStack(
                    alignment: .leading,
                    spacing:
                        CosmosDesign.spacingS
                ) {

                    Text("执行方式")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(
                        executionModeText(
                            for: step
                        )
                    )
                    .font(.callout)
                }
                .frame(
                    maxWidth: 220,
                    alignment: .leading
                )

                VStack(
                    alignment: .leading,
                    spacing:
                        CosmosDesign.spacingS
                ) {

                    Text("人工确认")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

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

                Spacer()
            }

            HStack {

                if step.selectedProviderID
                    == nil {

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

                Spacer()

                Button {

                    // 后续：
                    // 这里将进入 Task Package /
                    // AI 执行流程。

                } label: {

                    Label(
                        "准备任务",
                        systemImage:
                            "arrow.right.circle"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(
                    step.selectedProviderID
                    == nil
                )
            }
        }
        .padding(
            .leading,
            72
        )
        .padding(
            .trailing,
            CosmosDesign.spacingL
        )
        .padding(
            .bottom,
            CosmosDesign.spacingL
        )
    }


    // MARK: - Provider Picker

    private func providerPicker(
        workflow: ZhuowangCampaignWorkflow,
        step: ZhuowangWorkflowStep
    ) -> some View {

        Menu {

            Button {

                store.selectProvider(
                    workflowID:
                        workflow.id,
                    stepID:
                        step.id,
                    providerID:
                        nil
                )

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

                    store.selectProvider(
                        workflowID:
                            workflow.id,
                        stepID:
                            step.id,
                        providerID:
                            provider.id
                    )

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

            HStack(spacing: 8) {

                if let provider =
                    selectedProvider(
                        for: step
                    ) {

                    Image(
                        systemName:
                            provider
                            .kind
                            .systemImage
                    )

                    Text(
                        provider.name
                    )

                    if !provider
                        .isEnabled {

                        Text("未启用")
                            .font(.caption2)
                            .foregroundStyle(
                                .secondary
                            )
                    }

                } else {

                    Image(
                        systemName:
                            "sparkles"
                    )

                    Text("选择 AI")
                }

                Spacer()

                Image(
                    systemName:
                        "chevron.up.chevron.down"
                )
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )
            }
            .padding(
                .horizontal,
                11
            )
            .padding(
                .vertical,
                8
            )
            .background(
                Color.primary
                    .opacity(0.025)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign
                        .cornerRadiusSmall,
                    style:
                        .continuous
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign
                        .cornerRadiusSmall,
                    style:
                        .continuous
                )
                .stroke(
                    Color.primary
                        .opacity(0.07),
                    lineWidth: 1
                )
            }
        }
        .menuStyle(
            .borderlessButton
        )
    }


    // MARK: - Provider Summary

    @ViewBuilder
    private func providerSummary(
        step: ZhuowangWorkflowStep
    ) -> some View {

        if let provider =
            selectedProvider(
                for: step
            ) {

            HStack(spacing: 6) {

                Image(
                    systemName:
                        provider
                        .kind
                        .systemImage
                )

                Text(
                    provider.name
                )
                .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
            .frame(
                maxWidth: 130
            )

        } else {

            Text("未选择 AI")
                .font(.caption)
                .foregroundStyle(
                    .tertiary
                )
                .frame(
                    maxWidth: 130
                )
        }
    }


    // MARK: - Status Badge

    private func workflowStatusBadge(
        _ status:
            ZhuowangWorkflowStepStatus
    ) -> some View {

        HStack(spacing: 6) {

            Circle()
                .fill(
                    statusColor(
                        status
                    )
                )
                .frame(
                    width: 6,
                    height: 6
                )

            Text(status.title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(
            .horizontal,
            9
        )
        .padding(
            .vertical,
            5
        )
        .background(
            statusColor(
                status
            )
            .opacity(0.08)
        )
        .clipShape(Capsule())
    }


    // MARK: - Workflow Progress

    private func workflowProgressBadge(
        _ workflow:
            ZhuowangCampaignWorkflow
    ) -> some View {

        let steps =
            enabledSteps(
                in: workflow
            )

        let completed =
            steps.filter {
                $0.status == .approved
                || $0.status == .completed
            }
            .count

        return VStack(
            alignment: .trailing,
            spacing: 5
        ) {

            Text(
                "\(completed) / \(steps.count)"
            )
            .font(
                .system(
                    size: 18,
                    weight: .semibold,
                    design: .rounded
                )
            )

            Text("Workflow Progress")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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


    // MARK: - Data

    private var workflow:
        ZhuowangCampaignWorkflow? {

        store.workflow(
            forCampaignID:
                campaignID
        )
    }


    private func ensureWorkflowExists() {

        _ =
            store.getOrCreateWorkflow(
                forCampaignID:
                    campaignID
            )
    }


    private func enabledSteps(
        in workflow:
            ZhuowangCampaignWorkflow
    ) -> [ZhuowangWorkflowStep] {

        workflow.steps
            .filter {
                $0.isEnabled
            }
            .sorted {

                if $0.sortOrder
                    != $1.sortOrder {

                    return $0.sortOrder
                        < $1.sortOrder
                }

                return $0.createdAt
                    < $1.createdAt
            }
    }


    private func selectedProvider(
        for step:
            ZhuowangWorkflowStep
    ) -> ZhuowangAIProvider? {

        guard
            let providerID =
                step.selectedProviderID
        else {
            return nil
        }

        return store.provider(
            id: providerID
        )
    }


    // MARK: - Counts

    private func approvedStepCount(
        in workflow:
            ZhuowangCampaignWorkflow
    ) -> Int {

        enabledSteps(
            in: workflow
        )
        .filter {

            $0.status == .approved
            || $0.status == .completed
        }
        .count
    }


    private func configuredProviderCount(
        in workflow:
            ZhuowangCampaignWorkflow
    ) -> Int {

        enabledSteps(
            in: workflow
        )
        .filter {
            $0.selectedProviderID
                != nil
        }
        .count
    }


    // MARK: - Status Color

    private func statusColor(
        _ status:
            ZhuowangWorkflowStepStatus
    ) -> Color {

        switch status {

        case .notStarted:
            return .secondary

        case .ready:
            return .blue

        case .running:
            return .orange

        case .waitingForApproval:
            return .purple

        case .approved:
            return .green

        case .needsRevision:
            return .orange

        case .completed:
            return .green

        case .failed:
            return .red

        case .skipped:
            return .secondary
        }
    }


    private func stepCircleColor(
        _ status:
            ZhuowangWorkflowStepStatus
    ) -> Color {

        switch status {

        case .ready:
            return Color.accentColor
                .opacity(0.11)

        case .running:
            return Color.orange
                .opacity(0.11)

        case .waitingForApproval:
            return Color.purple
                .opacity(0.11)

        case .approved,
             .completed:
            return Color.green
                .opacity(0.11)

        case .needsRevision:
            return Color.orange
                .opacity(0.11)

        case .failed:
            return Color.red
                .opacity(0.11)

        case .notStarted,
             .skipped:
            return Color.primary
                .opacity(0.045)
        }
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
            return "Figma Integration"

        case .custom:
            return "自定义连接"
        }
    }
}
