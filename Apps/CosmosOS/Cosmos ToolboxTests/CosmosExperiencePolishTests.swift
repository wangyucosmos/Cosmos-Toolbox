import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class CosmosExperiencePolishTests: XCTestCase {
    private var roots: [URL] = []
    private var suites: [String] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        for suite in suites { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        super.tearDown()
    }
    private func root() throws -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosWorkspaceFiles-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        roots.append(root); return root
    }
    private func preferences() throws -> (CosmosUIPreferences, UserDefaults) {
        let suite = "CosmosRound4.UI." + UUID().uuidString; suites.append(suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let prefs = CosmosUIPreferences(defaults: defaults); prefs.motion = .reduced
        return (prefs, defaults)
    }
    func testChineseDatesSameYearAndAcrossYear() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 12)))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 17)))
        let prior = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 8, day: 17)))
        XCTAssertEqual(CosmosDate.day(date, now: now, calendar: calendar), "8月17日")
        XCTAssertEqual(CosmosDate.day(prior, now: now, calendar: calendar), "2025年8月17日")
    }
    func testStableGenericBadgesAndAdaptiveColumns() {
        XCTAssertEqual(CosmosIconPalette.letter("河南"), "河")
        XCTAssertEqual(CosmosIconPalette.letter("浙江"), "浙")
        XCTAssertEqual(CosmosIconPalette.letter(""), "")
        for id in ["henan", "zhejiang", "national", "安徽", "🧭"] {
            XCTAssertEqual(CosmosIconPalette.index(id), CosmosIconPalette.index(id))
            XCTAssertTrue((0..<6).contains(CosmosIconPalette.index(id)))
        }
        XCTAssertEqual(CosmosIconPalette.index("henan"), 3)
        XCTAssertEqual(CosmosAdaptiveLayout.columns(width: 600), 3)
        XCTAssertEqual(CosmosAdaptiveLayout.columns(width: 1000), 5)
        XCTAssertEqual(CosmosAdaptiveLayout.columns(width: 2200), 7)
        XCTAssertEqual(CosmosAdaptiveLayout.columns(width: -1), 1)
    }
    func testWorkspaceMemoryAndMetricPriority() {
        let nav = CosmosNavigator(), province = UUID()
        nav.workspaceNavigation = .province(province); nav.workspaceCategory = "banner"
        nav.navigate(.module("projects")); nav.navigate(.module("zhuowang"))
        XCTAssertEqual(nav.workspaceNavigation, .province(province)); XCTAssertEqual(nav.workspaceCategory, "banner")
        nav.navigate(.workbench(.attention))
        XCTAssertEqual(nav.workspaceNavigation, .workbench); XCTAssertEqual(nav.workspaceCategory, "overview")
        XCTAssertEqual(nav.consumeWorkbenchMetric(), .attention); XCTAssertNil(nav.consumeWorkbenchMetric())
        nav.workspaceNavigation = .module("national"); nav.navigate(.module("dashboard")); nav.navigate(.module("zhuowang"))
        XCTAssertEqual(nav.workspaceNavigation, .module("national"))
    }
    func testAutomaticDetectionRunsOnceAcrossModelsAndAfterCancellation() async throws {
        let cache = AIWorkspaceResultCache()
        let calls = Counter()
        let first = AIWorkspaceViewModel(cache: cache, detect: { await calls.increment(); return nil })
        first.detectOnceOnArrival(); first.detectOnceOnArrival()
        try await Task.sleep(for: .milliseconds(40)); first.cancel()
        let second = AIWorkspaceViewModel(cache: cache, detect: { await calls.increment(); return nil })
        second.detectOnceOnArrival(); try await Task.sleep(for: .milliseconds(40))
        let automatic = await calls.value; XCTAssertEqual(automatic, 1)
        second.refresh(); try await Task.sleep(for: .milliseconds(40))
        let manual = await calls.value; XCTAssertEqual(manual, 2)
    }
    func testPromptSessionRetainsIdentityAndManualRefreshSemantics() async throws {
        let root = try root(), session = CosmosPromptSession(location: .init(root: root, error: nil))
        await session.loadIfNeeded()
        let saved = await session.store.save(PromptTemplate(name: "原始", body: "正文 {{目标}}"), expectedRevision: nil)
        XCTAssertTrue(saved)
        let item = try XCTUnwrap(session.store.templates.first)
        let draft = PromptTemplateEditSession(store: session.store, template: item); draft.draft.body = "未保存草稿"
        let external = PromptVaultStore(root: root); await external.reload()
        var update = item; update.body = "外部新正文"
        let externalSaved = await external.save(update, expectedRevision: item.revision); XCTAssertTrue(externalSaved)
        await session.loadIfNeeded()
        XCTAssertEqual(session.store.templates.first?.body, item.body)
        let conflict = await draft.save(); XCTAssertFalse(conflict); XCTAssertEqual(session.store.error, .conflict)
        XCTAssertEqual(draft.draft.body, "未保存草稿"); XCTAssertTrue(draft.isDirty)
        await session.store.reload()
        XCTAssertEqual(session.store.templates.first?.body, "外部新正文")
        XCTAssertTrue(draft.store === session.store)
    }
    private actor Counter {
        var value = 0
        func increment() { value += 1 }
    }
    private func host<V: View>(_ view: V, width: Int, height: Int, dark: Bool,
                               nav: CosmosNavigator, prefs: CosmosUIPreferences, defaults: UserDefaults, bridgedToolbar: Bool = false) -> (NSWindow, NSHostingView<AnyView>) {
        let content = AnyView(view.environment(\.cosmosNavigator, nav).environment(\.cosmosPreferences, prefs)
            .environment(\.colorScheme, dark ? .dark : .light).environment(\.locale, Locale(identifier: "zh_Hans_CN"))
            .defaultAppStorage(defaults).frame(width: CGFloat(width), height: CGFloat(height))
            .background(Color(nsColor: .windowBackgroundColor)))
        let controller = NSHostingController(rootView: content)
        if bridgedToolbar { controller.sceneBridgingOptions = [.toolbars] }
        let host = controller.view as! NSHostingView<AnyView>; host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let window = NSWindow(contentRect: host.frame, styleMask: bridgedToolbar ? [.titled, .closable, .resizable] : [.borderless], backing: .buffered, defer: false)
        if bridgedToolbar { window.contentViewController = controller }
        window.isReleasedWhenClosed = false; window.appearance = host.appearance; window.contentView = host
        return (window, host)
    }
    func testFullPromptRouteBeforeAfterAndWarmFrames() async throws {
        let root = try self.root()
        let body = String(repeating: "任务 {{活动名称}}，要求 {{目标}}，保留历史。\n", count: 24)
        let items = (0..<120).map { i in
            PromptTemplate(name: "合成模板\(i)", body: body, category: "分类\(i % 8)",
                versions: (1...40).map { PromptVersion(number: $0, name: "合成模板\(i)", body: body, category: "分类\(i % 8)", recordedAt: Date()) })
        }
        try JSONEncoder().encode(PromptVaultDocument(templates: items)).write(to: root.appendingPathComponent("templates.json"))
        let nav = CosmosNavigator(), (prefs, defaults) = try preferences()
        var report = "120 templates, 4800 versions; NSHostingView full page, 900×620. First frame is an actual cached bitmap.\n"
        func frame(_ host: NSView, _ name: String) throws {
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            XCTAssertGreaterThan(try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).count, 1500)
            CosmosExperienceTrace.shared.mark(name)
        }
        func measure<V: View>(_ view: V, store: PromptVaultStore, name: String) async throws {
            let (window, host) = self.host(view, width: 900, height: 620, dark: false, nav: nav, prefs: prefs, defaults: defaults)
            defer { window.contentView = nil; window.close() }
            CosmosExperienceTrace.shared.mark("host_created")
            try frame(host, "first_frame")
            for _ in 0..<500 {
                if store.loaded && !store.loading { break }
                try await Task.sleep(for: .milliseconds(2))
            }
            XCTAssertTrue(store.loaded); XCTAssertFalse(store.loading)
            CosmosExperienceTrace.shared.mark("list_data_available")
            for _ in 0..<3 { await Task.yield(); host.layoutSubtreeIfNeeded() }
            try frame(host, "real_list_frame")
            let events = CosmosExperienceTrace.shared.finish()
            report += name + "\n" + events.map { "\($0.0): \(String(format: "%.3f", $0.1)) ms" }.joined(separator: "\n") + "\n"
        }
        CosmosExperienceTrace.shared.start()
        CosmosExperienceTrace.shared.mark("store_creation.begin")
        let oldStore = PromptVaultStore(root: root), oldModel = CosmosLegacyPromptViewModel()
        oldModel.selectedID = items[0].id
        CosmosExperienceTrace.shared.mark("store_creation.end")
        try await measure(CosmosLegacyPromptView(store: oldStore, model: oldModel), store: oldStore, name: "before_original_page_cold")
        CosmosExperienceTrace.shared.start()
        CosmosExperienceTrace.shared.mark("store_creation.begin")
        let session = CosmosPromptSession(location: .init(root: root, error: nil)); session.model.selectedID = items[0].id
        CosmosExperienceTrace.shared.mark("store_creation.end")
        try await measure(PromptVaultView(session: session), store: session.store, name: "after_page_cold")
        CosmosExperienceTrace.shared.start()
        try await measure(PromptVaultView(session: session), store: session.store, name: "after_page_warm")
        try report.write(toFile: "/private/tmp/CosmosRound4-full-route-timing.txt", atomically: true, encoding: .utf8)
        print(report)
    }
    func testMountedWorkspaceReentryHasOneShellTransitionAndNoSecondSelection() async throws {
        let root = try self.root(), (prefs, defaults) = try preferences(), nav = CosmosNavigator()
        let province = ZhuowangProvince(id: UUID(), name: "河南", englishName: "Henan")
        let data = ZhuowangInMemoryPersistenceDataSource(storage: [ZhuowangCampaignStore.storageKey: Data("[]".utf8),
            ZhuowangWorkspaceStore.storageKey: try JSONEncoder().encode(ZhuowangWorkspaceSnapshot(modules: [], provinces: [province], categories: []))])
        let config = ZhuowangStorePersistenceConfiguration(dataSource: data, isIsolated: true, workspaceFilesRootURL: root)
        _ = ZhuowangWorkflowStore(persistenceConfiguration: config) // Seed the fixture before the read-only render baseline.
        let baselineWrites = data.writeCount
        nav.selection = .projects; nav.workspaceNavigation = .province(province.id); prefs.motion = .system
        let (window, host) = self.host(DashboardView(storePersistenceConfiguration: config), width: 900, height: 620, dark: false, nav: nav, prefs: prefs, defaults: defaults)
        defer { window.contentView = nil; window.close() }
        host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(450))
        let out = URL(fileURLWithPath: "/private/tmp/CosmosRound4-navigation-frames")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        CosmosExperienceTrace.shared.start(); nav.navigate(.module("zhuowang"))
        for index in 0..<5 {
            try await Task.sleep(for: .milliseconds(index == 0 ? 1 : 100)); host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds)); host.cacheDisplay(in: host.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: out.appendingPathComponent("entry-\(index).png"))
            CosmosExperienceTrace.shared.mark("entry.frame.\(index)")
        }
        let first = CosmosExperienceTrace.shared.finish()
        XCTAssertEqual(first.filter { $0.0 == "shell.transition.zhuowang" }.count, 1)
        XCTAssertEqual(first.filter { $0.0.hasPrefix("workspace.selection.") }.count, 0)
        XCTAssertEqual(nav.workspaceNavigation, .province(province.id))
        nav.navigate(.module("projects")); try await Task.sleep(for: .milliseconds(450))
        CosmosExperienceTrace.shared.start(); nav.navigate(.module("zhuowang"))
        try await Task.sleep(for: .milliseconds(450)); host.layoutSubtreeIfNeeded()
        let second = CosmosExperienceTrace.shared.finish()
        XCTAssertEqual(second.filter { $0.0 == "shell.transition.zhuowang" }.count, 1)
        XCTAssertFalse(second.contains { $0.0.hasPrefix("workspace.selection.") || $0.0.hasPrefix("workspace.appear.") })
        XCTAssertEqual(nav.workspaceNavigation, .province(province.id)); XCTAssertEqual(data.writeCount, baselineWrites)
        try ("first entry\n" + first.map { "\($0)" }.joined(separator: "\n") + "\nreentry\n" + second.map { "\($0)" }.joined(separator: "\n"))
            .write(toFile: "/private/tmp/CosmosRound4-navigation-timing.txt", atomically: true, encoding: .utf8)
    }
    func testAllDirectedPageSwitchesUseOneStableShellFade() async throws {
        let root = try root(), (prefs, defaults) = try preferences(), nav = CosmosNavigator()
        let data = ZhuowangInMemoryPersistenceDataSource(storage: [ZhuowangCampaignStore.storageKey: Data("[]".utf8),
            ZhuowangWorkspaceStore.storageKey: try JSONEncoder().encode(ZhuowangWorkspaceSnapshot(modules: [], provinces: [], categories: []))])
        let config = ZhuowangStorePersistenceConfiguration(dataSource: data, isIsolated: true, workspaceFilesRootURL: root)
        _ = ZhuowangWorkflowStore(persistenceConfiguration: config)
        let baseline = data.storage
        let pages = SidebarItem.allCases.filter { $0 != .settings }
        nav.selection = .dashboard; prefs.motion = .system
        let (window, host) = self.host(DashboardView(storePersistenceConfiguration: config), width: 900, height: 620, dark: false, nav: nav, prefs: prefs, defaults: defaults, bridgedToolbar: true)
        defer { window.contentView = nil; window.close() }
        try await Task.sleep(for: .milliseconds(500)); host.layoutSubtreeIfNeeded()
        // Visit the retained workspace before measuring reentry; fixture stores may initialize once.
        nav.selection = .zhuowang; try await Task.sleep(for: .milliseconds(500))
        let out = URL(fileURLWithPath: "/private/tmp/CosmosNativeBatch1-matrix")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        var rows = ["from,to,fade_begin,fade_commit,host_remount,workspace_second_selection,workspace_toolbar_items"]
        for from in pages {
            nav.selection = from; try await Task.sleep(for: .milliseconds(450))
            for to in pages where from != to {
                nav.selection = from; try await Task.sleep(for: .milliseconds(450))
                CosmosExperienceTrace.shared.start(); nav.selection = to
                try await Task.sleep(for: .milliseconds(500)); host.layoutSubtreeIfNeeded()
                let events = CosmosExperienceTrace.shared.finish()
                let begins = events.filter { $0.0 == "shell.fade.begin." + to.rawValue }.count
                let ends = events.filter { $0.0 == "shell.fade.commit." + to.rawValue }.count
                let remounts = events.filter { $0.0.hasPrefix("shell.host.") }.count
                let selections = events.filter { $0.0.hasPrefix("workspace.selection.") }.count
                XCTAssertEqual(begins, 1, "\(from) → \(to)"); XCTAssertEqual(ends, 1)
                XCTAssertEqual(remounts, 0); XCTAssertEqual(selections, 0); XCTAssertEqual(nav.selection, to)
                XCTAssertFalse(events.contains { $0.0.hasPrefix("workspace.appear.") })
                func toolbarLabels(_ item: NSToolbarItem) -> [String] {
                    [item.label] + ((item as? NSToolbarItemGroup)?.subitems.flatMap(toolbarLabels) ?? [])
                }
                let labels = window.toolbar?.items.flatMap(toolbarLabels) ?? []
                let workspaceItems = labels.filter { $0 == "管理工作区" }.count
                XCTAssertEqual(workspaceItems, to == .zhuowang ? 1 : 0, "Toolbar: \(from) → \(to), \(labels)")
                rows.append("\(from.rawValue),\(to.rawValue),\(begins),\(ends),\(remounts),\(selections),\(workspaceItems)")
                if to == .projects || to == .unifiedSearch {
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: out.appendingPathComponent("\(from.rawValue)-\(to.rawValue).png"))
                }
            }
        }
        XCTAssertEqual(rows.count, 73); XCTAssertEqual(data.storage, baseline)
        try rows.joined(separator: "\n").write(to: out.appendingPathComponent("matrix.csv"), atomically: true, encoding: .utf8)
    }

    func testSearchFocusDependsOnExplicitEntryAndCommandRequest() async throws {
        let root = try root(), (prefs, defaults) = try preferences(), nav = CosmosNavigator()
        let config = ZhuowangStorePersistenceConfiguration(dataSource: ZhuowangInMemoryPersistenceDataSource(), isIsolated: true, workspaceFilesRootURL: root)
        nav.navigate(.search("旧关键词")); nav.selectSidebar(.unifiedSearch)
        XCTAssertFalse(nav.searchFocusRequested)
        let search = UnifiedSearchView(configuration: config, projects: .init(root: nil, error: .unsafePath),
            prompts: .init(root: nil, error: .unsafePath), learning: .init(root: nil, error: .unsafePath),
            notes: .init(root: nil, error: .unsafePath), knowledge: .init(root: nil, error: .unsafePath, isolated: true), assetRoot: root)
        CosmosExperienceTrace.shared.start()
        let (window, host) = self.host(search, width: 900, height: 620, dark: false, nav: nav, prefs: prefs, defaults: defaults)
        defer { window.contentView = nil; window.close() }
        host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(150))
        var events = CosmosExperienceTrace.shared.finish()
        XCTAssertTrue(events.contains { $0.0 == "search.focus.entry.false" })
        XCTAssertFalse(events.contains { $0.0 == "search.focus.true" })
        CosmosExperienceTrace.shared.start(); nav.requestSearchFocus() // Same action as the ⌘F toolbar command.
        try await Task.sleep(for: .milliseconds(150)); host.layoutSubtreeIfNeeded()
        events = CosmosExperienceTrace.shared.finish()
        XCTAssertTrue(events.contains { $0.0 == "search.focus.true" })
        nav.selectSidebar(.projects); XCTAssertFalse(nav.searchFocusRequested)
        nav.navigate(.search("")); XCTAssertFalse(nav.searchFocusRequested) // Dashboard now matches sidebar entry.
        let request = nav.searchFocusRequest
        nav.navigate(.search("活动")); XCTAssertTrue(nav.searchFocusRequested)
        XCTAssertEqual(nav.searchFocusRequest, request + 1)
    }

    func testWorkspaceMinimumUsesActualNamesFontBadgesAndOldPreference() {
        let items: [CosmosWorkspaceSplitWidth.Item] = [.init(title: "推进工作台", count: 999, attention: true), .init(title: "知识与资产")]
        let normal = CosmosWorkspaceSplitWidth.requiredMinimum(items: items, scale: 1)
        let large = CosmosWorkspaceSplitWidth.requiredMinimum(items: items, scale: CosmosUIPreferences.TextSize.extraLarge.scale)
        XCTAssertGreaterThan(large, normal)
        let longer = CosmosWorkspaceSplitWidth.requiredMinimum(items: [.init(title: "省级福利中心运营工作模块", count: 9999, attention: true)], scale: 1)
        XCTAssertGreaterThan(longer, normal)
        XCTAssertEqual(CosmosWorkspaceSplitWidth.displayed(220, minimum: large), large)
        XCTAssertEqual(CosmosWorkspaceSplitWidth.displayed(300, minimum: normal), max(300, normal))
        XCTAssertEqual(CosmosWorkspaceSplitWidth.displayed(999, minimum: normal), max(360, normal))
        let nameWidth = ("推进工作台" as NSString).size(withAttributes: [.font: CosmosWorkspaceSplitWidth.nameFont(scale: 1)]).width
        XCTAssertGreaterThan(normal, nameWidth + 32 + 44) // Name, icon and both padding layers all fit.
    }

    func testWorkspaceSplitWidthBoundsMemoryAndNativeDivider() async throws {
        let (prefs, defaults) = try preferences(), nav = CosmosNavigator()
        XCTAssertEqual(prefs.workspaceSidebarWidth, 260)
        prefs.workspaceSidebarWidth = 100; XCTAssertEqual(prefs.workspaceSidebarWidth, 220)
        prefs.workspaceSidebarWidth = 900; XCTAssertEqual(prefs.workspaceSidebarWidth, 360)
        prefs.workspaceSidebarWidth = 280
        XCTAssertEqual(CosmosUIPreferences(defaults: defaults).workspaceSidebarWidth, 280)
        XCTAssertEqual(CosmosWorkspaceSplitWidth.clamp(.nan), 260)
        let view = HSplitView {
            Text("推进工作台").lineLimit(1).frame(minWidth: 220, idealWidth: prefs.workspaceSidebarWidth, maxWidth: 360)
                .background(CosmosNativeSplitWidth(width: Binding(get: { prefs.workspaceSidebarWidth }, set: { prefs.workspaceSidebarWidth = $0 })))
            GeometryReader { _ in Color.clear }.frame(minWidth: 320)
        }
        let (window, host) = self.host(view, width: 900, height: 620, dark: false, nav: nav, prefs: prefs, defaults: defaults)
        defer { window.contentView = nil; window.close() }
        host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(150))
        func splits(_ view: NSView) -> [NSSplitView] { (view as? NSSplitView).map { [$0] } ?? view.subviews.flatMap { splits($0) } }
        let split = try XCTUnwrap(splits(host).first)
        XCTAssertEqual(split.dividerStyle, .thin); XCTAssertLessThanOrEqual(split.dividerThickness, 1)
        split.setPosition(300, ofDividerAt: 0)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(prefs.workspaceSidebarWidth, 300, accuracy: 1)
        XCTAssertEqual(CosmosUIPreferences(defaults: defaults).workspaceSidebarWidth, prefs.workspaceSidebarWidth)
    }

    func testClosingWorkspaceTwoWidthsLightDarkAndTextSizes() async throws {
        let root = try root(), (prefs, defaults) = try preferences(), nav = CosmosNavigator()
        let province = ZhuowangProvince(id: UUID(), name: "河南", englishName: "Henan")
        let module = ZhuowangModule(id: "national", name: "全国促活", englishName: "National", icon: "globe", usesProvinces: false)
        let data = ZhuowangInMemoryPersistenceDataSource(storage: [ZhuowangCampaignStore.storageKey: Data("[]".utf8),
            ZhuowangWorkspaceStore.storageKey: try JSONEncoder().encode(ZhuowangWorkspaceSnapshot(modules: [module], provinces: [province], categories: []))])
        let config = ZhuowangStorePersistenceConfiguration(dataSource: data, isIsolated: true, workspaceFilesRootURL: root)
        _ = ZhuowangWorkflowStore(persistenceConfiguration: config)
        let before = data.storage
        nav.selection = .zhuowang; nav.workspaceNavigation = .province(province.id)
        prefs.workspaceSidebarWidth = 220 // Exercise an older preference below the measured minimum.
        let out = URL(fileURLWithPath: "/private/tmp/CosmosClose-workspace-screenshots")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for width in [900, 1440] {
            for dark in [false, true] {
                for size in [CosmosUIPreferences.TextSize.standard, .extraLarge] {
                    prefs.textSize = size
                    let (window, host) = self.host(DashboardView(storePersistenceConfiguration: config), width: width, height: width == 900 ? 620 : 900, dark: dark, nav: nav, prefs: prefs, defaults: defaults)
                    for _ in 0..<3 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(80)) }
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: out.appendingPathComponent("workspace-\(width)-\(dark ? "dark" : "light")-\(size.rawValue).png"))
                    window.contentView = nil; window.close()
                }
            }
        }
        XCTAssertEqual(data.storage, before)
    }

    func testOffscreenSevenPagesThreeSizesLightDarkAndCategory() async throws {
        let root = try root(), (prefs, defaults) = try preferences(), nav = CosmosNavigator()
        let province = ZhuowangProvince(id: UUID(), name: "河南", englishName: "Henan")
        let module = ZhuowangModule(id: "welfare", name: "福利中心", englishName: "Welfare", icon: "gift", usesProvinces: true)
        let category = ZhuowangCategory(id: "banner", name: "Banner", englishName: "Banner", icon: "photo")
        let source = ZhuowangInMemoryPersistenceDataSource(storage: [ZhuowangCampaignStore.storageKey: Data("[]".utf8),
            ZhuowangWorkspaceStore.storageKey: try JSONEncoder().encode(ZhuowangWorkspaceSnapshot(modules: [module], provinces: [province], categories: [category]))])
        let config = ZhuowangStorePersistenceConfiguration(dataSource: source, isIsolated: true, workspaceFilesRootURL: root)
        _ = ZhuowangWorkflowStore(persistenceConfiguration: config) // Fixture setup may seed built-in provider metadata.
        let campaigns = ZhuowangCampaignStore(persistenceConfiguration: config)
        let added = campaigns.addCampaign(name: "十月会员福利", scopeType: .province, provinceID: province.id, moduleID: module.id,
            startDate: Date().addingTimeInterval(-86400), endDate: Date().addingTimeInterval(86400 * 7))
        XCTAssertTrue(added.succeeded)
        let projects = ProjectsStore(location: .init(root: root.appendingPathComponent("projects"), error: nil)); await projects.reload()
        for starter in CosmosProjectStarter.allCases { let saved = await projects.save(starter.draft, expected: nil); XCTAssertTrue(saved) }
        let prompts = CosmosPromptSession(location: .init(root: root.appendingPathComponent("prompts"), error: nil)); await prompts.loadIfNeeded()
        for starter in CosmosPromptStarter.allCases { let saved = await prompts.store.save(starter.draft, expectedRevision: nil); XCTAssertTrue(saved) }
        prompts.model.selectedID = prompts.store.templates.first?.id
        let library = root.appendingPathComponent("sources"), folder = root.appendingPathComponent("knowledge")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "# 体验打磨验收\n\n保留已有资料，核对窗口布局与下一步。\n".write(to: folder.appendingPathComponent("体验.md"), atomically: true, encoding: .utf8)
        let knowledge = KnowledgeSourceStore(location: .init(root: library, error: nil, isolated: true)); await knowledge.reload()
        let registered = await knowledge.add(folder: folder); XCTAssertTrue(registered)
        let knowledgeSource = try XCTUnwrap(knowledge.sources.first); await knowledge.waitForScan(knowledgeSource.id)
        let readOnlyStorage = source.storage
        let reader = UnifiedSearchReader(readPreference: { readOnlyStorage[$0] }, roots: [.project: root.appendingPathComponent("projects"), .prompt: root.appendingPathComponent("prompts"), .knowledgeDocument: library])
        let snapshot = reader.read(), search = UnifiedSearchViewModel(debounce: .zero, load: { snapshot })
        search.search(.init(text: "体验")); try await Task.sleep(for: .milliseconds(80))
        let searchNav = UnifiedSearchNavigator(reader: reader, configuration: config,
            projects: .init(root: root.appendingPathComponent("projects"), error: nil), prompts: .init(root: root.appendingPathComponent("prompts"), error: nil), learning: .init(root: nil, error: .unsafePath), assetRoot: root)
        var dashboard = DashboardHomeData(); dashboard.total = 7; dashboard.ongoing = 4; dashboard.attention = 1
        dashboard.noteCount = 6; dashboard.promptCount = 3; dashboard.learningCount = 5; dashboard.readAt = Date()
        dashboard.distribution = ["河南", "浙江", "湖北", "全国"].enumerated().map { .init(id: String($0.offset), label: $0.element, count: [3,2,1,1][$0.offset]) }
        dashboard.workflow = [.init(id: "notStarted", label: "未开始", count: 8), .init(id: "ready", label: "可开始", count: 2), .init(id: "waitingForApproval", label: "等待确认", count: 3), .init(id: "approved", label: "已确认", count: 5), .init(id: "failed", label: "失败", count: 1)]
        dashboard.weeks = (0..<8).map { .init(id: String($0), label: "\($0 + 1)周", count: [1,3,2,4,1,5,2,3][$0]) }
        let out = URL(fileURLWithPath: "/private/tmp/CosmosCloseAcceptance-screenshots")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let before = source.storage
        for (width, height) in [(900,620),(1180,760),(1440,900),(2560,1440)] {
            for dark in [false,true] {
                func save<V: View>(_ view: V, _ name: String) async throws {
                    let (window, host) = host(view, width: width, height: height, dark: dark, nav: nav, prefs: prefs, defaults: defaults)
                    defer { window.contentView = nil; window.close() }
                    for _ in 0..<3 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(80)) }
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds)); host.cacheDisplay(in: host.bounds, to: bitmap)
                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:])); XCTAssertGreaterThan(png.count, 1500)
                    try png.write(to: out.appendingPathComponent("\(name)-\(width)-\(dark ? "dark" : "light").png"))
                }
                try await save(DashboardHomeView(model: .init(snapshot: dashboard, delivery: .loaded(2)), open: { _ in }), "dashboard")
                try await save(ZhuowangWorkspaceView(persistenceConfiguration: config, isolatedAssetRoot: root, initialNavigation: .province(province.id)), "province")
                try await save(PromptVaultView(session: prompts), "prompts")
                try await save(AIWorkspaceView(model: .init(detect: { nil })), "ai")
                try await save(ProjectsView(store: projects), "projects")
                let emptyProjects = ProjectsStore(location: .init(root: root.appendingPathComponent("empty-projects"), error: nil)); await emptyProjects.reload()
                try await save(ProjectsView(store: emptyProjects), "projects-empty")
                try await save(KnowledgeSourcesRootView(store: knowledge), "knowledge")
                nav.selectSidebar(.unifiedSearch)
                try await save(DashboardView(storePersistenceConfiguration: config), "search-sidebar")
                nav.navigate(.search(""))
                try await save(DashboardView(storePersistenceConfiguration: config), "search-shortcut")
                try await save(UnifiedSearchView(model: search, navigator: searchNav), "search")
                try await save(ZhuowangWorkspaceView(persistenceConfiguration: config, isolatedAssetRoot: root, initialNavigation: .province(province.id), initialCategoryID: "banner"), "category")
                nav.workspaceNavigation = .province(province.id); nav.selection = .zhuowang
                try await save(DashboardView(storePersistenceConfiguration: config), "shell")
                let shellPages: [SidebarItem] = width == 900 ? SidebarItem.allCases.filter { $0 != .settings } : [.unifiedSearch, .projects, .zhuowang, .knowledgeBase]
                for page in shellPages {
                        nav.selection = page
                        try await save(DashboardView(storePersistenceConfiguration: config), "shell-" + page.rawValue)
                }
            }
        }
        XCTAssertEqual(source.storage, before)
        print("Round4 screenshots: " + out.path)
    }
}
