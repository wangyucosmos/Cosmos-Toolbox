import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

private actor SearchLoadGate {
    var calls = 0
    private var pending: [Int: CheckedContinuation<UnifiedSearchSnapshot, Never>] = [:]
    func load() async -> UnifiedSearchSnapshot {
        calls += 1; let id = calls
        return await withCheckedContinuation { pending[id] = $0 }
    }
    func finish(_ id: Int, _ snapshot: UnifiedSearchSnapshot) { pending.removeValue(forKey: id)?.resume(returning: snapshot) }
}

@MainActor
final class UnifiedSearchTests: XCTestCase {
    private var roots: [URL] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }; roots = []
        super.tearDown()
    }
    private func root() throws -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosUnifiedSearchTest-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        roots.append(root); return root
    }
    private func json(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) }
    private struct Fixture {
        let reader: UnifiedSearchReader
        let source: ZhuowangInMemoryPersistenceDataSource
        let root: URL
        let sharedID: UUID
        let secondCampaignID: UUID
        let artifactID: UUID
        let historicalID: UUID
        let referenceID: UUID
        let fileBytes: [String: Data]
    }
    private func fixture() throws -> Fixture {
        let root = try root(), shared = UUID(), other = UUID(), artifact = UUID(), history = UUID(), refID = UUID(), province = UUID()
        let reference = CampaignExternalReference(id: refID, campaignID: shared, kind: .file, name: "统一 同名资料", versionLabel: "定位标签", location: root.appendingPathComponent("never-read.txt").path, notes: "  原文 e\u{301}\r\n备注定位  \n")
        let a = ZhuowangCampaign(id: shared, name: "统一 同名", scopeType: .province, provinceID: province, startDate: Date(), endDate: Date(), notes: "说明定位", externalReferences: [reference])
        let b = ZhuowangCampaign(id: other, name: "统一 同名", scopeType: .national, moduleID: "national", startDate: Date(), endDate: Date())
        let adopted = ZhuowangArtifact(id: artifact, campaignID: shared, name: "统一 策划", type: .markdown, logicalKey: "plan", location: reference.location, content: "禁止正文命中", version: 1, isApprovedVersion: true)
        let old = ZhuowangArtifact(id: history, campaignID: shared, name: "统一 策划", type: .markdown, logicalKey: "plan", content: "禁止正文命中", version: 3)
        let encoder = JSONEncoder()
        let values: [String: Data] = [
            ZhuowangCampaignStore.storageKey: try encoder.encode([a,b]),
            ZhuowangWorkspaceStore.storageKey: try json(["provinces": [["id": province.uuidString, "name": "浙江"]], "modules": [["id": "national", "name": "全国模块"]]]),
            ZhuowangWorkflowStore.workflowStorageKey: try encoder.encode([ZhuowangCampaignWorkflow(campaignID: shared, artifacts: [adopted,old])])
        ]
        let source = ZhuowangInMemoryPersistenceDataSource(storage: values)
        let project = ["id": shared.uuidString, "name": "统一 同名", "goal": "目标定位", "nextStep": "下一步定位", "isArchived": false, "progress": [["body": "禁止历史命中"]]] as [String: Any]
        let archived = ["id": UUID().uuidString, "name": "统一 归档", "goal": "归档目标", "nextStep": "", "isArchived": true] as [String: Any]
        // Bodies/histories deliberately use incompatible types: field-only decoders must skip them.
        let files = ["projects.json": try json(["schemaVersion": 1, "projects": [project, archived]]),
            "templates.json": try json(["schemaVersion": 1, "templates": [["id": shared.uuidString, "name": "统一 同名", "category": "分类定位", "body": ["ignored": "禁止正文命中"], "isArchived": false]]]),
            "learning.json": try json(["schemaVersion": 1, "topics": [["id": shared.uuidString, "name": "统一 同名", "goal": "学习目标定位", "nextStep": "学习下一步定位", "isArchived": false]], "entries": ["ignored": "禁止历史命中"]]),
            // Note body/history/references use incompatible types: the title/category-only projection must skip them.
            "notes.json": try json(["schemaVersion": 1, "notes": [
                ["id": shared.uuidString, "title": "统一 同名", "category": "笔记归类甲", "isArchived": false, "isFavorite": true, "body": ["ignored": "禁止笔记正文命中"], "versions": ["ignored": "禁止笔记历史命中"], "references": ["ignored": "禁止笔记引用命中"]],
                ["id": UUID().uuidString, "title": "统一 归档笔记", "isArchived": true, "isFavorite": false, "body": "归档正文"]]])]
        for (name, bytes) in files { try bytes.write(to: root.appendingPathComponent(name)) }
        try Data("禁止文件正文命中".utf8).write(to: root.appendingPathComponent("never-read.txt"))
        let protocolSource: any ZhuowangPersistenceDataSource = source
        let reader = UnifiedSearchReader(readPreference: { protocolSource.data(forKey: $0) }, roots: [.project: root, .prompt: root, .learning: root, .note: root])
        return Fixture(reader: reader, source: source, root: root, sharedID: shared, secondCampaignID: other, artifactID: artifact, historicalID: history, referenceID: refID, fileBytes: files)
    }
    func testSevenSourcesIdentityFieldsNoBodiesAndNoBusinessChanges() throws {
        let f = try fixture(), before = f.source.storage, snapshot = f.reader.read()
        XCTAssertEqual(snapshot.states.count, 7)
        XCTAssertTrue(snapshot.states.values.allSatisfy { $0 == .ready })
        let shared = snapshot.rows.filter { $0.id.objectID == f.sharedID }
        XCTAssertEqual(Set(shared.map(\.id)).count, 5) // Campaign, Project, Prompt, Learning, Note with the same UUID.
        XCTAssertEqual(Set(snapshot.rows.map(\.id)).count, snapshot.rows.count)
        let query = UnifiedSearchQuery(text: "统一")
        XCTAssertEqual(Set(snapshot.rows.filter(query.matches).map(\.id.source)).count, 7)
        XCTAssertFalse(snapshot.rows.contains(where: UnifiedSearchQuery(text: "禁止正文命中", includeHistory: true).matches))
        for forbidden in ["禁止笔记正文命中", "禁止笔记历史命中", "禁止笔记引用命中", "归档正文"] {
            XCTAssertFalse(snapshot.rows.contains(where: UnifiedSearchQuery(text: forbidden, includeArchived: true, includeHistory: true).matches), forbidden)
        }
        let note = try XCTUnwrap(snapshot.rows.first { $0.id.source == .note && $0.id.objectID == f.sharedID })
        XCTAssertEqual(note.fields.map(\.label), ["标题", "分类"]); XCTAssertTrue(note.favorite); XCTAssertFalse(note.archived)
        XCTAssertEqual(UnifiedSearchSource.note.title, "个人笔记")
        XCTAssertTrue(UnifiedSearchQuery(text: "笔记归类甲").matches(note))
        // Archived notes are hidden by default and revealed by the same toggle as other archivable sources.
        let archivedNote = try XCTUnwrap(snapshot.rows.first { $0.id.source == .note && $0.archived })
        XCTAssertFalse(UnifiedSearchQuery(text: "归档笔记").matches(archivedNote))
        XCTAssertTrue(UnifiedSearchQuery(text: "归档笔记", includeArchived: true).matches(archivedNote))
        XCTAssertFalse(UnifiedSearchQuery(text: "统一", source: .project).matches(note))
        XCTAssertFalse(snapshot.rows.contains(where: UnifiedSearchQuery(text: "禁止历史命中", includeArchived: true).matches))
        XCTAssertFalse(snapshot.rows.contains(where: UnifiedSearchQuery(text: "禁止文件正文命中").matches))
        XCTAssertEqual(f.source.storage, before); XCTAssertEqual(f.source.writeCount, 0)
        for (name, bytes) in f.fileBytes { XCTAssertEqual(try Data(contentsOf: f.root.appendingPathComponent(name)), bytes) }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: f.root.path).sorted(), ["learning.json","never-read.txt","notes.json","projects.json","templates.json"])
        XCTAssertEqual(snapshot.rows.first { $0.id.objectID == f.artifactID }?.ownership.contains("浙江"), true)
        XCTAssertEqual(snapshot.rows.first { $0.id.objectID == f.secondCampaignID }?.ownership, "全国模块")
        let ref = try XCTUnwrap(snapshot.rows.first { $0.id.objectID == f.referenceID })
        XCTAssertEqual(Array(ref.reference!.notes.utf8), Array("  原文 e\u{301}\r\n备注定位  \n".utf8))
        XCTAssertTrue(UnifiedSearchQuery(text: "备注定位").summary(ref).contains("备注："))
    }
    func testQueriesSourceArchivedHistoryAndExistingConflictPolicy() throws {
        let f = try fixture(), s = f.reader.read()
        XCTAssertTrue(s.rows.filter(UnifiedSearchQuery().matches).isEmpty)
        XCTAssertEqual(s.rows.filter(UnifiedSearchQuery(text: "统一", source: .campaign).matches).count, 2)
        XCTAssertEqual(s.rows.filter(UnifiedSearchQuery(text: "统一", source: .artifact).matches).map(\.id.objectID), [f.artifactID])
        XCTAssertEqual(s.rows.filter(UnifiedSearchQuery(text: "统一", source: .artifact, includeHistory: true).matches).count, 2)
        XCTAssertEqual(s.rows.filter(UnifiedSearchQuery(text: "统一", source: .project).matches).count, 1)
        XCTAssertEqual(s.rows.filter(UnifiedSearchQuery(text: "统一", source: .project, includeArchived: true).matches).count, 2)
        XCTAssertEqual(s.rows.filter(UnifiedSearchQuery(text: "分类定位").matches).first?.id.source, .prompt)
        XCTAssertEqual(s.rows.filter(UnifiedSearchQuery(text: "目标定位").matches).count, 2)
        XCTAssertEqual(s.rows.filter(UnifiedSearchQuery(text: "浙江").matches).first?.id.source, .artifact)
        var values = try XCTUnwrap(try JSONSerialization.jsonObject(with: f.source.storage[ZhuowangWorkflowStore.workflowStorageKey]!) as? [[String: Any]])
        var artifacts = values[0]["artifacts"] as! [[String: Any]]
        artifacts[1]["isApprovedVersion"] = true
        let unapproved: [String: Any] = ["id": UUID().uuidString, "campaignID": f.sharedID.uuidString, "name": "统一 未采用", "type": "markdown", "logicalKey": "plan", "version": 4, "isApprovedVersion": false]
        artifacts.append(unapproved); values[0]["artifacts"] = artifacts
        f.source.storage[ZhuowangWorkflowStore.workflowStorageKey] = try json(values)
        let conflicts = f.reader.read().rows.filter(UnifiedSearchQuery(text: "统一", source: .artifact).matches)
        XCTAssertEqual(conflicts.count, 3); XCTAssertTrue(conflicts.allSatisfy(\.adoptionConflict))
    }
    func testPartialFailureMissingSourceAndDuplicateIdentityNeverBecomeZero() throws {
        let f = try fixture()
        let originalCampaigns = try XCTUnwrap(f.source.storage[ZhuowangCampaignStore.storageKey])
        var campaignPayload = try JSONSerialization.jsonObject(with: originalCampaigns) as! [[String: Any]]
        var refs = campaignPayload[0]["externalReferences"] as! [[String: Any]]
        refs[0]["notes"] = 123; campaignPayload[0]["externalReferences"] = refs
        f.source.storage[ZhuowangCampaignStore.storageKey] = try json(campaignPayload)
        let referenceFailure = f.reader.read()
        XCTAssertEqual(referenceFailure.states[.campaign], .ready)
        if case .failed = referenceFailure.states[.reference] {} else { XCTFail("reference failure must not hide Campaigns") }
        f.source.storage[ZhuowangCampaignStore.storageKey] = originalCampaigns
        f.source.storage[ZhuowangWorkflowStore.workflowStorageKey] = Data("broken".utf8)
        try Data("broken".utf8).write(to: f.root.appendingPathComponent("templates.json"))
        let s = f.reader.read()
        if case .failed = s.states[.artifact] {} else { XCTFail("Artifact failure must be explicit") }
        if case .failed = s.states[.prompt] {} else { XCTFail("Prompt failure must be explicit") }
        XCTAssertEqual(s.states[.campaign], .ready); XCTAssertEqual(s.states[.project], .ready)
        XCTAssertFalse(s.rows.filter(UnifiedSearchQuery(text: "统一").matches).isEmpty)
        f.source.storage[ZhuowangWorkspaceStore.storageKey] = Data("broken".utf8)
        XCTAssertFalse(f.reader.read().notices.isEmpty)
        try json(["schemaVersion": 1, "templates": [["id": f.sharedID.uuidString, "name": "a"], ["id": f.sharedID.uuidString, "name": "b"]]]).write(to: f.root.appendingPathComponent("templates.json"))
        if case .failed = f.reader.read().states[.prompt] {} else { XCTFail("duplicate identity must fail") }
        f.source.storage.removeValue(forKey: ZhuowangCampaignStore.storageKey)
        f.source.storage[ZhuowangCampaignStore.backupKey] = Data("[]".utf8)
        if case .failed = f.reader.read().states[.campaign] {} else { XCTFail("missing primary with backup must fail") }
        XCTAssertEqual(f.source.writeCount, 0)
    }
    func testMissingLibrariesAndIsolationDependenciesFailClosedWithoutInitialization() throws {
        let root = try root(), missing = root.appendingPathComponent("missing")
        let reader = UnifiedSearchReader(readPreference: { _ in nil }, roots: [.project: missing, .prompt: missing, .learning: missing, .note: missing])
        let s = reader.read()
        XCTAssertEqual(s.states.count, 7); XCTAssertTrue(s.states.values.allSatisfy { $0 == .missing })
        XCTAssertTrue(s.rows.isEmpty); XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        let blocked = UnifiedSearchReader(readPreference: { _ in nil }, roots: [:], blocked: [.project: "隔离位置不可用"])
        if case .failed = blocked.read().states[.project] {} else { XCTFail("blocked must not look missing") }
        let link = root.appendingPathComponent("linked")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
        let unsafe = UnifiedSearchReader(readPreference: { _ in nil }, roots: [.project: link])
        if case .failed = unsafe.read().states[.project] {} else { XCTFail("linked root must fail") }
    }
    func testStableNavigationTargetsSameNamesMissingObjectsAndIsolationGate() throws {
        let f = try fixture(), s = f.reader.read()
        let a = try XCTUnwrap(s.rows.first { $0.id.source == .campaign && $0.id.objectID == f.sharedID })
        let b = try XCTUnwrap(s.rows.first { $0.id.source == .campaign && $0.id.objectID == f.secondCampaignID })
        XCTAssertEqual(try UnifiedSearchDestination.resolve(a, in: s, isolated: false), .campaign(f.sharedID))
        XCTAssertEqual(try UnifiedSearchDestination.resolve(b, in: s, isolated: false), .campaign(f.secondCampaignID))
        XCTAssertThrowsError(try UnifiedSearchDestination.resolve(a, in: s, isolated: true))
        let artifact = try XCTUnwrap(s.rows.first { $0.id.objectID == f.historicalID })
        XCTAssertEqual(try UnifiedSearchDestination.resolve(artifact, in: s, isolated: true), .artifact(f.historicalID, campaignID: f.sharedID))
        for source in [UnifiedSearchSource.project, .prompt, .learning, .note] {
            let row = try XCTUnwrap(s.rows.first { $0.id.source == source && $0.id.objectID == f.sharedID })
            let target: UnifiedSearchDestination = source == .project ? .project(f.sharedID) : source == .prompt ? .prompt(f.sharedID) : source == .note ? .note(f.sharedID) : .learning(f.sharedID)
            XCTAssertEqual(try UnifiedSearchDestination.resolve(row, in: s, isolated: true), target)
        }
        var removed = s; removed.rows.removeAll { $0.id == a.id }
        XCTAssertThrowsError(try UnifiedSearchDestination.resolve(a, in: removed, isolated: false))
    }
    func testReferenceInspectionNeverOpensAndExplicitOpenRevalidatesTemporaryBoundary() async throws {
        let f = try fixture(), s = f.reader.read(), row = try XCTUnwrap(s.rows.first { $0.id.objectID == f.referenceID })
        var opened: [URL] = []
        let navigator = UnifiedSearchNavigator(reader: f.reader, configuration: isolatedConfiguration(dataSource: f.source),
            projects: .init(root: f.root, error: nil), prompts: .init(root: f.root, error: nil), learning: .init(root: f.root, error: nil), assetRoot: f.root, systemOpen: { opened.append($0); return true })
        let before = f.source.storage
        await navigator.open(row)
        XCTAssertEqual(navigator.referenceRow?.id, row.id); XCTAssertTrue(opened.isEmpty)
        await navigator.openReference(row)
        XCTAssertEqual(opened, [URL(fileURLWithPath: row.reference!.location)])
        let blocked = UnifiedSearchNavigator(reader: f.reader, configuration: isolatedConfiguration(dataSource: f.source),
            projects: .init(root: nil, error: .unsafePath), prompts: .init(root: nil, error: .unsafePath), learning: .init(root: nil, error: .unsafePath), assetRoot: nil, systemOpen: { opened.append($0); return true })
        await blocked.openReference(row); XCTAssertNotNil(blocked.message); XCTAssertEqual(opened.count, 1)
        XCTAssertEqual(f.source.storage, before); XCTAssertEqual(f.source.writeCount, 0)
    }
    func testIsolatedContainmentAcceptsSystemAliasButRejectsOutsideSiblingTraversalAndSymlinkEscape() throws {
        let fm = FileManager.default, root = try root(), name = root.lastPathComponent
        let aliasRoot = URL(fileURLWithPath: "/tmp/" + name)          // legitimate alias of /private/tmp/<name>
        let inside = root.appendingPathComponent("inside.txt"); try Data("x".utf8).write(to: inside)
        func fail(_ path: String, _ base: URL = root) -> String? { UnifiedSearchNavigator.isolatedContainmentFailure(location: path, root: base) }
        XCTAssertNil(fail(inside.path)); XCTAssertNil(fail(inside.path, aliasRoot))
        XCTAssertNil(fail("/tmp/" + name + "/inside.txt")); XCTAssertNil(fail("/tmp/" + name + "/inside.txt", aliasRoot))
        // Outside the root, including a same-prefix sibling directory (string-prefix checks would accept it).
        let sibling = URL(fileURLWithPath: root.path + "-evil"); roots.append(sibling)
        try fm.createDirectory(at: sibling, withIntermediateDirectories: true)
        let siblingFile = sibling.appendingPathComponent("secret.txt"); try Data("s".utf8).write(to: siblingFile)
        XCTAssertNotNil(fail(siblingFile.path)); XCTAssertNotNil(fail(siblingFile.path, aliasRoot))
        let outside = fm.temporaryDirectory.appendingPathComponent("CosmosOutside-" + UUID().uuidString + ".txt")
        try Data("o".utf8).write(to: outside); roots.append(outside)
        XCTAssertNotNil(fail(outside.path))
        // The root itself is not a file inside the root; missing and traversal paths are rejected with reasons.
        XCTAssertNotNil(fail(root.path)); XCTAssertNotNil(fail(root.path + "/missing.txt"))
        XCTAssertNotNil(fail(root.path + "/../" + name + "-evil/secret.txt")); XCTAssertNotNil(fail("relative.txt"))
        // Symlink escapes (file link and directory link) resolve outside the root and are rejected.
        let fileLink = root.appendingPathComponent("link.txt"); try fm.createSymbolicLink(at: fileLink, withDestinationURL: siblingFile)
        let dirLink = root.appendingPathComponent("dirlink"); try fm.createSymbolicLink(at: dirLink, withDestinationURL: sibling)
        XCTAssertNotNil(fail(fileLink.path)); XCTAssertNotNil(fail(dirLink.path + "/secret.txt")); XCTAssertNotNil(fail(fileLink.path, aliasRoot))
    }
    func testExplicitOpenAcceptsAliasedRootButStillRefusesOutsideAndSymlinkReferences() async throws {
        let f = try fixture(), fm = FileManager.default, s = f.reader.read()
        let aliasRoot = URL(fileURLWithPath: "/tmp/" + f.root.lastPathComponent)
        let row = try XCTUnwrap(s.rows.first { $0.id.objectID == f.referenceID })
        var opened: [URL] = []
        let navigator = UnifiedSearchNavigator(reader: f.reader, configuration: isolatedConfiguration(dataSource: f.source),
            projects: .init(root: f.root, error: nil), prompts: .init(root: f.root, error: nil), learning: .init(root: f.root, error: nil), assetRoot: aliasRoot, systemOpen: { opened.append($0); return true })
        await navigator.openReference(row)
        XCTAssertNil(navigator.message); XCTAssertEqual(opened, [URL(fileURLWithPath: row.reference!.location)])
        // A different (outside) root must refuse without opening anything.
        let other = try root()
        let refused = UnifiedSearchNavigator(reader: f.reader, configuration: isolatedConfiguration(dataSource: f.source),
            projects: .init(root: f.root, error: nil), prompts: .init(root: f.root, error: nil), learning: .init(root: f.root, error: nil), assetRoot: other, systemOpen: { opened.append($0); return true })
        await refused.openReference(row)
        XCTAssertNotNil(refused.message); XCTAssertEqual(opened.count, 1)
        XCTAssertTrue(fm.fileExists(atPath: f.root.appendingPathComponent("never-read.txt").path))
    }
    func testEmptyQueryCacheCancelAndLateResultCannotOverwriteLatestQuery() async throws {
        let gate = SearchLoadGate(), model = UnifiedSearchViewModel(debounce: .zero, load: { await gate.load() })
        model.search(.init()); await Task.yield()
        let initial = await gate.calls; XCTAssertEqual(initial, 0)
        let old = UnifiedSearchRow(id: .init(source: .project, objectID: UUID()), name: "old", ownership: "项目", fields: [.init(label: "名称", text: "old")])
        let new = UnifiedSearchRow(id: .init(source: .learning, objectID: UUID()), name: "new", ownership: "学习", fields: [.init(label: "名称", text: "new")])
        model.search(.init(text: "old"))
        try await Task.sleep(for: .milliseconds(30))
        model.search(.init(text: "new"), refresh: true)
        try await Task.sleep(for: .milliseconds(30))
        await gate.finish(2, .init(rows: [new], states: [.learning: .ready]))
        try await Task.sleep(for: .milliseconds(30))
        await gate.finish(1, .init(rows: [old], states: [.project: .ready]))
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(model.rows.map(\.id), [new.id]); XCTAssertFalse(model.loading)
        model.search(.init(text: "none")); XCTAssertTrue(model.rows.isEmpty)
        let cached = await gate.calls; XCTAssertEqual(cached, 2)
        model.search(.init(text: "old"), refresh: true)
        try await Task.sleep(for: .milliseconds(30)); model.cancel()
        await gate.finish(3, .init(rows: [old])); try await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(model.rows.isEmpty); XCTAssertFalse(model.loading)
        model.search(.init()); XCTAssertTrue(model.states.isEmpty)
    }
    func testSearchViewSafeMountWithMissingRootsHasNoBusinessInitialization() throws {
        let root = try root(), source = ZhuowangInMemoryPersistenceDataSource(storage: [:])
        let protocolSource: any ZhuowangPersistenceDataSource = source
        let reader = UnifiedSearchReader(readPreference: { protocolSource.data(forKey: $0) }, roots: [:])
        let model = UnifiedSearchViewModel(load: { reader.read() })
        let navigator = UnifiedSearchNavigator(reader: reader, configuration: isolatedConfiguration(dataSource: source),
            projects: .init(root: nil, error: .unsafePath), prompts: .init(root: nil, error: .unsafePath), learning: .init(root: nil, error: .unsafePath), assetRoot: nil, systemOpen: { _ in XCTFail("unexpected system open"); return false })
        let view = NSHostingView(rootView: UnifiedSearchView(model: model, navigator: navigator))
        view.frame = NSRect(x: 0, y: 0, width: 1000, height: 800); view.layoutSubtreeIfNeeded()
        XCTAssertEqual(source.storage, [:]); XCTAssertEqual(source.writeCount, 0)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }
}
