import Foundation
import Combine
import AppKit

final class PromptVaultViewModel: ObservableObject {
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
