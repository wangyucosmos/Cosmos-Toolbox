import Foundation

/// Immutable content snapshot (name, exact body, category). `number` is the content version and is
/// independent of the template's optimistic-lock `revision`.
nonisolated struct PromptVersion: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let number: Int
    let name: String
    let body: String
    let category: String?
    let recordedAt: Date
    /// Pre-history content preserved on the first content edit. `recordedAt` is the template's
    /// pre-existing `updatedAt`, not a reconstructed edit time.
    let isUpgradeBaseline: Bool
    init(id: UUID = UUID(), number: Int, name: String, body: String, category: String?,
         recordedAt: Date, isUpgradeBaseline: Bool = false) {
        self.id = id; self.number = number; self.name = name; self.body = body
        self.category = category; self.recordedAt = recordedAt; self.isUpgradeBaseline = isUpgradeBaseline
    }
    private enum CodingKeys: String, CodingKey { case id, number, name, body, category, recordedAt, isUpgradeBaseline }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        number = try c.decode(Int.self, forKey: .number)
        name = try c.decode(String.self, forKey: .name)
        body = try c.decode(String.self, forKey: .body)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        recordedAt = try c.decode(Date.self, forKey: .recordedAt)
        isUpgradeBaseline = try c.decodeIfPresent(Bool.self, forKey: .isUpgradeBaseline) ?? false
    }
}

/// One row of the history list. A template saved before history existed has no stored versions;
/// its current content is shown as a single "升级前当前内容" entry and nothing is inferred from `revision`.
nonisolated struct PromptVersionEntry: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable { case current, history, upgradeBaseline, legacyCurrent }
    let id: UUID
    let number: Int?
    let name: String
    let body: String
    let category: String?
    let recordedAt: Date?
    let kind: Kind
    var isCurrent: Bool { kind == .current || kind == .legacyCurrent }
    var label: String {
        switch kind {
        case .legacyCurrent: return "升级前当前内容"
        case .upgradeBaseline: return "v\(number ?? 0) · 升级前内容"
        case .current: return "v\(number ?? 0) · 当前内容"
        case .history: return "v\(number ?? 0)"
        }
    }
}

nonisolated struct PromptTemplate: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var body: String
    var category: String?
    var isFavorite: Bool
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date
    var revision: Int
    /// Storage-owned. The store ignores this field on any draft passed to `save`; it is always rebuilt
    /// from the latest document so a stale window cannot write history.
    var versions: [PromptVersion]

    init(id: UUID = UUID(), name: String, body: String, category: String? = nil,
         isFavorite: Bool = false, isArchived: Bool = false, createdAt: Date = Date(),
         updatedAt: Date? = nil, revision: Int = 1, versions: [PromptVersion] = []) {
        self.id = id; self.name = name; self.body = body; self.category = category
        self.isFavorite = isFavorite; self.isArchived = isArchived
        self.createdAt = createdAt; self.updatedAt = updatedAt ?? createdAt; self.revision = revision
        self.versions = versions
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, body, category, isFavorite, isArchived, createdAt, updatedAt, revision, versions
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        body = try c.decode(String.self, forKey: .body)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        revision = try c.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        versions = try c.decodeIfPresent([PromptVersion].self, forKey: .versions) ?? []
    }
    func validated() throws -> PromptTemplate {
        var result = self
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategory = category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        result.category = cleanCategory.isEmpty ? nil : cleanCategory
        guard !result.name.isEmpty, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              revision > 0 else { throw PromptVaultError.invalidInput }
        return result
    }
    /// Byte-wise comparison: Swift `String ==` is canonical-equivalence, which would hide Unicode edits.
    static func sameText(_ a: String, _ b: String) -> Bool { a.utf8.elementsEqual(b.utf8) }
    static func sameText(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return sameText(x, y)
        default: return false
        }
    }
    func sameContent(as other: PromptTemplate) -> Bool {
        Self.sameText(name, other.name) && Self.sameText(body, other.body) && Self.sameText(category, other.category)
    }
    func sameContent(as version: PromptVersion) -> Bool {
        Self.sameText(name, version.name) && Self.sameText(body, version.body) && Self.sameText(category, version.category)
    }
    /// Newest first. Never inferred from `revision`.
    var versionEntries: [PromptVersionEntry] {
        if versions.isEmpty {
            return [PromptVersionEntry(id: id, number: nil, name: name, body: body, category: category,
                recordedAt: nil, kind: .legacyCurrent)]
        }
        let last = versions.last?.id
        return versions.reversed().map {
            PromptVersionEntry(id: $0.id, number: $0.number, name: $0.name, body: $0.body, category: $0.category,
                recordedAt: $0.recordedAt, kind: $0.id == last ? .current : ($0.isUpgradeBaseline ? .upgradeBaseline : .history))
        }
    }
    var contentVersion: Int? { versions.last?.number }
}

