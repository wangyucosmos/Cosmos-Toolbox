import SwiftUI

/// In-memory task handoff and read-only local tool detection.
struct AIWorkspaceView: View {

    @StateObject private var model: AIWorkspaceViewModel
    private let autoDetect: Bool
    private let initialStage: Int
    @StateObject private var preparation: AIWorkspaceTaskPreparation
    @StateObject private var history: AIWorkspaceHandoffStore
    @AppStorage("cosmos.ui.aiWorkspace.guideCollapsed") private var guideCollapsed = false
    @State private var showsHistory = false

    init(cache: AIWorkspaceResultCache, configuration: ZhuowangStorePersistenceConfiguration, referenceRoot: URL? = nil, autoDetect: Bool = false) {
        let reader = AIWorkspaceTaskContextReader(source: configuration.dataSource)
#if DEBUG
        if configuration.isIsolated && ProcessInfo.processInfo.arguments.contains("--cosmos-ai-workspace-history") {
            _showsHistory = State(initialValue: true)
        }
        let location = AIWorkspaceHandoffLocation.resolve(isIsolated: configuration.isIsolated,
            bundleIdentifier: Bundle.main.bundleIdentifier, arguments: ProcessInfo.processInfo.arguments)
#else
        let location = AIWorkspaceHandoffLocation.resolve(isIsolated: false, bundleIdentifier: nil, arguments: [])
#endif
        _history = StateObject(wrappedValue: AIWorkspaceHandoffStore(location: location))
#if DEBUG
        let referenceError = configuration.isIsolated && referenceRoot == nil ? "隔离资料读取缺少临时文件根，已停止正文读取。" : nil
#else
        let referenceError: String? = nil
#endif
        _preparation = StateObject(wrappedValue: AIWorkspaceTaskPreparation(read: { try reader.read() },
            referenceReader: ZhuowangAssetTextReader(allowedRoot: referenceRoot), referenceIsolationError: referenceError))
        _model = StateObject(wrappedValue: AIWorkspaceViewModel(cache: cache))
        self.autoDetect = autoDetect; initialStage = 1
    }

