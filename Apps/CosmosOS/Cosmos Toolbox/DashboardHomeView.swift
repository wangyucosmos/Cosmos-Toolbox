import SwiftUI

/// Home: a read-only summary of what the finished modules actually hold.
/// Every number and list comes from persisted data; navigation only opens an
/// existing module (never a Campaign detail window).
struct DashboardHomeView: View {

    @StateObject private var model: DashboardHomeViewModel
    let open: (SidebarItem) -> Void

    init(
        configuration: ZhuowangStorePersistenceConfiguration,
        promptLocation: DashboardLocation,
        learningLocation: DashboardLocation,
        cache: DashboardReadCache = DashboardReadCache(),
        open: @escaping (SidebarItem) -> Void
    ) {
        let reader = DashboardReader(
            dataSource: configuration.dataSource,
            promptLocation: promptLocation,
            learningLocation: learningLocation
        )
        _model = StateObject(wrappedValue: DashboardHomeViewModel(cache: cache) { cache, now in
            await reader.load(cache: cache, now: now)
        })
        self.open = open
    }

    /// Injectable model, for offscreen rendering and tests.
    init(model: DashboardHomeViewModel, open: @escaping (SidebarItem) -> Void) {
        _model = StateObject(wrappedValue: model)
        self.open = open
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CosmosDesign.spacingXL) {
                header
                activitiesCard
                monthlyCard
                HStack(alignment: .top, spacing: CosmosDesign.spacingL) {
                    promptsCard
                    learningCard
                }
                notConnected
            }
            .padding(.horizontal, CosmosDesign.pagePadding)
            .padding(.vertical, CosmosDesign.spacingXXL)
            .frame(maxWidth: CosmosDesign.contentMaxWidth, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task { model.refresh() }
        .onDisappear { model.cancel() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: CosmosDesign.spacingS) {
                Text(DashboardGreeting.text(now: model.now))
                    .font(.system(size: 32, weight: .semibold))
                Text(DashboardGreeting.dateText(now: model.now))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Button("刷新", systemImage: "arrow.clockwise") { model.refresh() }
                    .disabled(model.loading)
                    .accessibilityIdentifier("dashboard-refresh")
                Text(readText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("这是本次读取的时间，不是数据的更新时间。")
            }
        }
    }

    private var readText: String {
        if model.loading { return "正在读取…" }
        guard let readAt = model.display.readAt else { return "尚未读取" }
        return "读取于 " + Self.timeText(readAt)
    }

    // MARK: Activities

