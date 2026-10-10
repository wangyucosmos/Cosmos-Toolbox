import SwiftUI


// MARK: - Campaign Progress Workbench

/// One-screen, read-only summary of every Campaign: Workflow progress,
/// next actions, dates and adopted work. Actions open the existing Campaign
/// window (overview, AI Workflow, 工作产物 or the delivery-package sheet).
struct ZhuowangCampaignWorkbenchView: View {

    @ObservedObject var campaignStore: ZhuowangCampaignStore
    @ObservedObject var workspaceStore: ZhuowangWorkspaceStore
    @ObservedObject var workflowStore: ZhuowangWorkflowStore

    /// Set when embedded in a province / module overview; hides the scope
    /// picker and the page header.
    var fixedScope: ZhuowangCampaignWorkbenchFilter.Scope?

    var now: () -> Date = Date.init
    var permitsDetailOpening = true
    @Environment(\.cosmosNavigator) private var navigator
    @State private var selectedMetric: CosmosWorkbenchMetric?

    /// Defaults to the delivery-package eligibility rules.
    var deliverableCounter: ZhuowangCampaignProgressBuilder.DeliverableCounter?

    @State
    private var filter = ZhuowangCampaignWorkbenchFilter()

    /// Ended Campaigns older than this are counted but not listed.
    private let recentlyEndedDays = 30

