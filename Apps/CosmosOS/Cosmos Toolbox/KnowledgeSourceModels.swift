import Foundation
import CryptoKit
import Observation

/// 外部知识库（只读接入）：来源登记 `KnowledgeSources/sources.json`（schema 1）。
/// 来源只保存用户选择的文件夹路径；文件夹内容永远不写入、不移动、不删除，索引只在内存。
nonisolated enum KnowledgeSourceLimits {
    static let documentBytes = 1024 * 1024
    static let maxSources = 32
    static let nameCharacters = 100
    /// 单个文本文件读入上限；超出的文件只列出。
    static let fileBytes = 2 * 1024 * 1024
    /// 单个来源文本总量上限；超出的文件只列出。
    static let totalTextBytes = 64 * 1024 * 1024
    /// 单个来源列出的条目上限（防止失控扫描）。
    static let maxEntries = 100_000
    /// 判定敏感性时读取的文件头字节数（不保留）。
    static let classificationHeadBytes = 256 * 1024
    static let imageBytes = 20 * 1024 * 1024
}

nonisolated struct KnowledgeSource: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var displayName: String
    /// 规范化后的绝对路径（realpath）。
    let path: String
    let addedAt: Date
    var isEnabled: Bool

    init(id: UUID = UUID(), displayName: String, path: String, addedAt: Date = Date(), isEnabled: Bool = true) {
        self.id = id; self.displayName = displayName; self.path = path; self.addedAt = addedAt; self.isEnabled = isEnabled
    }
    var rootURL: URL { URL(fileURLWithPath: path, isDirectory: true) }

    static func validName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= KnowledgeSourceLimits.nameCharacters, !trimmed.contains("\0"),
              !trimmed.contains("\n") else { return nil }
        return trimmed
    }
    static func validPath(_ path: String) -> Bool {
        path.hasPrefix("/") && path.count > 1 && !path.contains("\0") && !path.split(separator: "/").contains("..")
            && !path.hasSuffix("/")
    }
    func validate() throws {
        guard Self.validName(displayName) == displayName, Self.validPath(path),
              addedAt.timeIntervalSinceReferenceDate.isFinite else { throw KnowledgeSourceError.corruptData }
    }
}

nonisolated struct KnowledgeSourcesDocument: Codable, Sendable {
    static let currentSchemaVersion = 1
    var schemaVersion = KnowledgeSourcesDocument.currentSchemaVersion
    /// 每次成功写入加一；用于乐观并发（缺库为 0）。
    var revision = 0
    var sources: [KnowledgeSource] = []
    func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else { throw KnowledgeSourceError.unsupportedSchema }
        guard revision >= 0, sources.count <= KnowledgeSourceLimits.maxSources else { throw KnowledgeSourceError.corruptData }
        guard Set(sources.map(\.id)).count == sources.count, Set(sources.map(\.path)).count == sources.count else {
            throw KnowledgeSourceError.duplicateIdentity
        }
        for source in sources { try source.validate() }
    }
}

nonisolated struct KnowledgeSourcesSnapshot: Sendable, Equatable {
    let sources: [KnowledgeSource]
    let revision: Int
    let established: Bool
}

nonisolated enum KnowledgeSourceError: Error, LocalizedError, Equatable, Sendable {
    case invalidInput(String), unsupportedSchema, duplicateIdentity, corruptData, missingPrimaryWithBackup
    case unsafePath, conflict, storage(String), writeFailed(String), uncertainWrite, capacityExceeded(String)
    case duplicateSource(String), overlap(String), notFound
    var errorDescription: String? {
        switch self {
        case .invalidInput(let text), .storage(let text), .duplicateSource(let text), .overlap(let text): return text
        case .unsupportedSchema: return "知识库来源登记格式不受当前版本支持，已禁止保存；原文件未被自动替换。"
        case .duplicateIdentity: return "知识库来源登记存在重复的身份或路径，已禁止保存；请核对原文件。"
        case .corruptData: return "知识库来源登记无法解码或结构校验失败，已禁止保存；不会用空库覆盖原文件。"
        case .missingPrimaryWithBackup: return "来源登记主文件不存在但备份仍在，已禁止初始化；尚未自动恢复。"
        case .unsafePath: return "存储路径不是安全的普通文件／目录、包含符号链接，或隔离配置缺失；已停止操作。"
        case .conflict: return "来源登记已被更新，本次修改未覆盖较新内容；请刷新后重试。"
        case .writeFailed(let text): return "保存失败：\(text)"
        case .uncertainWrite: return "主文件替换可能已发生，但读回校验失败。界面未发布本次修改，已锁定继续保存，请核对磁盘数据。"
        case .capacityExceeded(let reason): return "\(reason)；未保存。"
        case .notFound: return "该来源已不存在，请刷新。"
        }
    }
    var locksSaving: Bool {
        switch self {
        case .invalidInput, .conflict, .capacityExceeded, .writeFailed, .duplicateSource, .overlap, .notFound: return false
        default: return true
        }
    }
}

