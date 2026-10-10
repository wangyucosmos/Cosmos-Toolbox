import Foundation
import Darwin

nonisolated enum AIWorkspaceHandoffStorageStage: Sendable, Equatable { case read, encode, backup, backupReadBack, replace, readBack }

/// Module-local safety primitives follow LearningFileStorage: serial I/O, flock, verified backup,
/// sibling temporary file + fsync + atomic rename, then exact read-back. No automatic recovery.
nonisolated final class AIWorkspaceHandoffFileStorage: @unchecked Sendable {
    let root: URL
    private let queue = DispatchQueue(label: "cosmos.ai-workspace.handoff-storage")
    private let hook: @Sendable (AIWorkspaceHandoffStorageStage) throws -> Void
    var primaryURL: URL { root.appendingPathComponent("handoffs.json") }
    var backupURL: URL { root.appendingPathComponent("handoffs.backup.json") }
    private var lockURL: URL { root.appendingPathComponent(".handoffs.lock") }

    static func productionRoot() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false)
            .appendingPathComponent("Cosmos OS/AIWorkspace", isDirectory: true)
    }

    init(root: URL, hook: @escaping @Sendable (AIWorkspaceHandoffStorageStage) throws -> Void = { _ in }) {
        self.root = root; self.hook = hook
    }

    func load() async throws -> [AIWorkspaceHandoffRecord] {
        try await perform { try self.readDocument().document.records }
    }

    func append(_ record: AIWorkspaceHandoffRecord) async throws -> [AIWorkspaceHandoffRecord] {
        try await perform { try self.transact(record) }
    }

    private func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try operation()) }
                catch let error as AIWorkspaceHandoffError { continuation.resume(throwing: error) }
                catch { continuation.resume(throwing: AIWorkspaceHandoffError.storage(error.localizedDescription)) }
            }
        }
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }
    private static func makeDecoder() -> JSONDecoder { JSONDecoder() }

    private func kind(_ url: URL) throws -> mode_t? {
        var info = stat()
        if lstat(url.path, &info) == 0 { return info.st_mode & S_IFMT }
        if errno == ENOENT { return nil }
        throw AIWorkspaceHandoffError.storage(String(cString: strerror(errno)))
    }

    private func checkParents(create: Bool) throws -> Bool {
        guard root.isFileURL, root.path.hasPrefix("/"),
              !root.path.split(separator: "/").contains("..") else { throw AIWorkspaceHandoffError.unsafePath }
        var path = URL(fileURLWithPath: "/", isDirectory: true)
        for component in root.path.split(separator: "/") {
            path.appendPathComponent(String(component), isDirectory: true)
            if let type = try kind(path) {
                guard type == S_IFDIR else { throw AIWorkspaceHandoffError.unsafePath }
            } else if create {
                if mkdir(path.path, 0o700) != 0, errno != EEXIST {
                    throw AIWorkspaceHandoffError.storage(String(cString: strerror(errno)))
                }
                guard try kind(path) == S_IFDIR else { throw AIWorkspaceHandoffError.unsafePath }
            } else { return false }
        }
        return true
    }

    private func read(_ url: URL) throws -> Data? {
        guard let type = try kind(url) else { return nil }
        guard type == S_IFREG else { throw AIWorkspaceHandoffError.unsafePath }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw AIWorkspaceHandoffError.storage(String(cString: strerror(errno))) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw AIWorkspaceHandoffError.unsafePath }
        // Reject rather than truncate a library larger than the first-phase limit.
        guard info.st_size <= 16 * 1024 * 1024 else {
            throw AIWorkspaceHandoffError.storage("文件超过 16 MiB 限制，不会截断")
        }
        let data = try handle.read(upToCount: 16 * 1024 * 1024 + 1) ?? Data()
        guard data.count <= 16 * 1024 * 1024, data.count == info.st_size else {
            throw AIWorkspaceHandoffError.conflict
        }
        return data
    }

    private func readDocument() throws -> (document: AIWorkspaceHandoffDocument, raw: Data?) {
        try hook(.read)
        guard try checkParents(create: false) else { return (AIWorkspaceHandoffDocument(), nil) }
        // Check even an unused backup's file type; never overwrite a linked target.
        if let type = try kind(backupURL), type != S_IFREG { throw AIWorkspaceHandoffError.unsafePath }
        guard let raw = try read(primaryURL) else {
            if try kind(backupURL) != nil { throw AIWorkspaceHandoffError.missingPrimaryWithBackup }
            return (AIWorkspaceHandoffDocument(), nil)
        }
        guard String(data: raw, encoding: .utf8) != nil, !raw.contains(0) else { throw AIWorkspaceHandoffError.corruptData }
        let document: AIWorkspaceHandoffDocument
        do { document = try Self.makeDecoder().decode(AIWorkspaceHandoffDocument.self, from: raw) }
        catch { throw AIWorkspaceHandoffError.corruptData }
        do { try document.validate() }
        catch { throw AIWorkspaceHandoffError.corruptData }
        return (document, raw)
    }

    /// Writes a sibling temporary file and renames it over `target`. Every failure thrown from here
    /// happens strictly before the rename, so the target is untouched when this throws.
    private func writeAtomic(_ data: Data, to target: URL) throws {
        if let type = try kind(target), type != S_IFREG { throw AIWorkspaceHandoffError.unsafePath }
        let temporary = root.appendingPathComponent(".handoff-write-" + UUID().uuidString)
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw AIWorkspaceHandoffError.writeFailed(String(cString: strerror(errno))) }
        var closed = false
        defer { if !closed { close(fd) }; unlink(temporary.path) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch { throw AIWorkspaceHandoffError.writeFailed(error.localizedDescription) }
        closed = true
        guard close(fd) == 0 else { throw AIWorkspaceHandoffError.writeFailed(String(cString: strerror(errno))) }
        _ = try checkParents(create: false)
        if let type = try kind(target), type != S_IFREG { throw AIWorkspaceHandoffError.unsafePath }
        guard rename(temporary.path, target.path) == 0 else {
            throw AIWorkspaceHandoffError.writeFailed(String(cString: strerror(errno)))
        }
    }

    /// Maps plain I/O failures before the primary replacement to a retryable error.
    private func beforeReplace<T>(_ body: () throws -> T) throws -> T {
        do { return try body() }
        catch AIWorkspaceHandoffError.storage(let reason) { throw AIWorkspaceHandoffError.writeFailed(reason) }
        catch let error as AIWorkspaceHandoffError { throw error }
        catch { throw AIWorkspaceHandoffError.writeFailed(error.localizedDescription) }
    }

    // MARK: Transaction

    private func transact(_ record: AIWorkspaceHandoffRecord) throws -> [AIWorkspaceHandoffRecord] {
        let lockFD: Int32 = try beforeReplace {
            _ = try checkParents(create: true)
            if let type = try kind(lockURL), type != S_IFREG { throw AIWorkspaceHandoffError.unsafePath }
            let fd = open(lockURL.path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
            guard fd >= 0 else { throw AIWorkspaceHandoffError.storage(String(cString: strerror(errno))) }
            guard flock(fd, LOCK_EX) == 0 else {
                close(fd); throw AIWorkspaceHandoffError.storage("无法取得交接记录库写锁")
            }
            return fd
        }
        defer { flock(lockFD, LOCK_UN); close(lockFD) }

        let latest = try readDocument()
        if let existing = latest.document.records.first(where: { $0.id == record.id }) {
            guard try Self.makeEncoder().encode(existing) == Self.makeEncoder().encode(record) else { throw AIWorkspaceHandoffError.conflict }
            return latest.document.records
        }
        let prepared: (encoded: Data, raw: Data?) = try beforeReplace {
            // Latest disk state, read under the lock; the mutation is validated against it.
            let loaded = try readDocument()
            var candidate = loaded.document
            candidate.records.append(record)
            try candidate.validate()
            try hook(.encode)
            let encoded = try Self.makeEncoder().encode(candidate)
            guard encoded.count <= 16 * 1024 * 1024 else {
                throw AIWorkspaceHandoffError.writeFailed("交接记录库将超过 16 MiB 上限；未保存也未截断。")
            }
            guard try read(primaryURL) == loaded.raw else { throw AIWorkspaceHandoffError.conflict }
            if let raw = loaded.raw {
                try hook(.backup)
                try writeAtomic(raw, to: backupURL)
                try hook(.backupReadBack)
                guard try read(backupURL) == raw else { throw AIWorkspaceHandoffError.writeFailed("备份读回不一致") }
            }
            guard try read(primaryURL) == loaded.raw else { throw AIWorkspaceHandoffError.conflict }
            try hook(.replace)
            return (encoded, loaded.raw)
        }

        // A throw from here up to and including the rename leaves the primary file untouched.
        try beforeReplace { try writeAtomic(prepared.encoded, to: primaryURL) }

        // The primary was replaced. Anything that cannot be confirmed from here is uncertain.
        do {
            try hook(.readBack)
            guard let actual = try read(primaryURL), actual == prepared.encoded else {
                throw AIWorkspaceHandoffError.uncertainWrite
            }
            let decoded = try Self.makeDecoder().decode(AIWorkspaceHandoffDocument.self, from: actual)
            try decoded.validate()
            return decoded.records
        } catch { throw AIWorkspaceHandoffError.uncertainWrite }
    }

}
