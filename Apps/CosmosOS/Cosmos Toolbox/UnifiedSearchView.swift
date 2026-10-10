import SwiftUI

struct UnifiedSearchView: View {
    @StateObject private var model: UnifiedSearchViewModel
    @StateObject private var navigator: UnifiedSearchNavigator
    @State private var query = UnifiedSearchQuery()
    @Environment(\.cosmosNavigator) private var appNavigator
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    @FocusState private var searchFocused: Bool
    @Namespace private var selectionIndicator
    private var followsNavigation = true

    init(configuration: ZhuowangStorePersistenceConfiguration, projects: ProjectsLocation,
         prompts: PromptVaultLocation, learning: LearningLocation,
         notes: PersonalNotesLocation, assetRoot: URL?) {
        var roots: [UnifiedSearchSource: URL] = [:], blocked: [UnifiedSearchSource: String] = [:]
        if let root = projects.root { roots[.project] = root } else { blocked[.project] = projects.error?.localizedDescription ?? "位置不可用" }
        if let root = prompts.root { roots[.prompt] = root } else { blocked[.prompt] = prompts.error?.localizedDescription ?? "位置不可用" }
        if let root = learning.root { roots[.learning] = root } else { blocked[.learning] = learning.error?.localizedDescription ?? "位置不可用" }
        if let root = notes.root { roots[.note] = root } else { blocked[.note] = notes.error?.localizedDescription ?? "位置不可用" }
        let dataSource = configuration.dataSource
        let reader = UnifiedSearchReader(readPreference: { key in
            if let source = dataSource as? ZhuowangUserDefaultsDataSource { return try source.coreBackupData(forKey: key) }
            return dataSource.data(forKey: key)
        }, roots: roots, blocked: blocked)
        _model = StateObject(wrappedValue: UnifiedSearchViewModel(load: { await Task.detached { reader.read() }.value }))
        _navigator = StateObject(wrappedValue: UnifiedSearchNavigator(reader: reader, configuration: configuration,
            projects: projects, prompts: prompts, learning: learning, notes: notes, assetRoot: assetRoot))
    }
    init(model: UnifiedSearchViewModel, navigator: UnifiedSearchNavigator) {
        _model = StateObject(wrappedValue: model); _navigator = StateObject(wrappedValue: navigator)
        _query = State(initialValue: model.query); followsNavigation = false
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CosmosPageHeader("统一检索", subtitle: "跨模块查找已保存的名称、分类与位置。",
                info: "仅检索元数据：活动名称与说明；Artifact 名称、类型、活动、省份或模块；引用名称、版本、备注与位置；项目及学习主题的名称、目标、下一步；Prompt 名称与分类；个人笔记标题与分类。不检索文件、Prompt、笔记正文与历史、项目进展或学习历史。空查询不读取业务库；搜索词只保存在本次运行的内存。点击结果按 UUID 核验后打开，引用不会自动打开。")
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.secondary)
                TextField("输入关键词跨模块搜索", text: $query.text).textFieldStyle(.plain)
                    .font(CosmosDesign.font(.section)).focused($searchFocused)
                    .accessibilityIdentifier("unified-search-query")
                if !query.text.isEmpty {
                    Button("清空", systemImage: "xmark.circle.fill") { query.text = "" }.labelStyle(.iconOnly).buttonStyle(.borderless).foregroundStyle(.secondary)
                }
            }.padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(searchFocused ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.1)) }
            HStack(spacing: 14) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        sourceButton("全部", nil)
                        ForEach(UnifiedSearchSource.allCases) { sourceButton($0.title, $0) }
                    }
                }
                Toggle("包含归档", isOn: $query.includeArchived).toggleStyle(.checkbox).fixedSize()
                Toggle("Artifact 历史", isOn: $query.includeHistory).toggleStyle(.checkbox).fixedSize()
            }.font(CosmosDesign.font(.body))
            if !model.states.isEmpty {
                DisclosureGroup("来源状态") {
                    ForEach(UnifiedSearchSource.allCases) { source in
                        if let state = model.states[source] { Text(source.title + "：" + state.description).font(CosmosDesign.font(.caption)).foregroundStyle(isFailed(state) ? Color.orange : Color.secondary).frame(maxWidth: .infinity, alignment: .leading) }
                    }
                }.font(CosmosDesign.font(.caption))
                ForEach(UnifiedSearchSource.allCases) { source in
                    if case .failed(let reason) = model.states[source] { Text(source.title + "读取失败：" + reason).foregroundStyle(.orange).font(CosmosDesign.font(.body)) }
                }
            }
            ForEach(model.notices, id: \.self) { Text($0).font(CosmosDesign.font(.caption)).foregroundStyle(.secondary) }
            if query.keyword.isEmpty {
                CosmosEmptyState(icon: "magnifyingglass", title: "输入关键词开始检索", detail: "活动 · Artifact · 引用 · 项目 · 提示词 · 学习 · 个人笔记")
                if !appNavigator.lastSearchText.isEmpty {
                    Button("上次检索：" + appNavigator.lastSearchText) { query.text = appNavigator.lastSearchText }.buttonStyle(.glass)
                }
                Spacer()
            } else if model.loading {
                ProgressView("正在读取本地元数据…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.rows.isEmpty {
                CosmosEmptyState(icon: "magnifyingglass", title: "可读取来源中没有匹配", detail: "试试更短的关键词、全部来源，或包含归档与历史。读取失败会单独提示。")
                Spacer()
            } else {
                Text("\(model.rows.count) 个匹配").font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
                List {
                    ForEach(UnifiedSearchSource.allCases) { source in
                        let rows = model.rows.filter { $0.id.source == source }
                        if !rows.isEmpty {
                            Section {
                                ForEach(rows) { row in resultRow(row) }
                            } header: { Text(source.title + " · \(rows.count)").font(CosmosDesign.font(.section)) }
                        }
                    }
                }.listStyle(.inset).scrollContentBackground(.hidden)
            }
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar {
                ToolbarItem { Button("聚焦搜索", systemImage: "magnifyingglass") { searchFocused = true }.keyboardShortcut("f", modifiers: .command).buttonStyle(.glass) }
                ToolbarItem { Button("刷新", systemImage: "arrow.clockwise") { model.search(query, refresh: true) }.buttonStyle(.glass).disabled(query.keyword.isEmpty) }
            }
            .task {
                searchFocused = true
                if followsNavigation && !appNavigator.searchText.isEmpty { query.text = appNavigator.searchText }
            }
            .onChange(of: appNavigator.searchText) { _, text in if followsNavigation { query.text = text; searchFocused = true } }
            .onChange(of: query) { _, value in
                model.search(value)
                if !value.keyword.isEmpty { appNavigator.lastSearchText = value.keyword }
            }
            .onDisappear { model.cancel() }
            .sheet(item: $navigator.referenceRow) { row in referenceDetail(row) }
            .alert("检索导航", isPresented: Binding(get: { navigator.message != nil }, set: { if !$0 { navigator.message = nil } })) {
                Button("好") { navigator.message = nil }
            } message: { Text(navigator.message ?? "") }
            .modifier(CosmosMotionPolicy())
    }
    private func sourceButton(_ title: String, _ source: UnifiedSearchSource?) -> some View {
        Button { query.source = source } label: {
            Text(title).padding(.horizontal, 12).padding(.vertical, 7)
                .background {
                    if query.source == source { Capsule().fill(Color.accentColor.opacity(0.13)).matchedGeometryEffect(id: "source", in: selectionIndicator) }
                    else { Capsule().fill(Color.primary.opacity(0.035)) }
                }
        }.buttonStyle(.plain).accessibilityAddTraits(query.source == source ? .isSelected : [])
            .animation(preferences.reducesMotion(system: systemMotion) ? nil : CosmosDesign.motion, value: query.source)
    }
    private func resultRow(_ row: UnifiedSearchRow) -> some View {
        Button { Task { await navigator.open(row) } } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: row.id.source.cosmosIcon).foregroundStyle(.secondary).frame(width: 22).padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(highlight(row.name)).font(CosmosDesign.font(.section))
                        if row.archived { Text("已归档").font(CosmosDesign.font(.caption)).foregroundStyle(.orange) }
                        if row.favorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow) }
                        if row.id.source == .artifact { Text(row.adoptionConflict ? "采用冲突" : row.historical ? "历史/未采用" : "当前采用").font(CosmosDesign.font(.caption)).foregroundStyle(row.adoptionConflict ? Color.orange : Color.secondary) }
                    }
                    Text(row.id.source.title + " · " + row.ownership).font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
                    Text(highlight(model.query.summary(row))).font(CosmosDesign.font(.body)).lineLimit(3)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }.padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("unified-result-" + row.id.source.rawValue + "-" + row.id.objectID.uuidString)
    }
    private func highlight(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        guard !query.keyword.isEmpty else { return result }
        var remaining = text.startIndex..<text.endIndex
        while let range = text.range(of: query.keyword, options: [.caseInsensitive, .diacriticInsensitive], range: remaining) {
            if let lower = AttributedString.Index(range.lowerBound, within: result), let upper = AttributedString.Index(range.upperBound, within: result) {
                result[lower..<upper].foregroundColor = .accentColor
                result[lower..<upper].font = CosmosDesign.font(.body).bold()
            }
            remaining = range.upperBound..<text.endIndex
        }
        return result
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
