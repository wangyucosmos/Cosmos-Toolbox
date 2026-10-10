import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

private final class NotesClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_800_000_000)
    func next() -> Date { lock.lock(); defer { lock.unlock() }; value = value.addingTimeInterval(10); return value }
}

private final class NotesFault: @unchecked Sendable {
    private let lock = NSLock()
    private var stage: PersonalNotesStorageStage?
    func arm(_ stage: PersonalNotesStorageStage?) { lock.lock(); self.stage = stage; lock.unlock() }
    func fires(_ current: PersonalNotesStorageStage) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return stage == current
    }
}

private final class NotesRestoreMemory: CoreRestorePreferences, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func restoreRead(_ key: String) throws -> Data? { lock.lock(); defer { lock.unlock() }; return values[key] }
    func restoreInsert(_ data: Data, key: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard values[key] == nil else { throw CoreRestoreError.invalid("存在，不覆盖") }
        values[key] = data
    }
    func restoreRemoveOwned(_ data: Data, key: String) throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        if values[key] == nil { return true }
        guard values[key] == data else { return false }
        values.removeValue(forKey: key); return true
    }
}

@MainActor
final class PersonalNotesTests: XCTestCase {
    private var roots: [URL] = []
    private let clock = NotesClock()
    private let fault = NotesFault()
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots = []; super.tearDown()
    }

    // MARK: Helpers

    /// A path that does NOT exist yet (missing library vs. failure is part of what is tested).
    private func newRoot() -> URL {
        let url = URL(fileURLWithPath: "/private/tmp/CosmosPersonalNotesTest-" + UUID().uuidString, isDirectory: true)
        roots.append(url); return url
    }
    private func makeStorage(_ root: URL, faulty: Bool = false) -> PersonalNotesFileStorage {
        let clock = self.clock, fault = self.fault
        return PersonalNotesFileStorage(root: root, clock: { clock.next() }, hook: { stage in
            if faulty, fault.fires(stage) { throw NSError(domain: "inject", code: 1) }
        })
    }
    private func makeStore(_ root: URL, faulty: Bool = false) -> PersonalNotesStore {
        PersonalNotesStore(storage: makeStorage(root, faulty: faulty))
    }
    private func loaded(_ root: URL, faulty: Bool = false) async -> PersonalNotesStore {
        let store = makeStore(root, faulty: faulty); await store.reload(); return store
    }
    private func primary(_ root: URL) -> URL { root.appendingPathComponent("notes.json") }
    private func bytes(_ root: URL) throws -> Data { try Data(contentsOf: primary(root)) }
    private func disk(_ root: URL) throws -> PersonalNotesDocument {
        try PersonalNotesCoding.decoder().decode(PersonalNotesDocument.self, from: bytes(root))
    }
    private func listing(_ root: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []).sorted()
    }
    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
    private let tricky = "  第一行 e\u{301}\r\n\t制表 😀  \r\n\n结尾空白   "

    @discardableResult
    private func create(_ store: PersonalNotesStore, title: String = "标题", body: String = "正文", category: String? = nil) async throws -> PersonalNote {
        let draft = PersonalNote(title: title, body: body, category: category)
        let ok = await store.save(draft, expected: nil)
        XCTAssertTrue(ok, store.error?.localizedDescription ?? "")
        return try XCTUnwrap(store.notes.first { $0.id == draft.id })
    }
    private func edit(_ store: PersonalNotesStore, _ note: PersonalNote, _ change: (inout PersonalNote) -> Void) async throws -> PersonalNote {
        var draft = note; change(&draft)
        let ok = await store.save(draft, expected: note.revision)
        XCTAssertTrue(ok, store.error?.localizedDescription ?? "")
        return try XCTUnwrap(store.notes.first { $0.id == note.id })
    }

    // MARK: 1. Create / edit / reload / exact text

    func testMissingLibraryIsZeroInitAndDistinctFromReadFailure() async throws {
        let root = newRoot()
        let store = await loaded(root)
        XCTAssertTrue(store.loaded); XCTAssertFalse(store.established); XCTAssertTrue(store.notes.isEmpty); XCTAssertNil(store.error)
        XCTAssertFalse(exists(root), "reading a missing library creates nothing")
        _ = try await create(store)
        XCTAssertTrue(store.established)
        // A failing read is not an empty library: the error is explicit, nothing is replaced.
        try Data("{ broken".utf8).write(to: primary(root))
        let broken = await loaded(root)
        XCTAssertFalse(broken.loaded); XCTAssertEqual(broken.error, .corruptData); XCTAssertFalse(broken.established)
        XCTAssertEqual(try bytes(root), Data("{ broken".utf8))
    }

    func testCreateEditReloadPreservesExactTextAndNormalizesOnlyTitleAndCategory() async throws {
        let root = newRoot(), store = await loaded(root)
        let created = try await create(store, title: "  标题  ", body: tricky, category: "  工作  ")
        XCTAssertEqual(created.title, "标题"); XCTAssertEqual(created.category, "工作")
        XCTAssertEqual(Array(created.body.utf8), Array(tricky.utf8))
        XCTAssertEqual(created.revision, 1); XCTAssertEqual(created.versions.count, 1)
        XCTAssertEqual(created.createdAt, created.updatedAt); XCTAssertEqual(created.versions[0].recordedAt, created.createdAt)
        XCTAssertEqual(created.versions[0].number, 1); XCTAssertEqual(created.contentVersion, 1)
        // New store instance (= restart) reads the same bytes back.
        let fresh = await loaded(root)
        let reloaded = try XCTUnwrap(fresh.notes.first)
        XCTAssertEqual(reloaded, created)
        XCTAssertEqual(Array(reloaded.body.utf8), Array(tricky.utf8))
        XCTAssertEqual(Array(reloaded.versions[0].body.utf8), Array(tricky.utf8))
        let edited = try await edit(fresh, reloaded) { $0.body = tricky + "\r\n追加" }
        XCTAssertEqual(edited.revision, 2); XCTAssertEqual(edited.versions.map(\.number), [1, 2])
        XCTAssertEqual(Array(edited.versions[0].body.utf8), Array(tricky.utf8), "older snapshot is untouched")
        XCTAssertEqual(edited.createdAt, created.createdAt); XCTAssertGreaterThan(edited.updatedAt, created.updatedAt)
        // Empty body is allowed so notes can be organised step by step.
        let empty = try await create(fresh, title: "只有标题", body: "")
        XCTAssertEqual(empty.body, ""); XCTAssertEqual(empty.versions.count, 1)
        XCTAssertEqual(fresh.notes.count, 2)
    }

    func testInvalidInputIsRejectedWithoutWritingAndKeepsDraft() async throws {
        let root = newRoot(), store = await loaded(root)
        _ = try await create(store)
        let before = try bytes(root), existing = try XCTUnwrap(store.notes.first)
        for (label, draft) in [("blank title", PersonalNote(title: " \n ", body: "x")),
                               ("long title", PersonalNote(title: String(repeating: "长", count: 201), body: "")),
                               ("long category", PersonalNote(title: "t", body: "", category: String(repeating: "c", count: 61))),
                               ("NUL body", PersonalNote(title: "t", body: "a\0b")),
                               ("NUL title", PersonalNote(title: "t\0", body: ""))] {
            let ok = await store.save(draft, expected: nil)
            XCTAssertFalse(ok, label)
            if case .invalidInput = store.error {} else { XCTFail("\(label): \(String(describing: store.error))") }
            XCTAssertTrue(store.canSave, "invalid input does not lock saving")
        }
        XCTAssertEqual(try bytes(root), before); XCTAssertEqual(store.notes, [existing])
        // 200-character title and 60-character category are accepted.
        let edge = PersonalNote(title: String(repeating: "长", count: 200), body: "", category: String(repeating: "c", count: 60))
        let ok = await store.save(edge, expected: nil)
        XCTAssertTrue(ok)
    }

    // MARK: 2. Query, category, favorite, archive

    func testBodySearchCategoryFavoriteArchiveAndSort() async throws {
        let root = newRoot(), store = await loaded(root)
        let a = try await create(store, title: "苹果笔记", body: "水果 香蕉 CRLF\r\n行", category: "饮食")
        let b = try await create(store, title: "旅行", body: "护照 签证", category: "出行")
        let c = try await create(store, title: "杂项", body: "无关", category: nil)
        let notes = store.notes
        func titles(_ search: String = "", _ category: NoteCategoryFilter = .all, fav: Bool = false, archived: Bool = false) -> [String] {
            PersonalNotesQuery.filter(notes, search: search, category: category, favoritesOnly: fav, archived: archived).map(\.title)
        }
        XCTAssertEqual(titles("苹果"), ["苹果笔记"], "title match")
        XCTAssertEqual(titles("香蕉"), ["苹果笔记"], "saved body match")
        XCTAssertEqual(titles("  护照  "), ["旅行"]); XCTAssertEqual(titles("不存在"), [])
        XCTAssertEqual(titles("", .named("出行")), ["旅行"]); XCTAssertEqual(titles("", .uncategorized), ["杂项"])
        XCTAssertEqual(titles(), ["杂项", "旅行", "苹果笔记"], "newest update first")
        XCTAssertEqual(PersonalNotesQuery.categories(notes), ["出行", "饮食"])
        await store.setFavorite(b)
        let favorites = PersonalNotesQuery.filter(store.notes, search: "", favoritesOnly: true, archived: false)
        XCTAssertEqual(favorites.map(\.title), ["旅行"])
        let latestA = try XCTUnwrap(store.notes.first { $0.id == a.id })
        await store.setArchived(latestA)
        XCTAssertEqual(PersonalNotesQuery.filter(store.notes, search: "", archived: true).map(\.title), ["苹果笔记"])
        XCTAssertFalse(PersonalNotesQuery.filter(store.notes, search: "", archived: false).map(\.title).contains("苹果笔记"))
        let archivedA = try XCTUnwrap(store.notes.first { $0.id == a.id })
        await store.setArchived(archivedA)   // restore from archive
        XCTAssertEqual(PersonalNotesQuery.filter(store.notes, search: "香蕉", archived: false).map(\.title), ["苹果笔记"])
        XCTAssertEqual(c.revision, 1)
        // Search runs over the saved body only: it never sees an unsaved draft.
        let session = PersonalNoteEditSession(store: store, note: b)
        session.draft.body = "草稿独有词"
        XCTAssertTrue(PersonalNotesQuery.filter(store.notes, search: "草稿独有词", archived: false).isEmpty)
    }

    // MARK: 3. Content versions

    func testContentVersionRulesByUTF8BytesAndMetadataNeverMakeVersions() async throws {
        let root = newRoot(), store = await loaded(root)
        var note = try await create(store, title: "版本", body: "e\u{301}", category: "甲")
        XCTAssertEqual(note.versions.count, 1)
        note = try await edit(store, note) { _ in }                       // identical content
        XCTAssertEqual(note.versions.count, 1); XCTAssertEqual(note.revision, 2)
        await store.setFavorite(note); note = try XCTUnwrap(store.notes.first)
        await store.setArchived(note); note = try XCTUnwrap(store.notes.first)
        await store.setArchived(note); note = try XCTUnwrap(store.notes.first)   // restore from archive
        XCTAssertEqual(note.versions.count, 1, "favorite / archive / un-archive create no content version")
        XCTAssertEqual(note.revision, 5); XCTAssertTrue(note.isFavorite); XCTAssertFalse(note.isArchived)
        // Canonically equivalent Unicode is still a byte-level change.
        note = try await edit(store, note) { $0.body = "\u{E9}" }
        XCTAssertEqual(note.versions.count, 2)
        XCTAssertNotEqual(Array(note.versions[0].body.utf8), Array(note.versions[1].body.utf8))
        note = try await edit(store, note) { $0.title = "版本 改" }; XCTAssertEqual(note.versions.count, 3)
        note = try await edit(store, note) { $0.category = "乙" }; XCTAssertEqual(note.versions.count, 4)
        note = try await edit(store, note) { $0.category = nil }; XCTAssertEqual(note.versions.count, 5)
        XCTAssertEqual(note.versions.map(\.number), [1, 2, 3, 4, 5])
        XCTAssertEqual(Set(note.versions.map(\.id)).count, 5)
        XCTAssertNotEqual(note.revision, note.contentVersion, "content version and optimistic revision are independent")
        XCTAssertEqual(note.versions.map(\.category), ["甲", "甲", "甲", "乙", nil])
        XCTAssertTrue(zip(note.versions, note.versions.dropFirst()).allSatisfy { $0.recordedAt < $1.recordedAt })
        XCTAssertEqual(note.versions.last?.recordedAt, note.updatedAt)
        XCTAssertTrue(note.sameContent(as: try XCTUnwrap(note.versions.last)))
    }

    func testHistoryIsRebuiltFromLatestDiskAndStaleWindowsCannotOverwrite() async throws {
        let root = newRoot(), storeA = await loaded(root)
        let note = try await create(storeA, body: "v1")
        let storeB = await loaded(root)
        _ = try await edit(storeB, try XCTUnwrap(storeB.notes.first)) { $0.body = "v2 by B" }
        let onDisk = try bytes(root)
        // A still holds the revision-1 note; its save must be refused and must not touch the file.
        var stale = note; stale.body = "v2 by A"
        let refused = await storeA.save(stale, expected: note.revision)
        XCTAssertFalse(refused); XCTAssertEqual(storeA.error, .conflict); XCTAssertTrue(storeA.canSave)
        XCTAssertEqual(try bytes(root), onDisk)
        XCTAssertEqual(storeA.notes.first?.body, "v1", "the failed result is not published")
        // Forged history/references on a draft are ignored: history comes from the disk record.
        await storeA.reload()
        var forged = try XCTUnwrap(storeA.notes.first)
        forged.body = "v3"
        forged.versions = [NoteVersion(number: 1, title: "伪造", body: "伪造", category: nil, recordedAt: Date())]
        forged.references = [NoteReference(kind: .link, name: "伪造", location: "https://example.test")]
        let ok = await storeA.save(forged, expected: forged.revision)
        XCTAssertTrue(ok)
        let saved = try XCTUnwrap(storeA.notes.first)
        XCTAssertEqual(saved.versions.map(\.body), ["v1", "v2 by B", "v3"])
        XCTAssertTrue(saved.references.isEmpty)
    }

    func testRestoreMakesNewCurrentVersionAndKeepsIdentityStateAndReferences() async throws {
        let root = newRoot(), store = await loaded(root)
        var note = try await create(store, title: "恢复", body: "一\r\n", category: "甲")
        note = try await edit(store, note) { $0.body = "二"; $0.title = "恢复二"; $0.category = "乙"; $0.isFavorite = true }
        // Add a reference, then archive: restore must keep both untouched.
        let reference = NoteReference(kind: .link, name: "资料", location: "https://example.test/doc")
        let awaited1 = await store.save(note, newReferences: [reference], expected: note.revision)
        XCTAssertTrue(awaited1)
        note = try XCTUnwrap(store.notes.first)
        await store.setArchived(note); note = try XCTUnwrap(store.notes.first)
        XCTAssertEqual(note.versions.count, 2)
        let v1 = note.versions[0]
        let outcome = await store.restore(noteID: note.id, versionID: v1.id, expectedRevision: note.revision)
        XCTAssertEqual(outcome, .restored)
        let restored = try XCTUnwrap(store.notes.first)
        XCTAssertEqual(restored.id, note.id); XCTAssertEqual(restored.createdAt, note.createdAt)
        XCTAssertTrue(restored.isFavorite); XCTAssertTrue(restored.isArchived)
        XCTAssertEqual(restored.title, "恢复"); XCTAssertEqual(Array(restored.body.utf8), Array("一\r\n".utf8)); XCTAssertEqual(restored.category, "甲")
        XCTAssertEqual(restored.versions.count, 3); XCTAssertEqual(Array(restored.versions.prefix(2)), note.versions, "history is untouched")
        XCTAssertEqual(restored.versions[2].number, 3); XCTAssertNotEqual(restored.versions[2].id, v1.id)
        XCTAssertEqual(restored.versions[2].recordedAt, restored.updatedAt)
        XCTAssertEqual(restored.references.map(\.id), [reference.id], "restoring text never removes references")
        XCTAssertEqual(restored.revision, note.revision + 1)
        // Restoring content identical to the current content writes nothing and adds no version.
        let before = try bytes(root)
        let same = await store.restore(noteID: note.id, versionID: v1.id, expectedRevision: restored.revision)
        XCTAssertEqual(same, .unchanged); XCTAssertEqual(try bytes(root), before)
        XCTAssertEqual(store.notes.first?.versions.count, 3)
        // Stale revision and unknown version are conflicts that change nothing.
        let awaited2 = await store.restore(noteID: note.id, versionID: note.versions[1].id, expectedRevision: note.revision)
        XCTAssertEqual(awaited2, .failed)
        XCTAssertEqual(store.error, .conflict); XCTAssertEqual(try bytes(root), before)
        let awaited3 = await store.restore(noteID: note.id, versionID: UUID(), expectedRevision: restored.revision)
        XCTAssertEqual(awaited3, .failed)
        XCTAssertEqual(try bytes(root), before)
    }

    func testSessionHistoryCopyRestoreAndDraftProtection() async throws {
        let root = newRoot(), store = await loaded(root)
        var note = try await create(store, body: "旧正文\r\n  ")
        note = try await edit(store, note) { $0.body = "新正文" }
        let session = PersonalNoteEditSession(store: store, note: note)
        var copied: [String] = []
        session.copy = { copied.append($0); return true }
        XCTAssertTrue(session.copyVersion(note.versions[0]))
        XCTAssertEqual(copied, ["旧正文\r\n  "], "copies exactly the selected version's body, no labels or reference locations")
        XCTAssertTrue(session.copyBody()); XCTAssertEqual(copied.last, "新正文")
        session.copy = { _ in false }
        XCTAssertFalse(session.copyVersion(note.versions[0])); XCTAssertTrue(session.message.contains("未复制"))
        // A draft in the window blocks restore and is not overwritten.
        session.draft.body = "未保存草稿"
        let blocked = await session.restore(note.versions[0])
        XCTAssertFalse(blocked); XCTAssertEqual(session.draft.body, "未保存草稿"); XCTAssertTrue(session.message.contains("未保存"))
        XCTAssertEqual(store.notes.first?.versions.count, 2)
        // Current content needs no restore.
        let current = await session.restore(try XCTUnwrap(note.versions.last))
        XCTAssertFalse(current)
        // Discard the draft, then restore: the window follows the new saved version.
        session.draft.body = "新正文"
        XCTAssertFalse(session.isDirty)
        let awaited4 = await session.restore(note.versions[0])
        XCTAssertTrue(awaited4)
        XCTAssertEqual(session.baseline?.versions.count, 3); XCTAssertEqual(session.draft.body, "旧正文\r\n  ")
        XCTAssertFalse(session.isDirty)
        // A clean window follows other writers (list favorite / another window's restore); a dirty one never does.
        let sibling = PersonalNoteEditSession(store: store, note: session.baseline)
        let dirty = PersonalNoteEditSession(store: store, note: session.baseline)
        dirty.draft.title = "我的草稿"
        await store.setFavorite(try XCTUnwrap(store.notes.first))
        XCTAssertTrue(sibling.baseline?.isFavorite == true && sibling.draft.isFavorite)
        XCTAssertEqual(dirty.draft.title, "我的草稿"); XCTAssertFalse(dirty.baseline?.isFavorite == true)
        let conflict = await dirty.save()
        XCTAssertFalse(conflict); XCTAssertEqual(store.error, .conflict); XCTAssertEqual(dirty.draft.title, "我的草稿")
    }

    // MARK: 4. Draft protection, failure, concurrency

    func testSaveFailureKeepsDraftPublishesNothingAndRetrySucceeds() async throws {
        let root = newRoot(), store = await loaded(root, faulty: true)
        let note = try await create(store, body: "已保存")
        let session = PersonalNoteEditSession(store: store, note: note)
        session.draft.body = "草稿正文"
        let before = try bytes(root)
        for stage in [PersonalNotesStorageStage.encode, .backup, .backupReadBack, .replace] {
            fault.arm(stage)
            let ok = await session.save()
            XCTAssertFalse(ok, "\(stage)")
            XCTAssertNotEqual(session.message, "已保存。")
            XCTAssertEqual(session.draft.body, "草稿正文"); XCTAssertTrue(session.isDirty)
            XCTAssertEqual(store.notes.first?.body, "已保存", "failed result is never published")
            XCTAssertEqual(try bytes(root), before, "primary bytes unchanged after failure at \(stage)")
            XCTAssertTrue(store.canSave, "a retryable I/O failure does not lock saving")
            XCTAssertEqual(try disk(root).notes.first?.versions.count, 1)
        }
        fault.arm(nil)
        let awaited5 = await session.save()
        XCTAssertTrue(awaited5)
        XCTAssertEqual(store.notes.first?.body, "草稿正文"); XCTAssertEqual(store.notes.first?.versions.count, 2)
        XCTAssertFalse(session.isDirty); XCTAssertEqual(session.message, "已保存。")
    }

    func testUncertainWriteLocksSavingAndNeverReportsSuccess() async throws {
        let root = newRoot(), store = await loaded(root, faulty: true)
        let note = try await create(store, body: "旧")
        let session = PersonalNoteEditSession(store: store, note: note)
        session.draft.body = "新"
        fault.arm(.readBack)
        let ok = await session.save()
        XCTAssertFalse(ok); XCTAssertEqual(store.error, .uncertainWrite); XCTAssertFalse(store.canSave)
        XCTAssertEqual(session.draft.body, "新", "draft kept"); XCTAssertEqual(store.notes.first?.body, "旧", "result not published")
        XCTAssertNotEqual(session.message, "已保存。")
        fault.arm(nil)
        let awaited6 = await store.save(note, expected: note.revision)
        XCTAssertFalse(awaited6, "locked until the disk is verified")
    }

    func testCloseChoicesAndTerminationParticipant() async throws {
        let root = newRoot(), store = await loaded(root)
        let note = try await create(store, body: "x")
        let session = PersonalNoteEditSession(store: store, note: note)
        XCTAssertFalse(session.isDirty)
        let cleanClose = await session.allowClose(choice: .cancel)
        XCTAssertTrue(cleanClose, "nothing to protect")
        session.draft.body = "y"; XCTAssertTrue(session.isDirty)
        let cancelled = await session.allowClose(choice: .cancel)
        XCTAssertFalse(cancelled); XCTAssertEqual(session.draft.body, "y")
        // Pending reference input counts as unsaved work.
        session.draft.body = "x"; XCTAssertFalse(session.isDirty)
        session.linkText = "https://example.test"; XCTAssertTrue(session.isDirty)
        session.addLink(); XCTAssertEqual(session.pendingReferences.count, 1); XCTAssertTrue(session.isDirty)
        // Save with failure blocks closing and keeps everything.
        session.draft.body = "z"
        let faultyStore = await loaded(newRoot(), faulty: true)
        let other = try await create(faultyStore, body: "x")
        let failing = PersonalNoteEditSession(store: faultyStore, note: other)
        failing.draft.body = "fail"; fault.arm(.replace)
        let closedWithFailedSave = await failing.allowClose(choice: .save)
        XCTAssertFalse(closedWithFailedSave); XCTAssertEqual(failing.draft.body, "fail"); fault.arm(nil)
        let saved = await failing.allowClose(choice: .save)
        XCTAssertTrue(saved); XCTAssertEqual(faultyStore.notes.first?.body, "fail")
        let discarded = await session.allowClose(choice: .discard)
        XCTAssertTrue(discarded)
        XCTAssertEqual(store.notes.first?.body, "x", "discard writes nothing")
        // An un-added link blocks the save instead of silently dropping it.
        let blocked = PersonalNoteEditSession(store: store, note: store.notes.first)
        blocked.linkText = "https://example.test"
        let blockedSave = await blocked.save()
        XCTAssertFalse(blockedSave); XCTAssertTrue(blocked.message.contains("加入"))
        // Quit protection: frozen manager blocks new windows and unfreezes cleanly.
        let manager = PersonalNoteWindowManager.shared
        XCTAssertFalse(manager.hasUnsavedWork); XCTAssertFalse(manager.terminationBlocked)
        manager.freezeForTermination(); XCTAssertTrue(manager.terminationBlocked)
        XCTAssertNil(manager.open(store: store, note: nil), "no new editor windows while quitting")
        manager.unfreezeAfterTermination(); XCTAssertFalse(manager.terminationBlocked)
    }

    // MARK: 5. Corruption, safety, capacity

    func testCorruptUnknownAndUnsafeLibrariesRefuseWritesAndKeepOriginalBytes() async throws {
        let seedRoot = newRoot(), seed = await loaded(seedRoot)
        let note = try await create(seed, body: "有效")
        let valid = try disk(seedRoot)
        func variant(_ label: String, _ mutate: (inout PersonalNotesDocument) -> Void) throws -> (String, Data) {
            var document = valid; mutate(&document)
            return (label, try PersonalNotesCoding.encoder().encode(document))
        }
        let candidates: [(String, Data)] = [
            ("garbage", Data("not json".utf8)),
            ("unknown schema", try variant("") { $0.schemaVersion = 2 }.1),
            ("duplicate note id", try variant("") { $0.notes.append($0.notes[0]) }.1),
            ("no versions", try variant("") { $0.notes[0].versions = [] }.1),
            ("latest snapshot differs from current", try variant("") { $0.notes[0].body = "被篡改" }.1),
            ("non-consecutive version numbers", try variant("") {
                let v = $0.notes[0].versions[0]
                $0.notes[0].versions = [NoteVersion(id: v.id, number: 3, title: v.title, body: v.body, category: v.category, recordedAt: v.recordedAt)]
            }.1),
            ("correction without target", try variant("") {
                $0.notes[0].references = [NoteReference(kind: .correction, name: "更正", notes: "x", correctsReferenceID: UUID())]
            }.1),
            ("bad link scheme", try variant("") {
                $0.notes[0].references = [NoteReference(kind: .link, name: "坏", location: "javascript:alert(1)")]
            }.1),
            ("NUL byte", Data("{\"schemaVersion\":1,\"notes\":[]}\0".utf8)),
        ]
        for (label, data) in candidates {
            let root = newRoot()
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try data.write(to: primary(root))
            let store = await loaded(root)
            XCTAssertFalse(store.loaded, label); XCTAssertNotNil(store.error, label); XCTAssertFalse(store.canSave, label)
            let wrote = await store.save(PersonalNote(title: "新", body: "新"), expected: nil)
            XCTAssertFalse(wrote, label)
            XCTAssertEqual(try bytes(root), data, "\(label): original bytes preserved, never replaced by an empty library")
            XCTAssertEqual(listing(root), ["notes.json"], "\(label): no backup/lock/temp files appear")
        }
        // Missing primary with a backup present: no auto-init, no auto-recovery.
        let orphan = newRoot(); try FileManager.default.createDirectory(at: orphan, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: orphan.appendingPathComponent("notes.backup.json"))
        let orphanStore = await loaded(orphan)
        XCTAssertEqual(orphanStore.error, .missingPrimaryWithBackup); XCTAssertFalse(orphanStore.canSave)
        XCTAssertFalse(exists(primary(orphan)))
        // Symlinked root (unsafe path) and a directory in place of the primary file.
        let target = newRoot(); try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let link = newRoot(); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let linked = await loaded(link)
        XCTAssertEqual(linked.error, .unsafePath); XCTAssertFalse(linked.canSave)
        XCTAssertTrue(listing(target).isEmpty)
        let dirRoot = newRoot(); try FileManager.default.createDirectory(at: primary(dirRoot), withIntermediateDirectories: true)
        let dirStore = await loaded(dirRoot)
        XCTAssertEqual(dirStore.error, .unsafePath)
        XCTAssertEqual(note.versions.count, 1)
    }

    func testBodyVersionAndDocumentCapacityRefuseWithoutTruncatingOrDeletingHistory() async throws {
        let root = newRoot(), store = await loaded(root)
        let limit = PersonalNotesLimits.bodyBytes
        let exact = try await create(store, title: "恰好上限", body: String(repeating: "a", count: limit))
        XCTAssertEqual(exact.body.utf8.count, limit)
        let before = try bytes(root)
        let over = await store.save(PersonalNote(title: "超限", body: String(repeating: "a", count: limit + 1)), expected: nil)
        XCTAssertFalse(over)
        if case .capacityExceeded = store.error {} else { XCTFail("\(String(describing: store.error))") }
        XCTAssertTrue(store.canSave, "capacity refusal does not lock the module"); XCTAssertEqual(try bytes(root), before)
        // Multi-byte text is measured in UTF-8 bytes, not characters.
        let multibyte = await store.save(PersonalNote(title: "多字节", body: String(repeating: "汉", count: limit / 3 + 1)), expected: nil)
        XCTAssertFalse(multibyte)
        // Version cap: 500 versions kept, content change refused, metadata still works.
        let capRoot = newRoot(), capStore = await loaded(capRoot)
        let base = try await create(capStore, title: "上限", body: "v1")
        var capped = try disk(capRoot)
        var versions = capped.notes[0].versions
        for number in 2...PersonalNotesLimits.versionsPerNote {
            versions.append(NoteVersion(number: number, title: "上限", body: "v\(number)", category: nil, recordedAt: base.createdAt.addingTimeInterval(Double(number))))
        }
        capped.notes[0].versions = versions; capped.notes[0].body = "v500"
        try PersonalNotesCoding.encoder().encode(capped).write(to: primary(capRoot))
        let full = await loaded(capRoot)
        let fullNote = try XCTUnwrap(full.notes.first)
        XCTAssertEqual(fullNote.versions.count, 500)
        let fullBytes = try bytes(capRoot)
        var change = fullNote; change.body = "v501"
        let awaited7 = await full.save(change, expected: fullNote.revision)
        XCTAssertFalse(awaited7)
        if case .capacityExceeded = full.error {} else { XCTFail("\(String(describing: full.error))") }
        XCTAssertEqual(try bytes(capRoot), fullBytes); XCTAssertEqual(full.notes.first?.versions.count, 500)
        await full.setFavorite(fullNote)
        XCTAssertEqual(full.notes.first?.isFavorite, true); XCTAssertEqual(full.notes.first?.versions.count, 500)
        // Whole-library cap: refuse, never drop history to make room.
        let bigRoot = newRoot(), bigStore = await loaded(bigRoot)
        var accepted = 0
        for index in 0..<8 {
            let ok = await bigStore.save(PersonalNote(title: "大 \(index)", body: String(repeating: "x", count: limit - 8)), expected: nil)
            if ok { accepted += 1 } else { break }
        }
        XCTAssertGreaterThanOrEqual(accepted, 5); XCTAssertLessThan(accepted, 8)
        if case .capacityExceeded = bigStore.error {} else { XCTFail("\(String(describing: bigStore.error))") }
        let bigBytes = try bytes(bigRoot)
        XCTAssertLessThanOrEqual(bigBytes.count, PersonalNotesLimits.documentBytes)
        XCTAssertEqual(try disk(bigRoot).notes.count, accepted); XCTAssertTrue(bigStore.canSave)
        XCTAssertTrue(try disk(bigRoot).notes.allSatisfy { $0.versions.count == 1 })
    }

    // MARK: 6. References

    func testReferenceValidationAppendOnlyAndCorrections() async throws {
        let root = newRoot(), store = await loaded(root)
        let note = try await create(store)
        for bad in ["ftp://example.test/x", "javascript:alert(1)", "file:///etc/passwd", "https://user:pw@example.test", "https://", "example.test", "https://a b.test", ""] {
            XCTAssertThrowsError(try NoteReference(kind: .link, name: "x", location: bad).validate(), bad)
        }
        XCTAssertNoThrow(try NoteReference(kind: .link, name: "x", location: "https://example.test/a?b=1").validate())
        XCTAssertNoThrow(try NoteReference(kind: .link, name: "x", location: "http://example.test").validate())
        for bad in ["relative/path.txt", "/a/../b", "", "/a\0b"] {
            XCTAssertThrowsError(try NoteReference(kind: .file, name: "x", location: bad).validate(), bad)
        }
        XCTAssertThrowsError(try NoteReference(kind: .link, name: "  ", location: "https://example.test").validate())
        XCTAssertThrowsError(try NoteReference(kind: .correction, name: "更正", notes: "  ", correctsReferenceID: UUID()).validate())
        XCTAssertThrowsError(try NoteReference(kind: .correction, name: "更正", notes: "x").validate())
        let before = try bytes(root)
        let missingTarget = await store.save(note, newReferences: [NoteReference(kind: .correction, name: "更正", notes: "x", correctsReferenceID: UUID())], expected: note.revision)
        XCTAssertFalse(missingTarget); XCTAssertEqual(try bytes(root), before, "a rejected reference leaves the whole save unpublished")
        // Append in one save together with a content change: body, history and references publish as one.
        let file = NoteReference(kind: .file, name: "报告.docx", location: "/private/tmp/no-such-file.docx")
        let link = NoteReference(kind: .link, name: "网页", location: "https://example.test/page")
        var draft = note; draft.body = "新正文"
        let awaited8 = await store.save(draft, newReferences: [file, link], expected: note.revision)
        XCTAssertTrue(awaited8)
        var saved = try XCTUnwrap(store.notes.first)
        XCTAssertEqual(saved.references.map(\.id), [file.id, link.id]); XCTAssertEqual(saved.versions.count, 2)
        XCTAssertEqual(saved.references[0].recordedAt, saved.updatedAt, "registration time is the commit time")
        // References alone create no content version.
        let third = NoteReference(kind: .link, name: "更多", location: "https://example.test/more")
        let awaited9 = await store.save(saved, newReferences: [third], expected: saved.revision)
        XCTAssertTrue(awaited9)
        saved = try XCTUnwrap(store.notes.first); XCTAssertEqual(saved.versions.count, 2); XCTAssertEqual(saved.references.count, 3)
        // Corrections append without rewriting the corrected record; the original stays exactly as registered.
        let correction = NoteReference(kind: .correction, name: "更正说明", notes: "  路径写错了\r\n", correctsReferenceID: file.id)
        let awaited10 = await store.save(saved, newReferences: [correction], expected: saved.revision)
        XCTAssertTrue(awaited10)
        let withCorrection = try XCTUnwrap(store.notes.first)
        XCTAssertEqual(withCorrection.references.count, 4)
        XCTAssertEqual(Array(withCorrection.references.prefix(3)), saved.references, "earlier references are byte-for-byte unchanged")
        XCTAssertEqual(Array(withCorrection.references[3].notes.utf8), Array("  路径写错了\r\n".utf8))
        // Correcting a correction, or reusing an id, is refused.
        let again = NoteReference(kind: .correction, name: "再更正", notes: "x", correctsReferenceID: correction.id)
        let awaited11 = await store.save(withCorrection, newReferences: [again], expected: withCorrection.revision)
        XCTAssertFalse(awaited11)
        let awaited12 = await store.save(withCorrection, newReferences: [link], expected: withCorrection.revision)
        XCTAssertFalse(awaited12)
        // A stale window carrying fewer references cannot shrink the stored list.
        var staleView = withCorrection; staleView.references = []
        let awaited13 = await store.save(staleView, expected: withCorrection.revision)
        XCTAssertTrue(awaited13)
        XCTAssertEqual(store.notes.first?.references.count, 4)
        // Restoring the body does not undo references or corrections (covered in the restore test as well).
        let v1 = try XCTUnwrap(store.notes.first?.versions.first)
        let latest = try XCTUnwrap(store.notes.first)
        let awaited14 = await store.restore(noteID: latest.id, versionID: v1.id, expectedRevision: latest.revision)
        XCTAssertEqual(awaited14, .restored)
        XCTAssertEqual(store.notes.first?.references.count, 4)
        // Reference capacity.
        var many = try XCTUnwrap(store.notes.first)
        let refs = (0..<(PersonalNotesLimits.referencesPerNote - 4)).map { NoteReference(kind: .link, name: "r\($0)", location: "https://example.test/\($0)") }
        let awaited15 = await store.save(many, newReferences: refs, expected: many.revision)
        XCTAssertTrue(awaited15)
        many = try XCTUnwrap(store.notes.first)
        XCTAssertEqual(many.references.count, PersonalNotesLimits.referencesPerNote)
        let awaited16 = await store.save(many, newReferences: [NoteReference(kind: .link, name: "多", location: "https://example.test/x")], expected: many.revision)
        XCTAssertFalse(awaited16)
        if case .capacityExceeded = store.error {} else { XCTFail("\(String(describing: store.error))") }
    }

    func testExplicitOpenOnlyKeepsInvalidReferencesAndHonorsIsolationRoot() async throws {
        let sandbox = newRoot(); try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        let real = sandbox.appendingPathComponent("资料.txt"); try Data("内容".utf8).write(to: real)
        let directory = sandbox.appendingPathComponent("目录"); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let symlink = sandbox.appendingPathComponent("链接.txt"); try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: real)
        let missing = sandbox.appendingPathComponent("已移动.txt")
        let mtime = try FileManager.default.attributesOfItem(atPath: real.path)[.modificationDate] as? Date
        let root = newRoot(), store = await loaded(root)
        let note = try await create(store)
        let refs: [NoteReference] = [
            .init(kind: .file, name: "存在", location: real.path), .init(kind: .file, name: "目录", location: directory.path),
            .init(kind: .file, name: "符号链接", location: symlink.path), .init(kind: .file, name: "缺失", location: missing.path),
            .init(kind: .link, name: "网页", location: "https://example.test/x")]
        let awaited17 = await store.save(note, newReferences: refs, expected: note.revision)
        XCTAssertTrue(awaited17)
        let saved = try XCTUnwrap(store.notes.first)
        let session = PersonalNoteEditSession(store: store, note: saved)
        var opened: [URL] = []
        session.systemOpen = { opened.append($0); return true }
        XCTAssertEqual(opened.count, 0, "loading and rendering never open anything")
        XCTAssertNil(saved.references[0].unavailableReason())
        XCTAssertNotNil(saved.references[1].unavailableReason()); XCTAssertNotNil(saved.references[2].unavailableReason())
        XCTAssertNotNil(saved.references[3].unavailableReason()); XCTAssertNil(saved.references[4].unavailableReason())
        for reference in saved.references { session.open(reference) }
        XCTAssertEqual(opened.map(\.absoluteString), [URL(fileURLWithPath: real.path).absoluteString, "https://example.test/x"], "only the valid file and link are handed to the system")
        session.open(saved.references[3]); XCTAssertTrue(session.message.contains("不存在") || session.message.contains("不可访问"))
        XCTAssertEqual(store.notes.first?.references, saved.references, "failed references stay registered, path unrepaired")
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: real.path)[.modificationDate] as? Date, mtime, "file is never read or modified")
        session.systemOpen = { _ in false }
        session.open(saved.references[0]); XCTAssertTrue(session.message.contains("未能打开"))
        XCTAssertEqual(store.notes.first?.references.count, 5)
        // Isolated DEBUG launch: file opening needs a temporary reference root and containment.
        func gated(_ referenceRoot: URL?) -> PersonalNoteEditSession {
            let location = PersonalNotesLocation(root: store.location.root, error: nil, isolated: true, referenceRoot: referenceRoot)
            let gatedStore = PersonalNotesStore(storage: makeStorage(try! XCTUnwrap(location.root)), location: location)
            let s = PersonalNoteEditSession(store: gatedStore, note: saved); s.systemOpen = { opened.append($0); return true }
            return s
        }
        opened = []
        gated(nil).open(saved.references[0])
        XCTAssertTrue(opened.isEmpty)
        let elsewhere = newRoot(); try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let outside = gated(elsewhere); outside.open(saved.references[0])
        XCTAssertTrue(opened.isEmpty); XCTAssertTrue(outside.message.contains("隔离"))
        gated(sandbox).open(saved.references[0])
        XCTAssertEqual(opened.map(\.path), [real.path])
        gated(sandbox).open(saved.references[4]); XCTAssertEqual(opened.count, 2, "links are not constrained by the file root")
        // Corrections have nothing to open.
        let correction = NoteReference(kind: .correction, name: "更正", notes: "x", correctsReferenceID: saved.references[0].id)
        XCTAssertThrowsError(try correction.openURL()); XCTAssertNil(correction.unavailableReason())
    }

    func testSessionPendingReferencesAreAppendedOnSaveAndRemovableBeforeThen() async throws {
        let root = newRoot(), store = await loaded(root)
        let session = PersonalNoteEditSession(store: store, note: nil)
        session.draft.title = "带引用"; session.draft.body = "正文"
        session.linkText = "ftp://example.test"; session.addLink()
        XCTAssertTrue(session.pendingReferences.isEmpty); XCTAssertFalse(session.message.isEmpty)
        session.linkText = ""; session.referenceName = ""
        session.referenceName = "官网"; session.linkText = "https://example.test"; session.addLink()
        session.addFile(URL(fileURLWithPath: "/private/tmp/does-not-matter.pdf"))
        XCTAssertEqual(session.pendingReferences.map(\.name), ["官网", "does-not-matter.pdf"])
        session.removePending(session.pendingReferences[1].id)
        XCTAssertEqual(session.pendingReferences.count, 1)
        XCTAssertTrue(session.isDirty)
        let awaited18 = await session.save()
        XCTAssertTrue(awaited18)
        XCTAssertTrue(session.pendingReferences.isEmpty); XCTAssertFalse(session.isDirty)
        XCTAssertEqual(session.baseline?.references.map(\.name), ["官网"]); XCTAssertEqual(session.baseline?.revision, 1)
        session.correctionTarget = session.baseline?.references[0].id; session.correctionText = "链接换了"
        session.addCorrection(); XCTAssertNil(session.correctionTarget)
        let awaited19 = await session.save()
        XCTAssertTrue(awaited19)
        XCTAssertEqual(session.baseline?.references.count, 2); XCTAssertEqual(session.baseline?.references[1].kind, .correction)
    }

    // MARK: 7. Locations, atomicity, UI

    func testLocationResolutionFailsClosedAndReleasePathIsApplicationSupport() throws {
        let id = UUID().uuidString
        let prefix = "/private/tmp/CosmosPersonalNotesPhase1-"
        let bundle = CosmosDebugStorePersistenceBootstrap.isolatedBundleIdentifierPrefix + "notes"
        let valid = PersonalNotesLocation.resolve(isIsolated: true, bundleIdentifier: bundle, arguments: ["--cosmos-notes-fixture-root", prefix + id])
        XCTAssertEqual(valid.root?.path, prefix + id); XCTAssertNil(valid.error); XCTAssertTrue(valid.isolated)
        let failures: [(Bool, String?, [String])] = [
            (true, bundle, []),                                                                   // isolated but no root
            (true, nil, ["--cosmos-notes-fixture-root", prefix + id]),                            // no bundle id
            (true, "com.wangyucosmos.Cosmos-Toolbox", ["--cosmos-notes-fixture-root", prefix + id]), // production bundle
            (true, bundle, ["--cosmos-notes-fixture-root", "/private/tmp/Other-" + id]),          // wrong prefix
            (true, bundle, ["--cosmos-notes-fixture-root", prefix + "not-a-uuid"]),
            (true, bundle, ["--cosmos-notes-fixture-root", prefix + id + "/../x"]),
            (false, bundle, ["--cosmos-notes-fixture-root", prefix + id]),                        // flag without isolation
        ]
        for (isolated, bundleID, arguments) in failures {
            let location = PersonalNotesLocation.resolve(isIsolated: isolated, bundleIdentifier: bundleID, arguments: arguments)
            XCTAssertNil(location.root, "\(arguments)"); XCTAssertEqual(location.error, .unsafePath)
            let blocked = PersonalNotesStore(location: location)
            XCTAssertFalse(blocked.canSave); XCTAssertEqual(blocked.storageIdentity, "blocked")
        }
        let production = PersonalNotesLocation.resolve(isIsolated: false, bundleIdentifier: nil, arguments: [])
        XCTAssertTrue(production.root?.path.hasSuffix("Application Support/Cosmos OS/PersonalNotes") == true)
        XCTAssertFalse(production.isolated)
    }

    func testStorageSurvivesInterruptedWritesWithoutHalfPublishedState() async throws {
        let root = newRoot(), store = await loaded(root, faulty: true)
        let note = try await create(store, body: "A")
        let reference = NoteReference(kind: .link, name: "链接", location: "https://example.test/x")
        var draft = note; draft.body = "B"
        let before = try bytes(root)
        // Body + history + reference are one publish: a failure before the rename leaves none of them.
        fault.arm(.replace)
        let awaited20 = await store.save(draft, newReferences: [reference], expected: note.revision)
        XCTAssertFalse(awaited20)
        fault.arm(nil)
        let afterFailure = try disk(root).notes[0]
        XCTAssertEqual(try bytes(root), before); XCTAssertEqual(afterFailure.body, "A")
        XCTAssertEqual(afterFailure.versions.count, 1); XCTAssertTrue(afterFailure.references.isEmpty)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("notes.backup.json")).count > 0, true)
        XCTAssertFalse(listing(root).contains { $0.hasPrefix(".notes-write-") }, "temporary files are cleaned up")
        let awaited21 = await store.save(draft, newReferences: [reference], expected: note.revision)
        XCTAssertTrue(awaited21)
        let after = try disk(root).notes[0]
        XCTAssertEqual(after.body, "B"); XCTAssertEqual(after.versions.count, 2); XCTAssertEqual(after.references.count, 1)
        // The backup holds the exact pre-write bytes.
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("notes.backup.json")), before)
    }

    func testListEditorAndHubRenderOffscreenWithoutTouchingStorage() async throws {
        let root = newRoot(), store = await loaded(root)
        _ = try await create(store, title: "渲染", body: tricky, category: "视图")
        let stored = try bytes(root), files = listing(root)
        let list = NSHostingView(rootView: PersonalNotesView(store: store)); list.frame = NSRect(x: 0, y: 0, width: 1100, height: 800); list.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(list.fittingSize.height, 0)
        let session = PersonalNoteEditSession(store: store, note: store.notes.first)
        let editor = NSHostingView(rootView: PersonalNoteEditorView(session: session, store: store)); editor.frame = NSRect(x: 0, y: 0, width: 880, height: 740); editor.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(editor.fittingSize.height, 0)
        let fresh = PersonalNoteEditSession(store: store, note: nil)
        let newEditor = NSHostingView(rootView: PersonalNoteEditorView(session: fresh, store: store)); newEditor.frame = NSRect(x: 0, y: 0, width: 880, height: 740); newEditor.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(newEditor.fittingSize.height, 0)
        let missing = newRoot()
        let hub = NSHostingView(rootView: KnowledgeHubView(configuration: .init(dataSource: ZhuowangInMemoryPersistenceDataSource(storage: [:]), isIsolated: true),
            isolatedRoot: nil, notesLocation: PersonalNotesLocation(root: missing, error: nil)))
        hub.frame = NSRect(x: 0, y: 0, width: 1100, height: 800); hub.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(hub.fittingSize.height, 0)
        XCTAssertEqual(try bytes(root), stored); XCTAssertEqual(listing(root), files)
        XCTAssertFalse(exists(missing), "mounting the hub does not initialise a library")
    }

    // MARK: 8. Unified search identity and navigation

    func testUnifiedSearchFindsNotesByTitleAndCategoryOnlyAndOpensExactUUIDWindow() async throws {
        let root = newRoot(), store = await loaded(root)
        let a = try await create(store, title: "统一检索笔记", body: "只在正文里的秘密词", category: "分类甲")
        let b = try await create(store, title: "统一检索笔记", body: "另一个", category: "分类乙")   // same title, different UUID
        await store.setArchived(try XCTUnwrap(store.notes.first { $0.id == b.id }))
        _ = try await edit(store, try XCTUnwrap(store.notes.first { $0.id == a.id })) { $0.title = "改名后的标题" }
        let reader = UnifiedSearchReader(readPreference: { _ in nil }, roots: [.note: root])
        let snapshot = reader.read()
        XCTAssertEqual(snapshot.states[.note], .ready)
        let rows = snapshot.rows.filter { $0.id.source == .note }
        XCTAssertEqual(Set(rows.map(\.id.objectID)), [a.id, b.id])
        XCTAssertEqual(rows.first { $0.id.objectID == a.id }?.name, "改名后的标题", "searches the current title, not history")
        XCTAssertTrue(rows.contains { UnifiedSearchQuery(text: "改名后").matches($0) })
        XCTAssertFalse(rows.contains { UnifiedSearchQuery(text: "统一检索笔记", includeArchived: true, includeHistory: true).matches($0) && $0.id.objectID == a.id },
                       "old titles in history are not searchable")
        XCTAssertFalse(rows.contains { UnifiedSearchQuery(text: "秘密词", includeArchived: true, includeHistory: true).matches($0) }, "bodies are not searchable")
        XCTAssertTrue(rows.contains { UnifiedSearchQuery(text: "分类甲").matches($0) })
        let archivedRow = try XCTUnwrap(rows.first { $0.id.objectID == b.id })
        XCTAssertTrue(archivedRow.archived); XCTAssertFalse(UnifiedSearchQuery(text: "统一检索").matches(archivedRow))
        XCTAssertTrue(UnifiedSearchQuery(text: "统一检索", includeArchived: true).matches(archivedRow))
        // Exact destination; a vanished note never falls through to a same-named one.
        let rowA = try XCTUnwrap(rows.first { $0.id.objectID == a.id })
        XCTAssertEqual(try UnifiedSearchDestination.resolve(rowA, in: snapshot, isolated: true), .note(a.id))
        var removed = snapshot; removed.rows.removeAll { $0.id == rowA.id }
        XCTAssertThrowsError(try UnifiedSearchDestination.resolve(rowA, in: removed, isolated: false))
        // Navigation opens the existing native window for exactly that UUID, and re-activates instead of duplicating.
        let location = PersonalNotesLocation(root: root, error: nil)
        let navigator = UnifiedSearchNavigator(reader: reader,
            configuration: .init(dataSource: ZhuowangInMemoryPersistenceDataSource(storage: [:]), isIsolated: true),
            projects: .init(root: nil, error: .unsafePath), prompts: .init(root: nil, error: .unsafePath), learning: .init(root: nil, error: .unsafePath),
            notes: location, assetRoot: nil)
        let probe = PersonalNotesStore(location: location)
        await navigator.open(rowA)
        XCTAssertNil(navigator.message, navigator.message ?? "")
        XCTAssertTrue(PersonalNoteWindowManager.shared.hasWindow(store: probe, noteID: a.id))
        XCTAssertFalse(PersonalNoteWindowManager.shared.hasWindow(store: probe, noteID: b.id))
        let count = NSApp.windows.filter { $0.identifier?.rawValue == probe.storageIdentity + "::note::" + a.id.uuidString }.count
        await navigator.open(rowA)
        XCTAssertEqual(NSApp.windows.filter { $0.identifier?.rawValue == probe.storageIdentity + "::note::" + a.id.uuidString }.count, count, "same identity reuses the window")
        XCTAssertEqual(PersonalNoteWindowManager.shared.session(store: probe, noteID: a.id)?.draft.title, "改名后的标题")
        for window in NSApp.windows where window.identifier?.rawValue.hasPrefix(probe.storageIdentity) == true { window.close() }
        XCTAssertFalse(PersonalNoteWindowManager.shared.hasWindow(store: probe, noteID: a.id))
        // A deleted/unreadable library is an explicit navigation failure, not another note.
        try? FileManager.default.removeItem(at: root)
        await navigator.open(rowA)
        XCTAssertNotNil(navigator.message)
    }

    // MARK: 9. Core backup and restore

    private func exportBackup(from notesRoot: URL, into dir: URL, name: String = "backup.zip") throws -> URL {
        // A present preference source keeps older (notes-less) packages restorable in the compatibility tests.
        let source = CoreBackupSource(readPreference: { key in key == CoreBackupSource.keys[0] ? Data("[]".utf8) : nil },
            fileRoots: ["p", "l", "h", "j"].map { dir.appendingPathComponent("empty-" + $0) } + [notesRoot])
        let url = dir.appendingPathComponent(name)
        _ = try CoreBackupService(source: source).export(to: url)
        return url
    }
    private func target(_ dir: URL, notes: URL? = nil) -> CoreRestoreTarget {
        let names = ["restore-p", "restore-l", "restore-h", "restore-j"]
        return CoreRestoreTarget(preferences: NotesRestoreMemory(), roots: names.map { dir.appendingPathComponent($0) } + [notes ?? dir.appendingPathComponent("restore-n")],
            transactionRoot: dir.appendingPathComponent("transaction"))
    }
    /// Rewrites a V3 package as a genuine V1 or V2 one (fixed source list of that version, original exclusions).
    private func downgraded(_ url: URL, to version: Int, in dir: URL) throws -> URL {
        var items = try CoreBackupArchive.decode(Data(contentsOf: url))
        items.removeValue(forKey: "data/notes.json")
        if version == 1 { items.removeValue(forKey: "data/projects.json") }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var manifest = try decoder.decode(CoreBackupManifest.self, from: items["manifest.json"]!)
        manifest.version = version; manifest.exclusions = CoreBackupSource.exclusions
        manifest.sources = manifest.sources.filter { CoreBackupSource.ids(forVersion: version).contains($0.id) }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        items["manifest.json"] = try encoder.encode(manifest)
        let out = dir.appendingPathComponent("legacy-v\(version).zip")
        try CoreBackupArchive.encode(items).write(to: out)
        return out
    }
    private func seedNotes(_ dir: URL) async throws -> (root: URL, note: PersonalNote) {
        let root = dir.appendingPathComponent("source-notes")
        let store = await loaded(root)
        var note = try await create(store, title: "备份笔记", body: tricky, category: "分类")
        note = try await edit(store, note) { $0.body = tricky + "\r\n第二版" }
        let reference = NoteReference(kind: .file, name: "文件", location: dir.appendingPathComponent("never-copied.docx").path)
        let awaited22 = await store.save(note, newReferences: [reference], expected: note.revision)
        XCTAssertTrue(awaited22)
        return (root, try XCTUnwrap(store.notes.first))
    }

    func testNotesJoinCoreBackupAndRestoreIntoEmptyEnvironmentWithOriginalBytes() async throws {
        let dir = newRoot(); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let (notesRoot, note) = try await seedNotes(dir)
        let original = try bytes(notesRoot), sourceListing = listing(notesRoot)
        let url = try exportBackup(from: notesRoot, into: dir)
        let result = try CoreBackupService.verify(url)
        XCTAssertEqual(result.manifest.version, 3); XCTAssertEqual(result.manifest.sources.count, 12)
        XCTAssertEqual(result.manifest.sources.first { $0.id == "notes" }?.status, "present")
        XCTAssertEqual(try CoreBackupArchive.decode(Data(contentsOf: url))["data/notes.json"], original)
        XCTAssertFalse(String(data: try CoreBackupArchive.decode(Data(contentsOf: url))["manifest.json"]!, encoding: .utf8)!.contains("never-copied"))
        XCTAssertFalse(exists(dir.appendingPathComponent("never-copied.docx")), "no file entity exists, none is packaged")
        XCTAssertEqual(try bytes(notesRoot), original); XCTAssertEqual(listing(notesRoot), sourceListing, "export only reads")
        // Restore into an empty environment: bytes, history, references, identities all survive; no file entities appear.
        let plan = try CoreRestoreService.prepare(url)
        XCTAssertEqual(plan.payloads["notes"], original)
        XCTAssertTrue(plan.summaries["notes"]?.contains("notes：1 项") == true)
        let target = self.target(dir), service = CoreRestoreService(target: target)
        try service.restore(plan)
        XCTAssertEqual(try target.read(id: "notes")?.0, original)
        let restoredStore = await loaded(target.roots[4])
        let restored = try XCTUnwrap(restoredStore.notes.first)
        XCTAssertEqual(restored, note)
        XCTAssertEqual(restored.versions.count, 2); XCTAssertEqual(restored.references.count, 1)
        XCTAssertEqual(Array(restored.body.utf8), Array((tricky + "\r\n第二版").utf8))
        XCTAssertFalse(exists(dir.appendingPathComponent("never-copied.docx")))
        XCTAssertEqual(listing(target.roots[4]), ["notes.json"], "no backup/lock files from restore")
        // The restored library keeps working with the normal storage (editing continues from the restored revision).
        _ = try await edit(restoredStore, restored) { $0.body = "恢复后继续编辑" }
        XCTAssertEqual(restoredStore.notes.first?.versions.count, 3)
    }

    func testOlderBackupVersionsStayReadableWithoutInventingNotes() async throws {
        let dir = newRoot(); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let (notesRoot, _) = try await seedNotes(dir)
        let v3 = try exportBackup(from: notesRoot, into: dir)
        for version in [2, 1] {
            let legacy = try downgraded(v3, to: version, in: dir)
            let verified = try CoreBackupService.verify(legacy)
            XCTAssertEqual(verified.manifest.version, version)
            XCTAssertEqual(verified.manifest.sources.count, version == 1 ? 10 : 11)
            XCTAssertTrue(verified.summary.contains("个人笔记"), "older package says clearly that it has no notes")
            // Nothing in the old package is carried into the new source list.
            let work = dir.appendingPathComponent("legacy-work-\(version)")
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let plan = try CoreRestoreService.prepare(legacy)
            XCTAssertNil(plan.payloads["notes"])
            XCTAssertTrue(plan.warnings.contains { $0.contains("个人笔记") && $0.contains("不会建立空的个人笔记库") }, "\(plan.warnings)")
            let target = self.target(work)
            if plan.payloads.isEmpty { continue }
            try CoreRestoreService(target: target).restore(plan)
            XCTAssertFalse(exists(target.roots[4]), "an old package must not create an empty notes library")
        }
        // The 'notes' source cannot be forced into an old-version package, nor omitted from a V3 one.
        let hybrid = try downgraded(v3, to: 2, in: dir)
        var items = try CoreBackupArchive.decode(Data(contentsOf: hybrid))
        items["data/notes.json"] = try Data(contentsOf: notesRoot.appendingPathComponent("notes.json"))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var manifest = try decoder.decode(CoreBackupManifest.self, from: items["manifest.json"]!)
        let body = items["data/notes.json"]!
        manifest.sources.append(.init(id: "notes", status: "present", path: "data/notes.json", bytes: body.count, sha256: CoreBackupService.digest(body), transformation: nil))
        items["manifest.json"] = try encoder.encode(manifest)
        let forced = dir.appendingPathComponent("forced.zip"); try CoreBackupArchive.encode(items).write(to: forced)
        XCTAssertThrowsError(try CoreBackupService.verify(forced), "V2 package with a notes source is invalid")
        var shortItems = try CoreBackupArchive.decode(Data(contentsOf: v3))
        shortItems.removeValue(forKey: "data/notes.json")
        var shortManifest = try decoder.decode(CoreBackupManifest.self, from: shortItems["manifest.json"]!)
        shortManifest.sources.removeAll { $0.id == "notes" }
        shortItems["manifest.json"] = try encoder.encode(shortManifest)
        let omitted = dir.appendingPathComponent("omitted.zip"); try CoreBackupArchive.encode(shortItems).write(to: omitted)
        XCTAssertThrowsError(try CoreBackupService.verify(omitted), "V3 package must list all 12 sources")
    }

    func testBackupRejectsTamperedNotesEvenWhenHashIsRecomputed() async throws {
        let dir = newRoot(); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let (notesRoot, _) = try await seedNotes(dir)
        let v3 = try exportBackup(from: notesRoot, into: dir)
        let original = try CoreBackupArchive.decode(Data(contentsOf: v3))
        let document = try PersonalNotesCoding.decoder().decode(PersonalNotesDocument.self, from: original["data/notes.json"]!)
        func repackaged(_ label: String, _ mutate: (inout PersonalNotesDocument) -> Void) throws -> URL {
            var copy = document; mutate(&copy)
            let body = try PersonalNotesCoding.encoder().encode(copy)
            var items = original; items["data/notes.json"] = body
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            var manifest = try decoder.decode(CoreBackupManifest.self, from: items["manifest.json"]!)
            let index = manifest.sources.firstIndex { $0.id == "notes" }!
            manifest.sources[index] = .init(id: "notes", status: "present", path: "data/notes.json", bytes: body.count, sha256: CoreBackupService.digest(body), transformation: nil)
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            items["manifest.json"] = try encoder.encode(manifest)
            let out = dir.appendingPathComponent(label + ".zip"); try CoreBackupArchive.encode(items).write(to: out); return out
        }
        XCTAssertNoThrow(try CoreBackupService.verify(repackaged("same") { _ in }))
        for (label, mutate) in [("history", { (d: inout PersonalNotesDocument) in d.notes[0].versions[1] = NoteVersion(id: d.notes[0].versions[1].id, number: 2, title: "x", body: "被改", category: nil, recordedAt: Date()) }),
                                ("duplicate", { (d: inout PersonalNotesDocument) in d.notes.append(d.notes[0]) }),
                                ("numbering", { (d: inout PersonalNotesDocument) in d.notes[0].versions.removeFirst() }),
                                ("reference", { (d: inout PersonalNotesDocument) in d.notes[0].references = [NoteReference(kind: .link, name: "坏", location: "mailto:a@b.c")] }),
                                ("schema", { (d: inout PersonalNotesDocument) in d.schemaVersion = 9 })] as [(String, (inout PersonalNotesDocument) -> Void)] {
            let url = try repackaged(label, mutate)
            XCTAssertThrowsError(try CoreBackupService.verify(url), label)
            XCTAssertThrowsError(try CoreRestoreService.prepare(url), label)
        }
        XCTAssertNoThrow(try CoreBackupService.verify(repackaged("empty-library") { $0.notes.removeAll() }), "an established but empty library is valid data")
    }

    func testRestoreNeverOverwritesExistingOrUnsafeNotesTargets() async throws {
        let dir = newRoot(); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let (notesRoot, _) = try await seedNotes(dir)
        let url = try exportBackup(from: notesRoot, into: dir)
        let plan = try CoreRestoreService.prepare(url)
        // An existing notes library (even one that only holds the write lock or a backup) is not an empty environment.
        for name in ["notes.json", "notes.backup.json", ".notes.lock"] {
            let work = dir.appendingPathComponent("existing-" + name)
            let existingRoot = work.appendingPathComponent("restore-n")
            try FileManager.default.createDirectory(at: existingRoot, withIntermediateDirectories: true)
            let mine = Data("我的现有数据".utf8)
            try mine.write(to: existingRoot.appendingPathComponent(name))
            let target = self.target(work)
            XCTAssertThrowsError(try CoreRestoreService(target: target).restore(plan), name)
            XCTAssertEqual(try Data(contentsOf: existingRoot.appendingPathComponent(name)), mine, "\(name) untouched")
            XCTAssertEqual(try CoreRestoreService(target: target).startup(), "existing")
            XCTAssertEqual(listing(existingRoot), [name])
            XCTAssertFalse(exists(target.transactionRoot.appendingPathComponent("state.json")))
        }
        // Real, established notes created by the app itself also block.
        let work = dir.appendingPathComponent("established")
        let live = await loaded(work.appendingPathComponent("restore-n")); _ = try await create(live, title: "已有")
        let before = try bytes(work.appendingPathComponent("restore-n"))
        XCTAssertThrowsError(try CoreRestoreService(target: self.target(work)).restore(plan))
        XCTAssertEqual(try bytes(work.appendingPathComponent("restore-n")), before)
        // Unsafe targets: symlinked notes root.
        let unsafeWork = dir.appendingPathComponent("unsafe")
        try FileManager.default.createDirectory(at: unsafeWork, withIntermediateDirectories: true)
        let real = dir.appendingPathComponent("real-target"); try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let link = unsafeWork.appendingPathComponent("restore-n"); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        XCTAssertThrowsError(try CoreRestoreService(target: self.target(unsafeWork)).restore(plan))
        XCTAssertTrue(listing(real).isEmpty, "nothing written through the link")
        // Preview and the plan alone never write.
        let cleanWork = dir.appendingPathComponent("preview-only")
        let preview = self.target(cleanWork)
        _ = try CoreRestoreService.prepare(url)
        XCTAssertFalse(exists(preview.roots[4])); XCTAssertFalse(exists(preview.transactionRoot))
    }
}
