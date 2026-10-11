import XCTest
import SwiftUI
import AppKit
@testable import Cosmos_Toolbox

/// 体验升级第三步 B 线：活动详情窗口改版。
/// 只使用合成数据：内存数据源 + `/private/tmp/CosmosWorkspaceFiles-<UUID>` 隔离工作文件根。
/// 不读写正式 UserDefaults，不访问 ~/Documents，不执行任何 Provider / Harness。
@MainActor
final class ZhuowangCampaignDetailUITests: XCTestCase {

    // MARK: Fixture

    private var roots: [URL] = []
    private var suites: [String] = []

    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        for suite in suites { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        roots = []; suites = []
        super.tearDown()
    }

    private func preferences(reduced: Bool = true) throws -> CosmosUIPreferences {
        let suite = "CosmosStep3B.UI." + UUID().uuidString
        suites.append(suite)
        let prefs = CosmosUIPreferences(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        if reduced { prefs.motion = .reduced }
        return prefs
    }

    struct Fixture {
        let root: URL
        let configuration: ZhuowangStorePersistenceConfiguration
        let campaignStore: ZhuowangCampaignStore
        let workflowStore: ZhuowangWorkflowStore
        let province: ZhuowangProvince
        let sixStep: ZhuowangCampaign
        let monthly: ZhuowangCampaign
        let deliverable: ZhuowangCampaign
        let tool: ZhuowangExternalToolIntegration
        let connections: ZhuowangWorkflowConnections
        var manager: ZhuowangWorkspaceFileManager { workflowStore.workspaceFileManager }
    }

    private func makeRoot() throws -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosWorkspaceFiles-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        roots.append(root)
        return root
    }

    private func makeEmptyStores(root: URL) -> (ZhuowangStorePersistenceConfiguration, ZhuowangCampaignStore, ZhuowangWorkflowStore) {
        let source = ZhuowangInMemoryPersistenceDataSource(storage: [:])
        let configuration = ZhuowangStorePersistenceConfiguration(
            dataSource: source, isIsolated: true,
            isolationSuiteName: source.domainIdentifier, workspaceFilesRootURL: root)
        return (configuration, ZhuowangCampaignStore(persistenceConfiguration: configuration),
                ZhuowangWorkflowStore(persistenceConfiguration: configuration))
    }

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func makeFixture() throws -> Fixture {
        let root = try makeRoot()
        let (configuration, campaignStore, workflowStore) = makeEmptyStores(root: root)
        XCTAssertNil(workflowStore.workspaceFileManager.accessFailure, "隔离根必须先生效")
        XCTAssertEqual(workflowStore.workspaceFileManager.cosmosRootURL.path, root.path)

        let province = ZhuowangProvince(id: UUID(), name: "浙江", englishName: "Zhejiang")
        func campaign(_ name: String, notes: String = "") throws -> ZhuowangCampaign {
            XCTAssertEqual(campaignStore.addCampaign(
                name: name, scopeType: .province, provinceID: province.id,
                startDate: start, endDate: start.addingTimeInterval(30 * 86_400),
                status: .designing, notes: notes), .succeeded)
            return try XCTUnwrap(campaignStore.campaigns.first { $0.name == name })
        }
        let sixStep = try campaign("十月福利活动（合成）", notes: "合成夹具：六步各处于不同状态。")
        let deliverable = try campaign("国庆签到活动（合成）", notes: "合成夹具：六步均已采用，文件已落盘。")
        XCTAssertEqual(campaignStore.addCampaign(
            name: "月度会员促活 2026-10（合成）", scopeType: .national, moduleID: "national",
            startDate: start, endDate: start.addingTimeInterval(30 * 86_400),
            status: .planning, monthlyMonth: "2026-10"), .succeeded)
        let monthly = try XCTUnwrap(campaignStore.campaigns.first { $0.name.hasPrefix("月度会员促活") })

        let tool = ZhuowangExternalToolIntegration(
            kind: .figma, name: "Figma", status: .available,
            capabilities: [.prototypeDesign], isEnabled: true)
        let connections = ZhuowangWorkflowConnections(
            recommendedConnection: { _ in nil }, route: { _, _ in nil },
            availableTools: { $0 == .prototypeDesign ? [tool] : [] },
            toolIntegration: { $0 == tool.id ? tool : nil })

        let fixture = Fixture(root: root, configuration: configuration, campaignStore: campaignStore,
                              workflowStore: workflowStore, province: province, sixStep: sixStep,
                              monthly: monthly, deliverable: deliverable, tool: tool, connections: connections)
        try seedSixStep(fixture)
        try seedDeliverable(fixture)
        try seedMonthly(fixture)
        return fixture
    }

