import SwiftUI

/// 知识库入口：个人笔记 与 卓望知识与资产（既有资产中心，行为与检索语义不变）。
struct KnowledgeHubView: View {
    enum Section: String, CaseIterable, Identifiable {
        case notes = "个人笔记", assets = "卓望知识与资产"
        var id: String { rawValue }
    }
    let configuration: ZhuowangStorePersistenceConfiguration
    let isolatedRoot: URL?
    let notesLocation: PersonalNotesLocation
    var promptLocation: PromptVaultLocation? = nil
    @State private var section: Section = .notes
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("知识库", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 360)
                    .accessibilityIdentifier("knowledge-section")
                Spacer()
            }.padding(.horizontal, CosmosDesign.pagePadding).padding(.vertical, 10)
            Divider()
            switch section {
            case .notes: PersonalNotesView(location: notesLocation, promptLocation: promptLocation).id("notes")
            case .assets: ZhuowangAssetCenterView(configuration: configuration, isolatedRoot: isolatedRoot).id("assets")
            }
        }
    }
}

struct PersonalNotesView: View {
    @StateObject private var store: PersonalNotesStore
    @State private var search = ""
    @State private var category: NoteCategoryFilter = .all
    @State private var favoritesOnly = false
    @State private var archived = false
    @State private var showExport = false
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    private let promptLocation: PromptVaultLocation?

    init(location: PersonalNotesLocation, promptLocation: PromptVaultLocation? = nil) {
        self.promptLocation = promptLocation
        _store = StateObject(wrappedValue: PersonalNotesStore(location: location))
    }
    init(store: PersonalNotesStore) { promptLocation = nil; _store = StateObject(wrappedValue: store) }

    @State private var selection: UUID?

