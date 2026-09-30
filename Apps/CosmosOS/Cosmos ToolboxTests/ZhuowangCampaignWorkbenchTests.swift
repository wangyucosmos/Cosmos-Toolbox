import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox


final class ZhuowangCampaignWorkbenchTests: XCTestCase {

    // MARK: Progress Projection

    func testProgressReflectsWorkflowStepsAdoptionAndNextAction() {
        let fixture = WorkbenchFixture()
        let progress = fixture.progress()

        let national = fixture.row("国庆福利周", in: progress)
        XCTAssertEqual(national.scopeName, "浙江")
        XCTAssertEqual(national.completedSteps, 4)
        XCTAssertEqual(national.totalSteps, 6)
        XCTAssertEqual(national.category, .needsAttention)
        XCTAssertEqual(national.attentionSteps.map(\.label), ["05 产品原型设计"])
        XCTAssertEqual(national.nextActionText, "处理 05 产品原型设计（需修改）")
        XCTAssertEqual(national.adoptedArtifactCount, 4)

        let henan = fixture.row("秋季签到", in: progress)
        XCTAssertEqual(henan.category, .readyForNextStep)
        XCTAssertEqual(henan.nextStep?.label, "03 完整策划案")
        XCTAssertEqual(henan.nextActionText, "开始 03 完整策划案")

        let anhui = fixture.row("会员日", in: progress)
        XCTAssertEqual(anhui.category, .awaitingReview)
        XCTAssertEqual(anhui.nextActionText, "05 产品原型设计：等待确认")

        let delivery = fixture.row("客服体验月", in: progress)
        XCTAssertTrue(delivery.isWorkflowComplete)
        XCTAssertEqual(delivery.adoptedArtifactCount, 6)
        XCTAssertEqual(delivery.deliverableFileCount, 6)
        XCTAssertEqual(delivery.category, .deliverable)

        let summer = fixture.row("夏日回顾", in: progress)
        XCTAssertEqual(summer.category, .completedFilesUnavailable)
        XCTAssertEqual(summer.adoptionConflictCount, 1)
        XCTAssertEqual(summer.adoptedArtifactCount, 5)

        let preview = fixture.row("双十一预热", in: progress)
        XCTAssertFalse(preview.hasWorkflow)
        XCTAssertEqual(preview.category, .workflowNotCreated)
        XCTAssertEqual(preview.scopeName, "全国促活")

        let quiz = fixture.row("暑期答题", in: progress)
        XCTAssertEqual(quiz.category, .needsAttention)
        XCTAssertEqual(quiz.nextActionText, "处理 01 需求整理（失败）")
    }

    func testDisabledStepsAreExcludedAndAttentionOutranksNextStep() {
        let fixture = WorkbenchFixture()
        var workflow = fixture.workflows.first { $0.campaignID == fixture.campaignID("秋季签到") }!
        workflow.steps[5].isEnabled = false
        workflow.steps[1].status = .needsRevision
        let progress = ZhuowangCampaignProgressBuilder.build(
            campaigns: fixture.campaigns.filter { $0.id == workflow.campaignID },
            workflows: [workflow],
            provinces: fixture.provinces,
            modules: fixture.modules,
            now: fixture.now,
            calendar: fixture.calendar,
            deliverableCounter: { _, _, _, _ in 0 }
        )[0]

        XCTAssertEqual(progress.totalSteps, 5)
        XCTAssertEqual(progress.completedSteps, 1)
        XCTAssertEqual(progress.category, .needsAttention)
        XCTAssertEqual(progress.nextStep?.label, "02 策划思路")
    }

