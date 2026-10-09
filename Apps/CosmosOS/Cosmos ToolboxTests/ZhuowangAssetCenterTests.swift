import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

final class ZhuowangAssetCenterTests: XCTestCase {
    private func fixture(content: String? = "  # 签到\n\n完整正文  \n", location: String = "") throws -> (AssetMemorySource, UUID, UUID) {
        let campaign = ZhuowangCampaign(name: "秋季活动", scopeType: .other, startDate: Date(), endDate: Date())
        let artifact = ZhuowangArtifact(campaignID: campaign.id, name: "方案", type: .markdown,
            logicalKey: "plan", location: location, content: content, isApprovedVersion: true)
        let workflow = ZhuowangCampaignWorkflow(campaignID: campaign.id, artifacts: [artifact])
        let source = AssetMemorySource()
        source.storage[ZhuowangCampaignStore.storageKey] = try JSONEncoder().encode([campaign])
        source.storage[ZhuowangWorkflowStore.workflowStorageKey] = try JSONEncoder().encode([workflow])
        source.storage[ZhuowangWorkspaceStore.storageKey] = try JSONEncoder().encode(
            ZhuowangWorkspaceSnapshot(modules: [], provinces: [], categories: []))
        return (source, campaign.id, artifact.id)
    }

    func testSnapshotReadsWithoutInitialisingOrWriting() throws {
        let (source, _, _) = try fixture()
        let before = source.storage
        let snapshot = try ZhuowangAssetCatalogReader(dataSource: source).read()
        XCTAssertEqual(snapshot.entries.count, 1)
        XCTAssertEqual(source.storage, before)
        XCTAssertEqual(source.writes, 0)
        let missing = AssetMemorySource()
        let empty = try ZhuowangAssetCatalogReader(dataSource: missing).read()
        XCTAssertTrue(empty.entries.isEmpty)
        XCTAssertEqual(empty.notices.count, 3)
        XCTAssertTrue(missing.storage.isEmpty)
        XCTAssertEqual(missing.writes, 0)
    }

    func testCorruptPrimaryNeverReadsBackupOrPretendsEmpty() throws {
        let (source, _, _) = try fixture()
        source.storage[ZhuowangWorkflowStore.workflowBackupStorageKey] = source.storage[ZhuowangWorkflowStore.workflowStorageKey]
        source.storage[ZhuowangWorkflowStore.workflowStorageKey] = Data("bad".utf8)
        XCTAssertThrowsError(try ZhuowangAssetCatalogReader(dataSource: source).read())
        XCTAssertFalse(source.reads.contains(ZhuowangWorkflowStore.workflowBackupStorageKey))
        XCTAssertEqual(source.writes, 0)
    }

    func testSnapshotChangeHasBoundedRetry() {
        let source = AssetMemorySource()
        source.changing = true
        XCTAssertThrowsError(try ZhuowangAssetCatalogReader(dataSource: source).read())
        XCTAssertLessThanOrEqual(source.reads.count, 16)
        XCTAssertEqual(source.writes, 0)
    }

    func testGroupingCurrentOlderVersionConflictsAndOrphans() throws {
        let (source, campaignID, _) = try fixture()
        var workflows = try JSONDecoder().decode([ZhuowangCampaignWorkflow].self,
            from: source.storage[ZhuowangWorkflowStore.workflowStorageKey]!)
        let adopted = workflows[0].artifacts[0]
        var historical = adopted
        historical = ZhuowangArtifact(campaignID: campaignID, name: adopted.name, type: .markdown,
            logicalKey: adopted.logicalKey, content: "historical", version: 3, isApprovedVersion: false)
        let orphan = ZhuowangArtifact(campaignID: UUID(), name: adopted.name, type: .markdown, content: "orphan", isApprovedVersion: false)
        workflows[0].artifacts += [historical, orphan]
        source.storage[ZhuowangWorkflowStore.workflowStorageKey] = try JSONEncoder().encode(workflows)
        var entries = try ZhuowangAssetCatalogReader(dataSource: source).read().entries
        XCTAssertEqual(entries.filter(ZhuowangAssetFilter().includes).map(\.artifact.version), [1])
        XCTAssertEqual(entries.first { $0.id == orphan.id }?.campaignName, "所属活动缺失")
        XCTAssertEqual(Set(entries.map(\.groupID)).count, 2)
        workflows[0].artifacts[1].isApprovedVersion = true
        source.storage[ZhuowangWorkflowStore.workflowStorageKey] = try JSONEncoder().encode(workflows)
        entries = try ZhuowangAssetCatalogReader(dataSource: source).read().entries
        XCTAssertEqual(entries.filter(ZhuowangAssetFilter().includes).count, 2)
        XCTAssertTrue(entries.filter { $0.artifact.campaignID == campaignID }.allSatisfy { $0.adoptedCount == 2 })
    }

