import SwiftUI

struct ZhuowangCampaignDetailView: View {

    @ObservedObject var store: ZhuowangCampaignStore
    @ObservedObject var workflowStore: ZhuowangWorkflowStore

    let campaignID: UUID
    let province: ZhuowangProvince?
    let module: ZhuowangModule?

    @Environment(\.dismiss)
    private var dismiss

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

    @State private var selectedTab: ZhuowangCampaignDetailTab = .overview

    @State private var name = ""
    @State private var englishName = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var status: ZhuowangCampaignStatus = .planning
    @State private var notes = ""

    var body: some View {
        VStack(spacing: 0) {

            header

            Divider()

            if let campaign {

                VStack(spacing: 0) {

                    detailTabs

                    Divider()

                    ScrollView {

                        VStack(
                            alignment: .leading,
                            spacing: CosmosDesign.spacingXL
                        ) {

                            switch selectedTab {

                            case .overview:

                                if isEditing {
                                    editContent
                                } else {
                                    readOnlyContent(campaign)
                                }

                            case .workflow:
                                ZhuowangWorkflowView(
                                    store: workflowStore,
                                    campaign: campaign,
                                    province: province,
                                    module: module
                                )

                            case .artifacts:

                                artifactsContent
                            }
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
                            maxWidth: 860,
                            alignment: .leading
                        )
                    }
                }

            } else {

                missingCampaignView
            }
        }
        .frame(
            minWidth: 700,
            minHeight: 650
        )
        .onAppear {
            loadDraft()
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
    }


    // MARK: - Header

    private var header: some View {
        HStack(
            spacing: CosmosDesign.spacingM
        ) {

            Button {
                dismiss()
            } label: {
                Image(
                    systemName: "chevron.left"
                )
                .frame(
                    width: 28,
                    height: 28
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("返回")

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(
                    isEditing
                    ? "编辑活动"
                    : campaign?.name ?? "活动详情"
                )
                .font(.title2)
                .fontWeight(.semibold)

                Text(
                    isEditing
                    ? "Edit Campaign"
                    : "Campaign Detail"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if campaign != nil {
                if isEditing {

                    Button("取消") {
                        cancelEditing()
                    }

                    Button("保存") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        name
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty
                    )

                } else {

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

                    Button {
                        beginEditing()
                    } label: {
                        Label(
                            "编辑",
                            systemImage: "pencil"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
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

    // MARK: - Detail Tabs

    private var detailTabs: some View {

        HStack(spacing: 6) {

            ForEach(
                ZhuowangCampaignDetailTab.allCases
            ) { tab in

                Button {

                    guard !isEditing else {
                        return
                    }

                    withAnimation(
                        .easeInOut(
                            duration:
                                CosmosDesign.animationFast
                        )
                    ) {
                        selectedTab = tab
                    }

                } label: {

                    HStack(spacing: 7) {

                        Image(
                            systemName:
                                tab.systemImage
                        )

                        Text(tab.title)

                        if !tab.englishTitle.isEmpty {

                            Text(tab.englishTitle)
                                .font(.caption2)
                                .foregroundStyle(
                                    selectedTab == tab
                                    ? Color.accentColor.opacity(0.75)
                                    : Color.secondary
                                )
                        }
                    }
                    .font(
                        .system(
                            size: 13,
                            weight:
                                selectedTab == tab
                                ? .semibold
                                : .medium
                        )
                    )
                    .padding(
                        .horizontal,
                        13
                    )
                    .padding(
                        .vertical,
                        8
                    )
                    .foregroundStyle(
                        selectedTab == tab
                        ? Color.accentColor
                        : Color.primary
                    )
                    .background(
                        selectedTab == tab
                        ? Color.accentColor.opacity(0.09)
                        : Color.clear
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 9,
                            style: .continuous
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(isEditing)
                .opacity(
                    isEditing && selectedTab != tab
                    ? 0.45
                    : 1
                )
            }

            Spacer()
        }
        .padding(
            .horizontal,
            CosmosDesign.spacingL
        )
        .padding(
            .vertical,
            9
        )
        .background(
            Color(nsColor: .controlBackgroundColor)
                .opacity(0.25)
        )
    }
    // MARK: - Artifacts

    private var artifactsContent: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingXL
        ) {

            HStack(
                alignment: .top
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text("工作产物")
                        .font(
                            .system(
                                size: 25,
                                weight: .semibold
                            )
                        )

                    Text("Artifacts")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text(
                        "集中保存该活动最终确认的策划案、Figma 原型、客服文档、流程图和其他工作文件。"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }

                Spacer()

                Text("\(campaignArtifacts.count) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if campaignArtifacts.isEmpty {

                VStack(
                    spacing: CosmosDesign.spacingM
                ) {

                    ZStack {

                        Circle()
                            .fill(
                                Color.accentColor.opacity(0.08)
                            )
                            .frame(
                                width: 58,
                                height: 58
                            )

                        Image(
                            systemName: "doc.on.doc"
                        )
                        .font(
                            .system(
                                size: 22,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(.tint)
                    }

                    Text("还没有工作产物")
                        .font(.headline)

                    Text(
                        "之后 AI Workflow 生成并由你确认的策划案、Figma 原型、客服文档等内容，会统一出现在这里。"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: 300
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

            } else {

                VStack(spacing: 0) {

                    ForEach(
                        Array(
                            campaignArtifacts.enumerated()
                        ),
                        id: \.element.id
                    ) { index, artifact in

                        HStack(
                            spacing:
                                CosmosDesign.spacingM
                        ) {

                            ZStack {

                                RoundedRectangle(
                                    cornerRadius: 9,
                                    style: .continuous
                                )
                                .fill(
                                    Color.accentColor.opacity(0.07)
                                )
                                .frame(
                                    width: 38,
                                    height: 38
                                )

                                Image(
                                    systemName:
                                        artifactIcon(
                                            artifact.type
                                        )
                                )
                                .font(
                                    .system(
                                        size: 15,
                                        weight: .medium
                                    )
                                )
                                .foregroundStyle(.tint)
                            }

                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {

                                Text(artifact.name)
                                    .fontWeight(.medium)

                                HStack(spacing: 6) {

                                    Text(artifact.type.title)

                                    Text("·")

                                    Text("V\(artifact.version)")

                                    if artifact.isApprovedVersion {

                                        Text("·")

                                        Text("已采用")
                                            .foregroundStyle(.green)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(
                                systemName: "chevron.right"
                            )
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                        .padding(
                            .horizontal,
                            CosmosDesign.spacingL
                        )
                        .padding(
                            .vertical,
                            CosmosDesign.spacingM
                        )

                        if index
                            < campaignArtifacts.count - 1 {

                            Divider()
                                .padding(.leading, 72)
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
    }


    private var campaignArtifacts:
        [ZhuowangArtifact] {

        workflowStore.artifacts(
            forCampaignID: campaignID
        )
    }


    private func artifactIcon(
        _ type: ZhuowangArtifactType
    ) -> String {

        switch type {

        case .markdown:
            return "doc.text"

        case .word:
            return "doc.richtext"

        case .pdf:
            return "doc.text"

        case .excel:
            return "tablecells"

        case .image:
            return "photo"

        case .figma:
            return "square.on.square"

        case .html:
            return "chevron.left.forwardslash.chevron.right"

        case .flowchart:
            return "point.3.connected.trianglepath.dotted"

        case .prompt:
            return "text.quote"

        case .url:
            return "link"

        case .other:
            return "doc"
        }
    }
    // MARK: - Read Only

    private func readOnlyContent(
        _ campaign: ZhuowangCampaign
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingXL
        ) {

            heroCard(campaign)

            detailSection(
                title: "基本信息",
                subtitle: "Basic Information"
            ) {

                detailRow(
                    icon: "textformat",
                    title: "活动名称",
                    value: campaign.name
                )

                Divider()

                detailRow(
                    icon: "character",
                    title: "英文名称",
                    value:
                        campaign.englishName.isEmpty
                        ? "未填写"
                        : campaign.englishName
                )

                Divider()

                detailRow(
                    icon: "mappin.and.ellipse",
                    title: "所属范围",
                    value: scopeText
                )
            }

            detailSection(
                title: "时间与状态",
                subtitle: "Schedule & Status"
            ) {

                detailRow(
                    icon: "calendar",
                    title: "活动时间",
                    value: campaign.dateRangeText
                )

                Divider()

                HStack(
                    spacing: CosmosDesign.spacingM
                ) {

                    Image(
                        systemName:
                            campaign.status.systemImage
                    )
                    .frame(width: 22)
                    .foregroundStyle(.secondary)

                    Text("活动状态")
                        .frame(
                            width: 90,
                            alignment: .leading
                        )
                        .foregroundStyle(.secondary)

                    ZhuowangCampaignStatusBadge(
                        status: campaign.status
                    )

                    Spacer()
                }
                .padding(.vertical, 11)
            }

            detailSection(
                title: "备注",
                subtitle: "Notes"
            ) {

                if campaign.notes.isEmpty {
                    Text("暂无备注")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)

                } else {
                    Text(campaign.notes)
                        .textSelection(.enabled)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .padding(.vertical, 4)
                }
            }

            detailSection(
                title: "记录信息",
                subtitle: "Record Information"
            ) {

                detailRow(
                    icon: "plus.circle",
                    title: "创建时间",
                    value:
                        formattedDateTime(
                            campaign.createdAt
                        )
                )

                Divider()

                detailRow(
                    icon: "clock.arrow.circlepath",
                    title: "最后更新",
                    value:
                        formattedDateTime(
                            campaign.updatedAt
                        )
                )
            }
        }
    }


    // MARK: - Hero Card

    private func heroCard(
        _ campaign: ZhuowangCampaign
    ) -> some View {

        HStack(
            spacing: CosmosDesign.spacingL
        ) {

            ZStack {
                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign.cornerRadiusMedium,
                    style: .continuous
                )
                .fill(
                    Color.accentColor.opacity(0.09)
                )
                .frame(
                    width: 56,
                    height: 56
                )

                Image(
                    systemName:
                        campaign.status.systemImage
                )
                .font(
                    .system(
                        size: 22,
                        weight: .medium
                    )
                )
                .foregroundStyle(.tint)
            }

            VStack(
                alignment: .leading,
                spacing: 6
            ) {

                Text(campaign.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 10) {

                    Text(scopeText)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(campaign.dateRangeText)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Spacer()

            ZhuowangCampaignStatusBadge(
                status: campaign.status
            )
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


    // MARK: - Edit Content

    private var editContent: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingXL
        ) {

            detailSection(
                title: "基本信息",
                subtitle: "Basic Information"
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

                Divider()

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

                Divider()

                detailRow(
                    icon: "mappin.and.ellipse",
                    title: "所属范围",
                    value: scopeText
                )
            }

            detailSection(
                title: "时间",
                subtitle: "Schedule"
            ) {

                DatePicker(
                    "开始日期",
                    selection: $startDate,
                    displayedComponents: .date
                )

                Divider()

                DatePicker(
                    "结束日期",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )
            }

            detailSection(
                title: "状态",
                subtitle: "Status"
            ) {

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

            detailSection(
                title: "备注",
                subtitle: "Notes"
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
                    Color.primary.opacity(0.025)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            CosmosDesign.cornerRadiusSmall,
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


    // MARK: - Detail Section

    private func detailSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {

            CosmosSectionTitle(
                title: title,
                subtitle: subtitle
            )

            VStack(
                alignment: .leading,
                spacing: 0
            ) {
                content()
            }
            .padding(
                .horizontal,
                CosmosDesign.spacingL
            )
            .padding(
                .vertical,
                CosmosDesign.spacingS
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
    }


    // MARK: - Detail Row

    private func detailRow(
        icon: String,
        title: String,
        value: String
    ) -> some View {

        HStack(
            spacing: CosmosDesign.spacingM
        ) {

            Image(
                systemName: icon
            )
            .frame(width: 22)
            .foregroundStyle(.secondary)

            Text(title)
                .frame(
                    width: 90,
                    alignment: .leading
                )
                .foregroundStyle(.secondary)

            Text(value)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.vertical, 11)
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
            .buttonStyle(.borderedProminent)
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

        store.updateCampaign(
            campaign
        )

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


    private func deleteCampaign() {

        store.deleteCampaign(
            id: campaignID
        )

        dismiss()
    }


    private func formattedDateTime(
        _ date: Date
    ) -> String {

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier: "zh_CN"
            )

        formatter.dateFormat =
            "yyyy.MM.dd HH:mm"

        return formatter.string(
            from: date
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
