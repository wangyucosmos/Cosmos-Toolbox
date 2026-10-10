import SwiftUI

struct UnifiedSearchView: View {
    @StateObject private var model: UnifiedSearchViewModel
    @StateObject private var navigator: UnifiedSearchNavigator
    @State private var query = UnifiedSearchQuery()

    init(configuration: ZhuowangStorePersistenceConfiguration, projects: ProjectsLocation,
         prompts: PromptVaultLocation, learning: LearningLocation, assetRoot: URL?) {
        var roots: [UnifiedSearchSource: URL] = [:], blocked: [UnifiedSearchSource: String] = [:]
        if let root = projects.root { roots[.project] = root } else { blocked[.project] = projects.error?.localizedDescription ?? "位置不可用" }
        if let root = prompts.root { roots[.prompt] = root } else { blocked[.prompt] = prompts.error?.localizedDescription ?? "位置不可用" }
        if let root = learning.root { roots[.learning] = root } else { blocked[.learning] = learning.error?.localizedDescription ?? "位置不可用" }
        let dataSource = configuration.dataSource
        let reader = UnifiedSearchReader(readPreference: { key in
            if let source = dataSource as? ZhuowangUserDefaultsDataSource { return try source.coreBackupData(forKey: key) }
            return dataSource.data(forKey: key)
        }, roots: roots, blocked: blocked)
        _model = StateObject(wrappedValue: UnifiedSearchViewModel(load: { await Task.detached { reader.read() }.value }))
        _navigator = StateObject(wrappedValue: UnifiedSearchNavigator(reader: reader, configuration: configuration,
            projects: projects, prompts: prompts, learning: learning, assetRoot: assetRoot))
    }
    init(model: UnifiedSearchViewModel, navigator: UnifiedSearchNavigator) {
        _model = StateObject(wrappedValue: model); _navigator = StateObject(wrappedValue: navigator)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("统一检索").font(.largeTitle)
                Spacer()
                Button("刷新", systemImage: "arrow.clockwise") { model.search(query, refresh: true) }
                    .disabled(query.keyword.isEmpty)
            }
            Text("仅检索已保存的元数据：活动名称/说明；Artifact 名称/类型/活动/省份或模块；引用名称/版本/备注/位置；项目与学习主题的名称/目标/下一步；Prompt 名称/分类。")
                .font(.callout).foregroundStyle(.secondary)
            Text("不检索文件或 Prompt 正文、项目进展或学习历史。不保存搜索记录与索引。点击结果复用原模块详情；引用不会自动打开。")
                .font(.caption).foregroundStyle(.secondary)
            TextField("输入关键词跨模块搜索", text: $query.text).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("unified-search-query")
            HStack {
                Picker("来源", selection: $query.source) {
                    Text("全部来源").tag(Optional<UnifiedSearchSource>.none)
                    ForEach(UnifiedSearchSource.allCases) { Text($0.title).tag(Optional($0)) }
                }.frame(maxWidth: 220)
                Toggle("包含归档（项目/Prompt/学习）", isOn: $query.includeArchived)
                Toggle("Artifact 历史版本", isOn: $query.includeHistory)
            }
            if !model.states.isEmpty {
                DisclosureGroup("来源状态（单源失败不影响其他来源）") {
                    ForEach(UnifiedSearchSource.allCases) { source in
                        if let state = model.states[source] {
                            Text(source.title + "：" + state.description)
                                .foregroundStyle(isFailed(state) ? Color.orange : Color.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                // Failures stay visible even when the details are collapsed.
                ForEach(UnifiedSearchSource.allCases) { source in
                    if case .failed(let reason) = model.states[source] {
                        Text(source.title + "读取失败：" + reason).foregroundStyle(.orange).font(.callout)
                    }
                }
            }
            ForEach(model.notices, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
            if query.keyword.isEmpty {
                ContentUnavailableView("输入关键词开始检索", systemImage: "magnifyingglass", description: Text("空查询不全量展示，也不读取业务库。"))
            } else if model.loading {
                ProgressView("正在读取本地元数据…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.rows.isEmpty {
                ContentUnavailableView("可读取来源中没有匹配", systemImage: "magnifyingglass", description: Text("可调整来源、归档或历史选项；读取失败另行标示，不代表零结果。"))
            } else {
                Text("\(model.rows.count) 个匹配").font(.caption).foregroundStyle(.secondary)
                List(model.rows) { row in
                    Button { Task { await navigator.open(row) } } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(row.name).font(.headline)
                                Text(row.id.source.title).font(.caption).foregroundStyle(.secondary)
                                if row.archived { Text("已归档").font(.caption).foregroundStyle(.orange) }
                                if row.id.source == .artifact {
                                    Text(row.adoptionConflict ? "采用冲突" : (row.historical ? "历史/未采用" : "当前采用"))
                                        .font(.caption).foregroundStyle(row.adoptionConflict ? Color.orange : Color.secondary)
                                }
                            }
                            Text(row.ownership).font(.caption).foregroundStyle(.secondary)
                            Text(model.query.summary(row)).font(.callout).lineLimit(3)
                        }.padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("unified-result-" + row.id.source.rawValue + "-" + row.id.objectID.uuidString)
                }
            }
        }.padding(24).frame(minWidth: 760, minHeight: 560)
            .onChange(of: query) { _, value in model.search(value) }
            .onDisappear { model.cancel() }
            .sheet(item: $navigator.referenceRow) { row in referenceDetail(row) }
            .alert("检索导航", isPresented: Binding(get: { navigator.message != nil }, set: { if !$0 { navigator.message = nil } })) {
                Button("好") { navigator.message = nil }
            } message: { Text(navigator.message ?? "") }
    }
    private func isFailed(_ state: UnifiedSearchState) -> Bool { if case .failed = state { return true }; return false }
    @ViewBuilder private func referenceDetail(_ row: UnifiedSearchRow) -> some View {
        if let ref = row.reference {
            VStack(alignment: .leading, spacing: 12) {
                Text("引用记录 · " + ref.name).font(.title2)
                Text("所属活动：" + row.ownership)
                Text("活动 ID：\(ref.campaignID.uuidString)").font(.caption)
                Text("引用 ID：\(ref.id.uuidString)").font(.caption)
                Text("版本标签：" + (ref.versionLabel.isEmpty ? "未填写" : ref.versionLabel))
                Text(ref.recordedAt, format: .dateTime.year().month().day().hour().minute())
                if let corrected = ref.correctsReferenceID { Text("更正对象 ID：" + corrected.uuidString).font(.caption) }
                if !ref.location.isEmpty { Text(ref.location).textSelection(.enabled) }
                if !ref.notes.isEmpty { ScrollView { Text(ref.notes).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 220) }
                Text("这是位置登记，不是 Artifact 或已采用成果；备份不包含文件实体。打开失败仍保留原记录，不修复路径。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("关闭") { navigator.referenceRow = nil }
                    Spacer()
                    if ref.kind != .correction { Button(ref.kind == .file ? "打开原文件" : "打开链接") { Task { await navigator.openReference(row) } } }
                }
            }.padding(24).frame(width: 600)
        }
    }
}