    private var deepSeek: (ZhuowangWorkflowStore) -> ZhuowangAIProvider? = { store in
        store.visibleProviders().first { $0.kind == .deepSeekHarness } ?? store.visibleProviders().first
    }

    @discardableResult
    private func write(_ f: Fixture, _ campaign: ZhuowangCampaign, _ step: ZhuowangWorkflowStep,
                       name: String, version: Int) throws -> ZhuowangArtifact {
        let url = try f.manager.writeMarkdownArtifact(
            provinceName: f.province.pathName, campaignName: campaign.name, stepKind: step.kind,
            artifactName: name, version: version,
            content: "# \(name) V\(version)\n\n合成正文：用于界面验证，不含任何真实业务数据。\n\n- 要点一\n- 要点二\n")
        return ZhuowangArtifact(
            campaignID: campaign.id, stepID: step.id, name: name, type: .markdown,
            providerID: deepSeek(f.workflowStore)?.id, location: url.path,
            content: try String(contentsOf: url, encoding: .utf8), version: version,
            createdAt: start.addingTimeInterval(Double(version) * 3_600),
            updatedAt: start.addingTimeInterval(Double(version) * 3_600))
    }

    private func seedSixStep(_ f: Fixture) throws {
        var workflow = f.workflowStore.getOrCreateWorkflow(forCampaignID: f.sixStep.id)
        let provider = deepSeek(f.workflowStore)
        let statuses: [ZhuowangWorkflowStepStatus] =
            [.approved, .approved, .needsRevision, .failed, .waitingForApproval, .notStarted]
        // Opening a Campaign window runs the existing local recovery, which approves any step that owns
        // local files; so only approved steps own files and the fixture stays unchanged by rendering.
        let plans: [[(Int, Bool)]] = [[(1, true)], [(1, false), (2, false), (3, true)], [], [], [], []]
        let ordered = workflow.steps.sorted { $0.sortOrder < $1.sortOrder }
        for (index, step) in ordered.enumerated() {
            let i = workflow.steps.firstIndex { $0.id == step.id }!
            workflow.steps[i].status = statuses[index]
            workflow.steps[i].selectedProviderID = (index == 3 || index == 5) ? nil : provider?.id
            if step.kind == .prototype { workflow.steps[i].selectedToolIDs = [f.tool.id] }
            for (version, adopted) in plans[index] {
                var artifact = try write(f, f.sixStep, step, name: step.title, version: version)
                artifact.isApprovedVersion = adopted
                workflow.artifacts.append(artifact)
            }
        }
        f.workflowStore.updateWorkflow(workflow)
    }

