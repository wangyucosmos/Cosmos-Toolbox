import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class ZhuowangCategoryBarTests: XCTestCase {
    private func category(_ id: String, _ name: String) -> ZhuowangCategory {
        .init(id: id, name: name, englishName: "", icon: "square")
    }

    func testCategoryCountAndOrderFollowEditableSource() {
        let categories = [category("overview", "忽略重复概览"), category("faq", "客服文档"), category("banner", "自定义横幅"), category("campaign", "忽略重复活动")]
        let items = ZhuowangCategoryBarItem.items(categories: categories)
        XCTAssertEqual(items.map(\.id), ["overview", "campaign", "faq", "banner"])
        XCTAssertEqual(items.map(\.title), ["概览", "活动", "客服文档", "自定义横幅"])
        XCTAssertEqual(ZhuowangCategoryBarItem.items(categories: []).count, 2)
        XCTAssertEqual(ZhuowangCategoryBarItem.items(categories: categories + [category("new", "新增分类")]).count, 5)
    }

    func testUnsupportedMarkerFollowsRouteIDRatherThanName() {
        let items = ZhuowangCategoryBarItem.items(categories: [category("faq", "任意名称"), category("banner", "客服文档"), category("prompt", "提示词")])
        XCTAssertEqual(items.map(\.unsupported), [false, false, false, true, false])
        XCTAssertEqual(items[3].title, "客服文档")
    }

    func testSelectionBindingPreservesDestinationResetWithoutPreferenceWrites() {
        var selected = "overview", destination: String? = "old-asset"
        let bar = ZhuowangCategoryBar(items: ZhuowangCategoryBarItem.items(categories: [category("faq", "客服文档")]),
            selection: Binding(get: { selected }, set: { destination = nil; selected = $0 }))
        bar.selection = "faq"
        XCTAssertEqual(selected, "faq"); XCTAssertNil(destination)
        bar.selection = "overview"
        XCTAssertEqual(selected, "overview")
    }

    func testCategoryBarAndWorkspaceOffscreenWideNarrowLightDark() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosWorkspaceFiles-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "CosmosNativeBatch2.Category." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)), prefs = CosmosUIPreferences(defaults: defaults)
        prefs.motion = .reduced
        defer { try? FileManager.default.removeItem(at: root); defaults.removePersistentDomain(forName: suite) }
        let categories = [category("popup", "弹窗"), category("banner", "Banner"), category("faq", "客服文档"), category("prompt", "提示词"), category("flow", "流程图"), category("prototype", "原型"), category("asset", "素材")]
        let province = ZhuowangProvince(id: UUID(), name: "浙江", englishName: "Zhejiang")
        let source = ZhuowangInMemoryPersistenceDataSource(storage: [
            ZhuowangCampaignStore.storageKey: Data("[]".utf8),
            ZhuowangWorkspaceStore.storageKey: try JSONEncoder().encode(ZhuowangWorkspaceSnapshot(modules: [], provinces: [province], categories: categories))])
        let config = ZhuowangStorePersistenceConfiguration(dataSource: source, isIsolated: true, workspaceFilesRootURL: root)
        _ = ZhuowangWorkflowStore(persistenceConfiguration: config)
        let before = source.storage
        let out = URL(fileURLWithPath: "/private/tmp/CosmosNativeBatch2-screenshots")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for width in [900, 1440] {
            for dark in [false, true] {
                let view = ZhuowangWorkspaceView(persistenceConfiguration: config, isolatedAssetRoot: root,
                    initialNavigation: .province(province.id), initialCategoryID: "banner")
                    .environment(\.cosmosPreferences, prefs).environment(\.cosmosNavigator, CosmosNavigator())
                    .environment(\.colorScheme, dark ? .dark : .light).defaultAppStorage(defaults)
                    .frame(width: CGFloat(width), height: 760)
                let controller = NSHostingController(rootView: view); controller.sceneBridgingOptions = [.toolbars]
                let window = NSWindow(contentViewController: controller); window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                defer { window.contentViewController = nil; window.close() }
                let host = controller.view
                for _ in 0..<3 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(80)) }
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds)); host.cacheDisplay(in: host.bounds, to: bitmap)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: out.appendingPathComponent("workspace-\(width)-\(dark ? "dark" : "light").png"))
            }
        }
        XCTAssertEqual(source.storage, before)
    }
}
