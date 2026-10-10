import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class ProjectsTests: XCTestCase {
    private var roots: [URL] = []
    private func root() throws -> URL {
        let url = URL(fileURLWithPath: "/private/tmp/CosmosProjectsTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); roots.append(url); return url
    }
    override func tearDown() { for root in roots { try? FileManager.default.removeItem(at: root) }; roots = []; super.tearDown() }
    private func project() -> PersonalProject {
        PersonalProject(name: "个人项目", goal: "  目标 e\u{301}\r\n尾部  \n", status: .active, nextStep: "  下一步\r\n", progress: [.init(body: "  进展原文 e\u{301}\r\n  ")], references: [.init(kind: .file, name: "缺失文件", location: "/nonexistent/project-reference.md"), .init(kind: .link, name: "参考", location: "https://example.org/project")])
    }
    func testMissingVersusEstablishedEmptyAndZeroReadWrites() async throws {
        let root = try root().appendingPathComponent("absent"), storage = ProjectsFileStorage(root: root)
        let missing = try await storage.load(); XCTAssertFalse(missing.established); XCTAssertTrue(missing.projects.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try ProjectsCoding.encoder().encode(ProjectsDocument()).write(to: storage.primaryURL)
        let empty = try await storage.load(); XCTAssertTrue(empty.established); XCTAssertTrue(empty.projects.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.backupURL.path))
    }
    func testCreateEditReloadOriginalTextAndHistoryPreserved() async throws {
        let storage = ProjectsFileStorage(root: try root()), input = project()
        let saved = try await storage.apply(.save(input, expectedRevision: nil)).projects[0]
        XCTAssertEqual(Data(saved.goal.utf8), Data(input.goal.utf8)); XCTAssertEqual(Data(saved.progress[0].body.utf8), Data(input.progress[0].body.utf8))
        var edited = saved; edited.nextStep = "new\r\n  "; edited.progress.append(.init(body: "第二次\r\n"))
        let result = try await storage.apply(.save(edited, expectedRevision: saved.revision))
        let fresh = try await ProjectsFileStorage(root: storage.root).load()
        XCTAssertEqual(fresh.projects, result.projects); XCTAssertEqual(fresh.projects[0].id, input.id)
        XCTAssertEqual(Data(fresh.projects[0].progress[0].body.utf8), Data(input.progress[0].body.utf8))
        XCTAssertEqual(fresh.projects[0].progress.count, 2); XCTAssertEqual(fresh.projects[0].revision, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.backupURL.path))
    }
    func testFilteringArchiveRestoreAndManualState() async throws {
        let storage = ProjectsFileStorage(root: try root()); var input = project()
        input = try await storage.apply(.save(input, expectedRevision: nil)).projects[0]
        XCTAssertEqual(ProjectsQuery.filter([input], search: "目标", status: .active, archived: false).count, 1)
        XCTAssertTrue(ProjectsQuery.filter([input], search: "", status: .completed, archived: false).isEmpty)
        input.isArchived = true; input = try await storage.apply(.save(input, expectedRevision: input.revision)).projects[0]
        XCTAssertTrue(ProjectsQuery.filter([input], search: "", status: nil, archived: false).isEmpty)
        XCTAssertEqual(ProjectsQuery.filter([input], search: "个人", status: nil, archived: true).count, 1)
        input.isArchived = false; input.status = .completed
        let restored = try await storage.apply(.save(input, expectedRevision: input.revision)).projects[0]
        XCTAssertFalse(restored.isArchived); XCTAssertEqual(restored.status, .completed); XCTAssertEqual(restored.progress.count, 1)
    }
    func testSavedProgressAndReferencesCannotBeRewritten() async throws {
        let storage = ProjectsFileStorage(root: try root())
        let saved = try await storage.apply(.save(project(), expectedRevision: nil)).projects[0]
        let raw = try Data(contentsOf: storage.primaryURL)
        var changed = saved; changed.progress[0].body = "overwrite"
        do { _ = try await storage.apply(.save(changed, expectedRevision: saved.revision)); XCTFail() } catch {}
        changed = saved; changed.references.removeAll()
        do { _ = try await storage.apply(.save(changed, expectedRevision: saved.revision)); XCTFail() } catch {}
        XCTAssertEqual(try Data(contentsOf: storage.primaryURL), raw)
    }
    func testInvalidReferenceIsRetainedAndNoEntityCreated() throws {
        let input = project(); XCTAssertNotNil(input.references[0].availability())
        XCTAssertFalse(FileManager.default.fileExists(atPath: input.references[0].location))
        XCTAssertEqual(input.references.count, 2)
        for text in ["file:///tmp/a", "javascript:alert(1)", "https://user:secret@example.org/a", "http://"] {
            XCTAssertThrowsError(try ProjectReference(kind: .link, name: "bad", location: text).validate())
        }
        XCTAssertNoThrow(try input.validate())
    }
    func testTwoEditorSessionsRejectStaleRevisionPreserveDraft() async throws {
        let storage = ProjectsFileStorage(root: try root())
        let first = ProjectsStore(storage: storage); await first.reload()
        let check1 = await first.save(project(), expected: nil); XCTAssertTrue(check1)
        let second = ProjectsStore(storage: ProjectsFileStorage(root: storage.root)); await second.reload()
        let a = ProjectsEditSession(store: first, project: first.projects[0]), b = ProjectsEditSession(store: second, project: second.projects[0])
        a.draft.nextStep = "first"; let check2 = await a.save(); XCTAssertTrue(check2)
        b.draft.goal = "retained draft"; let check3 = await b.save(); XCTAssertFalse(check3)
        XCTAssertEqual(b.draft.goal, "retained draft"); XCTAssertTrue(b.isDirty); XCTAssertFalse(second.canSave)
        let latest = try await storage.load(); XCTAssertEqual(latest.projects[0].nextStep, "first")
        await b.reload(); XCTAssertEqual(b.draft.nextStep, "first"); XCTAssertFalse(b.isDirty)
    }
    func testWriteFailureKeepsExistingRawAndEditorDraft() async throws {
        let root = try root(), storage = ProjectsFileStorage(root: root)
        _ = try await storage.apply(.save(project(), expectedRevision: nil)); let before = try Data(contentsOf: storage.primaryURL)
        let failing = ProjectsFileStorage(root: root, hook: { stage in if stage == .replace { throw ProjectsError.writeFailed("injected") } })
        let store = ProjectsStore(storage: failing); await store.reload()
        let session = ProjectsEditSession(store: store, project: store.projects[0]); session.progressText = "retained progress"
        let check4 = await session.save(); XCTAssertFalse(check4); XCTAssertEqual(session.progressText, "retained progress"); XCTAssertTrue(session.isDirty)
        XCTAssertEqual(try Data(contentsOf: storage.primaryURL), before); XCTAssertTrue(store.canSave)
    }
    func testCorruptionMissingPrimaryBackupAndSymlinkLockWrites() async throws {
        let root = try root(), storage = ProjectsFileStorage(root: root)
        let bad = Data("broken".utf8); try bad.write(to: storage.primaryURL)
        let store = ProjectsStore(storage: storage); await store.reload(); XCTAssertFalse(store.loaded); XCTAssertFalse(store.canSave)
        let check5 = await store.save(project(), expected: nil); XCTAssertFalse(check5); XCTAssertEqual(try Data(contentsOf: storage.primaryURL), bad)
        try FileManager.default.removeItem(at: storage.primaryURL); try bad.write(to: storage.backupURL)
        await store.reload(); XCTAssertFalse(store.canSave); XCTAssertFalse(FileManager.default.fileExists(atPath: storage.primaryURL.path))
        let other = try self.root(), linked = other.appendingPathComponent("linked")
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: root)
        do { _ = try await ProjectsFileStorage(root: linked).load(); XCTFail() } catch {}
    }
    func testCloseCancelFailureAndQuitFreezeProtection() async throws {
        let store = ProjectsStore(storage: ProjectsFileStorage(root: try root())); await store.reload()
        let session = ProjectsEditSession(store: store, project: nil); session.draft.name = "草稿"
        let check6 = await session.allowClose(choice: .cancel); XCTAssertFalse(check6); XCTAssertTrue(session.isDirty)
        session.progressText = " "
        let check7 = await session.allowClose(choice: .save); XCTAssertFalse(check7); XCTAssertTrue(session.isDirty)
        let check8 = await session.allowClose(choice: .discard); XCTAssertTrue(check8); XCTAssertTrue(session.isDirty)
        ProjectsWindowManager.shared.freezeForTermination(); XCTAssertTrue(ProjectsWindowManager.shared.terminationBlocked)
        ProjectsWindowManager.shared.unfreezeAfterTermination(); XCTAssertFalse(ProjectsWindowManager.shared.terminationBlocked)
    }
    nonisolated private final class Prefs: CoreRestorePreferences {
        var values: [String: Data] = [:]
        func restoreRead(_ key: String) throws -> Data? { values[key] }
        func restoreInsert(_ data: Data, key: String) throws { guard values[key] == nil else { throw CoreRestoreError.invalid("occupied") }; values[key] = data }
        func restoreRemoveOwned(_ data: Data, key: String) throws -> Bool { guard values[key] == data else { return false }; values.removeValue(forKey: key); return true }
    }
    private func backupSource(_ root: URL) -> CoreBackupSource { .init(readPreference: { _ in nil }, fileRoots: ["p", "l", "h", "j", "n"].map { root.appendingPathComponent($0) }) }
    private func restoreTarget(_ root: URL) -> CoreRestoreTarget { .init(preferences: Prefs(), roots: ["p", "l", "h", "j", "n"].map { root.appendingPathComponent($0) }, transactionRoot: root.appendingPathComponent("control")) }
    func testBackupRestoreProjectsExactBytesAndOldV1NotIncluded() async throws {
        let root = try root(), source = backupSource(root)
        let storage = ProjectsFileStorage(root: source.fileRoots[3]); _ = try await storage.apply(.save(project(), expectedRevision: nil))
        let original = try Data(contentsOf: storage.primaryURL), package = root.appendingPathComponent("v3.zip")
        let result = try CoreBackupService(source: source).export(to: package); XCTAssertEqual(result.manifest.version, 3)
        let target = restoreTarget(try self.root()); try CoreRestoreService(target: target).restore(CoreRestoreService.prepare(package))
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(target.fileURL(id: "projects"))), original)
        let loaded = try await ProjectsFileStorage(root: target.roots[3]).load(); XCTAssertEqual(loaded.projects[0].progress.count, 1)
        XCTAssertEqual(loaded.projects[0].references.count, 2)
        var entries = try CoreBackupArchive.decode(Data(contentsOf: package)); entries.removeValue(forKey: "data/projects.json"); entries.removeValue(forKey: "data/notes.json")
        var manifest = result.manifest; manifest.version = 1; manifest.exclusions = CoreBackupSource.exclusions(forVersion: 1); manifest.sources = manifest.sources.filter { CoreBackupSource.ids(forVersion: 1).contains($0.id) }
        // A V1 valid empty Learning payload ensures the old package has one restore item.
        let body = Data("{\"schemaVersion\":1,\"topics\":[],\"entries\":[]}".utf8)
        entries["data/learning.json"] = body
        let index = try XCTUnwrap(manifest.sources.firstIndex { $0.id == "learning" })
        manifest.sources[index] = .init(id: "learning", status: "present", path: "data/learning.json", bytes: body.count, sha256: CoreBackupService.digest(body), transformation: nil)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; entries["manifest.json"] = try encoder.encode(manifest)
        let old = root.appendingPathComponent("v1.zip"); try CoreBackupArchive.encode(entries).write(to: old)
        let oldPlan = try CoreRestoreService.prepare(old); XCTAssertTrue(oldPlan.warnings.contains { $0.contains("未包含 Projects") })
        XCTAssertNil(oldPlan.payloads["projects"])
        let oldTarget = restoreTarget(try self.root()); try CoreRestoreService(target: oldTarget).restore(oldPlan)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldTarget.roots[3].path))
        XCTAssertEqual(try Data(contentsOf: storage.primaryURL), original)
    }
    func testProjectsOccupiedTargetsAndCorruptBackupRejected() async throws {
        let root = try root(), target = restoreTarget(root)
        try FileManager.default.createDirectory(at: target.roots[3], withIntermediateDirectories: true)
        try ProjectsCoding.encoder().encode(ProjectsDocument()).write(to: XCTUnwrap(target.fileURL(id: "projects")))
        XCTAssertThrowsError(try target.requireEmpty())
        try FileManager.default.removeItem(at: XCTUnwrap(target.fileURL(id: "projects")))
        try Data("corrupt".utf8).write(to: target.roots[3].appendingPathComponent("projects.backup.json"))
        XCTAssertThrowsError(try target.requireEmpty()); XCTAssertThrowsError(try CoreBackupService(source: backupSource(root)).export(to: root.appendingPathComponent("refused.zip")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("refused.zip").path))
    }
    func testLimitsDuplicateIDsIsolationAndOffscreenView() async throws {
        var input = project(); input.goal = String(repeating: "x", count: 1024 * 1024 + 1); XCTAssertThrowsError(try input.validate())
        let value = project(); XCTAssertThrowsError(try ProjectsDocument(projects: [value, value]).validate())
        XCTAssertNil(ProjectsLocation.resolve(isIsolated: true, bundleIdentifier: "com.wangyucosmos.cosmostoolbox.persistenceui.projects", arguments: []).root)
        let root = try root(), store = ProjectsStore(storage: ProjectsFileStorage(root: root)); await store.reload()
        let session = ProjectsEditSession(store: store, project: value)
        let view = NSHostingView(rootView: ProjectsEditorView(session: session, store: store, close: {}))
        view.frame = NSRect(x: 0, y: 0, width: 760, height: 900); view.layoutSubtreeIfNeeded(); XCTAssertGreaterThan(view.fittingSize.height, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("projects.json").path))
    }
}
