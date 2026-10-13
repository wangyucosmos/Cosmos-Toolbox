import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class ZhuowangNativeSidebarTests: XCTestCase {
    private struct State {
        var navigation: ZhuowangNavigationItem = .workbench
        var category = "campaign"
        var destination: ZhuowangAssetFilter? = ZhuowangAssetFilter()
        var resources = false
        var expanded = false
        var promptCalls = 0

        mutating func select(_ selection: ZhuowangWorkspaceSidebarSelection, stopped: UUID? = nil) -> Bool {
            var calls = 0
            let refresh = selection.apply(navigation: &navigation, categoryID: &category,
                assetDestination: &destination, publicResources: &resources,
                showStoppedProvinces: &expanded, isStopped: { $0 == stopped },
                openPromptVault: { calls += 1 })
            promptCalls += calls
            return refresh
        }
    }

    func testSidebarMappingRoundTripsWorkbenchProvinceModuleAndAssets() {
        for navigation in [ZhuowangNavigationItem.workbench, .province(UUID()), .module("national")] {
            let selected = ZhuowangWorkspaceSidebarSelection(navigation: navigation, publicResources: false)
            XCTAssertEqual(selected.navigation, navigation)
            XCTAssertEqual(ZhuowangWorkspaceSidebarSelection(navigation: navigation, publicResources: true), .assets)
        }
        XCTAssertNil(ZhuowangWorkspaceSidebarSelection.assets.navigation)
        XCTAssertNil(ZhuowangWorkspaceSidebarSelection.promptVault.navigation)
    }

    func testNavigationResetsCategoryAndAssetDestinationAndRequestsRefresh() {
        var state = State()
        state.resources = true
        let id = UUID()
        XCTAssertTrue(state.select(.province(id)))
        XCTAssertEqual(state.navigation, .province(id))
        XCTAssertEqual(state.category, "overview")
        XCTAssertNil(state.destination)
        XCTAssertFalse(state.resources)
        state.category = "faq"
        state.destination = ZhuowangAssetFilter()
        XCTAssertFalse(state.select(.province(id)), "重复选择保持当前分类与概览资产目的地")
        XCTAssertEqual(state.category, "faq")
        XCTAssertNotNil(state.destination)
    }

    func testPromptVaultOnlyCallsActionAndPreservesContentSelection() {
        var state = State()
        state.navigation = .module("national")
        state.resources = true
        state.expanded = true
        let before = state
        XCTAssertFalse(state.select(.promptVault))
        XCTAssertEqual(state.promptCalls, 1)
        XCTAssertEqual(state.navigation, before.navigation)
        XCTAssertEqual(state.category, before.category)
        XCTAssertEqual(state.destination, before.destination)
        XCTAssertEqual(state.resources, before.resources)
        XCTAssertEqual(state.expanded, before.expanded)
        XCTAssertEqual(ZhuowangWorkspaceSidebarSelection(navigation: state.navigation, publicResources: state.resources), .assets)
    }

    func testStoppedProvinceSelectionExpandsWithoutCollapsingOnLaterNavigation() {
        var state = State()
        let stopped = UUID()
        XCTAssertTrue(state.select(.province(stopped), stopped: stopped))
        XCTAssertTrue(state.expanded)
        XCTAssertTrue(state.select(.workbench, stopped: stopped))
        XCTAssertTrue(state.expanded)
    }

    func testAssetsSelectionKeepsLastNavigationAndCategoryAndClearsDestination() {
        var state = State()
        state.navigation = .module("national")
        XCTAssertFalse(state.select(.assets))
        XCTAssertTrue(state.resources)
        XCTAssertNil(state.destination)
        XCTAssertEqual(state.navigation, .module("national"))
        XCTAssertEqual(state.category, "campaign")
        XCTAssertTrue(state.select(.module("national")))
        XCTAssertFalse(state.resources)
        XCTAssertEqual(state.category, "overview")
    }

    func testTableSortsNameDateStatusAndStableTiesInBothDirections() {
        let campaigns = [
            ZhuowangCampaign(name: "B", scopeType: .other, startDate: Date(timeIntervalSince1970: 100),
                endDate: Date(timeIntervalSince1970: 200), status: .planning),
            ZhuowangCampaign(name: "A", scopeType: .other, startDate: Date(timeIntervalSince1970: 300),
                endDate: Date(timeIntervalSince1970: 400), status: .completed)
        ]
        let rows = ZhuowangCampaignProgressBuilder.build(campaigns: campaigns, workflows: [], provinces: [], modules: [], now: Date(timeIntervalSince1970: 0),
            deliverableCounter: { _, _, _, _ in 0 })
        XCTAssertEqual(ZhuowangCampaignTableRow.sorted(rows, using: [KeyPathComparator(\.name)]).map(\.name), ["A", "B"])
        XCTAssertEqual(ZhuowangCampaignTableRow.sorted(rows, using: [KeyPathComparator(\.name, order: .reverse)]).map(\.name), ["B", "A"])
        XCTAssertEqual(ZhuowangCampaignTableRow.sorted(rows, using: [KeyPathComparator(\.startDate)]).map(\.name), ["B", "A"])
        XCTAssertEqual(ZhuowangCampaignTableRow.sorted(rows, using: [KeyPathComparator(\.startDate, order: .reverse)]).map(\.name), ["A", "B"])
        XCTAssertEqual(ZhuowangCampaignTableRow.sorted(rows, using: [KeyPathComparator(\.statusOrder)]).map(\.name), ["B", "A"])
        XCTAssertEqual(ZhuowangCampaignTableRow.sorted(rows, using: [KeyPathComparator(\.statusOrder, order: .reverse)]).map(\.name), ["A", "B"])
        XCTAssertEqual(ZhuowangCampaignTableRow.sorted(Array(rows.reversed()), using: []).map(\.id), rows.map(\.id).sorted { $0.uuidString < $1.uuidString })
        XCTAssertEqual(campaigns.map(\.name), ["B", "A"], "排序只作用于视图投影")
    }

    func testFixedAssetDimensionsCannotEscapeAndResetPreservesScope() {
        var fixed = ZhuowangAssetFilter()
        fixed.provinceID = UUID(); fixed.moduleID = "module"; fixed.stepKind = .plan
        fixed.campaignID = UUID(); fixed.type = .markdown
        var edited = ZhuowangAssetFilter()
        edited.provinceID = UUID(); edited.moduleID = "other"; edited.stepKind = .prototype
        edited.campaignID = UUID(); edited.type = .html; edited.query = "搜索"; edited.allVersions = true
        let result = ZhuowangAssetFilterControls.constrained(edited, to: fixed)
        XCTAssertEqual(result.provinceID, fixed.provinceID)
        XCTAssertEqual(result.moduleID, fixed.moduleID)
        XCTAssertEqual(result.stepKind, fixed.stepKind)
        XCTAssertEqual(result.campaignID, fixed.campaignID)
        XCTAssertEqual(result.type, fixed.type)
        XCTAssertEqual(result.query, "搜索")
        XCTAssertTrue(result.allVersions)
        XCTAssertEqual(ZhuowangAssetFilterControls.reset(fixedScope: fixed), fixed)
    }

    func testUnfixedAssetDimensionsStayEditableAndResetRestoresDefaults() {
        var edited = ZhuowangAssetFilter()
        edited.query = "正文"; edited.allVersions = true; edited.type = .pdf; edited.campaignID = UUID()
        XCTAssertEqual(ZhuowangAssetFilterControls.constrained(edited, to: nil), edited)
        var fixed = ZhuowangAssetFilter(); fixed.provinceID = UUID()
        let result = ZhuowangAssetFilterControls.constrained(edited, to: fixed)
        XCTAssertEqual(result.type, .pdf)
        XCTAssertEqual(result.campaignID, edited.campaignID)
        XCTAssertEqual(result.provinceID, fixed.provinceID)
        XCTAssertEqual(ZhuowangAssetFilterControls.reset(fixedScope: nil), ZhuowangAssetFilter())
    }
}