    private func seedDeliverable(_ f: Fixture) throws {
        var workflow = f.workflowStore.getOrCreateWorkflow(forCampaignID: f.deliverable.id)
        let provider = deepSeek(f.workflowStore)
        for step in workflow.steps.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let i = workflow.steps.firstIndex { $0.id == step.id }!
            workflow.steps[i].status = .approved
            workflow.steps[i].selectedProviderID = provider?.id
            var artifact = try write(f, f.deliverable, step, name: step.title, version: 1)
            artifact.isApprovedVersion = true
            workflow.artifacts.append(artifact)
        }
        f.workflowStore.updateWorkflow(workflow)
    }

    private func seedMonthly(_ f: Fixture) throws {
        func update(_ mutation: ZhuowangMonthlyMutation) {
            let revision = f.campaignStore.campaign(id: f.monthly.id)?.monthly?.revision ?? 0
            XCTAssertEqual(f.campaignStore.updateMonthlyPlan(
                campaignID: f.monthly.id, expectedRevision: revision, mutation).succeeded, true)
        }
        let key = "monthly.output.idea"
        let id = UUID()
        update(.addRegistration(outputKey: key, id: id, location: "https://example.com/monthly/idea",
                                versionLabel: "V1.1", note: "合成登记", at: start))
        update(.confirmRegistration(outputKey: key, registrationID: id))
        update(.setInput(key: "monthly.input.prizeTable", status: .received, note: "已收到"))
    }

    // MARK: Pure presentation rules

    private func steps(_ statuses: [ZhuowangWorkflowStepStatus], enabled: [Bool]? = nil) -> [ZhuowangWorkflowStep] {
        let template = ZhuowangCampaignWorkflow.standard(campaignID: UUID()).steps.sorted { $0.sortOrder < $1.sortOrder }
        return statuses.enumerated().map { index, status in
            var step = template[index]
            step.status = status
            step.isEnabled = enabled?[index] ?? true
            return step
        }
    }

    func testProgressAndTimelineCountOnlyEnabledSteps() {
        var workflow = ZhuowangCampaignWorkflow.standard(campaignID: UUID())
        let ordered = workflow.steps.sorted { $0.sortOrder < $1.sortOrder }
        for (index, step) in ordered.enumerated() {
            let i = workflow.steps.firstIndex { $0.id == step.id }!
            workflow.steps[i].status = index < 2 ? .approved : .notStarted
            if index == 5 || index == 4 { workflow.steps[i].isEnabled = false }
        }
        let enabled = ZhuowangWorkflowUIModel.enabledSteps(in: workflow)
        XCTAssertEqual(enabled.count, 4)
        XCTAssertEqual(enabled.map(\.sortOrder), enabled.map(\.sortOrder).sorted())
        let progress = ZhuowangWorkflowUIModel.progress(of: enabled)
        XCTAssertEqual(progress.completed, 2)
        XCTAssertEqual(progress.total, 4, "停用的步骤不计入进度环")
        let items = ZhuowangWorkflowUIModel.timelineItems(
            steps: enabled, artifacts: [], providerName: { _ in nil }, toolName: { _ in nil },
            canAct: { _ in false }, actionTitle: { _ in nil })
        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items.map(\.position), [1, 2, 3, 4])
        XCTAssertFalse(items.contains { $0.title == ordered[5].title || $0.title == ordered[4].title })
        // A skipped step counts as done, like the progress workbench.
        XCTAssertEqual(ZhuowangWorkflowUIModel.progress(of: steps([.skipped, .approved, .completed, .ready])).completed, 3)
    }

    func testProviderAndToolAreSeparateOnTimelineItems() {
        let list = steps([.approved, .ready, .ready, .ready, .ready, .notStarted])
        let prototypeID = list[4].id
        var withTool = list
        withTool[4].requiredCapabilities = [.prototypeDesign]
        let items = ZhuowangWorkflowUIModel.timelineItems(
            steps: withTool, artifacts: [],
            providerName: { $0.id == prototypeID ? "DeepSeek Harness" : nil },
            toolName: { $0.id == prototypeID ? "Figma" : nil },
            canAct: { _ in true }, actionTitle: { _ in "准备任务" })
        let prototype = items[4]
        XCTAssertEqual(prototype.provider, "DeepSeek Harness")
        XCTAssertEqual(prototype.tool, "Figma")
        XCTAssertNotEqual(prototype.provider, prototype.tool, "Figma 是 Tool，不是 AI Provider")
        // Steps without any tool requirement show no tool capsule; a tool step with none chosen shows an empty choice.
        XCTAssertNil(items[0].tool)
        withTool[4].requiredCapabilities = [.prototypeDesign]
        let unchosen = ZhuowangWorkflowUIModel.timelineItems(
            steps: withTool, artifacts: [], providerName: { _ in nil }, toolName: { _ in nil },
            canAct: { _ in true }, actionTitle: { _ in nil })
        XCTAssertEqual(unchosen[4].tool, "")
        XCTAssertNil(unchosen[4].provider)
    }

    func testNextStepAndSelectionPointAtFirstOpenEnabledStep() {
        let list = steps([.approved, .approved, .needsRevision, .failed, .waitingForApproval, .notStarted])
        XCTAssertEqual(ZhuowangWorkflowUIModel.nextStep(in: list)?.id, list[2].id)
        XCTAssertEqual(ZhuowangWorkflowUIModel.effectiveStep(selectedID: nil, in: list)?.id, list[2].id)
        XCTAssertEqual(ZhuowangWorkflowUIModel.effectiveStep(selectedID: list[4].id, in: list)?.id, list[4].id)
        XCTAssertEqual(ZhuowangWorkflowUIModel.effectiveStep(selectedID: UUID(), in: list)?.id, list[2].id, "过期选择回到下一步")
        // Disabled steps never become "next".
        let skippedOpen = steps([.approved, .notStarted, .ready], enabled: [true, false, true])
        let enabledOnly = skippedOpen.filter(\.isEnabled)
        XCTAssertEqual(ZhuowangWorkflowUIModel.nextStep(in: enabledOnly)?.id, skippedOpen[2].id)
        XCTAssertNil(ZhuowangWorkflowUIModel.nextStep(in: steps([.approved, .completed, .skipped])))
        let allDone = steps([.approved, .completed])
        XCTAssertEqual(ZhuowangWorkflowUIModel.effectiveStep(selectedID: nil, in: allDone)?.id, allDone.first?.id)
        // Focus requests for the same step stay distinguishable.
        let id = UUID()
        XCTAssertNotEqual(ZhuowangWorkflowFocusRequest(stepID: id, serial: 1), ZhuowangWorkflowFocusRequest(stepID: id, serial: 2))
    }

    func testLockedStepNamesWhatIsMissingAndStatusLooksUseSemanticTones() {
        let list = steps([.approved, .approved, .needsRevision, .failed, .waitingForApproval, .notStarted])
        XCTAssertEqual(ZhuowangWorkflowUIModel.lockedReason(for: list[5], in: list), "还差：先确认「\(list[4].title)」")
        XCTAssertNil(ZhuowangWorkflowUIModel.lockedReason(for: list[3], in: list), "只有未开始的步骤是锁定")
        XCTAssertEqual(ZhuowangWorkflowUIModel.presentation(for: .failed).tone, .danger)
        XCTAssertEqual(ZhuowangWorkflowUIModel.presentation(for: .needsRevision).tone, .warning)
        XCTAssertEqual(ZhuowangWorkflowUIModel.presentation(for: .approved).tone, .success)
        for status in ZhuowangWorkflowStepStatus.allCases { XCTAssertFalse(ZhuowangWorkflowUIModel.presentation(for: status).icon.isEmpty) }
    }

    func testAdoptedArtifactIsTheNewestAdoptedVersionOfTheStep() throws {
        let f = try makeFixture()
        let workflow = try XCTUnwrap(f.workflowStore.workflow(forCampaignID: f.sixStep.id))
        let ordered = ZhuowangWorkflowUIModel.enabledSteps(in: workflow)
        XCTAssertEqual(ZhuowangWorkflowUIModel.adoptedArtifact(for: ordered[1], in: workflow.artifacts)?.version, 3)
        XCTAssertEqual(workflow.artifacts.filter { $0.stepID == ordered[1].id }.count, 3, "历史版本保留")
        XCTAssertNil(ZhuowangWorkflowUIModel.adoptedArtifact(for: ordered[3], in: workflow.artifacts))
    }

    // MARK: Window lifecycle and isolation

    private func mount<V: View>(_ view: V, width: CGFloat = 980, height: CGFloat = 760) -> (NSWindow, NSView) {
        let host = NSHostingView(rootView: view.frame(width: width, height: height))
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        return (window, host)
    }

    func testDetailWindowStillRecoversAndMigratesInsideIsolatedRoot() throws {
        let root = try makeRoot()
        let (_, campaignStore, workflowStore) = makeEmptyStores(root: root)
        XCTAssertNil(workflowStore.workspaceFileManager.accessFailure)
        XCTAssertEqual(campaignStore.addCampaign(name: "恢复迁移夹具", scopeType: .national, moduleID: "national",
            startDate: start, endDate: start.addingTimeInterval(86_400)), .succeeded)
        let campaign = try XCTUnwrap(campaignStore.campaigns.first)

        // 1) a real local file that exists only on disk (recovery must import it);
        let recovered = try workflowStore.workspaceFileManager.writeMarkdownArtifact(
            provinceName: nil, campaignName: campaign.name, stepKind: .brief,
            artifactName: "需求整理", version: 1, content: "仅存在于磁盘的合成正文")
        // 2) a legacy artifact that has content but no file (migration must write it).
        var workflow = workflowStore.getOrCreateWorkflow(forCampaignID: campaign.id)
        let idea = try XCTUnwrap(workflow.steps.first { $0.kind == .idea })
        workflow.artifacts.append(ZhuowangArtifact(campaignID: campaign.id, stepID: idea.id, name: "策划思路",
            type: .markdown, content: "仅存在于元数据的合成正文", version: 1, isApprovedVersion: false))
        workflowStore.updateWorkflow(workflow)
        XCTAssertEqual(workflowStore.workflow(forCampaignID: campaign.id)?.artifacts.count, 1)

        let (window, _) = mount(ZhuowangCampaignDetailView(
            store: campaignStore, workflowStore: workflowStore, campaignID: campaign.id,
            province: nil, module: nil).environment(\.cosmosPreferences, try preferences()))
        defer { window.contentView = nil; window.close() }

        let artifacts = try XCTUnwrap(workflowStore.workflow(forCampaignID: campaign.id)).artifacts
        XCTAssertEqual(artifacts.count, 2, "onAppear 的本地恢复仍然发生")
        XCTAssertTrue(artifacts.contains { $0.location == recovered.path })
        let migrated = try XCTUnwrap(artifacts.first { $0.name == "策划思路" })
        XCTAssertTrue(migrated.location.hasPrefix(root.path + "/"), "onAppear 的迁移仍然发生，并写入隔离根")
        XCTAssertEqual(try String(contentsOfFile: migrated.location, encoding: .utf8), "仅存在于元数据的合成正文")
        let listing = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
        for case let url as URL in listing { XCTAssertTrue(url.path.hasPrefix(root.path)) }
    }

    func testDetailWindowRefusesFileAccessWhenIsolatedRootIsMissing() throws {
        let source = ZhuowangInMemoryPersistenceDataSource(storage: [:])
        let configuration = ZhuowangStorePersistenceConfiguration(
            dataSource: source, isIsolated: true, isolationSuiteName: source.domainIdentifier, workspaceFilesRootURL: nil)
        let campaignStore = ZhuowangCampaignStore(persistenceConfiguration: configuration)
        let workflowStore = ZhuowangWorkflowStore(persistenceConfiguration: configuration)
        XCTAssertNotNil(workflowStore.workspaceFileManager.accessFailure)
        XCTAssertEqual(campaignStore.addCampaign(name: "失败关闭夹具", scopeType: .national, moduleID: "national",
            startDate: start, endDate: start.addingTimeInterval(86_400)), .succeeded)
        let campaign = try XCTUnwrap(campaignStore.campaigns.first)
        let (window, _) = mount(ZhuowangCampaignDetailView(
            store: campaignStore, workflowStore: workflowStore, campaignID: campaign.id,
            province: nil, module: nil).environment(\.cosmosPreferences, try preferences()))
        defer { window.contentView = nil; window.close() }
        XCTAssertTrue(workflowStore.workflows.isEmpty, "缺少隔离根时不恢复、不创建 Workflow")
        XCTAssertFalse(FileManager.default.fileExists(atPath: "/private/tmp/CosmosWorkspaceFiles-Unavailable"))
    }

    // MARK: Offscreen matrix

    private func bytes(_ root: URL) throws -> [String: Data] {
        var result: [String: Data] = [:]
        guard let listing = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return result }
        for case let url as URL in listing where (try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            result[String(url.path.dropFirst(root.path.count))] = try Data(contentsOf: url)
        }
        return result
    }

    private func workflowDiff(_ a: [ZhuowangCampaignWorkflow], _ b: [ZhuowangCampaignWorkflow]) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let left = String(decoding: (try? encoder.encode(a)) ?? Data(), as: UTF8.self).split(separator: "\n")
        let right = String(decoding: (try? encoder.encode(b)) ?? Data(), as: UTF8.self).split(separator: "\n")
        var out: [String] = []
        for (index, line) in left.enumerated() where index < right.count && right[index] != line {
            out.append("L\(index): \(line.trimmingCharacters(in: .whitespaces)) -> \(right[index].trimmingCharacters(in: .whitespaces))")
            if out.count >= 8 { break }
        }
        return "行数 \(left.count)/\(right.count) " + out.joined(separator: " | ")
    }

    func testOffscreenWindowMatrix() throws {
        let f = try makeFixture()
        let prefs = try preferences()
        let out = URL(fileURLWithPath: "/private/tmp/CosmosStep3B-screenshots")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let workflowBefore = f.workflowStore.workflows
        let campaignsBefore = f.campaignStore.campaigns
        let filesBefore = try bytes(f.root)
        XCTAssertNil(f.manager.accessFailure)

        let sixWorkflow = try XCTUnwrap(f.workflowStore.workflow(forCampaignID: f.sixStep.id))
        let sixSteps = ZhuowangWorkflowUIModel.enabledSteps(in: sixWorkflow)
        let provider = deepSeek(f.workflowStore)
        func route(_ destination: ZhuowangCampaignDetailRoute.Destination?) -> ZhuowangCampaignDetailRoute {
            let route = ZhuowangCampaignDetailRoute(); if let destination { route.show(destination) }; return route
        }
        func detail(_ campaign: ZhuowangCampaign, _ destination: ZhuowangCampaignDetailRoute.Destination?) -> some View {
            ZhuowangCampaignDetailView(store: f.campaignStore, workflowStore: f.workflowStore, campaignID: campaign.id,
                province: f.province, module: nil, route: route(destination), workflowConnections: f.connections)
        }
        func step(_ index: Int) -> some View {
            ScrollView {
                ZhuowangWorkflowView(store: f.workflowStore, campaign: f.sixStep, province: f.province, module: nil,
                    focusRequest: ZhuowangWorkflowFocusRequest(stepID: sixSteps[index].id, serial: index + 1),
                    connections: f.connections)
                    .padding(28)
            }
        }

        let taskPackage = ZhuowangAITaskPackage(
            campaignID: f.sixStep.id, workflowStepID: sixSteps[2].id, workflowStepKind: .plan,
            title: "完整策划案 · 任务包（合成）",
            instruction: "请基于已确认的策划思路，输出一份完整的活动策划方案。\n\n要求：\n1. 活动目标与对象\n2. 玩法与奖品\n3. 风险与待确认事项\n\n（合成夹具，不含真实业务数据）",
            contextReferences: ["当前 Campaign Brief", "已确认策划思路 V3", "卓望.md（合成）"],
            expectedOutputs: ["策划案 Markdown", "待确认问题清单"],
            destinationHint: "卓望/浙江/十月福利活动/03_完整策划案")
        let draft = ZhuowangArtifactDraft(logicalKey: "synthetic.plan", name: "完整策划案", type: .markdown, content: "# 完整策划案（合成）\n\n这是一份用于界面验证的合成草稿。", preferredFileExtension: "md")
        let artifacts = sixWorkflow.artifacts.filter { $0.stepID == sixSteps[1].id }.sorted { $0.version > $1.version }
        let compareItems = artifacts.map {
            ArtifactVersionComparisonItem(artifactID: $0.id, version: $0.version, isCurrent: $0.isApprovedVersion,
                document: ArtifactReviewDocument(artifact: $0, providerName: provider?.name))
        }
        let deliverableCampaignURL = f.manager.campaignDirectoryURL(provinceName: f.province.pathName, campaignName: f.deliverable.name)

        struct Page { let name: String; let sizes: [CGSize]; let view: AnyView }
        let big = CGSize(width: 1180, height: 760), small = CGSize(width: 900, height: 620)
        let minimum = CGSize(width: 760, height: 620)
        let all = [big, small]
        let pages: [Page] = [
            Page(name: "01-概览", sizes: all + [minimum], view: AnyView(detail(f.sixStep, nil))),
            Page(name: "02-概览-月度活动", sizes: [big], view: AnyView(detail(f.monthly, nil))),
            Page(name: "03-Workflow-默认下一步", sizes: all + [minimum], view: AnyView(detail(f.sixStep, .workflow))),
            Page(name: "04-Workflow-选中失败步骤", sizes: all, view: AnyView(step(3))),
            Page(name: "05-Workflow-选中多版本步骤", sizes: [big], view: AnyView(step(1))),
            Page(name: "06-Workflow-选中原型步骤", sizes: [big], view: AnyView(step(4))),
            Page(name: "07-Workflow-选中锁定步骤", sizes: all, view: AnyView(step(5))),
            Page(name: "08-工作产物", sizes: all + [minimum], view: AnyView(detail(f.sixStep, .artifacts))),
            Page(name: "09-工作产物-可交付活动", sizes: [big], view: AnyView(detail(f.deliverable, .artifacts))),
            Page(name: "10-月度清单", sizes: all, view: AnyView(ScrollView {
                ZhuowangMonthlyChecklistView(store: f.campaignStore, workflowStore: f.workflowStore, campaignID: f.monthly.id).padding(28)
            })),
            Page(name: "11-任务包预览", sizes: [CGSize(width: 820, height: 760)], view: AnyView(
                ZhuowangTaskPackagePreviewView(taskPackage: taskPackage, provider: provider, connection: nil, tool: f.tool, route: nil,
                    onAdoptResult: { _, _ in .failure("夹具不执行采用") }))),
            Page(name: "12-执行结果-已完成", sizes: [CGSize(width: 880, height: 760)], view: AnyView(
                ZhuowangAIExecutionResultView(taskPackage: taskPackage, provider: provider, connection: nil, artifactDraft: draft,
                    resultText: draft.content, errorText: "", state: .succeeded,
                    onAdopt: { .failure("夹具不执行采用") }, onRequestRevision: { _ in }, onRegenerate: { }))),
            Page(name: "13-执行结果-失败", sizes: [CGSize(width: 880, height: 700)], view: AnyView(
                ZhuowangAIExecutionResultView(taskPackage: taskPackage, provider: provider, connection: nil, artifactDraft: nil,
                    resultText: "", errorText: "合成错误：执行器未接入（夹具）。", state: .failed,
                    onAdopt: { .failure("夹具不执行采用") }, onRequestRevision: { _ in }, onRegenerate: { }))),
            Page(name: "14-执行结果-执行中", sizes: [CGSize(width: 880, height: 700)], view: AnyView(
                ZhuowangAIExecutionResultView(taskPackage: taskPackage, provider: provider, connection: nil, artifactDraft: nil,
                    resultText: "", errorText: "", state: .running,
                    onAdopt: { .failure("夹具不执行采用") }, onRequestRevision: { _ in }, onRegenerate: { }))),
            Page(name: "15-交付包", sizes: [CGSize(width: 840, height: 660)], view: AnyView(
                ZhuowangArtifactDeliveryPackageView(campaign: f.deliverable, provinceName: f.province.name,
                    campaignWorkspaceURL: deliverableCampaignURL,
                    snapshotProvider: { [store = f.workflowStore, id = f.deliverable.id] in
                        ZhuowangArtifactDeliverySnapshot(campaignID: id, artifacts: store.artifacts(forCampaignID: id),
                            steps: store.workflow(forCampaignID: id)?.steps ?? [])
                    }))),
            Page(name: "16-Review", sizes: [CGSize(width: 1100, height: 760)], view: AnyView(
                ArtifactReviewWorkspace(document: ArtifactReviewDocument(artifact: artifacts[0], providerName: provider?.name),
                    windowContext: ArtifactReviewWindowContext()))),
            Page(name: "17-Compare", sizes: [CGSize(width: 1280, height: 760)], view: AnyView(
                ArtifactVersionCompareWorkspace(artifactName: "策划思路", items: compareItems,
                    windowContext: ArtifactReviewWindowContext(),
                    initialState: try XCTUnwrap(ArtifactVersionCompareState(items: compareItems, selectedArtifactID: compareItems[0].artifactID))))),
            Page(name: "18-资料引用", sizes: [big], view: AnyView(ScrollView {
                CampaignReferencesView(store: f.campaignStore, campaignID: f.sixStep.id).padding(28)
            }))
        ]

        var written = 0
        for page in pages {
            for size in page.sizes {
                for (appearance, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                    let content = page.view
                        .environment(\.cosmosPreferences, prefs)
                        .environment(\.colorScheme, scheme)
                        .frame(width: size.width, height: size.height)
                        .background(Color(nsColor: .windowBackgroundColor))
                    let host = NSHostingView(rootView: content)
                    host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                    host.frame = NSRect(origin: .zero, size: size)
                    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false; window.appearance = host.appearance; window.contentView = host
                    defer { window.contentView = nil; window.close() }
                    host.layoutSubtreeIfNeeded(); RunLoop.current.run(until: Date().addingTimeInterval(0.25)); host.layoutSubtreeIfNeeded()
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    XCTAssertGreaterThan(data.count, 1500, page.name)
                    try data.write(to: out.appendingPathComponent("\(page.name)-\(appearance)-\(Int(size.width))x\(Int(size.height)).png"))
                    written += 1
                }
            }
        }
        XCTAssertGreaterThan(written, 40)
        XCTAssertEqual(f.workflowStore.workflows, workflowBefore, "离屏渲染不得改变 Workflow 数据：" + workflowDiff(workflowBefore, f.workflowStore.workflows))
        XCTAssertEqual(f.campaignStore.campaigns, campaignsBefore, "离屏渲染不得改变活动数据")
        XCTAssertEqual(try bytes(f.root), filesBefore, "离屏渲染不得改变隔离根内的任何文件")
        print("Step3B screenshots: " + out.path + " (\(written))")
    }
}
