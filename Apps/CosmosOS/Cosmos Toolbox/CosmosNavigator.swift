import Foundation
import Observation

nonisolated enum CosmosWorkbenchMetric: String, CaseIterable, Identifiable, Sendable {
    case all, ongoing, attention, deliverable
    var id: String { rawValue }
    var title: String { switch self { case .all: return "活动总数"; case .ongoing: return "活动日期内"; case .attention: return "失败或需修改"; case .deliverable: return "可以交付" } }
    var icon: String { switch self { case .all: return "megaphone"; case .ongoing: return "calendar"; case .attention: return "exclamationmark.triangle"; case .deliverable: return "shippingbox" } }
    @MainActor func matches(_ row: ZhuowangCampaignProgress) -> Bool {
        switch self { case .all: return true; case .ongoing: return row.datePhase == .ongoing; case .attention: return row.category == .needsAttention; case .deliverable: return row.category == .deliverable }
    }
    func toggled(from selected: Self?) -> Self? { selected == self ? nil : self }
}
nonisolated enum CosmosSettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general, data, about
    var id: String { rawValue }
    var title: String { switch self { case .general: return "通用"; case .data: return "数据与备份"; case .about: return "关于" } }
    var icon: String { switch self { case .general: return "gearshape"; case .data: return "externaldrive"; case .about: return "info.circle" } }
}
nonisolated enum CosmosKnowledgeSection: String, Sendable { case notes, assets }
nonisolated enum CosmosDestination: Equatable {
    case module(String), workbench(CosmosWorkbenchMetric), knowledge(CosmosKnowledgeSection)
    case search(String), settings(CosmosSettingsTab), record(UnifiedSearchRow)
}
nonisolated enum CosmosDashboardLink: CaseIterable {
    case campaigns, ongoing, attention, deliverable, notes, prompts, learning, distribution, workflow, learningChart, mac, ai
    var destination: CosmosDestination {
        switch self {
        case .campaigns, .distribution, .workflow: return .workbench(.all)
        case .ongoing: return .workbench(.ongoing)
        case .attention: return .workbench(.attention)
        case .deliverable: return .workbench(.deliverable)
        case .notes: return .knowledge(.notes)
        case .prompts: return .module("promptVault")
        case .learning, .learningChart: return .module("learningCenter")
        case .mac: return .module("macOptimizer")
        case .ai: return .module("aiWorkspace")
        }
    }
}

@Observable @MainActor
final class CosmosNavigator {
    static let shared = CosmosNavigator()
    var selection: SidebarItem? = .dashboard
    var pendingWorkbenchMetric: CosmosWorkbenchMetric?
    var knowledgeSection: CosmosKnowledgeSection = .notes
    var searchText = ""
    var lastSearchText = ""
    var settingsTab: CosmosSettingsTab = .general
    var settingsRequest = 0
    var newRecordRequest: UnifiedSearchSource?
    var recordRequest: UnifiedSearchRow?
    func navigate(_ destination: CosmosDestination, isolated: Bool = false) {
        switch destination {
        case .module(let name):
            guard let item = SidebarItem(rawValue: name), item != .settings else { return }
            pendingWorkbenchMetric = nil; selection = item
        case .workbench(let metric): pendingWorkbenchMetric = metric; selection = .zhuowang
        case .knowledge(let section): knowledgeSection = section; selection = .knowledgeBase
        case .search(let text): searchText = text; selection = .unifiedSearch
        case .settings(let tab): settingsTab = tab; settingsRequest += 1
        case .record(let row):
            if isolated && row.id.source == .campaign { navigate(.workbench(.all)) }
            else { recordRequest = row }
        }
    }
    func consumeWorkbenchMetric() -> CosmosWorkbenchMetric? {
        let metric = pendingWorkbenchMetric
        pendingWorkbenchMetric = nil
        return metric
    }
}
