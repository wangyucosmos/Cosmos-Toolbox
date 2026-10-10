import XCTest
import SwiftUI
import AppKit
@testable import Cosmos_Toolbox

@MainActor
final class ZhuowangCategoryPageTests: XCTestCase {
    private func fixture() throws -> (ZhuowangInMemoryPersistenceDataSource, UUID, UUID) {
        let province = UUID()
        let campaigns = [
            ZhuowangCampaign(name: "省份范围", scopeType: .province, provinceID: province, moduleID: "welfare", startDate: Date(), endDate: Date()),
            ZhuowangCampaign(name: "模块范围", scopeType: .national, moduleID: "national", startDate: Date(), endDate: Date())]
        let workflows = campaigns.map { campaign in
            var workflow = ZhuowangCampaignWorkflow.standard(campaignID: campaign.id)
            let faq = workflow.steps.first { $0.kind == .customerService }!
            let prototype = workflow.steps.first { $0.kind == .prototype }!
            workflow.artifacts = [
                ZhuowangArtifact(campaignID: campaign.id, stepID: faq.id, name: "FAQ", type: .markdown,
                    content: "当前客服正文", isApprovedVersion: true),
                ZhuowangArtifact(campaignID: campaign.id, stepID: prototype.id, name: "与文件名无关", type: .html,
                    content: "<p>原型</p>", isApprovedVersion: true),
                ZhuowangArtifact(campaignID: campaign.id, name: "任意名称", type: .flowchart, isApprovedVersion: true),
                ZhuowangArtifact(campaignID: campaign.id, name: "任意名称", type: .image, isApprovedVersion: true),
                ZhuowangArtifact(campaignID: campaign.id, name: "素材流程图原型客服", type: .pdf, isApprovedVersion: true)]
            return workflow
        }
        let source = ZhuowangInMemoryPersistenceDataSource(storage: [
            ZhuowangCampaignStore.storageKey: try JSONEncoder().encode(campaigns),
            ZhuowangWorkflowStore.workflowStorageKey: try JSONEncoder().encode(workflows),
            ZhuowangWorkspaceStore.storageKey: try JSONEncoder().encode(ZhuowangWorkspaceSnapshot(modules: [], provinces: [], categories: []))])
        return (source, province, campaigns[1].id)
    }

    func testStableIDMappingsAndUnsupportedDoNotGuessNames() throws {
        XCTAssertEqual(ZhuowangCategoryRoute(categoryID: "faq"), .assets(step: .customerService, type: nil))
        XCTAssertEqual(ZhuowangCategoryRoute(categoryID: "prototype"), .assets(step: .prototype, type: nil))
        XCTAssertEqual(ZhuowangCategoryRoute(categoryID: "flow"), .assets(step: nil, type: .flowchart))
        XCTAssertEqual(ZhuowangCategoryRoute(categoryID: "asset"), .assets(step: nil, type: .image))
        XCTAssertEqual(ZhuowangCategoryRoute(categoryID: "prompt"), .promptVault)
        for id in ["popup", "banner", "FAQ", "custom", UUID().uuidString, "素材"] {
            XCTAssertEqual(ZhuowangCategoryRoute(categoryID: id), .unsupported)
            XCTAssertNil(ZhuowangCategoryRoute(categoryID: id).filter(provinceID: UUID(), moduleID: nil))
        }
        let renamed = ZhuowangCategory(id: "faq", name: "改名后的分类", englishName: "Renamed", icon: "doc")
        XCTAssertEqual(ZhuowangCategoryRoute(categoryID: renamed.id), .assets(step: .customerService, type: nil))
        XCTAssertNil(ZhuowangCategoryRoute(categoryID: "faq").filter(provinceID: nil, moduleID: nil))
        XCTAssertNil(ZhuowangCategoryRoute(categoryID: "prompt").filter(provinceID: UUID(), moduleID: "national"))
    }

