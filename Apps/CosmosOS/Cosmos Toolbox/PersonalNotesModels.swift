import Foundation

/// 个人知识笔记：独立于卓望业务 Store 的个人模块。数据文件 `PersonalNotes/notes.json`（schema 1）。
nonisolated enum PersonalNotesLimits {
    static let documentBytes = 16 * 1024 * 1024
    static let titleCharacters = 200
    static let categoryCharacters = 60
    /// 单个正文（及每个内容快照）的 UTF-8 字节上限；超限拒绝保存，不截断。
    static let bodyBytes = 1024 * 1024
    static let versionsPerNote = 500
    static let referencesPerNote = 200
    static let referenceNameCharacters = 200
    static let referenceLocationBytes = 16 * 1024
    static let correctionBytes = 16 * 1024
}

/// 文件 / 链接引用的追加记录。只保存位置；不复制、移动、删除文件，不读取内容，不抓取网页。
/// 保存后不可改写或删除；登记错误通过追加 `.correction` 记录说明。
nonisolated struct NoteReference: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case file, link, correction }
    let id: UUID
    let kind: Kind
    let name: String
    let location: String
    /// 更正说明原文（仅 `.correction` 使用）。
    let notes: String
    let correctsReferenceID: UUID?
    let recordedAt: Date

    init(id: UUID = UUID(), kind: Kind, name: String, location: String = "", notes: String = "",
         correctsReferenceID: UUID? = nil, recordedAt: Date = Date()) {
        self.id = id; self.kind = kind; self.name = name; self.location = location
        self.notes = notes; self.correctsReferenceID = correctsReferenceID; self.recordedAt = recordedAt
    }

    func validate() throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, name.count <= PersonalNotesLimits.referenceNameCharacters, !name.contains("\0"),
              recordedAt.timeIntervalSinceReferenceDate.isFinite,
              location.utf8.count <= PersonalNotesLimits.referenceLocationBytes, !location.contains("\0"),
              notes.utf8.count <= PersonalNotesLimits.correctionBytes, !notes.contains("\0") else {
            throw PersonalNotesError.invalidInput("引用名称、位置或说明无效（名称必填，且不含 NUL、不超限）。")
        }
        switch kind {
        case .file:
            guard correctsReferenceID == nil, notes.isEmpty, location.hasPrefix("/"),
                  !location.split(separator: "/").contains("..") else {
                throw PersonalNotesError.invalidInput("文件引用须为用户选取的绝对路径。")
            }
        case .link:
            guard correctsReferenceID == nil, notes.isEmpty, let url = CampaignExternalReference.webURL(location),
                  let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  parts.user == nil, parts.password == nil else {
                throw PersonalNotesError.invalidInput("链接须为有效 http/https 地址，且不能包含认证信息。")
            }
        case .correction:
            guard correctsReferenceID != nil, location.isEmpty,
                  !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PersonalNotesError.invalidInput("更正说明须指向已有引用并填写原文。")
            }
        }
    }

    /// 复用卓望引用已有的受控打开逻辑（http/https 校验、祖先符号链接拒绝、普通文件与可读性核验）。
    /// 只检查路径元数据，不读取文件内容，不修复路径。
    func openURL() throws -> URL {
        switch kind {
        case .correction:
            throw CampaignExternalReference.ReferenceError.unavailable("更正说明没有可打开的文件或链接。")
        case .file, .link:
            do { try validate() }
            catch { throw CampaignExternalReference.ReferenceError.unavailable("引用格式无效，记录仍保留。") }
            return try CampaignExternalReference(id: id, campaignID: id, kind: kind == .file ? .file : .link,
                name: name, location: location).openURL()
        }
    }

    /// nil 表示可打开；否则返回失效原因（引用本身始终保留）。
    func unavailableReason() -> String? {
        guard kind != .correction else { return nil }
        do { _ = try openURL(); return nil } catch { return error.localizedDescription }
    }
}

/// 不可变内容快照（标题、正文、分类）。`number` 是内容版本号，与乐观锁 `revision` 分开。
nonisolated struct NoteVersion: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let number: Int
    let title: String
    let body: String
    let category: String?
    let recordedAt: Date
    init(id: UUID = UUID(), number: Int, title: String, body: String, category: String?, recordedAt: Date) {
        self.id = id; self.number = number; self.title = title; self.body = body
        self.category = category; self.recordedAt = recordedAt
    }
}

