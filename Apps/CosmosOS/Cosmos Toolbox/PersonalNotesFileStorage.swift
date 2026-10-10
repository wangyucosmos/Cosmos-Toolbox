import Foundation
import Darwin

nonisolated enum PersonalNotesStorageStage: Sendable, Equatable { case read, encode, backup, backupReadBack, replace, readBack }

nonisolated enum PersonalNotesMutation: Sendable {
    /// `newReferences` 与正文/历史在同一次事务中发布；`expectedRevision == nil` 表示新建。
    case save(PersonalNote, newReferences: [NoteReference], expectedRevision: Int?)
    case restore(noteID: UUID, versionID: UUID, expectedRevision: Int)
}

nonisolated struct PersonalNotesApplyResult: Sendable {
    let snapshot: PersonalNotesSnapshot
    /// false：所选历史内容与当前完全相同，未写盘、未新增版本。
    let changed: Bool
}

/// 独立个人笔记存储：缺库只读零初始化、结构校验、协作 flock 写锁、写前精确字节备份、
/// 原子 rename 发布与读回校验。当前正文、内容历史与引用由同一次写入发布，失败不留半成品。
nonisolated final class PersonalNotesFileStorage: @unchecked Sendable {
    let root: URL
    private let queue = DispatchQueue(label: "cosmos.personal-notes.storage")
    private let hook: @Sendable (PersonalNotesStorageStage) throws -> Void
    private let clock: @Sendable () -> Date
    var primaryURL: URL { root.appendingPathComponent("notes.json") }
    var backupURL: URL { root.appendingPathComponent("notes.backup.json") }
    private var lockURL: URL { root.appendingPathComponent(".notes.lock") }

    static func productionRoot() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false)
            .appendingPathComponent("Cosmos OS/PersonalNotes", isDirectory: true)
    }
    init(root: URL, clock: @escaping @Sendable () -> Date = { Date() },
         hook: @escaping @Sendable (PersonalNotesStorageStage) throws -> Void = { _ in }) {
        self.root = root; self.clock = clock; self.hook = hook
    }

    func load() async throws -> PersonalNotesSnapshot {
        try await perform {
            let loaded = try self.readDocument()
            return PersonalNotesSnapshot(notes: loaded.document.notes, established: loaded.raw != nil)
        }
    }
    func apply(_ mutation: PersonalNotesMutation) async throws -> PersonalNotesApplyResult {
        try await perform { try self.transact(mutation) }
    }

    private func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try operation()) }
                catch let error as PersonalNotesError { continuation.resume(throwing: error) }
                catch { continuation.resume(throwing: PersonalNotesError.storage(error.localizedDescription)) }
            }
        }
    }

    // MARK: File primitives

    private func kind(_ url: URL) throws -> mode_t? {
        var info = stat()
        if lstat(url.path, &info) == 0 { return info.st_mode & S_IFMT }
        if errno == ENOENT { return nil }
        throw PersonalNotesError.storage(String(cString: strerror(errno)))
    }
    private func checkParents(create: Bool) throws -> Bool {
        guard root.isFileURL, root.path.hasPrefix("/"), !root.path.contains("\0"),
              !root.path.split(separator: "/").contains("..") else { throw PersonalNotesError.unsafePath }
        var path = URL(fileURLWithPath: "/", isDirectory: true)
        for component in root.path.split(separator: "/") {
            path.appendPathComponent(String(component), isDirectory: true)
            if let type = try kind(path) {
                guard type == S_IFDIR else { throw PersonalNotesError.unsafePath }
            } else if create {
                if mkdir(path.path, 0o700) != 0, errno != EEXIST {
                    throw PersonalNotesError.storage(String(cString: strerror(errno)))
                }
                guard try kind(path) == S_IFDIR else { throw PersonalNotesError.unsafePath }
            } else { return false }
        }
        return true
    }
    private func read(_ url: URL) throws -> Data? {
        guard let type = try kind(url) else { return nil }
        guard type == S_IFREG else { throw PersonalNotesError.unsafePath }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw PersonalNotesError.storage(String(cString: strerror(errno))) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw PersonalNotesError.unsafePath }
        // 拒绝而不是截断超过上限的库。
        guard info.st_size <= PersonalNotesLimits.documentBytes else {
            throw PersonalNotesError.storage("文件超过 16 MiB 限制，不会截断")
        }
        let data = try handle.read(upToCount: PersonalNotesLimits.documentBytes + 1) ?? Data()
        guard data.count <= PersonalNotesLimits.documentBytes, data.count == info.st_size else { throw PersonalNotesError.conflict }
        return data
    }
    private func readDocument() throws -> (document: PersonalNotesDocument, raw: Data?) {
        try hook(.read)
        guard try checkParents(create: false) else { return (PersonalNotesDocument(), nil) }
        // 即便备份未使用，也检查其文件类型；不覆盖链接目标。
        if let type = try kind(backupURL), type != S_IFREG { throw PersonalNotesError.unsafePath }
        guard let raw = try read(primaryURL) else {
            if try kind(backupURL) != nil { throw PersonalNotesError.missingPrimaryWithBackup }
            return (PersonalNotesDocument(), nil)
        }
        guard String(data: raw, encoding: .utf8) != nil, !raw.contains(0) else { throw PersonalNotesError.corruptData }
        let document: PersonalNotesDocument
        do { document = try PersonalNotesCoding.decoder().decode(PersonalNotesDocument.self, from: raw) }
        catch { throw PersonalNotesError.corruptData }
        try document.validate()
        return (document, raw)
    }
    /// 兄弟临时文件 + rename；所有失败都发生在 rename 之前，目标保持不变。
    private func writeAtomic(_ data: Data, to target: URL) throws {
        if let type = try kind(target), type != S_IFREG { throw PersonalNotesError.unsafePath }
        let temporary = root.appendingPathComponent(".notes-write-" + UUID().uuidString)
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw PersonalNotesError.writeFailed(String(cString: strerror(errno))) }
        var closed = false
        defer { if !closed { close(fd) }; unlink(temporary.path) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        do { try handle.write(contentsOf: data); try handle.synchronize() }
        catch { throw PersonalNotesError.writeFailed(error.localizedDescription) }
        closed = true
        guard close(fd) == 0 else { throw PersonalNotesError.writeFailed(String(cString: strerror(errno))) }
        _ = try checkParents(create: false)
        if let type = try kind(target), type != S_IFREG { throw PersonalNotesError.unsafePath }
        guard rename(temporary.path, target.path) == 0 else {
            throw PersonalNotesError.writeFailed(String(cString: strerror(errno)))
        }
    }
    /// 主文件替换之前的普通 I/O 失败映射为可重试错误。
    private func beforeReplace<T>(_ body: () throws -> T) throws -> T {
        do { return try body() }
        catch PersonalNotesError.storage(let reason) { throw PersonalNotesError.writeFailed(reason) }
        catch let error as PersonalNotesError { throw error }
        catch { throw PersonalNotesError.writeFailed(error.localizedDescription) }
    }

    // MARK: Transaction

    private func transact(_ mutation: PersonalNotesMutation) throws -> PersonalNotesApplyResult {
        let lockFD: Int32 = try beforeReplace {
            _ = try checkParents(create: true)
            if let type = try kind(lockURL), type != S_IFREG { throw PersonalNotesError.unsafePath }
            let fd = open(lockURL.path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
            guard fd >= 0 else { throw PersonalNotesError.storage(String(cString: strerror(errno))) }
            guard flock(fd, LOCK_EX) == 0 else { close(fd); throw PersonalNotesError.storage("无法取得个人笔记库写锁") }
            return fd
        }
        defer { flock(lockFD, LOCK_UN); close(lockFD) }

        var unchanged: PersonalNotesApplyResult?
        let prepared: (encoded: Data, raw: Data?)? = try beforeReplace {
            // 在锁内读取最新磁盘状态；历史永远由它生成，不信任旧草稿提交的历史。
            let loaded = try readDocument()
            let applied = try Self.apply(mutation, to: loaded.document, now: clock())
            guard applied.changed else {
                unchanged = PersonalNotesApplyResult(
                    snapshot: PersonalNotesSnapshot(notes: loaded.document.notes, established: loaded.raw != nil), changed: false)
                return nil
            }
            let candidate = applied.document
            try candidate.validate()
            try hook(.encode)
            let encoded = try PersonalNotesCoding.encoder().encode(candidate)
            guard encoded.count <= PersonalNotesLimits.documentBytes else {
                throw PersonalNotesError.capacityExceeded("个人笔记库（含全部历史版本）将超过 16 MiB 限制")
            }
            guard try read(primaryURL) == loaded.raw else { throw PersonalNotesError.conflict }
            if let raw = loaded.raw {
                try hook(.backup)
                try writeAtomic(raw, to: backupURL)
                try hook(.backupReadBack)
                guard try read(backupURL) == raw else { throw PersonalNotesError.writeFailed("备份读回不一致") }
            }
            guard try read(primaryURL) == loaded.raw else { throw PersonalNotesError.conflict }
            try hook(.replace)
            return (encoded, loaded.raw)
        }
        guard let prepared else { return unchanged! }

        // 到 rename 为止的任何抛错都不触及主文件。
        try beforeReplace { try writeAtomic(prepared.encoded, to: primaryURL) }

        // 主文件已替换；此后无法确认的情况一律视为不确定写入。
        do {
            try hook(.readBack)
            guard let actual = try read(primaryURL), actual == prepared.encoded else { throw PersonalNotesError.uncertainWrite }
            let decoded = try PersonalNotesCoding.decoder().decode(PersonalNotesDocument.self, from: actual)
            try decoded.validate()
            return PersonalNotesApplyResult(snapshot: PersonalNotesSnapshot(notes: decoded.notes, established: true), changed: true)
        } catch { throw PersonalNotesError.uncertainWrite }
    }

    // MARK: Pure mutation logic (exposed for tests)

    static func apply(_ mutation: PersonalNotesMutation, to document: PersonalNotesDocument,
                      now: Date) throws -> (document: PersonalNotesDocument, changed: Bool) {
        var document = document
        switch mutation {
        case .save(let draft, let newReferences, let expected):
            let input = try draft.validatedInput()
            if let index = document.notes.firstIndex(where: { $0.id == input.id }) {
                let old = document.notes[index]
                guard expected == old.revision, old.revision < Int.max else { throw PersonalNotesError.conflict }
                document.notes[index] = try updated(old, with: input, newReferences: newReferences, now: now)
            } else {
                guard expected == nil else { throw PersonalNotesError.conflict }
                var created = PersonalNote(id: input.id, title: input.title, body: input.body, category: input.category,
                    isFavorite: input.isFavorite, isArchived: input.isArchived, createdAt: now, updatedAt: now, revision: 1,
                    versions: [NoteVersion(number: 1, title: input.title, body: input.body, category: input.category, recordedAt: now)])
                created.references = try appended(newReferences, to: [], now: now)
                document.notes.append(created)
            }
            return (document, true)
        case .restore(let noteID, let versionID, let expected):
            guard let index = document.notes.firstIndex(where: { $0.id == noteID }),
                  document.notes[index].revision == expected,
                  let version = document.notes[index].versions.first(where: { $0.id == versionID }) else {
                throw PersonalNotesError.conflict
            }
            let current = document.notes[index]
            // 快照取自磁盘最新文档，不信任界面传入的内容；收藏、归档、身份、创建时间与引用保持不变。
            var input = current
            input.title = version.title; input.body = version.body; input.category = version.category
            let target = try input.validatedInput()
            guard !current.sameContent(as: target) else { return (document, false) }
            document.notes[index] = try updated(current, with: target, newReferences: [], now: now)
            return (document, true)
        }
    }

    /// 由磁盘最新记录构建保存结果：草稿只贡献标题、正文、分类、收藏与归档标记。
    private static func updated(_ current: PersonalNote, with input: PersonalNote,
                                newReferences: [NoteReference], now: Date) throws -> PersonalNote {
        guard current.revision < Int.max else { throw PersonalNotesError.conflict }
        var saved = current
        saved.title = input.title; saved.body = input.body; saved.category = input.category
        saved.isFavorite = input.isFavorite; saved.isArchived = input.isArchived
        saved.updatedAt = now; saved.revision = current.revision + 1
        if !current.sameContent(as: input) {      // 收藏/归档/引用/相同内容：不产生内容版本
            guard current.versions.count < PersonalNotesLimits.versionsPerNote else {
                throw PersonalNotesError.capacityExceeded("该笔记已达 \(PersonalNotesLimits.versionsPerNote) 个内容版本上限")
            }
            saved.versions.append(NoteVersion(number: (current.versions.last?.number ?? 0) + 1,
                title: input.title, body: input.body, category: input.category, recordedAt: now))
        }
        saved.references = try appended(newReferences, to: current.references, now: now)
        return saved
    }

    /// 引用只追加：登记时间取提交时刻；更正说明必须指向更早的非更正记录。
    private static func appended(_ new: [NoteReference], to existing: [NoteReference], now: Date) throws -> [NoteReference] {
        guard !new.isEmpty else { return existing }
        guard existing.count + new.count <= PersonalNotesLimits.referencesPerNote else {
            throw PersonalNotesError.capacityExceeded("该笔记引用已达 \(PersonalNotesLimits.referencesPerNote) 条上限")
        }
        var result = existing
        for reference in new {
            try reference.validate()
            let stamped = NoteReference(id: reference.id, kind: reference.kind, name: reference.name, location: reference.location,
                notes: reference.notes, correctsReferenceID: reference.correctsReferenceID, recordedAt: now)
            guard !result.contains(where: { $0.id == stamped.id }) else {
                throw PersonalNotesError.invalidInput("引用身份重复；未保存。")
            }
            if let corrected = stamped.correctsReferenceID {
                guard let target = result.first(where: { $0.id == corrected }), target.kind != .correction else {
                    throw PersonalNotesError.invalidInput("更正说明必须指向本笔记已有的文件或链接引用；未保存。")
                }
            }
            result.append(stamped)
        }
        return result
    }
}
