import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class CampaignReferencesTests: XCTestCase {
    private func campaign() -> ZhuowangCampaign {
        .init(name: "隔离活动", scopeType: .national, startDate: Date(), endDate: Date())
    }
    private func setup(_ campaigns: [ZhuowangCampaign]) throws -> (ZhuowangInMemoryPersistenceDataSource, ZhuowangCampaignStore) {
        let source = ZhuowangInMemoryPersistenceDataSource(storage: [
            ZhuowangCampaignStore.storageKey: try JSONEncoder().encode(campaigns)
        ])
        let store = ZhuowangCampaignStore(persistenceConfiguration: isolatedConfiguration(dataSource: source))
        source.resetWriteLog()
        return (source, store)
    }
    private func reference(_ id: UUID) -> CampaignExternalReference {
        .init(campaignID: id, kind: .link, name: "  原文 e\u{301}\r\n", versionLabel: " V1  ",
              location: "https://example.com/path?q=1#原文", notes: "  原文\r\n尾部  \n")
    }

    func testLegacyReadIsCompatibleWithoutWritesAndNewRecordsReloadExactly() throws {
        let a = campaign(), b = campaign(), (source, store) = try setup([a, b])
        let before = source.storage[ZhuowangCampaignStore.storageKey]
        XCTAssertNil(store.campaign(id: a.id)?.externalReferences)
        XCTAssertTrue(store.campaign(id: a.id)!.referenceRecords.isEmpty)
        XCTAssertEqual(source.writeCount, 0)
        let ref = reference(a.id)
        XCTAssertEqual(store.appendReference(ref, expectedCount: 0), .succeeded)
        XCTAssertEqual(source.storage[ZhuowangCampaignStore.backupKey], before)
        let reloaded = ZhuowangCampaignStore(persistenceConfiguration: isolatedConfiguration(dataSource: source))
        XCTAssertEqual(reloaded.campaign(id: a.id)?.referenceRecords, [ref])
        XCTAssertEqual(Array(reloaded.campaign(id: a.id)!.referenceRecords[0].notes.utf8), Array(ref.notes.utf8))
        XCTAssertEqual(reloaded.campaign(id: b.id), b)
        XCTAssertEqual(store.updateCampaign(a), .succeeded)
        XCTAssertEqual(store.campaign(id: a.id)?.referenceRecords, [ref])
    }

    func testSharedStoreOldWindowRevisionAndSeparateStoreBaselineCannotOverwrite() throws {
        let a = campaign(), (source, first) = try setup([a])
        let second = ZhuowangCampaignStore(persistenceConfiguration: isolatedConfiguration(dataSource: source))
        let oldDraft = CampaignReferenceDraft(); oldDraft.begin(records: [])
        oldDraft.kind = .link; oldDraft.name = "旧窗口输入"; oldDraft.location = "https://example.com/old"
        XCTAssertEqual(first.appendReference(reference(a.id), expectedCount: 0), .succeeded)
        let primary = source.storage[ZhuowangCampaignStore.storageKey], backup = source.storage[ZhuowangCampaignStore.backupKey]
        XCTAssertFalse(oldDraft.save(store: first, campaignID: a.id))
        XCTAssertEqual(oldDraft.name, "旧窗口输入"); XCTAssertNotNil(oldDraft.message)
        XCTAssertEqual(second.appendReference(reference(a.id), expectedCount: 0), .rejected(.staleConflict))
        XCTAssertEqual(source.storage[ZhuowangCampaignStore.storageKey], primary)
        XCTAssertEqual(source.storage[ZhuowangCampaignStore.backupKey], backup)
    }

    func testCorrectionAppendsOriginalHistoryAndRejectsWrongCampaignMissingOrDuplicateTargets() throws {
        let a = campaign(), b = campaign(), (source, store) = try setup([a, b]), ref = reference(a.id)
        XCTAssertEqual(store.appendReference(ref, expectedCount: 0), .succeeded)
        let correction = CampaignExternalReference(campaignID: a.id, kind: .correction, name: "更正", notes: "  应使用新地址\r\n", correctsReferenceID: ref.id)
        XCTAssertEqual(store.appendReference(correction, expectedCount: 1), .succeeded)
        XCTAssertEqual(store.campaign(id: a.id)?.referenceRecords, [ref, correction])
        let before = source.storage; source.resetWriteLog()
        XCTAssertFalse(store.appendReference(ref, expectedCount: 2).succeeded)
        XCTAssertFalse(store.appendReference(.init(campaignID: b.id, kind: .correction, name: "错误", notes: "更正", correctsReferenceID: ref.id), expectedCount: 0).succeeded)
        XCTAssertFalse(store.appendReference(reference(UUID()), expectedCount: 0).succeeded)
        XCTAssertEqual(source.storage, before); XCTAssertEqual(source.writeCount, 0)
    }

    func testWriteFailuresKeepDraftMemoryAndRecoverableOriginal() throws {
        for key in [ZhuowangCampaignStore.backupKey, ZhuowangCampaignStore.storageKey] {
            let a = campaign(), (source, store) = try setup([a]), before = source.storage[ZhuowangCampaignStore.storageKey]
            source.corruptWritesForKeys = [key]
            let draft = CampaignReferenceDraft(); draft.begin(records: [])
            draft.kind = .link; draft.name = "  待保存  "; draft.location = "https://example.com"; draft.notes = "  e\u{301}\r\n"
            XCTAssertFalse(draft.save(store: store, campaignID: a.id))
            XCTAssertEqual(draft.name, "  待保存  "); XCTAssertEqual(draft.notes, "  e\u{301}\r\n")
            XCTAssertEqual(store.campaigns, [a]); XCTAssertNotNil(draft.message)
            XCTAssertEqual(source.storage[key == ZhuowangCampaignStore.backupKey ? ZhuowangCampaignStore.storageKey : ZhuowangCampaignStore.backupKey], before)
        }
    }

    func testInvalidSchemesAndFileLossRetainRecordWithoutOpeningOrRepairing() throws {
        for text in ["file:///tmp/a", "javascript:alert(1)", "ftp://example.com", "https://", "https://example.com/a b", "relative"] {
            XCTAssertNil(CampaignExternalReference.webURL(text))
        }
        let root = URL(fileURLWithPath: "/private/tmp/CosmosReferenceTest-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("原文.txt"), bytes = Data("不得读取正文".utf8)
        try bytes.write(to: file)
        let a = campaign(), (source, store) = try setup([a])
        let ref = CampaignExternalReference(campaignID: a.id, kind: .file, name: "文件", location: file.path)
        XCTAssertEqual(store.appendReference(ref, expectedCount: 0), .succeeded)
        XCTAssertEqual(try ref.openURL(), file)
        XCTAssertEqual(try Data(contentsOf: file), bytes)
        let link = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try CampaignExternalReference(campaignID: a.id, kind: .file, name: "链接", location: link.path).openURL())
        XCTAssertThrowsError(try CampaignExternalReference(campaignID: a.id, kind: .file, name: "目录", location: root.path).openURL())
        let before = source.storage
        try FileManager.default.moveItem(at: file, to: root.appendingPathComponent("移动.txt"))
        XCTAssertThrowsError(try ref.openURL())
        XCTAssertEqual(store.campaign(id: a.id)?.referenceRecords, [ref]); XCTAssertEqual(source.storage, before)
    }

    func testBackupValidationRejectsBadAssociationAndHistoryWithoutReadingFiles() throws {
        var a = campaign(); let ref = reference(a.id)
        a.externalReferences = [ref]
        try CoreBackupSource.validated(JSONEncoder().encode([a]), id: "campaigns")
        a.externalReferences = [ref, ref]
        XCTAssertThrowsError(try CoreBackupSource.validated(JSONEncoder().encode([a]), id: "campaigns"))
        a.externalReferences = [reference(UUID())]
        XCTAssertThrowsError(try CoreBackupSource.validated(JSONEncoder().encode([a]), id: "campaigns"))
        a.externalReferences = [.init(campaignID: a.id, kind: .correction, name: "更正", notes: "内容", correctsReferenceID: ref.id), ref]
        XCTAssertThrowsError(try CoreBackupSource.validated(JSONEncoder().encode([a]), id: "campaigns"))
    }

    func testRealDetailMountUsesInjectedTemporaryRootAndDoesNotChangeWorkflowOrMetadata() throws {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosReferenceDetail-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var a = campaign(); a.externalReferences = [reference(a.id)]
        let (source, store) = try setup([a])
        source.set(try JSONEncoder().encode([ZhuowangCampaignWorkflow]()), forKey: ZhuowangWorkflowStore.workflowStorageKey)
        source.set(try JSONEncoder().encode([ZhuowangAIProvider]()), forKey: "cosmos.zhuowang.ai.providers.v1")
        let manager = ZhuowangWorkspaceFileManager(rootURL: root)
        XCTAssertTrue(manager.campaignDirectoryURL(provinceName: nil, campaignName: a.name).path.hasPrefix(root.path + "/"))
        let workflowStore = ZhuowangWorkflowStore(persistenceConfiguration: isolatedConfiguration(dataSource: source), workspaceFileManager: manager)
        source.resetWriteLog(); let before = source.storage
        let view = NSHostingView(rootView: ZhuowangCampaignDetailView(store: store, workflowStore: workflowStore, campaignID: a.id, province: nil, module: nil))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 1000), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view; view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        XCTAssertEqual(source.storage, before); XCTAssertEqual(source.writeCount, 0)
        XCTAssertTrue(workflowStore.workflows.isEmpty)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
        window.contentView = nil; window.close()
    }
}
