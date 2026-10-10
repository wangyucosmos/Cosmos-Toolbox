import SwiftUI
import AppKit
import Combine

struct ZhuowangCampaignView: View {

    @ObservedObject var store: ZhuowangCampaignStore

    let province: ZhuowangProvince?
    let module: ZhuowangModule?

    @State private var searchText = ""
    @State private var selectedStatus: ZhuowangCampaignStatus?
    @State private var showCreateSheet = false

    /// Shared with the Workspace so every Campaign window uses one
    /// in-memory Workflow Store instance.
    @ObservedObject var workflowStore: ZhuowangWorkflowStore

    /// Reads the *live* province configuration. A stopped province cannot
    /// receive new Campaigns; existing Campaigns are never affected.
    var isProvinceEnabled: (UUID) -> Bool = { _ in true }

    var canCreate: () -> Bool = { true }

    private var canCreateCampaign: Bool {
        guard let province else {
            return true
        }
        return isProvinceEnabled(province.id)
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingXL
        ) {

            header

            if let message =
                store.persistenceState.userMessage {
                Label(
                    message,
                    systemImage:
                        "lock.trianglebadge.exclamationmark"
                )
                .font(.callout)
                .foregroundStyle(.orange)
                .padding(CosmosDesign.spacingM)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(
                    Color.orange.opacity(0.08)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            CosmosDesign.cornerRadiusMedium,
                        style: .continuous
                    )
                )
            }

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
            .disabled(
                !store.persistenceState
                    .allowsMutations
                || !canCreateCampaign
                || !canCreate()
            )
        }
        .sheet(isPresented: $showCreateSheet) {
            ZhuowangCampaignCreateView(
                store: store,
                province: province,
                module: module,
                isProvinceEnabled: isProvinceEnabled,
                canCreate: canCreate,
                onCreated: openCampaignWindow
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
                    openCampaignWindow(
                        campaign
                    )
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
                && selectedStatus == nil
                && canCreateCampaign {

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
                .disabled(
                    !store.persistenceState
                        .allowsMutations
                )
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



    // MARK: - Open Campaign Window

    private func openCampaignWindow(
        _ campaign: ZhuowangCampaign
    ) {

        ZhuowangCampaignWindowManager.shared.open(
            campaign: campaign,
            store: store,
            workflowStore: workflowStore,
            province: province,
            module: module
        )
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
            if !canCreateCampaign {
                return "\(province.name)福利中心已停用：不能新建活动，历史活动仍可查看、编辑和推进。"
            }
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

        if let province, !canCreateCampaign {
            return "\(province.name) 已停用，不能新建活动。恢复后可以继续创建。"
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



// MARK: - Campaign Detail Route

/// One pending navigation request for an open Campaign window.
final class ZhuowangCampaignDetailRoute: ObservableObject {

    enum Destination: Equatable {
        case overview
        case workflow
        case artifacts
        case deliveryPackage
    }

    @Published
    private(set) var requestSerial = 0

    private var pending: Destination?

    func show(_ destination: Destination) {
        pending = destination
        requestSerial += 1
    }

    func takeRequest() -> Destination? {
        defer {
            pending = nil
        }
        return pending
    }
}


// MARK: - Campaign Native Window Manager

final class ZhuowangCampaignWindowManager:
    NSObject,
    NSWindowDelegate {

    static let shared =
        ZhuowangCampaignWindowManager()

    private var controllers:
        [UUID: NSWindowController] = [:]

    private var routes:
        [UUID: ZhuowangCampaignDetailRoute] = [:]

    private override init() {
        super.init()
    }


    func open(
        campaign: ZhuowangCampaign,
        store: ZhuowangCampaignStore,
        workflowStore: ZhuowangWorkflowStore,
        province: ZhuowangProvince?,
        module: ZhuowangModule?,
        destination: ZhuowangCampaignDetailRoute.Destination? = nil
    ) {

        if let existing =
            controllers[campaign.id] {

            if let destination {
                routes[campaign.id]?.show(destination)
            }

            existing.window?
                .makeKeyAndOrderFront(nil)

            NSApp.activate(
                ignoringOtherApps: true
            )

            return
        }

        let route = ZhuowangCampaignDetailRoute()
        if let destination {
            route.show(destination)
        }
        routes[campaign.id] = route

        let rootView =
            ZhuowangCampaignDetailView(
                store: store,
                workflowStore:
                    workflowStore,
                campaignID:
                    campaign.id,
                province:
                    province,
                module:
                    module,
                route: route
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
                        width: 980,
                        height: 760
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
            campaign.name

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
                campaign.id.uuidString
            )

        let controller =
            NSWindowController(
                window: window
            )

        controllers[campaign.id] =
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
            let rawID =
                window.identifier?
                    .rawValue,
            let campaignID =
                UUID(
                    uuidString: rawID
                )
        else {
            return
        }

        controllers.removeValue(
            forKey: campaignID
        )
        routes.removeValue(
            forKey: campaignID
        )
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

    /// Re-checked at save time against the live province configuration, so a
    /// form that was opened before the province was stopped cannot create a
    /// Campaign in it. Input is kept when the save is refused.
    var isProvinceEnabled: (UUID) -> Bool = { _ in true }

    var canCreate: () -> Bool = { true }
    var onCreated: (ZhuowangCampaign) -> Void = { _ in }

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

    // Monthly member-activation type (national module only).
    @State
    private var isMonthly = false

    @State
    private var monthText =
        ZhuowangCampaignCreateView.defaultMonthText()

    @State
    private var referenceID: UUID?

    @State
    private var referenceChosen = false

    @State
    private var userEditedDates = false

    @State
    private var mutationMessage = ""

    @State
    private var showMutationAlert = false

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


                if monthlyAvailable {
                    Section("项目类型 · Type") {
                        Picker("类型", selection: $isMonthly) {
                            Text("普通活动").tag(false)
                            Text("月度会员促活").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("campaign-type")
                        .onChange(of: isMonthly) { _, nowMonthly in
                            // Switching back to a plain Campaign restores the
                            // plain default dates unless the user edited them.
                            if !nowMonthly, !userEditedDates {
                                startDate = Date()
                                endDate =
                                    Calendar.current.date(
                                        byAdding: .day,
                                        value: 30,
                                        to: Date()
                                    ) ?? Date()
                            }
                        }
                    }
                }

                if isMonthlyActive {
                    monthlySection
                }

                Section(
                    "时间 · Schedule"
                ) {

                    if isMonthlyActive {
                        DatePicker(
                            "开始时间",
                            selection: Binding(
                                get: { startDate },
                                set: {
                                    startDate = $0
                                    userEditedDates = true
                                }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        DatePicker(
                            "结束时间",
                            selection: Binding(
                                get: { endDate },
                                set: {
                                    endDate = $0
                                    userEditedDates = true
                                }
                            ),
                            in: startDate...,
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        Text("已按上海时区预填「上月末 17:00 — 本月末 17:00」，可手动修改；月份标签与实际起止时间相互独立。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
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
        .alert(
            "Campaign Store",
            isPresented: $showMutationAlert
        ) {
            Button("知道了") { }
        } message: {
            Text(mutationMessage)
        }
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
                || !canCreate()
                || !isProvinceEnabledForCreation
                || !store.persistenceState
                    .allowsMutations
            )
        }
        .padding(20)
    }


    // MARK: Create

    private func createCampaign() {

        guard canCreate() else {
            mutationMessage = "当前范围已不可创建，草稿未保存。"
            showMutationAlert = true
            return
        }
        let previousIDs = Set(store.campaigns.map(\.id))

        if let refusal =
            ZhuowangProvinceRules.creationRefusalMessage(
                province: province,
                isEnabled: isProvinceEnabled
            ) {
            mutationMessage = refusal
            showMutationAlert = true
            return
        }

        let result: ZhuowangStoreMutationResult

        if isMonthlyActive {

            guard let month = parsedMonth else {
                mutationMessage = ZhuowangMonthlyViolation.invalidMonth.message
                showMutationAlert = true
                return
            }

            guard endDate >= startDate else {
                mutationMessage = ZhuowangMonthlyViolation.invalidDates.message
                showMutationAlert = true
                return
            }

            if let referenceID,
               let violation =
                ZhuowangMonthlyRules.validateReference(
                    referenceID,
                    month: month.string,
                    selfID: UUID(),
                    campaigns: store.campaigns
                ) {
                mutationMessage = violation.message
                showMutationAlert = true
                return
            }

            result = store.addCampaign(
                name: name,
                englishName: englishName,
                scopeType: .national,
                moduleID: "national",
                startDate: startDate,
                endDate: endDate,
                status: status,
                notes: notes,
                monthlyMonth: month.string,
                referenceCampaignID: referenceID
            )

        } else if let province {

            result = store.addCampaign(
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

            result = store.addCampaign(
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

            result = store.addCampaign(
                name: name,
                englishName: englishName,
                scopeType: .other,
                startDate: startDate,
                endDate: endDate,
                status: status,
                notes: notes
            )
        }

        guard result.succeeded else {
            mutationMessage =
                result.userMessage
                ?? "活动未保存。"
            showMutationAlert = true
            return
        }

        dismiss()
        if let created = ZhuowangWorkspaceEntry.createdCampaign(
            result: result, previousIDs: previousIDs, campaigns: store.campaigns) {
            onCreated(created)
        }
    }

    private var isProvinceEnabledForCreation: Bool {
        province.map { isProvinceEnabled($0.id) } ?? true
    }

    // MARK: Monthly type

    private var monthlyAvailable: Bool {
        province == nil && module?.id == "national"
    }

    private var isMonthlyActive: Bool {
        isMonthly && monthlyAvailable
    }

    private var parsedMonth: ZhuowangActivityMonth? {
        ZhuowangActivityMonth(
            string:
                monthText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
        )
    }

    private var eligibleReferences: [ZhuowangCampaign] {
        guard let month = parsedMonth else {
            return []
        }

        return store.campaigns.filter { other in
            guard
                let theirs =
                    other.monthly.flatMap({
                        ZhuowangActivityMonth(
                            string: $0.activityMonth
                        )
                    })
            else {
                return false
            }
            return theirs < month
        }
        .sorted {
            let a = $0.monthly.flatMap { ZhuowangActivityMonth(string: $0.activityMonth) }
            let b = $1.monthly.flatMap { ZhuowangActivityMonth(string: $0.activityMonth) }
            if let a, let b, a != b { return a > b }
            return $0.createdAt > $1.createdAt
        }
    }

    private var monthlySection: some View {
        Section("月度信息 · Monthly") {
            TextField("活动月份（YYYY-MM）", text: $monthText)
                .accessibilityIdentifier("campaign-month")
                .onChange(of: monthText) { _, _ in
                    monthChanged()
                }

            if parsedMonth == nil {
                Text("月份须为 YYYY-MM，例如 2026-11。")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                let duplicates =
                    ZhuowangMonthlyRules.campaignsWithMonth(
                        monthText.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                        in: store.campaigns
                    )
                if !duplicates.isEmpty {
                    Text("已有 \(duplicates.count) 个同月月度活动（仅提示，仍可创建）。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Picker("上期参考（可选）", selection: $referenceID) {
                Text("不选").tag(UUID?.none)
                ForEach(eligibleReferences) { reference in
                    Text(
                        "\(reference.monthly?.activityMonth ?? "") · \(reference.name)"
                    )
                    .tag(UUID?.some(reference.id))
                }
            }
            .onChange(of: referenceID) { _, _ in
                if referenceID != defaultReferenceID {
                    referenceChosen = true
                }
            }

            Text("只保存上期活动的身份，不复制它的内容；创建后清单是空白的，输入状态、掌厅奖池关系、成品位置和定稿确认都不会带过来。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            if referenceID == nil, !referenceChosen {
                referenceID = defaultReferenceID
            }
            applyDefaultDatesIfNeeded()
        }
    }

    private var defaultReferenceID: UUID? {
        ZhuowangMonthlyRules.defaultReferenceCandidate(
            forMonth:
                monthText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            in: store.campaigns
        )?.id
    }

    private func monthChanged() {
        applyDefaultDatesIfNeeded()

        if !referenceChosen {
            referenceID = defaultReferenceID
        }
    }

    /// Never overwrites dates the user edited by hand.
    private func applyDefaultDatesIfNeeded() {
        let next =
            ZhuowangMonthlyRules.datesAfterMonthChange(
                current: (startDate, endDate),
                newMonth:
                    monthText.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                userEditedDates: userEditedDates
            )
        startDate = next.start
        endDate = next.end
    }

    /// Next calendar month (Shanghai) as the default label.
    static func defaultMonthText() -> String {
        let today = LearningDay.today(timeZone: ZhuowangMonthlyRules.shanghai)
        let month = ZhuowangActivityMonth(year: today.year, month: today.month)
        let next = month.flatMap { current in
            current.month == 12
                ? ZhuowangActivityMonth(year: current.year + 1, month: 1)
                : ZhuowangActivityMonth(year: current.year, month: current.month + 1)
        }
        return next?.string ?? month?.string ?? ""
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
        module: nil,
        workflowStore: ZhuowangWorkflowStore()
    )
    .padding(36)
    .frame(
        width: 1000,
        height: 720
    )
}
