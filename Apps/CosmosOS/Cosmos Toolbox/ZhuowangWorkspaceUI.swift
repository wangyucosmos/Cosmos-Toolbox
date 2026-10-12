import SwiftUI

/// Read-only presentation projection; uses the workbench's existing rules.
enum ZhuowangWorkspaceUI {
    static func rows(campaigns: [ZhuowangCampaign], workflows: [ZhuowangCampaignWorkflow],
                     provinces: [ZhuowangProvince], modules: [ZhuowangModule],
                     manager: ZhuowangWorkspaceFileManager, now: Date = Date()) -> [ZhuowangCampaignProgress] {
        ZhuowangCampaignProgressBuilder.build(campaigns: campaigns, workflows: workflows,
            provinces: provinces, modules: modules, now: now, deliverableCounter: { campaign, province, artifacts, steps in
                ZhuowangCampaignProgressBuilder.deliveryPackageCount(campaign: campaign, provinceName: province,
                    artifacts: artifacts, steps: steps, workspaceFileManager: manager)
            })
    }
    static func scoped(_ rows: [ZhuowangCampaignProgress], scope: ZhuowangCampaignWorkbenchFilter.Scope) -> [ZhuowangCampaignProgress] {
        var filter = ZhuowangCampaignWorkbenchFilter(); filter.scope = scope
        return rows.filter(filter.matches)
    }
    static func badge(_ rows: [ZhuowangCampaignProgress], scope: ZhuowangCampaignWorkbenchFilter.Scope) -> (count: Int, attention: Bool) {
        let items = scoped(rows, scope: scope)
        return (items.count, items.contains { $0.category == .needsAttention })
    }
    static func dates(_ campaign: ZhuowangCampaign) -> String {
        CosmosDate.day(campaign.startDate) + " – " + CosmosDate.day(max(campaign.startDate, campaign.endDate))
    }
}

struct ZhuowangCampaignCardUI: View {
    let row: ZhuowangCampaignProgress
    let action: () -> Void
    var body: some View {
        CosmosWorkCard(title: row.campaign.name, scope: row.scopeName + (row.province?.isEnabled == false ? " · 已停用" : ""),
            dates: ZhuowangWorkspaceUI.dates(row.campaign), completed: row.completedSteps, total: row.totalSteps,
            adopted: row.adoptedArtifactCount, attention: row.category == .needsAttention,
            status: { ZhuowangCampaignStatusBadge(status: row.campaign.status) }, action: action)
    }
}

struct ZhuowangScopeOverviewUI: View {
    let title: String
    let rows: [ZhuowangCampaignProgress]
    let canCreate: Bool
    let create: () -> Void
    let open: (ZhuowangCampaignProgress) -> Void
    let assets: () -> Void
    @State private var metric: CosmosWorkbenchMetric?
    private var visible: [ZhuowangCampaignProgress] { rows.filter { metric?.matches($0) ?? true } }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ForEach(CosmosWorkbenchMetric.allCases) { item in metricTile(item).frame(minWidth: 130) }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(CosmosWorkbenchMetric.allCases) { item in metricTile(item) }
                }
            }
            if rows.isEmpty {
                CosmosEmptyState(icon: "megaphone", title: "开始在\(title)推进工作",
                    detail: canCreate ? "创建第一个活动，逐步整理需求、策划与工作产物。" : "当前范围已停用，历史工作仍可查看。",
                    actionTitle: canCreate ? "创建第一个活动" : nil, action: create)
            } else if visible.isEmpty {
                CosmosEmptyState(icon: "line.3.horizontal.decrease.circle", title: "此指标下暂无活动",
                    actionTitle: "查看全部", action: { metric = nil })
            } else {
                Text("活动 · \(visible.count)").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: 12) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, row in
                        ZhuowangCampaignCardUI(row: row) { open(row) }.cosmosScrollReveal()
                    }
                }
            }
            HStack {
                Button(action: create) { Label("在此新建活动", systemImage: "plus") }
                    .buttonStyle(.bordered).disabled(!canCreate)
                Spacer()
                Button(action: assets) { Label("查看该范围资料", systemImage: "archivebox") }.buttonStyle(.bordered)
            }
        }
    }
    private func metricTile(_ item: CosmosWorkbenchMetric) -> some View {
        CosmosMetricTile(icon: item.icon, title: item.title, value: rows.filter(item.matches).count,
            selected: metric == item) { metric = item.toggled(from: metric) }
    }

}
