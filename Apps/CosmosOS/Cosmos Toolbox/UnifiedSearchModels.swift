import Foundation

nonisolated enum UnifiedSearchSource: String, CaseIterable, Identifiable, Sendable {
    case campaign, artifact, reference, project, prompt, learning, note
    var id: String { rawValue }
    var title: String {
        switch self {
        case .campaign: return "活动"
        case .artifact: return "已管理 Artifact"
        case .reference: return "引用记录"
        case .project: return "个人项目"
        case .prompt: return "Prompt Vault"
        case .learning: return "学习主题"
        case .note: return "个人笔记"
        }
    }
}
nonisolated struct UnifiedSearchID: Hashable, Sendable {
    let source: UnifiedSearchSource
    let objectID: UUID
}
nonisolated struct UnifiedSearchField: Equatable, Sendable { let label: String; let text: String }
nonisolated struct UnifiedSearchRow: Identifiable, Equatable, Sendable {
    let id: UnifiedSearchID
    let name: String
    let ownership: String
    let fields: [UnifiedSearchField]
    var archived = false
    var favorite = false
    var historical = false
    var adoptionConflict = false
    var campaignID: UUID?
    var reference: CampaignExternalReference?
}
nonisolated enum UnifiedSearchState: Equatable, Sendable {
    case ready, missing, failed(String)
    var description: String {
        switch self {
        case .ready: return "已读取"
        case .missing: return "尚未建立；未初始化业务库"
        case .failed(let reason): return "无法读取：" + reason
        }
    }
}
nonisolated struct UnifiedSearchSnapshot: Sendable {
    var rows: [UnifiedSearchRow] = []
    var states: [UnifiedSearchSource: UnifiedSearchState] = [:]
    var notices: [String] = []
}
nonisolated struct UnifiedSearchQuery: Equatable, Sendable {
    var text = ""
    var source: UnifiedSearchSource?
    var includeArchived = false
    var includeHistory = false
    var keyword: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    func matches(_ row: UnifiedSearchRow) -> Bool {
        !keyword.isEmpty && (source == nil || source == row.id.source)
        && (includeArchived || !row.archived)
        && (includeHistory || !row.historical || row.adoptionConflict)
        && row.fields.contains { $0.text.localizedStandardContains(keyword) }
    }
    func summary(_ row: UnifiedSearchRow) -> String {
        row.fields.filter { $0.text.localizedStandardContains(keyword) }.map { field in
            guard let range = field.text.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) else {
                return field.label + "：" + String(field.text.prefix(120))
            }
            let start = field.text.index(range.lowerBound, offsetBy: -30, limitedBy: field.text.startIndex) ?? field.text.startIndex
            let end = field.text.index(range.upperBound, offsetBy: 75, limitedBy: field.text.endIndex) ?? field.text.endIndex
            return field.label + "：" + (start == field.text.startIndex ? "" : "…") + String(field.text[start..<end]) + (end == field.text.endIndex ? "" : "…")
        }.joined(separator: " · ")
    }
}
