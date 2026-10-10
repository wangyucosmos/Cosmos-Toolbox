import Foundation
import Darwin

nonisolated enum ProjectsStorageStage: Sendable { case read, encode, backup, backupReadBack, replace, readBack }
nonisolated enum ProjectsMutation: Sendable { case save(PersonalProject, expectedRevision: Int?) }

/// Module-local adaptation of the Learning storage transaction; no shared business writes.
nonisolated final class ProjectsFileStorage: @unchecked Sendable {
    let root: URL
    private let queue = DispatchQueue(label: "cosmos.projects.storage")
    private let hook: @Sendable (ProjectsStorageStage) throws -> Void
    private let clock: @Sendable () -> Date
    var primaryURL: URL { root.appendingPathComponent("projects.json") }
    var backupURL: URL { root.appendingPathComponent("projects.backup.json") }
    private var lockURL: URL { root.appendingPathComponent(".projects.lock") }
    static func productionRoot() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("Cosmos OS/Projects", isDirectory: true)
    }
    init(root: URL, clock: @escaping @Sendable () -> Date = { Date() }, hook: @escaping @Sendable (ProjectsStorageStage) throws -> Void = { _ in }) {
        self.root = root; self.clock = clock; self.hook = hook
    }
    func load() async throws -> ProjectsSnapshot {
        try await perform {
            let loaded = try self.readDocument()
            return ProjectsSnapshot(projects: loaded.document.projects, established: loaded.raw != nil)
        }
    }
    func apply(_ mutation: ProjectsMutation) async throws -> ProjectsSnapshot { try await perform { try self.transact(mutation) } }
    private func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try operation()) }
                catch let error as ProjectsError { continuation.resume(throwing: error) }
                catch { continuation.resume(throwing: ProjectsError.storage(error.localizedDescription)) }
            }
        }
    }
    private static func makeEncoder() -> JSONEncoder { ProjectsCoding.encoder() }
    private static func makeDecoder() -> JSONDecoder { ProjectsCoding.decoder() }
    private func kind(_ url: URL) throws -> mode_t? {
        var info = stat()
        if lstat(url.path, &info) == 0 { return info.st_mode & S_IFMT }
        if errno == ENOENT { return nil }
        throw ProjectsError.storage(String(cString: strerror(errno)))
    }

    private func checkParents(create: Bool) throws -> Bool {
        guard root.isFileURL, root.path.hasPrefix("/"),
              !root.path.split(separator: "/").contains("..") else { throw ProjectsError.unsafePath }
        var path = URL(fileURLWithPath: "/", isDirectory: true)
        for component in root.path.split(separator: "/") {
            path.appendPathComponent(String(component), isDirectory: true)
            if let type = try kind(path) {
                guard type == S_IFDIR else { throw ProjectsError.unsafePath }
            } else if create {
                if mkdir(path.path, 0o700) != 0, errno != EEXIST {
                    throw ProjectsError.storage(String(cString: strerror(errno)))
                }
                guard try kind(path) == S_IFDIR else { throw ProjectsError.unsafePath }
            } else { return false }
        }
        return true
    }

    private func read(_ url: URL) throws -> Data? {
        guard let type = try kind(url) else { return nil }
        guard type == S_IFREG else { throw ProjectsError.unsafePath }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw ProjectsError.storage(String(cString: strerror(errno))) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw ProjectsError.unsafePath }
        // Reject rather than truncate a library larger than the first-phase limit.
        guard info.st_size <= ProjectsLimits.documentBytes else {
            throw ProjectsError.storage("文件超过 16 MiB 限制，不会截断")
        }
        let data = try handle.read(upToCount: ProjectsLimits.documentBytes + 1) ?? Data()
        guard data.count <= ProjectsLimits.documentBytes, data.count == info.st_size else {
            throw ProjectsError.conflict
        }
        return data
    }

    private func readDocument() throws -> (document: ProjectsDocument, raw: Data?) {
        try hook(.read)
        guard try checkParents(create: false) else { return (ProjectsDocument(), nil) }
        // Check even an unused backup's file type; never overwrite a linked target.
        if let type = try kind(backupURL), type != S_IFREG { throw ProjectsError.unsafePath }
        guard let raw = try read(primaryURL) else {
            if try kind(backupURL) != nil { throw ProjectsError.missingPrimaryWithBackup }
            return (ProjectsDocument(), nil)
        }
        guard String(data: raw, encoding: .utf8) != nil, !raw.contains(0) else { throw ProjectsError.corruptData }
        let document: ProjectsDocument
        do { document = try Self.makeDecoder().decode(ProjectsDocument.self, from: raw) }
        catch { throw ProjectsError.corruptData }
        do { try document.validate() }
        catch ProjectsError.invalidInput { throw ProjectsError.corruptData }
        return (document, raw)
    }

    /// Writes a sibling temporary file and renames it over `target`. Every failure thrown from here
    /// happens strictly before the rename, so the target is untouched when this throws.
    private func writeAtomic(_ data: Data, to target: URL) throws {
        if let type = try kind(target), type != S_IFREG { throw ProjectsError.unsafePath }
        let temporary = root.appendingPathComponent(".projects-write-" + UUID().uuidString)
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw ProjectsError.writeFailed(String(cString: strerror(errno))) }
        var closed = false
        defer { if !closed { close(fd) }; unlink(temporary.path) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch { throw ProjectsError.writeFailed(error.localizedDescription) }
        closed = true
        guard close(fd) == 0 else { throw ProjectsError.writeFailed(String(cString: strerror(errno))) }
        _ = try checkParents(create: false)
        if let type = try kind(target), type != S_IFREG { throw ProjectsError.unsafePath }
        guard rename(temporary.path, target.path) == 0 else {
            throw ProjectsError.writeFailed(String(cString: strerror(errno)))
        }
    }

    /// Maps plain I/O failures before the primary replacement to a retryable error.
    private func beforeReplace<T>(_ body: () throws -> T) throws -> T {
        do { return try body() }
        catch ProjectsError.storage(let reason) { throw ProjectsError.writeFailed(reason) }
        catch let error as ProjectsError { throw error }
        catch { throw ProjectsError.writeFailed(error.localizedDescription) }
    }

    // MARK: Transaction

    private func transact(_ mutation: ProjectsMutation) throws -> ProjectsSnapshot {
        let lockFD: Int32 = try beforeReplace {
            _ = try checkParents(create: true)
            if let type = try kind(lockURL), type != S_IFREG { throw ProjectsError.unsafePath }
            let fd = open(lockURL.path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
            guard fd >= 0 else { throw ProjectsError.storage(String(cString: strerror(errno))) }
            guard flock(fd, LOCK_EX) == 0 else {
                close(fd); throw ProjectsError.storage("无法取得学习库写锁")
            }
            return fd
        }
        defer { flock(lockFD, LOCK_UN); close(lockFD) }

        let prepared: (encoded: Data, raw: Data?) = try beforeReplace {
            // Latest disk state, read under the lock; the mutation is validated against it.
            let loaded = try readDocument()
            let candidate = try Self.apply(mutation, to: loaded.document, now: clock())
            try candidate.validate()
            try hook(.encode)
            let encoded = try Self.makeEncoder().encode(candidate)
            guard encoded.count <= ProjectsLimits.documentBytes else {
                throw ProjectsError.invalidInput("学习库将超过 16 MiB 上限；未保存也未截断。")
            }
            guard try read(primaryURL) == loaded.raw else { throw ProjectsError.conflict }
            if let raw = loaded.raw {
                try hook(.backup)
                try writeAtomic(raw, to: backupURL)
                try hook(.backupReadBack)
                guard try read(backupURL) == raw else { throw ProjectsError.writeFailed("备份读回不一致") }
            }
            guard try read(primaryURL) == loaded.raw else { throw ProjectsError.conflict }
            try hook(.replace)
            return (encoded, loaded.raw)
        }

        // A throw from here up to and including the rename leaves the primary file untouched.
        try beforeReplace { try writeAtomic(prepared.encoded, to: primaryURL) }

        // The primary was replaced. Anything that cannot be confirmed from here is uncertain.
        do {
            try hook(.readBack)
            guard let actual = try read(primaryURL), actual == prepared.encoded else {
                throw ProjectsError.uncertainWrite
            }
            let decoded = try Self.makeDecoder().decode(ProjectsDocument.self, from: actual)
            try decoded.validate()
            return ProjectsSnapshot(projects: decoded.projects, established: true)
        } catch { throw ProjectsError.uncertainWrite }
    }

    static func apply(_ mutation: ProjectsMutation, to document: ProjectsDocument, now: Date) throws -> ProjectsDocument {
        var document = document
        switch mutation {
        case .save(var proposed, let expected):
            try proposed.validate()
            if let index = document.projects.firstIndex(where: { $0.id == proposed.id }) {
                let old = document.projects[index]
                guard expected == old.revision, old.revision < Int.max else { throw ProjectsError.conflict }
                // Saved progress and references are append-only; original history cannot be rewritten.
                guard proposed.progress.count >= old.progress.count, proposed.references.count >= old.references.count,
                      try makeEncoder().encode(Array(proposed.progress.prefix(old.progress.count))) == makeEncoder().encode(old.progress),
                      try makeEncoder().encode(Array(proposed.references.prefix(old.references.count))) == makeEncoder().encode(old.references) else { throw ProjectsError.invalidInput("已保存进展和引用必须保留原文，不能改写或删除。") }
                proposed.createdAt = old.createdAt; proposed.updatedAt = now; proposed.revision = old.revision + 1
                document.projects[index] = proposed
            } else {
                guard expected == nil else { throw ProjectsError.conflict }
                proposed.revision = 1; proposed.updatedAt = proposed.createdAt
                document.projects.append(proposed)
            }
        }
        return document
    }
}
