import SwiftUI

struct DashboardView: View {
    @State private var selection: SidebarItem? = .dashboard

    var body: some View {
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
                    DashboardHomeView()
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


// MARK: - Dashboard Home

struct DashboardHomeView: View {

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: CosmosDesign.spacingXXL
            ) {

                header

                topCards

                recentProjects

                bottomCards
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
                maxWidth: CosmosDesign.contentMaxWidth,
                alignment: .leading
            )
        }
        .background(
            Color(nsColor: .windowBackgroundColor)
        )
    }


    // MARK: Header

    private var header: some View {

        HStack(
            alignment: .center
        ) {

            VStack(
                alignment: .leading,
                spacing: CosmosDesign.spacingS
            ) {

                Text("下午好")
                    .font(
                        .system(
                            size: 32,
                            weight: .semibold
                        )
                    )

                Text("Welcome back to Cosmos OS")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "sparkles")
                .font(
                    .system(
                        size: 21,
                        weight: .medium
                    )
                )
                .foregroundStyle(.secondary)
                .padding(CosmosDesign.spacingM)
                .background(.thinMaterial)
                .clipShape(Circle())
        }
    }


    // MARK: Top Cards

    private var topCards: some View {

        HStack(
            spacing: CosmosDesign.spacingL
        ) {

            CosmosCard(
                icon: "checklist",
                title: "今日工作",
                englishTitle: "Today"
            ) {

                VStack(
                    alignment: .leading,
                    spacing: CosmosDesign.spacingS
                ) {

                    Text("3")
                        .font(
                            .system(
                                size: 42,
                                weight: .semibold,
                                design: .rounded
                            )
                        )

                    Text("项待处理任务")
                        .foregroundStyle(.secondary)
                }
            }


            CosmosCard(
                icon: "graduationcap",
                title: "学习进度",
                englishTitle: "Learning"
            ) {

                VStack(
                    alignment: .leading,
                    spacing: CosmosDesign.spacingM
                ) {

                    HStack(
                        alignment: .firstTextBaseline
                    ) {

                        Text("Python")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Spacer()

                        Text("28%")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: 0.28)
                        .progressViewStyle(.linear)
                }
            }
        }
    }


    // MARK: Recent Projects

    private var recentProjects: some View {

        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {

            HStack {

                CosmosSectionTitle(
                    title: "最近项目",
                    subtitle: "Recent Projects"
                )

                Spacer()

                Button {

                } label: {

                    HStack(
                        spacing: CosmosDesign.spacingXS
                    ) {

                        Text("查看全部")

                        Image(
                            systemName: "arrow.right"
                        )
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }


            VStack(spacing: 0) {

                ProjectRow(
                    icon: "briefcase",
                    title: "河南 9 月促活",
                    subtitle: "Zhuowang Workspace",
                    time: "刚刚"
                )

                Divider()
                    .padding(.leading, 52)


                ProjectRow(
                    icon: "sportscourt",
                    title: "亚运竞猜",
                    subtitle: "Campaign Planning",
                    time: "今天"
                )

                Divider()
                    .padding(.leading, 52)


                ProjectRow(
                    icon: "hammer",
                    title: "Cosmos OS",
                    subtitle: "Personal Project",
                    time: "今天"
                )
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
                    Color.primary.opacity(0.065),
                    lineWidth: 1
                )
            }
        }
    }


    // MARK: Bottom Cards

    private var bottomCards: some View {

        HStack(
            spacing: CosmosDesign.spacingL
        ) {

            CosmosCard(
                icon: "sparkles",
                title: "AI 工作台",
                englishTitle: "AI Workspace"
            ) {

                VStack(
                    alignment: .leading,
                    spacing: CosmosDesign.spacingS
                ) {

                    HStack(
                        alignment: .firstTextBaseline,
                        spacing: CosmosDesign.spacingS
                    ) {

                        Text("8")
                            .font(
                                .system(
                                    size: 36,
                                    weight: .semibold,
                                    design: .rounded
                                )
                            )

                        Text("/ 9")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Text("核心环境运行正常")
                        .foregroundStyle(.secondary)
                }
            }


            CosmosCard(
                icon: "checkmark.circle",
                title: "系统状态",
                englishTitle: "System"
            ) {

                VStack(
                    alignment: .leading,
                    spacing: CosmosDesign.spacingS
                ) {

                    HStack {

                        Text("运行正常")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Spacer()

                        CosmosStatusBadge(
                            text: "正常",
                            icon: "checkmark"
                        )
                    }

                    Text("No issues detected")
                        .foregroundStyle(.secondary)
                }
            }
        }
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


// MARK: - Project Row

struct ProjectRow: View {

    let icon: String
    let title: String
    let subtitle: String
    let time: String

    @State
    private var isHovering = false


    var body: some View {

        HStack(
            spacing: CosmosDesign.spacingM
        ) {

            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.secondary)

            VStack(
                alignment: .leading,
                spacing: CosmosDesign.spacingXS
            ) {

                Text(title)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(time)
                .font(.caption)
                .foregroundStyle(.tertiary)

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
                ? Color.primary.opacity(0.035)
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
