import Foundation

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

    init(id: UUID = UUID(), name: String, body: String, category: String? = nil,
         isFavorite: Bool = false, isArchived: Bool = false, createdAt: Date = Date(),
         updatedAt: Date? = nil, revision: Int = 1) {
        self.id = id; self.name = name; self.body = body; self.category = category
        self.isFavorite = isFavorite; self.isArchived = isArchived
        self.createdAt = createdAt; self.updatedAt = updatedAt ?? createdAt; self.revision = revision
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, body, category, isFavorite, isArchived, createdAt, updatedAt, revision
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
}

nonisolated struct PromptVaultDocument: Codable, Sendable {
    var schemaVersion: Int = 1
    var templates: [PromptTemplate] = []
    func validate() throws {
        guard schemaVersion == 1 else { throw PromptVaultError.unsupportedSchema }
        guard Set(templates.map(\.id)).count == templates.count else { throw PromptVaultError.duplicateIdentity }
        for template in templates { _ = try template.validated() }
    }
}

nonisolated enum PromptVaultError: Error, LocalizedError, Equatable, Sendable {
    case invalidInput, unsupportedSchema, duplicateIdentity, corruptData, missingPrimaryWithBackup
    case unsafePath, conflict, storage(String), uncertainWrite
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
        case .uncertainWrite: return "主文件替换可能已发生，但读回校验失败。界面未发布本次修改，草稿已保留；已锁定继续保存，请核对磁盘数据。"
        }
    }
    var locksSaving: Bool {
        switch self {
        case .invalidInput, .conflict: return false
        default: return true
        }
    }
}