    private func temporaryRoot() throws -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosAssetPhase1-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    private func request(content: String?, path: String = "", id: UUID = UUID()) -> ZhuowangAssetTextRequest {
        ZhuowangAssetTextRequest(id: id, content: content, location: path, readsTextFile: true, searchesText: true)
    }

    func testRawTextComparisonCopyAndControlledPreview() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("方案.md")
        let raw = "  # 签到\n\n完整正文  \n"
        try Data(raw.utf8).write(to: file)
        let before = try Data(contentsOf: file)
        let (source, _, id) = try fixture(content: raw, location: file.path)
        let model = ZhuowangAssetCatalogViewModel(dataSource: source, allowedRoot: root)
        model.refresh()
        let resolved = await model.resolveDetail(id: id)
        let body = try XCTUnwrap(resolved)
        XCTAssertEqual(body.text, raw)
        XCTAssertTrue(body.comparison.contains("一致（已读取"))
        let entry = try XCTUnwrap(model.entries.first)
        let document = ZhuowangAssetCatalogViewModel.document(entry: entry, body: body)
        XCTAssertEqual(document.content, raw)
        XCTAssertNotNil(ZhuowangAssetCatalogViewModel.snippet(body.text, query: "签到"))
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("CosmosAssetTests-\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        var revealed: URL?
        let actions = ZhuowangAssetActions(copy: { text in
            pasteboard.clearContents(); pasteboard.setString(text, forType: .string)
        }, reveal: { revealed = $0 }, preview: { _ in })
        actions.copy(body.text!)
        actions.reveal(file)
        XCTAssertEqual(pasteboard.string(forType: .string), raw)
        XCTAssertEqual(revealed, file)
        XCTAssertEqual(try Data(contentsOf: file), before)
        XCTAssertEqual(source.writes, 0)
    }

