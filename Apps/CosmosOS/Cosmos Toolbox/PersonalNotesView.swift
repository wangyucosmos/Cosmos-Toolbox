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
            case .notes: PersonalNotesView(location: notesLocation).id("notes")
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

    init(location: PersonalNotesLocation) { _store = StateObject(wrappedValue: PersonalNotesStore(location: location)) }
    init(store: PersonalNotesStore) { _store = StateObject(wrappedValue: store) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("个人笔记").font(.system(size: 32, weight: .semibold))
                        Text("个人经验、操作说明与研究笔记 · 纯文本 / Markdown 源文，不渲染、不联网").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("新建笔记", systemImage: "plus") { PersonalNoteWindowManager.shared.open(store: store, note: nil) }
                        .disabled(!store.canSave).accessibilityIdentifier("notes-new")
                    Button("刷新", systemImage: "arrow.clockwise") { Task { await store.reload() } }
                        .disabled(store.loading || store.saving)
                }
                HStack {
                    TextField("搜索标题或已保存正文", text: $search).accessibilityIdentifier("notes-search")
                    Picker("分类", selection: $category) {
                        Text("全部分类").tag(NoteCategoryFilter.all)
                        Text("未分类").tag(NoteCategoryFilter.uncategorized)
                        ForEach(PersonalNotesQuery.categories(store.notes), id: \.self) {
                            Text($0).tag(NoteCategoryFilter.named($0))
                        }
                    }.frame(maxWidth: 200)
                    Toggle("仅收藏", isOn: $favoritesOnly)
                    Picker("范围", selection: $archived) { Text("当前笔记").tag(false); Text("已归档").tag(true) }
                        .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 220)
                }
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
            .frame(maxWidth: CosmosDesign.contentMaxWidth, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task { await store.reload() }
    }

    @ViewBuilder private var list: some View {
        let visible = PersonalNotesQuery.filter(store.notes, search: search, category: category,
            favoritesOnly: favoritesOnly, archived: archived)
        if visible.isEmpty {
            ContentUnavailableView(store.established ? "没有符合条件的笔记" : "尚未建立个人笔记库",
                systemImage: "note.text",
                description: Text(store.established
                    ? "笔记库中没有符合当前搜索、分类、收藏或归档筛选的笔记。"
                    : "新建第一条笔记并保存后才会建立笔记库；不会预置示例或扫描任何文件。"))
        } else {
            Text("\(visible.count) 条笔记").font(.caption).foregroundStyle(.secondary)
            ForEach(visible) { note in
                HStack(alignment: .top) {
                    Button { PersonalNoteWindowManager.shared.open(store: store, note: note) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(note.title).font(.headline)
                                if note.isArchived { Text("已归档").font(.caption).foregroundStyle(.orange) }
                            }
                            Text("\(note.category ?? "未分类") · 内容 v\(note.contentVersion ?? 0) · 更新 \(note.updatedAt.formatted())")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(Self.preview(note.body)).lineLimit(2).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("note-row-" + note.id.uuidString)
                    Button { Task { await store.setFavorite(note) } } label: {
                        Image(systemName: note.isFavorite ? "star.fill" : "star").foregroundStyle(note.isFavorite ? .yellow : .secondary)
                    }.buttonStyle(.plain).help(note.isFavorite ? "取消收藏" : "收藏").disabled(!store.canSave)
                        .accessibilityIdentifier("note-favorite-" + note.id.uuidString)
                    Button(note.isArchived ? "恢复" : "归档") { Task { await store.setArchived(note) } }
                        .disabled(!store.canSave).accessibilityIdentifier("note-archive-" + note.id.uuidString)
                }.padding(.vertical, 8)
                Divider()
            }
        }
    }

    /// 列表预览：只取正文前部的有限字符，不全量渲染长正文。
    static func preview(_ body: String) -> String {
        let head = String(body.prefix(240)).trimmingCharacters(in: .whitespacesAndNewlines)
        return head.isEmpty ? "（正文为空）" : head
    }
}