    private var activitiesCard: some View {
        CosmosCard(icon: "megaphone", title: "活动 · Workflow 状态", englishTitle: "Campaigns") {
            sectionBody(model.display.activities, notBuilt: "还没有活动数据。", openTarget: DashboardCard.campaigns.target) { activities in
                VStack(alignment: .leading, spacing: 10) {
                    Text(summaryText(activities)).font(.callout)
                    if activities.workflowUnreadable {
                        Label("Workflow 数据无法读取，下面不显示步骤进度（这不等于尚未创建）。", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if activities.rows.isEmpty {
                        Text(activities.totalCount == 0
                             ? "还没有活动。可以在卓望工作里新建。"
                             : "没有需要继续推进的活动（已结束或启用步骤均已确认的活动只计入上面的汇总）。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(activities.rows) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(row.name).fontWeight(.medium)
                                Text(row.scopeName).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                if let progress = row.progress {
                                    Text("步骤 \(progress)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Text(row.detail).font(.callout)
                            Text(row.phaseText).font(.caption).foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                    if activities.hiddenCount > 0 {
                        Text("还有 \(activities.hiddenCount) 个活动未显示，请在推进工作台查看。").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("按 Workflow 状态分组，同组按活动更新时间，最多 \(DashboardProjection.activityLimit) 条。活动期只是活动自己的起止日期，不是任务截止时间。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("进入卓望工作（推进工作台）") { open(DashboardCard.campaigns.target) }
                        .accessibilityIdentifier("dashboard-open-campaigns")
                }
            }
        }
    }

    private func summaryText(_ a: DashboardActivities) -> String {
        var parts = ["共 \(a.totalCount) 个活动"]
        if !a.workflowUnreadable {
            parts.append("失败或需修改 \(a.attentionCount)")
            parts.append("Workflow 尚未创建 \(a.workflowNotCreatedCount)")
            if a.noEnabledStepsCount > 0 { parts.append("没有启用步骤 \(a.noEnabledStepsCount)") }
            parts.append("启用步骤均已确认 \(a.stepsAllConfirmedCount)（含跳过；不代表文件可用、已导出或可交付）")
        }
        parts.append("活动状态已结束 \(a.endedCount)")
        return parts.joined(separator: " · ")
    }

    // MARK: Monthly

    private var monthlyCard: some View {
        CosmosCard(icon: "list.bullet.clipboard", title: "月度会员促活", englishTitle: "Monthly") {
            sectionBody(model.display.monthly, notBuilt: "还没有活动数据。", openTarget: DashboardCard.monthly.target) { items in
                VStack(alignment: .leading, spacing: 10) {
                    if items.isEmpty {
                        Text("还没有月度会员促活活动。可在卓望工作 → 全国促活里新建。").foregroundStyle(.secondary)
                    }
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(item.month) · \(item.name)").fontWeight(.medium)
                            Text("月度成品已确认 \(item.confirmedOutputs)/\(item.outputTotal)")
                            Text("业务输入：已到 \(item.inputsReceived)项 · 不适用 \(item.inputsNotApplicable)项 · 待要 \(item.inputsRequested)项（不含掌厅奖池）")
                            Text("掌厅奖池：\(item.prizePool.title)")
                                .foregroundStyle(item.prizePool == .pending ? Color.orange : Color.primary)
                            Text(item.workflowLine).foregroundStyle(.secondary)
                        }
                        .font(.callout)
                        Divider()
                    }
                    Text("最近 \(DashboardProjection.monthlyLimit) 期，按月份排序（同月按创建时间）。成品确认、业务输入和 Workflow 进度是三件独立的事，互不替代，也不代表文件可用或可交付。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("进入卓望工作") { open(DashboardCard.monthly.target) }
                        .accessibilityIdentifier("dashboard-open-monthly")
                }
            }
        }
    }

    // MARK: Prompts

    private var promptsCard: some View {
        CosmosCard(icon: "text.book.closed", title: "提示词 · 收藏", englishTitle: "Prompt Vault") {
            sectionBody(model.display.prompts, notBuilt: "提示词库尚未建立。", openTarget: DashboardCard.prompts.target) { prompts in
                VStack(alignment: .leading, spacing: 8) {
                    Text("收藏 \(prompts.favoriteCount) · 模板 \(prompts.templateCount)").font(.callout)
                    if prompts.rows.isEmpty {
                        Text("还没有收藏的模板。").foregroundStyle(.secondary)
                    }
                    ForEach(prompts.rows) { row in
                        HStack {
                            Text(row.name).lineLimit(1)
                            Spacer()
                            Text(row.category).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("仅收藏且未归档，按模板更新时间，最多 \(DashboardProjection.promptLimit) 条；这里只进入提示词库，不复制。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("进入提示词库") { open(DashboardCard.prompts.target) }
                        .accessibilityIdentifier("dashboard-open-prompts")
                }
            }
        }
    }

    // MARK: Learning

    private var learningCard: some View {
        CosmosCard(icon: "graduationcap", title: "学习", englishTitle: "Learning") {
            sectionBody(model.display.learning, notBuilt: "学习库尚未建立。", openTarget: DashboardCard.learning.target) { learning in
                VStack(alignment: .leading, spacing: 8) {
                    Text("学习中 \(learning.learningCount) · 计划中 \(learning.plannedCount)").font(.callout)
                    if learning.rows.isEmpty {
                        Text("没有进行中或计划中的学习主题。").foregroundStyle(.secondary)
                    }
                    ForEach(learning.rows) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(row.name).fontWeight(.medium).lineLimit(1)
                                Text(row.statusTitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(row.lastStudyText).font(.caption).foregroundStyle(.secondary)
                            if let nextStep = row.nextStep {
                                Text("下一步：" + nextStep).font(.callout).lineLimit(2)
                            }
                        }
                    }
                    Text("按最近学习排序，最多 \(DashboardProjection.learningLimit) 条；已归档和已完成的主题不显示。下一步是你自己填写的内容。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("进入学习中心") { open(DashboardCard.learning.target) }
                        .accessibilityIdentifier("dashboard-open-learning")
                }
            }
        }
    }

    // MARK: Not connected

    private var notConnected: some View {
        HStack(spacing: CosmosDesign.spacingS) {
            Image(systemName: "circle.dashed")
            Text("AI 工作台、Mac 优化：尚未接入首页。")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    // MARK: Section states

    @ViewBuilder
    private func sectionBody<Value: Equatable, Content: View>(
        _ section: DashboardSectionDisplay<Value>,
        notBuilt: String,
        openTarget: SidebarItem,
        @ViewBuilder content: @escaping (Value) -> Content
    ) -> some View {
        switch section.state {
        case .loaded(let value):
            content(value)
        case .notBuilt:
            VStack(alignment: .leading, spacing: 6) {
                Text(notBuilt).foregroundStyle(.secondary)
                Text("这是“尚未建立”，不是空列表；首页不会创建任何数据。").font(.caption).foregroundStyle(.secondary)
                Button("进入模块") { open(openTarget) }
            }
        case .blocked(let reason):
            Label("读取已被阻止：\(reason)", systemImage: "lock.trianglebadge.exclamationmark")
                .foregroundStyle(.orange)
        case .unreadable(let reason):
            VStack(alignment: .leading, spacing: 8) {
                Label("本次读取失败：\(reason) 首页没有修改任何数据。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                if let stale = section.stale {
                    Text("以下是 \(Self.timeText(stale.loadedAt)) 上次成功读取的内容，不是本次读取的结果：")
                        .font(.caption).foregroundStyle(.orange)
                    content(stale.value).opacity(0.6)
                }
                Button("进入模块") { open(openTarget) }
            }
        }
    }

    static func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
