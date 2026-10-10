import Foundation
import CryptoKit

/// 个人内容导出：把用户已保存的个人笔记 / 提示词导出为 Markdown 文件或内容 ZIP。
/// 这是内容导出，不是核心数据备份：不调用 AI、不改源库、不进入恢复流程。
nonisolated enum ContentExportSource: String, Codable, Sendable, CaseIterable, Hashable {
    case personalNote, promptTemplate
    var label: String { self == .personalNote ? "个人笔记" : "提示词" }
    /// 包内顶层目录。
    var directory: String { self == .personalNote ? "notes" : "prompts" }
    var sortRank: Int { self == .personalNote ? 0 : 1 }
}

nonisolated enum ContentExportScope: String, Sendable, Hashable {
    case currentOnly, includeHistory
}

nonisolated struct ContentExportSelection: Hashable, Sendable {
    let source: ContentExportSource
    let id: UUID
}

/// 单条 .md 导出的目标版本。`current` 携带界面当时展示的版本身份（旧提示词无历史则为 nil），
/// 准备时与磁盘最新记录核对，不一致即停止，绝不静默换版。
nonisolated enum ContentExportSingleVersion: Sendable, Hashable {
    case current(expectedVersionID: UUID?)
    case specific(UUID)
}

nonisolated struct ContentExportSingleRequest: Sendable, Hashable {
    let source: ContentExportSource
    let id: UUID
    let version: ContentExportSingleVersion
}

nonisolated struct ContentExportBatchRequest: Sendable {
    let selections: [ContentExportSelection]
    let scope: ContentExportScope
}

/// 一个已保存版本的原文快照。旧提示词（无历史）以 `versionID == nil` 表示，不编造版本号或日期。
nonisolated struct ContentExportVersion: Sendable {
    let versionID: UUID?
    let number: Int?
    let name: String
    let category: String?
    let body: String
    let savedAt: Date?
    /// 升级前基线：`savedAt` 沿用了模板当时的 updatedAt，并非实际编辑时间。
    let isUpgradeBaseline: Bool
    var bodyData: Data { Data(body.utf8) }
}

nonisolated struct ContentExportRecord: Sendable {
    let source: ContentExportSource
    let id: UUID
    let name: String
    let category: String?
    let isArchived: Bool
    /// 旧 → 新；最后一个是当前已保存内容。
    let versions: [ContentExportVersion]
    /// 仅个人笔记：全部引用与更正记录（原样登记信息）。
    let references: [NoteReference]
    var current: ContentExportVersion { versions[versions.count - 1] }
    var selection: ContentExportSelection { ContentExportSelection(source: source, id: id) }

    init(note: PersonalNote) {
        source = .personalNote; id = note.id; name = note.title; category = note.category
        isArchived = note.isArchived; references = note.references
        versions = note.versions.map {
            ContentExportVersion(versionID: $0.id, number: $0.number, name: $0.title, category: $0.category,
                body: $0.body, savedAt: $0.recordedAt, isUpgradeBaseline: false)
        }
    }
    init(template: PromptTemplate) {
        source = .promptTemplate; id = template.id; name = template.name; category = template.category
        isArchived = template.isArchived; references = []
        if template.versions.isEmpty {
            versions = [ContentExportVersion(versionID: nil, number: nil, name: template.name,
                category: template.category, body: template.body, savedAt: nil, isUpgradeBaseline: false)]
        } else {
            versions = template.versions.map {
                ContentExportVersion(versionID: $0.id, number: $0.number, name: $0.name, category: $0.category,
                    body: $0.body, savedAt: $0.recordedAt, isUpgradeBaseline: $0.isUpgradeBaseline)
            }
        }
    }
    private init(copy record: ContentExportRecord, versions: [ContentExportVersion]) {
        source = record.source; id = record.id; name = record.name; category = record.category
        isArchived = record.isArchived; references = record.references; self.versions = versions
    }
    func restricting(to versions: [ContentExportVersion]) -> ContentExportRecord {
        ContentExportRecord(copy: self, versions: versions)
    }

    /// 与导出相关的全部数据的指纹（按 UTF-8 字节，不受 Swift 字符串规范等价影响）。
    /// 收藏、updatedAt、revision 等与导出无关的字段不参与，因此元数据操作不会误伤。
    /// `includeRecordMetadata`：名称 / 分类 / 归档状态是否属于导出内容（批量包的 manifest 含这些；单条 .md 不含）。
    func fingerprint(includeRecordMetadata: Bool, includeReferences: Bool) -> String {
        var writer = ContentExportFingerprintWriter()
        writer.put(source.rawValue); writer.put(id.uuidString)
        if includeRecordMetadata { writer.put(name); writer.put(category); writer.put(isArchived ? "1" : "0") }
        writer.put(String(versions.count))
        for version in versions {
            writer.put(version.versionID?.uuidString); writer.put(version.number.map(String.init))
            writer.put(version.name); writer.put(version.category); writer.put(version.body)
            writer.put(version.savedAt.map { ContentExportTime.string($0) })
            writer.put(version.isUpgradeBaseline ? "1" : "0")
        }
        if includeReferences {
            writer.put(String(references.count))
            for reference in references {
                writer.put(reference.id.uuidString); writer.put(reference.kind.rawValue); writer.put(reference.name)
                writer.put(reference.location); writer.put(reference.notes)
                writer.put(reference.correctsReferenceID?.uuidString); writer.put(ContentExportTime.string(reference.recordedAt))
            }
        }
        return writer.finish()
    }
}