    func testDatePhaseUsesCampaignCalendarDaysOnly() {
        let fixture = WorkbenchFixture()
        func phase(_ start: String, _ end: String) -> (ZhuowangCampaignDatePhase, Int) {
            let campaign = ZhuowangCampaign(
                name: "日期", scopeType: .other,
                startDate: fixture.date(start), endDate: fixture.date(end)
            )
            let result = ZhuowangCampaignProgressBuilder.datePhase(
                campaign, now: fixture.now, calendar: fixture.calendar
            )
            return (result.0, result.1)
        }

        XCTAssertTrue(phase("2026-10-01 00:00", "2026-10-02 00:00") == (.upcoming, 1))
        XCTAssertTrue(phase("2026-09-30 23:59", "2026-10-01 00:00") == (.ongoing, 1))
        XCTAssertTrue(phase("2026-09-01 00:00", "2026-09-30 00:00") == (.ongoing, 0))
        XCTAssertTrue(phase("2026-09-01 00:00", "2026-09-29 23:59") == (.ended, 1))
        // End before start is treated as a one-day campaign, never negative.
        XCTAssertTrue(phase("2026-10-05 00:00", "2026-10-01 00:00") == (.upcoming, 5))

        let progress = fixture.progress()
        XCTAssertEqual(fixture.row("国庆福利周", in: progress).datePhase, .ongoing)
        XCTAssertEqual(fixture.row("秋季签到", in: progress).datePhase, .upcoming)
        XCTAssertEqual(fixture.row("客服体验月", in: progress).dayDistance, 2)
        XCTAssertEqual(fixture.row("夏日回顾", in: progress).dayDistance, 61)
    }

    func testFilterByProvinceModuleStatusAndName() {
        let fixture = WorkbenchFixture()
        let progress = fixture.progress()
        func names(_ filter: ZhuowangCampaignWorkbenchFilter) -> [String] {
            progress.filter(filter.matches).map(\.campaign.name).sorted()
        }

        var filter = ZhuowangCampaignWorkbenchFilter()
        XCTAssertEqual(names(filter).count, 7)
        XCTAssertFalse(filter.isActive)

        filter.scope = .province(fixture.province("浙江").id)
        XCTAssertEqual(names(filter), ["国庆福利周", "客服体验月"])

        filter.scope = .module("national")
        XCTAssertEqual(names(filter), ["双十一预热"])

        filter = ZhuowangCampaignWorkbenchFilter(status: .active)
        XCTAssertEqual(names(filter), ["国庆福利周", "暑期答题"])

        filter = ZhuowangCampaignWorkbenchFilter(query: "  签到 ")
        XCTAssertEqual(names(filter), ["秋季签到"])
        XCTAssertTrue(filter.isActive)

        filter = ZhuowangCampaignWorkbenchFilter(scope: .province(fixture.province("河南").id), status: .active)
        XCTAssertEqual(names(filter), [])
    }

    func testDeliverableCountUsesDeliveryPackageEligibility() throws {
        let fixture = WorkbenchFixture()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Cosmos-Workbench-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = ZhuowangWorkspaceFileManager(rootURL: root)
        let campaign = fixture.campaign("客服体验月")
        let workspace = try manager.createCampaignWorkspace(provinceName: "浙江", campaignName: campaign.name)
        var workflow = fixture.workflows.first { $0.campaignID == campaign.id }!

        // Only the first two adopted artifacts have real files in the Workspace.
        let adopted = workflow.artifacts.indices.filter { workflow.artifacts[$0].isApprovedVersion }
        for (offset, index) in adopted.enumerated() where offset < 2 {
            let file = workspace.appendingPathComponent("产物_\(offset).md")
            try Data("# 产物\n".utf8).write(to: file)
            workflow.artifacts[index].location = file.path
        }

        let progress = ZhuowangCampaignProgressBuilder.build(
            campaigns: [campaign],
            workflows: [workflow],
            provinces: fixture.provinces,
            modules: fixture.modules,
            now: fixture.now,
            calendar: fixture.calendar,
            deliverableCounter: { campaign, _, artifacts, steps in
                ZhuowangArtifactDeliveryPackageService()
                    .candidates(
                        snapshot: ZhuowangArtifactDeliverySnapshot(
                            campaignID: campaign.id, artifacts: artifacts, steps: steps
                        ),
                        campaignWorkspaceURL: workspace
                    )
                    .filter(\.isEligible)
                    .count
            }
        )[0]

        XCTAssertEqual(progress.adoptedArtifactCount, 6)
        XCTAssertEqual(progress.deliverableFileCount, 2)
        XCTAssertEqual(progress.category, .deliverable)
    }

