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
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            if let selection {
                VStack(spacing: 12) {
                    Image(systemName: selection.icon)
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)

                    Text(selection.chineseName)
                        .font(.largeTitle)
                        .fontWeight(.semibold)

                    Text(selection.englishName)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func sidebarRow(_ item: SidebarItem) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
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

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard
    case zhuowang
    case projects
    case knowledgeBase
    case aiWorkspace
    case promptVault
    case learningCenter
    case macOptimizer
    case settings

    var id: String { rawValue }

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

#Preview {
    DashboardView()
}
