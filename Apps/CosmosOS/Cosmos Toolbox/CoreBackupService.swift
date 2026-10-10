import Foundation
import CryptoKit
import Darwin

/// Invoked on a background queue by Settings. Sources are read only; publication uses exclusive rename.
nonisolated struct CoreBackupService {
    static let sourceLimit = 16 * 1024 * 1024
    static let packageLimit = 128 * 1024 * 1024
    static let manifestLimit = 256 * 1024
    var source: CoreBackupSource
    var checkpoint: () throws -> Void = {}

    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func kind(_ url: URL) throws -> stat? {
        var info = stat()
        if lstat(url.path, &info) == 0 { return info }
        if errno == ENOENT { return nil }
        throw CoreBackupError.invalid("无法读取路径或文件状态。")
    }
    static func checkParents(_ url: URL) throws {
        guard url.isFileURL, url.path.hasPrefix("/"), !url.path.contains("\0"), !url.path.split(separator: "/").contains("..") else { throw CoreBackupError.invalid("路径无效。") }
        var cursor = url.deletingLastPathComponent()
        while cursor.path != "/" {
            if let info = try kind(cursor) {
                guard info.st_mode & S_IFMT == S_IFDIR else { throw CoreBackupError.invalid("拒绝符号链接或非目录路径。") }
            }
            cursor.deleteLastPathComponent()
        }
    }
    private static func revision(_ info: stat) -> String {
        "\(info.st_dev):\(info.st_ino):\(info.st_size):\(info.st_mtimespec.tv_sec):\(info.st_mtimespec.tv_nsec):\(info.st_ctimespec.tv_sec):\(info.st_ctimespec.tv_nsec)"
    }
    static func readFile(_ url: URL, limit: Int) throws -> (Data, String)? {
        try checkParents(url)
        guard let before = try kind(url) else { return nil }
        guard before.st_mode & S_IFMT == S_IFREG, before.st_size >= 0, before.st_size <= limit else { throw CoreBackupError.invalid("拒绝符号链接、非普通文件或超限内容。") }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard fd >= 0 else { throw CoreBackupError.invalid("文件不可读取。") }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var opened = stat()
        guard fstat(fd, &opened) == 0, revision(opened) == revision(before) else { throw CoreBackupError.invalid("读取期间文件变化。") }
        let bytes = try handle.read(upToCount: limit + 1) ?? Data()
        guard let after = try kind(url), bytes.count == before.st_size, bytes.count <= limit,
              revision(before) == revision(after) else { throw CoreBackupError.invalid("读取期间文件变化或内容超限。") }
        return (bytes, revision(after))
    }

    func export(to target: URL) throws -> CoreBackupResult {
        try Self.checkParents(target)
        guard try Self.kind(target) == nil else { throw CoreBackupError.invalid("目标已存在，未覆盖；请选择新的文件名。") }
        let temporary = target.deletingLastPathComponent().appendingPathComponent(".cosmos-core-backup-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let initial = try source.capture()
        var entries = [String: Data](), sources = [CoreBackupEntry]()
        var total = 0
        for (index, id) in CoreBackupSource.ids.enumerated() {
            guard let raw = initial.data[index] else {
                sources.append(.init(id: id, status: "missing", path: nil, bytes: 0, sha256: nil, transformation: nil)); continue
            }
            let safe = try CoreBackupSource.sanitized(raw, id: id)
            total += safe.count
            guard total <= Self.packageLimit - Self.manifestLimit else { throw CoreBackupError.invalid("备份数据超过总容量限制。") }
            let path = "data/\(id).json"; entries[path] = safe
            sources.append(.init(id: id, status: "present", path: path, bytes: safe.count, sha256: Self.digest(safe),
                transformation: CoreBackupSource.configurationFields[id] == nil ? nil : "已按非敏感字段白名单转换；排除项见 exclusions。"))
        }
        let manifest = CoreBackupManifest(exportedAt: Date(), sources: sources)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        entries["manifest.json"] = try encoder.encode(manifest)
        let archive = try CoreBackupArchive.encode(entries)
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw CoreBackupError.invalid("无法创建临时备份包。") }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        do { try handle.write(contentsOf: archive); guard fsync(fd) == 0 else { throw CoreBackupError.invalid("备份写入同步失败。") }; try handle.close() }
        catch { try? handle.close(); throw error }
        _ = try Self.verify(temporary)
        try checkpoint()
        guard initial == (try source.capture()) else { throw CoreBackupError.invalid("导出期间源数据发生变化，未发布；请重试。") }
        try Self.checkParents(target)
        guard renamex_np(temporary.path, target.path, UInt32(RENAME_EXCL)) == 0 else { throw CoreBackupError.invalid("发布失败或目标已存在；未覆盖。") }
        return CoreBackupResult(url: target, manifest: manifest)
    }

    static func verify(_ url: URL) throws -> CoreBackupResult {
        guard let raw = try readFile(url, limit: packageLimit)?.0 else { throw CoreBackupError.invalid("备份包不存在。") }
        return try verifyBytes(raw, at: url)
    }

    static func verifyBytes(_ raw: Data, at url: URL) throws -> CoreBackupResult {
        let entries = try CoreBackupArchive.decode(raw)
        guard let bytes = entries["manifest.json"], bytes.count <= manifestLimit else { throw CoreBackupError.invalid("清单缺失或超限。") }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let manifest: CoreBackupManifest
        do { manifest = try decoder.decode(CoreBackupManifest.self, from: bytes) }
        catch { throw CoreBackupError.invalid("清单无法解析。") }
        guard manifest.format == "CosmosCoreMetadata", [1, 2].contains(manifest.version),
              manifest.exportedAt.timeIntervalSinceReferenceDate.isFinite,
              manifest.sources.count == (manifest.version == 1 ? CoreBackupSource.legacyIDs.count : CoreBackupSource.ids.count),
              Set(manifest.sources.map(\.id)) == Set(manifest.version == 1 ? CoreBackupSource.legacyIDs : CoreBackupSource.ids), manifest.exclusions == CoreBackupSource.exclusions else {
            throw CoreBackupError.invalid("格式版本、范围或排除说明无效。")
        }
        var expected: Set<String> = ["manifest.json"]
        for item in manifest.sources {
            switch item.status {
            case "missing":
                guard item.path == nil, item.bytes == 0, item.sha256 == nil, item.transformation == nil else { throw CoreBackupError.invalid("尚未建立项的清单无效。") }
            case "present":
                let path = "data/\(item.id).json"
                guard item.path == path, let body = entries[path], item.bytes == body.count,
                      item.bytes <= sourceLimit, item.sha256 == digest(body) else { throw CoreBackupError.invalid("\(item.id)：缺项、大小或 SHA-256 不一致。") }
                try CoreBackupSource.validated(body, id: item.id)
                if let fields = CoreBackupSource.configurationFields[item.id] {
                    guard item.transformation == "已按非敏感字段白名单转换；排除项见 exclusions。",
                          let values = try JSONSerialization.jsonObject(with: body) as? [[String: Any]],
                          values.allSatisfy({ Set($0.keys).isSubset(of: fields) }) else { throw CoreBackupError.invalid("配置含未获准字段或转换说明缺失。") }
                } else if item.transformation != nil { throw CoreBackupError.invalid("业务载荷转换说明异常。") }
                expected.insert(path)
            default: throw CoreBackupError.invalid("未知数据源状态。")
            }
        }
        guard expected == Set(entries.keys) else { throw CoreBackupError.invalid("存在未列入清单或重复的条目。") }
        return CoreBackupResult(url: url, manifest: manifest)
    }
}
