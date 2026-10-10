import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class CosmosUIUpgradeTests: XCTestCase {
    private var suites: [String] = []
    override func tearDown() {
        suites.forEach { UserDefaults(suiteName: $0)?.removePersistentDomain(forName: $0) }; suites = []
        super.tearDown()
    }
    private func preferences() throws -> (UserDefaults, CosmosUIPreferences) {
        let name = "com.wangyucosmos.CosmosUI.Tests." + UUID().uuidString; suites.append(name)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        return (defaults, CosmosUIPreferences(defaults: defaults))
    }
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Shanghai")!; c.firstWeekday = 2; return c }
    private var now: Date { ISO8601DateFormatter().date(from: "2026-10-11T12:00:00+08:00")! }
    private func empty() -> DashboardHomeData {
        DashboardHomeAggregation.project(campaigns: .loaded([]), workflows: .loaded([]), workspace: .missing, prompts: .loaded([]), notes: .loaded([]), learning: .loaded(LearningSnapshot()), now: now, calendar: calendar)
    }
    private func campaign() -> ZhuowangCampaign {
        ZhuowangCampaign(name: "浙江十月福利活动", scopeType: .national, moduleID: "national", startDate: now.addingTimeInterval(-86400), endDate: now.addingTimeInterval(86400), updatedAt: now)
    }
    private func decode<T: Decodable, V: Encodable>(_ type: T.Type, _ value: V) throws -> T { try JSONDecoder().decode(type, from: JSONEncoder().encode(value)) }
    private func fixture() throws -> DashboardHomeData {
        let campaign = campaign()
        var flow = ZhuowangCampaignWorkflow.standard(campaignID: campaign.id); flow.steps[0].status = .failed; flow.steps[5].isEnabled = false
        let topic = LearningTopic(name: "Swift Charts")
        let entries = (0..<8).map { offset in LearningEntry(topicID: topic.id, studyDay: LearningDay(date: now.addingTimeInterval(Double(-offset) * 86400), timeZone: calendar.timeZone), body: "学习记录") }
        let note = PersonalNote(title: "交付经验", body: "原文", updatedAt: now)
        let prompt = PromptTemplate(name: "活动策划模板", body: "正文", updatedAt: now)
        return DashboardHomeAggregation.project(campaigns: .loaded(try decode([DashboardHomeCampaign].self, [campaign])),
            workflows: .loaded(try decode([DashboardHomeWorkflow].self, [flow])),
            workspace: .loaded(DashboardHomeWorkspace(provinces: [], modules: [.init(id: "national", name: "全国促活")])),
            prompts: .loaded([prompt]), notes: .loaded([note]), learning: .loaded(LearningSnapshot(topics: [topic], entries: entries)), now: now, calendar: calendar)
    }
    func testUIPreferencesDefaultsAndNoWritesOnRead() throws {
        let (defaults, prefs) = try preferences()
        let before = defaults.dictionaryRepresentation()
        XCTAssertEqual(prefs.appearance, .system); XCTAssertEqual(prefs.textSize, .standard)
        XCTAssertEqual(prefs.startup, .dashboard); XCTAssertFalse(prefs.sidebarEnglish); XCTAssertEqual(prefs.motion, .system)
        XCTAssertEqual(defaults.dictionaryRepresentation().count, before.count)
    }
    func testUIPreferencesRoundTripTouchesOnlyUIPrefix() throws {
        let (defaults, prefs) = try preferences()
        let business = Data("protected".utf8); defaults.set(business, forKey: "cosmos.zhuowang.campaigns.v1")
        let before = defaults.dictionaryRepresentation()
        // Do not change application-wide appearance in this preference persistence test.
        prefs.textSize = .extraLarge; prefs.sidebarEnglish = true; prefs.startup = .lastPage; prefs.motion = .reduced; prefs.lastPage = "promptVault"
        let after = CosmosUIPreferences(defaults: defaults)
        XCTAssertEqual(after.textSize, .extraLarge); XCTAssertTrue(after.sidebarEnglish); XCTAssertEqual(after.startup, .lastPage)
        XCTAssertEqual(after.motion, .reduced); XCTAssertEqual(after.lastPage, "promptVault")
        XCTAssertEqual(defaults.data(forKey: "cosmos.zhuowang.campaigns.v1"), business)
        let added = Set(defaults.dictionaryRepresentation().keys).subtracting(before.keys)
        XCTAssertTrue(added.allSatisfy { $0.hasPrefix("cosmos.ui.") }); XCTAssertEqual(added.count, 5)
    }
    func testIllegalUIPreferencesFallBackWithoutRewriting() throws {
        let (defaults, _) = try preferences()
        for name in ["appearance", "textSize", "startup", "motion", "lastPage"] { defaults.set("invalid", forKey: "cosmos.ui." + name) }
        defaults.set(42, forKey: "cosmos.ui.sidebarEnglish")
        let prefs = CosmosUIPreferences(defaults: defaults)
        XCTAssertEqual(prefs.appearance, .system); XCTAssertEqual(prefs.textSize, .standard); XCTAssertEqual(prefs.startup, .dashboard)
        XCTAssertEqual(prefs.motion, .system); XCTAssertFalse(prefs.sidebarEnglish); XCTAssertEqual(prefs.lastPage, "dashboard")
        XCTAssertEqual(defaults.string(forKey: "cosmos.ui.appearance"), "invalid")
    }
    func testReducedMotionAlwaysHonorsSystem() throws {
        let (_, prefs) = try preferences()
        XCTAssertFalse(prefs.reducesMotion(system: false)); XCTAssertTrue(prefs.reducesMotion(system: true))
        prefs.motion = .reduced; XCTAssertTrue(prefs.reducesMotion(system: false))
    }
    func testEveryDashboardDestinationAndFilters() {
        let mapping: [(CosmosDashboardLink, CosmosDestination)] = [(.campaigns, .workbench(.all)), (.ongoing, .workbench(.ongoing)),
            (.attention, .workbench(.attention)), (.deliverable, .workbench(.deliverable)), (.notes, .knowledge(.notes)),
            (.prompts, .module("promptVault")), (.learning, .module("learningCenter")), (.distribution, .workbench(.all)),
            (.workflow, .workbench(.all)), (.learningChart, .module("learningCenter")), (.mac, .module("macOptimizer")), (.ai, .module("aiWorkspace"))]
        XCTAssertEqual(mapping.count, CosmosDashboardLink.allCases.count)
        for (link, destination) in mapping { XCTAssertEqual(link.destination, destination) }
    }
    func testNavigationRoutesAndWorkbenchToggleCancel() {
        let nav = CosmosNavigator()
        for metric in CosmosWorkbenchMetric.allCases {
            nav.navigate(.workbench(metric)); XCTAssertEqual(nav.selection, .zhuowang); XCTAssertEqual(nav.pendingWorkbenchMetric, metric)
            XCTAssertEqual(nav.consumeWorkbenchMetric(), metric); XCTAssertNil(nav.pendingWorkbenchMetric)
            XCTAssertNil(metric.toggled(from: metric)); XCTAssertEqual(metric.toggled(from: nil), metric)
        }
        nav.navigate(.knowledge(.assets)); XCTAssertEqual(nav.knowledgeSection, .assets)
        nav.navigate(.search("福利")); XCTAssertEqual(nav.searchText, "福利"); XCTAssertEqual(nav.selection, .unifiedSearch)
        nav.navigate(.settings(.data)); XCTAssertEqual(nav.settingsTab, .data); XCTAssertEqual(nav.settingsRequest, 1)
        nav.navigate(.module("projects")); XCTAssertEqual(nav.selection, .projects); XCTAssertNil(nav.pendingWorkbenchMetric)
    }
    func testIsolatedRecentCampaignRoutesToWorkbench() {
        let nav = CosmosNavigator(), row = UnifiedSearchRow(id: .init(source: .campaign, objectID: UUID()), name: "同名", ownership: "", fields: [])
        nav.navigate(.record(row), isolated: true); XCTAssertEqual(nav.pendingWorkbenchMetric, .all); XCTAssertNil(nav.recordRequest)
        let note = UnifiedSearchRow(id: .init(source: .note, objectID: row.id.objectID), name: "同名", ownership: "", fields: [])
        nav.navigate(.record(note), isolated: true); XCTAssertEqual(nav.recordRequest?.id, note.id)
    }
    func testAggregationCountsEnabledStepsAndSevenDays() throws {
        let data = try fixture()
        XCTAssertEqual(data.total, 1); XCTAssertEqual(data.ongoing, 1); XCTAssertEqual(data.attention, 1)
        XCTAssertEqual(data.workflow.reduce(0) { $0 + $1.count }, 5); XCTAssertEqual(data.workflow.first { $0.id == "failed" }?.count, 1)
        XCTAssertEqual(data.learningCount, 7); XCTAssertEqual(data.weeks.count, 8); XCTAssertEqual(data.weeks.reduce(0) { $0 + $1.count }, 8)
        XCTAssertEqual(data.distribution.first?.label, "全国促活"); XCTAssertEqual(data.noteCount, 1); XCTAssertEqual(data.promptCount, 1)
        XCTAssertEqual(Set(data.recent.map { $0.id.source }), [.campaign, .note, .prompt])
    }
    func testEmptyAggregationHasNoFakeCountsOrBars() {
        let data = empty(); XCTAssertEqual(data.total, 0); XCTAssertEqual(data.learningCount, 0)
        XCTAssertTrue(data.workflow.isEmpty); XCTAssertTrue(data.distribution.isEmpty); XCTAssertTrue(data.recent.isEmpty)
        XCTAssertEqual(data.weeks.count, 8); XCTAssertTrue(data.weeks.allSatisfy { $0.count == 0 })
    }
    func testSingleSourceFailureDoesNotBecomeEmptyOrAffectOtherSources() {
        let data = DashboardHomeAggregation.project(campaigns: .failed("活动损坏"), workflows: .loaded([]), workspace: .missing,
            prompts: .failed("提示词损坏"), notes: .loaded([PersonalNote(title: "可读", body: "x")]), learning: .loaded(LearningSnapshot()), now: now, calendar: calendar)
        XCTAssertNil(data.total); XCTAssertNil(data.promptCount); XCTAssertEqual(data.noteCount, 1); XCTAssertEqual(data.learningCount, 0)
        XCTAssertEqual(data.deliveryError, "活动损坏"); XCTAssertEqual(data.recent.map { $0.row.name }, ["可读"])
    }
    func testDisabledProvinceAndRecentLimit() throws {
        let id = UUID(); var c = campaign(); c.scopeType = .province; c.provinceID = id
        let notes = (0..<12).map { PersonalNote(title: "笔记 \($0)", body: "x", updatedAt: now.addingTimeInterval(Double($0))) }
        let data = DashboardHomeAggregation.project(campaigns: .loaded(try decode([DashboardHomeCampaign].self, [c])), workflows: .missing,
            workspace: .loaded(.init(provinces: [.init(id: id, name: "浙江", isEnabled: false)], modules: [])), prompts: .missing,
            notes: .loaded(notes), learning: .missing, now: now, calendar: calendar)
        XCTAssertEqual(data.distribution[0].label, "浙江（已停用）"); XCTAssertEqual(data.recent.count, 8)
        XCTAssertEqual(data.recent.first?.row.name, "笔记 11")
    }
    func testReadOnlyReaderMissingAndSingleCorruptSource() async throws {
        let source = ZhuowangInMemoryPersistenceDataSource(storage: [DashboardHomeReader.keys[0]: Data("broken".utf8)])
        let readSource: any ZhuowangPersistenceDataSource = source
        let root = URL(fileURLWithPath: "/private/tmp/CosmosUIRead-" + UUID().uuidString)
        let reader = DashboardHomeReader(readPreference: { readSource.data(forKey: $0) }, prompts: root.appendingPathComponent("p"), notes: root.appendingPathComponent("n"), learning: root.appendingPathComponent("l"), blocked: [:])
        let data = await reader.load(now: now, calendar: calendar)
        XCTAssertNil(data.total); XCTAssertNotNil(data.errors["campaigns"]); XCTAssertEqual(data.noteCount, 0)
        XCTAssertEqual(source.writeCount, 0); XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }
    func testWorkbenchMetricSemanticsMatchExistingBuilder() {
        let c = campaign(); var w = ZhuowangCampaignWorkflow.standard(campaignID: c.id)
        w.steps[0].status = .failed
        let row = ZhuowangCampaignProgressBuilder.build(campaigns: [c], workflows: [w], provinces: [], modules: [], now: now, calendar: calendar, deliverableCounter: { _, _, _, _ in 0 })[0]
        XCTAssertTrue(CosmosWorkbenchMetric.all.matches(row)); XCTAssertTrue(CosmosWorkbenchMetric.ongoing.matches(row))
        XCTAssertTrue(CosmosWorkbenchMetric.attention.matches(row)); XCTAssertFalse(CosmosWorkbenchMetric.deliverable.matches(row))
    }
    func testHomeRefreshCoalescesAndDeliveryFailureIsIndependent() async throws {
        var calls = 0
        let data = try fixture()
        let model = DashboardHomeViewModel(observeDayChange: false, homeLoad: { _, _ in
            try? await Task.sleep(for: .milliseconds(25)); return data
        }, deliveryCalculation: { _, _, _, _, _ in
            calls += 1; XCTAssertTrue(Thread.isMainThread)
            throw NSError(domain: "交付读取失败", code: 1)
        }, isolated: true, load: { _, now in DashboardRaw(readAt: now, campaigns: .notBuilt, workflows: .notBuilt, workspace: .notBuilt, prompts: .notBuilt, learning: .notBuilt) })
        model.refresh(); model.refresh(); model.refresh()
        XCTAssertTrue(model.delivery.isLoading)
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(calls, 1); XCTAssertEqual(model.homeData.noteCount, 1); XCTAssertNotNil(model.delivery.error)
        XCTAssertFalse(model.loading)
    }
    func testIsolatedHomeDeliveryWithoutInjectionFailsClosed() async throws {
        let model = DashboardHomeViewModel(observeDayChange: false, homeLoad: { _, _ in DashboardHomeData() }, isolated: true,
            load: { _, now in DashboardRaw(readAt: now, campaigns: .notBuilt, workflows: .notBuilt, workspace: .notBuilt, prompts: .notBuilt, learning: .notBuilt) })
        model.refresh(); try await Task.sleep(for: .milliseconds(60))
        XCTAssertNotNil(model.delivery.error); XCTAssertEqual(model.homeData.total, 0)
    }

    func testOffscreenAcceptanceMatrix() async throws {
        let out = URL(fileURLWithPath: "/private/tmp/CosmosUIUpgrade-01a1267e/screenshots")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let (_, prefs) = try preferences(); prefs.motion = .reduced
        let data = try fixture(), nav = CosmosNavigator()
        let sampleCampaign = campaign()
        var sampleWorkflow = ZhuowangCampaignWorkflow.standard(campaignID: sampleCampaign.id); sampleWorkflow.steps[0].status = .failed
        let sampleWorkspace = ZhuowangWorkspaceSnapshot(modules: [ZhuowangModule(id: "national", name: "全国促活", englishName: "National", icon: "globe", usesProvinces: false)], provinces: [], categories: [])
        let seedSource = ZhuowangInMemoryPersistenceDataSource(storage: [:])
        let seededProviders = ZhuowangWorkflowStore(persistenceConfiguration: .init(dataSource: seedSource, isIsolated: true)).providers
        let source = ZhuowangInMemoryPersistenceDataSource(storage: [
            "cosmos.zhuowang.ai.providers.v1": try JSONEncoder().encode(seededProviders),
            ZhuowangCampaignStore.storageKey: try JSONEncoder().encode([sampleCampaign]),
            ZhuowangWorkflowStore.workflowStorageKey: try JSONEncoder().encode([sampleWorkflow]),
            ZhuowangWorkspaceStore.storageKey: try JSONEncoder().encode(sampleWorkspace)])
        let configuration = ZhuowangStorePersistenceConfiguration(dataSource: source, isIsolated: true)
        let backup = CoreBackupSource(readPreference: { _ in nil }, fileRoots: (0..<5).map { out.appendingPathComponent("fixture-\($0)") })
        let reader = UnifiedSearchReader(readPreference: { _ in nil }, roots: [:])
        let searchNavigator = UnifiedSearchNavigator(reader: reader, configuration: configuration, projects: .init(root: nil, error: .unsafePath), prompts: .init(root: nil, error: .unsafePath), learning: .init(root: nil, error: .unsafePath), assetRoot: nil)
        let search = UnifiedSearchViewModel(debounce: .zero, load: { .init(rows: data.recent.map(\.row), states: [.campaign: .ready, .note: .ready, .prompt: .ready]) })
        let resultRows = data.recent.map { recent in
            let row = recent.row; return UnifiedSearchRow(id: row.id, name: row.name, ownership: row.ownership, fields: [.init(label: "名称", text: row.name)])
        }
        let populatedSearch = UnifiedSearchViewModel(debounce: .zero, load: { .init(rows: resultRows, states: [.campaign: .ready, .note: .ready, .prompt: .ready]) })
        populatedSearch.search(.init(text: "活")); try await Task.sleep(for: .milliseconds(40))
        let campaigns = ZhuowangCampaignStore(persistenceConfiguration: configuration)
        let workspace = ZhuowangWorkspaceStore(persistenceConfiguration: configuration)
        let workflows = ZhuowangWorkflowStore(persistenceConfiguration: configuration)
        for width in [1180, 900] {
            let height = width == 1180 ? 760 : 620
            for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                func save<V: View>(_ view: V, _ page: String) throws {
                    let content = view.environment(\.cosmosPreferences, prefs).environment(\.cosmosNavigator, nav).environment(\.colorScheme, scheme)
                        .frame(width: CGFloat(width), height: CGFloat(height)).background(Color(nsColor: .windowBackgroundColor))
                    let host = NSHostingView(rootView: content)
                    host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                    host.frame = NSRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
                    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.appearance = host.appearance
                    window.contentView = host
                    defer { window.contentView = nil; window.close() }
                    host.layoutSubtreeIfNeeded()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.12))
                    host.layoutSubtreeIfNeeded()
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    XCTAssertGreaterThan(png.count, 1500)
                    try png.write(to: out.appendingPathComponent("\(page)-\(name)-\(width)x\(height).png"))
                }
                try save(DashboardHomeView(model: .init(snapshot: data, delivery: .loaded(0)), open: { _ in }), "dashboard-data")
                try save(DashboardHomeView(model: .init(snapshot: empty(), delivery: .loaded(0)), open: { _ in }), "dashboard-empty")
                try save(UnifiedSearchView(model: search, navigator: searchNavigator), "search-empty")
                try save(UnifiedSearchView(model: populatedSearch, navigator: searchNavigator), "search-results")
                nav.pendingWorkbenchMetric = nil
                try save(ZhuowangCampaignWorkbenchView(campaignStore: campaigns, workspaceStore: workspace, workflowStore: workflows,
                    permitsDetailOpening: false, deliverableCounter: { _, _, _, _ in 0 }).padding(24), "workbench-unselected")
                nav.navigate(.workbench(.attention))
                try save(ZhuowangCampaignWorkbenchView(campaignStore: campaigns, workspaceStore: workspace, workflowStore: workflows,
                    permitsDetailOpening: false, deliverableCounter: { _, _, _, _ in 0 }).padding(24), "workbench-selected")
                for tab in CosmosSettingsTab.allCases {
                    nav.settingsTab = tab
                    try save(CosmosSettingsView(source: backup, restoreTarget: nil), "settings-" + tab.rawValue)
                }
            }
        }
        print("UI acceptance screenshots: " + out.path)
        XCTAssertEqual(source.writeCount, 0, "mounting views must not write business data")
    }
}