    /// Injectable model, for offscreen rendering and tests.
    init(model: AIWorkspaceViewModel, autoDetect: Bool = false, preparation: AIWorkspaceTaskPreparation? = nil, history: AIWorkspaceHandoffStore? = nil, initialStage: Int = 1) {
        _preparation = StateObject(wrappedValue: preparation ?? AIWorkspaceTaskPreparation(read: { AIWorkspaceTaskContext() }))
        _history = StateObject(wrappedValue: history ?? AIWorkspaceHandoffStore(location: .init(root: nil, error: .unsafePath)))
        _model = StateObject(wrappedValue: model)
        self.autoDetect = autoDetect; self.initialStage = initialStage
    }

    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CosmosPageHeader("AI 工作台", subtitle: "把卓望活动的上下文整理成一段提示词，交给 Claude 或 Codex 去执行。",
                    info: "选择活动与步骤，填写本次目标，预览后手动复制。草稿仅在页面内存中。CLI 检测只证明本机入口与 --version 可运行，不证明登录、额度、网络或模型可用；不会安装、更新、读取密钥或调用 AI 服务。")
                usageGuide
                toolStatus
                CosmosSegmentedControl(title: "工作台", options: [(false, "准备任务"), (true, "交接记录")], selection: $showsHistory)
                    .accessibilityIdentifier("ai-workspace-section")
                if showsHistory { AIWorkspaceHandoffHistoryView(history: history, preparation: preparation).cosmosEntrance(1) }
                else { AIWorkspaceTaskPreparationView(model: preparation, history: history, initialStage: initialStage).cosmosEntrance(1) }
            }.padding(24).frame(maxWidth: CosmosDesign.contentMaxWidth, alignment: .leading).frame(maxWidth: .infinity)
        }.background(Color(nsColor: .windowBackgroundColor))
            .toolbar { ToolbarItem(placement: .primaryAction) { CosmosGlassToolbarGroup {
                Button(model.isDetecting ? "正在检测…" : "开始检测", systemImage: "terminal") { model.refresh() }
                    .disabled(model.isDetecting).accessibilityIdentifier("ai-workspace-detect")
                Button("刷新活动上下文", systemImage: "arrow.clockwise") { preparation.refresh() }
            }.labelStyle(.iconOnly) } }
            .task {
                guard await CosmosDesign.beginPageLoad(reduced: preferences.reducesMotion(system: systemMotion)) else { return }
                preparation.refresh(); await history.reload()
                if autoDetect { model.detectOnceOnArrival() }
            }.onDisappear { model.cancel() }
    }
    private var usageGuide: some View {
        CosmosContentPanel {
            DisclosureGroup("怎么用 · 从上下文到交接", isExpanded: Binding(get: { !guideCollapsed }, set: { guideCollapsed = !$0 })) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 16)], alignment: .leading, spacing: 16) {
                    ForEach(Array(zip(["list.bullet.rectangle", "pencil", "doc.on.doc", "terminal", "checkmark.bubble"],
                        ["选活动和步骤", "写本次目标", "复制完整提示词", "粘贴到 Claude Code 或 Codex 执行", "回来记录交接"]).enumerated()), id: \.offset) { index, item in
                        VStack(alignment: .leading, spacing: 8) {
                            CosmosSquareIcon(symbol: item.0, identity: String(index), filled: false)
                            Text("\(index + 1). " + item.1).font(.callout.weight(.medium))
                            Text(["带上已确认的上游上下文。", "说明希望得到什么成果。", "先核对预览再复制。", "在外部工具中检查并完成任务。", "记录结果与下一步，保留追踪线索。"][index]).font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.top, 12)
                Text("示例：为河南活动的完整策划案步骤生成初稿。").font(.callout).foregroundStyle(.secondary).padding(.top, 10)
            }
        }
    }
    private func statusText(_ result: AIWorkspaceToolResult?) -> String {
        guard let result else { return model.isDetecting ? "检测中" : "未检测" }
        switch result.status {
        case .ready: return result.version.map { "可运行 · " + $0 } ?? "可运行"
        case .missing: return "未找到"
        case .warning: return "无法运行"
        }
    }
    private var toolStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.isDetecting { ProgressView("正在检测本机工具（--version）…") }
            if model.snapshot == nil { Text("检测本机是否已安装这些 AI 工具").font(CosmosDesign.font(.body)).foregroundStyle(.secondary) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AIWorkspaceToolID.allCases) { tool in
                        let result = model.snapshot?.results.first { $0.tool == tool }
                        HStack(spacing: 6) {
                            Circle().fill(result?.status == .ready ? Color.green : result?.status == .warning ? Color.orange : Color.secondary).frame(width: 6, height: 6)
                            Text(tool.title).font(CosmosDesign.font(.body))
                            Text(statusText(result)).font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
                            if let result { CosmosInfoButton(text: [result.versionLine, result.path, result.resolvedPath.map { "实际位置：" + $0 }, result.source.map { "来源：" + $0.title }, result.isSystemShim ? "系统自带入口" : nil, result.failure?.message, result.failure?.hint].compactMap { $0 }.joined(separator: "\n")) }
                        }.padding(.horizontal, 12).padding(.vertical, 8).background(.quaternary, in: Capsule())
                    }
                }
            }
            if let snapshot = model.snapshot { Text("最近检测：" + CosmosDate.timestamp(snapshot.completedAt)).font(CosmosDesign.font(.caption)).foregroundStyle(.secondary).accessibilityIdentifier("ai-workspace-time") }
        }
    }
}


struct AIWorkspaceToolRow: View {

    let tool: AIWorkspaceToolID
    let result: AIWorkspaceToolResult?
    let isDetecting: Bool

    var body: some View {
        HStack(alignment: .top, spacing: CosmosDesign.spacingL) {
            Image(systemName: tool.symbol)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: CosmosDesign.spacingS) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tool.title).font(.headline)
                    if let version = result?.version {
                        Text(version)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    statusBadge
                }
                details
            }
        }
        .padding(CosmosDesign.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusMedium)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusMedium)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ai-workspace-row-\(tool.rawValue)")
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch result?.status {
        case .ready?:
            Label("可运行", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .warning?:
            Label("无法运行", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .missing?:
            Label("未找到", systemImage: "minus.circle.fill").foregroundStyle(.secondary)
        case nil:
            Label(isDetecting ? "检测中" : "未检测", systemImage: "circle.dashed").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var details: some View {
        if let result {
            if let line = result.versionLine, line != result.version {
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let path = result.path {
                VStack(alignment: .leading, spacing: 2) {
                    Text(path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    if let resolved = result.resolvedPath {
                        Text("实际位置：\(resolved)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    HStack(spacing: CosmosDesign.spacingS) {
                        if let source = result.source {
                            Text("来源：\(source.title)")
                        }
                        if result.isSystemShim {
                            Text("· 系统自带入口")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            if let failure = result.failure {
                VStack(alignment: .leading, spacing: 2) {
                    Text(failure.message)
                        .foregroundStyle(result.status == .warning ? Color.orange : Color.primary)
                    Text(failure.hint)
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(isDetecting ? "正在检测…" : "点击右上角“开始检测”。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