nonisolated struct PersonalNote: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var body: String
    var category: String?
    var isFavorite: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var revision: Int
    /// 存储拥有：任何草稿传入的 `versions` / `references` 都被忽略，由存储用磁盘最新记录重建。
    var versions: [NoteVersion]
    var references: [NoteReference]

    init(id: UUID = UUID(), title: String, body: String = "", category: String? = nil,
         isFavorite: Bool = false, isArchived: Bool = false, createdAt: Date = Date(),
         updatedAt: Date? = nil, revision: Int = 1, versions: [NoteVersion] = [], references: [NoteReference] = []) {
        self.id = id; self.title = title; self.body = body; self.category = category
        self.isFavorite = isFavorite; self.isArchived = isArchived
        self.createdAt = createdAt; self.updatedAt = updatedAt ?? createdAt; self.revision = revision
        self.versions = versions; self.references = references
    }

    /// 字节比较：Swift `String ==` 是规范等价，会吞掉 Unicode 层面的真实修改。
    static func sameText(_ a: String, _ b: String) -> Bool { a.utf8.elementsEqual(b.utf8) }
    static func sameText(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return sameText(x, y)
        default: return false
        }
    }
    func sameContent(as other: PersonalNote) -> Bool {
        Self.sameText(title, other.title) && Self.sameText(body, other.body) && Self.sameText(category, other.category)
    }
    func sameContent(as version: NoteVersion) -> Bool {
        Self.sameText(title, version.title) && Self.sameText(body, version.body) && Self.sameText(category, version.category)
    }
    var contentVersion: Int? { versions.last?.number }
    var currentVersionID: UUID? { versions.last?.id }

    /// 保存输入校验与规范化：仅标题、分类去除首尾空白；正文逐字节保持原样。
    func validatedInput() throws -> PersonalNote {
        var result = self
        result.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategory = category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        result.category = cleanCategory.isEmpty ? nil : cleanCategory
        guard !result.title.isEmpty else { throw PersonalNotesError.invalidInput("标题必填；未保存，输入已保留。") }
        guard result.title.count <= PersonalNotesLimits.titleCharacters else {
            throw PersonalNotesError.invalidInput("标题最多 \(PersonalNotesLimits.titleCharacters) 个字符；未保存，输入已保留。")
        }
        if let category = result.category, category.count > PersonalNotesLimits.categoryCharacters {
            throw PersonalNotesError.invalidInput("分类最多 \(PersonalNotesLimits.categoryCharacters) 个字符；未保存，输入已保留。")
        }
        guard !result.title.contains("\0"), !body.contains("\0"), result.category?.contains("\0") != true else {
            throw PersonalNotesError.invalidInput("标题、正文和分类不能包含 NUL 字符；未保存，输入已保留。")
        }
        guard body.utf8.count <= PersonalNotesLimits.bodyBytes else {
            throw PersonalNotesError.capacityExceeded("正文超过单条笔记 \(PersonalNotesLimits.bodyBytes / 1024) KiB 上限")
        }
        guard revision > 0 else { throw PersonalNotesError.invalidInput("修订号无效。") }
        return result
    }

    /// 已存储记录的结构校验（读取与写入前都执行）。
    func validateStored() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= PersonalNotesLimits.titleCharacters,
              category?.isEmpty != true, (category?.count ?? 0) <= PersonalNotesLimits.categoryCharacters,
              !title.contains("\0"), !body.contains("\0"), body.utf8.count <= PersonalNotesLimits.bodyBytes,
              revision > 0, createdAt.timeIntervalSinceReferenceDate.isFinite, updatedAt.timeIntervalSinceReferenceDate.isFinite,
              !versions.isEmpty, versions.count <= PersonalNotesLimits.versionsPerNote,
              references.count <= PersonalNotesLimits.referencesPerNote else { throw PersonalNotesError.corruptData }
        for (offset, version) in versions.enumerated() {
            guard version.number == offset + 1,
                  !version.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  version.title.count <= PersonalNotesLimits.titleCharacters,
                  version.category?.isEmpty != true, (version.category?.count ?? 0) <= PersonalNotesLimits.categoryCharacters,
                  !version.title.contains("\0"), !version.body.contains("\0"),
                  version.body.utf8.count <= PersonalNotesLimits.bodyBytes,
                  version.recordedAt.timeIntervalSinceReferenceDate.isFinite else { throw PersonalNotesError.corruptData }
        }
        // 当前内容与最新快照是同一次原子发布的结果；不一致说明文件被撕裂或手改。
        guard let last = versions.last, sameContent(as: last) else { throw PersonalNotesError.corruptData }
        var earlier = [UUID: NoteReference.Kind]()
        for reference in references {
            do { try reference.validate() } catch { throw PersonalNotesError.corruptData }
            if let corrected = reference.correctsReferenceID {
                guard let kind = earlier[corrected], kind != .correction else { throw PersonalNotesError.corruptData }
            }
            guard earlier.updateValue(reference.kind, forKey: reference.id) == nil else { throw PersonalNotesError.corruptData }
        }
    }
}

