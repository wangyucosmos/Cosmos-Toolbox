import SwiftUI
import Combine

// MARK: - Zhuowang Workspace

struct ZhuowangWorkspaceView: View {

    @StateObject private var store: ZhuowangWorkspaceStore
    @StateObject private var campaignStore: ZhuowangCampaignStore
    /// One Workflow Store for the Campaign list, the progress workbench and
    /// every Campaign window opened from them.
    @StateObject private var workflowStore: ZhuowangWorkflowStore
    @State private var selectedNavigation: ZhuowangNavigationItem?
    @State private var selectedCategoryID = "overview"
    @State private var showManager = false
    @State private var showStoppedProvinces = false
    @State private var showCreateCampaign = false
    @State private var assetDestination: ZhuowangAssetFilter?
    @StateObject private var assetModel: ZhuowangAssetCatalogViewModel
    private let openPromptVault: () -> Void


    init(
        persistenceConfiguration:
            ZhuowangStorePersistenceConfiguration = .production,
        isolatedAssetRoot: URL? = nil,
        openPromptVault: @escaping () -> Void = { }
    ) {
        self.openPromptVault = openPromptVault
#if DEBUG
        let requiresRoot = persistenceConfiguration.isIsolated
#else
        let requiresRoot = false
#endif
        _assetModel = StateObject(wrappedValue: ZhuowangAssetCatalogViewModel(
            dataSource: persistenceConfiguration.dataSource,
            allowedRoot: isolatedAssetRoot, requiresIsolatedRoot: requiresRoot))
        _store = StateObject(
            wrappedValue: ZhuowangWorkspaceStore(
                persistenceConfiguration:
                    persistenceConfiguration
            )
        )

        _workflowStore = StateObject(wrappedValue: ZhuowangWorkflowStore(
            persistenceConfiguration: persistenceConfiguration))

        _campaignStore = StateObject(
            wrappedValue: ZhuowangCampaignStore(
                persistenceConfiguration:
                    persistenceConfiguration
            )
        )
    }


