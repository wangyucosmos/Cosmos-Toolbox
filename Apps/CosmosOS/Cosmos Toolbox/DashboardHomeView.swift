import SwiftUI
import Charts

struct DashboardHomeView: View {
    @StateObject private var model: DashboardHomeViewModel
    @Environment(\.cosmosNavigator) private var navigator
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    @ObservedObject private var mac: MacEnvironmentViewModel
    private let ai: AIWorkspaceResultCache
    private let autoRefresh: Bool
    private let open: (SidebarItem) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    init(configuration: ZhuowangStorePersistenceConfiguration, promptLocation: DashboardLocation,
         learningLocation: DashboardLocation, notesLocation: DashboardLocation = .blocked("未提供笔记位置"),
         cache: DashboardReadCache = DashboardReadCache(), mac: MacEnvironmentViewModel? = nil,
         ai: AIWorkspaceResultCache? = nil, open: @escaping (SidebarItem) -> Void) {
        func root(_ location: DashboardLocation) -> URL? { if case .root(let value) = location { return value }; return nil }
        func reason(_ location: DashboardLocation) -> String { if case .blocked(let value) = location { return value }; return "位置不可用" }
        let dataSource = configuration.dataSource
        let reader = DashboardHomeReader(readPreference: { key in
            if let source = dataSource as? ZhuowangUserDefaultsDataSource { return try source.coreBackupData(forKey: key) }
            return dataSource.data(forKey: key)
        }, prompts: root(promptLocation), notes: root(notesLocation), learning: root(learningLocation),
            blocked: ["prompts": reason(promptLocation), "notes": reason(notesLocation), "learning": reason(learningLocation)])
        _model = StateObject(wrappedValue: DashboardHomeViewModel(cache: cache,
            homeLoad: { now, calendar in await reader.load(now: now, calendar: calendar) },
            isolated: configuration.isIsolatedForUI,
            load: { _, now in DashboardRaw(readAt: now, campaigns: .notBuilt, workflows: .notBuilt, workspace: .notBuilt, prompts: .notBuilt, learning: .notBuilt) }))
        self.open = open; self.mac = mac ?? MacEnvironmentViewModel(); self.ai = ai ?? AIWorkspaceResultCache(); autoRefresh = true
    }
    init(model: DashboardHomeViewModel, mac: MacEnvironmentViewModel? = nil,
         ai: AIWorkspaceResultCache? = nil, autoRefresh: Bool = false,
         open: @escaping (SidebarItem) -> Void) {
        _model = StateObject(wrappedValue: model); self.open = open; self.mac = mac ?? MacEnvironmentViewModel(); self.ai = ai ?? AIWorkspaceResultCache(); self.autoRefresh = autoRefresh
        _appeared = State(initialValue: !autoRefresh)
    }
    private var data: DashboardHomeData { model.homeData }
    private func go(_ link: CosmosDashboardLink) { navigator.navigate(link.destination) }
    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                CosmosPageHeader(DashboardGreeting.text(now: model.now), subtitle: DashboardGreeting.dateText(now: model.now),
                    info: "汇总本地已保存数据。图表表示数量，Workflow 仅统计启用步骤；学习按未归档主题的学习日期计次数。归档笔记与提示词不计入。交付资格沿用推进工作台检查。")
                ViewThatFits(in: .horizontal) {
                    quickActions
                    quickActions.labelStyle(.iconOnly)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: CosmosAdaptiveLayout.columns(width: min(geometry.size.width, CosmosDesign.contentMaxWidth) - 48, minimum: 145)), spacing: 12) {
                    metric(.campaigns, "megaphone", "活动总数", data.total, data.errors["campaigns"])
                    metric(.ongoing, "calendar", "活动日期内", data.ongoing, data.errors["campaigns"])
                    metric(.attention, "exclamationmark.triangle", "失败或需修改", data.attention, data.errors["workflow"] ?? data.errors["campaigns"])
                    CosmosMetricTile(icon: "shippingbox", title: "可以交付", value: model.delivery.value,
                        detail: model.delivery.error, loading: model.delivery.isLoading) { go(.deliverable) }
                    metric(.notes, "note.text", "个人笔记", data.noteCount, data.errors["notes"])
                    metric(.prompts, "text.book.closed", "提示词", data.promptCount, data.errors["prompts"])
                    metric(.learning, "graduationcap", "近 7 天学习记录", data.learningCount, data.errors["learning"])
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: CosmosAdaptiveLayout.columns(width: min(geometry.size.width, CosmosDesign.contentMaxWidth) - 48, minimum: 320, maximum: 3)), alignment: .leading, spacing: 16) {
                    CosmosChartCard(title: "活动分布", icon: "chart.bar", empty: data.distribution.isEmpty, loading: model.loading,
                        error: data.errors["distribution"] ?? data.errors["campaigns"], action: { go(.distribution) }) {
                        Chart(data.distribution) { row in
                            BarMark(x: .value("活动数", appeared ? row.count : 0), y: .value("省份或模块", row.label), height: .fixed(14))
                                .cornerRadius(5).foregroundStyle(Color.accentColor.opacity(0.55))
                                .annotation(position: .trailing, alignment: .leading) { Text(String(row.count)).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                        }
                        .chartXScale(domain: 0...max(5, Int(Double(data.distribution.map(\.count).max() ?? 0) * 1.45)))
                        .chartXAxis(.hidden)
                        .chartYAxis { AxisMarks(position: .leading) { _ in AxisValueLabel() } }
                    }
                    CosmosChartCard(title: "Workflow 步骤状态", icon: "chart.pie", empty: data.workflow.isEmpty, loading: model.loading,
                        error: data.errors["workflow"] ?? data.errors["campaigns"], action: { go(.workflow) }) {
                        VStack(spacing: 12) {
                            Chart(data.workflow) { row in
                                SectorMark(angle: .value("步骤数", row.count), innerRadius: .ratio(0.65), angularInset: 2)
                                    .cornerRadius(3).foregroundStyle(workflowColor(row.id).opacity(0.8))
                            }.frame(height: 130).opacity(appeared ? 1 : 0)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), alignment: .leading)], alignment: .leading, spacing: 6) {
                                ForEach(data.workflow) { row in
                                    HStack(spacing: 5) { Circle().fill(workflowColor(row.id)).frame(width: 7, height: 7)
                                        Text(row.label + " " + String(row.count)).font(.caption).lineLimit(1) }
                                }
                            }
                        }
                    }
                    CosmosChartCard(title: "近 8 周学习记录", icon: "chart.bar.xaxis", empty: data.weeks.allSatisfy { $0.count == 0 },
                        loading: model.loading, error: data.errors["learning"], action: { go(.learningChart) }) {
                        Chart(data.weeks) { row in BarMark(x: .value("周", row.label), y: .value("次数", appeared ? row.count : 0)).foregroundStyle(Color.accentColor) }
                            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("最近更新").font(CosmosDesign.font(.section)); Spacer(); Text("最多 8 条").font(CosmosDesign.font(.caption)).foregroundStyle(.secondary) }
                    if data.recent.isEmpty {
                        CosmosEmptyState(icon: "clock", title: "还没有最近更新", detail: data.errors.isEmpty ? "从一个活动、一篇笔记或一条提示词开始" : "部分来源无法读取，请查看对应指标的原因",
                            actionTitle: "打开卓望工作", action: { navigator.navigate(.module("zhuowang")) })
                    } else {
                        VStack(spacing: 8) {
                            ForEach(data.recent) { item in
                                Button { navigator.navigate(.record(item.row)) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: item.row.id.source.cosmosIcon).foregroundStyle(.secondary).frame(width: 22)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.row.name).font(CosmosDesign.font(.body)).lineLimit(1)
                                            Text(item.row.id.source.title + " · " + item.row.ownership).font(CosmosDesign.font(.caption)).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer()
                                        Text(CosmosDate.day(item.updatedAt)).font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                    }
                                }.buttonStyle(CosmosInteractiveCardStyle())
                            }
                        }
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { statusCards }
                    VStack(spacing: 12) { statusCards }
                }
                if let readAt = data.readAt { Text("读取于 " + CosmosDate.timestamp(readAt)).font(CosmosDesign.font(.caption)).foregroundStyle(.tertiary) }
            }.padding(24).frame(maxWidth: CosmosDesign.contentMaxWidth).frame(maxWidth: .infinity)
        }
        }.background(Color(nsColor: .windowBackgroundColor))
            .toolbar { ToolbarItem { Button("刷新", systemImage: "arrow.clockwise") { model.refresh(); mac.refresh() }.buttonStyle(.glass).disabled(model.loading).accessibilityIdentifier("dashboard-refresh") } }
             .task {
                appeared = true
                if autoRefresh, await CosmosDesign.beginPageLoad(reduced: preferences.reducesMotion(system: systemMotion)) { model.refresh(); mac.loadIfNeeded() }
            }
            .animation(preferences.reducesMotion(system: systemMotion) ? nil : .smooth(duration: 0.35), value: appeared)
            .animation(preferences.reducesMotion(system: systemMotion) ? nil : .smooth(duration: 0.35), value: data.readAt)
            .onDisappear { model.cancel() }
            .modifier(CosmosMotionPolicy())
    }
    private func workflowColor(_ status: String) -> Color {
        switch status {
        case "ready": return .blue
        case "running", "waitingForApproval", "generated": return .orange
        case "approved", "completed": return .green
        case "failed", "needsRevision": return .red
        default: return .gray
        }
    }
    private var quickActions: some View {
        CosmosGlassToolbarGroup {
            Button { navigator.navigate(.module("zhuowang")) } label: { Label("新建活动", systemImage: "plus.circle").foregroundStyle(colorScheme == .dark ? Color.white : Color.black) }.help("打开卓望工作，在活动分类新建")
            Button { navigator.newRecordRequest = .note } label: { Label("新建笔记", systemImage: "square.and.pencil").foregroundStyle(colorScheme == .dark ? Color.white : Color.black) }.help("打开原生新建笔记窗口")
            Button { navigator.newRecordRequest = .prompt } label: { Label("新建提示词", systemImage: "text.badge.plus").foregroundStyle(colorScheme == .dark ? Color.white : Color.black) }.help("打开原生新建模板窗口")
            Button { navigator.navigate(.search("")) } label: { Label("统一检索", systemImage: "magnifyingglass").foregroundStyle(colorScheme == .dark ? Color.white : Color.black) }
        }
    }
    private func metric(_ link: CosmosDashboardLink, _ icon: String, _ title: String, _ value: Int?, _ error: String?) -> some View {
        CosmosMetricTile(icon: icon, title: title, value: value, detail: error, loading: model.loading) { go(link) }
    }
    @ViewBuilder private var statusCards: some View {
        CosmosCard(icon: "desktopcomputer", title: "Mac 环境", action: { go(.mac) }) { Text(macText).font(CosmosDesign.font(.body)).foregroundStyle(.secondary) }
        CosmosCard(icon: "sparkles", title: "AI 工具", action: { go(.ai) }) {
            if let snapshot = ai.snapshot {
                Text("本次检测：\(snapshot.results.filter { $0.status == .ready }.count)/\(snapshot.results.count) 可运行 · " + CosmosDate.timestamp(snapshot.completedAt)).font(CosmosDesign.font(.body)).foregroundStyle(.secondary)
            } else { Text("尚未检测 · 打开 AI 工作台").font(CosmosDesign.font(.body)).foregroundStyle(.secondary) }
        }
    }
    private var macText: String {
        guard let snapshot = mac.snapshot else { return mac.isReading ? "正在读取系统信息…" : "尚未读取" }
        var parts: [String] = []
        switch snapshot.disk { case .value(let disk): parts.append("可用 " + MacEnvironmentFormat.decimalBytes(disk.availableBytes)); case .failed(let error), .unknown(let error), .notApplicable(let error): parts.append("磁盘：" + error) }
        switch snapshot.physicalMemory { case .value(let memory): parts.append("内存 " + MacEnvironmentFormat.binaryBytes(memory)); case .failed(let error), .unknown(let error), .notApplicable(let error): parts.append("内存：" + error) }
        return parts.joined(separator: " · ")
    }
}

extension UnifiedSearchSource {
    var cosmosIcon: String { switch self { case .campaign: return "megaphone"; case .artifact: return "doc.richtext"; case .reference: return "link"; case .project: return "folder"; case .prompt: return "text.book.closed"; case .learning: return "graduationcap"; case .note: return "note.text"; case .knowledgeDocument: return "books.vertical" } }
}

extension ZhuowangStorePersistenceConfiguration {
    var isIsolatedForUI: Bool {
#if DEBUG
        isIsolated
#else
        false
#endif
    }
}
