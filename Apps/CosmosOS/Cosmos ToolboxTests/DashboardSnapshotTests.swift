import XCTest
import Foundation
import SwiftUI
import AppKit
@testable import Cosmos_Toolbox

/// Dashboard real-data integration: read-only reading, projection semantics,
/// stale handling and rendering. Synthetic data, in-memory data sources and
/// temporary roots only; no production data is read.
@MainActor
final class DashboardSnapshotTests: XCTestCase {

    // MARK: Helpers

    var roots: [URL] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots = []; super.tearDown()
    }

    func tempRoot() -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosDashboardPhase1-" + UUID().uuidString, isDirectory: true)
        roots.append(root); return root
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
    var now: Date { date("2026-10-09T12:00:00+08:00") }

    func campaign(_ name: String, status: ZhuowangCampaignStatus = .active, module: String? = "national",
                  start: String = "2026-10-01T00:00:00+08:00", end: String = "2026-10-31T00:00:00+08:00",
                  updated: Date? = nil, created: Date? = nil, monthly: ZhuowangMonthlyPlan? = nil,
                  id: UUID = UUID()) -> ZhuowangCampaign {
        ZhuowangCampaign(id: id, name: name, scopeType: .national, moduleID: module, startDate: date(start), endDate: date(end),
            status: status, createdAt: created ?? date("2026-09-01T00:00:00+08:00"),
            updatedAt: updated ?? date("2026-09-02T00:00:00+08:00"), monthly: monthly)
    }

    func workflow(_ campaign: ZhuowangCampaign, _ statuses: [ZhuowangWorkflowStepStatus], disabled: Set<Int> = []) -> ZhuowangCampaignWorkflow {
        var flow = ZhuowangCampaignWorkflow.standard(campaignID: campaign.id)
        for (index, status) in statuses.enumerated() { flow.steps[index].status = status }
        for index in disabled { flow.steps[index].isEnabled = false }
        return flow
    }

    let modules = [ZhuowangModule(id: "national", name: "全国促活", englishName: "National", icon: "globe", usesProvinces: false)]
    var workspace: ZhuowangWorkspaceSnapshot { ZhuowangWorkspaceSnapshot(modules: modules, provinces: [], categories: []) }

    func raw(campaigns: DashboardSource<[ZhuowangCampaign]> = .loaded([]),
             workflows: DashboardSource<[ZhuowangCampaignWorkflow]> = .loaded([]),
             prompts: DashboardSource<[PromptTemplate]> = .loaded([]),
             learning: DashboardSource<LearningSnapshot> = .loaded(LearningSnapshot()),
             readAt: Date? = nil) -> DashboardRaw {
        DashboardRaw(readAt: readAt ?? now, campaigns: campaigns, workflows: workflows,
            workspace: .loaded(workspace), prompts: prompts, learning: learning)
    }

    func activities(_ raw: DashboardRaw, at moment: Date? = nil) throws -> DashboardActivities {
        guard case .loaded(let value) = DashboardProjection.activities(raw, now: moment ?? now, calendar: calendar) else {
            throw NotLoaded()
        }
        return value
    }

    struct NotLoaded: Error {}

    func memorySource(_ storage: [String: Data] = [:]) -> ZhuowangInMemoryPersistenceDataSource {
        ZhuowangInMemoryPersistenceDataSource(storage: storage)
    }

    func encoded<T: Encodable>(_ value: T) -> Data { try! JSONEncoder().encode(value) }

    func readerFor(_ source: any ZhuowangPersistenceDataSource, prompt: DashboardLocation? = nil, learning: DashboardLocation? = nil) -> DashboardReader {
        DashboardReader(dataSource: source, promptLocation: prompt ?? .root(tempRoot()), learningLocation: learning ?? .root(tempRoot()))
    }

    // MARK: Reading: four states, zero writes

    func testNothingBuiltIsNotBuiltAndNothingIsWrittenOrCreated() async throws {
        let source = memorySource()
        let promptRoot = tempRoot(), learningRoot = tempRoot()
        let reader = readerFor(source, prompt: .root(promptRoot), learning: .root(learningRoot))
        let raw = await reader.load(cache: DashboardReadCache(), now: now)
        guard case .notBuilt = raw.campaigns, case .notBuilt = raw.workflows, case .notBuilt = raw.workspace,
              case .notBuilt = raw.prompts, case .notBuilt = raw.learning else { return XCTFail("expected notBuilt everywhere") }
        XCTAssertEqual(source.writeCount, 0, "reading writes no default value")
        XCTAssertFalse(FileManager.default.fileExists(atPath: promptRoot.path), "no directory is created")
        XCTAssertFalse(FileManager.default.fileExists(atPath: learningRoot.path))
        let projected = DashboardProjection.project(raw, now: now, calendar: calendar)
        XCTAssertEqual(projected.activities, .notBuilt); XCTAssertEqual(projected.monthly, .notBuilt)
        XCTAssertEqual(projected.prompts, .notBuilt); XCTAssertEqual(projected.learning, .notBuilt)
    }

    func testBuiltButEmptyIsLoadedEmptyNotNotBuilt() async throws {
        let promptRoot = tempRoot(), learningRoot = tempRoot()
        try FileManager.default.createDirectory(at: promptRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: learningRoot, withIntermediateDirectories: true)
        try Data("{\"schemaVersion\":1,\"templates\":[]}".utf8).write(to: promptRoot.appendingPathComponent("templates.json"))
        try Data("{\"schemaVersion\":1,\"topics\":[],\"entries\":[]}".utf8).write(to: learningRoot.appendingPathComponent("learning.json"))
        let source = memorySource([ZhuowangCampaignStore.storageKey: Data("[]".utf8),
                                   ZhuowangWorkflowStore.workflowStorageKey: Data("[]".utf8)])
        let raw = await readerFor(source, prompt: .root(promptRoot), learning: .root(learningRoot)).load(cache: DashboardReadCache(), now: now)
        guard case .loaded(let campaigns) = raw.campaigns, campaigns.isEmpty,
              case .loaded(let templates) = raw.prompts, templates.isEmpty,
              case .loaded(let snapshot) = raw.learning, snapshot.topics.isEmpty else { return XCTFail("expected loaded + empty") }
        let projected = DashboardProjection.project(raw, now: now, calendar: calendar)
        XCTAssertEqual(projected.monthly, .loaded([]))
        XCTAssertEqual(projected.prompts, .loaded(DashboardPrompts(rows: [], favoriteCount: 0, templateCount: 0)))
        XCTAssertEqual(projected.learning, .loaded(DashboardLearning(rows: [], learningCount: 0, plannedCount: 0)))
    }

    func testUnreadableSourcesAreReportedPerSectionAndNeverModified() async throws {
        let promptRoot = tempRoot(), learningRoot = tempRoot()
        try FileManager.default.createDirectory(at: promptRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: learningRoot, withIntermediateDirectories: true)
        let promptBytes = Data("not json".utf8), learningBytes = Data("{\"schemaVersion\":2,\"topics\":[],\"entries\":[]}".utf8)
        try promptBytes.write(to: promptRoot.appendingPathComponent("templates.json"))
        try learningBytes.write(to: learningRoot.appendingPathComponent("learning.json"))
        let source = memorySource([ZhuowangCampaignStore.storageKey: Data("garbage".utf8),
                                   ZhuowangWorkflowStore.workflowStorageKey: Data("[]".utf8)])
        let raw = await readerFor(source, prompt: .root(promptRoot), learning: .root(learningRoot)).load(cache: DashboardReadCache(), now: now)
        guard case .unreadable = raw.campaigns, case .loaded = raw.workflows,
              case .unreadable = raw.prompts, case .unreadable = raw.learning else { return XCTFail("expected per-section failures") }
        XCTAssertEqual(source.writeCount, 0)
        XCTAssertEqual(source.storage[ZhuowangCampaignStore.storageKey], Data("garbage".utf8))
        XCTAssertEqual(try Data(contentsOf: promptRoot.appendingPathComponent("templates.json")), promptBytes)
        XCTAssertEqual(try Data(contentsOf: learningRoot.appendingPathComponent("learning.json")), learningBytes)
        let names = try FileManager.default.contentsOfDirectory(atPath: promptRoot.path)
        XCTAssertEqual(names, ["templates.json"], "no lock, backup or temporary file appears")
        let projected = DashboardProjection.project(raw, now: now, calendar: calendar)
        if case .unreadable = projected.activities {} else { XCTFail() }
        if case .unreadable = projected.monthly {} else { XCTFail() }
    }

    func testBlockedLocationsAreReportedAndBadRootsNeverFallBackToProduction() async throws {
        let raw = await readerFor(memorySource(), prompt: .blocked("隔离保护"), learning: .blocked("隔离保护"))
            .load(cache: DashboardReadCache(), now: now)
        guard case .blocked("隔离保护") = raw.prompts, case .blocked("隔离保护") = raw.learning else { return XCTFail() }
        let projected = DashboardProjection.project(raw, now: now, calendar: calendar)
        XCTAssertEqual(projected.prompts, .blocked("隔离保护")); XCTAssertEqual(projected.learning, .blocked("隔离保护"))
    }

    func testRealStoragesLoadWithoutChangingTheirFiles() async throws {
        let promptRoot = tempRoot(), learningRoot = tempRoot()
        let prompts = PromptVaultFileStorage(root: promptRoot)
        _ = try await prompts.save(PromptTemplate(name: "常用", body: "正文", isFavorite: true), expectedRevision: nil)
        let learning = LearningFileStorage(root: learningRoot)
        _ = try await learning.apply(.saveTopic(LearningTopic(name: "Swift", status: .learning), expectedRevision: nil))
        func snapshotFiles(_ root: URL) throws -> [String: Data] {
            Dictionary(uniqueKeysWithValues: try FileManager.default.contentsOfDirectory(atPath: root.path).map {
                ($0, (try? Data(contentsOf: root.appendingPathComponent($0))) ?? Data()) })
        }
        let before = (try snapshotFiles(promptRoot), try snapshotFiles(learningRoot))
        let raw = await readerFor(memorySource(), prompt: .root(promptRoot), learning: .root(learningRoot)).load(cache: DashboardReadCache(), now: now)
        guard case .loaded(let templates) = raw.prompts, case .loaded(let snapshot) = raw.learning else { return XCTFail() }
        XCTAssertEqual(templates.count, 1); XCTAssertEqual(snapshot.topics.count, 1)
        XCTAssertEqual(try snapshotFiles(promptRoot), before.0); XCTAssertEqual(try snapshotFiles(learningRoot), before.1)
    }

    func testChangingDataDuringTheReadIsReportedNotShownAsFresh() async throws {
        nonisolated final class Shifting: ZhuowangPersistenceDataSource, @unchecked Sendable {
            let domainIdentifier = "shifting"
            private var counter = 0
            func data(forKey key: String) -> Data? { counter += 1; return Data("[\(counter)]".utf8) }
            func set(_ data: Data, forKey key: String) {}
        }
        let raw = await readerFor(Shifting()).load(cache: DashboardReadCache(), now: now)
        guard case .unreadable(let reason) = raw.campaigns, case .unreadable = raw.workflows else { return XCTFail() }
        XCTAssertTrue(reason.contains("变化"))
    }

    func testUnchangedBytesReuseTheDecodeButChangedBytesAreDecodedAgain() async throws {
        let real = campaign("真实活动")
        let bytes = encoded([real])
        let sentinel = campaign("缓存哨兵")
        let cache = DashboardReadCache()
        cache.campaignsBytes = bytes; cache.campaigns = [sentinel]
        let source = memorySource([ZhuowangCampaignStore.storageKey: bytes])
        let reused = await readerFor(source).load(cache: cache, now: now)
        guard case .loaded(let first) = reused.campaigns else { return XCTFail() }
        XCTAssertEqual(first.map(\.name), ["缓存哨兵"], "identical bytes reuse the previous decode")
        source.set(encoded([real, campaign("新增")]), forKey: ZhuowangCampaignStore.storageKey)
        let changed = await readerFor(source).load(cache: cache, now: now)
        guard case .loaded(let second) = changed.campaigns else { return XCTFail() }
        XCTAssertEqual(Set(second.map(\.name)), ["真实活动", "新增"])
        XCTAssertEqual(cache.campaigns?.count, 2)
    }

    func testAWorkflowReadFailureIsNeverTreatedAsNotCreated() throws {
        let a = campaign("甲"), b = campaign("乙")
        let missing = try activities(raw(campaigns: .loaded([a, b]), workflows: .notBuilt))
        XCTAssertFalse(missing.workflowUnreadable)
        XCTAssertEqual(missing.workflowNotCreatedCount, 2)
        XCTAssertTrue(missing.rows.allSatisfy { $0.group == .workflowNotCreated })
        let failed = try activities(raw(campaigns: .loaded([a, b]), workflows: .unreadable("损坏")))
        XCTAssertTrue(failed.workflowUnreadable)
        XCTAssertEqual(failed.workflowNotCreatedCount, 0, "a failure is not counted as not created")
        XCTAssertEqual(failed.rows.count, 2)
        XCTAssertTrue(failed.rows.allSatisfy { $0.group == .workflowUnreadable && $0.progress == nil })
        XCTAssertTrue(failed.rows.allSatisfy { $0.detail.contains("无法读取") })
        XCTAssertEqual(failed.stepsAllConfirmedCount, 0); XCTAssertEqual(failed.attentionCount, 0)
        // The monthly section does not depend on Workflow readability.
        let monthlyCampaign = campaign("月", monthly: ZhuowangMonthlyPlan(activityMonth: "2026-11"))
        guard case .loaded(let items) = DashboardProjection.monthly(raw(campaigns: .loaded([monthlyCampaign]), workflows: .unreadable("损坏"))) else { return XCTFail() }
        XCTAssertEqual(items.count, 1); XCTAssertEqual(items[0].workflowLine, "Workflow 数据无法读取")
    }

    // MARK: Activities: enabled steps, completion, grouping

    func testProgressUsesTheEnabledStepsNotAFixedSix() throws {
        let c = campaign("三步活动")
        // Steps 3...5 disabled: only 3 enabled steps count.
        var flow = workflow(c, [.approved, .approved, .ready, .notStarted, .notStarted, .notStarted], disabled: [3, 4, 5])
        var result = try activities(raw(campaigns: .loaded([c]), workflows: .loaded([flow])))
        XCTAssertEqual(result.rows.first?.progress, "2/3")
        XCTAssertEqual(result.rows.first?.group, .readyForNextStep)
        XCTAssertTrue(result.rows.first?.detail.contains("03") == true, "label position counts enabled steps only")
        // All enabled steps approved while disabled ones are untouched: complete, counted, not listed.
        flow = workflow(c, [.approved, .approved, .approved, .notStarted, .notStarted, .notStarted], disabled: [3, 4, 5])
        result = try activities(raw(campaigns: .loaded([c]), workflows: .loaded([flow])))
        XCTAssertTrue(result.rows.isEmpty); XCTAssertEqual(result.stepsAllConfirmedCount, 1)
        // A middle disabled step shifts positions.
        flow = workflow(c, [.approved, .notStarted, .notStarted, .notStarted, .notStarted, .notStarted], disabled: [1])
        result = try activities(raw(campaigns: .loaded([c]), workflows: .loaded([flow])))
        XCTAssertEqual(result.rows.first?.progress, "1/5")
        XCTAssertTrue(result.rows.first?.detail.contains("02 完整策划案") == true)
    }

    func testZeroOrAllDisabledStepsNeverCountAsComplete() throws {
        let allDisabled = campaign("全停用"), empty = campaign("零步骤")
        var emptyFlow = ZhuowangCampaignWorkflow.standard(campaignID: empty.id); emptyFlow.steps = []
        let flows = [workflow(allDisabled, [], disabled: [0, 1, 2, 3, 4, 5]), emptyFlow]
        let result = try activities(raw(campaigns: .loaded([allDisabled, empty]), workflows: .loaded(flows)))
        XCTAssertEqual(result.stepsAllConfirmedCount, 0)
        XCTAssertEqual(result.noEnabledStepsCount, 2)
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertTrue(result.rows.allSatisfy { $0.group == .noEnabledSteps && $0.progress == nil })
        XCTAssertTrue(result.rows.allSatisfy { $0.detail == "没有启用的 Workflow 步骤" })
    }

    func testEndedAndFullyConfirmedCampaignsAreOnlyCountedAndNeverImplyDelivery() throws {
        let done = campaign("全部确认"), ended = campaign("已结束", status: .completed), doing = campaign("进行中")
        let flows = [workflow(done, Array(repeating: .approved, count: 6)),
                     workflow(ended, [.failed, .notStarted, .notStarted, .notStarted, .notStarted, .notStarted]),
                     workflow(doing, [.approved, .waitingForApproval, .notStarted, .notStarted, .notStarted, .notStarted])]
        let result = try activities(raw(campaigns: .loaded([done, ended, doing]), workflows: .loaded(flows)))
        XCTAssertEqual(result.totalCount, 3); XCTAssertEqual(result.endedCount, 1); XCTAssertEqual(result.stepsAllConfirmedCount, 1)
        XCTAssertEqual(result.rows.map(\.name), ["进行中"])
        let text = result.rows.map { $0.detail + $0.phaseText + $0.scopeName }.joined()
        for word in ["可交付", "可以交付", "导出", "文件不可用"] { XCTAssertFalse(text.contains(word), word) }
    }

    func testGroupingOrderIsStableLimitedAndShuffleIndependent() throws {
        func make(_ name: String, _ statuses: [ZhuowangWorkflowStepStatus], updated: Date) -> (ZhuowangCampaign, ZhuowangCampaignWorkflow?) {
            let c = campaign(name, updated: updated); return (c, statuses.isEmpty ? nil : workflow(c, statuses))
        }
        let t = date("2026-09-10T00:00:00+08:00")
        let items = [
            make("需修改甲", [.needsRevision, .notStarted, .notStarted, .notStarted, .notStarted, .notStarted], updated: t),
            make("需修改乙", [.failed, .notStarted, .notStarted, .notStarted, .notStarted, .notStarted], updated: t.addingTimeInterval(60)),
            make("待确认", [.approved, .waitingForApproval, .notStarted, .notStarted, .notStarted, .notStarted], updated: t),
            make("可推进A", [.approved, .ready, .notStarted, .notStarted, .notStarted, .notStarted], updated: t),
            make("可推进B", [.approved, .ready, .notStarted, .notStarted, .notStarted, .notStarted], updated: t),
            make("未创建", [], updated: t),
            make("生成中", [.running, .notStarted, .notStarted, .notStarted, .notStarted, .notStarted], updated: t),
            make("可推进C", [.ready, .notStarted, .notStarted, .notStarted, .notStarted, .notStarted], updated: t)
        ]
        let campaigns = items.map(\.0), flows = items.compactMap(\.1)
        let first = try activities(raw(campaigns: .loaded(campaigns), workflows: .loaded(flows)))
        XCTAssertEqual(first.rows.count, 5); XCTAssertEqual(first.hiddenCount, 3); XCTAssertEqual(first.totalCount, 8)
        XCTAssertEqual(first.rows.prefix(2).map(\.name), ["需修改乙", "需修改甲"], "attention first, newer update first within a group")
        XCTAssertTrue(first.rows.prefix(2).allSatisfy { $0.group == .needsAttention })
        XCTAssertTrue(first.rows.dropFirst(2).prefix(2).allSatisfy { $0.group == .awaitingReview })
        for _ in 0..<5 {
            let shuffled = try activities(raw(campaigns: .loaded(campaigns.shuffled()), workflows: .loaded(flows.shuffled())))
            XCTAssertEqual(shuffled.rows.map(\.id), first.rows.map(\.id), "stable regardless of input order")
        }
        XCTAssertEqual(first.attentionCount, 2); XCTAssertEqual(first.workflowNotCreatedCount, 1)
        XCTAssertEqual(first.rows.first?.phaseText, "活动期：进行中")
    }

    func testActivityPhaseIsOnlyTheCampaignsOwnDatesAndNoForbiddenWordingAppears() throws {
        let past = campaign("过去", start: "2026-08-01T00:00:00+08:00", end: "2026-08-31T00:00:00+08:00")
        let future = campaign("未来", start: "2026-12-01T00:00:00+08:00", end: "2026-12-31T00:00:00+08:00")
        let result = try activities(raw(campaigns: .loaded([past, future]), workflows: .loaded([])))
        XCTAssertEqual(Set(result.rows.map(\.phaseText)), ["活动期：已结束", "活动期：即将开始"])
        let all = result.rows.map { "\($0.name)\($0.scopeName)\($0.detail)\($0.phaseText)" }.joined()
        for word in ["最近访问", "逾期", "优先级", "今日待办", "百分比", "%", "截止"] { XCTAssertFalse(all.contains(word), word) }
    }

    // MARK: Monthly

    func monthlyPlan(_ month: String, confirmed: Int = 0, received: Int = 0, notApplicable: Int = 0,
                     pool: ZhuowangPrizePoolRelation = .pending) -> ZhuowangMonthlyPlan {
        var plan = ZhuowangMonthlyPlan(activityMonth: month)
        for definition in ZhuowangMonthlyDefinition.outputs.prefix(confirmed) {
            let id = UUID()
            plan.outputs.append(ZhuowangMonthlyOutputRecord(key: definition.key,
                registrations: [ZhuowangMonthlyRegistration(id: id, location: "/virtual/x", versionLabel: "", note: "", createdAt: now)],
                currentRegistrationID: id, confirmedRegistrationID: id, confirmedAt: now))
        }
        let receipts = ZhuowangMonthlyDefinition.inputs.filter { $0.kind == .receipt }
        for definition in receipts.prefix(received) {
            plan.inputs.append(ZhuowangMonthlyInputRecord(key: definition.key, status: .received, note: ""))
        }
        for definition in receipts.dropFirst(received).prefix(notApplicable) {
            plan.inputs.append(ZhuowangMonthlyInputRecord(key: definition.key, status: .notApplicable, note: ""))
        }
        plan.prizePoolRelation = pool
        return plan
    }

    func testMonthlyShowsIndependentStatesAndNeverFoldsNotApplicableIntoComplete() throws {
        let c = campaign("十一月", monthly: monthlyPlan("2026-11", confirmed: 2, received: 4, notApplicable: 2))
        let flows = [workflow(c, [.approved, .approved, .ready, .notStarted, .notStarted, .notStarted])]
        guard case .loaded(let items) = DashboardProjection.monthly(raw(campaigns: .loaded([c]), workflows: .loaded(flows))) else { return XCTFail() }
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.confirmedOutputs, 2); XCTAssertEqual(item.outputTotal, 7)
        // Six ordinary inputs: 4 received, 2 not applicable, 0 requested. The pool is separate and still pending.
        XCTAssertEqual([item.inputsReceived, item.inputsNotApplicable, item.inputsRequested], [4, 2, 0])
        XCTAssertEqual(item.prizePool, .pending, "an undecided prize pool is never hidden by the ordinary inputs")
        XCTAssertEqual(item.workflowLine, "Workflow 2/6 个启用步骤已确认")
        XCTAssertFalse(item.workflowLine.contains("交付")); XCTAssertFalse(item.workflowLine.contains("可交付"))
        let decided = campaign("决定", monthly: monthlyPlan("2026-12", pool: .shared))
        guard case .loaded(let again) = DashboardProjection.monthly(raw(campaigns: .loaded([decided]))) else { return XCTFail() }
        XCTAssertEqual(again[0].prizePool, .shared); XCTAssertEqual(again[0].inputsRequested, 6)
        XCTAssertEqual(again[0].workflowLine, "Workflow 尚未创建")
    }

    func testMonthlyOrderingLimitAndWorkflowLines() throws {
        let t = date("2026-09-01T00:00:00+08:00")
        let nov1 = campaign("十一月先建", created: t, monthly: monthlyPlan("2026-11"), id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
        let nov2 = campaign("十一月后建", created: t.addingTimeInterval(100), monthly: monthlyPlan("2026-11"), id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!)
        let oct = campaign("十月", created: t, monthly: monthlyPlan("2026-10"))
        let sep = campaign("九月", created: t, monthly: monthlyPlan("2026-09"))
        let bad = campaign("坏月份", created: t, monthly: monthlyPlan("bad"))
        let plain = campaign("普通")
        let all = [oct, bad, nov1, plain, sep, nov2]
        for _ in 0..<5 {
            guard case .loaded(let items) = DashboardProjection.monthly(raw(campaigns: .loaded(all.shuffled()))) else { return XCTFail() }
            XCTAssertEqual(items.map(\.name), ["十一月后建", "十一月先建"], "two latest periods; same month ordered by creation, then id")
        }
        guard case .loaded(let three) = DashboardProjection.monthly(raw(campaigns: .loaded([bad, sep, oct]))) else { return XCTFail() }
        XCTAssertEqual(three.map(\.name), ["十月", "九月"], "invalid month labels sort last")
        // Workflow line variants.
        let withFlow = campaign("有流程", monthly: monthlyPlan("2026-11")), noSteps = campaign("无启用", monthly: monthlyPlan("2026-10"))
        let flows = [workflow(withFlow, [.approved, .ready, .notStarted, .notStarted, .notStarted, .notStarted]),
                     workflow(noSteps, [], disabled: [0, 1, 2, 3, 4, 5])]
        guard case .loaded(let lines) = DashboardProjection.monthly(raw(campaigns: .loaded([withFlow, noSteps]), workflows: .loaded(flows))) else { return XCTFail() }
        XCTAssertEqual(lines.map(\.workflowLine), ["Workflow 1/6 个启用步骤已确认", "没有启用的 Workflow 步骤"])
        guard case .loaded(let missing) = DashboardProjection.monthly(raw(campaigns: .loaded([withFlow]), workflows: .notBuilt)) else { return XCTFail() }
        XCTAssertEqual(missing[0].workflowLine, "Workflow 尚未创建")
    }

    // MARK: Prompts and learning

    func testPromptsListOnlyFavoritesNotArchivedByUpdateTimeWithLimit() throws {
        let base = date("2026-09-01T00:00:00+08:00")
        var templates: [PromptTemplate] = (0..<7).map {
            PromptTemplate(name: "收藏\($0)", body: "正文\($0)", category: $0 == 0 ? nil : "分类", isFavorite: true,
                           createdAt: base, updatedAt: base.addingTimeInterval(Double($0) * 60))
        }
        templates.append(PromptTemplate(name: "归档收藏", body: "x", isFavorite: true, isArchived: true, createdAt: base, updatedAt: base.addingTimeInterval(9999)))
        templates.append(PromptTemplate(name: "未收藏", body: "x", createdAt: base, updatedAt: base.addingTimeInterval(8888)))
        guard case .loaded(let prompts) = DashboardProjection.prompts(raw(prompts: .loaded(templates.shuffled()))) else { return XCTFail() }
        XCTAssertEqual(prompts.rows.map(\.name), ["收藏6", "收藏5", "收藏4", "收藏3", "收藏2"])
        XCTAssertEqual(prompts.favoriteCount, 7); XCTAssertEqual(prompts.templateCount, 8, "archived templates are not counted")
        guard case .loaded(let uncategorized) = DashboardProjection.prompts(raw(prompts: .loaded([templates[0]]))) else { return XCTFail() }
        XCTAssertEqual(uncategorized.rows[0].category, "未分类")
        guard case .loaded(let none) = DashboardProjection.prompts(raw(prompts: .loaded([PromptTemplate(name: "只有普通", body: "x")]))) else { return XCTFail() }
        XCTAssertTrue(none.rows.isEmpty); XCTAssertEqual(none.favoriteCount, 0)
    }

    func testLearningExcludesArchivedAndCompletedKeepsExactNextStepAndLimit() throws {
        func topic(_ name: String, _ status: LearningStatus, next: String = "", archived: Bool = false) -> LearningTopic {
            LearningTopic(name: name, status: status, nextStep: next, isArchived: archived)
        }
        let exact = " 读第三章\n  写例子 "
        let topics = [topic("学习A", .learning, next: exact), topic("学习B", .learning, next: "  \n "), topic("计划C", .planned),
                      topic("学习D", .learning), topic("已完成", .completed, next: "不显示"), topic("已归档", .learning, archived: true)]
        let today = LearningDay.today(now: now, timeZone: calendar.timeZone)
        let entries = [LearningEntry(topicID: topics[0].id, studyDay: today, body: "x"),
                       LearningEntry(topicID: topics[1].id, studyDay: LearningDay(string: "2026-10-01")!, body: "y"),
                       LearningEntry(topicID: topics[4].id, studyDay: today, body: "z")]
        let snapshot = LearningSnapshot(topics: topics, entries: entries)
        guard case .loaded(let learning) = DashboardProjection.learning(raw(learning: .loaded(snapshot)), now: now, calendar: calendar) else { return XCTFail() }
        XCTAssertEqual(learning.rows.count, 3)
        XCTAssertEqual(learning.rows.map(\.name).prefix(2), ["学习A", "学习B"], "most recent study first")
        XCTAssertFalse(learning.rows.contains { $0.name == "已完成" || $0.name == "已归档" })
        XCTAssertEqual(Data((learning.rows[0].nextStep ?? "").utf8), Data(exact.utf8), "user text kept exactly")
        XCTAssertNil(learning.rows[1].nextStep, "whitespace-only is not a next step")
        XCTAssertEqual(learning.rows[0].lastStudyText, "上次学习：今天")
        XCTAssertEqual(learning.rows[1].lastStudyText, "上次学习：2026-10-01")
        XCTAssertEqual(learning.learningCount, 3); XCTAssertEqual(learning.plannedCount, 1)
        XCTAssertEqual(learning.rows[2].lastStudyText.isEmpty, false)
        let none = LearningDay.today(now: now, timeZone: calendar.timeZone)
        XCTAssertEqual(none, today)
    }

    // MARK: Cross-day re-projection

    func testANewDayReprojectsDateDerivedTextWithoutReadingAgain() async throws {
        let clock = Box(date("2026-10-09T12:00:00+08:00"))
        let c = campaign("活动", start: "2026-10-01T00:00:00+08:00", end: "2026-10-09T23:00:00+08:00")
        let topic = LearningTopic(name: "主题", status: .learning)
        let entry = LearningEntry(topicID: topic.id, studyDay: LearningDay(string: "2026-10-09")!, body: "x")
        var loads = 0
        let model = DashboardHomeViewModel(calendar: calendar, clock: { clock.value }, observeDayChange: false) { _, readAt in
            loads += 1
            return self.raw(campaigns: .loaded([c]), workflows: .loaded([]),
                learning: .loaded(LearningSnapshot(topics: [topic], entries: [entry])), readAt: readAt)
        }
        model.refresh(); await settle(model)
        XCTAssertEqual(loads, 1)
        guard case .loaded(let before) = model.display.learning.state, case .loaded(let activitiesBefore) = model.display.activities.state
        else { return XCTFail() }
        XCTAssertEqual(before.rows[0].lastStudyText, "上次学习：今天")
        XCTAssertEqual(activitiesBefore.rows[0].phaseText, "活动期：进行中")
        let readAt = model.display.readAt
        clock.value = date("2026-10-10T08:00:00+08:00")
        model.reproject()
        XCTAssertEqual(loads, 1, "re-projection does not read again")
        guard case .loaded(let after) = model.display.learning.state, case .loaded(let activitiesAfter) = model.display.activities.state
        else { return XCTFail() }
        XCTAssertEqual(after.rows[0].lastStudyText, "上次学习：2026-10-09")
        XCTAssertEqual(activitiesAfter.rows[0].phaseText, "活动期：已结束")
        XCTAssertEqual(model.display.readAt, readAt, "the read time stays the snapshot time")
    }

    // MARK: Refresh failure, stale values, generations

    final class Box<T> { var value: T; init(_ value: T) { self.value = value } }

    func settle(_ model: DashboardHomeViewModel) async {
        for _ in 0..<400 where model.loading { try? await Task.sleep(nanoseconds: 5_000_000) }
    }

    func testFailedRefreshKeepsOldValuesOnlyWithTheirTimeAndErrorAndRecovers() async throws {
        let first = date("2026-10-09T10:00:00+08:00"), second = date("2026-10-09T10:05:00+08:00"), third = date("2026-10-09T10:10:00+08:00")
        let clock = Box(first)
        let queue = Box<[DashboardSource<[PromptTemplate]>]>([
            .loaded([PromptTemplate(name: "旧收藏", body: "x", isFavorite: true)]),
            .unreadable("文件损坏"),
            .loaded([PromptTemplate(name: "新收藏", body: "x", isFavorite: true)]),
            .notBuilt])
        let model = DashboardHomeViewModel(calendar: calendar, clock: { clock.value }, observeDayChange: false) { _, readAt in
            self.raw(prompts: queue.value.removeFirst(), readAt: readAt)
        }
        model.refresh(); await settle(model)
        guard case .loaded(let good) = model.display.prompts.state else { return XCTFail() }
        XCTAssertEqual(good.rows.map(\.name), ["旧收藏"]); XCTAssertEqual(model.display.prompts.loadedAt, first)
        clock.value = second; model.refresh(); await settle(model)
        XCTAssertEqual(model.display.prompts.state, .unreadable("文件损坏"))
        XCTAssertEqual(model.display.prompts.stale?.value.rows.map(\.name), ["旧收藏"])
        XCTAssertEqual(model.display.prompts.stale?.loadedAt, first, "the old value keeps its own read time")
        XCTAssertNil(model.display.prompts.loadedAt, "a failed read is not shown as freshly loaded")
        XCTAssertEqual(model.display.readAt, second, "read time is this attempt's snapshot time")
        clock.value = third; model.refresh(); await settle(model)
        guard case .loaded(let recovered) = model.display.prompts.state else { return XCTFail() }
        XCTAssertEqual(recovered.rows.map(\.name), ["新收藏"]); XCTAssertNil(model.display.prompts.stale)
        XCTAssertEqual(model.display.prompts.loadedAt, third)
        clock.value = third.addingTimeInterval(60); model.refresh(); await settle(model)
        XCTAssertEqual(model.display.prompts.state, .notBuilt); XCTAssertNil(model.display.prompts.stale, "a vanished source is reported as it is")
    }

    func testStaleValueSurvivesRepeatedFailuresAndSectionsFailIndependently() async throws {
        let box = Box<[DashboardRaw]>([])
        let t = date("2026-10-09T09:00:00+08:00")
        let goodLearning = LearningSnapshot(topics: [LearningTopic(name: "主题", status: .learning)], entries: [])
        box.value = [
            raw(prompts: .loaded([]), learning: .loaded(goodLearning), readAt: t),
            raw(prompts: .unreadable("甲"), learning: .loaded(goodLearning), readAt: t.addingTimeInterval(60)),
            raw(prompts: .unreadable("乙"), learning: .unreadable("丙"), readAt: t.addingTimeInterval(120))]
        let model = DashboardHomeViewModel(calendar: calendar, clock: { t }, observeDayChange: false) { _, _ in box.value.removeFirst() }
        for _ in 0..<3 { model.refresh(); await settle(model) }
        XCTAssertEqual(model.display.prompts.state, .unreadable("乙"))
        XCTAssertEqual(model.display.prompts.stale?.loadedAt, t, "two failures in a row still point at the last success")
        XCTAssertEqual(model.display.learning.state, .unreadable("丙"))
        XCTAssertEqual(model.display.learning.stale?.loadedAt, t.addingTimeInterval(60))
        XCTAssertEqual(model.display.learning.stale?.value.learningCount, 1)
    }

    func testOnlyTheNewestRefreshWinsAndCancelDiscardsPendingResults() async throws {
        let order = Box<[String]>([])
        var call = 0
        let model = DashboardHomeViewModel(calendar: calendar, observeDayChange: false) { _, readAt in
            call += 1
            let mine = call
            if mine == 1 { try? await Task.sleep(nanoseconds: 150_000_000) }
            order.value.append("call\(mine)")
            return self.raw(campaigns: .loaded([self.campaign("结果\(mine)")]), readAt: readAt)
        }
        model.refresh(); model.refresh()
        await settle(model)
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard case .loaded(let value) = model.display.activities.state else { return XCTFail() }
        XCTAssertEqual(value.rows.map(\.name), ["结果2"], "the stale first result was dropped")
        XCTAssertEqual(Set(order.value), ["call1", "call2"])
        let before = model.display
        let slow = DashboardHomeViewModel(calendar: calendar, observeDayChange: false) { _, readAt in
            try? await Task.sleep(nanoseconds: 100_000_000)
            return self.raw(campaigns: .loaded([self.campaign("不应出现")]), readAt: readAt)
        }
        slow.refresh(); slow.cancel()
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertFalse(slow.display.hasLoaded); XCTAssertFalse(slow.loading)
        XCTAssertEqual(model.display, before)
    }

    // MARK: Greeting and navigation

    func testGreetingFollowsTheClockAndDateIsReal() {
        func greeting(_ hour: Int) -> String { DashboardGreeting.text(now: date(String(format: "2026-10-09T%02d:30:00+08:00", hour)), calendar: calendar) }
        XCTAssertEqual(greeting(6), "早上好"); XCTAssertEqual(greeting(12), "中午好")
        XCTAssertEqual(greeting(15), "下午好"); XCTAssertEqual(greeting(20), "晚上好"); XCTAssertEqual(greeting(2), "晚上好")
        XCTAssertEqual(DashboardGreeting.dateText(now: now, calendar: calendar), "10月9日 星期五")
    }

    func testCardsOnlyOpenExistingModulesNeverCampaignDetail() {
        XCTAssertEqual(DashboardCard.campaigns.target, .zhuowang)
        XCTAssertEqual(DashboardCard.monthly.target, .zhuowang)
        XCTAssertEqual(DashboardCard.prompts.target, .promptVault)
        XCTAssertEqual(DashboardCard.learning.target, .learningCenter)
    }

    // MARK: Rendering

    func testHomeRendersEveryStateOffscreen() async throws {
        let c = campaign("十一月促活", monthly: monthlyPlan("2026-11", confirmed: 1, received: 2, pool: .pending))
        let flows = [workflow(c, [.approved, .waitingForApproval, .notStarted, .notStarted, .notStarted, .notStarted])]
        let topic = LearningTopic(name: "Swift 并发", status: .learning, nextStep: "读 Sendable 一章")
        let loaded = raw(campaigns: .loaded([c, campaign("另一个")]), workflows: .loaded(flows),
            prompts: .loaded([PromptTemplate(name: "周报模板", body: "x", category: "工作", isFavorite: true)]),
            learning: .loaded(LearningSnapshot(topics: [topic], entries: [])))
        let notBuilt = raw(campaigns: .notBuilt, workflows: .notBuilt, prompts: .notBuilt, learning: .notBuilt)
        let blocked = raw(campaigns: .loaded([]), prompts: .blocked("隔离保护"), learning: .blocked("隔离保护"))
        let failing = Box<[DashboardRaw]>([loaded, raw(campaigns: .unreadable("损坏"), workflows: .unreadable("损坏"),
            prompts: .unreadable("损坏"), learning: .unreadable("损坏"))])
        let root = tempRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        func png<V: View>(_ view: V, _ name: String) throws {
            let renderer = ImageRenderer(content: view)
            let image = try XCTUnwrap(renderer.nsImage, name)
            let rep = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
            let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
            try data.write(to: root.appendingPathComponent(name + ".png"))
            XCTAssertGreaterThan(data.count, 1000, name)
        }
        for (name, source) in [("loaded", [loaded]), ("not-built", [notBuilt]), ("blocked", [blocked])] {
            let queue = Box(source)
            let model = DashboardHomeViewModel(calendar: calendar, observeDayChange: false) { _, _ in queue.value[0] }
            model.refresh(); await settle(model)
            try png(DashboardHomeView(model: model, open: { _ in }).frame(width: 1100, height: 1500), name)
        }
        let stale = DashboardHomeViewModel(calendar: calendar, observeDayChange: false) { _, readAt in
            var next = failing.value.removeFirst(); next.readAt = readAt; return next
        }
        stale.refresh(); await settle(stale); stale.refresh(); await settle(stale)
        XCTAssertNotNil(stale.display.activities.stale)
        try png(DashboardHomeView(model: stale, open: { _ in }).frame(width: 1100, height: 1500), "stale")
    }
}
