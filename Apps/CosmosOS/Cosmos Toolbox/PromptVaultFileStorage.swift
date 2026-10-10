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
        try await perform {
            let input = try template.validated()
            return try self.transact { document, now in
                try Self.applySave(input, expectedRevision: expectedRevision, to: &document, now: now)
            }.templates
        }
    }
    /// Restores a stored snapshot (looked up in the latest on-disk document, never taken from the caller)
    /// as a new current content version. Identical content is a no-op: nothing is written.
    func restoreVersion(templateID: UUID, versionID: UUID, expectedRevision: Int) async throws -> PromptRestoreResult {
        try await perform {
            let result = try self.transact { document, now in
                try Self.applyRestore(templateID: templateID, versionID: versionID,
                    expectedRevision: expectedRevision, to: &document, now: now)
            }
            return PromptRestoreResult(templates: result.templates, changed: result.wrote)
        }
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
    /// Returns false when the mutation decided that nothing needs to be written.
    private typealias Mutation = (inout PromptVaultDocument, Date) throws -> Bool

    private static func requireCapacity(_ template: PromptTemplate, adding count: Int) throws {
        guard template.versions.count + count <= PromptVaultDocument.maxVersionsPerTemplate else {
            throw PromptVaultError.capacityExceeded("该模板已达 \(PromptVaultDocument.maxVersionsPerTemplate) 个内容版本上限")
        }
    }
    /// Builds the saved template from the latest on-disk record: the draft contributes only name, body,
    /// category, favorite and archive flags. History is rebuilt here, in the same publish as the content.
    private static func updated(_ current: PromptTemplate, with input: PromptTemplate, now: Date) throws -> PromptTemplate {
        guard current.revision < Int.max else { throw PromptVaultError.conflict }
        var saved = PromptTemplate(id: current.id, name: input.name, body: input.body, category: input.category,
            isFavorite: input.isFavorite, isArchived: input.isArchived, createdAt: current.createdAt,
            updatedAt: now, revision: current.revision + 1, versions: current.versions)
        guard !current.sameContent(as: saved) else { return saved }   // favorite/archive/no-op: no content version
        try requireCapacity(current, adding: current.versions.isEmpty ? 2 : 1)
        if saved.versions.isEmpty {
            // First content edit of a pre-history template: keep the old content as the baseline.
            saved.versions = [PromptVersion(number: 1, name: current.name, body: current.body, category: current.category,
                recordedAt: current.updatedAt, isUpgradeBaseline: true)]
        }
        saved.versions.append(PromptVersion(number: (saved.versions.last?.number ?? 0) + 1, name: saved.name,
            body: saved.body, category: saved.category, recordedAt: now))
        return saved
    }
    private static func applySave(_ input: PromptTemplate, expectedRevision: Int?,
                                  to document: inout PromptVaultDocument, now: Date) throws -> Bool {
        if let index = document.templates.firstIndex(where: { $0.id == input.id }) {
            guard expectedRevision == document.templates[index].revision else { throw PromptVaultError.conflict }
            document.templates[index] = try updated(document.templates[index], with: input, now: now)
        } else {
            guard expectedRevision == nil else { throw PromptVaultError.conflict }
            var created = input
            created.revision = 1; created.updatedAt = created.createdAt
            created.versions = [PromptVersion(number: 1, name: created.name, body: created.body,
                category: created.category, recordedAt: now)]
            document.templates.append(created)
        }
        return true
    }
    private static func applyRestore(templateID: UUID, versionID: UUID, expectedRevision: Int,
                                     to document: inout PromptVaultDocument, now: Date) throws -> Bool {
        guard let index = document.templates.firstIndex(where: { $0.id == templateID }),
              document.templates[index].revision == expectedRevision,
              let version = document.templates[index].versions.first(where: { $0.id == versionID }) else {
            throw PromptVaultError.conflict
        }
        let current = document.templates[index]
        var input = current
        input.name = version.name; input.body = version.body; input.category = version.category
        let target = try input.validated()
        guard !current.sameContent(as: target) else { return false }
        document.templates[index] = try updated(current, with: target, now: now)
        return true
    }
    private func transact(_ mutation: Mutation) throws -> (templates: [PromptTemplate], wrote: Bool) {
        _ = try checkParents(create: true)
        let lockURL = root.appendingPathComponent(".prompt-vault.lock")
        if let type = try kind(lockURL), type != S_IFREG { throw PromptVaultError.unsafePath }
        let fd = open(lockURL.path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw PromptVaultError.storage(String(cString: strerror(errno))) }
        defer { flock(fd, LOCK_UN); close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw PromptVaultError.storage("无法取得提示词库写锁") }
        let loaded = try readDocument()
        var candidate = loaded.document
        guard try mutation(&candidate, Date()) else { return (loaded.document.templates, false) }
        candidate.schemaVersion = PromptVaultDocument.currentSchemaVersion
        try candidate.validate()
        try hook(.encode)
        let encoded = try JSONEncoder().encode(candidate)
        guard encoded.count <= 16 * 1024 * 1024 else {
            throw PromptVaultError.capacityExceeded("提示词库（含全部历史版本）将超过 16 MiB 限制")
        }
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
            return (decoded.templates, true)
        } catch { throw PromptVaultError.uncertainWrite }
    }
}

nonisolated struct PromptRestoreResult: Sendable {
    let templates: [PromptTemplate]
    /// False when the chosen snapshot equals the current content: no new version, no write.
    let changed: Bool
}