    var body: some View {
        let today = now()
        let all = ZhuowangCampaignProgressBuilder.build(
            campaigns: campaignStore.campaigns,
            workflows: workflowStore.workflows,
            provinces: workspaceStore.provinces,
            modules: workspaceStore.modules,
            now: today,
            deliverableCounter: effectiveDeliverableCounter
        )
        var effective = filter
        if let fixedScope {
            effective.scope = fixedScope
        }
        var scopeOnly = ZhuowangCampaignWorkbenchFilter()
        scopeOnly.scope = effective.scope
        let scoped = all.filter(scopeOnly.matches)
        let visible = scoped.filter(effective.matches).filter { selectedMetric?.matches($0) ?? true }

        return VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingXL
        ) {
            if fixedScope == nil {
                header
            }

            metrics(scoped)
            filterBar

            if scoped.isEmpty {
                emptyState(
                    title: "还没有活动",
                    message: "在左侧选择省份或模块，进入「活动」分类新建活动后，进度会自动汇总到这里。",
                    showsClear: false
                )
            } else if visible.isEmpty {
                emptyState(
                    title: "没有符合条件的活动",
                    message: "调整或清除省份、状态和名称筛选后再查看。",
                    showsClear: true
                )
            } else {
                actionSection(visible)
                timelineSection(visible, today: today)
                overviewSection(visible)
            }
        }
        .onAppear { applyPendingMetric() }
        .onChange(of: navigator.pendingWorkbenchMetric) { _, _ in applyPendingMetric() }
    }


    private var effectiveDeliverableCounter: ZhuowangCampaignProgressBuilder.DeliverableCounter? {
        if let deliverableCounter { return deliverableCounter }
        if campaignStore.persistenceConfiguration.isIsolatedForUI { return { _, _, _, _ in 0 } }
        return nil
    }

    private func applyMetric(_ metric: CosmosWorkbenchMetric?) {
        selectedMetric = metric
    }

    private func applyPendingMetric() {
        guard fixedScope == nil, let metric = navigator.consumeWorkbenchMetric() else { return }
        filter = ZhuowangCampaignWorkbenchFilter()
        applyMetric(metric)
    }

    // MARK: Header / Metrics

    private var header: some View {
        CosmosPageHeader("推进工作台", subtitle: "查看活动日期、Workflow 状态与采用产物。",
            info: "只读汇总全部活动，不修改状态或采用版本。指标遵循下方推进列表的分组口径；点击筛选，再点同一指标取消。")
    }

    private func metrics(_ items: [ZhuowangCampaignProgress]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
            ForEach(CosmosWorkbenchMetric.allCases) { metric in
                CosmosMetricTile(icon: metric.icon, title: metric.title, value: items.filter(metric.matches).count,
                    selected: selectedMetric == metric) {
                    applyMetric(metric.toggled(from: selectedMetric))
                }
            }
        }
    }


    // MARK: Filter

    private var filterBar: some View {
        HStack(spacing: CosmosDesign.spacingM) {
            HStack(spacing: CosmosDesign.spacingS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索活动名称", text: $filter.query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, CosmosDesign.spacingM)
            .padding(.vertical, 7)
            .background(
                Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusSmall, style: .continuous)
            )
            .frame(maxWidth: 280)

            if fixedScope == nil {
                Picker("省份", selection: $filter.scope) {
                    Text("全部省份 / 模块").tag(ZhuowangCampaignWorkbenchFilter.Scope.all)
                    Divider()
                    ForEach(workspaceStore.provinces) { province in
                        Text(province.isEnabled ? province.name : province.name + "（已停用）")
                            .tag(ZhuowangCampaignWorkbenchFilter.Scope.province(province.id))
                    }
                    Divider()
                    ForEach(workspaceStore.modules.filter { !$0.usesProvinces }) { module in
                        Text(module.name)
                            .tag(ZhuowangCampaignWorkbenchFilter.Scope.module(module.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 170)
            }

            Picker("活动状态", selection: $filter.status) {
                Text("全部状态").tag(ZhuowangCampaignStatus?.none)
                Divider()
                ForEach(ZhuowangCampaignStatus.allCases) { status in
                    Text(status.title).tag(ZhuowangCampaignStatus?.some(status))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 130)

            if isFiltering {
                Button("清除筛选") {
                    filter = ZhuowangCampaignWorkbenchFilter(); selectedMetric = nil
                }
                .buttonStyle(.borderless)
            }

            Spacer()
        }
    }


    private var isFiltering: Bool {
        selectedMetric != nil || filter.status != nil
            || !filter.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (fixedScope == nil && filter.scope != .all)
    }


    // MARK: Action List

    private func actionSection(_ items: [ZhuowangCampaignProgress]) -> some View {
        let groups = ZhuowangCampaignActionCategory.allCases.compactMap { category in
            let rows = items
                .filter { $0.category == category }
                .sorted { Self.byStartDate($0, $1) }
            return rows.isEmpty ? nil : (category, rows)
        }

        return VStack(alignment: .leading, spacing: CosmosDesign.spacingM) {
            CosmosSectionTitle(title: "推进列表", subtitle: "Next Actions")

            Text("按 AI Workflow 的真实步骤状态分组；每个活动只出现一次。")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {

                ForEach(Array(groups.enumerated()), id: \.element.0) { index, group in
                    if index > 0 {
                        Divider()
                    }
                    actionGroup(group.0, rows: group.1)
                }
            }
            .modifier(WorkbenchPanel())
        }
    }


    private func actionGroup(
        _ category: ZhuowangCampaignActionCategory,
        rows: [ZhuowangCampaignProgress]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("\(category.title) · \(rows.count)", systemImage: category.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(category == .needsAttention ? Color.orange : Color.secondary)
                .padding(.horizontal, CosmosDesign.spacingL)
                .padding(.top, CosmosDesign.spacingM)
                .padding(.bottom, CosmosDesign.spacingS)

            ForEach(rows) { row in
                HStack(spacing: CosmosDesign.spacingM) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: CosmosDesign.spacingS) {
                            Text(row.campaign.name)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(row.scopeName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(row.nextActionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: CosmosDesign.spacingM)

                    Text(progressText(row))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    actionButtons(row)
                }
                .padding(.horizontal, CosmosDesign.spacingL)
                .padding(.vertical, CosmosDesign.spacingS)
            }
            .padding(.bottom, CosmosDesign.spacingS)
        }
    }


    @ViewBuilder
    private func actionButtons(_ row: ZhuowangCampaignProgress) -> some View {
        switch row.category {
        case .deliverable:
            Button("导出交付包") {
                open(row, .deliveryPackage)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Button("查看产物") {
                open(row, .artifacts)
            }
            .controlSize(.small)
        case .completedFilesUnavailable:
            Button("查看产物") {
                open(row, .artifacts)
            }
            .controlSize(.small)
        default:
            Button("打开 Workflow") {
                open(row, .workflow)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }


    // MARK: Timeline

    private func timelineSection(
        _ items: [ZhuowangCampaignProgress],
        today: Date
    ) -> some View {
        let ongoing = items.filter { $0.datePhase == .ongoing }
            .sorted { $0.dayDistance < $1.dayDistance }
        let upcoming = items.filter { $0.datePhase == .upcoming }
            .sorted { $0.dayDistance < $1.dayDistance }
        let ended = items.filter { $0.datePhase == .ended }
            .sorted { $0.dayDistance < $1.dayDistance }
        let recentEnded = ended.filter { $0.dayDistance <= recentlyEndedDays }

        return VStack(alignment: .leading, spacing: CosmosDesign.spacingM) {
            CosmosSectionTitle(title: "近期活动", subtitle: "Schedule")

            Text("依据：各活动信息中填写的开始 / 结束日期，今天为 \(Self.fullDate(today))。这里只反映活动日期，不推算任务截止时间。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: CosmosDesign.spacingM) {
                timelineColumn(.ongoing, rows: ongoing, footnote: nil)
                timelineColumn(.upcoming, rows: upcoming, footnote: nil)
                timelineColumn(
                    .ended,
                    rows: recentEnded,
                    footnote: ended.count > recentEnded.count
                        ? "另有 \(ended.count - recentEnded.count) 个活动结束超过 \(recentlyEndedDays) 天"
                        : nil
                )
            }
        }
    }


    private func timelineColumn(
        _ phase: ZhuowangCampaignDatePhase,
        rows: [ZhuowangCampaignProgress],
        footnote: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: CosmosDesign.spacingS) {
            Text(phase == .ended ? "近 \(recentlyEndedDays) 天结束 · \(rows.count)" : "\(phase.title) · \(rows.count)")
                .font(.subheadline.weight(.semibold))

            if rows.isEmpty {
                Text("无")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ForEach(rows) { row in
                Button {
                    open(row, .overview)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.campaign.name)
                            .font(.callout)
                            .lineLimit(1)
                        Text(timelineText(row))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("打开活动详情")
            }

            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(CosmosDesign.spacingM)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .modifier(WorkbenchPanel())
    }


    private func timelineText(_ row: ZhuowangCampaignProgress) -> String {
        let start = Self.shortDate(row.campaign.startDate)
        let end = Self.shortDate(max(row.campaign.startDate, row.campaign.endDate))
        switch row.datePhase {
        case .ongoing:
            return row.dayDistance == 0
                ? "今天结束（\(start)–\(end)）"
                : "还剩 \(row.dayDistance) 天（\(start)–\(end)）"
        case .upcoming:
            return "\(row.dayDistance) 天后开始（\(start)）"
        case .ended:
            return row.dayDistance == 0
                ? "今天结束（\(end)）"
                : "\(row.dayDistance) 天前结束（\(end)）"
        }
    }


    // MARK: Overview

    private func overviewSection(_ items: [ZhuowangCampaignProgress]) -> some View {
        let rows = items.sorted { Self.byStartDate($0, $1) }

        return VStack(alignment: .leading, spacing: CosmosDesign.spacingM) {
            CosmosSectionTitle(title: "活动总览", subtitle: "All Campaigns")

            VStack(spacing: 0) {
                overviewHeaderRow
                Divider()

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider().padding(.leading, CosmosDesign.spacingL)
                    }
                    overviewRow(row)
                }
            }
            .modifier(WorkbenchPanel())
        }
    }


    private var overviewHeaderRow: some View {
        HStack(spacing: CosmosDesign.spacingM) {
            Text("活动").frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
            Text("省份").frame(width: 56, alignment: .leading)
            Text("活动时间").frame(width: 118, alignment: .leading)
            Text("状态").frame(width: 64, alignment: .leading)
            Text("六步进度").frame(width: 104, alignment: .leading)
            Text("采用产物").frame(width: 52, alignment: .leading)
            Color.clear.frame(width: 44, height: 1)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, CosmosDesign.spacingL)
        .padding(.vertical, CosmosDesign.spacingS)
    }


    private func overviewRow(_ row: ZhuowangCampaignProgress) -> some View {
        HStack(spacing: CosmosDesign.spacingM) {
            Text(row.campaign.name)
                .fontWeight(.medium)
                .lineLimit(1)
                .help(row.campaign.name)
                .frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)

            Text(row.scopeName)
                .frame(width: 56, alignment: .leading)
                .lineLimit(1)

            Text(compactDateRange(row.campaign))
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .help(row.campaign.dateRangeText)
                .frame(width: 118, alignment: .leading)

            ZhuowangCampaignStatusBadge(status: row.campaign.status)
                .frame(width: 64, alignment: .leading)

            HStack(spacing: CosmosDesign.spacingS) {
                ProgressView(
                    value: Double(row.completedSteps),
                    total: Double(max(row.totalSteps, 1))
                )
                .frame(width: 36)
                Text(row.hasWorkflow ? progressText(row) : "未建立")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 104, alignment: .leading)

            HStack(spacing: 4) {
                Text("\(row.adoptedArtifactCount)")
                    .monospacedDigit()
                if row.adoptionConflictCount > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .help("\(row.adoptionConflictCount) 个产物存在多个采用版本")
                }
            }
            .frame(width: 52, alignment: .leading)

            Button("打开") {
                open(row, .overview)
            }
            .controlSize(.small)
            .frame(width: 44)
        }
        .font(.callout)
        .padding(.horizontal, CosmosDesign.spacingL)
        .padding(.vertical, CosmosDesign.spacingS)
    }


    // MARK: Empty State

    private func emptyState(title: String, message: String, showsClear: Bool) -> some View {
        VStack(spacing: CosmosDesign.spacingM) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if showsClear {
                Button("清除筛选") {
                    filter = ZhuowangCampaignWorkbenchFilter(); selectedMetric = nil
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .modifier(WorkbenchPanel())
    }


    // MARK: Helpers

    private func progressText(_ row: ZhuowangCampaignProgress) -> String {
        row.hasWorkflow
            ? "\(row.completedSteps)/\(row.totalSteps) 已确认"
            : "Workflow 未建立"
    }

    private func open(
        _ row: ZhuowangCampaignProgress,
        _ destination: ZhuowangCampaignDetailRoute.Destination
    ) {
        guard permitsDetailOpening && !campaignStore.persistenceConfiguration.isIsolatedForUI else { return }
        ZhuowangCampaignWindowManager.shared.open(
            campaign: row.campaign,
            store: campaignStore,
            workflowStore: workflowStore,
            province: row.province,
            module: row.module,
            destination: destination
        )
    }

    private static func byStartDate(
        _ lhs: ZhuowangCampaignProgress,
        _ rhs: ZhuowangCampaignProgress
    ) -> Bool {
        if lhs.campaign.startDate != rhs.campaign.startDate {
            return lhs.campaign.startDate < rhs.campaign.startDate
        }
        return lhs.campaign.name.localizedStandardCompare(rhs.campaign.name) == .orderedAscending
    }

    /// "09.25–10.07" within the current year; the year is added otherwise.
    private func compactDateRange(_ campaign: ZhuowangCampaign) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now())
        let start = campaign.startDate
        let end = max(campaign.startDate, campaign.endDate)
        let sameYear = calendar.component(.year, from: start) == year
            && calendar.component(.year, from: end) == year
        guard !sameYear else {
            return "\(Self.shortDate(start))–\(Self.shortDate(end))"
        }
        return "\(Self.fullDate(start))–\(Self.fullDate(end))"
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM.dd"
        return formatter.string(from: date)
    }

    private static func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}


private struct WorkbenchPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.thinMaterial)
            .clipShape(
                RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusLarge, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusLarge, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }
}
