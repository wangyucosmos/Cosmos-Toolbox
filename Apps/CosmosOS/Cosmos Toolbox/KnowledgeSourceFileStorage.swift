import Foundation
import Darwin

nonisolated enum KnowledgeSourceStorageStage: Sendable, Equatable { case read, encode, backup, backupReadBack, replace, readBack }

nonisolated enum KnowledgeSourceMutation: Sendable {
    case add(KnowledgeSource, expectedRevision: Int)
    case remove(id: UUID, expectedRevision: Int)
    case rename(id: UUID, name: String, expectedRevision: Int)
    case setEnabled(id: UUID, enabled: Bool, expectedRevision: Int)
    var expectedRevision: Int {
        switch self {
        case .add(_, let r), .remove(_, let r), .rename(_, _, let r), .setEnabled(_, _, let r): return r
        }
    }
}

/// 独立知识库来源登记存储：缺库只读零初始化、结构校验、协作 flock 写锁、写前精确字节备份、
/// 原子 rename 发布与读回校验。登记很小；只保存路径，从不触碰来源文件夹内容。
nonisolated final class KnowledgeSourceFileStorage: @unchecked Sendable {
    let root: URL
    private let queue = DispatchQueue(label: "cosmos.knowledge-sources.storage")
    private let hook: @Sendable (KnowledgeSourceStorageStage) throws -> Void
    var primaryURL: URL { root.appendingPathComponent("sources.json") }
    var backupURL: URL { root.appendingPathComponent("sources.backup.json") }
    private var lockURL: URL { root.appendingPathComponent(".sources.lock") }

    static func productionRoot() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false)
            .appendingPathComponent("Cosmos OS/KnowledgeSources", isDirectory: true)
    }
    init(root: URL, hook: @escaping @Sendable (KnowledgeSourceStorageStage) throws -> Void = { _ in }) {
        self.root = root; self.hook = hook
    }

    func load() async throws -> KnowledgeSourcesSnapshot {
        try await perform { try self.loadSynchronously() }
    }
    /// 只读同步加载（统一检索使用）：缺库不创建任何文件。
    func loadSynchronously() throws -> KnowledgeSourcesSnapshot {
        do {
            let loaded = try readDocument()
            return KnowledgeSourcesSnapshot(sources: loaded.document.sources, revision: loaded.document.revision, established: loaded.raw != nil)
        } catch let error as KnowledgeSourceError { throw error }
        catch { throw KnowledgeSourceError.storage(error.localizedDescription) }
    }
    func apply(_ mutation: KnowledgeSourceMutation) async throws -> KnowledgeSourcesSnapshot {
        try await perform { try self.transact(mutation) }
    }

    private func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try operation()) }
                catch let error as KnowledgeSourceError { continuation.resume(throwing: error) }
                catch { continuation.resume(throwing: KnowledgeSourceError.storage(error.localizedDescription)) }
            }
        }
    }

    // MARK: File primitives

    private func kind(_ url: URL) throws -> mode_t? {
        var info = stat()
        if lstat(url.path, &info) == 0 { return info.st_mode & S_IFMT }
        if errno == ENOENT { return nil }
        throw KnowledgeSourceError.storage(String(cString: strerror(errno)))
    }
    private func checkParents(create: Bool) throws -> Bool {
        guard root.isFileURL, root.path.hasPrefix("/"), !root.path.contains("\0"),
              !root.path.split(separator: "/").contains("..") else { throw KnowledgeSourceError.unsafePath }
        var path = URL(fileURLWithPath: "/", isDirectory: true)
        for component in root.path.split(separator: "/") {
            path.appendPathComponent(String(component), isDirectory: true)
            if let type = try kind(path) {
                guard type == S_IFDIR else { throw KnowledgeSourceError.unsafePath }
            } else if create {
                if mkdir(path.path, 0o700) != 0, errno != EEXIST {
                    throw KnowledgeSourceError.storage(String(cString: strerror(errno)))
                }
                guard try kind(path) == S_IFDIR else { throw KnowledgeSourceError.unsafePath }
            } else { return false }
        }
        return true
    }
    private func read(_ url: URL) throws -> Data? {
        guard let type = try kind(url) else { return nil }
        guard type == S_IFREG else { throw KnowledgeSourceError.unsafePath }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw KnowledgeSourceError.storage(String(cString: strerror(errno))) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw KnowledgeSourceError.unsafePath }
        guard info.st_size <= KnowledgeSourceLimits.documentBytes else {
            throw KnowledgeSourceError.storage("文件超过 1 MiB 限制，不会截断")
        }
        let data = try handle.read(upToCount: KnowledgeSourceLimits.documentBytes + 1) ?? Data()
        guard data.count <= KnowledgeSourceLimits.documentBytes, data.count == info.st_size else { throw KnowledgeSourceError.conflict }
        return data
    }
    private func readDocument() throws -> (document: KnowledgeSourcesDocument, raw: Data?) {
        try hook(.read)
        guard try checkParents(create: false) else { return (KnowledgeSourcesDocument(), nil) }
        if let type = try kind(backupURL), type != S_IFREG { throw KnowledgeSourceError.unsafePath }
        guard let raw = try read(primaryURL) else {
            if try kind(backupURL) != nil { throw KnowledgeSourceError.missingPrimaryWithBackup }
            return (KnowledgeSourcesDocument(), nil)
        }
        guard String(data: raw, encoding: .utf8) != nil, !raw.contains(0) else { throw KnowledgeSourceError.corruptData }
        let document: KnowledgeSourcesDocument
        do { document = try KnowledgeSourceCoding.decoder().decode(KnowledgeSourcesDocument.self, from: raw) }
        catch { throw KnowledgeSourceError.corruptData }
        try document.validate()
        return (document, raw)
    }
    /// 兄弟临时文件 + rename；所有失败都发生在 rename 之前，目标保持不变。
    private func writeAtomic(_ data: Data, to target: URL) throws {
        if let type = try kind(target), type != S_IFREG { throw KnowledgeSourceError.unsafePath }
        let temporary = root.appendingPathComponent(".sources-write-" + UUID().uuidString)
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw KnowledgeSourceError.writeFailed(String(cString: strerror(errno))) }
        var closed = false
        defer { if !closed { close(fd) }; unlink(temporary.path) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        do { try handle.write(contentsOf: data); try handle.synchronize() }
        catch { throw KnowledgeSourceError.writeFailed(error.localizedDescription) }
        closed = true
        guard close(fd) == 0 else { throw KnowledgeSourceError.writeFailed(String(cString: strerror(errno))) }
        _ = try checkParents(create: false)
        if let type = try kind(target), type != S_IFREG { throw KnowledgeSourceError.unsafePath }
        guard rename(temporary.path, target.path) == 0 else {
            throw KnowledgeSourceError.writeFailed(String(cString: strerror(errno)))
        }
    }
    private func beforeReplace<T>(_ body: () throws -> T) throws -> T {
        do { return try body() }
        catch KnowledgeSourceError.storage(let reason) { throw KnowledgeSourceError.writeFailed(reason) }
        catch let error as KnowledgeSourceError { throw error }
        catch { throw KnowledgeSourceError.writeFailed(error.localizedDescription) }
    }

    // MARK: Transaction

    private func transact(_ mutation: KnowledgeSourceMutation) throws -> KnowledgeSourcesSnapshot {
        let lockFD: Int32 = try beforeReplace {
            _ = try checkParents(create: true)
            if let type = try kind(lockURL), type != S_IFREG { throw KnowledgeSourceError.unsafePath }
            let fd = open(lockURL.path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
            guard fd >= 0 else { throw KnowledgeSourceError.storage(String(cString: strerror(errno))) }
            guard flock(fd, LOCK_EX) == 0 else { close(fd); throw KnowledgeSourceError.storage("无法取得知识库来源写锁") }
            return fd
        }
        defer { flock(lockFD, LOCK_UN); close(lockFD) }

        let prepared: (encoded: Data, raw: Data?) = try beforeReplace {
            // 在锁内读取最新磁盘状态；任何修改都基于它生成。
            let loaded = try readDocument()
            let candidate = try Self.apply(mutation, to: loaded.document)
            try candidate.validate()
            try hook(.encode)
            let encoded = try KnowledgeSourceCoding.encoder().encode(candidate)
            guard encoded.count <= KnowledgeSourceLimits.documentBytes else {
                throw KnowledgeSourceError.capacityExceeded("来源登记将超过 1 MiB 限制")
            }
            guard try read(primaryURL) == loaded.raw else { throw KnowledgeSourceError.conflict }
            if let raw = loaded.raw {
                try hook(.backup)
                try writeAtomic(raw, to: backupURL)
                try hook(.backupReadBack)
                guard try read(backupURL) == raw else { throw KnowledgeSourceError.writeFailed("备份读回不一致") }
            }
            guard try read(primaryURL) == loaded.raw else { throw KnowledgeSourceError.conflict }
            try hook(.replace)
            return (encoded, loaded.raw)
        }

        // 到 rename 为止的任何抛错都不触及主文件。
        try beforeReplace { try writeAtomic(prepared.encoded, to: primaryURL) }

        // 主文件已替换；此后无法确认的情况一律视为不确定写入。
        do {
            try hook(.readBack)
            guard let actual = try read(primaryURL), actual == prepared.encoded else { throw KnowledgeSourceError.uncertainWrite }
            let decoded = try KnowledgeSourceCoding.decoder().decode(KnowledgeSourcesDocument.self, from: actual)
            try decoded.validate()
            return KnowledgeSourcesSnapshot(sources: decoded.sources, revision: decoded.revision, established: true)
        } catch { throw KnowledgeSourceError.uncertainWrite }
    }

    // MARK: Pure mutation logic (exposed for tests)

    static func apply(_ mutation: KnowledgeSourceMutation, to document: KnowledgeSourcesDocument) throws -> KnowledgeSourcesDocument {
        guard mutation.expectedRevision == document.revision, document.revision < Int.max else { throw KnowledgeSourceError.conflict }
        var document = document
        switch mutation {
        case .add(let source, _):
            try source.validate()
            guard document.sources.count < KnowledgeSourceLimits.maxSources else {
                throw KnowledgeSourceError.capacityExceeded("最多登记 \(KnowledgeSourceLimits.maxSources) 个来源")
            }
            guard !document.sources.contains(where: { $0.id == source.id }) else { throw KnowledgeSourceError.duplicateIdentity }
            if let rejection = KnowledgeSourceOverlap.rejection(candidate: source.path, existing: document.sources) { throw rejection }
            document.sources.append(source)
        case .remove(let id, _):
            guard document.sources.contains(where: { $0.id == id }) else { throw KnowledgeSourceError.notFound }
            document.sources.removeAll { $0.id == id }
        case .rename(let id, let name, _):
            guard let index = document.sources.firstIndex(where: { $0.id == id }) else { throw KnowledgeSourceError.notFound }
            guard let clean = KnowledgeSource.validName(name) else {
                throw KnowledgeSourceError.invalidInput("显示名必填，最多 \(KnowledgeSourceLimits.nameCharacters) 个字符，且不能含换行。")
            }
            document.sources[index].displayName = clean
        case .setEnabled(let id, let enabled, _):
            guard let index = document.sources.firstIndex(where: { $0.id == id }) else { throw KnowledgeSourceError.notFound }
            document.sources[index].isEnabled = enabled
        }
        document.revision += 1
        return document
    }
}
