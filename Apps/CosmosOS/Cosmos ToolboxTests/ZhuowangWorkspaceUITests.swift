import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class ZhuowangWorkspaceUITests: XCTestCase {
    private var roots: [URL] = []
    private var suites: [String] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        for suite in suites { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        super.tearDown()
    }
    private struct Fixture {
        let root: URL
        let source: ZhuowangInMemoryPersistenceDataSource
        let config: ZhuowangStorePersistenceConfiguration
        let workspace: ZhuowangWorkspaceStore
        let campaigns: ZhuowangCampaignStore
        let workflows: ZhuowangWorkflowStore
        let assets: ZhuowangAssetCatalogViewModel
        let provinces: [ZhuowangProvince]
        let modules: [ZhuowangModule]
        var rows: [ZhuowangCampaignProgress] {
            ZhuowangWorkspaceUI.rows(campaigns: campaigns.campaigns, workflows: workflows.workflows,
                provinces: provinces, modules: modules, manager: workflows.workspaceFileManager)
        }
    }
    private func fixture() throws -> Fixture {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosWorkspaceFiles-" + UUID().uuidString, isDirectory: true)
        roots.append(root)
        let provinces = [ZhuowangProvince(id: UUID(), name: "浙江", englishName: "Zhejiang"),
                         ZhuowangProvince(id: UUID(), name: "湖北", englishName: "Hubei"),
                         ZhuowangProvince(id: UUID(), name: "湖南", englishName: "Hunan"),
                         ZhuowangProvince(id: UUID(), name: "河南", englishName: "Henan", isEnabled: false)]
        let modules = [ZhuowangModule(id: "welfare", name: "福利中心", englishName: "Welfare", icon: "gift", usesProvinces: true),
                       ZhuowangModule(id: "national", name: "全国会员促活", englishName: "National", icon: "globe.asia.australia", usesProvinces: false)]
        let categories = [ZhuowangCategory(id: "faq", name: "客服文档", englishName: "FAQ", icon: "headphones"),
                          ZhuowangCategory(id: "prototype", name: "产品原型", englishName: "Prototype", icon: "rectangle.portrait")]
        let source = ZhuowangInMemoryPersistenceDataSource(storage: [
            ZhuowangCampaignStore.storageKey: Data("[]".utf8),
            ZhuowangWorkspaceStore.storageKey: try JSONEncoder().encode(ZhuowangWorkspaceSnapshot(modules: modules, provinces: provinces, categories: categories))])
        let config = ZhuowangStorePersistenceConfiguration(dataSource: source, isIsolated: true, workspaceFilesRootURL: root)
        let workspace = ZhuowangWorkspaceStore(persistenceConfiguration: config)
        let campaigns = ZhuowangCampaignStore(persistenceConfiguration: config)
        let workflows = ZhuowangWorkflowStore(persistenceConfiguration: config)
        let now = Date()
        for index in 0..<6 {
            let names = ["国庆福利延续", "十一月会员预热", "签到体验提升", "湖北秋日福利", "十月月度会员促活", "河南历史活动"]
            let province = index < 3 ? provinces[0] : index == 3 ? provinces[1] : index == 5 ? provinces[3] : nil
            let result = campaigns.addCampaign(name: names[index], scopeType: province == nil ? .national : .province,
                provinceID: province?.id, moduleID: province == nil ? "national" : "welfare",
                startDate: now.addingTimeInterval(index == 1 ? 86400 * 14 : -86400 * 4),
                endDate: now.addingTimeInterval(index == 5 ? -86400 * 2 : index == 1 ? 86400 * 40 : 86400 * Double(8 + index)),
                monthlyMonth: index == 4 ? "2026-10" : nil)
            XCTAssertTrue(result.succeeded)
            let campaign = try XCTUnwrap(campaigns.campaigns.first { $0.name == names[index] })
            var workflow = workflows.getOrCreateWorkflow(forCampaignID: campaign.id)
            for i in workflow.steps.indices {
                workflow.steps[i].status = index == 2 ? .completed : i < 2 ? .approved : .notStarted
            }
            if index == 0 { workflow.steps[2].status = .needsRevision }
            if index == 3 { workflow.steps[2].status = .waitingForApproval }
            if index == 1 { workflow.steps[5].isEnabled = false }
            let step = workflow.steps[0]
            let file = try workflows.workspaceFileManager.writeMarkdownArtifact(provinceName: province?.pathName,
                campaignName: campaign.name, stepKind: .brief, artifactName: "需求整理", version: 1,
                content: "# " + campaign.name + "\n\n这是隔离夹具中的完整需求正文。\n\n## 下一步\n核对目标与活动范围，保留历史产物。")
            workflow.artifacts = [.init(campaignID: campaign.id, stepID: step.id, name: "需求整理", type: .markdown,
                location: file.path, version: 1, isApprovedVersion: true)]
            let faq = workflow.steps.first { $0.kind == .customerService }!
            workflow.artifacts.append(.init(campaignID: campaign.id, stepID: faq.id, name: "客服文档", type: .markdown,
                content: "合成客服正文，仅用于验证分类页面。", version: 1, isApprovedVersion: true))
            workflows.updateWorkflow(workflow)
        }
        let assets = ZhuowangAssetCatalogViewModel(dataSource: source, allowedRoot: root, requiresIsolatedRoot: true); assets.refresh()
        return Fixture(root: root, source: source, config: config, workspace: workspace, campaigns: campaigns,
            workflows: workflows, assets: assets, provinces: provinces, modules: modules)
    }

    func testProvinceAndModuleBadgesMatchWorkbenchMetrics() throws {
        let f = try fixture(), rows = f.rows
        let baseline = f.source.storage
        for scope in f.provinces.map({ ZhuowangCampaignWorkbenchFilter.Scope.province($0.id) }) + [.module("national")] {
            var filter = ZhuowangCampaignWorkbenchFilter(); filter.scope = scope
            let workbench = rows.filter(filter.matches)
            let badge = ZhuowangWorkspaceUI.badge(rows, scope: scope)
            XCTAssertEqual(badge.count, workbench.count)
            XCTAssertEqual(badge.attention, workbench.contains { CosmosWorkbenchMetric.attention.matches($0) })
            for metric in CosmosWorkbenchMetric.allCases {
                XCTAssertEqual(ZhuowangWorkspaceUI.scoped(rows, scope: scope).filter(metric.matches).count,
                    workbench.filter(metric.matches).count)
            }
        }
        XCTAssertEqual(f.source.storage, baseline)
    }

    func testCardProgressCountsOnlyEnabledSteps() throws {
        let f = try fixture()
        let row = try XCTUnwrap(f.rows.first { $0.campaign.name == "十一月会员预热" })
        XCTAssertEqual(row.totalSteps, 5)
        XCTAssertEqual(row.completedSteps, 2)
        XCTAssertEqual(row.adoptedArtifactCount, 2)
    }

    func testOverviewUsesOnlyRealRowsAndEmptyScopeHasNoPlaceholderMetrics() throws {
        let f = try fixture()
        XCTAssertEqual(Set(f.rows.map(\.campaign.id)), Set(f.campaigns.campaigns.map(\.id)))
        let empty = ZhuowangWorkspaceUI.scoped(f.rows, scope: .province(f.provinces[2].id))
        XCTAssertTrue(empty.isEmpty)
        for metric in CosmosWorkbenchMetric.allCases { XCTAssertEqual(empty.filter(metric.matches).count, 0) }
    }

    func testNewCampaignPreservesPreselectedProvinceWithoutWrites() throws {
        let f = try fixture(), before = f.source.storage
        let form = ZhuowangCampaignCreateView(store: f.campaigns, province: f.provinces[1], module: nil)
        XCTAssertEqual(form.province?.id, f.provinces[1].id)
        XCTAssertNil(form.module)
        XCTAssertEqual(f.source.storage, before)
    }

    func testOffscreenPagesLightDarkAndBothSizesPreserveData() async throws {
        let f = try fixture()
        let suite = "CosmosStep3A.UI." + UUID().uuidString; suites.append(suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let prefs = CosmosUIPreferences(defaults: defaults); prefs.motion = .reduced
        let nav = CosmosNavigator()
        let out = URL(fileURLWithPath: "/private/tmp/CosmosStep3A-screenshots")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let before = f.source.storage
        for width in [1180, 900] {
            let height = width == 1180 ? 760 : 620
            for dark in [false, true] {
                let scheme: ColorScheme = dark ? .dark : .light
                func save<V: View>(_ view: V, _ name: String) async throws {
                    let content = view.environment(\.cosmosPreferences, prefs).environment(\.cosmosNavigator, nav)
                        .environment(\.colorScheme, scheme).defaultAppStorage(defaults)
                        .frame(width: CGFloat(width), height: CGFloat(height)).background(Color(nsColor: .windowBackgroundColor))
                    let host = NSHostingView(rootView: content)
                    host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                    host.frame = NSRect(x: 0, y: 0, width: width, height: height)
                    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false; window.appearance = host.appearance; window.contentView = host
                    defer { window.contentView = nil; window.close() }
                    host.layoutSubtreeIfNeeded()
                    try await Task.sleep(for: .milliseconds(250)); host.layoutSubtreeIfNeeded()
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    XCTAssertGreaterThan(png.count, 1500)
                    try png.write(to: out.appendingPathComponent("\(name)-\(width)-\(dark ? "dark" : "light").png"))
                }
                func workspace(_ navigation: ZhuowangNavigationItem, category: String = "overview") -> some View {
                    ZhuowangWorkspaceView(persistenceConfiguration: f.config, isolatedAssetRoot: f.root,
                        initialNavigation: navigation, initialCategoryID: category)
                }
                try await save(workspace(.workbench), "navigation-workbench")
                try await save(ScrollViewReader { proxy in
                    workspace(.workbench).task {
                        try? await Task.sleep(for: .milliseconds(100))
                        proxy.scrollTo("workbench-schedule", anchor: .top)
                    }
                }, "workbench-schedule")
                try await save(workspace(.province(f.provinces[0].id)), "province-overview")
                try await save(workspace(.province(f.provinces[2].id)), "province-empty")
                try await save(workspace(.module("national")), "module-overview")
                defaults.set("cards", forKey: "cosmos.ui.workspace.campaignLayout")
                try await save(workspace(.province(f.provinces[0].id), category: "campaign"), "campaign-cards")
                defaults.set("list", forKey: "cosmos.ui.workspace.campaignLayout")
                try await save(workspace(.province(f.provinces[0].id), category: "campaign"), "campaign-list")
                try await save(ZhuowangCampaignCreateView(store: f.campaigns, province: f.provinces[1], module: nil), "create-province")
                try await save(ZhuowangCampaignCreateView(store: f.campaigns, province: nil, module: f.modules[1]), "create-monthly-type")
                try await save(workspace(.province(f.provinces[0].id), category: "faq"), "category-faq")
                try await save(ZhuowangAssetCenterView(model: f.assets), "assets")
                let entry = try XCTUnwrap(f.assets.entries.first { $0.artifact.type == .markdown && !$0.artifact.location.isEmpty })
                try await save(ZhuowangAssetDetailView(model: f.assets, groupID: entry.groupID, selectedID: entry.id), "asset-detail")
                try await save(ZhuowangWorkspaceManagerView(store: f.workspace,
                    campaignCount: { id in f.campaigns.campaigns.filter { $0.provinceID == id }.count }), "province-management")
            }
        }
        XCTAssertEqual(f.source.storage, before)
    }
}
