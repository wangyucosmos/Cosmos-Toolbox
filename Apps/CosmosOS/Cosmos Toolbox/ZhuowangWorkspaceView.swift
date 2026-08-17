import SwiftUI
import Combine

// MARK: - Zhuowang Workspace

struct ZhuowangWorkspaceView: View {

    @StateObject private var store = ZhuowangWorkspaceStore()

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
        .background(
            Color(nsColor: .windowBackgroundColor)
        )
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
            Color(nsColor: .controlBackgroundColor)
                .opacity(0.55)
        )
    }


    // MARK: Sidebar Header

    private var sidebarHeader: some View {

        HStack(
            spacing: CosmosDesign.spacingM
        ) {

            Image(
                systemName: "briefcase.fill"
            )
            .font(
                .system(
                    size: 19,
                    weight: .medium
                )
            )
            .foregroundStyle(.tint)

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
            }
            .buttonStyle(.plain)
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

                    withAnimation(
                        .easeInOut(
                            duration:
                                CosmosDesign
                                .animationNormal
                        )
                    ) {

                        selectedNavigation =
                            .province(
                                province.id
                            )

                        selectedCategoryID =
                            "overview"
                    }
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

                    withAnimation(
                        .easeInOut(
                            duration:
                                CosmosDesign
                                .animationNormal
                        )
                    ) {

                        selectedNavigation =
                            .module(
                                module.id
                            )

                        selectedCategoryID =
                            "overview"
                    }
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
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }


    // MARK: - Workspace Detail

    private var workspaceDetail: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: CosmosDesign.spacingXL
            ) {

                detailHeader

                categoryTabs

                Divider()
                    .opacity(0.45)

                if selectedCategoryID == "overview" {

                    overviewContent

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
            alignment: .top,
            spacing: CosmosDesign.spacingXL
        ) {

            VStack(
                alignment: .leading,
                spacing: CosmosDesign.spacingS
            ) {

                Text(currentWorkspaceTitle)
                    .font(
                        .system(
                            size: 30,
                            weight: .semibold
                        )
                    )

                Text(currentWorkspaceSubtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(currentWorkspaceDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
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
                .buttonStyle(.borderedProminent)
            }
        }
    }


    // MARK: Category Tabs

    private var categoryTabs: some View {

        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {

            HStack(
                spacing: CosmosDesign.spacingS
            ) {

                ForEach(store.categories) { category in

                    Button {

                        withAnimation(
                            .easeOut(
                                duration:
                                    CosmosDesign
                                    .animationFast
                            )
                        ) {

                            selectedCategoryID =
                                category.id
                        }

                    } label: {

                        HStack(
                            spacing: 7
                        ) {

                            Image(
                                systemName:
                                    category.icon
                            )

                            Text(category.name)

                            Text(
                                category.englishName
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                        .padding(
                            .horizontal,
                            13
                        )
                        .padding(
                            .vertical,
                            8
                        )
                        .background(
                            selectedCategoryID
                            == category.id
                            ? Color.accentColor
                                .opacity(0.12)
                            : Color.clear
                        )
                        .foregroundStyle(
                            selectedCategoryID
                            == category.id
                            ? Color.accentColor
                            : Color.primary
                        )
                        .clipShape(
                            Capsule()
                        )
                        .overlay {

                            Capsule()
                                .stroke(
                                    selectedCategoryID
                                    == category.id
                                    ? Color.accentColor
                                        .opacity(0.25)
                                    : Color.primary
                                        .opacity(0.07),
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
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


// MARK: - Navigation Item

enum ZhuowangNavigationItem:
    Equatable {

    case province(UUID)
    case module(String)
}


// MARK: - Sidebar Row

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

            HStack(
                spacing: CosmosDesign.spacingM
            ) {

                Image(systemName: icon)
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
                        .fontWeight(.medium)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {

                    Circle()
                        .fill(
                            Color.accentColor
                        )
                        .frame(
                            width: 5,
                            height: 5
                        )
                }
            }
            .padding(
                .horizontal,
                CosmosDesign.spacingM
            )
            .padding(
                .vertical,
                8
            )
            .background(
                isSelected
                ? Color.accentColor
                    .opacity(0.11)
                : isHovering
                    ? Color.primary
                        .opacity(0.035)
                    : Color.clear
            )
            .foregroundStyle(
                isSelected
                ? Color.accentColor
                : Color.primary
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign
                        .cornerRadiusSmall,
                    style: .continuous
                )
            )
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

            Image(systemName: icon)
                .font(
                    .system(
                        size: 17,
                        weight: .medium
                    )
                )
                .foregroundStyle(.secondary)

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


// MARK: - Data Models

struct ZhuowangModule:
    Identifiable,
    Codable,
    Hashable {

    let id: String
    var name: String
    var englishName: String
    var icon: String
    var usesProvinces: Bool
}


struct ZhuowangProvince:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID
    var name: String
    var englishName: String
}


struct ZhuowangCategory:
    Identifiable,
    Codable,
    Hashable {

    let id: String
    var name: String
    var englishName: String
    var icon: String
}


// MARK: - Workspace Store

final class ZhuowangWorkspaceStore:
    ObservableObject {

    @Published
    var modules: [ZhuowangModule]

    @Published
    var provinces: [ZhuowangProvince]

    @Published
    var categories: [ZhuowangCategory]

    private let storageKey =
        "cosmos.zhuowang.workspace.v1"


    init() {

        self.modules =
            Self.defaultModules

        self.provinces =
            Self.defaultProvinces

        self.categories =
            Self.defaultCategories

        load()
    }


    func addProvince(
        name: String,
        englishName: String
    ) {

        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty
        else {
            return
        }

        let cleanEnglish =
            englishName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let province =
            ZhuowangProvince(
                id: UUID(),
                name: cleanName,
                englishName:
                    cleanEnglish.isEmpty
                    ? cleanName
                    : cleanEnglish
            )

        provinces.append(province)

        save()
    }


    func addCategory(
        name: String,
        englishName: String
    ) {

        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty
        else {
            return
        }

        let cleanEnglish =
            englishName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let category =
            ZhuowangCategory(
                id:
                    "custom-\(UUID().uuidString)",
                name:
                    cleanName,
                englishName:
                    cleanEnglish.isEmpty
                    ? cleanName
                    : cleanEnglish,
                icon: "folder"
            )

        categories.append(category)

        save()
    }


    func addModule(
        name: String,
        englishName: String,
        usesProvinces: Bool
    ) {

        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty
        else {
            return
        }

        let cleanEnglish =
            englishName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let module =
            ZhuowangModule(
                id:
                    "custom-\(UUID().uuidString)",
                name:
                    cleanName,
                englishName:
                    cleanEnglish.isEmpty
                    ? cleanName
                    : cleanEnglish,
                icon:
                    "square.grid.2x2",
                usesProvinces:
                    usesProvinces
            )

        modules.append(module)

        save()
    }


    private func save() {

        let snapshot =
            ZhuowangWorkspaceSnapshot(
                modules: modules,
                provinces: provinces,
                categories: categories
            )

        guard
            let data =
                try? JSONEncoder()
                .encode(snapshot)
        else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: storageKey
        )
    }


    private func load() {

        guard
            let data =
                UserDefaults.standard
                .data(
                    forKey: storageKey
                ),
            let snapshot =
                try? JSONDecoder()
                .decode(
                    ZhuowangWorkspaceSnapshot.self,
                    from: data
                )
        else {
            return
        }

        modules =
            snapshot.modules

        provinces =
            snapshot.provinces

        categories =
            snapshot.categories
    }


    // MARK: Defaults

    private static let defaultModules: [
        ZhuowangModule
    ] = [

        ZhuowangModule(
            id: "welfare",
            name: "福利中心",
            englishName: "Welfare Center",
            icon: "gift",
            usesProvinces: true
        ),

        ZhuowangModule(
            id: "national",
            name: "全国促活",
            englishName: "National Campaign",
            icon: "globe.asia.australia",
            usesProvinces: false
        ),

        ZhuowangModule(
            id: "quiz",
            name: "竞猜专题",
            englishName: "Quiz Campaign",
            icon: "sportscourt",
            usesProvinces: false
        ),

        ZhuowangModule(
            id: "shared",
            name: "公共资料",
            englishName: "Shared Resources",
            icon: "books.vertical",
            usesProvinces: false
        ),

        ZhuowangModule(
            id: "templates",
            name: "工作模板",
            englishName: "Templates",
            icon: "square.stack.3d.up",
            usesProvinces: false
        )
    ]


    private static let defaultProvinces: [
        ZhuowangProvince
    ] = [

        ZhuowangProvince(
            id: UUID(),
            name: "河南",
            englishName: "Henan"
        ),

        ZhuowangProvince(
            id: UUID(),
            name: "安徽",
            englishName: "Anhui"
        ),

        ZhuowangProvince(
            id: UUID(),
            name: "浙江",
            englishName: "Zhejiang"
        ),

        ZhuowangProvince(
            id: UUID(),
            name: "海南",
            englishName: "Hainan"
        ),

        ZhuowangProvince(
            id: UUID(),
            name: "广东",
            englishName: "Guangdong"
        ),

        ZhuowangProvince(
            id: UUID(),
            name: "贵州",
            englishName: "Guizhou"
        )
    ]


    private static let defaultCategories: [
        ZhuowangCategory
    ] = [

        ZhuowangCategory(
            id: "overview",
            name: "总览",
            englishName: "Overview",
            icon: "square.grid.2x2"
        ),

        ZhuowangCategory(
            id: "campaign",
            name: "活动",
            englishName: "Campaign",
            icon: "megaphone"
        ),

        ZhuowangCategory(
            id: "popup",
            name: "弹窗",
            englishName: "Popup",
            icon:
                "rectangle.portrait"
        ),

        ZhuowangCategory(
            id: "banner",
            name: "Banner",
            englishName: "Banner",
            icon:
                "rectangle.on.rectangle"
        ),

        ZhuowangCategory(
            id: "faq",
            name: "客服文档",
            englishName: "FAQ",
            icon: "headphones"
        ),

        ZhuowangCategory(
            id: "prompt",
            name: "提示词",
            englishName: "Prompt",
            icon: "text.quote"
        ),

        ZhuowangCategory(
            id: "flow",
            name: "流程图",
            englishName: "Flow",
            icon:
                "point.3.connected.trianglepath.dotted"
        ),

        ZhuowangCategory(
            id: "prototype",
            name: "原型",
            englishName: "Prototype",
            icon: "macwindow"
        ),

        ZhuowangCategory(
            id: "asset",
            name: "素材",
            englishName: "Assets",
            icon: "photo.on.rectangle"
        )
    ]
}


private struct ZhuowangWorkspaceSnapshot:
    Codable {

    let modules: [ZhuowangModule]
    let provinces: [ZhuowangProvince]
    let categories: [ZhuowangCategory]
}


// MARK: - Preview

#Preview {

    ZhuowangWorkspaceView()
        .frame(
            width: 1200,
            height: 820
        )
}