    func testFileChangesInvalidateCacheAndMismatchIsExplicit() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("asset.md")
        try Data("original".utf8).write(to: file)
        let reader = ZhuowangAssetTextReader(allowedRoot: root)
        let request = request(content: "original", path: file.path)
        let first = await reader.read(request)
        let cached = await reader.read(request)
        XCTAssertEqual(first, cached)
        let stats = await reader.statistics(); XCTAssertEqual(stats.diskReads, 1)
        try Data("different longer body".utf8).write(to: file)
        let changed = await reader.read(request)
        XCTAssertTrue(changed?.comparison.contains("不一致") == true)
        XCTAssertEqual(changed?.text, "original")
        await reader.invalidate()
        _ = await reader.read(request)
        let final = await reader.statistics(); XCTAssertEqual(final.diskReads, 3)
    }

    func testMissingInvalidPathsAndSymlinksKeepMetadataBody() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let reader = ZhuowangAssetTextReader(allowedRoot: root)
        let file = root.appendingPathComponent("valid.md")
        try Data("file".utf8).write(to: file)
        let link = root.appendingPathComponent("link.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        for path in ["relative.md", "https://example.com/file.md", root.path, link.path,
                     root.appendingPathComponent("missing.md").path, "/etc/hosts"] {
            let body = await reader.read(request(content: "  raw\n", path: path))
            XCTAssertEqual(body?.text, "  raw\n")
            XCTAssertNil(body?.admittedPath)
            XCTAssertFalse(body?.comparison.contains("正文一致") == true)
        }
    }

    func testFileOnlyUTF8AndLimitsNeverTruncate() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("only.txt")
        let raw = "\n file only \n"
        try Data(raw.utf8).write(to: file)
        let reader = ZhuowangAssetTextReader(allowedRoot: root)
        let body = await reader.read(request(content: nil, path: file.path))
        XCTAssertEqual(body?.text, raw)
        XCTAssertEqual(body?.source, "本地文件正文")
        let huge = String(repeating: "x", count: ZhuowangAssetTextReader.bodyLimit + 1)
        let metadata = await reader.read(request(content: huge))
        XCTAssertNil(metadata?.text); XCTAssertNotNil(metadata?.limitation)
        try Data(huge.utf8).write(to: file)
        let oversized = await reader.read(request(content: nil, path: file.path))
        XCTAssertNil(oversized?.text); XCTAssertNotNil(oversized?.limitation)
        try Data([0xff, 0xfe]).write(to: file)
        let invalid = await reader.read(request(content: nil, path: file.path))
        XCTAssertNil(invalid?.text); XCTAssertTrue(invalid?.fileStatus.contains("UTF-8") == true)
    }

    func testCacheBudgetAndCancellation() async {
        let reader = ZhuowangAssetTextReader()
        for _ in 0..<12 {
            _ = await reader.read(request(content: String(repeating: "中", count: 500_000)))
        }
        let stats = await reader.statistics()
        XCTAssertLessThanOrEqual(stats.bytes, ZhuowangAssetTextReader.cacheLimit)
        let task = Task { await reader.read(self.request(content: "cancelled")) }
        task.cancel()
        let result = await task.value
        XCTAssertNil(result)
    }

    func testSearchLatestRequestFiltersAndRefreshRemoval() async throws {
        let (source, _, id) = try fixture()
        let model = ZhuowangAssetCatalogViewModel(dataSource: source)
        model.refresh()
        model.filter.query = "not present"
        model.filter.query = "签到"
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(model.matches.map(\.id), [id])
        XCTAssertNotNil(model.matches.first?.snippet)
        model.filter.type = .pdf
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(model.matches.isEmpty)
        source.storage[ZhuowangWorkflowStore.workflowStorageKey] = try JSONEncoder().encode([ZhuowangCampaignWorkflow]())
        model.refresh()
        let removed = await model.resolveDetail(id: id)
        XCTAssertNil(removed)
        XCTAssertTrue(model.entries.isEmpty)
        XCTAssertEqual(source.writes, 0)
    }

    func testFileOnlyOtherTypeUsesTextPreviewWithoutDefaultReader() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("only.txt")
        try Data("  literal\n".utf8).write(to: file)
        let (source, _, _) = try fixture(content: nil, location: file.path)
        var workflow = try JSONDecoder().decode([ZhuowangCampaignWorkflow].self,
            from: source.storage[ZhuowangWorkflowStore.workflowStorageKey]!)
        workflow[0].artifacts[0].type = .other
        source.storage[ZhuowangWorkflowStore.workflowStorageKey] = try JSONEncoder().encode(workflow)
        let model = ZhuowangAssetCatalogViewModel(dataSource: source, allowedRoot: root)
        model.refresh()
        let entry = try XCTUnwrap(model.entries.first)
        let result = await model.resolveDetail(id: entry.id)
        let body = try XCTUnwrap(result)
        let document = ZhuowangAssetCatalogViewModel.document(entry: entry, body: body)
        XCTAssertEqual(document.content, "  literal\n")
        XCTAssertEqual(document.previewInput.mediaType.classification, .text)
    }

    func testUnicodeComparisonIsByteExactAndUnreadableIsUnverified() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("unicode.md")
        try Data("e\u{301}".utf8).write(to: file)
        let reader = ZhuowangAssetTextReader(allowedRoot: root)
        let body = await reader.read(request(content: "é", path: file.path))
        XCTAssertTrue(body?.comparison.contains("不一致") == true)
        XCTAssertEqual(body?.text?.utf8.map { $0 }, Array("é".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)
        let unreadable = await reader.read(request(content: "metadata", path: file.path))
        XCTAssertEqual(unreadable?.text, "metadata")
        XCTAssertNil(unreadable?.admittedPath)
        XCTAssertTrue(unreadable?.comparison.contains("未核对") == true)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    func testHistoricalSearchAndSameIDMetadataRefresh() async throws {
        let (source, campaignID, id) = try fixture(content: "adopted")
        var workflows = try JSONDecoder().decode([ZhuowangCampaignWorkflow].self,
            from: source.storage[ZhuowangWorkflowStore.workflowStorageKey]!)
        let historical = ZhuowangArtifact(campaignID: campaignID, name: "方案", type: .markdown,
            logicalKey: "plan", content: "history keyword", version: 3)
        workflows[0].artifacts.append(historical)
        source.storage[ZhuowangWorkflowStore.workflowStorageKey] = try JSONEncoder().encode(workflows)
        let model = ZhuowangAssetCatalogViewModel(dataSource: source)
        model.refresh(); model.filter.query = "keyword"
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(model.matches.isEmpty)
        model.filter.allVersions = true
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(model.matches.first?.entry.artifact.version, 3)
        XCTAssertEqual(model.matches.first?.entry.artifact.isApprovedVersion, false)
        workflows[0].artifacts[0].content = "new raw \n"
        source.storage[ZhuowangWorkflowStore.workflowStorageKey] = try JSONEncoder().encode(workflows)
        model.refresh()
        let updated = await model.resolveDetail(id: id)
        XCTAssertEqual(updated?.text, "new raw \n")
        XCTAssertEqual(source.writes, 0)
    }

    func testIsolationFailsClosedWithoutRoot() {
        let source = AssetMemorySource()
        let model = ZhuowangAssetCatalogViewModel(dataSource: source, requiresIsolatedRoot: true)
        model.refresh()
        XCTAssertNotNil(model.error)
        XCTAssertTrue(source.reads.isEmpty)
    }

    func testOffscreenRealViewsAndFixtureExport() async throws {
        let root = try temporaryRoot()
        // Retained temporary evidence, suitable for the isolated App; no formal file is read.
        let file = root.appendingPathComponent("签到方案.md")
        try Data("  # 签到\n完整复用正文\n".utf8).write(to: file)
        let (source, _, id) = try fixture(content: "  # 签到\n完整复用正文\n", location: file.path)
        let model = ZhuowangAssetCatalogViewModel(dataSource: source, allowedRoot: root)
        model.refresh()
        try await Task.sleep(for: .milliseconds(300))
        let view = NSHostingView(rootView: ZhuowangAssetCenterView(model: model))
        view.frame = NSRect(x: 0, y: 0, width: 1180, height: 760)
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: root.appendingPathComponent("center.png"))
        let detail = NSHostingView(rootView: ZhuowangAssetDetailView(model: model,
            groupID: model.entries[0].groupID, selectedID: id))
        detail.frame = NSRect(x: 0, y: 0, width: 960, height: 760)
        detail.layoutSubtreeIfNeeded()
        let detailBitmap = try XCTUnwrap(detail.bitmapImageRepForCachingDisplay(in: detail.bounds))
        detail.cacheDisplay(in: detail.bounds, to: detailBitmap)
        try XCTUnwrap(detailBitmap.representation(using: .png, properties: [:])).write(to: root.appendingPathComponent("detail.png"))
        try PropertyListSerialization.data(fromPropertyList: source.storage, format: .xml, options: 0)
            .write(to: root.appendingPathComponent("fixture.plist"))
        XCTAssertEqual(source.writes, 0)
        print("ASSET_FIXTURE_ROOT=\(root.path)")
    }
}

private final class AssetMemorySource: ZhuowangPersistenceDataSource {
    let domainIdentifier = "CosmosAssetTests-\(UUID())"
    var storage: [String: Data] = [:]
    var reads: [String] = []
    var writes = 0
    var changing = false
    func data(forKey key: String) -> Data? {
        reads.append(key)
        if changing && key == ZhuowangCampaignStore.storageKey {
            return Data("[]".utf8) + Data(repeating: 32, count: reads.count)
        }
        return storage[key]
    }
    func set(_ data: Data, forKey key: String) { writes += 1; storage[key] = data }
}
