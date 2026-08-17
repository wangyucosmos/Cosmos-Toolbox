import SwiftUI

struct ZhuowangCampaignView: View {

    @ObservedObject var store: ZhuowangCampaignStore

    let province: ZhuowangProvince?
    let module: ZhuowangModule?

    @State private var searchText = ""
    @State private var selectedStatus: ZhuowangCampaignStatus?
    @State private var showCreateSheet = false
    @State private var selectedCampaign: ZhuowangCampaign?

    @StateObject private var workflowStore = ZhuowangWorkflowStore()

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingXL
        ) {

            header

            filterBar

            if filteredCampaigns.isEmpty {
                emptyState
            } else {
                campaignList
            }
        }
    }


    // MARK: - Header

    private var header: some View {
        HStack(
            alignment: .top,
            spacing: CosmosDesign.spacingXL
        ) {

            VStack(
                alignment: .leading,
                spacing: CosmosDesign.spacingS
            ) {

                Text("活动")
                    .font(
                        .system(
                            size: 26,
                            weight: .semibold
                        )
                    )

                Text("Campaigns")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(scopeDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            Spacer()

            Button {
                showCreateSheet = true
            } label: {
                Label(
                    "新建活动",
                    systemImage: "plus"
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showCreateSheet) {
            ZhuowangCampaignCreateView(
                store: store,
                province: province,
                module: module
            )
        }
        .sheet(item: $selectedCampaign) { campaign in

            ZhuowangCampaignDetailView(
                store: store,
                workflowStore: workflowStore,
                campaignID: campaign.id,
                province: province,
                module: module
            )
        }
    }


    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(
            spacing: CosmosDesign.spacingM
        ) {

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(
                    "搜索活动名称",
                    text: $searchText
                )
                .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: 320)
            .background(
                Color.primary.opacity(0.035)
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
                    Color.primary.opacity(0.06),
                    lineWidth: 1
                )
            }

            Menu {
                Button("全部状态") {
                    selectedStatus = nil
                }

                Divider()

                ForEach(
                    ZhuowangCampaignStatus.allCases
                ) { status in

                    Button(status.title) {
                        selectedStatus = status
                    }
                }

            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle")

                    Text(
                        selectedStatus?.title
                        ?? "全部状态"
                    )

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Color.primary.opacity(0.03)
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
                        Color.primary.opacity(0.06),
                        lineWidth: 1
                    )
                }
            }
            .menuStyle(.borderlessButton)

            Spacer()

            Text("\(filteredCampaigns.count) 个活动")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }


    // MARK: - Campaign List

    private var campaignList: some View {
        VStack(spacing: 0) {

            ForEach(
                Array(filteredCampaigns.enumerated()),
                id: \.element.id
            ) { index, campaign in

                ZhuowangCampaignRow(
                    campaign: campaign
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedCampaign = campaign
                }

                if index
                    < filteredCampaigns.count - 1 {

                    Divider()
                        .padding(.leading, 56)
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


    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: CosmosDesign.spacingM) {

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
                    systemName: "megaphone"
                )
                .font(
                    .system(
                        size: 23,
                        weight: .medium
                    )
                )
                .foregroundStyle(.tint)
            }

            Text(emptyStateTitle)
                .font(.headline)

            Text(emptyStateDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            if searchText.isEmpty
                && selectedStatus == nil {

                Button {
                    showCreateSheet = true
                } label: {
                    Label(
                        "创建第一个活动",
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
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
    }


    // MARK: - Filtering

    private var filteredCampaigns: [ZhuowangCampaign] {

        let scopedCampaigns: [ZhuowangCampaign]

        if let province {
            scopedCampaigns =
                store.campaigns(
                    forProvinceID: province.id
                )

        } else if let module {
            scopedCampaigns =
                store.campaigns(
                    forModuleID: module.id
                )

        } else {
            scopedCampaigns =
                store.campaigns
        }

        return scopedCampaigns.filter { campaign in

            let matchesSearch =
                searchText
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
                ||
                campaign.name.localizedCaseInsensitiveContains(
                    searchText
                )
                ||
                campaign.englishName.localizedCaseInsensitiveContains(
                    searchText
                )
                ||
                campaign.notes.localizedCaseInsensitiveContains(
                    searchText
                )

            let matchesStatus =
                selectedStatus == nil
                ||
                campaign.status == selectedStatus

            return matchesSearch
                && matchesStatus
        }
    }


    // MARK: - Text

    private var scopeDescription: String {

        if let province {
            return "\(province.name)福利中心的活动项目管理"
        }

        if let module {
            return "\(module.name)相关活动项目管理"
        }

        return "卓望工作区全部活动项目"
    }


    private var emptyStateTitle: String {

        if !searchText.isEmpty
            || selectedStatus != nil {

            return "没有找到符合条件的活动"
        }

        return "还没有活动项目"
    }


    private var emptyStateDescription: String {

        if !searchText.isEmpty
            || selectedStatus != nil {

            return "尝试调整搜索关键词或状态筛选条件。"
        }

        if let province {
            return "你还没有为 \(province.name) 创建活动。以后该省的活动策划、设计和上线状态都可以在这里统一管理。"
        }

        if let module {
            return "你还没有在 \(module.name) 中创建活动项目。"
        }

        return "创建活动后，可以在这里统一查看项目状态、时间和备注。"
    }
}


// MARK: - Campaign Row

struct ZhuowangCampaignRow: View {

    let campaign: ZhuowangCampaign

    @State
    private var isHovering = false

    var body: some View {
        HStack(
            spacing: CosmosDesign.spacingM
        ) {

            ZStack {
                RoundedRectangle(
                    cornerRadius: 9,
                    style: .continuous
                )
                .fill(
                    Color.accentColor.opacity(0.08)
                )
                .frame(
                    width: 38,
                    height: 38
                )

                Image(
                    systemName:
                        campaign.status.systemImage
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
                spacing: 4
            ) {

                HStack(spacing: 8) {

                    Text(campaign.name)
                        .fontWeight(.medium)

                    if !campaign.englishName.isEmpty {
                        Text(campaign.englishName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {

                    Label(
                        campaign.dateRangeText,
                        systemImage: "calendar"
                    )

                    if !campaign.notes.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)

                        Text(campaign.notes)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            ZhuowangCampaignStatusBadge(
                status: campaign.status
            )

            Image(
                systemName: "chevron.right"
            )
            .font(.caption)
            .foregroundStyle(.tertiary)
            .offset(
                x: isHovering ? 3 : 0
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
        .background(
            isHovering
            ? Color.primary.opacity(0.03)
            : Color.clear
        )
        .contentShape(Rectangle())
        .animation(
            .easeOut(
                duration:
                    CosmosDesign.animationFast
            ),
            value: isHovering
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}


// MARK: - Status Badge

struct ZhuowangCampaignStatusBadge: View {

    let status: ZhuowangCampaignStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
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
            statusColor.opacity(0.08)
        )
        .clipShape(Capsule())
    }


    private var statusColor: Color {
        switch status {
        case .planning:
            return .blue

        case .designing:
            return .purple

        case .pendingLaunch:
            return .orange

        case .active:
            return .green

        case .completed:
            return .secondary
        }
    }
}


// MARK: - Create Campaign

struct ZhuowangCampaignCreateView: View {

    @ObservedObject
    var store: ZhuowangCampaignStore

    let province: ZhuowangProvince?
    let module: ZhuowangModule?

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var name = ""

    @State
    private var englishName = ""

    @State
    private var startDate = Date()

    @State
    private var endDate =
        Calendar.current.date(
            byAdding: .day,
            value: 30,
            to: Date()
        ) ?? Date()

    @State
    private var status:
        ZhuowangCampaignStatus = .planning

    @State
    private var notes = ""

    var body: some View {
        VStack(spacing: 0) {

            sheetHeader

            Divider()

            Form {

                Section(
                    "基本信息 · Basic Information"
                ) {

                    TextField(
                        "活动名称",
                        text: $name
                    )

                    TextField(
                        "英文名称（可选）",
                        text: $englishName
                    )

                    HStack {
                        Text("所属范围")

                        Spacer()

                        Text(scopeText)
                            .foregroundStyle(.secondary)
                    }
                }


                Section(
                    "时间 · Schedule"
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
                }


                Section(
                    "状态 · Status"
                ) {

                    Picker(
                        "活动状态",
                        selection: $status
                    ) {

                        ForEach(
                            ZhuowangCampaignStatus.allCases
                        ) { campaignStatus in

                            Text(
                                "\(campaignStatus.title) · \(campaignStatus.englishTitle)"
                            )
                            .tag(campaignStatus)
                        }
                    }
                }


                Section(
                    "备注 · Notes"
                ) {

                    TextEditor(
                        text: $notes
                    )
                    .frame(
                        minHeight: 90
                    )
                }
            }
            .formStyle(.grouped)
        }
        .frame(
            minWidth: 560,
            minHeight: 620
        )
    }


    // MARK: Sheet Header

    private var sheetHeader: some View {
        HStack {

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text("新建活动")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create Campaign")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("取消") {
                dismiss()
            }

            Button("创建") {
                createCampaign()
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
        }
        .padding(20)
    }


    // MARK: Create

    private func createCampaign() {

        if let province {

            store.addCampaign(
                name: name,
                englishName: englishName,
                scopeType: .province,
                provinceID: province.id,
                moduleID: "welfare",
                startDate: startDate,
                endDate: endDate,
                status: status,
                notes: notes
            )

        } else if let module {

            store.addCampaign(
                name: name,
                englishName: englishName,
                scopeType:
                    module.id == "national"
                    ? .national
                    : .other,
                moduleID: module.id,
                startDate: startDate,
                endDate: endDate,
                status: status,
                notes: notes
            )

        } else {

            store.addCampaign(
                name: name,
                englishName: englishName,
                scopeType: .other,
                startDate: startDate,
                endDate: endDate,
                status: status,
                notes: notes
            )
        }

        dismiss()
    }


    private var scopeText: String {

        if let province {
            return "\(province.name)福利中心"
        }

        if let module {
            return module.name
        }

        return "卓望工作区"
    }
}


// MARK: - Preview

#Preview {

    ZhuowangCampaignView(
        store: ZhuowangCampaignStore(),
        province:
            ZhuowangProvince(
                id: UUID(),
                name: "浙江",
                englishName: "Zhejiang"
            ),
        module: nil
    )
    .padding(36)
    .frame(
        width: 1000,
        height: 720
    )
}
