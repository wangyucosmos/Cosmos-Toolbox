import SwiftUI

struct DashboardView: View {
    @Environment(\.cosmosNavigator) private var navigator
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    @Environment(\.openSettings) private var openSettings
    @State private var didRestoreNavigation = false
    @State private var preciseNavigator: UnifiedSearchNavigator?
    @State private var navigationMessage: String?
    private var selection: SidebarItem? {
        get { navigator.selection }
        nonmutating set { navigator.selection = newValue }
    }

    /// Reused across visits to the Home so unchanged data is not decoded again.
    @State private var homeCache = DashboardReadCache()

    /// Last finished AI 工作台 detection; memory only, never persisted.
    @State private var aiWorkspaceCache = AIWorkspaceResultCache()

    @StateObject private var macEnvironment = MacEnvironmentViewModel()

    let storePersistenceConfiguration:
        ZhuowangStorePersistenceConfiguration

    init(
        storePersistenceConfiguration:
            ZhuowangStorePersistenceConfiguration = .production
    ) {
        self.storePersistenceConfiguration =
            storePersistenceConfiguration


    }

    var body: some View {
#if DEBUG
        if storePersistenceConfiguration.isIsolated {
            VStack(spacing: 0) {
                isolatedSuiteBanner
                navigationContent
            }
        } else {
            navigationContent
        }
#else
        navigationContent
#endif
    }


    private func dashboardLocation(
        root: URL?,
        reason: String?
    ) -> DashboardLocation {
        if let root {
            return .root(root)
        }
        return .blocked(reason ?? "存储位置不可用")
    }

    private var promptVaultLocation: PromptVaultLocation {
#if DEBUG
        PromptVaultLocation.resolve(isIsolated: storePersistenceConfiguration.isIsolated,
            bundleIdentifier: Bundle.main.bundleIdentifier, arguments: ProcessInfo.processInfo.arguments)
#else
        PromptVaultLocation.resolve(isIsolated: false, bundleIdentifier: nil, arguments: [])
#endif
    }

    private var learningLocation: LearningLocation {
#if DEBUG
        LearningLocation.resolve(isIsolated: storePersistenceConfiguration.isIsolated,
            bundleIdentifier: Bundle.main.bundleIdentifier, arguments: ProcessInfo.processInfo.arguments)
#else
        LearningLocation.resolve(isIsolated: false, bundleIdentifier: nil, arguments: [])
#endif
    }

    private var projectsLocation: ProjectsLocation {
#if DEBUG
        ProjectsLocation.resolve(isIsolated: storePersistenceConfiguration.isIsolated, bundleIdentifier: Bundle.main.bundleIdentifier, arguments: ProcessInfo.processInfo.arguments)
#else
        ProjectsLocation.resolve(isIsolated: false, bundleIdentifier: nil, arguments: [])
#endif
    }

    private var personalNotesLocation: PersonalNotesLocation {
#if DEBUG
        PersonalNotesLocation.resolve(isIsolated: storePersistenceConfiguration.isIsolated, bundleIdentifier: Bundle.main.bundleIdentifier,
            arguments: ProcessInfo.processInfo.arguments, referenceRoot: isolatedAssetRoot)
#else
        PersonalNotesLocation.resolve(isIsolated: false, bundleIdentifier: nil, arguments: [])
#endif
    }

    private var coreBackupSource: CoreBackupSource {
#if DEBUG
        let handoff = AIWorkspaceHandoffLocation.resolve(isIsolated: storePersistenceConfiguration.isIsolated,
            bundleIdentifier: Bundle.main.bundleIdentifier, arguments: ProcessInfo.processInfo.arguments)
#else
        let handoff = AIWorkspaceHandoffLocation.resolve(isIsolated: false, bundleIdentifier: nil, arguments: [])
#endif
        return CoreBackupSource(configuration: storePersistenceConfiguration,
            promptRoot: promptVaultLocation.root, learningRoot: learningLocation.root, handoffRoot: handoff.root, projectsRoot: projectsLocation.root,
            notesRoot: personalNotesLocation.root)
    }

    /// Isolated UI acceptance only: run the AI 工作台 detection on arrival.
    private var aiWorkspaceAutoDetect: Bool {
#if DEBUG
        storePersistenceConfiguration.isIsolated
            && ProcessInfo.processInfo.arguments.contains("--cosmos-ai-workspace-autodetect")
#else
        false
#endif
    }