/// Format policy: schemaVersion 1 (no history) is read as-is and never rewritten on load; every write by
/// this version emits schemaVersion 2 (templates may carry `versions`). Anything else locks saving.
/// A pre-history App rejects schemaVersion 2 (`unsupportedSchema`) instead of silently dropping history.
nonisolated struct PromptVaultDocument: Codable, Sendable {
    static let currentSchemaVersion = 2
    static let maxVersionsPerTemplate = 500
    var schemaVersion: Int = PromptVaultDocument.currentSchemaVersion
    var templates: [PromptTemplate] = []
    func validate() throws {
        guard schemaVersion == 1 || schemaVersion == 2 else { throw PromptVaultError.unsupportedSchema }
        guard Set(templates.map(\.id)).count == templates.count else { throw PromptVaultError.duplicateIdentity }
        var versionIDs = Set<UUID>()
        for template in templates {
            _ = try template.validated()
            let versions = template.versions
            if versions.isEmpty { continue }
            guard schemaVersion >= 2, versions.count <= Self.maxVersionsPerTemplate else { throw PromptVaultError.corruptData }
            for (offset, version) in versions.enumerated() {
                let validName = !version.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                guard version.number == offset + 1, validName,
                      !version.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      version.category?.isEmpty != true, versionIDs.insert(version.id).inserted,
                      !version.isUpgradeBaseline || offset == 0 else { throw PromptVaultError.corruptData }
            }
            // Current content and the newest snapshot are one atomic result; a mismatch means a torn or edited file.
            guard let last = versions.last, template.sameContent(as: last) else { throw PromptVaultError.corruptData }
        }
    }
}

nonisolated enum PromptVaultError: Error, LocalizedError, Equatable, Sendable {
    case invalidInput, unsupportedSchema, duplicateIdentity, corruptData, missingPrimaryWithBackup
    case unsafePath, conflict, storage(String), uncertainWrite, capacityExceeded(String)
    var errorDescription: String? {
        switch self {
        case .invalidInput: return "名称和正文须包含非空白内容；未保存。"
        case .unsupportedSchema: return "提示词库格式不受当前版本支持，已禁止保存；原文件未被自动替换。"
        case .duplicateIdentity: return "提示词库存在重复身份，已禁止保存；请核对原文件。"
        case .corruptData: return "提示词库无法解码，已禁止保存；不会用空列表覆盖原文件。"
        case .missingPrimaryWithBackup: return "主文件不存在但备份仍在，已禁止初始化；尚未自动恢复。"
        case .unsafePath: return "存储路径不是安全的普通文件／目录，或包含符号链接；已停止操作。"
        case .conflict: return "模板或磁盘数据已变化，未覆盖较新内容。草稿已保留；请复制草稿或显式重新加载。"
        case .storage(let reason): return "提示词库文件操作失败：\(reason)。草稿已保留。"
        case .capacityExceeded(let reason): return "\(reason)；未保存，输入与全部历史已保留，不会删除历史腾空间。"
        case .uncertainWrite: return "主文件替换可能已发生，但读回校验失败。界面未发布本次修改，草稿已保留；已锁定继续保存，请核对磁盘数据。"
        }
    }
    var locksSaving: Bool {
        switch self {
        case .invalidInput, .conflict, .capacityExceeded: return false
        default: return true
        }
    }
}
