import XCTest
import AppKit
import SwiftUI
@testable import Cosmos_Toolbox

/// Isolated temp roots only; never the production Prompt Vault.
@MainActor
final class PromptVersionHistoryTests: XCTestCase {
    private var roots: [URL] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots = []; super.tearDown()
    }
    private func root() -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosPromptVersionTest-" + UUID().uuidString, isDirectory: true)
        roots.append(root); return root
    }
    private let legacyID = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
    private let legacyBody = "  旧正文 e\u{301}\r\n{{变量}}  "
    private let legacyJSON = Data(#"{"schemaVersion":1,"templates":[{"id":"11111111-2222-4333-8444-555555555555","name":"旧模板","body":"  旧正文 é\r\n{{变量}}  ","category":"工作","isFavorite":true,"isArchived":false,"createdAt":1000,"updatedAt":2000,"revision":7}]}"#.utf8)
    private func writeLegacy(_ root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try legacyJSON.write(to: root.appendingPathComponent("templates.json"))
    }
    private func state(_ root: URL) throws -> [String: Data] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return Dictionary(uniqueKeysWithValues: try names.map { ($0, try Data(contentsOf: root.appendingPathComponent($0))) })
    }
    /// Content files only: a rejected save still creates the (empty) cooperative write lock, as before.
    private func dataState(_ root: URL) throws -> [String: Data] {
        try state(root).filter { $0.key != ".prompt-vault.lock" }
    }
    private func primary(_ root: URL) throws -> Data { try Data(contentsOf: root.appendingPathComponent("templates.json")) }
    private func schemaVersion(_ data: Data) throws -> Int {
        try XCTUnwrap((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["schemaVersion"] as? Int)
    }
    private func edit(_ store: PromptVaultStore, _ id: UUID, _ change: (inout PromptTemplate) -> Void) async throws -> PromptTemplate {
        var draft = try XCTUnwrap(store.templates.first { $0.id == id }); let revision = draft.revision
        change(&draft)
        let saved = await store.save(draft, expectedRevision: revision)
        XCTAssertTrue(saved, store.error?.localizedDescription ?? "")
        return try XCTUnwrap(store.templates.first { $0.id == id })
    }

    // MARK: Legacy data

    func testLegacyLibraryLoadsReadOnlyThenFirstEditKeepsOldBaselineAndNewContentTogether() async throws {
        let root = root(); try writeLegacy(root)
        let before = try state(root)
        let store = PromptVaultStore(root: root); await store.reload()
        let legacy = try XCTUnwrap(store.templates.first)
        XCTAssertTrue(legacy.versions.isEmpty); XCTAssertNil(legacy.contentVersion)
        XCTAssertEqual(legacy.revision, 7, "revision is not turned into invented history")
        let entries = legacy.versionEntries
        XCTAssertEqual(entries.count, 1); XCTAssertEqual(entries[0].kind, .legacyCurrent)
        XCTAssertEqual(entries[0].label, "升级前当前内容"); XCTAssertNil(entries[0].recordedAt)
        XCTAssertEqual(Array(entries[0].body.unicodeScalars), Array(legacyBody.unicodeScalars))
        XCTAssertEqual(try state(root), before, "loading never writes, backs up, locks or upgrades the file")

        // Metadata-only change on a legacy template: no history is manufactured.
        let favoured = try await edit(store, legacy.id) { $0.isFavorite = false }
        XCTAssertTrue(favoured.versions.isEmpty); XCTAssertEqual(favoured.revision, 8)

        let edited = try await edit(store, legacy.id) { $0.body = "新正文 {{变量}}" }
        XCTAssertEqual(edited.versions.map(\.number), [1, 2]); XCTAssertEqual(edited.contentVersion, 2)
        let baseline = edited.versions[0]
        XCTAssertTrue(baseline.isUpgradeBaseline); XCTAssertEqual(baseline.name, "旧模板"); XCTAssertEqual(baseline.category, "工作")
        XCTAssertEqual(Array(baseline.body.unicodeScalars), Array(legacyBody.unicodeScalars))
        XCTAssertEqual(baseline.recordedAt, favoured.updatedAt, "baseline date reuses the existing update time, nothing invented")
        XCTAssertFalse(edited.versions[1].isUpgradeBaseline); XCTAssertEqual(edited.versions[1].body, "新正文 {{变量}}")
        XCTAssertEqual(edited.id, legacyID); XCTAssertEqual(edited.createdAt, Date(timeIntervalSinceReferenceDate: 1000))
        XCTAssertEqual(edited.versionEntries.map(\.kind), [.current, .upgradeBaseline])
        // Written format is schema 2; the pre-edit primary was backed up byte-exact.
        let after = try state(root)
        XCTAssertEqual(try schemaVersion(XCTUnwrap(after["templates.json"])), 2)
        let reopened = try await PromptVaultFileStorage(root: root).load()
        XCTAssertEqual(reopened, store.templates)
    }

    func testFirstContentEditBackupHoldsExactLegacyBytes() async throws {
        let root = root(); try writeLegacy(root)
        let store = PromptVaultStore(root: root); await store.reload()
        _ = try await edit(store, legacyID) { $0.name = "改名" }
        XCTAssertEqual(try state(root)["templates.backup.json"], legacyJSON)
        XCTAssertEqual(try schemaVersion(primary(root)), 2)
    }

    // MARK: Versions

    func testNewTemplateFirstVersionConsecutiveEditsAndReloadKeepExactSnapshots() async throws {
        let root = root(); let store = PromptVaultStore(root: root); await store.reload()
        let original = PromptTemplate(name: "  示例  ", body: "\t\r\n😀 e\u{301}\n{{省份}}  \\{{字面}} ", category: "   ")
        let first = await store.save(original, expectedRevision: nil); XCTAssertTrue(first)
        var current = try XCTUnwrap(store.templates.first)
        XCTAssertEqual(current.versions.map(\.number), [1]); XCTAssertFalse(current.versions[0].isUpgradeBaseline)
        XCTAssertEqual(current.versions[0].name, "示例", "snapshot records the actual saved (trimmed) value")
        XCTAssertNil(current.versions[0].category)
        XCTAssertEqual(Array(current.versions[0].body.unicodeScalars), Array(original.body.unicodeScalars))
        XCTAssertEqual(current.versionEntries.map(\.kind), [.current])
        let bodies = ["第二版\r\n", "第三版  ", "第四版 e\u{301}"]
        for body in bodies { current = try await edit(store, current.id) { $0.body = body } }
        XCTAssertEqual(current.versions.map(\.number), [1, 2, 3, 4]); XCTAssertEqual(current.revision, 4)
        XCTAssertEqual(Set(current.versions.map(\.id)).count, 4)
        // Unicode-equivalent but byte-different text is a real change (String == would hide it).
        let precomposed = try await edit(store, current.id) { $0.body = "第四版 \u{E9}" }
        XCTAssertEqual(precomposed.versions.count, 5)
        let reloaded = try await PromptVaultFileStorage(root: root).load()
        XCTAssertEqual(reloaded, store.templates)
        let stored = try XCTUnwrap(reloaded.first)
        XCTAssertEqual(stored.versions.dropFirst().prefix(3).map { Array($0.body.unicodeScalars) },
                       bodies.map { Array($0.unicodeScalars) })
        XCTAssertEqual(stored.versions.last?.body, stored.body)
        XCTAssertTrue(zip(stored.versions, stored.versions.dropFirst()).allSatisfy { $0.recordedAt <= $1.recordedAt })
    }

    func testMetadataOperationsAndIdenticalSaveNeverCreateContentVersions() async throws {
        let root = root(); let store = PromptVaultStore(root: root); await store.reload()
        let initial = PromptTemplate(name: "n", body: "b", category: "c")
        _ = await store.save(initial, expectedRevision: nil)
        var current = try XCTUnwrap(store.templates.first)
        await store.setFavorite(current); current = try XCTUnwrap(store.templates.first)
        await store.setArchived(current); current = try XCTUnwrap(store.templates.first)
        await store.setArchived(current); current = try XCTUnwrap(store.templates.first)
        XCTAssertTrue(current.isFavorite); XCTAssertFalse(current.isArchived)
        XCTAssertEqual(current.versions.count, 1); XCTAssertEqual(current.revision, 4)
        let same = try await edit(store, current.id) { _ in }
        XCTAssertEqual(same.versions.count, 1, "identical content adds no version"); XCTAssertEqual(same.revision, 5)
        let renamed = try await edit(store, current.id) { $0.category = "d" }
        XCTAssertEqual(renamed.versions.count, 2)
        XCTAssertEqual(renamed.versions[1].category, "d"); XCTAssertEqual(renamed.versions[0].category, "c")
    }

    func testStaleDraftCannotInjectHistoryOrOverwriteNewerRevision() async throws {
        let root = root(); let store = PromptVaultStore(root: root); await store.reload()
        _ = await store.save(PromptTemplate(name: "n", body: "v1"), expectedRevision: nil)
        let stale = try XCTUnwrap(store.templates.first)
        _ = try await edit(store, stale.id) { $0.body = "v2" }
        var forged = stale; forged.body = "stale edit"
        forged.versions = [PromptVersion(number: 1, name: "伪造", body: "伪造", category: nil, recordedAt: Date())]
        let ok = await store.save(forged, expectedRevision: stale.revision)
        XCTAssertFalse(ok); XCTAssertEqual(store.error, .conflict)
        let disk = try await PromptVaultFileStorage(root: root).load()
        XCTAssertEqual(disk.first?.body, "v2"); XCTAssertEqual(disk.first?.versions.map(\.body), ["v1", "v2"])
        // A current-revision draft with forged history keeps only what is on disk.
        var good = try XCTUnwrap(store.templates.first); good.body = "v3"; good.versions = []
        let saved = await store.save(good, expectedRevision: good.revision); XCTAssertTrue(saved)
        XCTAssertEqual(store.templates.first?.versions.map(\.body), ["v1", "v2", "v3"])
    }

    // MARK: Copy and restore

    private func seeded(_ store: PromptVaultStore) async throws -> PromptTemplate {
        _ = await store.save(PromptTemplate(name: "名一", body: "第一版 {{x}}\r\n", category: "甲", isFavorite: true), expectedRevision: nil)
        var t = try XCTUnwrap(store.templates.first)
        t = try await edit(store, t.id) { $0.name = "名二"; $0.body = "第二版  " }
        t = try await edit(store, t.id) { $0.body = "第三版 {{y}}"; $0.category = "乙" }
        await store.setArchived(t)
        return try XCTUnwrap(store.templates.first)
    }

    func testCopyUsesExactlyTheDisplayedVersionAndFailureIsNeverReportedAsSuccess() async throws {
        let store = PromptVaultStore(root: root()); await store.reload()
        let t = try await seeded(store)
        var copied: [String] = []
        let model = PromptVaultViewModel(copy: { copied.append($0); return true })
        XCTAssertEqual(model.viewedEntry(of: t).kind, .current, "default view is the current content")
        let oldest = try XCTUnwrap(t.versionEntries.last)
        model.viewEntry(oldest, of: t)
        XCTAssertEqual(model.viewedEntry(of: t).id, oldest.id)
        XCTAssertTrue(model.copyVersion(model.viewedEntry(of: t)))
        XCTAssertEqual(copied.map { Array($0.unicodeScalars) }, [Array("第一版 {{x}}\r\n".unicodeScalars)])
        XCTAssertNotEqual(copied.first, t.body); XCTAssertTrue(model.historyMessage.contains("v1"))
        let failing = PromptVaultViewModel(copy: { _ in false })
        XCTAssertFalse(failing.copyVersion(oldest))
        XCTAssertTrue(failing.historyMessage.contains("失败")); XCTAssertFalse(failing.historyMessage.contains("已复制"))
        // Current-template rendering still uses only the saved current body.
        let rendered = model.rendered(t)
        XCTAssertEqual(PromptTemplateRenderer(t.body).variables.map(\.name), ["y"]); XCTAssertEqual(rendered.missing, ["y"])
    }

    func testRestoreCreatesNewVersionKeepsHistoryIdentityFlagsAndRejectsNoOpAndStaleWindows() async throws {
        let root = root(); let store = PromptVaultStore(root: root); await store.reload()
        let t = try await seeded(store)
        XCTAssertEqual(t.versions.count, 3); XCTAssertTrue(t.isFavorite); XCTAssertTrue(t.isArchived)
        let v1 = t.versions[0], bytesBefore = try primary(root)
        let model = PromptVaultViewModel(copy: { _ in true })

        // Unsaved edit-window draft: nothing is restored or overwritten.
        let blocked = await model.restore(t.versionEntries.last!, of: t, in: store, hasUnsavedDraft: true)
        XCTAssertFalse(blocked); XCTAssertTrue(model.historyMessage.contains("草稿")); XCTAssertEqual(try primary(root), bytesBefore)

        // Restoring the current version, or content identical to the current, creates nothing.
        let currentRestore = await model.restore(t.versionEntries[0], of: t, in: store, hasUnsavedDraft: false)
        XCTAssertFalse(currentRestore)
        XCTAssertEqual(try primary(root), bytesBefore)
        let identicalTwin = try await edit(store, t.id) { $0.body = "第一版 {{x}}\r\n"; $0.name = "名一"; $0.category = "甲" }
        XCTAssertEqual(identicalTwin.versions.count, 4)   // setup: v4 equals v1's content
        let beforeNoOp = try primary(root)
        let unchanged = await store.restore(templateID: t.id, versionID: v1.id, expectedRevision: identicalTwin.revision)
        XCTAssertEqual(unchanged, .unchanged); XCTAssertEqual(try primary(root), beforeNoOp, "no-op restore writes nothing")
        XCTAssertEqual(store.templates.first?.revision, identicalTwin.revision)

        // Stale window: an older revision cannot restore over newer data.
        let stale = await store.restore(templateID: t.id, versionID: t.versions[1].id, expectedRevision: t.revision)
        XCTAssertEqual(stale, .failed); XCTAssertEqual(store.error, .conflict); XCTAssertEqual(try primary(root), beforeNoOp)
        let missing = await store.restore(templateID: t.id, versionID: UUID(), expectedRevision: identicalTwin.revision)
        XCTAssertEqual(missing, .failed); XCTAssertEqual(try primary(root), beforeNoOp)

        // Real restore of v2 as a new version.
        let latest = try XCTUnwrap(store.templates.first)
        let target = try XCTUnwrap(latest.versionEntries.first { $0.number == 2 })
        let restored = await model.restore(target, of: latest, in: store, hasUnsavedDraft: false)
        XCTAssertTrue(restored)
        let after = try XCTUnwrap(store.templates.first)
        XCTAssertEqual(after.versions.count, 5); XCTAssertEqual(after.contentVersion, 5)
        XCTAssertEqual(Array(after.versions.prefix(4)), latest.versions, "history is untouched")
        XCTAssertEqual(after.name, "名二"); XCTAssertEqual(after.body, "第二版  "); XCTAssertEqual(after.category, "甲")
        XCTAssertEqual(after.id, t.id); XCTAssertEqual(after.createdAt, t.createdAt)
        XCTAssertTrue(after.isFavorite); XCTAssertTrue(after.isArchived)
        XCTAssertEqual(after.revision, latest.revision + 1)
        XCTAssertEqual(after.versions[4].recordedAt, after.updatedAt); XCTAssertNotEqual(after.versions[4].id, target.id)
        let reloadedAfter = try await PromptVaultFileStorage(root: root).load()
        XCTAssertEqual(reloadedAfter, store.templates)
        XCTAssertTrue(model.historyMessage.contains("v5"))
    }

    func testCleanEditorFollowsRestoreButDirtyDraftIsNeverReplaced() async throws {
        let store = PromptVaultStore(root: root()); await store.reload()
        let t = try await seeded(store)
        let clean = PromptTemplateEditSession(store: store, template: t)
        let dirty = PromptTemplateEditSession(store: store, template: t)
        dirty.draft.body = "未保存的草稿"
        let restored = await store.restore(templateID: t.id, versionID: t.versions[0].id, expectedRevision: t.revision)
        XCTAssertEqual(restored, .restored)
        let saved = try XCTUnwrap(store.templates.first)
        clean.adoptSavedIfClean(saved); dirty.adoptSavedIfClean(saved)
        XCTAssertEqual(clean.baseline, saved); XCTAssertEqual(clean.draft, saved); XCTAssertFalse(clean.isDirty)
        XCTAssertEqual(dirty.draft.body, "未保存的草稿"); XCTAssertTrue(dirty.isDirty)
        // The dirty window is behind the new revision: saving conflicts and keeps the draft.
        let ok = await dirty.save(); XCTAssertFalse(ok)
        XCTAssertEqual(dirty.draft.body, "未保存的草稿"); XCTAssertEqual(store.templates.first, saved)
    }

    // MARK: Failure, corruption, capacity

    func testFailuresBeforeAndDuringPublishNeverLeaveHalfUpdatedContentAndHistory() async throws {
        for stage in [PromptStorageStage.encode, .backup, .backupReadBack, .replace] {
            let root = root(); let failure = PromptStageFailure()
            let store = PromptVaultStore(storage: PromptVaultFileStorage(root: root, hook: failure.check)); await store.reload()
            _ = await store.save(PromptTemplate(name: "n", body: "original"), expectedRevision: nil)
            let before = try state(root), snapshot = store.templates
            failure.fail(stage)
            var draft = try XCTUnwrap(store.templates.first); let revision = draft.revision; draft.body = "changed"
            let ok = await store.save(draft, expectedRevision: revision)
            XCTAssertFalse(ok, "\(stage)")
            XCTAssertEqual(store.templates, snapshot, "\(stage)")
            XCTAssertEqual(try primary(root), before["templates.json"], "\(stage)")
        }
        let root = root(); let failure = PromptStageFailure()
        let store = PromptVaultStore(storage: PromptVaultFileStorage(root: root, hook: failure.check)); await store.reload()
        _ = await store.save(PromptTemplate(name: "n", body: "original"), expectedRevision: nil)
        let snapshot = store.templates
        failure.fail(.readBack)
        var draft = try XCTUnwrap(store.templates.first); let revision = draft.revision; draft.body = "changed"
        let ok = await store.save(draft, expectedRevision: revision)
        XCTAssertFalse(ok); XCTAssertEqual(store.error, .uncertainWrite); XCTAssertFalse(store.canSave)
        XCTAssertEqual(store.templates, snapshot, "memory is not published after an uncertain write")
        let onDisk = try await PromptVaultFileStorage(root: root).load()   // load validates content == newest snapshot
        XCTAssertEqual(onDisk.first?.versions.last?.body, onDisk.first?.body)
    }

    func testUnknownCorruptAndInconsistentHistoryFormatsLockSavingWithoutOverwriting() async throws {
        let fixtures = try makeMutations()
        for (label, data, expected) in fixtures {
            let root = root(); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try data.write(to: root.appendingPathComponent("templates.json"))
            let before = try state(root)
            do { _ = try await PromptVaultFileStorage(root: root).load(); XCTFail(label) }
            catch { XCTAssertEqual(error as? PromptVaultError, expected, label) }
            let store = PromptVaultStore(root: root); await store.reload()
            XCTAssertFalse(store.canSave, label)
            let saved = await store.save(PromptTemplate(name: "n", body: "b"), expectedRevision: nil)
            XCTAssertFalse(saved, label); XCTAssertEqual(try state(root), before, label)
        }
    }
    private func makeMutations() throws -> [(String, Data, PromptVaultError)] {
        var doc = PromptVaultDocument()
        var t = PromptTemplate(name: "n", body: "two")
        t.versions = [PromptVersion(number: 1, name: "n", body: "one", category: nil, recordedAt: Date(timeIntervalSinceReferenceDate: 1)),
                      PromptVersion(number: 2, name: "n", body: "two", category: nil, recordedAt: Date(timeIntervalSinceReferenceDate: 2))]
        doc.templates = [t]
        XCTAssertNoThrow(try doc.validate())
        let base = doc
        func variant(_ mutate: (inout PromptVaultDocument) -> Void) throws -> Data {
            var copy = base; mutate(&copy); return try JSONEncoder().encode(copy)
        }
        func rebuilt(_ index: Int, number: Int? = nil, id: UUID? = nil, baseline: Bool = false) -> PromptVersion {
            let v = base.templates[0].versions[index]
            return PromptVersion(id: id ?? v.id, number: number ?? v.number, name: v.name, body: v.body, category: v.category,
                recordedAt: v.recordedAt, isUpgradeBaseline: baseline)
        }
        var futureSchema = try JSONEncoder().encode(base)
        futureSchema = Data(String(decoding: futureSchema, as: UTF8.self).replacingOccurrences(of: "\"schemaVersion\":2", with: "\"schemaVersion\":3").utf8)
        return [
            ("future schema", futureSchema, .unsupportedSchema),
            ("current != newest snapshot", try variant { $0.templates[0].body = "tampered" }, .corruptData),
            ("non-consecutive numbers", try variant { $0.templates[0].versions[1] = rebuilt(1, number: 3) }, .corruptData),
            ("duplicate version id", try variant { $0.templates[0].versions[1] = rebuilt(1, id: base.templates[0].versions[0].id) }, .corruptData),
            ("baseline not first", try variant { $0.templates[0].versions[1] = rebuilt(1, baseline: true) }, .corruptData),
            ("history under schema 1", try variant { $0.schemaVersion = 1 }, .corruptData),
            ("empty snapshot body", try variant { $0.templates[0].versions[0] = PromptVersion(number: 1, name: "n", body: "  ", category: nil, recordedAt: Date()) }, .corruptData),
        ]
    }

    func testVersionCountAndFileSizeLimitsRejectWithoutTrimmingHistoryOrLockingInput() async throws {
        let root = root(); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var doc = PromptVaultDocument(); var t = PromptTemplate(name: "n", body: "b500")
        t.versions = (1...PromptVaultDocument.maxVersionsPerTemplate).map {
            PromptVersion(number: $0, name: "n", body: $0 == PromptVaultDocument.maxVersionsPerTemplate ? "b500" : "b\($0)", category: nil,
                recordedAt: Date(timeIntervalSinceReferenceDate: Double($0)))
        }
        doc.templates = [t]
        try JSONEncoder().encode(doc).write(to: root.appendingPathComponent("templates.json"))
        let before = try dataState(root)
        let store = PromptVaultStore(root: root); await store.reload()
        XCTAssertTrue(store.canSave)
        var draft = try XCTUnwrap(store.templates.first); let revision = draft.revision; draft.body = "one more"
        let session = PromptTemplateEditSession(store: store, template: draft)
        session.draft.body = "one more"
        let ok = await session.save()
        XCTAssertFalse(ok); XCTAssertEqual(session.draft.body, "one more", "input is kept")
        if case .capacityExceeded = store.error {} else { XCTFail("expected capacityExceeded, got \(String(describing: store.error))") }
        XCTAssertTrue(store.canSave, "a limit rejection does not lock the module")
        XCTAssertEqual(store.templates.first?.versions.count, 500); XCTAssertEqual(try dataState(root), before)
        // Metadata-only changes still work at the limit (no new content version needed).
        await store.setFavorite(try XCTUnwrap(store.templates.first))
        XCTAssertEqual(store.templates.first?.isFavorite, true); XCTAssertEqual(store.templates.first?.versions.count, 500)
        XCTAssertEqual(revision + 1, store.templates.first?.revision)

        // 16 MiB total limit: rejected, nothing deleted.
        let big = root.deletingLastPathComponent().appendingPathComponent("CosmosPromptVersionTest-" + UUID().uuidString, isDirectory: true)
        roots.append(big)
        let bigStore = PromptVaultStore(root: big); await bigStore.reload()
        _ = await bigStore.save(PromptTemplate(name: "n", body: "small"), expectedRevision: nil)
        let snapshot = try dataState(big)
        var huge = try XCTUnwrap(bigStore.templates.first); let r = huge.revision
        huge.body = String(repeating: "a", count: 16 * 1024 * 1024)
        let hugeOK = await bigStore.save(huge, expectedRevision: r)
        XCTAssertFalse(hugeOK)
        if case .capacityExceeded = bigStore.error {} else { XCTFail("expected capacityExceeded") }
        XCTAssertTrue(bigStore.canSave); XCTAssertEqual(try dataState(big), snapshot)
        XCTAssertEqual(bigStore.templates.first?.versions.count, 1)
    }

    // MARK: Backup, restore, other modules

    func testBackupExportVerifyAndRestorePlanAcceptNewHistoryAndOldPayloads() async throws {
        let root = root(); let promptRoot = root.appendingPathComponent("prompts")
        let store = PromptVaultStore(root: promptRoot); await store.reload()
        let t = try await seeded(store)
        let v2Raw = try primary(promptRoot)
        XCTAssertNoThrow(try CoreBackupSource.validated(v2Raw, id: "prompts"))
        XCTAssertNoThrow(try CoreBackupSource.validated(legacyJSON, id: "prompts"), "old prompt payloads still accepted")
        var tampered = try XCTUnwrap(String(data: v2Raw, encoding: .utf8))
        tampered = tampered.replacingOccurrences(of: "\"number\":2", with: "\"number\":9")
        XCTAssertThrowsError(try CoreBackupSource.validated(Data(tampered.utf8), id: "prompts"))
        for (label, raw) in [("v2 history", v2Raw), ("v1 legacy", legacyJSON)] {
            let source = root.appendingPathComponent(label.replacingOccurrences(of: " ", with: "-"), isDirectory: true)
            let prompts = source.appendingPathComponent("p", isDirectory: true)
            try FileManager.default.createDirectory(at: prompts, withIntermediateDirectories: true)
            try raw.write(to: prompts.appendingPathComponent("templates.json"))
            let backupSource = CoreBackupSource(readPreference: { _ in nil },
                fileRoots: [prompts, source.appendingPathComponent("l"), source.appendingPathComponent("h"), source.appendingPathComponent("j")])
            let url = source.appendingPathComponent("backup.zip")
            _ = try CoreBackupService(source: backupSource).export(to: url)
            XCTAssertEqual(try CoreBackupArchive.decode(Data(contentsOf: url))["data/prompts.json"], raw, label)
            XCTAssertNoThrow(try CoreBackupService.verify(url), label)
            let plan = try CoreRestoreService.prepare(url)
            XCTAssertEqual(plan.payloads["prompts"], raw, label)
        }
        XCTAssertEqual(t.versions.count, 3)
    }

    func testUnifiedSearchReadsSchema2ButOnlyCurrentTemplateMetadata() async throws {
        let root = root(); let store = PromptVaultStore(root: root); await store.reload()
        let t = try await seeded(store)    // history names: 名一 / 名二, bodies 第一版/第二版/第三版
        let reader = UnifiedSearchReader(readPreference: { _ in nil }, roots: [.prompt: root])
        let snapshot = reader.read()
        XCTAssertEqual(snapshot.states[.prompt], .ready)
        let rows = snapshot.rows.filter { $0.id.source == .prompt }
        XCTAssertEqual(rows.map(\.id.objectID), [t.id])
        let texts = rows.flatMap(\.fields).map(\.text)
        XCTAssertTrue(texts.contains("名二")); XCTAssertFalse(texts.contains("名一"))
        XCTAssertTrue(texts.allSatisfy { !$0.contains("第一版") && !$0.contains("第二版") && !$0.contains("第三版") })
        var query = UnifiedSearchQuery(); query.text = "名一"; query.includeArchived = true; query.includeHistory = true
        XCTAssertFalse(rows.contains { query.matches($0) }, "history names are not searchable")
        query.text = "名二"; XCTAssertTrue(rows.contains { query.matches($0) })
    }

    func testVaultViewMountsOffscreenWithHistoryAndNoWrites() async throws {
        let root = root(); let store = PromptVaultStore(root: root); await store.reload()
        _ = try await seeded(store)
        let before = try dataState(root)
        let view = NSHostingView(rootView: PromptVaultView(location: PromptVaultLocation(root: root, error: nil)))
        view.frame = NSRect(x: 0, y: 0, width: 1100, height: 900); view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(try dataState(root), before, "mounting the view reads only")
    }
}