    func testSummaryIsReadOnlyForStoresAndNeverCreatesWorkflows() {
        let fixture = WorkbenchFixture()
        let stores = fixture.makeStores()
        // Store initialisation may normalise provider data; only writes made
        // after this point could come from the summary.
        stores.dataSource.resetWriteLog()
        let before = stores.dataSource.storage

        let progress = ZhuowangCampaignProgressBuilder.build(
            campaigns: stores.campaigns.campaigns,
            workflows: stores.workflows.workflows,
            provinces: stores.workspace.provinces,
            modules: stores.workspace.modules,
            now: fixture.now,
            calendar: fixture.calendar,
            deliverableCounter: { _, _, _, _ in 0 }
        )

        XCTAssertEqual(progress.count, 7)
        XCTAssertEqual(stores.workflows.workflows.count, 6)
        XCTAssertNil(stores.workflows.workflow(forCampaignID: fixture.campaignID("双十一预热")))
        XCTAssertEqual(stores.dataSource.storage, before)
        XCTAssertEqual(stores.dataSource.writeCount, 0)
    }

    func testRouteDeliversEachRequestOnce() {
        let route = ZhuowangCampaignDetailRoute()
        XCTAssertNil(route.takeRequest())

        route.show(.workflow)
        XCTAssertEqual(route.requestSerial, 1)
        XCTAssertEqual(route.takeRequest(), .workflow)
        XCTAssertNil(route.takeRequest())

        route.show(.deliveryPackage)
        route.show(.artifacts)
        XCTAssertEqual(route.requestSerial, 3)
        XCTAssertEqual(route.takeRequest(), .artifacts)
    }


    // MARK: Rendered View

    func testWorkbenchRendersFixtureStoresAndEmptyStates() throws {
        let fixture = WorkbenchFixture()
        let stores = fixture.makeStores()
        let before = stores.dataSource.storage
        let output = WorkbenchFixture.screenshotDirectory
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let full = try render(
            ZhuowangCampaignWorkbenchView(
                campaignStore: stores.campaigns,
                workspaceStore: stores.workspace,
                workflowStore: stores.workflows,
                now: { fixture.now },
                deliverableCounter: fixture.counter
            ),
            height: 2040,
            name: "01-推进工作台-全部活动.png",
            into: output
        )
        XCTAssertGreaterThan(full, 0.02)

        let scoped = try render(
            ZhuowangCampaignWorkbenchView(
                campaignStore: stores.campaigns,
                workspaceStore: stores.workspace,
                workflowStore: stores.workflows,
                fixedScope: .province(fixture.province("浙江").id),
                now: { fixture.now },
                deliverableCounter: fixture.counter
            ),
            height: 1180,
            name: "02-浙江概览-范围内推进.png",
            into: output
        )
        XCTAssertGreaterThan(scoped, 0.02)

        let empty = WorkbenchFixture(empty: true).makeStores()
        let emptyShare = try render(
            ZhuowangCampaignWorkbenchView(
                campaignStore: empty.campaigns,
                workspaceStore: empty.workspace,
                workflowStore: empty.workflows,
                now: { fixture.now }
            ),
            height: 620,
            name: "03-空状态.png",
            into: output
        )
        XCTAssertGreaterThan(emptyShare, 0.01)

        XCTAssertEqual(stores.dataSource.storage, before)

        // Same fixture as plist payloads for an isolated App launch
        // (temporary Bundle ID + Store Phase 1 suite). Written only here.
        let suitePayload = [
            ZhuowangCampaignStore.storageKey: stores.dataSource.storage[ZhuowangCampaignStore.storageKey]!,
            ZhuowangWorkspaceStore.storageKey: stores.dataSource.storage[ZhuowangWorkspaceStore.storageKey]!
        ]
        let bundlePayload = [
            ZhuowangWorkflowStore.workflowStorageKey:
                stores.dataSource.storage[ZhuowangWorkflowStore.workflowStorageKey]!
        ]
        try PropertyListSerialization.data(fromPropertyList: suitePayload, format: .xml, options: 0)
            .write(to: output.appendingPathComponent("fixture-suite.plist"))
        try PropertyListSerialization.data(fromPropertyList: bundlePayload, format: .xml, options: 0)
            .write(to: output.appendingPathComponent("fixture-bundle.plist"))
    }


