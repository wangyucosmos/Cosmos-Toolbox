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
        for template in templates {
            let names = Set(PromptTemplateRenderer(template.body).variables.map(\.id))
            values[template.id] = values[template.id]?.filter { names.contains($0.key) }
        }
        copyMessage = ""
    }
    func clearSession() { values = [:]; copyMessage = "" }
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
