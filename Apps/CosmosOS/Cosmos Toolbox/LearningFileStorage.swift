import Foundation
import Darwin

nonisolated enum LearningStorageStage: Sendable, Equatable { case read, encode, backup, backupReadBack, replace, readBack }

/// A topic field change applied to the latest on-disk topic after its revision is checked.
nonisolated enum LearningTopicChange: Sendable, Equatable {
    case status(LearningStatus)
    case archived(Bool)
}

/// Optional "update the topic's next step" half of a combined entry save.
nonisolated struct LearningNextStepUpdate: Sendable, Equatable {
    let expectedTopicRevision: Int
    let nextStep: String
}

nonisolated enum LearningMutation: Sendable {
    case saveTopic(LearningTopic, expectedRevision: Int?)
    case changeTopic(id: UUID, expectedRevision: Int, change: LearningTopicChange)
    case saveEntry(LearningEntry, expectedRevision: Int?, nextStep: LearningNextStepUpdate?, today: LearningDay)
}

/// Independent JSON storage for the learning center. The file-safety primitives are adapted from
/// the Prompt Vault storage on purpose (copied, not shared) so neither module can affect the other.
nonisolated final class LearningFileStorage: @unchecked Sendable {
    let root: URL
    private let queue = DispatchQueue(label: "cosmos.learning.storage")
    private let hook: @Sendable (LearningStorageStage) throws -> Void
    private let clock: @Sendable () -> Date
    var primaryURL: URL { root.appendingPathComponent("learning.json") }
    var backupURL: URL { root.appendingPathComponent("learning.backup.json") }
    private var lockURL: URL { root.appendingPathComponent(".learning.lock") }

    static func productionRoot() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false)
            .appendingPathComponent("Cosmos OS/Learning", isDirectory: true)
    }

    init(root: URL, clock: @escaping @Sendable () -> Date = { Date() },
         hook: @escaping @Sendable (LearningStorageStage) throws -> Void = { _ in }) {
        self.root = root; self.clock = clock; self.hook = hook
    }

    func load() async throws -> LearningSnapshot {
        try await perform { try self.readDocument().document.snapshot }
    }

    func apply(_ mutation: LearningMutation) async throws -> LearningSnapshot {
        try await perform { try self.transact(mutation) }
    }

    private func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try operation()) }
                catch let error as LearningError { continuation.resume(throwing: error) }
                catch { continuation.resume(throwing: LearningError.storage(error.localizedDescription)) }
            }
        }
    }

    // MARK: Coding

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: text) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                debugDescription: "Invalid date: \(text)"))
        }
        return decoder
    }

    // MARK: File safety primitives

    private func kind(_ url: URL) throws -> mode_t? {
        var info = stat()
        if lstat(url.path, &info) == 0 { return info.st_mode & S_IFMT }
        if errno == ENOENT { return nil }
        throw LearningError.storage(String(cString: strerror(errno)))
    }

    private func checkParents(create: Bool) throws -> Bool {
        guard root.isFileURL, root.path.hasPrefix("/"),
              !root.path.split(separator: "/").contains("..") else { throw LearningError.unsafePath }
        var path = URL(fileURLWithPath: "/", isDirectory: true)
        for component in root.path.split(separator: "/") {
            path.appendPathComponent(String(component), isDirectory: true)
            if let type = try kind(path) {
                guard type == S_IFDIR else { throw LearningError.unsafePath }
            } else if create {
                if mkdir(path.path, 0o700) != 0, errno != EEXIST {
                    throw LearningError.storage(String(cString: strerror(errno)))
                }
                guard try kind(path) == S_IFDIR else { throw LearningError.unsafePath }
            } else { return false }
        }
        return true
    }

    private func read(_ url: URL) throws -> Data? {
        guard let type = try kind(url) else { return nil }
        guard type == S_IFREG else { throw LearningError.unsafePath }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw LearningError.storage(String(cString: strerror(errno))) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw LearningError.unsafePath }
        // Reject rather than truncate a library larger than the first-phase limit.
        guard info.st_size <= LearningLimits.documentBytes else {
            throw LearningError.storage("文件超过 16 MiB 限制，不会截断")
        }
        let data = try handle.read(upToCount: LearningLimits.documentBytes + 1) ?? Data()
        guard data.count <= LearningLimits.documentBytes, data.count == info.st_size else {
            throw LearningError.conflict
        }
        return data
    }

    private func readDocument() throws -> (document: LearningDocument, raw: Data?) {
        try hook(.read)
        guard try checkParents(create: false) else { return (LearningDocument(), nil) }
        // Check even an unused backup's file type; never overwrite a linked target.
        if let type = try kind(backupURL), type != S_IFREG { throw LearningError.unsafePath }
        guard let raw = try read(primaryURL) else {
            if try kind(backupURL) != nil { throw LearningError.missingPrimaryWithBackup }
            return (LearningDocument(), nil)
        }
        guard String(data: raw, encoding: .utf8) != nil, !raw.contains(0) else { throw LearningError.corruptData }
        let document: LearningDocument
        do { document = try Self.makeDecoder().decode(LearningDocument.self, from: raw) }
        catch { throw LearningError.corruptData }
        do { try document.validate() }
        catch LearningError.invalidInput { throw LearningError.corruptData }
        return (document, raw)
    }

    /// Writes a sibling temporary file and renames it over `target`. Every failure thrown from here
    /// happens strictly before the rename, so the target is untouched when this throws.
    private func writeAtomic(_ data: Data, to target: URL) throws {
        if let type = try kind(target), type != S_IFREG { throw LearningError.unsafePath }
        let temporary = root.appendingPathComponent(".learning-write-" + UUID().uuidString)
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw LearningError.writeFailed(String(cString: strerror(errno))) }
        var closed = false
        defer { if !closed { close(fd) }; unlink(temporary.path) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch { throw LearningError.writeFailed(error.localizedDescription) }
        closed = true
        guard close(fd) == 0 else { throw LearningError.writeFailed(String(cString: strerror(errno))) }
        _ = try checkParents(create: false)
        if let type = try kind(target), type != S_IFREG { throw LearningError.unsafePath }
        guard rename(temporary.path, target.path) == 0 else {
            throw LearningError.writeFailed(String(cString: strerror(errno)))
        }
    }

    /// Maps plain I/O failures before the primary replacement to a retryable error.
    private func beforeReplace<T>(_ body: () throws -> T) throws -> T {
        do { return try body() }
        catch LearningError.storage(let reason) { throw LearningError.writeFailed(reason) }
        catch let error as LearningError { throw error }
        catch { throw LearningError.writeFailed(error.localizedDescription) }
    }

    // MARK: Transaction

    private func transact(_ mutation: LearningMutation) throws -> LearningSnapshot {
        let lockFD: Int32 = try beforeReplace {
            _ = try checkParents(create: true)
            if let type = try kind(lockURL), type != S_IFREG { throw LearningError.unsafePath }
            let fd = open(lockURL.path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
            guard fd >= 0 else { throw LearningError.storage(String(cString: strerror(errno))) }
            guard flock(fd, LOCK_EX) == 0 else {
                close(fd); throw LearningError.storage("无法取得学习库写锁")
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
            guard encoded.count <= LearningLimits.documentBytes else {
                throw LearningError.invalidInput("学习库将超过 16 MiB 上限；未保存也未截断。")
            }
            guard try read(primaryURL) == loaded.raw else { throw LearningError.conflict }
            if let raw = loaded.raw {
                try hook(.backup)
                try writeAtomic(raw, to: backupURL)
                try hook(.backupReadBack)
                guard try read(backupURL) == raw else { throw LearningError.writeFailed("备份读回不一致") }
            }
            guard try read(primaryURL) == loaded.raw else { throw LearningError.conflict }
            try hook(.replace)
            return (encoded, loaded.raw)
        }

        // A throw from here up to and including the rename leaves the primary file untouched.
        try beforeReplace { try writeAtomic(prepared.encoded, to: primaryURL) }

        // The primary was replaced. Anything that cannot be confirmed from here is uncertain.
        do {
            try hook(.readBack)
            guard let actual = try read(primaryURL), actual == prepared.encoded else {
                throw LearningError.uncertainWrite
            }
            let decoded = try Self.makeDecoder().decode(LearningDocument.self, from: actual)
            try decoded.validate()
            return decoded.snapshot
        } catch { throw LearningError.uncertainWrite }
    }

    // MARK: Pure mutation logic (applied to the latest on-disk document)

    static func apply(_ mutation: LearningMutation, to document: LearningDocument, now: Date) throws -> LearningDocument {
        var document = document
        switch mutation {
        case .saveTopic(let proposed, let expectedRevision):
            let input = try proposed.validated()
            if let index = document.topics.firstIndex(where: { $0.id == input.id }) {
                var topic = document.topics[index]
                guard expectedRevision == topic.revision, topic.revision < Int.max else { throw LearningError.conflict }
                guard !topic.isArchived else { throw LearningError.topicArchived }
                topic.name = input.name; topic.goal = input.goal; topic.status = input.status
                topic.nextStep = input.nextStep; topic.resourceURL = input.resourceURL
                topic.updatedAt = now; topic.revision += 1
                document.topics[index] = topic
            } else {
                guard expectedRevision == nil else { throw LearningError.conflict }
                var topic = input
                topic.isArchived = false; topic.revision = 1; topic.updatedAt = topic.createdAt
                document.topics.append(topic)
            }

        case .changeTopic(let id, let expectedRevision, let change):
            guard let index = document.topics.firstIndex(where: { $0.id == id }) else { throw LearningError.topicMissing }
            var topic = document.topics[index]
            guard expectedRevision == topic.revision, topic.revision < Int.max else { throw LearningError.conflict }
            switch change {
            case .status(let status):
                guard !topic.isArchived else { throw LearningError.topicArchived }
                topic.status = status
            case .archived(let archived):
                topic.isArchived = archived
            }
            topic.updatedAt = now; topic.revision += 1
            document.topics[index] = topic

        case .saveEntry(let proposed, let expectedRevision, let nextStep, let today):
            let input = try proposed.validated()
            guard let topicIndex = document.topics.firstIndex(where: { $0.id == input.topicID }) else {
                throw LearningError.topicMissing
            }
            guard !document.topics[topicIndex].isArchived else { throw LearningError.topicArchived }
            if let index = document.entries.firstIndex(where: { $0.id == input.id }) {
                var entry = document.entries[index]
                guard expectedRevision == entry.revision, entry.revision < Int.max else { throw LearningError.conflict }
                guard entry.topicID == input.topicID else {
                    throw LearningError.invalidInput("学习记录不能移到其他主题。")
                }
                // An untouched historical date is kept even if the time zone made it "future".
                if input.studyDay > today, input.studyDay != entry.studyDay { throw LearningError.futureDate }
                entry.studyDay = input.studyDay; entry.body = input.body
                entry.durationMinutes = input.durationMinutes
                entry.updatedAt = now; entry.revision += 1
                document.entries[index] = entry
            } else {
                guard expectedRevision == nil else { throw LearningError.conflict }
                if input.studyDay > today { throw LearningError.futureDate }
                var entry = input
                entry.revision = 1; entry.updatedAt = entry.createdAt
                document.entries.append(entry)
            }
            if let nextStep {
                var topic = document.topics[topicIndex]
                guard nextStep.expectedTopicRevision == topic.revision, topic.revision < Int.max else {
                    throw LearningError.conflict
                }
                try LearningTopic.validateNextStep(nextStep.nextStep)
                if Data(topic.nextStep.utf8) != Data(nextStep.nextStep.utf8) {
                    topic.nextStep = nextStep.nextStep
                    topic.updatedAt = now; topic.revision += 1
                    document.topics[topicIndex] = topic
                }
            }
        }
        return document
    }
}