    // MARK: Rendering Helper

    /// Renders the view in an offscreen window and returns the share of
    /// non-background pixels, proving that content was actually drawn.
    private func render<V: View>(
        _ view: V,
        height: CGFloat,
        name: String,
        into directory: URL
    ) throws -> Double {
        let size = NSSize(width: 1160, height: height)
        let host = NSHostingView(
            rootView: view
                .padding(38)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, .light)
        )
        host.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        host.layoutSubtreeIfNeeded()

        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: directory.appendingPathComponent(name))

        let background = bitmap.colorAt(x: 2, y: 2)
        var differing = 0
        var sampled = 0
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: 6) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 6) {
                sampled += 1
                if let color = bitmap.colorAt(x: x, y: y), color != background {
                    differing += 1
                }
            }
        }
        return Double(differing) / Double(max(sampled, 1))
    }
}


// MARK: - Fixture

/// In-memory fixture only; nothing is written to UserDefaults or disk.
@MainActor
struct WorkbenchFixture {

    static let screenshotDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("Cosmos-Workbench-Screens", isDirectory: true)

    let calendar: Calendar
    let now: Date
    let provinces: [ZhuowangProvince]
    let modules: [ZhuowangModule]
    let campaigns: [ZhuowangCampaign]
    let workflows: [ZhuowangCampaignWorkflow]
    /// Campaigns whose adopted artifacts are treated as deliverable files.
    let deliverableCampaignIDs: Set<UUID>

    init(empty: Bool = false) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        self.calendar = calendar

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        func date(_ text: String) -> Date { formatter.date(from: text)! }
        now = date("2026-09-30 12:00")

        provinces = ["浙江", "河南", "安徽"].map {
            ZhuowangProvince(id: UUID(), name: $0, englishName: $0)
        }
        modules = [
            ZhuowangModule(id: "welfare", name: "福利中心", englishName: "Welfare", icon: "gift", usesProvinces: true),
            ZhuowangModule(id: "national", name: "全国促活", englishName: "National", icon: "globe", usesProvinces: false)
        ]

        guard !empty else {
            campaigns = []
            workflows = []
            deliverableCampaignIDs = []
            return
        }

        let provinceID = Dictionary(uniqueKeysWithValues: provinces.map { ($0.name, $0.id) })
        func campaign(
            _ name: String, _ province: String?, _ status: ZhuowangCampaignStatus,
            _ start: String, _ end: String
        ) -> ZhuowangCampaign {
            ZhuowangCampaign(
                name: name,
                scopeType: province == nil ? .national : .province,
                provinceID: province.flatMap { provinceID[$0] },
                moduleID: province == nil ? "national" : nil,
                startDate: date(start + " 00:00"),
                endDate: date(end + " 00:00"),
                status: status
            )
        }

        let list = [
            campaign("国庆福利周", "浙江", .active, "2026-09-25", "2026-10-07"),
            campaign("秋季签到", "河南", .planning, "2026-10-10", "2026-10-31"),
            campaign("会员日", "安徽", .designing, "2026-10-03", "2026-10-20"),
            campaign("客服体验月", "浙江", .pendingLaunch, "2026-09-01", "2026-09-28"),
            campaign("双十一预热", nil, .planning, "2026-10-20", "2026-11-11"),
            campaign("夏日回顾", "河南", .completed, "2026-07-01", "2026-07-31"),
            campaign("暑期答题", "安徽", .active, "2026-09-15", "2026-10-15")
        ]
        campaigns = list