    func testCategoryFiltersIsolateScopesAndTypes() throws {
        let (source, province, national) = try fixture()
        let entries = try ZhuowangAssetCatalogReader(dataSource: source).read().entries
        let expected: [String: ZhuowangArtifactType] = ["faq": .markdown, "prototype": .html, "flow": .flowchart, "asset": .image]
        for (id, type) in expected {
            let route = ZhuowangCategoryRoute(categoryID: id)
            let provinceFilter = try XCTUnwrap(route.filter(provinceID: province, moduleID: "national"))
            let p = entries.filter(provinceFilter.includes)
            XCTAssertEqual(p.count, 1); XCTAssertEqual(p[0].provinceID, province); XCTAssertEqual(p[0].artifact.type, type)
            let moduleFilter = try XCTUnwrap(route.filter(provinceID: nil, moduleID: "national"))
            let m = entries.filter(moduleFilter.includes)
            XCTAssertEqual(m.count, 1); XCTAssertEqual(m[0].artifact.campaignID, national)
            XCTAssertTrue(Set(p.map(\.id)).isDisjoint(with: Set(m.map(\.id))))
            XCTAssertTrue(entries.filter(route.filter(provinceID: UUID(), moduleID: nil)!.includes).isEmpty)
        }
        XCTAssertEqual(source.writeCount, 0)
    }

    private func render<V: View>(_ view: V, to url: URL) throws {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 1100, height: 800)
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
    }

    func testMountedScopeAndCategorySwitchClearPreviousResults() async throws {
        let (source, province, national) = try fixture()
        let before = source.storage
        let model = ZhuowangAssetCatalogViewModel(dataSource: source)
        let faq = try XCTUnwrap(ZhuowangCategoryRoute(categoryID: "faq").filter(provinceID: province, moduleID: nil))
        let prototype = try XCTUnwrap(ZhuowangCategoryRoute(categoryID: "prototype").filter(provinceID: nil, moduleID: "national"))
        let host = NSHostingView(rootView: ZhuowangAssetCenterView(model: model, fixedScope: faq))
        host.frame = NSRect(x: 0, y: 0, width: 1100, height: 800)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        defer { window.contentView = nil }
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(model.filter, faq)
        XCTAssertEqual(model.matches.count, 1)
        XCTAssertEqual(model.matches.first?.entry.provinceID, province)
        host.rootView = ZhuowangAssetCenterView(model: model, fixedScope: prototype)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(model.filter, prototype)
        XCTAssertEqual(model.matches.count, 1)
        XCTAssertEqual(model.matches.first?.entry.artifact.campaignID, national)
        XCTAssertEqual(model.matches.first?.entry.stepKind, .prototype)
        // A late debounced search from the old scope cannot republish it.
        model.filter = faq
        model.filter = prototype
        XCTAssertTrue(model.matches.isEmpty)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(model.matches.first?.entry.artifact.campaignID, national)
        XCTAssertEqual(source.storage, before); XCTAssertEqual(source.writeCount, 0)
    }

    func testEmptyUnsupportedErrorAndNavigationSurfacesAreDistinct() async throws {
        let (source, province, _) = try fixture()
        let root = URL(fileURLWithPath: "/private/tmp/CosmosCategoryUI-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let model = ZhuowangAssetCatalogViewModel(dataSource: source, allowedRoot: root)
        let empty = try XCTUnwrap(ZhuowangCategoryRoute(categoryID: "faq").filter(provinceID: UUID(), moduleID: nil))
        model.filter = empty; model.refresh()
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertNil(model.error); XCTAssertFalse(model.loading); XCTAssertTrue(model.matches.isEmpty)
        try render(ZhuowangAssetCenterView(model: model, fixedScope: empty), to: root.appendingPathComponent("empty.png"))
        let unsupported = ZhuowangCategoryContentView(category: nil, categoryID: "popup", scopeName: "范围",
            provinceID: province, moduleID: nil, model: model, openPromptVault: {})
        try render(unsupported, to: root.appendingPathComponent("unsupported.png"))
        let prompt = ZhuowangCategoryContentView(category: nil, categoryID: "prompt", scopeName: "范围",
            provinceID: province, moduleID: nil, model: model, openPromptVault: {})
        try render(prompt, to: root.appendingPathComponent("prompt.png"))
        source.storage[ZhuowangWorkflowStore.workflowStorageKey] = Data("bad".utf8)
        model.refresh()
        XCTAssertNotNil(model.error); XCTAssertTrue(model.matches.isEmpty)
        try render(ZhuowangAssetCenterView(model: model, fixedScope: empty), to: root.appendingPathComponent("error.png"))
        XCTAssertEqual(source.writeCount, 0)
        print("CATEGORY_UI_EVIDENCE=\(root.path)")
    }
}
