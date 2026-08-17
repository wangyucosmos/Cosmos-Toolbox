import SwiftUI
import Combine

// MARK: - Zhuowang Workspace

struct ZhuowangWorkspaceView: View {

    @StateObject private var store = ZhuowangWorkspaceStore()
    @StateObject private var campaignStore = ZhuowangCampaignStore()
    @State private var selectedNavigation: ZhuowangNavigationItem?
    @State private var selectedCategoryID = "overview"
    @State private var showManager = false


    var body: some View {

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
        }
        .sheet(isPresented: $showManager) {
            ZhuowangWorkspaceManagerView(
                store: store
            )
        }
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


    // MARK: Welfare Center

    private var welfareSection: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingS
        ) {

            sectionLabel(
                "福利中心",
                english: "Welfare Center"
            )

            ForEach(store.provinces) { province in

                ZhuowangSidebarRow(
                    icon: "mappin.and.ellipse",
                    title: province.name,
                    subtitle: province.englishName,
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

                detailHeader

                categoryTabs

                Divider()
                    .opacity(0.35)

                if selectedCategoryID == "overview" {

                    overviewContent

                } else if selectedCategoryID == "campaign" {

                    ZhuowangCampaignView(
                        store: campaignStore,
                        province: selectedProvince,
                        module: selectedModule
                    )

                } else {

                    categoryContent
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

                } label: {

                    Label(
                        "新建",
                        systemImage: "plus"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
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

            metricCards

            recentWorkSection

            quickActionsSection

            assetSummarySection
        }
    }


    // MARK: Metrics

    private var metricCards: some View {

        HStack(
            spacing: CosmosDesign.spacingL
        ) {

            ZhuowangMetricCard(
                icon: "megaphone",
                value: "3",
                title: "进行中活动",
                subtitle: "Active Campaigns"
            )

            ZhuowangMetricCard(
                icon: "folder",
                value: "8",
                title: "工作资产",
                subtitle: "Workspace Assets"
            )

            ZhuowangMetricCard(
                icon: "clock",
                value: "2",
                title: "待处理事项",
                subtitle: "To Do"
            )
        }
    }


    // MARK: Recent Work

    private var recentWorkSection: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {

            HStack {

                CosmosSectionTitle(
                    title: "最近工作",
                    subtitle: "Recent Work"
                )

                Spacer()

                Button {

                } label: {

                    HStack(
                        spacing:
                            CosmosDesign.spacingXS
                    ) {

                        Text("查看全部")

                        Image(
                            systemName:
                                "arrow.right"
                        )
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }

            VStack(spacing: 0) {

                ZhuowangWorkRow(
                    icon: "megaphone",
                    title:
                        "\(currentDisplayName) 9 月促活",
                    subtitle:
                        "活动策划 · 刚刚更新",
                    status: "进行中"
                )

                Divider()
                    .padding(.leading, 52)

                ZhuowangWorkRow(
                    icon:
                        "rectangle.portrait.on.rectangle.portrait",
                    title:
                        "\(currentDisplayName) 福利中心",
                    subtitle:
                        "页面内容 · 今天",
                    status: "进行中"
                )

                Divider()
                    .padding(.leading, 52)

                ZhuowangWorkRow(
                    icon: "headphones",
                    title:
                        "\(currentDisplayName) 客服文档",
                    subtitle:
                        "客服 FAQ · 最近更新",
                    status: "已完成"
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


    // MARK: Quick Actions

    private var quickActionsSection: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {

            CosmosSectionTitle(
                title: "快捷创建",
                subtitle: "Quick Actions"
            )

            HStack(
                spacing: CosmosDesign.spacingM
            ) {

                ZhuowangQuickAction(
                    icon: "plus.circle",
                    title: "新建活动",
                    subtitle: "Campaign"
                )

                ZhuowangQuickAction(
                    icon: "rectangle.portrait",
                    title: "弹窗需求",
                    subtitle: "Popup"
                )

                ZhuowangQuickAction(
                    icon: "headphones",
                    title: "客服文档",
                    subtitle: "FAQ"
                )

                ZhuowangQuickAction(
                    icon: "text.quote",
                    title: "提示词",
                    subtitle: "Prompt"
                )
            }
        }
    }


    // MARK: Asset Summary

    private var assetSummarySection: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {

            CosmosSectionTitle(
                title: "内容资产",
                subtitle: "Content Assets"
            )

            HStack(
                spacing: CosmosDesign.spacingM
            ) {

                ZhuowangAssetTile(
                    icon: "doc.text",
                    title: "活动方案",
                    count: "3"
                )

                ZhuowangAssetTile(
                    icon: "rectangle.portrait",
                    title: "弹窗",
                    count: "5"
                )

                ZhuowangAssetTile(
                    icon: "headphones",
                    title: "客服文档",
                    count: "4"
                )

                ZhuowangAssetTile(
                    icon: "text.quote",
                    title: "提示词",
                    count: "6"
                )
            }
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

        selectedCategoryID =
            "overview"
    }


    private func prepareInitialSelection() {

        guard selectedNavigation == nil
        else {
            return
        }

        if let firstProvince =
            store.provinces.first {

            selectedNavigation =
                .province(firstProvince.id)

        } else if let firstModule =
            store.modules.first(
                where: {
                    !$0.usesProvinces
                }
            ) {

            selectedNavigation =
                .module(firstModule.id)
        }
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

    @State
    private var isHovering = false

    var body: some View {

        Button {

        } label: {

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

    @State
    private var isHovering = false

    var body: some View {

        Button {

        } label: {

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

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var newProvinceName = ""

    @State
    private var newProvinceEnglishName = ""

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

                Section(
                    "新增省份 · Add Province"
                ) {

                    TextField(
                        "中文名称，例如：湖北",
                        text:
                            $newProvinceName
                    )

                    TextField(
                        "English Name, e.g. Hubei",
                        text:
                            $newProvinceEnglishName
                    )

                    Button(
                        "添加省份"
                    ) {

                        store.addProvince(
                            name:
                                newProvinceName,
                            englishName:
                                newProvinceEnglishName
                        )

                        newProvinceName = ""
                        newProvinceEnglishName = ""
                    }
                    .disabled(
                        newProvinceName
                            .trimmingCharacters(
                                in: .whitespaces
                            )
                            .isEmpty
                    )
                }


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

                        store.addCategory(
                            name:
                                newCategoryName,
                            englishName:
                                newCategoryEnglishName
                        )

                        newCategoryName = ""
                        newCategoryEnglishName = ""
                    }
                    .disabled(
                        newCategoryName
                            .trimmingCharacters(
                                in: .whitespaces
                            )
                            .isEmpty
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

                        store.addModule(
                            name:
                                newModuleName,
                            englishName:
                                newModuleEnglishName,
                            usesProvinces:
                                newModuleUsesProvinces
                        )

                        newModuleName = ""
                        newModuleEnglishName = ""
                        newModuleUsesProvinces = true
                    }
                    .disabled(
                        newModuleName
                            .trimmingCharacters(
                                in: .whitespaces
                            )
                            .isEmpty
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