        func workflow(
            _ campaign: ZhuowangCampaign,
            _ statuses: [ZhuowangWorkflowStepStatus],
            conflict: Bool = false
        ) -> ZhuowangCampaignWorkflow {
            var workflow = ZhuowangCampaignWorkflow.standard(campaignID: campaign.id)
            for (index, status) in statuses.enumerated() {
                workflow.steps[index].status = status
                guard status == .approved else {
                    continue
                }
                let step = workflow.steps[index]
                workflow.artifacts.append(
                    ZhuowangArtifact(
                        campaignID: campaign.id, stepID: step.id,
                        name: step.title, type: .markdown,
                        location: "/nonexistent/\(step.title)_V2.md",
                        version: 2, isApprovedVersion: true
                    )
                )
                workflow.artifacts.append(
                    ZhuowangArtifact(
                        campaignID: campaign.id, stepID: step.id,
                        name: step.title, type: .markdown,
                        location: "/nonexistent/\(step.title)_V1.md",
                        version: 1, isApprovedVersion: conflict && index == 0
                    )
                )
            }
            return workflow
        }

        let done: [ZhuowangWorkflowStepStatus] = Array(repeating: .approved, count: 6)
        workflows = [
            workflow(list[0], [.approved, .approved, .approved, .approved, .needsRevision, .notStarted]),
            workflow(list[1], [.approved, .approved, .ready, .notStarted, .notStarted, .notStarted]),
            workflow(list[2], [.approved, .approved, .approved, .approved, .waitingForApproval, .notStarted]),
            workflow(list[3], done),
            workflow(list[5], done, conflict: true),
            workflow(list[6], [.failed, .notStarted, .notStarted, .notStarted, .notStarted, .notStarted])
        ]
        deliverableCampaignIDs = [list[3].id]
    }

    var counter: ZhuowangCampaignProgressBuilder.DeliverableCounter {
        let ids = deliverableCampaignIDs
        return { campaign, _, artifacts, _ in
            ids.contains(campaign.id) ? artifacts.filter(\.isApprovedVersion).count : 0
        }
    }

    func progress() -> [ZhuowangCampaignProgress] {
        ZhuowangCampaignProgressBuilder.build(
            campaigns: campaigns,
            workflows: workflows,
            provinces: provinces,
            modules: modules,
            now: now,
            calendar: calendar,
            deliverableCounter: counter
        )
    }

    func row(_ name: String, in progress: [ZhuowangCampaignProgress]) -> ZhuowangCampaignProgress {
        progress.first { $0.campaign.name == name }!
    }

    func campaign(_ name: String) -> ZhuowangCampaign {
        campaigns.first { $0.name == name }!
    }

    func campaignID(_ name: String) -> UUID {
        campaign(name).id
    }

    func province(_ name: String) -> ZhuowangProvince {
        provinces.first { $0.name == name }!
    }

    func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    struct Stores {
        let dataSource: ZhuowangInMemoryPersistenceDataSource
        let campaigns: ZhuowangCampaignStore
        let workspace: ZhuowangWorkspaceStore
        let workflows: ZhuowangWorkflowStore
    }

    /// Real Stores over an in-memory data source seeded with the fixture.
    func makeStores() -> Stores {
        let encoder = JSONEncoder()
        let dataSource = ZhuowangInMemoryPersistenceDataSource(
            storage: [
                ZhuowangCampaignStore.storageKey: try! encoder.encode(campaigns),
                ZhuowangWorkspaceStore.storageKey: try! encoder.encode(
                    ZhuowangWorkspaceSnapshot(modules: modules, provinces: provinces, categories: [])
                ),
                ZhuowangWorkflowStore.workflowStorageKey: try! encoder.encode(workflows)
            ]
        )
        let configuration = isolatedConfiguration(dataSource: dataSource)
        return Stores(
            dataSource: dataSource,
            campaigns: ZhuowangCampaignStore(persistenceConfiguration: configuration),
            workspace: ZhuowangWorkspaceStore(persistenceConfiguration: configuration),
            workflows: ZhuowangWorkflowStore(persistenceConfiguration: configuration)
        )
    }
}