    var body: some View {
        VStack(spacing: 0) {
            if store.persistenceState.allowsMutations {
                HSplitView {
                    workspaceSidebar
                        .frame(
                            minWidth: 190,
                            idealWidth: 235,
                            maxWidth: 360
                        )

                    workspaceDetail
                        .frame(
                            minWidth: 620,
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                }

            } else {
                lockedWorkspaceContent
            }
        }
        .background {

            ZStack {

                Color(
                    nsColor:
                        .windowBackgroundColor
                )

                LinearGradient(
                    colors: [
                        Color.accentColor
                            .opacity(0.055),
                        Color.clear,
                        Color.primary
                            .opacity(0.015)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            prepareInitialSelection()
            assetModel.refresh()
        }
        .onReceive(campaignStore.$campaigns.dropFirst()) { _ in assetModel.refresh() }
        .onReceive(workflowStore.$workflows.dropFirst()) { _ in assetModel.refresh() }
        .sheet(isPresented: $showCreateCampaign) {
            ZhuowangCampaignCreateView(
                store: campaignStore, province: selectedProvince, module: selectedModule,
                isProvinceEnabled: { id in
                    ZhuowangProvinceRules.canCreateCampaign(provinceID: id, in: store.provinces)
                },
                canCreate: { canCreateCampaign },
                onCreated: { campaign in
                    ZhuowangCampaignWindowManager.shared.open(
                        campaign: campaign, store: campaignStore, workflowStore: workflowStore,
                        province: selectedProvince, module: selectedModule)
                })
        }
        .sheet(isPresented: $showManager) {
            ZhuowangWorkspaceManagerView(
                store: store,
                campaignCount: { id in
                    campaignStore.campaigns.filter {
                        $0.provinceID == id
                    }.count
                }
            )
        }
    }


    private var lockedWorkspaceContent: some View {
        ContentUnavailableView {
            Label(
                "Workspace 数据已锁定",
                systemImage:
                    "lock.trianglebadge.exclamationmark"
            )
        } description: {
            Text(
                store.persistenceState.userMessage
                ?? "当前数据不可写。"
            )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }


    // MARK: - Workspace Sidebar

    private var workspaceSidebar: some View {

        VStack(spacing: 0) {

            sidebarHeader

            Divider()
                .opacity(0.6)

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: CosmosDesign.spacingL
                ) {

                    workbenchSection

                    welfareSection

                    standaloneModuleSection

                    Spacer(minLength: 24)
                }
                .padding(
                    CosmosDesign.spacingM
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(
            .ultraThinMaterial
        )
        .overlay(
            alignment: .trailing
        ) {

            Rectangle()
                .fill(
                    Color.primary
                        .opacity(0.045)
                )
                .frame(width: 1)
        }
    }


    // MARK: Sidebar Header

    private var sidebarHeader: some View {

        HStack(
            spacing: CosmosDesign.spacingM
        ) {

            ZStack {

                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .fill(
                    Color.accentColor.opacity(0.11)
                )
                .frame(
                    width: 34,
                    height: 34
                )

                Image(
                    systemName: "briefcase.fill"
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
                spacing: 2
            ) {

                Text("卓望工作")
                    .font(.headline)

                Text("Zhuowang Workspace")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showManager = true

            } label: {

                Image(
                    systemName:
                        "slider.horizontal.3"
                )
                .font(
                    .system(
                        size: 13,
                        weight: .medium
                    )
                )
                .frame(
                    width: 28,
                    height: 28
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("管理工作区")
            .disabled(
                !store.persistenceState
                    .allowsMutations
            )
        }
        .padding(
            .horizontal,
            CosmosDesign.spacingM
        )
        .padding(
            .vertical,
            CosmosDesign.spacingM
        )
    }


    // MARK: Workbench

    private var workbenchSection: some View {
        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingS
        ) {
            sectionLabel(
                "总览",
                english: "Overview"
            )

            ZhuowangSidebarRow(
                icon: "chart.bar.doc.horizontal",
                title: "推进工作台",
                subtitle: "Campaign Progress",
                isSelected:
                    selectedNavigation == .workbench
            ) {
                selectNavigation(.workbench)
            }
        }
    }


    // MARK: Welfare Center

    private var welfareSection: some View {
        let enabledProvinces =
            store.provinces.filter(\.isEnabled)
        let stoppedProvinces =
            store.provinces.filter { !$0.isEnabled }

        return VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingS
        ) {

            sectionLabel(
                "福利中心",
                english: "Welfare Center"
            )

            if store.provinces.isEmpty {
                Button {
                    showManager = true
                } label: {
                    Label(
                        "还没有省份，点击添加",
                        systemImage: "plus.circle"
                    )
                    .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .padding(
                    .horizontal,
                    CosmosDesign.spacingM
                )
            }

            ForEach(enabledProvinces) { province in
                provinceSidebarRow(
                    province,
                    isStopped: false
                )
            }

            if !stoppedProvinces.isEmpty {
                DisclosureGroup(
                    "已停用省份（历史）",
                    isExpanded: Binding(
                        get: {
                            showStoppedProvinces
                                || (selectedProvince.map {
                                    !$0.isEnabled
                                } ?? false)
                        },
                        set: {
                            showStoppedProvinces = $0
                        }
                    )
                ) {
                    ForEach(stoppedProvinces) { province in
                        provinceSidebarRow(
                            province,
                            isStopped: true
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(
                    .horizontal,
                    CosmosDesign.spacingM
                )
            }
        }
    }

    private func provinceSidebarRow(
        _ province: ZhuowangProvince,
        isStopped: Bool
    ) -> some View {
        ZhuowangSidebarRow(
            icon:
                isStopped
                ? "archivebox"
                : "mappin.and.ellipse",
            title: province.name,
            subtitle:
                isStopped
                ? "已停用 · \(province.englishName)"
                : province.englishName,
            isSelected:
                selectedNavigation
                == .province(province.id)
        ) {
            selectNavigation(
                .province(
                    province.id
                )
            )
        }
    }

    // MARK: Standalone Modules

    private var standaloneModuleSection: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingS
        ) {

            sectionLabel(
                "其他工作",
                english: "Workspace"
            )

            ForEach(
                store.modules.filter {
                    !$0.usesProvinces
                }
            ) { module in

                ZhuowangSidebarRow(
                    icon: module.icon,
                    title: module.name,
                    subtitle: module.englishName,
                    isSelected:
                        selectedNavigation
                        == .module(module.id)
                ) {

                    selectNavigation(
                        .module(
                            module.id
                        )
                    )
                }
            }
        }
    }


    // MARK: Sidebar Section Label

    private func sectionLabel(
        _ title: String,
        english: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 1
        ) {

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(english)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 3)
    }


    // MARK: - Workspace Detail

    private var workspaceDetail: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color.accentColor
                        .opacity(0.025),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            workspaceDetailContent
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }


    private var workspaceDetailContent: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: CosmosDesign.spacingXL
            ) {

                if selectedNavigation == .workbench {

                    ZhuowangCampaignWorkbenchView(
                        campaignStore: campaignStore,
                        workspaceStore: store,
                        workflowStore: workflowStore
                    )

                } else {

                    detailHeader

                    categoryTabs

                    Divider()
                        .opacity(0.35)

                    if let assetDestination {
                        Button("返回概览", systemImage: "chevron.left") { self.assetDestination = nil }
                        Text(currentWorkspaceTitle + " · 内容资产").font(.headline)
                        if assetDestination.stepKind == .customerService {
                            Text("仅查看已有 Step06 客服文档产物，不创建或执行 AI。")
                                .foregroundStyle(.secondary)
                        }
                        ZhuowangAssetCenterView(model: assetModel, fixedScope: assetDestination)
                            .id(String(describing: assetDestination))
                    } else if selectedCategoryID == "overview" {

                        overviewContent

                    } else if selectedCategoryID == "campaign" {

                        ZhuowangCampaignView(
                            store: campaignStore,
                            province: selectedProvince,
                            module: selectedModule,
                            workflowStore: workflowStore,
                            isProvinceEnabled: { id in
                                ZhuowangProvinceRules.canCreateCampaign(
                                    provinceID: id,
                                    in: store.provinces
                                )
                            },
                            canCreate: { canCreateCampaign }
                        )

                    } else {

                        categoryContent
                    }
                }
            }
            .padding(
                .horizontal,
                CosmosDesign.pagePadding
            )
            .padding(
                .vertical,
                CosmosDesign.spacingXXL
            )
            .frame(
                maxWidth:
                    CosmosDesign.contentMaxWidth,
                alignment: .leading
            )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }


    // MARK: Detail Header

    private var detailHeader: some View {

        HStack(
            alignment: .center,
            spacing: CosmosDesign.spacingXL
        ) {

            HStack(
                spacing: 16
            ) {

                ZStack {

                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                    .fill(
                        Color.accentColor
                            .opacity(0.10)
                    )
                    .frame(
                        width: 48,
                        height: 48
                    )

                    Image(
                        systemName:
                            selectedProvince != nil
                            ? "mappin.and.ellipse"
                            : "square.grid.2x2"
                    )
                    .font(
                        .system(
                            size: 20,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.accentColor
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(currentWorkspaceTitle)
                        .font(
                            .system(
                                size: 28,
                                weight: .semibold,
                                design: .rounded
                            )
                        )

                    HStack(
                        spacing: 8
                    ) {

                        Text(
                            currentWorkspaceSubtitle
                        )
                        .font(.callout)
                        .foregroundStyle(
                            .secondary
                        )

                        Circle()
                            .fill(
                                Color.secondary
                                    .opacity(0.5)
                            )
                            .frame(
                                width: 3,
                                height: 3
                            )

                        Text(
                            currentWorkspaceDescription
                        )
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(1)
                    }
                }
            }

            Spacer()

            HStack(
                spacing: CosmosDesign.spacingS
            ) {

                CosmosStatusBadge(
                    text: "工作中",
                    icon: "circle.fill"
                )

                Button {
                    showCreateCampaign = true
                } label: {

                    Label(
                        "新建活动",
                        systemImage: "plus"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .disabled(!canCreateCampaign)
            }
        }
        .padding(
            20
        )
        .background(
            .thinMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    CosmosDesign
                    .cornerRadiusLarge,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    CosmosDesign
                    .cornerRadiusLarge,
                style: .continuous
            )
            .stroke(
                Color.primary
                    .opacity(0.055),
                lineWidth: 1
            )
        }
        .shadow(
            color:
                Color.black
                .opacity(0.035),
            radius: 14,
            x: 0,
            y: 6
        )
    }


    // MARK: - Category Tabs

    private var categoryTabs: some View {

        HStack(
            spacing: CosmosDesign.spacingS
        ) {

            // 常用分类固定显示
            ForEach(primaryCategories) { category in

                categoryTabButton(
                    category
                )
            }


            // 如果当前选择的是“更多”里的分类，
            // 自动把它临时显示在主导航中，
            // 让用户始终知道自己当前在哪里。
            if let selectedExtraCategory {

                categoryTabButton(
                    selectedExtraCategory
                )
            }


            // 更多分类
            if !extraCategories.isEmpty {

                Menu {

                    ForEach(extraCategories) { category in

                        Button {

                            selectCategory(
                                category
                            )

                        } label: {

                            Label(
                                category.name,
                                systemImage:
                                    category.icon
                            )
                        }
                    }

                } label: {

                    HStack(spacing: 7) {

                        Image(
                            systemName:
                                "ellipsis"
                        )

                        Text("更多")
                            .lineLimit(1)
                            .fixedSize(
                                horizontal: true,
                                vertical: false
                            )

                        Text("More")
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                            .lineLimit(1)
                            .fixedSize(
                                horizontal: true,
                                vertical: false
                            )

                        Image(
                            systemName:
                                "chevron.down"
                        )
                        .font(.caption2)
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .lineLimit(1)
                    .fixedSize(
                        horizontal: true,
                        vertical: false
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
                        Color.primary
                    )
                    .background(
                        Color.primary
                            .opacity(0.025)
                    )
                    .clipShape(
                        Capsule()
                    )
                    .overlay {

                        Capsule()
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


            Spacer(
                minLength: 0
            )
        }
        .padding(
            .horizontal,
            10
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
                    .cornerRadiusMedium,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    CosmosDesign
                    .cornerRadiusMedium,
                style: .continuous
            )
            .stroke(
                Color.primary
                    .opacity(0.045),
                lineWidth: 1
            )
        }
    }


    // MARK: - Primary Categories

    private var primaryCategoryIDs: [String] {

        [
            "overview",
            "campaign",
            "popup",
            "banner",
            "faq"
        ]
    }


    private var primaryCategories:
        [ZhuowangCategory] {

        primaryCategoryIDs.compactMap { id in

            store.categories.first {
                $0.id == id
            }
        }
    }


    // MARK: - Extra Categories

    private var extraCategories:
        [ZhuowangCategory] {

        store.categories.filter { category in

            !primaryCategoryIDs.contains(
                category.id
            )
        }
    }


    private var selectedExtraCategory:
        ZhuowangCategory? {

        guard
            !primaryCategoryIDs.contains(
                selectedCategoryID
            )
        else {
            return nil
        }

        return extraCategories.first {
            $0.id == selectedCategoryID
        }
    }


    // MARK: - Category Button

    private func categoryTabButton(
        _ category: ZhuowangCategory
    ) -> some View {

        let isSelected =
            selectedCategoryID
            == category.id

        return Button {

            selectCategory(
                category
            )

        } label: {

            HStack(spacing: 7) {

                Image(
                    systemName:
                        category.icon
                )
                .fixedSize(
                    horizontal: true,
                    vertical: false
                )

                Text(
                    category.name
                )
                .lineLimit(1)
                .fixedSize(
                    horizontal: true,
                    vertical: false
                )

                if !category
                    .englishName
                    .isEmpty {

                    Text(
                        category.englishName
                    )
                    .font(.caption)
                    .foregroundStyle(
                        isSelected
                        ? Color.accentColor
                            .opacity(0.72)
                        : Color.secondary
                    )
                    .lineLimit(1)
                    .fixedSize(
                        horizontal: true,
                        vertical: false
                    )
                }
            }
            .lineLimit(1)
            .fixedSize(
                horizontal: true,
                vertical: false
            )
            .font(
                .system(
                    size: 13,
                    weight:
                        isSelected
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
                isSelected
                ? Color.accentColor
                : Color.primary
            )
            .background(
                isSelected
                ? Color.accentColor
                    .opacity(0.10)
                : Color.clear
            )
            .clipShape(
                Capsule()
            )
            .overlay {

                Capsule()
                    .stroke(
                        isSelected
                        ? Color.accentColor
                            .opacity(0.24)
                        : Color.primary
                            .opacity(0.065),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(
            .plain
        )
        .fixedSize(
            horizontal: true,
            vertical: false
        )
    }


    // MARK: - Select Category

    private func selectCategory(
        _ category: ZhuowangCategory
    ) {

        withAnimation(
            .easeOut(
                duration:
                    CosmosDesign.animationFast
            )
        ) {

            assetDestination = nil
            selectedCategoryID =
                category.id
        }
    }

    // MARK: - Overview

    private var overviewContent: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingXXL
        ) {

            ZhuowangCampaignWorkbenchView(
                campaignStore: campaignStore,
                workspaceStore: store,
                workflowStore: workflowStore,
                fixedScope: currentWorkbenchScope
            )

            quickActionsSection

            assetSummarySection
        }
    }


    private var currentWorkbenchScope:
        ZhuowangCampaignWorkbenchFilter.Scope {

        if let selectedProvince {
            return .province(selectedProvince.id)
        }
        if let selectedModule {
            return .module(selectedModule.id)
        }
        return .all
    }


    // MARK: Quick Actions

    private var canCreateCampaign: Bool {
        ZhuowangWorkspaceEntry.canCreate(
            workspaceWritable: store.persistenceState.allowsMutations,
            campaignWritable: campaignStore.persistenceState.allowsMutations,
            province: selectedProvince, module: selectedModule,
            isProvinceEnabled: { id in
                ZhuowangProvinceRules.canCreateCampaign(provinceID: id, in: store.provinces)
            })
    }

    private func scopedAssetFilter(step: ZhuowangWorkflowStepKind? = nil) -> ZhuowangAssetFilter {
        var filter = ZhuowangAssetFilter()
        filter.provinceID = selectedProvince?.id
        filter.moduleID = selectedProvince == nil ? selectedModule?.id : nil
        filter.stepKind = step
        return filter
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: CosmosDesign.spacingM) {
            CosmosSectionTitle(title: "快捷入口", subtitle: "Quick Actions")
            HStack(spacing: CosmosDesign.spacingM) {
                ZhuowangQuickAction(icon: "plus.circle", title: "新建活动", subtitle: "Campaign") {
                    showCreateCampaign = true
                }.disabled(!canCreateCampaign)
                ZhuowangQuickAction(icon: "headphones", title: "查看客服文档", subtitle: "已有 Step06 产物") {
                    assetDestination = scopedAssetFilter(step: .customerService)
                }
                ZhuowangQuickAction(icon: "text.quote", title: "提示词库", subtitle: "全局 Prompt Vault") {
                    openPromptVault()
                }
            }
        }
    }

    // MARK: Asset Summary

    private var assetSummarySection: some View {
        VStack(alignment: .leading, spacing: CosmosDesign.spacingM) {
            HStack {
                CosmosSectionTitle(title: "内容资产", subtitle: "Content Assets · 当前采用版本")
                Spacer()
                Button("刷新", systemImage: "arrow.clockwise") { assetModel.refresh() }
            }
            if let error = assetModel.error {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            } else if assetModel.loading {
                ProgressView("正在核对资产…")
            } else {
                let scoped = assetModel.entries.filter(scopedAssetFilter().includes)
                let conflicts = Set(scoped.filter { $0.adoptedCount > 1 }.map(\.groupID)).count
                if conflicts > 0 {
                    Text("采用冲突 \(conflicts) 组；计数包含冲突版本，请进入资产中心核对。")
                        .foregroundStyle(.orange)
                }
                HStack(spacing: CosmosDesign.spacingM) {
                    assetTile("全部资产", icon: "archivebox", step: nil)
                    assetTile("完整策划案", icon: "doc.text", step: .plan)
                    assetTile("产品原型", icon: "rectangle.portrait", step: .prototype)
                    assetTile("客服文档", icon: "headphones", step: .customerService)
                }
                Text("按 Workflow 步骤分类；未采用组与历史版本可进入资产中心查看全部版本。")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(assetModel.notices, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    private func assetTile(_ title: String, icon: String, step: ZhuowangWorkflowStepKind?) -> some View {
        let filter = scopedAssetFilter(step: step)
        return ZhuowangAssetTile(icon: icon, title: title,
            count: String(assetModel.entries.filter(filter.includes).count)) {
                assetDestination = filter
            }
    }


    // MARK: - Category Content

    private var categoryContent: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingXL
        ) {

            HStack {

                CosmosSectionTitle(
                    title:
                        selectedCategory?
                        .name
                        ?? "内容",
                    subtitle:
                        selectedCategory?
                        .englishName
                        ?? "Content"
                )

                Spacer()

                Button {

                } label: {

                    Label(
                        "新建",
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
            }

            VStack(spacing: 0) {

                ZhuowangWorkRow(
                    icon:
                        selectedCategory?
                        .icon
                        ?? "doc",
                    title:
                        "\(currentDisplayName) · \(selectedCategory?.name ?? "内容") · 当前工作",
                    subtitle:
                        "最近更新 · Cosmos OS",
                    status: "进行中"
                )

                Divider()
                    .padding(.leading, 52)

                ZhuowangWorkRow(
                    icon:
                        selectedCategory?
                        .icon
                        ?? "doc",
                    title:
                        "\(currentDisplayName) · \(selectedCategory?.name ?? "内容") · 历史资料",
                    subtitle:
                        "历史工作资产",
                    status: "已归档"
                )
            }
            .background(.thinMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign
                        .cornerRadiusLarge,
                    style: .continuous
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign
                        .cornerRadiusLarge,
                    style: .continuous
                )
                .stroke(
                    Color.primary
                        .opacity(0.06),
                    lineWidth: 1
                )
            }
        }
    }


    // MARK: - Helpers

    private var selectedProvince:
        ZhuowangProvince? {

        guard
            case let .province(id)
                = selectedNavigation
        else {
            return nil
        }

        return store.provinces.first {
            $0.id == id
        }
    }


    private var selectedModule:
        ZhuowangModule? {

        guard
            case let .module(id)
                = selectedNavigation
        else {
            return nil
        }

        return store.modules.first {
            $0.id == id
        }
    }


    private var selectedCategory:
        ZhuowangCategory? {

        store.categories.first {
            $0.id == selectedCategoryID
        }
    }


    private var currentDisplayName: String {

        if let selectedProvince {
            return selectedProvince.name
        }

        if let selectedModule {
            return selectedModule.name
        }

        return "卓望"
    }


    private var currentWorkspaceTitle: String {

        if let selectedProvince {
            return "\(selectedProvince.name)福利中心"
        }

        if let selectedModule {
            return selectedModule.name
        }

        return "卓望工作"
    }


    private var currentWorkspaceSubtitle: String {

        if let selectedProvince {
            return "\(selectedProvince.englishName) Welfare Center"
        }

        if let selectedModule {
            return selectedModule.englishName
        }

        return "Zhuowang Workspace"
    }


    private var currentWorkspaceDescription: String {

        if selectedProvince != nil {
            return "该省福利中心的活动、弹窗、客服文档、提示词、流程图与原型资产"
        }

        if selectedModule?.id == "national" {
            return "咪咕视频全国促活活动策划、页面、规则与执行资产"
        }

        if selectedModule?.id == "quiz" {
            return "竞猜活动策划、题库、原型与运营资产"
        }

        if selectedModule?.id == "shared" {
            return "跨省共用资料、规范、参考案例与通用素材"
        }

        if selectedModule?.id == "templates" {
            return "活动策划、客服文档、流程图、Prompt 等可复用工作模板"
        }

        return "卓望项目统一工作空间"
    }


    private func selectNavigation(
        _ navigation: ZhuowangNavigationItem
    ) {

        guard
            selectedNavigation != navigation
        else {
            return
        }

        withAnimation(
            .easeOut(
                duration: 0.16
            )
        ) {

            selectedNavigation =
                navigation
        }

        assetDestination = nil
        assetModel.refresh()
        selectedCategoryID =
            "overview"
    }


    private func prepareInitialSelection() {

        guard selectedNavigation == nil
        else {
            return
        }

        // Entering the Workspace opens the cross-Campaign progress view.
        selectedNavigation = .workbench
    }
}





// MARK: - Refined Sidebar Row

struct ZhuowangSidebarRow: View {

    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    @State
    private var isHovering = false

    var body: some View {

        Button(action: action) {

            ZStack(
                alignment: .leading
            ) {

                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign
                        .cornerRadiusSmall,
                    style: .continuous
                )
                .fill(
                    isSelected
                    ? Color.accentColor
                        .opacity(0.065)
                    : isHovering
                        ? Color.primary
                            .opacity(0.027)
                        : Color.clear
                )

                if isSelected {

                    RoundedRectangle(
                        cornerRadius: 2,
                        style: .continuous
                    )
                    .fill(
                        Color.accentColor
                    )
                    .frame(
                        width: 3
                    )
                    .padding(
                        .vertical,
                        8
                    )
                    .padding(
                        .leading,
                        2
                    )
                }

                HStack(
                    spacing:
                        CosmosDesign.spacingM
                ) {

                    Image(
                        systemName: icon
                    )
                    .font(
                        .system(
                            size: 14,
                            weight:
                                isSelected
                                ? .semibold
                                : .regular
                        )
                    )
                    .frame(width: 20)
                    .foregroundStyle(
                        isSelected
                        ? Color.accentColor
                        : Color.secondary
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {

                        Text(title)
                            .fontWeight(
                                isSelected
                                ? .semibold
                                : .medium
                            )
                            .foregroundStyle(
                                isSelected
                                ? Color.primary
                                : Color.primary
                            )

                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(
                                isSelected
                                ? Color.accentColor
                                    .opacity(0.78)
                                : Color.secondary
                            )
                    }

                    Spacer()

                    if isSelected {

                        Circle()
                            .fill(
                                Color.accentColor
                                    .opacity(0.9)
                            )
                            .frame(
                                width: 4,
                                height: 4
                            )
                            .transition(
                                .scale
                                .combined(
                                    with: .opacity
                                )
                            )
                    }
                }
                .padding(
                    .leading,
                    13
                )
                .padding(
                    .trailing,
                    12
                )
                .padding(
                    .vertical,
                    8
                )
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign
                        .cornerRadiusSmall,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(
            isHovering && !isSelected
            ? 1.004
            : 1
        )
        .animation(
            .easeOut(
                duration:
                    CosmosDesign
                    .animationFast
            ),
            value: isHovering
        )
        .animation(
            .easeOut(
                duration:
                    CosmosDesign
                    .animationFast
            ),
            value: isSelected
        )
        .onHover { hovering in

            isHovering = hovering
        }
    }
}


// MARK: - Metric Card

struct ZhuowangMetricCard: View {

    let icon: String
    let value: String
    let title: String
    let subtitle: String

    @State
    private var isHovering = false

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {

            ZStack {

                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
                .fill(
                    Color.accentColor
                        .opacity(0.08)
                )
                .frame(
                    width: 34,
                    height: 34
                )

                Image(systemName: icon)
                    .font(
                        .system(
                            size: 15,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.accentColor
                    )
            }

            Text(value)
                .font(
                    .system(
                        size: 32,
                        weight: .semibold,
                        design: .rounded
                    )
                )

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
            minHeight: 125,
            alignment: .topLeading
        )
        .modifier(
            CosmosCardStyle(
                isHovering: isHovering
            )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}


// MARK: - Work Row

struct ZhuowangWorkRow: View {

    let icon: String
    let title: String
    let subtitle: String
    let status: String

    @State
    private var isHovering = false

    var body: some View {

        HStack(
            spacing: CosmosDesign.spacingM
        ) {

            Image(systemName: icon)
                .frame(width: 25)
                .foregroundStyle(.secondary)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(title)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(status)
                .font(.caption)
                .padding(
                    .horizontal,
                    9
                )
                .padding(
                    .vertical,
                    4
                )
                .background(.thinMaterial)
                .clipShape(Capsule())

            Image(
                systemName:
                    "chevron.right"
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
            ? Color.primary
                .opacity(0.035)
            : Color.clear
        )
        .contentShape(Rectangle())
        .animation(
            .easeOut(
                duration:
                    CosmosDesign
                    .animationFast
            ),
            value: isHovering
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}


// MARK: - Quick Action

struct ZhuowangQuickAction: View {

    let icon: String
    let title: String
    let subtitle: String

    let action: () -> Void

    @State
    private var isHovering = false

    var body: some View {

        Button(action: action) {

            VStack(
                alignment: .leading,
                spacing: CosmosDesign.spacingM
            ) {

                Image(systemName: icon)
                    .font(
                        .system(
                            size: 18,
                            weight: .medium
                        )
                    )

                Spacer()

                Text(title)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 105,
                alignment: .topLeading
            )
            .padding(
                CosmosDesign.spacingM
            )
            .background(
                isHovering
                ? Color.accentColor
                    .opacity(0.08)
                : Color.primary
                    .opacity(0.025)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign
                        .cornerRadiusMedium,
                    style: .continuous
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign
                        .cornerRadiusMedium,
                    style: .continuous
                )
                .stroke(
                    isHovering
                    ? Color.accentColor
                        .opacity(0.22)
                    : Color.primary
                        .opacity(0.06),
                    lineWidth: 1
                )
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in

            withAnimation(
                .easeOut(
                    duration:
                        CosmosDesign
                        .animationFast
                )
            ) {

                isHovering = hovering
            }
        }
    }
}


// MARK: - Asset Tile

struct ZhuowangAssetTile: View {

    let icon: String
    let title: String
    let count: String

    let action: () -> Void

    @State
    private var isHovering = false

    var body: some View {

        Button(action: action) {

            HStack(
                spacing: CosmosDesign.spacingM
            ) {

                Image(systemName: icon)
                    .font(
                        .system(
                            size: 17,
                            weight: .medium
                        )
                    )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {

                    Text(title)
                        .fontWeight(.medium)

                    Text("\(count) 项")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(
                    systemName:
                        "chevron.right"
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .frame(
                maxWidth: .infinity
            )
            .padding(
                CosmosDesign.spacingM
            )
            .background(
                isHovering
                ? Color.primary
                    .opacity(0.04)
                : Color.primary
                    .opacity(0.02)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign
                        .cornerRadiusMedium,
                    style: .continuous
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign
                        .cornerRadiusMedium,
                    style: .continuous
                )
                .stroke(
                    Color.primary
                        .opacity(0.06),
                    lineWidth: 1
                )
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in

            withAnimation(
                .easeOut(
                    duration:
                        CosmosDesign
                        .animationFast
                )
            ) {

                isHovering = hovering
            }
        }
    }
}


// MARK: - Workspace Manager

struct ZhuowangWorkspaceManagerView: View {

    @ObservedObject
    var store: ZhuowangWorkspaceStore

    /// Number of Campaigns that belong to a province (for the stop
    /// confirmation). Defaults to 0 where no Campaign Store is available.
    var campaignCount: (UUID) -> Int = { _ in 0 }

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var newCategoryName = ""

    @State
    private var newCategoryEnglishName = ""

    @State
    private var newModuleName = ""

    @State
    private var newModuleEnglishName = ""

    @State
    private var newModuleUsesProvinces = true

    @State
    private var mutationMessage = ""

    @State
    private var showMutationAlert = false

    var body: some View {

        VStack(spacing: 0) {

            HStack {

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text("管理工作区")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Manage Workspace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(
                    .defaultAction
                )
            }
            .padding(20)

            Divider()

            Form {

                ZhuowangProvinceManagementSection(
                    store: store,
                    campaignCount: campaignCount,
                    report: { message in
                        mutationMessage = message
                        showMutationAlert = true
                    }
                )

                Section(
                    "新增内容分类 · Add Category"
                ) {

                    TextField(
                        "例如：短视频",
                        text:
                            $newCategoryName
                    )

                    TextField(
                        "例如：Video",
                        text:
                            $newCategoryEnglishName
                    )

                    Button(
                        "添加内容分类"
                    ) {

                        let result = store.addCategory(
                            name:
                                newCategoryName,
                            englishName:
                                newCategoryEnglishName
                        )

                        if result.succeeded {
                            newCategoryName = ""
                            newCategoryEnglishName = ""
                        } else {
                            showFailure(result)
                        }
                    }
                    .disabled(
                        newCategoryName
                            .trimmingCharacters(
                                in: .whitespaces
                            )
                            .isEmpty
                        || !store.persistenceState
                            .allowsMutations
                    )
                }


                Section(
                    "新增工作模块 · Add Workspace"
                ) {

                    TextField(
                        "例如：湖北专项",
                        text:
                            $newModuleName
                    )

                    TextField(
                        "例如：Hubei Campaign",
                        text:
                            $newModuleEnglishName
                    )

                    Toggle(
                        "需要省份分类",
                        isOn:
                            $newModuleUsesProvinces
                    )

                    Button(
                        "添加工作模块"
                    ) {

                        let result = store.addModule(
                            name:
                                newModuleName,
                            englishName:
                                newModuleEnglishName,
                            usesProvinces:
                                newModuleUsesProvinces
                        )

                        if result.succeeded {
                            newModuleName = ""
                            newModuleEnglishName = ""
                            newModuleUsesProvinces = true
                        } else {
                            showFailure(result)
                        }
                    }
                    .disabled(
                        newModuleName
                            .trimmingCharacters(
                                in: .whitespaces
                            )
                            .isEmpty
                        || !store.persistenceState
                            .allowsMutations
                    )
                }


                Section(
                    "当前配置 · Current Configuration"
                ) {

                    Text(
                        "工作模块：\(store.modules.count)"
                    )

                    Text(
                        "省份：\(store.provinces.count)"
                    )

                    Text(
                        "内容分类：\(store.categories.count)"
                    )
                }
            }
            .formStyle(.grouped)
        }
        .frame(
            minWidth: 520,
            minHeight: 620
        )
        .alert(
            "Workspace Store",
            isPresented: $showMutationAlert
        ) {
            Button("知道了") { }
        } message: {
            Text(mutationMessage)
        }
    }


    private func showFailure(
        _ result: ZhuowangStoreMutationResult
    ) {
        mutationMessage =
            result.userMessage
            ?? "操作失败，未保存任何修改。"
        showMutationAlert = true
    }
}










// MARK: - Preview

#Preview {

    ZhuowangWorkspaceView()
        .frame(
            width: 1200,
            height: 820
        )
}