    private var isolatedAssetRoot: URL? {
#if DEBUG
        guard storePersistenceConfiguration.isIsolated else { return nil }
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--cosmos-asset-fixture-root"),
              index + 1 < arguments.count else { return nil }
        let path = arguments[index + 1]
        guard path.hasPrefix("/private/tmp/CosmosAssetPhase1-"),
              !path.split(separator: "/").contains("..") else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
#else
        return nil
#endif
    }

    private var navigationContent: some View {
        return NavigationSplitView {
            List(selection: Binding(get: { selection }, set: { navigator.pendingWorkbenchMetric = nil; selection = $0 })) {

                Section("首页") {
                    sidebarRow(.dashboard)
                    sidebarRow(.unifiedSearch)
                }

                Section("工作") {
                    sidebarRow(.zhuowang)
                    sidebarRow(.projects)
                    sidebarRow(.knowledgeBase)
                }

                Section("AI") {
                    sidebarRow(.aiWorkspace)
                    sidebarRow(.promptVault)
                }

                Section("学习") {
                    sidebarRow(.learningCenter)
                }

                Section("系统") {
                    sidebarRow(.macOptimizer)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { navigator.navigate(.settings(.general)) } label: {
                    Label("设置", systemImage: "gearshape").frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }.buttonStyle(.plain).padding(10)
            }
            .navigationSplitViewColumnWidth(
                min: 220,
                ideal: 250
            )

        } detail: {

            ZStack {
                if selection == .dashboard {

                    DashboardHomeView(
                        configuration:
                            storePersistenceConfiguration,
                        promptLocation:
                            dashboardLocation(
                                root: promptVaultLocation.root,
                                reason: promptVaultLocation.error?.localizedDescription
                            ),
                        learningLocation:
                            dashboardLocation(
                                root: learningLocation.root,
                                reason: learningLocation.error?.localizedDescription
                            ),
                        notesLocation: dashboardLocation(root: personalNotesLocation.root, reason: personalNotesLocation.error?.localizedDescription),
                        cache: homeCache, mac: macEnvironment, ai: aiWorkspaceCache,
                        open: { selection = $0 }
                    )
                        .id(SidebarItem.dashboard)
                        .transition(
                            .asymmetric(
                                insertion:
                                    .opacity
                                    .combined(
                                        with: .offset(x: 18, y: 0)
                                    ),
                                removal:
                                    .opacity
                                    .combined(
                                        with: .offset(x: -8, y: 0)
                                    )
                            )
                        )

                } else if selection == .zhuowang {

                    ZhuowangWorkspaceView(
                        persistenceConfiguration:
                            storePersistenceConfiguration,
                        isolatedAssetRoot: isolatedAssetRoot,
                        openPromptVault: { selection = .promptVault }
                    )
                        .id(SidebarItem.zhuowang)
                        .transition(
                            .asymmetric(
                                insertion:
                                    .opacity
                                    .combined(
                                        with: .offset(x: 18, y: 0)
                                    ),
                                removal:
                                    .opacity
                                    .combined(
                                        with: .offset(x: -8, y: 0)
                                    )
                            )
                        )

                } else if selection == .unifiedSearch {
                    UnifiedSearchView(configuration: storePersistenceConfiguration,
                        projects: projectsLocation, prompts: promptVaultLocation,
                        learning: learningLocation, notes: personalNotesLocation, assetRoot: isolatedAssetRoot)
                        .id(SidebarItem.unifiedSearch)

                } else if selection == .knowledgeBase {
                    CosmosKnowledgeDestinationView(
                        configuration: storePersistenceConfiguration,
                        isolatedRoot: isolatedAssetRoot,
                        notesLocation: personalNotesLocation,
                        promptLocation: promptVaultLocation
                    )
                    .id(SidebarItem.knowledgeBase)

                } else if selection == .promptVault {
                    PromptVaultView(location: promptVaultLocation, notesLocation: personalNotesLocation)
                        .id(SidebarItem.promptVault)

                } else if selection == .learningCenter {
                    LearningCenterView(location: learningLocation)
                        .id(SidebarItem.learningCenter)

                } else if selection == .aiWorkspace {
                    AIWorkspaceView(cache: aiWorkspaceCache, configuration: storePersistenceConfiguration, referenceRoot: isolatedAssetRoot, autoDetect: aiWorkspaceAutoDetect)
                        .id(SidebarItem.aiWorkspace)

                } else if selection == .projects {
                    ProjectsView(location: projectsLocation)
                        .id(SidebarItem.projects)

                } else if selection == .macOptimizer {
                    MacEnvironmentView(model: macEnvironment)
                        .id(SidebarItem.macOptimizer)

                } else if let selection {

                    PlaceholderView(item: selection)
                        .id(selection)
                        .transition(
                            .asymmetric(
                                insertion:
                                    .opacity
                                    .combined(
                                        with: .offset(x: 18, y: 0)
                                    ),
                                removal:
                                    .opacity
                                    .combined(
                                        with: .offset(x: -8, y: 0)
                                    )
                            )
                        )
                }
            }
            .id(selection)
            .transition(preferences.reducesMotion(system: systemMotion) ? .opacity : .opacity.combined(with: .offset(x: 8)))
            .animation(preferences.reducesMotion(system: systemMotion) ? nil : CosmosDesign.motion, value: selection)
        }
        .modifier(CosmosMotionPolicy())
        .task { restoreNavigationOnce() }
        .onChange(of: selection) { _, value in
            if let value, value != .settings { preferences.lastPage = value.rawValue }
        }
        .onChange(of: navigator.settingsRequest) { _, _ in openSettings() }
        .onChange(of: navigator.newRecordRequest) { _, source in
            guard let source else { return }
            Task {
                if source == .note {
                    let store = PersonalNotesStore(location: personalNotesLocation); await store.reload()
                    if store.canSave { PersonalNoteWindowManager.shared.open(store: store, note: nil) }
                    else { navigationMessage = store.error?.localizedDescription ?? "笔记库不可编辑" }
                } else if source == .prompt {
                    let store = PromptVaultStore(root: promptVaultLocation.root, startupError: promptVaultLocation.error); await store.reload()
                    if store.canSave { PromptTemplateWindowManager.shared.open(store: store, template: nil) }
                    else { navigationMessage = store.error?.localizedDescription ?? "提示词库不可编辑" }
                }
                navigator.newRecordRequest = nil
            }
        }
        .onChange(of: navigator.recordRequest) { _, row in
            guard let row else { return }
            if storePersistenceConfiguration.isIsolatedForUI && row.id.source == .campaign {
                navigator.navigate(.workbench(.all)); navigator.recordRequest = nil; return
            }
            Task { await openRecord(row); navigator.recordRequest = nil }
        }
        .alert("打开记录", isPresented: Binding(get: { navigationMessage != nil }, set: { if !$0 { navigationMessage = nil } })) {
            Button("好") { navigationMessage = nil }
        } message: { Text(navigationMessage ?? "") }
    }

    private func restoreNavigationOnce() {
        guard !didRestoreNavigation else { return }; didRestoreNavigation = true
        if preferences.startup == .lastPage { selection = SidebarItem(rawValue: preferences.lastPage) ?? .dashboard }
#if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if storePersistenceConfiguration.isIsolated, let index = args.firstIndex(of: "--cosmos-initial-sidebar"), index + 1 < args.count {
            if args[index + 1] == "settings" { navigator.navigate(.settings(.general)) }
            else if let item = SidebarItem(rawValue: args[index + 1]) { selection = item }
        }
#endif
    }

