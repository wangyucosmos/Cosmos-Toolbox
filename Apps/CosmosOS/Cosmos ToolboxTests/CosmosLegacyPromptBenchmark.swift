#if DEBUG
// Frozen pre-polish UI and view-model baseline for the opt-in synthetic-data performance test.
@testable import Cosmos_Toolbox
import SwiftUI

struct CosmosLegacyPromptView: View {
    @StateObject private var store: PromptVaultStore
    @StateObject private var model = CosmosLegacyPromptViewModel()
    @State private var pendingRestore: PromptVersionEntry?
    @State private var showExport = false
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    private let location: PromptVaultLocation
    private let notesLocation: PersonalNotesLocation?
    init(location: PromptVaultLocation, notesLocation: PersonalNotesLocation? = nil) {
        self.location = location; self.notesLocation = notesLocation
        _store = StateObject(wrappedValue: PromptVaultStore(root: location.root, startupError: location.error))
    }
    init(store: PromptVaultStore, model: CosmosLegacyPromptViewModel) {
        location = .init(root: store.storageRoot, error: nil); notesLocation = nil
        _store = StateObject(wrappedValue: store); _model = StateObject(wrappedValue: model)
    }
    private func legacyDelay() async -> Bool {
        try? await Task.sleep(for: .milliseconds(380))
        return !Task.isCancelled
    }
    private var singleExportLibraries: ContentExportLibraries {
        ContentExportLibraries(notes: nil, prompts: store.storageRoot.map { PromptVaultFileStorage(root: $0) },
            promptsUnavailable: store.error?.localizedDescription ?? "存储位置不可用")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CosmosPageHeader("提示词库", subtitle: "保存常用提示词，填写变量后复制完整结果。",
                info: "模板由你创建；变量使用 {{变量名}} 写法。填写变量只在内存中，不修改原模板、不保存变量值。内容版本与历史语义保持不变。")
            if let error = store.error {
                Text(error.localizedDescription).foregroundStyle(.orange).textSelection(.enabled)
            }
            if store.loading { ProgressView("正在读取提示词库…") }
            HStack {
                TextField("搜索名称或正文", text: $model.query).accessibilityIdentifier("prompt-search")
                Toggle("仅收藏", isOn: $model.favoritesOnly)
                Toggle("查看归档", isOn: $model.showArchived)
            }
            if store.loaded && store.templates.isEmpty && store.error == nil {
                ScrollView(.vertical, showsIndicators: true) { starters }
            } else {
                ViewThatFits(in: .horizontal) {
                    HSplitView {
                        categories.frame(minWidth: 120, idealWidth: 145, maxWidth: 180)
                        content.frame(minWidth: 580)
                    }.frame(minWidth: 730)
                    VStack(alignment: .leading) {
                        Picker("分类", selection: $model.category) {
                            Text("全部分类").tag("")
                            ForEach(categoryNames, id: \.self) { Text($0).tag($0) }
                        }.frame(maxWidth: 220)
                        content
                    }
                }
            }
        }
        .padding(24)
        .toolbar { ToolbarItemGroup(placement: .primaryAction) {
            Button("新建模板", systemImage: "plus") { PromptTemplateWindowManager.shared.open(store: store, template: nil) }.disabled(!store.canSave).accessibilityIdentifier("prompt-new")
            Button("批量导出…", systemImage: "square.and.arrow.up") { showExport = true }.accessibilityIdentifier("prompt-export-batch")
            Button("刷新", systemImage: "arrow.clockwise") { Task { await store.reload() } }.disabled(store.saving)
        } }
        .task { if await legacyDelay() { await store.reload(); model.reconcile(store.templates) } }
        .onChange(of: store.templates) { _, templates in model.reconcile(templates) }
        .onDisappear { model.clearSession() }
        .sheet(isPresented: $showExport) {
            ContentExportBatchSheet(libraries: ContentExportLibraries(notesLocation: notesLocation, promptLocation: location),
                initialSource: .promptTemplate)
        }
    }
    private var starters: some View {
        VStack(alignment: .leading, spacing: 16) {
            CosmosEmptyState(icon: "text.badge.plus", title: "把常用任务保存为模板", detail: "用 {{变量}} 留出每次需要替换的内容，填写后复制即可。")
            Text("从模板开始").font(CosmosDesign.font(.section))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                ForEach(Array(CosmosPromptStarter.allCases.enumerated()), id: \.element.id) { index, starter in
                    CosmosCard(icon: "text.book.closed", title: starter.title, action: {
                        PromptTemplateWindowManager.shared.open(store: store, template: nil, prefill: starter.draft)
                    }) {
                        Text(starter.draft.body).font(CosmosDesign.font(.body)).foregroundStyle(.secondary).lineLimit(4)
                        Text("预填编辑器 · 保存后才创建").font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
                    }.disabled(!store.canSave).cosmosScrollReveal()
                }
            }
        }.padding(.vertical, 12)
    }
    private var categoryNames: [String] {
        CosmosExperienceTrace.timed("categories") { Array(Set(store.templates.map { $0.category ?? "未分类" })).sorted() }
    }
    private var categories: some View {
        List(selection: $model.category) {
            Label("全部分类", systemImage: "square.grid.2x2").tag("")
            ForEach(categoryNames, id: \.self) { Label($0, systemImage: "folder").tag($0) }
        }.listStyle(.sidebar)
    }
    private var content: some View {
        HSplitView {
            VStack {
                if model.filtered(store.templates).isEmpty {
                    ContentUnavailableView(store.templates.isEmpty ? "创建第一份提示词模板" : "没有匹配的模板",
                        systemImage: "text.book.closed", description: Text("模板由你创建；可调整搜索、分类、收藏或归档筛选。"))
                } else {
                    List(selection: $model.selectedID) {
                        ForEach(model.filtered(store.templates)) { template in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(template.name).fontWeight(.medium)
                                    if template.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                                }
                                Text(template.category ?? "未分类").font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
                                Text(template.updatedAt, format: .dateTime.month().day().hour().minute()).font(CosmosDesign.font(.caption)).foregroundStyle(.tertiary)
                            }.padding(.vertical, 7).cosmosRowFeedback().tag(template.id).accessibilityIdentifier("prompt-template-" + template.id.uuidString)
                        }
                    }
                }
            }.frame(minWidth: 180, idealWidth: 210, maxWidth: 280)
            if let template = store.templates.first(where: { $0.id == model.selectedID }) {
                detail(template).frame(minWidth: 330, maxWidth: .infinity)
            } else {
                ContentUnavailableView("选择一个模板开始使用", systemImage: "text.cursor",
                    description: Text("填写变量 → 完整预览 → 复制。"))
                    .frame(minWidth: 330, maxWidth: .infinity)
            }
        }
    }
    private func detail(_ template: PromptTemplate) -> some View {
        let renderer = PromptTemplateRenderer(template.body)
        let result = model.rendered(template)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(template.name).font(CosmosDesign.font(.section))
                Text("\(template.category ?? "未分类") · 已保存 r\(template.revision)\(template.contentVersion.map { " · 内容 v\($0)" } ?? "")\(template.isArchived ? " · 已归档" : "")")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("编辑", systemImage: "square.and.pencil") {
                        PromptTemplateWindowManager.shared.open(store: store, template: template)
                    }.accessibilityIdentifier("prompt-edit")
                    Button(template.isFavorite ? "取消收藏" : "收藏", systemImage: "star") { Task { await store.setFavorite(template) } }
                    Button(template.isArchived ? "恢复归档" : "归档", systemImage: "archivebox") { Task { await store.setArchived(template) } }
                }.disabled(!store.canSave)
                if renderer.variables.isEmpty { Text("此模板没有需要填写的变量。").foregroundStyle(.secondary) }
                ForEach(renderer.variables) { variable in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(variable.name).font(.headline)
                        TextField("填写 \(variable.name)", text: Binding(
                            get: { model.values[template.id]?[variable.id] ?? "" },
                            set: { model.setValue($0, variable: variable, templateID: template.id) }), axis: .vertical)
                            .textFieldStyle(.roundedBorder).lineLimit(2...6)
                            .accessibilityIdentifier("prompt-variable-" + variable.id)
                    }
                }
                if !result.missing.isEmpty {
                    Text("待填写：" + result.missing.joined(separator: "、")).foregroundStyle(.orange)
                }
                ForEach(Array(result.warnings.enumerated()), id: \.offset) { _, warning in
                    Text(warning).font(.caption).foregroundStyle(.orange)
                }
                Divider()
                Text("完整提示词预览").font(CosmosDesign.font(.section))
                Text(result.text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(.background).accessibilityIdentifier("prompt-preview")
                HStack {
                    Button("复制完整结果", systemImage: "doc.on.doc") { model.copyResult(template) }
                        .disabled(!result.canCopy).accessibilityIdentifier("prompt-copy-result")
                    Button("复制原始模板") { model.copyOriginal(template) }
                }
                ContentExportSingleButton(title: "导出已保存正文（.md）…",
                    request: ContentExportSingleRequest(source: .promptTemplate, id: template.id,
                        version: .current(expectedVersionID: template.versions.last?.id)),
                    libraries: singleExportLibraries,
                    hasUnsavedDraft: PromptTemplateWindowManager.shared.hasUnsavedDraft(store: store, templateID: template.id),
                    identifier: "prompt-export-current")
                Text(model.copyMessage).font(.caption).foregroundStyle(.secondary)
                Divider()
                history(template)
            }.padding(12)
        }
    }
    private static let timeText: Date.FormatStyle = .dateTime.year().month().day().hour().minute().second()
    private func timeLabel(_ entry: PromptVersionEntry, _ template: PromptTemplate) -> String {
        switch entry.kind {
        case .legacyCurrent: return "无独立记录时间 · 模板更新于 " + template.updatedAt.formatted(Self.timeText)
        case .upgradeBaseline: return (entry.recordedAt ?? template.updatedAt).formatted(Self.timeText) + "（沿用升级前的模板更新时间，非实际编辑时间）"
        default: return (entry.recordedAt ?? template.updatedAt).formatted(Self.timeText)
        }
    }
    private func history(_ template: PromptTemplate) -> some View {
        let entries = CosmosExperienceTrace.timed("version_history") { template.versionEntries }, viewed = model.viewedEntry(of: template)
        return VStack(alignment: .leading, spacing: 8) {
            Text("版本历史").font(.headline)
            if template.versions.isEmpty {
                Text("此模板保存于版本历史功能之前：当前内容显示为「升级前当前内容」。首次修改内容并保存时，会连同旧内容一起保留；收藏与归档不产生内容版本。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                Button { model.viewEntry(entry, of: template) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.label).fontWeight(entry.isCurrent ? .semibold : .regular)
                            Text(entry.name).lineLimit(1)
                            Spacer()
                            if entry.id == viewed.id { Image(systemName: "eye") }
                        }
                        Text(timeLabel(entry, template)).font(.caption).foregroundStyle(.secondary)
                    }.contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(6)
                .background(entry.id == viewed.id ? Color.accentColor.opacity(0.12) : Color.clear)
                .accessibilityIdentifier("prompt-version-" + entry.id.uuidString)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("正在查看：\(viewed.label) · \(viewed.name) · \(viewed.category ?? "未分类")").font(.subheadline)
                Text(viewed.body).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.background)
                    .accessibilityIdentifier("prompt-version-body")
                HStack {
                    Button("复制此版本正文（\(viewed.label)）", systemImage: "doc.on.doc") { model.copyVersion(viewed) }
                        .accessibilityIdentifier("prompt-version-copy")
                    if !viewed.isCurrent {
                        Button("恢复此版本…", systemImage: "clock.arrow.circlepath") { pendingRestore = viewed }
                            .disabled(!store.canSave).accessibilityIdentifier("prompt-version-restore")
                    }
                }
                ContentExportSingleButton(title: "导出此版本（\(viewed.label)）为 .md…",
                    request: ContentExportSingleRequest(source: .promptTemplate, id: template.id,
                        version: viewed.kind == .legacyCurrent ? .current(expectedVersionID: nil) : .specific(viewed.id)),
                    libraries: singleExportLibraries,
                    hasUnsavedDraft: PromptTemplateWindowManager.shared.hasUnsavedDraft(store: store, templateID: template.id),
                    identifier: "prompt-export-version")
            }
            Text(model.historyMessage).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }
        .alert("将 \(pendingRestore?.label ?? "") 恢复为新的当前版本？", isPresented: Binding(
            get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })) {
            Button("取消", role: .cancel) { pendingRestore = nil }
            Button("恢复") {
                guard let entry = pendingRestore else { return }
                pendingRestore = nil
                Task {
                    let dirty = PromptTemplateWindowManager.shared.hasUnsavedDraft(store: store, templateID: template.id)
                    if await model.restore(entry, of: template, in: store, hasUnsavedDraft: dirty),
                       let saved = store.templates.first(where: { $0.id == template.id }) {
                        PromptTemplateWindowManager.shared.syncCleanSession(store: store, saved: saved)
                    }
                }
            }
        } message: { Text("所选版本的名称、正文、分类会保存为一个新的当前内容版本；全部历史保留，收藏与归档状态不变。") }
    }
}

