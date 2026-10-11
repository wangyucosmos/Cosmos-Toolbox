import SwiftUI
import AppKit

struct ZhuowangCampaignDetailView: View {

    @ObservedObject var store: ZhuowangCampaignStore
    @ObservedObject var workflowStore: ZhuowangWorkflowStore

    let campaignID: UUID
    let province: ZhuowangProvince?
    let module: ZhuowangModule?

    /// Lets another entry (e.g. the progress workbench) open a specific tab
    /// or the existing delivery-package sheet in this window.
    @ObservedObject var route = ZhuowangCampaignDetailRoute()

    /// Synthetic connection registry for tests / fixtures; `nil` = live registry.
    var workflowConnections: ZhuowangWorkflowConnections?

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.accessibilityReduceMotion)
    private var systemMotion

    @Environment(\.cosmosPreferences)
    private var preferences

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

    @State private var workspaceMessage = ""
    @State private var showWorkspaceAlert = false

    @State
    private var showArtifactDeliveryPackage = false

    @State private var selectedTab: ZhuowangCampaignDetailTab = .overview

    /// Set by the overview "下一步" button; the Workflow tab selects that step.
    @State private var workflowFocus: ZhuowangWorkflowFocusRequest?
    @State private var focusSerial = 0

    @State private var name = ""
    @State private var englishName = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var status: ZhuowangCampaignStatus = .planning
    @State private var notes = ""

    private var reducedMotion: Bool {
        preferences.reducesMotion(system: systemMotion)
    }

    var body: some View {
        VStack(spacing: 0) {

            header

            Divider()

            if let message =
                store.persistenceState.userMessage {
                CampaignUINotice(
                    text: message,
                    icon: "lock.trianglebadge.exclamationmark",
                    tone: .warning
                )
                .padding(.horizontal, CosmosDesign.spacingL)
                .padding(.vertical, CosmosDesign.spacingS)

                Divider()
            }

            if let campaign {
                tabContent(campaign)
            } else {
                missingCampaignView
            }
        }
        .frame(
            minWidth: 700,
            minHeight: 560
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .modifier(CosmosMotionPolicy())
        .onAppear {
            loadDraft()
            if let failure = workflowStore.workspaceFileManager.accessFailure {
                workspaceMessage = failure
                showWorkspaceAlert = true
            }
            recoverLocalWorkflowIfNeeded()
            migrateLegacyArtifactsIfNeeded()
            applyRoute()
        }
        .onChange(of: route.requestSerial) {
            applyRoute()
        }
        .confirmationDialog(
            "删除这个活动？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                "删除活动",
                role: .destructive
            ) {
                deleteCampaign()
            }

            Button(
                "取消",
                role: .cancel
            ) { }

        } message: {
            Text(
                "删除后，这个活动将从 Cosmos OS 中移除。"
            )
        }
        .alert(
            "工作区",
            isPresented: $showWorkspaceAlert
        ) {
            Button("知道了") { }
        } message: {
            Text(workspaceMessage)
        }
        .sheet(
            isPresented:
                $showArtifactDeliveryPackage
        ) {
            if let campaign, workflowStore.workspaceFileManager.accessFailure == nil {
                ZhuowangArtifactDeliveryPackageView(
                    campaign: campaign,
                    provinceName: province?.name,
                    campaignWorkspaceURL:
                        workflowStore.workspaceFileManager
                            .campaignDirectoryURL(
                                provinceName:
                                    province?.pathName,
                                campaignName:
                                    campaign.name
                            ),
                    snapshotProvider: {
                        ZhuowangArtifactDeliverySnapshot(
                            campaignID: campaign.id,
                            artifacts:
                                workflowStore.artifacts(
                                    forCampaignID:
                                        campaign.id
                                ),
                            steps:
                                workflowStore.workflow(
                                    forCampaignID:
                                        campaign.id
                                )?.steps
                                ?? []
                        )
                    }
                )
            }
        }
    }


    // MARK: - Route

    private func applyRoute() {
        guard !isEditing,
              let destination = route.takeRequest()
        else {
            return
        }

        switch destination {
        case .overview:
            show(.overview)
        case .workflow:
            show(.workflow)
        case .artifacts:
            show(.artifacts)
        case .deliveryPackage:
            show(.artifacts)
            showArtifactDeliveryPackage = true
        }
    }

    private func show(_ tab: ZhuowangCampaignDetailTab) {
        if reducedMotion {
            selectedTab = tab
        } else {
            withAnimation(CosmosDesign.motion) {
                selectedTab = tab
            }
        }
    }

    /// Jumps to the Workflow tab; the Workflow view selects `stepID`.
    private func openWorkflow(focusing stepID: UUID?) {
        guard !isEditing else {
            return
        }

        if let stepID {
            focusSerial += 1
            workflowFocus = ZhuowangWorkflowFocusRequest(
                stepID: stepID,
                serial: focusSerial
            )
        }

        show(.workflow)
    }


    // MARK: - Header

    private var visibleTabs: [ZhuowangCampaignDetailTab] {
        ZhuowangCampaignDetailTab.allCases.filter {
            $0 != .monthly
            || campaign?.isMonthlyMemberActivation == true
        }
    }

    private var tabItems: [CampaignUITabItem<ZhuowangCampaignDetailTab>] {
        visibleTabs.map {
            CampaignUITabItem(id: $0, title: $0.title, icon: $0.systemImage)
        }
    }

    private var tabSelection: Binding<ZhuowangCampaignDetailTab> {
        Binding(
            get: { selectedTab },
            set: { tab in
                guard !isEditing else {
                    return
                }
                selectedTab = tab
            }
        )
    }

    private var header: some View {
        VStack(spacing: 0) {

            HStack(spacing: CosmosDesign.spacingL) {

                headerLeading

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(
                        isEditing
                        ? "编辑活动"
                        : campaign?.name ?? "活动详情"
                    )
                    .font(.system(size: 24, weight: .semibold))
                    .lineLimit(1)

                    if let campaign, !isEditing {
                        HStack(spacing: 8) {
                            Text(scopeText)

                            Text("·")
                                .foregroundStyle(.tertiary)

                            Text(ZhuowangWorkspaceUI.dates(campaign))
                                .monospacedDigit()

                            if campaign.isMonthlyMemberActivation {
                                CampaignUIStatusPill(
                                    text: "月度会员促活",
                                    icon: "calendar.badge.clock",
                                    tone: .info
                                )
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }

                Spacer(minLength: 12)

                if let campaign {
                    if isEditing {

                        Button("取消") {
                            cancelEditing()
                        }
                        .buttonStyle(.glass)

                        Button("保存") {
                            saveChanges()
                        }
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(
                            name
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty
                            || !store.persistenceState
                                .allowsMutations
                        )

                    } else {

                        ZhuowangCampaignStatusBadge(
                            status: campaign.status
                        )

                        Menu {
                            Button {
                                beginEditing()
                            } label: {
                                Label(
                                    "编辑活动",
                                    systemImage: "pencil"
                                )
                            }

                            Divider()

                            Button(
                                role: .destructive
                            ) {
                                showDeleteConfirmation = true
                            } label: {
                                Label(
                                    "删除活动",
                                    systemImage: "trash"
                                )
                            }

                        } label: {
                            Image(
                                systemName: "ellipsis.circle"
                            )
                            .font(
                                .system(
                                    size: 16,
                                    weight: .medium
                                )
                            )
                            .frame(
                                width: 30,
                                height: 30
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .disabled(
                            !store.persistenceState
                                .allowsMutations
                        )

                        Button {
                            beginEditing()
                        } label: {
                            Label(
                                "编辑",
                                systemImage: "pencil"
                            )
                        }
                        .buttonStyle(.glass)
                        .disabled(
                            !store.persistenceState
                                .allowsMutations
                        )
                    }
                }
            }
            .padding(.horizontal, CosmosDesign.spacingXL)
            .padding(.top, 16)
            .padding(.bottom, campaign == nil ? 14 : 12)

            if campaign != nil {
                toolbarStrip
            }
        }
        .background(.bar)
    }

    @ViewBuilder
    private var headerLeading: some View {
        if campaign != nil, !isEditing {
            let progress = ZhuowangWorkflowUIModel.progress(of: workflowSteps)
            CampaignUIProgressRing(
                completed: progress.completed,
                total: progress.total,
                size: 52
            )
            .help("Workflow 进度：按已启用步骤计算")
        } else {
            Image(systemName: campaign == nil ? "exclamationmark.triangle" : "pencil.and.outline")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(campaign == nil ? Color.secondary : Color.accentColor)
                .frame(width: 52, height: 52)
                .background(Color.primary.opacity(0.05), in: Circle())
        }
    }

    /// Window toolbar strip: segmented tabs on the left, tab actions on the right.
    private var toolbarStrip: some View {
        HStack(spacing: CosmosDesign.spacingM) {

            CampaignUISegmentedTabs(
                items: tabItems,
                selection: tabSelection,
                isDisabled: isEditing
            )

            Spacer(minLength: 8)

            if selectedTab == .artifacts, !isEditing {
                Button {
                    showArtifactDeliveryPackage = true
                } label: {
                    Label(
                        "导出交付包",
                        systemImage: "archivebox"
                    )
                }
                .buttonStyle(.glass)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, CosmosDesign.spacingXL)
        .padding(.bottom, 12)
        .campaignUIAnimation(value: selectedTab)
    }


    // MARK: - Tab Content

    private func tabContent(
        _ campaign: ZhuowangCampaign
    ) -> some View {

        let transition: AnyTransition = reducedMotion
            ? .opacity
            : .opacity.combined(with: .offset(y: 8))

        return ScrollViewReader { proxy in

            ScrollView {

                ZStack(alignment: .top) {

                    switch selectedTab {

                    case .overview:

                        Group {
                            if isEditing {
                                editContent
                            } else {
                                overviewContent(campaign)
                            }
                        }
                        .transition(transition)

                    case .workflow:
                        ZhuowangWorkflowView(
                            store: workflowStore,
                            campaign: campaign,
                            province: province,
                            module: module,
                            focusRequest: workflowFocus,
                            onOpenArtifact: { artifact in
                                openArtifactWindow(artifact)
                            },
                            connections: workflowConnections
                        )
                        .transition(transition)

                    case .artifacts:
                        artifactsContent
                            .transition(transition)

                    case .monthly:
                        ZhuowangMonthlyChecklistView(
                            store: store,
                            workflowStore: workflowStore,
                            campaignID: campaignID
                        )
                        .transition(transition)
                    }
                }
                .id("campaign-detail-top")
                .padding(.horizontal, CosmosDesign.spacingXL + 4)
                .padding(.vertical, CosmosDesign.spacingXL)
                .frame(maxWidth: 1080)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: selectedTab) {
                if selectedTab != .workflow {
                    workflowFocus = nil
                }
                proxy.scrollTo("campaign-detail-top", anchor: .top)
            }
        }
    }


    // MARK: - Overview

    private func overviewContent(
        _ campaign: ZhuowangCampaign
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingL
        ) {

            workflowSummaryCard
                .campaignUIEntrance(0)

            twoColumn(
                adoptedArtifactsCard,
                workspaceCard
            )
            .campaignUIEntrance(1)

            basicInfoCard(campaign)
                .campaignUIEntrance(2)

            CampaignReferencesView(
                store: store,
                campaignID: campaignID
            )
            .campaignUIEntrance(3)
        }
    }

    private func twoColumn<A: View, B: View>(
        _ left: A,
        _ right: B
    ) -> some View {

        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: 340),
                    spacing: CosmosDesign.spacingL,
                    alignment: .top
                )
            ],
            alignment: .leading,
            spacing: CosmosDesign.spacingL
        ) {
            left
            right
        }
    }

    // MARK: Workflow summary

    private var workflowSteps: [ZhuowangWorkflowStep] {
        workflowStore.workflow(forCampaignID: campaignID)
            .map(ZhuowangWorkflowUIModel.enabledSteps(in:))
            ?? []
    }

    private var workflowSummaryCard: some View {

        let steps = workflowSteps
        let progress = ZhuowangWorkflowUIModel.progress(of: steps)
        let next = ZhuowangWorkflowUIModel.nextStep(in: steps)
        let attention = steps.filter {
            $0.status == .failed || $0.status == .needsRevision
        }

        return CampaignUICard(
            title: "Workflow 进度",
            icon: "list.bullet.rectangle",
            info: "进度按已启用的步骤计算。“下一步”是按顺序第一个尚未确认的步骤；确认一步后才会解锁下一步。",
            trailing: {
                Button {
                    openWorkflow(focusing: next?.id)
                } label: {
                    Label(
                        steps.isEmpty ? "开始 Workflow" : "前往 Workflow",
                        systemImage: "arrow.right"
                    )
                }
                .buttonStyle(.glassProminent)
                .disabled(isEditing)
            }
        ) {

            if steps.isEmpty {

                Text("还没有开始 Workflow。进入 Workflow 后会从第一步开始。")
                    .font(CosmosDesign.font(.body))
                    .foregroundStyle(.secondary)

            } else {

                stepDots(steps)

                HStack(alignment: .firstTextBaseline, spacing: 10) {

                    if let next {
                        let look = ZhuowangWorkflowUIModel.presentation(for: next.status)
                        let position = (steps.firstIndex { $0.id == next.id } ?? 0) + 1

                        Text("下一步")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Text(String(format: "%02d ", position) + next.title)
                            .font(.system(size: 15, weight: .semibold))

                        CampaignUIStatusPill(
                            text: next.status.title,
                            tone: look.tone
                        )

                    } else {
                        Label(
                            "全部 \(progress.total) 步均已确认",
                            systemImage: "checkmark.seal.fill"
                        )
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.green)
                    }

                    Spacer(minLength: 0)

                    Text("已完成 \(progress.completed) / \(progress.total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if !attention.isEmpty {
                    CampaignUINotice(
                        text: "需要处理："
                            + attention
                            .map { "「\($0.title)」\($0.status.title)" }
                            .joined(separator: "、"),
                        icon: "exclamationmark.triangle",
                        tone: .warning
                    )
                }
            }
        }
    }

    private func stepDots(
        _ steps: [ZhuowangWorkflowStep]
    ) -> some View {

        HStack(spacing: 0) {

            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in

                let look = ZhuowangWorkflowUIModel.presentation(for: step.status)

                VStack(spacing: 6) {
                    Image(systemName: look.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(look.tone.color)
                        .frame(width: 30, height: 30)
                        .background(look.tone.color.opacity(0.13), in: Circle())

                    Text(step.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .help("\(step.title)：\(step.status.title)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("第 \(index + 1) 步 \(step.title)，\(step.status.title)")
            }
        }
    }

    // MARK: Adopted artifacts

    private var adoptedArtifactsCard: some View {

        let adopted = artifactGroups.filter {
            $0.currentArtifact.isApprovedVersion
        }

        return CampaignUICard(
            title: "当前采用产物",
            icon: "checkmark.seal",
            trailing: {
                if !adopted.isEmpty {
                    Button("全部产物") {
                        show(.artifacts)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isEditing)
                }
            }
        ) {

            if adopted.isEmpty {

                Text("还没有采用的产物。在 Workflow 中采用 AI 结果后，会显示在这里。")
                    .font(CosmosDesign.font(.body))
                    .foregroundStyle(.secondary)

            } else {

                VStack(spacing: 0) {

                    ForEach(Array(adopted.prefix(5).enumerated()), id: \.element.id) { index, group in

                        let artifact = group.currentArtifact

                        Button {
                            openArtifactWindow(group)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: CampaignUIFormat.artifactIcon(artifact.type))
                                    .frame(width: 22)
                                    .foregroundStyle(.tint)

                                Text(artifact.name)
                                    .lineLimit(1)

                                Spacer(minLength: 6)

                                CampaignUIVersionBadge(
                                    version: artifact.version,
                                    isCurrent: true
                                )
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < min(adopted.count, 5) - 1 {
                            Divider()
                        }
                    }
                }

                if adopted.count > 5 {
                    Text("另有 \(adopted.count - 5) 项，见“工作产物”。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Local workspace

    private var workspaceCard: some View {

        CampaignUICard(
            title: "本地工作目录",
            icon: "folder",
            info: "在 Mac 的“文稿/Cosmos OS/Workspaces”中为当前活动创建标准文件夹；采用的工作产物会落盘在这里。"
        ) {

            if let path = workspacePathText {
                Text(path)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: CosmosDesign.spacingS) {

                Button {
                    createWorkspace()
                } label: {
                    Label(
                        "创建工作目录",
                        systemImage: "folder.badge.plus"
                    )
                }
                .buttonStyle(.glass)

                Button {
                    openWorkspaceInFinder()
                } label: {
                    Label(
                        "在 Finder 中显示",
                        systemImage: "folder"
                    )
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private var workspacePathText: String? {

        guard let campaign else {
            return nil
        }

        return (
            workflowStore.workspaceFileManager
                .campaignDirectoryURL(
                    provinceName: province?.pathName,
                    campaignName: campaign.name
                )
                .path as NSString
        ).abbreviatingWithTildeInPath
    }

    // MARK: Basic info

    private func basicInfoCard(
        _ campaign: ZhuowangCampaign
    ) -> some View {

        CampaignUICard(
            title: "活动信息",
            icon: "info.circle"
        ) {

            VStack(alignment: .leading, spacing: 0) {

                CampaignUIMetaRow(
                    icon: "textformat",
                    title: "活动名称",
                    value: campaign.name
                )

                CampaignUIMetaRow(
                    icon: "character",
                    title: "英文名称",
                    value:
                        campaign.englishName.isEmpty
                        ? "未填写"
                        : campaign.englishName
                )

                CampaignUIMetaRow(
                    icon: "mappin.and.ellipse",
                    title: "所属范围",
                    value: scopeText
                )

                CampaignUIMetaRow(
                    icon: "calendar",
                    title: "活动时间",
                    value: ZhuowangWorkspaceUI.dates(campaign)
                )

                HStack(alignment: .firstTextBaseline, spacing: CosmosDesign.spacingM) {
                    Image(systemName: campaign.status.systemImage)
                        .frame(width: 20)
                        .foregroundStyle(.secondary)
                    Text("活动状态")
                        .frame(width: 76, alignment: .leading)
                        .foregroundStyle(.secondary)
                    ZhuowangCampaignStatusBadge(status: campaign.status)
                    Spacer(minLength: 0)
                }
                .font(CosmosDesign.font(.body))
                .padding(.vertical, 6)

                CampaignUIMetaRow(
                    icon: "note.text",
                    title: "备注",
                    value:
                        campaign.notes.isEmpty
                        ? "暂无备注"
                        : campaign.notes
                )

                Divider()
                    .padding(.vertical, 6)

                HStack(spacing: CosmosDesign.spacingXL) {
                    Label(
                        "创建 " + CampaignUIFormat.dateTime(campaign.createdAt),
                        systemImage: "plus.circle"
                    )
                    Label(
                        "更新 " + CampaignUIFormat.dateTime(campaign.updatedAt),
                        systemImage: "clock.arrow.circlepath"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }


    // MARK: - Edit Content

    private var editContent: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingL
        ) {

            CampaignUICard(
                title: "基本信息",
                icon: "textformat"
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text("活动名称")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(
                        "活动名称",
                        text: $name
                    )
                    .textFieldStyle(.roundedBorder)
                }

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text("英文名称")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(
                        "英文名称（可选）",
                        text: $englishName
                    )
                    .textFieldStyle(.roundedBorder)
                }

                CampaignUIMetaRow(
                    icon: "mappin.and.ellipse",
                    title: "所属范围",
                    value: scopeText
                )
            }

            CampaignUICard(
                title: "时间与状态",
                icon: "calendar"
            ) {

                DatePicker(
                    "开始日期",
                    selection: $startDate,
                    displayedComponents: .date
                )

                DatePicker(
                    "结束日期",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )

                Picker(
                    "活动状态",
                    selection: $status
                ) {

                    ForEach(
                        ZhuowangCampaignStatus.allCases
                    ) { campaignStatus in

                        Label(
                            campaignStatus.title,
                            systemImage:
                                campaignStatus.systemImage
                        )
                        .tag(campaignStatus)
                    }
                }
                .pickerStyle(.menu)
            }

            CampaignUICard(
                title: "备注",
                icon: "note.text"
            ) {

                TextEditor(
                    text: $notes
                )
                .font(.body)
                .frame(
                    minHeight: 120
                )
                .padding(8)
                .background(
                    Color.primary.opacity(0.025),
                    in: RoundedRectangle(
                        cornerRadius: CosmosDesign.cornerRadiusSmall,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius:
                            CosmosDesign.cornerRadiusSmall,
                        style: .continuous
                    )
                    .stroke(
                        Color.primary.opacity(0.07),
                        lineWidth: 1
                    )
                }
            }
        }
    }


    // MARK: - Artifacts

    private struct ArtifactStepSection: Identifiable {
        let id: String
        let title: String
        let groups: [ZhuowangArtifactVersionGroup]
    }

    /// Groups the logical artifacts under the Workflow step that produced them.
    private var artifactSections: [ArtifactStepSection] {

        let steps = workflow.map(ZhuowangWorkflowUIModel.enabledSteps(in:)) ?? []
        var remaining = artifactGroups
        var sections: [ArtifactStepSection] = []

        for (index, step) in steps.enumerated() {
            let matched = remaining.filter {
                $0.currentArtifact.stepID == step.id
            }
            guard !matched.isEmpty else {
                continue
            }
            remaining.removeAll { group in
                matched.contains { $0.id == group.id }
            }
            sections.append(
                ArtifactStepSection(
                    id: step.id.uuidString,
                    title: String(format: "%02d ", index + 1) + step.title,
                    groups: matched
                )
            )
        }

        if !remaining.isEmpty {
            sections.append(
                ArtifactStepSection(
                    id: "other",
                    title: "其他产物",
                    groups: remaining
                )
            )
        }

        return sections
    }

    private var workflow: ZhuowangCampaignWorkflow? {
        workflowStore.workflow(forCampaignID: campaignID)
    }

    private var artifactsContent: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingL
        ) {

            if campaignArtifacts.isEmpty {

                CosmosEmptyState(
                    icon: "doc.on.doc",
                    title: "还没有工作产物",
                    detail: "之后 AI Workflow 生成并由你确认的策划案、Figma 原型、客服文档等内容，会统一出现在这里。"
                )
                .frame(minHeight: 260)
                .campaignUICardSurface()

            } else {

                HStack(alignment: .firstTextBaseline, spacing: 10) {

                    Text("集中保存该活动最终确认的策划案、原型、客服文档、流程图和其他工作文件。")
                        .font(CosmosDesign.font(.body))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Text(
                        campaignArtifacts.count != artifactGroups.count
                        ? "\(artifactGroups.count) 项 · \(campaignArtifacts.count) 个版本"
                        : "\(artifactGroups.count) 项"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }

                ForEach(
                    Array(artifactSections.enumerated()),
                    id: \.element.id
                ) { index, section in

                    VStack(
                        alignment: .leading,
                        spacing: CosmosDesign.spacingM
                    ) {

                        CampaignUISectionTitle(
                            section.title,
                            count: section.groups.count
                        )

                        LazyVGrid(
                            columns: [
                                GridItem(
                                    .adaptive(minimum: 240, maximum: 360),
                                    spacing: CosmosDesign.spacingM,
                                    alignment: .top
                                )
                            ],
                            spacing: CosmosDesign.spacingM
                        ) {

                            ForEach(section.groups) { group in

                                let artifact = group.currentArtifact

                                CampaignUIArtifactCard(
                                    icon: CampaignUIFormat.artifactIcon(artifact.type),
                                    name: artifact.name,
                                    typeTitle: artifact.type.title,
                                    version: artifact.version,
                                    isCurrent: artifact.isApprovedVersion,
                                    versionCount: group.versions.count,
                                    fileState:
                                        artifactFileExists(artifact)
                                        ? .present
                                        : .missing
                                ) {
                                    openArtifactWindow(group)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .campaignUIEntrance(index)
                }
            }
        }
    }


    private var campaignArtifacts:
        [ZhuowangArtifact] {

        workflowStore.artifacts(
            forCampaignID: campaignID
        )
    }


    private var artifactGroups:
        [ZhuowangArtifactVersionGroup] {

        let grouped =
            Dictionary(
                grouping:
                    campaignArtifacts
            ) {
                $0.versionGroupKey
            }

        return grouped
            .compactMap {
                name,
                artifacts
                -> ZhuowangArtifactVersionGroup?
                in

                let versions =
                    artifacts.sorted {
                        $0.version
                            > $1.version
                    }

                guard
                    let current =
                        versions.first(
                            where: {
                                $0.isApprovedVersion
                            }
                        )
                        ?? versions.first
                else {
                    return nil
                }

                return ZhuowangArtifactVersionGroup(
                    name: name,
                    currentArtifact:
                        current,
                    versions:
                        versions
                )
            }
            .sorted {
                $0.currentArtifact.updatedAt
                    > $1.currentArtifact.updatedAt
            }
    }


    private func openArtifactWindow(
        _ group: ZhuowangArtifactVersionGroup
    ) {

        ZhuowangArtifactWindowManager.shared.open(
            artifactName:
                group.name,
            initialArtifactID:
                group.currentArtifact.id,
            campaignID:
                campaignID,
            workflowStore:
                workflowStore
        )
    }

    private func openArtifactWindow(
        _ artifact: ZhuowangArtifact
    ) {

        ZhuowangArtifactWindowManager.shared.open(
            artifactName:
                artifact.versionGroupKey,
            initialArtifactID:
                artifact.id,
            campaignID:
                campaignID,
            workflowStore:
                workflowStore
        )
    }


    private func artifactFileExists(
        _ artifact: ZhuowangArtifact
    ) -> Bool {

        let path =
            artifact.location
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !path.isEmpty else {
            return false
        }

        return workflowStore.workspaceFileManager
            .fileExists(
                atPath: path
            )
    }


    // MARK: - Missing Campaign

    private var missingCampaignView: some View {

        VStack(
            spacing: CosmosDesign.spacingM
        ) {

            Image(
                systemName:
                    "exclamationmark.triangle"
            )
            .font(
                .system(
                    size: 28,
                    weight: .medium
                )
            )
            .foregroundStyle(.secondary)

            Text("找不到这个活动")
                .font(.headline)

            Text(
                "该活动可能已经被删除。"
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            Button("关闭") {
                dismiss()
            }
            .buttonStyle(.glassProminent)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }


    // MARK: - Data

    private var campaign:
        ZhuowangCampaign? {

        store.campaign(
            id: campaignID
        )
    }


    private var scopeText: String {

        if let province {
            return "\(province.name)福利中心"
        }

        if let module {
            return module.name
        }

        if campaign?.scopeType == .national {
            return "全国促活"
        }

        return "卓望工作区"
    }


    private func recoverLocalWorkflowIfNeeded() {

        guard let campaign else {
            return
        }

        let summary =
            workflowStore
                .recoverWorkflowFromLocalFiles(
                    campaign:
                        campaign,
                    provinceName:
                        province?.pathName
                )

        guard
            summary.didRecoverAnything
        else {
            return
        }

        var lines: [String] = [
            "已从本地工作目录恢复 Workflow 数据。",
            "",
            "恢复工作产物：\(summary.importedArtifacts) 个",
            "恢复已完成步骤：\(summary.restoredSteps) 个"
        ]

        if !summary
            .ambiguousArtifactNames
            .isEmpty {

            lines.append("")
            lines.append(
                "以下工作产物存在多个本地版本，系统暂时采用最高版本："
            )

            lines.append(
                summary
                    .ambiguousArtifactNames
                    .joined(
                        separator: "、"
                    )
            )

            lines.append(
                "如需使用其他版本，可在“工作产物”中重新设为当前版本。"
            )
        }

        workspaceMessage =
            lines.joined(
                separator: "\n"
            )

        showWorkspaceAlert = true
    }


    private func migrateLegacyArtifactsIfNeeded() {

        guard let campaign else {
            return
        }

        _ =
            workflowStore
                .migrateLegacyArtifactsToLocalFiles(
                    campaign:
                        campaign,
                    provinceName:
                        province?.pathName
                )
    }


    private func loadDraft() {

        guard let campaign else {
            return
        }

        name = campaign.name
        englishName = campaign.englishName
        startDate = campaign.startDate
        endDate = campaign.endDate
        status = campaign.status
        notes = campaign.notes
    }


    private func beginEditing() {

        loadDraft()

        withAnimation(
            .easeInOut(
                duration:
                    CosmosDesign.animationFast
            )
        ) {
            isEditing = true
        }
    }


    private func cancelEditing() {

        loadDraft()

        withAnimation(
            .easeInOut(
                duration:
                    CosmosDesign.animationFast
            )
        ) {
            isEditing = false
        }
    }


    private func saveChanges() {

        guard var campaign else {
            return
        }

        campaign.name =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        campaign.englishName =
            englishName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        campaign.startDate = startDate
        campaign.endDate = endDate
        campaign.status = status

        campaign.notes =
            notes.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let result = store.updateCampaign(
            campaign
        )

        guard result.succeeded else {
            workspaceMessage =
                result.userMessage
                ?? "活动未保存。"
            showWorkspaceAlert = true
            return
        }

        loadDraft()

        withAnimation(
            .easeInOut(
                duration:
                    CosmosDesign.animationFast
            )
        ) {
            isEditing = false
        }
    }


    private func openWorkspaceInFinder() {

        guard let campaign else {
            return
        }

        do {

            let workspaceURL =
                try workflowStore.workspaceFileManager
                    .createCampaignWorkspace(
                        provinceName:
                            province?.pathName,
                        campaignName:
                            campaign.name
                    )

            NSWorkspace.shared.open(
                workspaceURL
            )

        } catch {

            workspaceMessage =
                """
                无法打开工作目录：

                \(error.localizedDescription)
                """

            showWorkspaceAlert = true
        }
    }


    private func createWorkspace() {

        guard let campaign else {
            return
        }

        do {

            let workspaceURL =
                try workflowStore.workspaceFileManager
                    .createCampaignWorkspace(
                        provinceName:
                            province?.pathName,
                        campaignName:
                            campaign.name
                    )

            workspaceMessage =
                """
                已成功创建工作目录：

                \(workspaceURL.path)
                """

        } catch {

            workspaceMessage =
                """
                创建工作目录失败：

                \(error.localizedDescription)
                """
        }

        showWorkspaceAlert = true
    }


    private func deleteCampaign() {

        let result = store.deleteCampaign(
            id: campaignID
        )

        guard result.succeeded else {
            workspaceMessage =
                result.userMessage
                ?? "活动未删除。"
            showWorkspaceAlert = true
            return
        }

        dismiss()
    }
}



// MARK: - Artifact Version Group

private struct ZhuowangArtifactVersionGroup:
    Identifiable {

    let name: String
    let currentArtifact: ZhuowangArtifact
    let versions: [ZhuowangArtifact]

    var id: String {
        name
    }
}

// MARK: - Artifact Detail

private struct ZhuowangArtifactDetailView: View {

    @ObservedObject
    var workflowStore: ZhuowangWorkflowStore

    let campaignID: UUID
    let artifactName: String

    @State
    private var selectedArtifactID: UUID

    @State
    private var copied = false

    @State
    private var contentMode: ArtifactDetailContentMode = .initial

    init(
        workflowStore: ZhuowangWorkflowStore,
        campaignID: UUID,
        artifactName: String,
        initialArtifactID: UUID
    ) {

        self.workflowStore =
            workflowStore

        self.campaignID =
            campaignID

        self.artifactName =
            artifactName

        _selectedArtifactID =
            State(
                initialValue:
                    initialArtifactID
            )
    }


    var body: some View {

        VStack(spacing: 0) {

            header
                .background(.bar)
            Divider()

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: CosmosDesign.spacingL
                ) {

                    summaryCard

                    if versions.count > 1 {
                        versionHistorySection
                    }

                    contentSection
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
                    maxWidth: 940
                )
                .frame(maxWidth: .infinity)
            }

            Divider()
            footer
                .background(.bar)
        }
        .frame(
            minWidth: 820,
            minHeight: 680
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .modifier(CosmosMotionPolicy())
    }


    private var header: some View {

        CampaignUIHeader(
            icon: CampaignUIFormat.artifactIcon(artifact?.type ?? .other),
            title: artifact?.name ?? artifactName,
            subtitle:
                versions.count > 1
                ? "共 \(versions.count) 个版本"
                : "仅此版本"
        ) {

            if let artifact,
               !artifact.isApprovedVersion {

                Button {
                    setSelectedAsCurrent()
                } label: {
                    Label(
                        "设为当前版本",
                        systemImage:
                            "checkmark.seal"
                    )
                }
                .buttonStyle(.glassProminent)
            }
        }
    }


    private var summaryCard: some View {

        CampaignUICard(
            title: "产物信息",
            icon: "info.circle",
            trailing: {
                if let artifact {
                    if artifact.isApprovedVersion {
                        CampaignUIStatusPill(
                            text: "当前采用版本",
                            icon: "checkmark.seal.fill",
                            tone: .success
                        )
                    } else {
                        CampaignUIStatusPill(
                            text: "历史版本",
                            icon: "clock.arrow.circlepath",
                            tone: .neutral
                        )
                    }
                }
            }
        ) {

            HStack(
                alignment: .top,
                spacing: CosmosDesign.spacingL
            ) {

                CampaignUIKeyValue(
                    title: "文件类型",
                    value:
                        artifact?.type.title
                        ?? "—"
                )

                CampaignUIKeyValue(
                    title: "版本",
                    value:
                        artifact.map {
                            "V\($0.version)"
                        }
                        ?? "—"
                )

                CampaignUIKeyValue(
                    title: "来源步骤",
                    value:
                        sourceStepName
                )

                CampaignUIKeyValue(
                    title: "来源 AI",
                    value:
                        sourceAIName
                )

                CampaignUIKeyValue(
                    title: "本地文件",
                    value:
                        localFileExists
                        ? "已落盘"
                        : "未落盘"
                )
            }

            if let artifact {
                Text(
                    "创建于 "
                    + CampaignUIFormat.dateTime(
                        artifact.createdAt
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }


    private var versionHistorySection:
        some View {

        CampaignUICard(
            title: "版本历史",
            icon: "clock.arrow.circlepath",
            trailing: {
                Button {
                    openArtifactVersionCompareWorkspace()
                } label: {
                    Label(
                        "比较版本",
                        systemImage: "rectangle.split.2x1"
                    )
                }
                .buttonStyle(.glass)
                .disabled(!canCompareVersions)
            }
        ) {

            VStack(spacing: 0) {

                ForEach(
                    Array(
                        versions.enumerated()
                    ),
                    id: \.element.id
                ) { index, version in

                    let selected = selectedArtifactID == version.id

                    Button {
                        selectedArtifactID =
                            version.id
                        contentMode = .initial
                    } label: {

                        HStack(
                            spacing:
                                CosmosDesign.spacingM
                        ) {

                            CampaignUIVersionBadge(
                                version: version.version,
                                isCurrent: version.isApprovedVersion
                            )
                            .frame(width: 70, alignment: .leading)

                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {

                                Text(
                                    version.isApprovedVersion
                                    ? "版本 V\(version.version) · 当前采用"
                                    : "版本 V\(version.version)"
                                )
                                .fontWeight(.medium)

                                HStack(
                                    spacing: 6
                                ) {

                                    Text(
                                        sourceAIName(
                                            for: version
                                        )
                                    )

                                    Text("·")

                                    Text(
                                        CampaignUIFormat.dateTime(
                                            version.createdAt
                                        )
                                    )
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            CampaignUIFilePill(
                                state:
                                    fileExists(version)
                                    ? .present
                                    : .missing
                            )

                            Image(
                                systemName:
                                    "checkmark.circle.fill"
                            )
                            .foregroundStyle(.tint)
                            .opacity(selected ? 1 : 0)
                        }
                        .padding(
                            .vertical,
                            CosmosDesign.spacingS + 2
                        )
                        .padding(
                            .horizontal,
                            CosmosDesign.spacingS
                        )
                        .background(
                            selected
                            ? Color.accentColor.opacity(0.08)
                            : Color.clear,
                            in: RoundedRectangle(
                                cornerRadius: CosmosDesign.cornerRadiusSmall,
                                style: .continuous
                            )
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .campaignUIAnimation(value: selected)

                    if index
                        < versions.count - 1 {

                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }


    private var contentSection: some View {

        CampaignUICard(
            title: "产物查看",
            icon: "eye",
            trailing: {
                Picker(
                    "产物查看方式",
                    selection: $contentMode
                ) {
                    Text("Preview Workspace")
                        .tag(ArtifactDetailContentMode.preview)
                    Text("查看源码")
                        .tag(ArtifactDetailContentMode.source)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 300)
            }
        ) {

            if contentMode == .preview {
                previewWorkspaceEntry
            } else {
                sourceContent
            }
        }
    }


    private var previewWorkspaceEntry: some View {
        VStack(spacing: CosmosDesign.spacingM) {
            Image(systemName: "macwindow")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.tint)

            Text("在 Artifact Review Workspace 中查看")
                .font(.headline)

            Text(
                "统一预览窗口会根据 Artifact 类型选择 Renderer；未接入的类型将显示安全提示。"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button {
                openArtifactReviewWorkspace()
            } label: {
                Label(
                    "打开预览",
                    systemImage: "arrow.up.right.square"
                )
            }
            .buttonStyle(.glassProminent)
            .disabled(artifact == nil)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(CosmosDesign.spacingL)
        .background(
            Color.primary.opacity(0.018),
            in: RoundedRectangle(
                cornerRadius: CosmosDesign.cornerRadiusMedium,
                style: .continuous
            )
        )
    }


    private var sourceContent: some View {
        Group {

            if cleanContent.isEmpty {

                VStack(
                    spacing:
                        CosmosDesign.spacingM
                ) {

                    Image(
                        systemName:
                            "doc.text.magnifyingglass"
                    )
                    .font(
                        .system(
                            size: 24,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(.secondary)

                    Text(
                        "这个版本暂时没有可显示的正文"
                    )
                    .font(.headline)

                    if !cleanLocation.isEmpty {

                        Text(cleanLocation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: 180
                )

            } else {

                Text(cleanContent)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            }
        }
        .padding(CosmosDesign.spacingL)
        .background(
            Color.primary.opacity(0.018),
            in: RoundedRectangle(
                cornerRadius: CosmosDesign.cornerRadiusMedium,
                style: .continuous
            )
        )
    }


    private var footer: some View {

        HStack(
            spacing: CosmosDesign.spacingM
        ) {

            if !cleanLocation.isEmpty {

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(
                        localFileExists
                        ? "已落盘 · 当前查看 V\(artifact?.version ?? 0)"
                        : "本地文件不可用"
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        localFileExists
                        ? Color.green
                        : Color.orange
                    )

                    Text(cleanLocation)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            Spacer()

            if localFileExists {

                Button {
                    revealInFinder()
                } label: {
                    Label(
                        "Finder 中显示",
                        systemImage: "folder"
                    )
                }
                .buttonStyle(.glass)

                Button {
                    openLocalFile()
                } label: {
                    Label(
                        "打开文件",
                        systemImage:
                            "arrow.up.right.square"
                    )
                }
                .buttonStyle(.glass)
            }

            Button {
                copyContent()
            } label: {

                Label(
                    copied
                    ? "已复制"
                    : "复制内容",
                    systemImage:
                        copied
                        ? "checkmark"
                        : "doc.on.doc"
                )
            }
            .buttonStyle(.glassProminent)
            .disabled(cleanContent.isEmpty)
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


    private var versions:
        [ZhuowangArtifact] {

        workflowStore
            .artifacts(
                forCampaignID:
                    campaignID
            )
            .filter {
                $0.versionGroupKey == artifactName
            }
            .sorted {
                $0.version > $1.version
            }
    }


    private var canCompareVersions: Bool {
        versions.count >= 2
    }


    private var comparisonItems:
        [ArtifactVersionComparisonItem] {

        versions.map { version in
            ArtifactVersionComparisonItem(
                artifactID: version.id,
                version: version.version,
                isCurrent: version.isApprovedVersion,
                document: ArtifactReviewDocument(
                    artifact: version,
                    providerName: sourceAIName(
                        for: version
                    )
                )
            )
        }
    }


    private var artifact:
        ZhuowangArtifact? {

        versions.first {
            $0.id == selectedArtifactID
        }
        ?? currentApprovedArtifact
        ?? versions.first
    }


    private var currentApprovedArtifact:
        ZhuowangArtifact? {

        versions.first {
            $0.isApprovedVersion
        }
    }


    private var workflow:
        ZhuowangCampaignWorkflow? {

        workflowStore.workflow(
            forCampaignID:
                campaignID
        )
    }


    private var sourceStepName: String {

        guard
            let artifact,
            let stepID =
                artifact.stepID,
            let step =
                workflow?
                    .steps.first(
                        where: {
                            $0.id == stepID
                        }
                    )
        else {
            return "未关联"
        }

        return step.title
    }


    private var sourceAIName: String {

        guard let artifact else {
            return "未记录"
        }

        return sourceAIName(
            for: artifact
        )
    }


    private func sourceAIName(
        for artifact:
            ZhuowangArtifact
    ) -> String {

        guard
            let runID =
                artifact.runID,
            let run =
                workflow?
                    .aiRuns.first(
                        where: {
                            $0.id == runID
                        }
                    )
        else {
            return "未记录"
        }

        if let provider =
            workflowStore.provider(
                id: run.providerID
            ) {

            return provider.name
        }

        let modelName =
            run.modelName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        return modelName.isEmpty
            ? "未记录"
            : modelName
    }


    private var cleanLocation: String {

        artifact?
            .location
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        ?? ""
    }


    private var localFileURL: URL? {

        guard !cleanLocation.isEmpty else {
            return nil
        }

        return URL(
            fileURLWithPath:
                cleanLocation
        )
    }


    private var localFileExists: Bool {

        guard let artifact else {
            return false
        }

        return fileExists(
            artifact
        )
    }


    private func fileExists(
        _ artifact:
            ZhuowangArtifact
    ) -> Bool {

        let path =
            artifact.location
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !path.isEmpty else {
            return false
        }

        return workflowStore.workspaceFileManager
            .fileExists(
                atPath: path
            )
    }


    private var cleanContent: String {

        artifact?
            .content?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        ?? ""
    }


    private func setSelectedAsCurrent() {

        guard
            let artifact,
            let workflow
        else {
            return
        }

        workflowStore.approveArtifact(
            workflowID:
                workflow.id,
            artifactID:
                artifact.id
        )
    }


    private func openLocalFile() {

        guard
            let localFileURL,
            localFileExists
        else {
            return
        }

        NSWorkspace.shared.open(
            localFileURL
        )
    }


    private func openArtifactReviewWorkspace() {
        guard let artifact else {
            return
        }

        let providerName = artifact.providerID.flatMap {
            workflowStore.provider(id: $0)?.name
        }
        let document = ArtifactReviewDocument(
            artifact: artifact,
            providerName: providerName
        )

        ArtifactReviewWindowManager.shared.open(
            document: document
        )
    }


    private func openArtifactVersionCompareWorkspace() {
        guard canCompareVersions else {
            return
        }

        ArtifactVersionCompareWindowManager.shared.open(
            campaignID: campaignID,
            versionGroupKey: artifactName,
            artifactName: artifact?.name ?? artifactName,
            items: comparisonItems,
            selectedArtifactID: selectedArtifactID
        )
    }


    private func revealInFinder() {

        guard
            let localFileURL,
            localFileExists
        else {
            return
        }

        NSWorkspace.shared
            .activateFileViewerSelecting(
                [localFileURL]
            )
    }


    private func copyContent() {

        guard !cleanContent.isEmpty else {
            return
        }

        NSPasteboard.general.clearContents()

        NSPasteboard.general.setString(
            cleanContent,
            forType: .string
        )

        copied = true

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1.5
        ) {
            copied = false
        }
    }
}


// MARK: - Artifact Native Window Manager

private final class ZhuowangArtifactWindowManager:
    NSObject,
    NSWindowDelegate {

    static let shared =
        ZhuowangArtifactWindowManager()

    private var controllers:
        [String: NSWindowController] = [:]

    private override init() {
        super.init()
    }


    func open(
        artifactName: String,
        initialArtifactID: UUID,
        campaignID: UUID,
        workflowStore: ZhuowangWorkflowStore
    ) {

        let windowKey =
            campaignID.uuidString
            + "::"
            + artifactName

        if let existing =
            controllers[windowKey] {

            existing.window?
                .makeKeyAndOrderFront(nil)

            NSApp.activate(
                ignoringOtherApps: true
            )

            return
        }

        let rootView =
            ZhuowangArtifactDetailView(
                workflowStore:
                    workflowStore,
                campaignID:
                    campaignID,
                artifactName:
                    artifactName,
                initialArtifactID:
                    initialArtifactID
            )

        let hostingController =
            NSHostingController(
                rootView: rootView
            )

        let window =
            NSWindow(
                contentRect:
                    NSRect(
                        x: 0,
                        y: 0,
                        width: 960,
                        height: 780
                    ),
                styleMask: [
                    .titled,
                    .closable,
                    .miniaturizable,
                    .resizable
                ],
                backing: .buffered,
                defer: false
            )

        window.title =
            artifactName

        window.titleVisibility =
            .visible

        window.titlebarAppearsTransparent =
            false

        window.minSize =
            NSSize(
                width: 760,
                height: 620
            )

        window.contentViewController =
            hostingController

        window.delegate = self

        window.identifier =
            NSUserInterfaceItemIdentifier(
                windowKey
            )

        let controller =
            NSWindowController(
                window: window
            )

        controllers[windowKey] =
            controller

        window.center()

        controller.showWindow(nil)

        window.makeKeyAndOrderFront(nil)

        NSApp.activate(
            ignoringOtherApps: true
        )
    }


    func windowWillClose(
        _ notification: Notification
    ) {

        guard
            let window =
                notification.object
                    as? NSWindow,
            let windowKey =
                window.identifier?
                    .rawValue
        else {
            return
        }

        controllers.removeValue(
            forKey:
                windowKey
        )
    }
}


// MARK: - Detail Tab

enum ZhuowangCampaignDetailTab:
    String,
    CaseIterable,
    Identifiable {

    case overview
    case workflow
    case artifacts
    /// Only shown for monthly member-activation Campaigns.
    case monthly

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .overview:
            return "概览"

        case .workflow:
            return "AI Workflow"

        case .artifacts:
            return "工作产物"

        case .monthly:
            return "月度清单"
        }
    }

    var englishTitle: String {
        switch self {
        case .overview:
            return "Overview"

        case .workflow:
            return ""

        case .artifacts:
            return "Artifacts"

        case .monthly:
            return "Monthly"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "rectangle.grid.1x2"

        case .workflow:
            return "sparkles"

        case .artifacts:
            return "folder"

        case .monthly:
            return "list.bullet.clipboard"
        }
    }
}
// MARK: - Preview

#Preview {

    let store =
        ZhuowangCampaignStore()

    let province =
        ZhuowangProvince(
            id: UUID(),
            name: "浙江",
            englishName: "Zhejiang"
        )

    return ZhuowangCampaignDetailView(
        store: store,
        workflowStore: ZhuowangWorkflowStore(),
        campaignID:
            UUID(),
        province:
            province,
        module:
            nil
    )
}