nonisolated struct PersonalNotesDocument: Codable, Sendable {
    static let currentSchemaVersion = 1
    var schemaVersion = PersonalNotesDocument.currentSchemaVersion
    var notes: [PersonalNote] = []
    func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else { throw PersonalNotesError.unsupportedSchema }
        guard Set(notes.map(\.id)).count == notes.count else { throw PersonalNotesError.duplicateIdentity }
        var versionIDs = Set<UUID>(), referenceIDs = Set<UUID>()
        for note in notes {
            try note.validateStored()
            for version in note.versions { guard versionIDs.insert(version.id).inserted else { throw PersonalNotesError.duplicateIdentity } }
            for reference in note.references { guard referenceIDs.insert(reference.id).inserted else { throw PersonalNotesError.duplicateIdentity } }
        }
    }
}

nonisolated struct PersonalNotesSnapshot: Sendable { let notes: [PersonalNote]; let established: Bool }

nonisolated enum PersonalNotesError: Error, LocalizedError, Equatable, Sendable {
    case invalidInput(String), unsupportedSchema, duplicateIdentity, corruptData, missingPrimaryWithBackup
    case unsafePath, conflict, storage(String), writeFailed(String), uncertainWrite, capacityExceeded(String)
    var errorDescription: String? {
        switch self {
        case .invalidInput(let text), .storage(let text): return text
        case .unsupportedSchema: return "个人笔记库格式不受当前版本支持，已禁止保存；原文件未被自动替换。"
        case .duplicateIdentity: return "个人笔记库存在重复身份，已禁止保存；请核对原文件。"
        case .corruptData: return "个人笔记库无法解码或结构校验失败，已禁止保存；不会用空库覆盖原文件。"
        case .missingPrimaryWithBackup: return "主笔记库不存在但备份仍在，已禁止初始化；尚未自动恢复。"
        case .unsafePath: return "存储路径不是安全的普通文件／目录、包含符号链接，或隔离配置缺失；已停止操作。"
        case .conflict: return "笔记或磁盘数据已变化，未覆盖较新内容。草稿已保留；请复制草稿或显式重新加载。"
        case .writeFailed(let text): return "保存失败，草稿已保留：\(text)"
        case .uncertainWrite: return "主文件替换可能已发生，但读回校验失败。界面未发布本次修改，草稿已保留；已锁定继续保存，请核对磁盘数据。"
        case .capacityExceeded(let reason): return "\(reason)；未保存，输入与全部历史已保留，不会删除历史腾空间。"
        }
    }
    var locksSaving: Bool {
        switch self {
        case .invalidInput, .conflict, .capacityExceeded, .writeFailed: return false
        default: return true
        }
    }
}

nonisolated enum PersonalNotesCoding {
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys, .prettyPrinted]
        e.dateEncodingStrategy = .custom { date, encoder in
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var c = encoder.singleValueContainer(); try c.encode(f.string(from: date))
        }
        return e
    }
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: text) { return date }
            f.formatOptions = [.withInternetDateTime]
            guard let date = f.date(from: text) else { throw PersonalNotesError.corruptData }
            return date
        }
        return d
    }
}

nonisolated enum NoteCategoryFilter: Hashable, Sendable { case all, uncategorized, named(String) }

nonisolated enum PersonalNotesQuery {
    /// 标题与**已保存**正文的字面搜索；分类、收藏、当前/归档组合筛选；最近更新优先。
    static func filter(_ notes: [PersonalNote], search: String, category: NoteCategoryFilter = .all,
                       favoritesOnly: Bool = false, archived: Bool) -> [PersonalNote] {
        let keyword = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.filter { note in
            guard note.isArchived == archived, !favoritesOnly || note.isFavorite else { return false }
            switch category {
            case .all: break
            case .uncategorized: if note.category != nil { return false }
            case .named(let name): if note.category != name { return false }
            }
            return keyword.isEmpty || note.title.localizedStandardContains(keyword) || note.body.localizedStandardContains(keyword)
        }.sorted {
            $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt
        }
    }
    static func categories(_ notes: [PersonalNote]) -> [String] {
        Array(Set(notes.compactMap(\.category))).sorted()
    }
}