nonisolated struct ContentExportFingerprintWriter {
    private var hasher = SHA256()
    mutating func put(_ text: String?) {
        guard let text else { hasher.update(data: Data([0])); return }
        let data = Data(text.utf8)
        var length = UInt64(data.count).bigEndian
        hasher.update(data: Data([1]))
        withUnsafeBytes(of: &length) { hasher.update(bufferPointer: $0) }
        hasher.update(data: data)
    }
    func finish() -> String { hasher.finalize().map { String(format: "%02x", $0) }.joined() }
}

nonisolated enum ContentExportTime {
    static func string(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

/// 选择界面的一行（只含元数据，不含正文）。
nonisolated struct ContentExportListingRow: Identifiable, Sendable, Hashable {
    let source: ContentExportSource
    let recordID: UUID
    let name: String
    let category: String?
    let isArchived: Bool
    /// 当前内容版本号；旧提示词（无历史）为 nil。
    let contentVersion: Int?
    let versionCount: Int
    let referenceCount: Int
    let updatedAt: Date
    var id: ContentExportSelection { ContentExportSelection(source: source, id: recordID) }
    var versionLabel: String {
        guard let contentVersion else { return "无版本历史（升级前内容）" }
        return "内容 v\(contentVersion) · 共 \(versionCount) 个版本"
    }
}

/// 选择界面的筛选口径。“全选当前筛选结果”只选这里返回的行；归档记录只有切到“已归档”并明确选择才会进入。
nonisolated enum ContentExportListingFilter {
    static func apply(_ rows: [ContentExportListingRow], source: ContentExportSource?, archived: Bool, search: String) -> [ContentExportListingRow] {
        let keyword = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return rows.filter { row in
            if let source, row.source != source { return false }
            guard row.isArchived == archived else { return false }
            return keyword.isEmpty || row.name.localizedStandardContains(keyword) || (row.category?.localizedStandardContains(keyword) ?? false)
        }.sorted { $0.updatedAt == $1.updatedAt ? $0.recordID.uuidString < $1.recordID.uuidString : $0.updatedAt > $1.updatedAt }
    }
}

nonisolated struct ContentExportPreview: Sendable, Equatable {
    struct Row: Identifiable, Sendable, Equatable {
        let id: String
        let source: String
        let name: String
        let category: String
        let archived: Bool
        let versionSummary: String
        let fileCount: Int
        let bytes: Int
        let referenceCount: Int
    }
    let rows: [Row]
    let fileCount: Int
    let totalBytes: Int
    let notices: [String]
}

nonisolated enum ContentExportSelectionRule: Sendable, Hashable {
    case singleCurrent(expectedVersionID: UUID?)
    case singleSpecific(UUID)
    case batch(ContentExportScope)
}

/// 准备阶段冻结的导出内容。导出前以同一规则重新读取并按指纹核对，绝不信任界面提交的正文。
nonisolated struct ContentExportPlan: Sendable {
    enum Kind: Sendable { case singleMarkdown, archive }
    let kind: Kind
    let rule: ContentExportSelectionRule
    let records: [ContentExportRecord]
    let fingerprints: [ContentExportSelection: String]
    let suggestedFileName: String
    let preview: ContentExportPreview
    var includeReferences: Bool { kind == .archive }
    var includeRecordMetadata: Bool { kind == .archive }
    func fingerprint(of record: ContentExportRecord) -> String {
        record.fingerprint(includeRecordMetadata: includeRecordMetadata, includeReferences: includeReferences)
    }
    var scope: ContentExportScope {
        if case .batch(let scope) = rule { return scope }
        return .currentOnly
    }
}

nonisolated struct ContentExportResult: Sendable, Equatable {
    let url: URL
    let kind: ContentExportPlan.Kind
    let entryCount: Int
    let byteCount: Int
    let sha256: String
}

extension ContentExportPlan.Kind: Equatable {}

nonisolated enum ContentExportCheckpoint: Sendable, Equatable {
    case afterRecheck, afterBuild, afterVerify, afterSecondRecheck, beforePublish, afterPartWritten
}

nonisolated final class ContentExportCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func check() throws { if isCancelled { throw ContentExportError.cancelled } }
}

nonisolated enum ContentExportError: Error, LocalizedError, Equatable, Sendable {
    case noSelection
    case sourceUnavailable(String)
    case recordMissing(String)
    case versionMissing(String)
    case sourceChanged(String)
    case destinationInvalid(String)
    case destinationExists
    case tooLarge(String)
    case buildFailed(String)
    case verifyFailed(String)
    case publishFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noSelection: return "尚未选择任何要导出的记录。"
        case .sourceUnavailable(let reason): return "无法读取导出来源，已停止（不会当作空结果）：\(reason)"
        case .recordMissing(let name): return "「\(name)」已不存在于源库，已停止导出。请重新选择并准备。"
        case .versionMissing(let name): return "「\(name)」中所选版本已不存在，已停止导出。请重新选择并准备。"
        case .sourceChanged(let name): return "「\(name)」的已保存内容、版本或与导出相关的信息已变化，已停止导出，未导出任何混合内容。请重新准备导出范围。"
        case .destinationInvalid(let reason): return "无法使用所选保存位置：\(reason)"
        case .destinationExists: return "目标位置已存在同名文件或文件夹；为保护现有内容，不会覆盖。请换一个名称或位置。"
        case .tooLarge(let reason): return "导出内容超出容量限制：\(reason)"
        case .buildFailed(let reason): return "生成导出文件失败：\(reason)。未发布任何文件。"
        case .verifyFailed(let reason): return "导出文件校验失败：\(reason)。未发布任何文件。"
        case .publishFailed(let reason): return "发布导出文件失败：\(reason)。未留下导出结果。"
        case .cancelled: return "导出已取消，未发布任何文件。"
        }
    }
}