    private func openRecord(_ row: UnifiedSearchRow) async {
        if preciseNavigator == nil {
            var roots: [UnifiedSearchSource: URL] = [:], blocked: [UnifiedSearchSource: String] = [:]
            for (key, root, error) in [(UnifiedSearchSource.project, projectsLocation.root, projectsLocation.error?.localizedDescription),
                (.prompt, promptVaultLocation.root, promptVaultLocation.error?.localizedDescription),
                (.learning, learningLocation.root, learningLocation.error?.localizedDescription),
                (.note, personalNotesLocation.root, personalNotesLocation.error?.localizedDescription)] {
                if let root { roots[key] = root } else { blocked[key] = error ?? "位置不可用" }
            }
            let dataSource = storePersistenceConfiguration.dataSource
            let reader = UnifiedSearchReader(readPreference: { key in
                if let source = dataSource as? ZhuowangUserDefaultsDataSource { return try source.coreBackupData(forKey: key) }
                return dataSource.data(forKey: key)
            }, roots: roots, blocked: blocked)
            preciseNavigator = UnifiedSearchNavigator(reader: reader, configuration: storePersistenceConfiguration,
                projects: projectsLocation, prompts: promptVaultLocation, learning: learningLocation, notes: personalNotesLocation, assetRoot: isolatedAssetRoot)
        }
        await preciseNavigator?.open(row)
        navigationMessage = preciseNavigator?.message
    }

#if DEBUG
    private var isolatedSuiteBanner: some View {
        HStack(spacing: CosmosDesign.spacingS) {
            Image(systemName: "testtube.2")

            Text("Store Phase 1 隔离测试数据")
                .fontWeight(.semibold)

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(
                    "Bundle: "
                    + (
                        storePersistenceConfiguration
                            .isolationBundleIdentifier
                        ?? "未知 Bundle"
                    )
                )

                Text(
                    "suite: "
                    + (
                        storePersistenceConfiguration
                            .isolationSuiteName
                        ?? "未知 suite"
                    )
                )
            }
            .font(.caption.monospaced())
            .lineLimit(1)
            .textSelection(.enabled)

            Spacer()
        }
        .font(.callout)
        .padding(
            .horizontal,
            CosmosDesign.spacingL
        )
        .padding(
            .vertical,
            CosmosDesign.spacingS
        )
        .foregroundStyle(.orange)
        .background(
            Color.orange.opacity(0.10)
        )
    }