import Foundation
import Combine
import AppKit

final class CosmosLegacyPromptViewModel: ObservableObject {
    @Published var query = ""
    @Published var category = ""
    @Published var favoritesOnly = false
    @Published var showArchived = false
    @Published var selectedID: UUID?
    @Published private(set) var values: [UUID: [String: String]] = [:]
    @Published private(set) var copyMessage = ""
    /// templateID → history entry currently shown in full. Absent means the current content.
    @Published private(set) var viewedEntryIDs: [UUID: UUID] = [:]
    @Published private(set) var historyMessage = ""
    private let copy: (String) -> Bool
    init(copy: @escaping (String) -> Bool = { text in
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }) { self.copy = copy }
    func filtered(_ templates: [PromptTemplate]) -> [PromptTemplate] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return templates.filter {
            $0.isArchived == showArchived && (!favoritesOnly || $0.isFavorite)
                && (category.isEmpty || ($0.category ?? "未分类") == category)
                && (search.isEmpty || $0.name.localizedStandardContains(search) || $0.body.localizedStandardContains(search))
        }.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
    func setValue(_ value: String, variable: PromptVariable, templateID: UUID) {
        values[templateID, default: [:]][variable.id] = value; copyMessage = ""
    }
    func reconcile(_ templates: [PromptTemplate]) {
        let ids = Set(templates.map(\.id))
        values = values.filter { ids.contains($0.key) }
        viewedEntryIDs = viewedEntryIDs.filter { ids.contains($0.key) }
        for template in templates {
            let names = Set(PromptTemplateRenderer(template.body).variables.map(\.id))
            values[template.id] = values[template.id]?.filter { names.contains($0.key) }
        }
        copyMessage = ""
    }
    func clearSession() { values = [:]; copyMessage = ""; viewedEntryIDs = [:]; historyMessage = "" }

