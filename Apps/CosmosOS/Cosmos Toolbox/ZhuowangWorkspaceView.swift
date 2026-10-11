import SwiftUI
import Combine

struct ZhuowangWorkspaceView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.cosmosNavigator) private var navigator
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    @StateObject private var store: ZhuowangWorkspaceStore
    @StateObject private var campaignStore: ZhuowangCampaignStore
    @StateObject private var workflowStore: ZhuowangWorkflowStore
    @StateObject private var assetModel: ZhuowangAssetCatalogViewModel
    @State private var selectedNavigation: ZhuowangNavigationItem
    @State private var selectedCategoryID: String
    @State private var showManager = false
    @State private var showStoppedProvinces = false
    @State private var showCreateCampaign = false
    @State private var assetDestination: ZhuowangAssetFilter?
    @State private var publicResources = false
    private let openPromptVault: () -> Void

    init(persistenceConfiguration: ZhuowangStorePersistenceConfiguration = .production,
         isolatedAssetRoot: URL? = nil, openPromptVault: @escaping () -> Void = {},
         initialNavigation: ZhuowangNavigationItem = .workbench, initialCategoryID: String = "overview") {
        self.openPromptVault = openPromptVault
        _selectedNavigation = State(initialValue: initialNavigation)
        _selectedCategoryID = State(initialValue: initialCategoryID)
        _store = StateObject(wrappedValue: ZhuowangWorkspaceStore(persistenceConfiguration: persistenceConfiguration))
        _campaignStore = StateObject(wrappedValue: ZhuowangCampaignStore(persistenceConfiguration: persistenceConfiguration))
        _workflowStore = StateObject(wrappedValue: ZhuowangWorkflowStore(persistenceConfiguration: persistenceConfiguration))
        _assetModel = StateObject(wrappedValue: ZhuowangAssetCatalogViewModel(dataSource: persistenceConfiguration.dataSource,
            allowedRoot: isolatedAssetRoot, requiresIsolatedRoot: persistenceConfiguration.isIsolatedForUI))
    }

    private var reduced: Bool { preferences.reducesMotion(system: systemMotion) }
    private var rows: [ZhuowangCampaignProgress] {
        ZhuowangWorkspaceUI.rows(campaigns: campaignStore.campaigns, workflows: workflowStore.workflows,
            provinces: store.provinces, modules: store.modules, manager: workflowStore.workspaceFileManager)
    }
    private var province: ZhuowangProvince? {
        if case .province(let id) = selectedNavigation { return store.provinces.first { $0.id == id } }; return nil
    }
    private var module: ZhuowangModule? {
        if case .module(let id) = selectedNavigation { return store.modules.first { $0.id == id } }; return nil
    }
    private var scope: ZhuowangCampaignWorkbenchFilter.Scope {
        if let province { return .province(province.id) }; if let module { return .module(module.id) }; return .all
    }
    private var title: String { province?.name ?? module?.name ?? "卓望工作" }
    private var canCreate: Bool {
        ZhuowangWorkspaceEntry.canCreate(workspaceWritable: store.persistenceState.allowsMutations,
            campaignWritable: campaignStore.persistenceState.allowsMutations, province: province, module: module,
            isProvinceEnabled: { ZhuowangProvinceRules.canCreateCampaign(provinceID: $0, in: store.provinces) })
    }
    private var scopeAssets: ZhuowangAssetFilter {
        var filter = ZhuowangAssetFilter(); filter.provinceID = province?.id; filter.moduleID = province == nil ? module?.id : nil
        return filter
    }
    private var contentIdentity: String { String(describing: selectedNavigation) + "::" + selectedCategoryID + "::" + String(publicResources) + "::" + String(describing: assetDestination) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("卓望工作", systemImage: "briefcase").font(.headline)
                Spacer()
                CosmosGlassToolbarGroup {
                    Button { showManager = true } label: { Label("管理工作区", systemImage: "slider.horizontal.3").foregroundStyle(colorScheme == .dark ? Color.white : Color.black) }
                        .disabled(!store.persistenceState.allowsMutations)
                }
            }.padding(.horizontal, 20).padding(.vertical, 10)
            Divider()
            if let message = store.persistenceState.userMessage {
                ContentUnavailableView("工作区暂不可编辑", systemImage: "lock.trianglebadge.exclamationmark", description: Text(message))
            } else {
                HSplitView {
                    sidebar.frame(minWidth: 160, idealWidth: 190, maxWidth: 250)
                    // Only the outer shell transitions; local selection changes keep their host.
                    ZStack(alignment: .topLeading) {
                        detail.id(contentIdentity)
                    }
                        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }.background(Color(nsColor: .windowBackgroundColor))
            .onChange(of: selectedNavigation) { _, value in
#if DEBUG
                CosmosExperienceTrace.shared.mark("workspace.selection." + String(describing: value))
#endif
                navigator.workspaceNavigation = value
            }
            .onAppear {
#if DEBUG
                CosmosExperienceTrace.shared.mark("workspace.appear." + String(describing: selectedNavigation))
#endif
            }
            .onChange(of: selectedCategoryID) { _, value in navigator.workspaceCategory = value }
            .onChange(of: navigator.pendingWorkbenchMetric) { _, metric in if metric != nil { select(.workbench) } }
            .onReceive(campaignStore.$campaigns.dropFirst()) { _ in assetModel.refresh() }
            .onReceive(workflowStore.$workflows.dropFirst()) { _ in assetModel.refresh() }
            .sheet(isPresented: $showManager) {
                ZhuowangWorkspaceManagerView(store: store, campaignCount: { id in campaignStore.campaigns.filter { $0.provinceID == id }.count })
            }
            .sheet(isPresented: $showCreateCampaign) {
                ZhuowangCampaignCreateView(store: campaignStore, province: province, module: module,
                    isProvinceEnabled: { ZhuowangProvinceRules.canCreateCampaign(provinceID: $0, in: store.provinces) },
                    canCreate: { canCreate }, onCreated: { campaign in open(campaign, province: province, module: module) })
            }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("总览") {
                    CosmosWorkspaceNavigationRow(icon: "chart.bar.doc.horizontal", title: "推进工作台", count: rows.count,
                        attention: rows.contains { $0.category == .needsAttention }, selected: !publicResources && selectedNavigation == .workbench) { select(.workbench) }
                }
                section("福利中心") {
                    if store.provinces.isEmpty {
                        Button("添加负责的省份", systemImage: "plus.circle") { showManager = true }.buttonStyle(.plain).foregroundStyle(.tint).padding(10)
                    }
                    ForEach(store.provinces.filter(\.isEnabled)) { provinceRow($0) }
                    if store.provinces.contains(where: { !$0.isEnabled }) {
                        DisclosureGroup("已停用省份", isExpanded: $showStoppedProvinces) {
                            ForEach(store.provinces.filter { !$0.isEnabled }) { provinceRow($0) }
                        }.font(.caption).padding(.horizontal, 10)
                    }
                }
                section("其他工作") {
                    ForEach(store.modules.filter { !$0.usesProvinces }) { item in
                        let badge = ZhuowangWorkspaceUI.badge(rows, scope: .module(item.id))
                        CosmosWorkspaceNavigationRow(icon: item.icon, title: item.name, count: badge.count, attention: badge.attention,
                            selected: !publicResources && selectedNavigation == .module(item.id)) { select(.module(item.id)) }
                    }
                }
                section("公共资料") {
                    CosmosWorkspaceNavigationRow(icon: "archivebox", title: "知识与资产", selected: publicResources) {
                        publicResources = true; assetDestination = nil
                    }
                    CosmosWorkspaceNavigationRow(icon: "text.quote", title: "提示词库", action: openPromptVault)
                }
            }.padding(12)
        }.background(Color(nsColor: .controlBackgroundColor))
    }
    private func section<Content: View>(_ name: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 14)
            content()
        }
    }
    private func provinceRow(_ item: ZhuowangProvince) -> some View {
        let badge = ZhuowangWorkspaceUI.badge(rows, scope: .province(item.id))
        return CosmosWorkspaceNavigationRow(icon: "square", title: item.name, letter: CosmosIconPalette.letter(item.name),
            iconIdentity: item.id.uuidString, subdued: !item.isEnabled,
            subtitle: item.isEnabled ? "" : "已停用 · 历史保留", count: badge.count, attention: badge.attention,
            selected: !publicResources && selectedNavigation == .province(item.id)) { select(.province(item.id)) }
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if publicResources {
                    ZhuowangAssetCenterView(model: assetModel)
                } else if selectedNavigation == .workbench {
                    ZhuowangCampaignWorkbenchView(campaignStore: campaignStore, workspaceStore: store, workflowStore: workflowStore)
                } else {
                    CosmosPageHeader(title, subtitle: "\(ZhuowangWorkspaceUI.scoped(rows, scope: scope).count) 个活动",
                        info: "指标与推进工作台使用相同口径；只读取当前范围。停用省份保留历史活动，不能新建。")
                    categoryNavigation
                    if let assetDestination {
                        Button("返回概览", systemImage: "chevron.left") { self.assetDestination = nil }
                        ZhuowangAssetCenterView(model: assetModel, fixedScope: assetDestination)
                    } else if selectedCategoryID == "overview" {
                        ZhuowangScopeOverviewUI(title: title, rows: ZhuowangWorkspaceUI.scoped(rows, scope: scope), canCreate: canCreate,
                            create: { showCreateCampaign = true }, open: { row in open(row.campaign, province: row.province, module: row.module) },
                            assets: { assetDestination = scopeAssets })
                    } else if selectedCategoryID == "campaign" {
                        ZhuowangCampaignView(store: campaignStore, province: province, module: module, workflowStore: workflowStore,
                            isProvinceEnabled: { ZhuowangProvinceRules.canCreateCampaign(provinceID: $0, in: store.provinces) }, canCreate: { canCreate })
                    } else {
                        ZhuowangCategoryContentView(category: store.categories.first { $0.id == selectedCategoryID }, categoryID: selectedCategoryID,
                            scopeName: title, provinceID: province?.id, moduleID: module?.id, model: assetModel, openPromptVault: openPromptVault)
                    }
                }
            }.padding(24).frame(maxWidth: CosmosDesign.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }
    private var categoryNavigation: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                tab("概览", id: "overview")
                tab("活动", id: "campaign")
                ForEach(store.categories.filter { $0.id != "overview" && $0.id != "campaign" }) { tab($0.name + (ZhuowangCategoryRoute(categoryID: $0.id) == .unsupported ? " · 未接入" : ""), id: $0.id) }
            }.padding(4).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    private func tab(_ name: String, id: String) -> some View {
        Button(name) { assetDestination = nil; selectedCategoryID = id }
            .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 7)
            .background(selectedCategoryID == id ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityAddTraits(selectedCategoryID == id ? .isSelected : [])
    }
    private func select(_ navigation: ZhuowangNavigationItem) {
        guard publicResources || selectedNavigation != navigation else { return }
        selectedNavigation = navigation; selectedCategoryID = "overview"; assetDestination = nil; publicResources = false
        if province?.isEnabled == false { showStoppedProvinces = true }
        assetModel.refresh()
    }
    private func open(_ campaign: ZhuowangCampaign, province: ZhuowangProvince?, module: ZhuowangModule?) {
        ZhuowangCampaignWindowManager.shared.open(campaign: campaign, store: campaignStore, workflowStore: workflowStore,
            province: province, module: module)
    }
}

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
