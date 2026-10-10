import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class CosmosStep2IntegrationTests: XCTestCase {
    private var roots: [URL] = []
    private var suites: [String] = []
    override func tearDown() {
        KnowledgeSourceOpenCenter.shared.pending = nil
        for root in roots { try? FileManager.default.removeItem(at: root) }
        for suite in suites { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        super.tearDown()
    }
    private func root() throws -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosStep2Integration-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        roots.append(root); return root
    }
    private func preferences() throws -> CosmosUIPreferences {
        let suite = "CosmosStep2Integration.UI." + UUID().uuidString; suites.append(suite)
        let prefs = CosmosUIPreferences(defaults: try XCTUnwrap(UserDefaults(suiteName: suite))); prefs.motion = .reduced
        return prefs
    }
    private func host<V: View>(_ view: V, nav: CosmosNavigator, prefs: CosmosUIPreferences, dark: Bool) -> (NSWindow, NSHostingView<AnyView>) {
        let content = AnyView(view.environment(\.cosmosNavigator, nav).environment(\.cosmosPreferences, prefs)
            .environment(\.colorScheme, dark ? .dark : .light).frame(width: 1180, height: 760)
            .background(Color(nsColor: .windowBackgroundColor)))
        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame = NSRect(x: 0, y: 0, width: 1180, height: 760)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.appearance = host.appearance; window.contentView = host
        return (window, host)
    }
    private func settle(_ host: NSView) async throws {
        for _ in 0..<5 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(100)) }
    }
    func testKnowledgeRequestRoutesMountedShellAndConsumesOnce() async throws {
        let nav = CosmosNavigator(), prefs = try preferences()
        nav.navigate(.module("projects"))
        let data = ZhuowangInMemoryPersistenceDataSource(storage: [:])
        let configuration = ZhuowangStorePersistenceConfiguration(dataSource: data, isIsolated: true)
        let (window, host) = host(DashboardView(storePersistenceConfiguration: configuration), nav: nav, prefs: prefs, dark: false)
        defer { window.contentView = nil; window.close() }
        try await settle(host)
        KnowledgeSourceOpenCenter.shared.post(.init(document: .init(sourceID: UUID(), relativePath: "不存在.md")))
        try await settle(host)
        XCTAssertEqual(nav.selection, .knowledgeBase); XCTAssertEqual(nav.knowledgeSection, .sources)
        XCTAssertNil(KnowledgeSourceOpenCenter.shared.pending)
        XCTAssertEqual(data.writeCount, 0)
        XCTAssertEqual(UnifiedSearchSource.knowledgeDocument.cosmosIcon, "books.vertical")
    }
    func testOffscreenIntegratedPagesAndKnowledgeReadOnly() async throws {
        let root = try root(), prefs = try preferences(), nav = CosmosNavigator()
        let out = URL(fileURLWithPath: "/private/tmp/CosmosStep2Integration-screenshots")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let library = root.appendingPathComponent("library"), folder = root.appendingPathComponent("knowledge")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let text = "---\ntitle: 集成知识库文档\ntags: [集成, 工作流]\n---\n# 集成知识库文档\n\n这是合成夹具。正文用于验证 **只读阅读**。\n\n## 下一步\n检查导航与检索，保留原文件。\n"
        let file = folder.appendingPathComponent("集成说明.md"); try Data(text.utf8).write(to: file)
        let store = KnowledgeSourceStore(location: .init(root: library, error: nil, isolated: true))
        await store.reload(); let added = await store.add(folder: folder); XCTAssertTrue(added)
        let source = try XCTUnwrap(store.sources.first); await store.waitForScan(source.id)
        let before = try Data(contentsOf: file), registry = try Data(contentsOf: library.appendingPathComponent("sources.json"))
        let data = ZhuowangInMemoryPersistenceDataSource(storage: [:])
        let configuration = ZhuowangStorePersistenceConfiguration(dataSource: data, isIsolated: true)
        let reader = UnifiedSearchReader(readPreference: { _ in nil }, roots: [.knowledgeDocument: library])
        let snapshot = reader.read()
        let search = UnifiedSearchViewModel(debounce: .zero, load: { snapshot })
        search.search(.init(text: "集成", source: .knowledgeDocument)); try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(search.rows.count, 1)
        let searchNav = UnifiedSearchNavigator(reader: reader, configuration: configuration,
            projects: .init(root: nil, error: .unsafePath), prompts: .init(root: nil, error: .unsafePath),
            learning: .init(root: nil, error: .unsafePath), assetRoot: nil)
        let projects = ProjectsStore(location: .init(root: root.appendingPathComponent("projects"), error: nil)); await projects.reload()
        let projectSaved = await projects.save(CosmosProjectStarter.cosmos.draft, expected: nil); XCTAssertTrue(projectSaved)
        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            func save<V: View>(_ view: V, _ name: String) async throws {
                let (window, host) = host(view, nav: nav, prefs: prefs, dark: dark)
                defer { window.contentView = nil; window.close() }
                try await settle(host)
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds)); host.cacheDisplay(in: host.bounds, to: bitmap)
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:])); XCTAssertGreaterThan(png.count, 1500)
                try png.write(to: out.appendingPathComponent(name + "-" + suffix + ".png"))
            }
            for section in [CosmosKnowledgeSection.notes, .assets, .sources] {
                nav.navigate(.knowledge(section))
                try await save(CosmosKnowledgeDestinationView(configuration: configuration, isolatedRoot: root,
                    notesLocation: .init(root: root.appendingPathComponent("notes"), error: nil),
                    promptLocation: .init(root: root.appendingPathComponent("prompts"), error: nil),
                    knowledgeSourcesLocation: .init(root: root.appendingPathComponent("empty-sources"), error: nil, isolated: true)), "knowledge-" + section.rawValue)
            }
            try await save(KnowledgeSourcesRootView(store: store), "knowledge-browser")
            KnowledgeSourceOpenCenter.shared.post(.init(document: .init(sourceID: source.id, relativePath: "集成说明.md")))
            try await save(KnowledgeSourcesRootView(store: store), "knowledge-reader")
            try await save(UnifiedSearchView(model: search, navigator: searchNav), "search-knowledge")
            try await save(DashboardHomeView(model: .init(snapshot: DashboardHomeData(), delivery: .loaded(0)), open: { _ in }), "dashboard")
            try await save(ProjectsView(store: projects), "projects")
            try await save(AIWorkspaceView(model: AIWorkspaceViewModel(detect: { nil })), "ai-workspace")
        }
        XCTAssertEqual(try Data(contentsOf: file), before); XCTAssertEqual(try Data(contentsOf: library.appendingPathComponent("sources.json")), registry)
        XCTAssertEqual(data.writeCount, 0)
        print("Integration screenshots: " + out.path)
    }
}
