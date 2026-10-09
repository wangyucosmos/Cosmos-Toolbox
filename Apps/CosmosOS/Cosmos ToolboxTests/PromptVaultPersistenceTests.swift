import XCTest
import Foundation
@testable import Cosmos_Toolbox

nonisolated final class PromptStageFailure: @unchecked Sendable {
    private let lock = NSLock()
    private var stage: PromptStorageStage?
    func fail(_ stage: PromptStorageStage?) { lock.lock(); self.stage = stage; lock.unlock() }
    func check(_ value: PromptStorageStage) throws {
        lock.lock(); defer { lock.unlock() }
        if stage == value { throw PromptVaultError.storage("injected") }
    }
}

@MainActor
final class PromptVaultPersistenceTests: XCTestCase {
    var roots: [URL] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots = []; super.tearDown()
    }
    func root() -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosPromptVaultPhase1-" + UUID().uuidString, isDirectory: true)
        roots.append(root); return root
    }
    func makeFile(_ root: URL, name: String = "templates.json", data: Data) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try data.write(to: root.appendingPathComponent(name))
    }
    func assertFailure(_ operation: () async throws -> Void, _ expected: PromptVaultError) async {
        do { try await operation(); XCTFail("expected failure") }
        catch { XCTAssertEqual(error as? PromptVaultError, expected) }
    }
    func testFirstLoadDoesNotCreateFilesAndRoundTripBodyAndBackup() async throws {
        let root = root(), storage = PromptVaultFileStorage(root: root)
        let empty = try await storage.load()
        XCTAssertTrue(empty.isEmpty); XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        var template = PromptTemplate(name: "  示例  ", body: "\t\r\n😀 e\u{301}\n{{省份}}  ", category: "   ")
        let first = try await storage.save(template, expectedRevision: nil)
        let raw = try Data(contentsOf: storage.primaryURL)
        XCTAssertEqual(first[0].name, "示例"); XCTAssertNil(first[0].category)
        XCTAssertEqual(Data(first[0].body.utf8), Data(template.body.utf8))
        template = first[0]; template.body += "\n追加"
        let second = try await storage.save(template, expectedRevision: 1)
        XCTAssertEqual(try Data(contentsOf: storage.backupURL), raw)
        XCTAssertEqual(second[0].id, first[0].id); XCTAssertEqual(second[0].createdAt, first[0].createdAt)
        XCTAssertEqual(second[0].revision, 2)
        let reopened = try await PromptVaultFileStorage(root: root).load()
        XCTAssertEqual(Data(reopened[0].body.utf8), Data(template.body.utf8))
        let before = try Data(contentsOf: storage.primaryURL)
        _ = try await storage.load()
        XCTAssertEqual(try Data(contentsOf: storage.primaryURL), before)
    }
    func testTwoStoresRejectSameTemplateAndPreserveDifferentTemplateUpdate() async throws {
        let root = root(), one = PromptVaultFileStorage(root: root), two = PromptVaultFileStorage(root: root)
        let a = PromptTemplate(name: "A", body: "a"), b = PromptTemplate(name: "B", body: "b")
        _ = try await one.save(a, expectedRevision: nil); _ = try await one.save(b, expectedRevision: nil)
        var staleA = a; staleA.body = "new A"
        _ = try await two.save(staleA, expectedRevision: 1)
        var staleB = b; staleB.body = "new B"
        let merged = try await one.save(staleB, expectedRevision: 1)
        XCTAssertEqual(merged.first { $0.id == a.id }?.body, "new A")
        XCTAssertEqual(merged.first { $0.id == b.id }?.body, "new B")
        let before = try Data(contentsOf: one.primaryURL)
        await assertFailure({ _ = try await one.save(a, expectedRevision: 1) }, .conflict)
        XCTAssertEqual(try Data(contentsOf: one.primaryURL), before)
    }
    func testCorruptUnknownSchemaDuplicatesAndMissingCoreIdentityLock() async throws {
        let fixtures: [(Data, PromptVaultError)] = [
            (Data("bad".utf8), .corruptData),
            (Data(#"{"schemaVersion":2,"templates":[]}"#.utf8), .unsupportedSchema),
            (Data(#"{"schemaVersion":1,"templates":[{"name":"n","body":"b","createdAt":0}]}"#.utf8), .corruptData)
        ]
        for (data, error) in fixtures {
            let root = root(); try makeFile(root, data: data)
            let storage = PromptVaultFileStorage(root: root)
            await assertFailure({ _ = try await storage.load() }, error)
            await assertFailure({ _ = try await storage.save(PromptTemplate(name: "n", body: "b"), expectedRevision: nil) }, error)
            XCTAssertEqual(try Data(contentsOf: storage.primaryURL), data)
        }
        let root = root(), item = PromptTemplate(name: "n", body: "b")
        let data = try JSONEncoder().encode(PromptVaultDocument(templates: [item, item]))
        try makeFile(root, data: data)
        await assertFailure({ _ = try await PromptVaultFileStorage(root: root).load() }, .duplicateIdentity)
    }
    func testMissingPrimaryWithBackupDoesNotInitialize() async throws {
        let root = root(), raw = Data(#"{"schemaVersion":1,"templates":[]}"#.utf8)
        try makeFile(root, name: "templates.backup.json", data: raw)
        let storage = PromptVaultFileStorage(root: root)
        await assertFailure({ _ = try await storage.save(PromptTemplate(name: "n", body: "b"), expectedRevision: nil) }, .missingPrimaryWithBackup)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.primaryURL.path))
        XCTAssertEqual(try Data(contentsOf: storage.backupURL), raw)
    }
    func testSymlinkParentsPrimaryBackupAndDirectoryRejected() async throws {
        let root = root(), outside = self.root()
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: outside)
        await assertFailure({ _ = try await PromptVaultFileStorage(root: root).load() }, .unsafePath)
        for name in ["templates.json", "templates.backup.json"] {
            let directory = self.root(); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent(name), withDestinationURL: outside)
            await assertFailure({ _ = try await PromptVaultFileStorage(root: directory).load() }, .unsafePath)
        }
        let directory = self.root(); try FileManager.default.createDirectory(at: directory.appendingPathComponent("templates.json"), withIntermediateDirectories: true)
        await assertFailure({ _ = try await PromptVaultFileStorage(root: directory).load() }, .unsafePath)
    }
    func testCompatibilityDefaultsAndCoreBodyRequired() async throws {
        let root = root()
        let raw = Data(#"{"schemaVersion":1,"templates":[{"id":"11111111-2222-4333-8444-555555555555","name":"n","body":"  b\n ","createdAt":0}]}"#.utf8)
        try makeFile(root, data: raw)
        let result = try await PromptVaultFileStorage(root: root).load()
        XCTAssertEqual(result[0].revision, 1); XCTAssertFalse(result[0].isArchived)
        XCTAssertEqual(result[0].createdAt, result[0].updatedAt)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("templates.json")), raw)
    }
    func testFailuresDoNotPublishOrLoseDraftAndUncertainWriteLocks() async throws {
        for stage in [PromptStorageStage.read, .encode, .backup, .backupReadBack, .replace, .readBack] {
            let root = root(), failure = PromptStageFailure()
            let storage = PromptVaultFileStorage(root: root, hook: failure.check)
            let initial = PromptTemplate(name: "n", body: "original")
            _ = try await storage.save(initial, expectedRevision: nil)
            let old = try Data(contentsOf: storage.primaryURL)
            let store = PromptVaultStore(storage: storage); await store.reload()
            let session = PromptTemplateEditSession(store: store, template: initial); session.draft.body = "new"
            failure.fail(stage)
            let saved = await session.save()
            XCTAssertFalse(saved); XCTAssertEqual(store.templates[0].body, "original")
            XCTAssertEqual(session.draft.body, "new"); XCTAssertTrue(session.isDirty)
            XCTAssertFalse(store.canSave)
            if stage == .readBack { XCTAssertEqual(store.error, .uncertainWrite) }
            else { XCTAssertEqual(try Data(contentsOf: storage.primaryURL), old) }
        }
    }
    func testConcurrentDifferentTemplatesUseLatestDiskUnderLock() async throws {
        let root = root(), one = PromptVaultFileStorage(root: root), two = PromptVaultFileStorage(root: root)
        let a = PromptTemplate(name: "A", body: "a"), b = PromptTemplate(name: "B", body: "b")
        // Both tasks are dispatched before either is awaited; flock is the explicit storage synchronization boundary.
        async let left = one.save(a, expectedRevision: nil)
        async let right = two.save(b, expectedRevision: nil)
        _ = try await (left, right)
        let result = try await one.load()
        XCTAssertEqual(Set(result.map(\.id)), Set([a.id, b.id]))
    }
}