    private var filters: PersonalNotesListFilter {
        PersonalNotesListFilter(search: search, category: category, favoritesOnly: favoritesOnly, archived: archived)
    }
    private var actions: PersonalNotesUIActions {
        PersonalNotesUIActions(canSave: { store.canSave },
            newNote: { PersonalNoteWindowManager.shared.open(store: store, note: nil) },
            favorite: { note in Task { await store.setFavorite(note) } },
            archive: { note in Task { await store.setArchived(note) } })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CosmosPageHeader("个人笔记", subtitle: "保存经验、操作说明与研究笔记。",
                info: "保存纯文本 / Markdown 源文，不渲染、不联网。笔记属于个人，不属于卓望活动；文件与链接仅登记引用，归档保留内容与全部历史。")
            if let error = store.error {
                Text(error.localizedDescription).foregroundStyle(.orange).textSelection(.enabled)
                    .accessibilityIdentifier("notes-error")
            }
            if store.loading { ProgressView("读取个人笔记…") }
            else if store.loaded { list }
            Text("笔记保存在本机个人笔记库，不属于卓望、省份或活动；文件和链接仅保存引用。归档保留全部内容与历史，不提供永久删除。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, CosmosDesign.pagePadding).padding(.vertical, CosmosDesign.spacingXXL)
        .frame(maxWidth: CosmosDesign.contentMaxWidth, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .searchable(text: $search, prompt: "搜索标题或已保存正文")
        .accessibilityIdentifier("notes-search")
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("分类", selection: $category) {
                        Text("全部分类").tag(NoteCategoryFilter.all)
                        Text("未分类").tag(NoteCategoryFilter.uncategorized)
                        ForEach(PersonalNotesQuery.categories(store.notes), id: \.self) {
                            Text($0).tag(NoteCategoryFilter.named($0))
                        }
                    }
                    Toggle("仅收藏", isOn: $favoritesOnly)
                    Picker("范围", selection: $archived) {
                        Text("当前笔记").tag(false)
                        Text("已归档").tag(true)
                    }
                } label: { Label("筛选", systemImage: "line.3.horizontal.decrease.circle") }
                .accessibilityIdentifier("notes-filter")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("新建笔记", systemImage: "plus") { actions.create() }
                    .disabled(!store.canSave).accessibilityIdentifier("notes-new").help("新建笔记").labelStyle(.iconOnly)
                Button("批量导出…", systemImage: "square.and.arrow.up") { showExport = true }
                    .accessibilityIdentifier("notes-export-batch").help("批量导出…").labelStyle(.iconOnly)
                Button("刷新", systemImage: "arrow.clockwise") { Task { await store.reload() } }
                    .disabled(store.loading || store.saving).help("刷新").labelStyle(.iconOnly)
            }
        }
        .task { if await CosmosDesign.beginPageLoad(reduced: preferences.reducesMotion(system: systemMotion)) { await store.reload() } }
        .sheet(isPresented: $showExport) {
            ContentExportBatchSheet(libraries: ContentExportLibraries(notesLocation: store.location, promptLocation: promptLocation),
                initialSource: .personalNote)
        }
    }

    private func clearFilters() {
        PersonalNotesListFilter.clear(search: &search, category: &category, favoritesOnly: &favoritesOnly, archived: &archived)
    }

    @ViewBuilder private var list: some View {
        let visible = filters.matching(store.notes)
        if filters.isActive {
            HStack {
                Label(filters.summary, systemImage: "line.3.horizontal.decrease.circle").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("清除筛选", action: clearFilters).buttonStyle(.borderless)
                    .accessibilityIdentifier("notes-filter-clear")
            }
        }
        Text("\(visible.count) 条笔记").font(.caption).foregroundStyle(.secondary)
        if visible.isEmpty {
            CosmosEmptyState(icon: "note.text", title: store.established ? "没有符合条件的笔记" : "写下第一条值得留下的经验",
                detail: store.established ? "调整搜索、分类、收藏或归档筛选。" : "从一次操作说明、一个研究结论，或一段工作经验开始。",
                actionTitle: store.established ? nil : "新建笔记",
                action: store.established ? nil : { actions.create() }).disabled(!store.canSave)
            Spacer(minLength: 0)
        } else {
            List(selection: $selection) {
                ForEach(visible) { note in
                    HStack(alignment: .top, spacing: 12) {
                        Button { PersonalNoteWindowManager.shared.open(store: store, note: note) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(note.title).font(.headline)
                                    if note.isArchived { Text("已归档").font(.caption).foregroundStyle(.orange) }
                                }
                                Text("\(note.category ?? "未分类") · 内容 v\(note.contentVersion ?? 0) · 更新 \(CosmosDate.timestamp(note.updatedAt))")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(Self.preview(note.body)).lineLimit(2).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("note-row-" + note.id.uuidString)
                        Button { actions.setFavorite(note) } label: {
                            Image(systemName: note.isFavorite ? "star.fill" : "star").cosmosSymbolReplacement()
                                .foregroundStyle(note.isFavorite ? .yellow : .secondary)
                        }.buttonStyle(.borderless).help(note.isFavorite ? "取消收藏" : "收藏").disabled(!store.canSave)
                            .accessibilityIdentifier("note-favorite-" + note.id.uuidString)
                    }
                    .padding(.vertical, 4).tag(note.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(note.isArchived ? "恢复" : "归档") { actions.setArchived(note) }
                            .disabled(!store.canSave).accessibilityIdentifier("note-archive-" + note.id.uuidString)
                    }
                }
            }
            .listStyle(.inset).scrollEdgeEffectStyle(.soft, for: .top)
            .contextMenu(forSelectionType: UUID.self) { ids in
                if let id = ids.first, let note = visible.first(where: { $0.id == id }) {
                    Button(note.isArchived ? "恢复" : "归档") { actions.setArchived(note) }
                        .disabled(!store.canSave).accessibilityIdentifier("note-archive-" + note.id.uuidString)
                }
            } primaryAction: { ids in
                if let id = ids.first, let note = visible.first(where: { $0.id == id }) {
                    PersonalNoteWindowManager.shared.open(store: store, note: note)
                }
            }
        }
    }

    /// 列表预览：只取正文前部的有限字符，不全量渲染长正文。
    static func preview(_ body: String) -> String {
        let head = String(body.prefix(240)).trimmingCharacters(in: .whitespacesAndNewlines)
        return head.isEmpty ? "（正文为空）" : head
    }
}

/// UI projection only; filtering remains owned by PersonalNotesQuery.
struct PersonalNotesListFilter {
    var search = ""
    var category: NoteCategoryFilter = .all
    var favoritesOnly = false
    var archived = false

    var isActive: Bool {
        !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || category != .all || favoritesOnly || archived
    }
    var summary: String {
        var items: [String] = []
        switch category {
        case .all: break
        case .uncategorized: items.append("未分类")
        case .named(let name): items.append(name)
        }
        if favoritesOnly { items.append("仅收藏") }
        if archived { items.append("已归档") }
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { items.append("搜索条件") }
        return items.joined(separator: " · ")
    }
    func matching(_ notes: [PersonalNote]) -> [PersonalNote] {
        PersonalNotesQuery.filter(notes, search: search, category: category, favoritesOnly: favoritesOnly, archived: archived)
    }
    static func clear(search: inout String, category: inout NoteCategoryFilter, favoritesOnly: inout Bool, archived: inout Bool) {
        search = ""; category = .all; favoritesOnly = false; archived = false
    }
}

/// The same live gate protects toolbar, row, context-menu and swipe requests.
struct PersonalNotesUIActions {
    let canSave: () -> Bool
    let newNote: () -> Void
    let favorite: (PersonalNote) -> Void
    let archive: (PersonalNote) -> Void
    func create() { guard canSave() else { return }; newNote() }
    func setFavorite(_ note: PersonalNote) { guard canSave() else { return }; favorite(note) }
    func setArchived(_ note: PersonalNote) { guard canSave() else { return }; archive(note) }
}
