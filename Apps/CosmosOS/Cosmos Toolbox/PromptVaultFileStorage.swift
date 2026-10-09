import Foundation
import Darwin

nonisolated enum PromptStorageStage: Sendable, Equatable { case read, encode, backup, backupReadBack, replace, readBack }

nonisolated final class PromptVaultFileStorage: @unchecked Sendable {
    let root: URL
    private let queue = DispatchQueue(label: "cosmos.prompt-vault.storage")
    private let hook: @Sendable (PromptStorageStage) throws -> Void
    var primaryURL: URL { root.appendingPathComponent("templates.json") }
    var backupURL: URL { root.appendingPathComponent("templates.backup.json") }
    static func productionRoot() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false)
            .appendingPathComponent("Cosmos OS/PromptVault", isDirectory: true)
    }
    init(root: URL, hook: @escaping @Sendable (PromptStorageStage) throws -> Void = { _ in }) {
        self.root = root; self.hook = hook
    }
    func load() async throws -> [PromptTemplate] {
        try await perform { try self.readDocument().document.templates }
    }
    func save(_ template: PromptTemplate, expectedRevision: Int?) async throws -> [PromptTemplate] {
        try await perform { try self.transact(template, expectedRevision: expectedRevision) }
    }
    private func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try operation()) }
                catch let error as PromptVaultError { continuation.resume(throwing: error) }
                catch { continuation.resume(throwing: PromptVaultError.storage(error.localizedDescription)) }
            }
        }
    }
    private func kind(_ url: URL) throws -> mode_t? {
        var info = stat()
        if lstat(url.path, &info) == 0 { return info.st_mode & S_IFMT }
        if errno == ENOENT { return nil }
        throw PromptVaultError.storage(String(cString: strerror(errno)))
    }
    private func checkParents(create: Bool) throws -> Bool {
        guard root.isFileURL, root.path.hasPrefix("/"),
              !root.path.split(separator: "/").contains("..") else { throw PromptVaultError.unsafePath }
        var path = URL(fileURLWithPath: "/", isDirectory: true)
        for component in root.path.split(separator: "/") {
            path.appendPathComponent(String(component), isDirectory: true)
            if let type = try kind(path) {
                guard type == S_IFDIR else { throw PromptVaultError.unsafePath }
            } else if create {
                if mkdir(path.path, 0o700) != 0, errno != EEXIST {
                    throw PromptVaultError.storage(String(cString: strerror(errno)))
                }
                guard try kind(path) == S_IFDIR else { throw PromptVaultError.unsafePath }
            } else { return false }
        }
        return true
    }
    private func read(_ url: URL) throws -> Data? {
        guard let type = try kind(url) else { return nil }
        guard type == S_IFREG else { throw PromptVaultError.unsafePath }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw PromptVaultError.storage(String(cString: strerror(errno))) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw PromptVaultError.unsafePath }
        // Reject rather than truncate a library too large for this first-phase editor.
        guard info.st_size <= 16 * 1024 * 1024 else { throw PromptVaultError.storage("文件超过 16 MiB 限制，不会截断") }
        let data = try handle.read(upToCount: 16 * 1024 * 1024 + 1) ?? Data()
        guard data.count <= 16 * 1024 * 1024, data.count == info.st_size else { throw PromptVaultError.conflict }
        return data
    }
    private func readDocument() throws -> (document: PromptVaultDocument, raw: Data?) {
        try hook(.read)
        guard try checkParents(create: false) else { return (PromptVaultDocument(), nil) }
        // Check even an unused backup's file type; never overwrite a linked target.
        if let type = try kind(backupURL), type != S_IFREG { throw PromptVaultError.unsafePath }
        guard let raw = try read(primaryURL) else {
            if try kind(backupURL) != nil { throw PromptVaultError.missingPrimaryWithBackup }
            return (PromptVaultDocument(), nil)
        }
        guard String(data: raw, encoding: .utf8) != nil, !raw.contains(0) else { throw PromptVaultError.corruptData }
        let document: PromptVaultDocument
        do { document = try JSONDecoder().decode(PromptVaultDocument.self, from: raw) }
        catch { throw PromptVaultError.corruptData }
        try document.validate()
        return (document, raw)
    }
    private func writeAtomic(_ data: Data, to target: URL) throws {
        if let type = try kind(target), type != S_IFREG { throw PromptVaultError.unsafePath }
        let temporary = root.appendingPathComponent(".prompt-write-" + UUID().uuidString)
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw PromptVaultError.storage(String(cString: strerror(errno))) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close(); try? FileManager.default.removeItem(at: temporary) }
        try handle.write(contentsOf: data)
        try handle.synchronize()
        try handle.close()
        _ = try checkParents(create: false)
        if let type = try kind(target), type != S_IFREG { throw PromptVaultError.unsafePath }
        guard rename(temporary.path, target.path) == 0 else {
            throw PromptVaultError.storage(String(cString: strerror(errno)))
        }
    }
    private func transact(_ proposed: PromptTemplate, expectedRevision: Int?) throws -> [PromptTemplate] {
        let input = try proposed.validated()
        _ = try checkParents(create: true)
        let lockURL = root.appendingPathComponent(".prompt-vault.lock")
        if let type = try kind(lockURL), type != S_IFREG { throw PromptVaultError.unsafePath }
        let fd = open(lockURL.path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw PromptVaultError.storage(String(cString: strerror(errno))) }
        defer { flock(fd, LOCK_UN); close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw PromptVaultError.storage("无法取得提示词库写锁") }
        let loaded = try readDocument()
        var candidate = loaded.document
        var saved = input
        if let index = candidate.templates.firstIndex(where: { $0.id == input.id }) {
            let current = candidate.templates[index]
            guard expectedRevision == current.revision, current.revision < Int.max else { throw PromptVaultError.conflict }
            saved = PromptTemplate(id: current.id, name: input.name, body: input.body, category: input.category,
                isFavorite: input.isFavorite, isArchived: input.isArchived, createdAt: current.createdAt,
                updatedAt: Date(), revision: current.revision + 1)
            candidate.templates[index] = saved
        } else {
            guard expectedRevision == nil else { throw PromptVaultError.conflict }
            saved.revision = 1; saved.updatedAt = saved.createdAt
            candidate.templates.append(saved)
        }
        try hook(.encode)
        let encoded = try JSONEncoder().encode(candidate)
        guard encoded.count <= 16 * 1024 * 1024 else { throw PromptVaultError.storage("文件超过 16 MiB 限制，未保存") }
        guard try read(primaryURL) == loaded.raw else { throw PromptVaultError.conflict }
        if let raw = loaded.raw {
            try hook(.backup)
            try writeAtomic(raw, to: backupURL)
            try hook(.backupReadBack)
            guard try read(backupURL) == raw else { throw PromptVaultError.storage("备份读回不一致") }
        }
        guard try read(primaryURL) == loaded.raw else { throw PromptVaultError.conflict }
        try hook(.replace)
        do {
            try writeAtomic(encoded, to: primaryURL)
            try hook(.readBack)
            guard let actual = try read(primaryURL), actual == encoded else { throw PromptVaultError.uncertainWrite }
            let decoded = try JSONDecoder().decode(PromptVaultDocument.self, from: actual)
            try decoded.validate()
            return decoded.templates
        } catch { throw PromptVaultError.uncertainWrite }
    }
}