nonisolated enum KnowledgeSourceCoding {
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
            guard let date = f.date(from: text) else { throw KnowledgeSourceError.corruptData }
            return date
        }
        return d
    }
}

/// 存储位置。正式：`~/Library/Application Support/Cosmos OS/KnowledgeSources/sources.json`。
/// DEBUG 隔离启动必须同时给出隔离 Bundle ID 与 `--cosmos-knowledge-sources-fixture-root`；缺失即失败关闭。
struct KnowledgeSourcesLocation {
    let root: URL?
    let error: KnowledgeSourceError?
    /// 隔离环境下只允许登记 /private/tmp 下的文件夹。Release 恒为 false。
    var isolated = false

    static func resolve(isIsolated: Bool, bundleIdentifier: String?, arguments: [String]) -> Self {
#if DEBUG
        let flag = "--cosmos-knowledge-sources-fixture-root", prefix = "/private/tmp/CosmosKnowledgeSources-"
        if isIsolated || arguments.contains(flag) {
            guard isIsolated, let bundleIdentifier,
                  bundleIdentifier.hasPrefix(CosmosDebugStorePersistenceBootstrap.isolatedBundleIdentifierPrefix),
                  let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
                return Self(root: nil, error: .unsafePath)
            }
            let path = arguments[index + 1]
            guard path.hasPrefix(prefix), UUID(uuidString: String(path.dropFirst(prefix.count))) != nil,
                  !path.contains("..") else { return Self(root: nil, error: .unsafePath) }
            return Self(root: URL(fileURLWithPath: path, isDirectory: true), error: nil, isolated: true)
        }
#endif
        do { return Self(root: try KnowledgeSourceFileStorage.productionRoot(), error: nil) }
        catch { return Self(root: nil, error: .storage(error.localizedDescription)) }
    }
}

// MARK: - Document identity / open request

/// 来源 + 来源内相对路径。统一检索与导航使用。
nonisolated struct KnowledgeDocumentRef: Hashable, Sendable {
    let sourceID: UUID
    let relativePath: String

    /// 由来源 ID 与相对路径确定性派生的稳定 UUID（SHA-256 前 16 字节，按 UUIDv5 形式设置版本位）。
    var stableID: UUID {
        var hasher = SHA256()
        hasher.update(data: Data(sourceID.uuidString.utf8)); hasher.update(data: Data([0]))
        hasher.update(data: Data(relativePath.precomposedStringWithCanonicalMapping.utf8))
        var bytes = Array(hasher.finalize().prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50; bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

/// 打开请求：目标文件，可选标题锚点。
struct KnowledgeSourceOpenRequest: Equatable, Sendable {
    let document: KnowledgeDocumentRef
    var heading: String? = nil
    /// 每次请求唯一，使重复点击同一目标也能触发。
    var serial = UUID()
}

/// 打开请求的中转站：统一检索把请求投递到这里；「我的知识库」页面消费。
/// 页面不在前台时，接线层观察 `pending` 并把导航切到该页面（见接线说明）。
@Observable @MainActor
final class KnowledgeSourceOpenCenter {
    static let shared = KnowledgeSourceOpenCenter()
    var pending: KnowledgeSourceOpenRequest?
    func post(_ request: KnowledgeSourceOpenRequest) { pending = request }
    func consume() -> KnowledgeSourceOpenRequest? { defer { pending = nil }; return pending }
}
