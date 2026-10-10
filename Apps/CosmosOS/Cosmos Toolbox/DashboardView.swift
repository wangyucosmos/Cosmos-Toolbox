import SwiftUI

struct DashboardView: View {
    @State private var selection: SidebarItem? = .dashboard

    /// Reused across visits to the Home so unchanged data is not decoded again.
    @State private var homeCache = DashboardReadCache()

    /// Last finished AI 工作台 detection; memory only, never persisted.
    @State private var aiWorkspaceCache = AIWorkspaceResultCache()

    let storePersistenceConfiguration:
        ZhuowangStorePersistenceConfiguration

    init(
        storePersistenceConfiguration:
            ZhuowangStorePersistenceConfiguration = .production
    ) {
        self.storePersistenceConfiguration =
            storePersistenceConfiguration

#if DEBUG
        // Isolated UI acceptance only: open a sidebar item at launch so a
        // fixture run can be captured without scripting the interface.
        let arguments = ProcessInfo.processInfo.arguments
        if storePersistenceConfiguration.isIsolated,
           let index = arguments.firstIndex(of: "--cosmos-initial-sidebar"),
           index + 1 < arguments.count,
           ["zhuowang", "knowledgeBase", "promptVault", "learningCenter", "aiWorkspace", "settings"].contains(arguments[index + 1]) {
            _selection = State(initialValue: SidebarItem(rawValue: arguments[index + 1]))
        }
#endif
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

    private var coreBackupSource: CoreBackupSource {
#if DEBUG
        let handoff = AIWorkspaceHandoffLocation.resolve(isIsolated: storePersistenceConfiguration.isIsolated,
            bundleIdentifier: Bundle.main.bundleIdentifier, arguments: ProcessInfo.processInfo.arguments)
#else
        let handoff = AIWorkspaceHandoffLocation.resolve(isIsolated: false, bundleIdentifier: nil, arguments: [])
#endif
        return CoreBackupSource(configuration: storePersistenceConfiguration,
            promptRoot: promptVaultLocation.root, learningRoot: learningLocation.root, handoffRoot: handoff.root)
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
        NavigationSplitView {
            List(selection: $selection) {

                Section("首页 · Home") {
                    sidebarRow(.dashboard)
                }

                Section("工作 · Work") {
                    sidebarRow(.zhuowang)
                    sidebarRow(.projects)
                    sidebarRow(.knowledgeBase)
                }

                Section("AI") {
                    sidebarRow(.aiWorkspace)
                    sidebarRow(.promptVault)
                }

                Section("学习 · Learning") {
                    sidebarRow(.learningCenter)
                }

                Section("系统 · System") {
                    sidebarRow(.macOptimizer)
                    sidebarRow(.settings)
                }
            }
            .navigationTitle("Cosmos OS")
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
                        cache: homeCache,
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
                            storePersistenceConfiguration
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

                } else if selection == .knowledgeBase {
                    ZhuowangAssetCenterView(
                        configuration: storePersistenceConfiguration,
                        isolatedRoot: isolatedAssetRoot
                    )
                    .id(SidebarItem.knowledgeBase)

                } else if selection == .promptVault {
                    PromptVaultView(location: promptVaultLocation)
                        .id(SidebarItem.promptVault)

                } else if selection == .learningCenter {
                    LearningCenterView(location: learningLocation)
                        .id(SidebarItem.learningCenter)

                } else if selection == .aiWorkspace {
                    AIWorkspaceView(cache: aiWorkspaceCache, configuration: storePersistenceConfiguration, referenceRoot: isolatedAssetRoot, autoDetect: aiWorkspaceAutoDetect)
                        .id(SidebarItem.aiWorkspace)

                } else if selection == .settings {
                    CoreBackupSettingsView(source: coreBackupSource, restoreTarget: try? CoreRestoreTarget.resolve(configuration: storePersistenceConfiguration))
                        .id(SidebarItem.settings)

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
            .animation(
                .spring(
                    response: 0.42,
                    dampingFraction: 0.88,
                    blendDuration: 0.12
                ),
                value: selection
            )
        }
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

                Text(item.chineseName)

                Text(item.englishName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        } icon: {

            Image(systemName: item.icon)
        }
        .tag(item)
    }
}


// MARK: - Cosmos Card

struct CosmosCard<Content: View>: View {

    let icon: String
    let title: String
    let englishTitle: String

    @ViewBuilder
    let content: Content

    @State
    private var isHovering = false


    init(
        icon: String,
        title: String,
        englishTitle: String,
        @ViewBuilder content: () -> Content
    ) {

        self.icon = icon
        self.title = title
        self.englishTitle = englishTitle
        self.content = content()
    }


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingXL
        ) {

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
                    spacing: CosmosDesign.spacingXS
                ) {

                    Text(title)
                        .font(.headline)

                    Text(englishTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content

            Spacer()
        }
        .frame(
            maxWidth: .infinity,
            minHeight: CosmosDesign.cardMinHeight,
            alignment: .topLeading
        )
        .modifier(
            CosmosCardStyle(
                isHovering: isHovering
            )
        )
        .contentShape(Rectangle())
        .onHover { hovering in

            isHovering = hovering
        }
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