/// 显示名称 → 安全文件名片段。只用于路径；绝不改写正文。
nonisolated enum ContentExportFileName {
    private static let forbidden = Set<Character>(["/", "\\", ":", "*", "?", "\"", "<", ">", "|"])
    private static let reserved: Set<String> = ["con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5",
        "com6", "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9"]

    static func safeDisplay(_ raw: String, fallback: String = "未命名", maxCharacters: Int = 60, maxBytes: Int = 120) -> String {
        var cleaned = ""
        for character in raw {
            if forbidden.contains(character) { cleaned.append("_"); continue }
            let scalars = character.unicodeScalars
            if scalars.contains(where: { scalar in
                switch scalar.properties.generalCategory {
                case .control, .lineSeparator, .paragraphSeparator: return true
                case .format: return (0x202A...0x202E).contains(scalar.value) || (0x2066...0x2069).contains(scalar.value)
                default: return false
                }
            }) { cleaned.append("_"); continue }
            cleaned.append(character)
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix(".") { cleaned = "_" + String(cleaned.drop(while: { $0 == "." })) }
        while cleaned.hasSuffix(".") || cleaned.hasSuffix(" ") { cleaned.removeLast() }
        while cleaned.count > maxCharacters { cleaned.removeLast() }
        while cleaned.utf8.count > maxBytes { cleaned.removeLast() }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return fallback }
        if reserved.contains(cleaned.lowercased()) { cleaned += "_" }
        return cleaned
    }

    /// 包内相对路径必须是纯相对、无穿越、无空组件、无反斜杠 / NUL 的路径。
    static func isSafeArchivePath(_ path: String) -> Bool {
        guard !path.isEmpty, path.utf8.count <= 1024, !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0"),
              !path.hasSuffix("/") else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return !components.contains { $0.isEmpty || $0 == "." || $0 == ".." }
    }

    static func ensureExtension(_ url: URL, allowed: [String], default ext: String) -> URL {
        if allowed.contains(url.pathExtension.lowercased()) { return url }
        return url.appendingPathExtension(ext)
    }
}