#endif

    @ViewBuilder
    private func sidebarRow(
        _ item: SidebarItem
    ) -> some View {

        Label {
            VStack(
                alignment: .leading,
                spacing: CosmosDesign.spacingXS
            ) {

                Text(item.chineseName).font(CosmosDesign.font(.body))

                if preferences.sidebarEnglish {
                    Text(item.englishName).font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
                }
            }

        } icon: {

            Image(systemName: item.icon)
        }
        .frame(minHeight: 30)
        .tag(item)
    }
}


// MARK: - Placeholder

struct PlaceholderView: View {

    let item: SidebarItem

    var body: some View {

        VStack(
            spacing: CosmosDesign.spacingM
        ) {

            Image(
                systemName: item.icon
            )
            .font(
                .system(size: 42)
            )
            .foregroundStyle(.secondary)

            Text(item.chineseName)
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text(item.englishName)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}


// MARK: - Sidebar Model

enum SidebarItem:
    String,
    CaseIterable,
    Identifiable {

    case dashboard
    case unifiedSearch
    case zhuowang
    case projects
    case knowledgeBase
    case aiWorkspace
    case promptVault
    case learningCenter
    case macOptimizer
    case settings


    var id: String {
        rawValue
    }


    var chineseName: String {

        switch self {

        case .unifiedSearch:
            return "统一检索"

        case .dashboard:
            return "仪表盘"

        case .zhuowang:
            return "卓望工作"

        case .projects:
            return "项目"

        case .knowledgeBase:
            return "知识库"

        case .aiWorkspace:
            return "AI 工作台"

        case .promptVault:
            return "提示词库"

        case .learningCenter:
            return "AI 学习中心"

        case .macOptimizer:
            return "Mac 优化"

        case .settings:
            return "设置"
        }
    }


    var englishName: String {

        switch self {

        case .unifiedSearch:
            return "Unified Search"

        case .dashboard:
            return "Dashboard"

        case .zhuowang:
            return "Zhuowang Workspace"

        case .projects:
            return "Projects"

        case .knowledgeBase:
            return "Knowledge Base"

        case .aiWorkspace:
            return "AI Workspace"

        case .promptVault:
            return "Prompt Vault"

        case .learningCenter:
            return "AI Learning Center"

        case .macOptimizer:
            return "Mac Optimizer"

        case .settings:
            return "Settings"
        }
    }


    var icon: String {

        switch self {

        case .unifiedSearch:
            return "magnifyingglass"

        case .dashboard:
            return "square.grid.2x2"

        case .zhuowang:
            return "briefcase"

        case .projects:
            return "folder"

        case .knowledgeBase:
            return "books.vertical"

        case .aiWorkspace:
            return "sparkles"

        case .promptVault:
            return "text.book.closed"

        case .learningCenter:
            return "graduationcap"

        case .macOptimizer:
            return "wrench.and.screwdriver"

        case .settings:
            return "gearshape"
        }
    }
}


// MARK: - Preview

#Preview {
    DashboardView()
}