    // MARK: Version history (raw templates only; the variable renderer never sees historical text)
    func viewedEntry(of template: PromptTemplate) -> PromptVersionEntry {
        let entries = template.versionEntries
        if let id = viewedEntryIDs[template.id], let entry = entries.first(where: { $0.id == id }) { return entry }
        return entries[0]
    }
    func viewEntry(_ entry: PromptVersionEntry, of template: PromptTemplate) {
        viewedEntryIDs[template.id] = entry.id; historyMessage = ""
    }
    /// Copies exactly `entry.body` — the version the interface shows — never the current body by default.
    @discardableResult func copyVersion(_ entry: PromptVersionEntry) -> Bool {
        let succeeded = copy(entry.body)
        historyMessage = succeeded
            ? "已复制 \(entry.label) 的原文（未替换变量、未处理转义）。"
            : "剪贴板写入失败，\(entry.label) 未复制，请重试。"
        return succeeded
    }
    /// `hasUnsavedDraft`: an edit window for this template holds unsaved changes; restore never overwrites it.
    @discardableResult func restore(_ entry: PromptVersionEntry, of template: PromptTemplate,
                                    in store: PromptVaultStore, hasUnsavedDraft: Bool) async -> Bool {
        guard !entry.isCurrent else { historyMessage = "这已是当前内容，无需恢复。"; return false }
        guard !hasUnsavedDraft else {
            historyMessage = "该模板在编辑窗口中有未保存的草稿；请先保存或放弃草稿再恢复历史版本。草稿未被覆盖，未做任何恢复。"
            return false
        }
        switch await store.restore(templateID: template.id, versionID: entry.id, expectedRevision: template.revision) {
        case .restored:
            let latest = store.templates.first { $0.id == template.id }
            viewedEntryIDs[template.id] = latest?.versions.last?.id
            historyMessage = "已将 \(entry.label) 的名称、正文、分类保存为新的当前内容版本 v\(latest?.contentVersion ?? 0)；全部历史已保留。"
            return true
        case .unchanged:
            historyMessage = "所选内容与当前内容完全相同，未新增版本。"; return false
        case .failed:
            historyMessage = (store.error?.localizedDescription ?? "恢复失败") + "（历史与现有内容未改变）"; return false
        }
    }
    func rendered(_ template: PromptTemplate) -> PromptRenderResult {
        PromptTemplateRenderer(template.body).render(values: values[template.id] ?? [:])
    }
    @discardableResult func copyResult(_ template: PromptTemplate) -> Bool {
        let result = rendered(template)
        guard result.canCopy else { copyMessage = "仍有未填写变量，未复制。"; return false }
        let succeeded = copy(result.text)
        copyMessage = succeeded ? "已复制完整提示词。" : "剪贴板写入失败，请重试。"
        return succeeded
    }
    func copyOriginal(_ template: PromptTemplate) {
        copyMessage = copy(template.body) ? "已复制原始模板，未替换或处理转义。" : "剪贴板写入失败，请重试。"
    }
}

#endif
