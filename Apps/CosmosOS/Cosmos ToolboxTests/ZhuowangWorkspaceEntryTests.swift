import XCTest
import SwiftUI
import AppKit
@testable import Cosmos_Toolbox

@MainActor
final class ZhuowangWorkspaceEntryTests: XCTestCase {
    func testLiveCreationGateForProvinceModuleStoppedAndLocked() {
        let province = ZhuowangProvince(id: UUID(), name: "配置省份", englishName: "Configured")
        let module = ZhuowangModule(id: "quiz", name: "答题", englishName: "Quiz", icon: "questionmark", usesProvinces: false)
        var enabled = true
        func gate(_ p: ZhuowangProvince?, _ m: ZhuowangModule?, _ w: Bool = true, _ c: Bool = true) -> Bool {
            ZhuowangWorkspaceEntry.canCreate(workspaceWritable: w, campaignWritable: c,
                province: p, module: m, isProvinceEnabled: { $0 == province.id && enabled })
        }
        XCTAssertTrue(gate(province, nil)); enabled = false
        XCTAssertFalse(gate(province, nil)); XCTAssertTrue(gate(nil, module))
        XCTAssertFalse(gate(nil, nil)); XCTAssertFalse(gate(nil, module, false))
        XCTAssertFalse(gate(province, nil, true, false))
    }

    func testCreationIdentityFailureAndCancelledFormHaveNoPublishedResidue() throws {
        let source = ZhuowangInMemoryPersistenceDataSource(storage: [ZhuowangCampaignStore.storageKey: Data("[]".utf8)])
        let store = ZhuowangCampaignStore(persistenceConfiguration: isolatedConfiguration(dataSource: source))
        let province = ZhuowangProvince(id: UUID(), name: "配置省份", englishName: "Configured")
        let before = source.storage
        let form = NSHostingView(rootView: ZhuowangCampaignCreateView(store: store, province: province, module: nil))
        form.frame = NSRect(x: 0, y: 0, width: 600, height: 700)
        form.layoutSubtreeIfNeeded()
        XCTAssertEqual(source.storage, before); XCTAssertTrue(store.campaigns.isEmpty)
        let ids = Set(store.campaigns.map(\.id))
        let saved = store.addCampaign(name: "省份活动", scopeType: .province, provinceID: province.id,
            moduleID: "welfare", startDate: Date(), endDate: Date())
        let created = try XCTUnwrap(ZhuowangWorkspaceEntry.createdCampaign(result: saved, previousIDs: ids, campaigns: store.campaigns))
        XCTAssertEqual(created.provinceID, province.id); XCTAssertEqual(created.moduleID, "welfare")
        let previous = Set(store.campaigns.map(\.id))
        let national = store.addCampaign(name: "全国活动", scopeType: .national, moduleID: "national", startDate: Date(), endDate: Date())
        let second = try XCTUnwrap(ZhuowangWorkspaceEntry.createdCampaign(result: national, previousIDs: previous, campaigns: store.campaigns))
        XCTAssertNil(second.provinceID); XCTAssertEqual(second.moduleID, "national")
        let memory = store.campaigns
        source.corruptWritesForKeys = [ZhuowangCampaignStore.backupKey]
        let failed = store.addCampaign(name: "失败活动", scopeType: .other, moduleID: "quiz", startDate: Date(), endDate: Date())
        XCTAssertFalse(failed.succeeded)
        XCTAssertNil(ZhuowangWorkspaceEntry.createdCampaign(result: failed, previousIDs: Set(memory.map(\.id)), campaigns: store.campaigns))
        XCTAssertEqual(store.campaigns, memory)
    }

    func testAssetScopeStepCountsVersionConflictAndReadFailure() throws {
        let provinceID = UUID()
        let campaigns = [
            ZhuowangCampaign(name: "省活动", scopeType: .province, provinceID: provinceID, moduleID: "welfare", startDate: Date(), endDate: Date()),
            ZhuowangCampaign(name: "全国活动", scopeType: .national, moduleID: "national", startDate: Date(), endDate: Date()),
            ZhuowangCampaign(name: "答题活动", scopeType: .other, moduleID: "quiz", startDate: Date(), endDate: Date())]
        var workflows = campaigns.map { campaign in
            var workflow = ZhuowangCampaignWorkflow.standard(campaignID: campaign.id)
            let step = workflow.steps.first { $0.kind == .customerService }!
            workflow.artifacts = [
                ZhuowangArtifact(campaignID: campaign.id, stepID: step.id, name: "不按名称分类", type: .markdown,
                    logicalKey: "faq", content: "current", isApprovedVersion: true),
                ZhuowangArtifact(campaignID: campaign.id, stepID: step.id, name: "历史", type: .markdown,
                    logicalKey: "faq", content: "history", version: 2)]
            return workflow
        }
        let source = ZhuowangInMemoryPersistenceDataSource(storage: [
            ZhuowangCampaignStore.storageKey: try JSONEncoder().encode(campaigns),
            ZhuowangWorkflowStore.workflowStorageKey: try JSONEncoder().encode(workflows)])
        let reader = ZhuowangAssetCatalogReader(dataSource: source)
        var entries = try reader.read().entries
        var filter = ZhuowangAssetFilter(); filter.provinceID = provinceID; filter.stepKind = .customerService
        XCTAssertEqual(entries.filter(filter.includes).count, 1)
        filter.allVersions = true; XCTAssertEqual(entries.filter(filter.includes).count, 2)
        filter.provinceID = nil; filter.moduleID = "national"; filter.allVersions = false
        XCTAssertEqual(entries.filter(filter.includes).map(\.artifact.campaignID), [campaigns[1].id])
        filter.moduleID = "quiz"; XCTAssertEqual(entries.filter(filter.includes).count, 1)
        filter.stepKind = .plan; XCTAssertTrue(entries.filter(filter.includes).isEmpty)
        workflows[1].artifacts[1].isApprovedVersion = true
        source.storage[ZhuowangWorkflowStore.workflowStorageKey] = try JSONEncoder().encode(workflows)
        entries = try reader.read().entries
        filter.moduleID = "national"; filter.stepKind = .customerService
        XCTAssertEqual(entries.filter(filter.includes).count, 2)
        XCTAssertTrue(entries.filter(filter.includes).allSatisfy { $0.adoptedCount == 2 })
        source.storage[ZhuowangWorkflowStore.workflowStorageKey] = Data("bad".utf8)
        XCTAssertThrowsError(try reader.read()); XCTAssertEqual(source.writeCount, 0)
    }
}
