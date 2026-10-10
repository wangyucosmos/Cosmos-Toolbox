import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class CosmosStep2ATests: XCTestCase {
    private var roots: [URL] = []
    private var suites: [String] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        for suite in suites { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        super.tearDown()
    }
    private func root() throws -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosStep2A-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); roots.append(root); return root
    }
    private func bytes(_ root: URL) throws -> [String: Data] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [:] }
        var result: [String: Data] = [:]
        for case let url as URL in FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])! {
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true { result[String(url.path.dropFirst(root.path.count))] = try Data(contentsOf: url) }
        }
        return result
    }
    private func preferences() throws -> CosmosUIPreferences {
        let suite = "CosmosStep2A.UI." + UUID().uuidString; suites.append(suite)
        return CosmosUIPreferences(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
    }
    func testMotionTokensReduceAllStaggerAndPageAnimation() throws {
        let prefs = try preferences()
        XCTAssertNotNil(CosmosDesign.pageAnimation(reduced: false)); XCTAssertNil(CosmosDesign.pageAnimation(reduced: true))
        XCTAssertEqual(CosmosDesign.entranceDelay(index: 7, reduced: false), 0.224, accuracy: 0.001)
        XCTAssertEqual(CosmosDesign.entranceDelay(index: 8, reduced: false), 0)
        for index in 0..<20 { XCTAssertEqual(CosmosDesign.entranceDelay(index: index, reduced: true), 0) }
        XCTAssertTrue(prefs.reducesMotion(system: true)); prefs.motion = .reduced; XCTAssertTrue(prefs.reducesMotion(system: false))
    }
    func testCancelledPageLoadDoesNotStartReader() async {
        let task = Task { await CosmosDesign.beginPageLoad(reduced: false) }; task.cancel()
        let allowed = await task.value; XCTAssertFalse(allowed)
    }
    func testProjectStarterPrefillsUnsavedSessionWithZeroWrites() async throws {
        let root = try root(), store = ProjectsStore(storage: ProjectsFileStorage(root: root)); await store.reload()
        let savedOK = await store.save(PersonalProject(name: "已有项目", goal: "保留原文"), expected: nil); XCTAssertTrue(savedOK)
        let before = try bytes(root), existing = store.projects[0]
        for starter in CosmosProjectStarter.allCases {
            let session = ProjectsEditSession(store: store, project: nil, prefill: starter.draft)
            XCTAssertNil(session.baseline); XCTAssertTrue(session.isDirty); XCTAssertEqual(session.draft.name, starter.title)
            XCTAssertFalse(session.draft.goal.isEmpty); XCTAssertFalse(session.draft.nextStep.isEmpty)
            XCTAssertEqual(store.projects, [existing]); XCTAssertEqual(try bytes(root), before)
            let protected = ProjectsEditSession(store: store, project: existing, prefill: starter.draft)
            XCTAssertEqual(protected.draft, existing)
        }
    }
    func testPromptStarterPrefillsUnsavedSessionWithZeroWrites() async throws {
        let root = try root(), store = PromptVaultStore(storage: PromptVaultFileStorage(root: root)); await store.reload()
        let savedOK = await store.save(PromptTemplate(name: "已有模板", body: "原文 {{资料}}"), expectedRevision: nil); XCTAssertTrue(savedOK)
        let before = try bytes(root), existing = store.templates[0]
        for starter in CosmosPromptStarter.allCases {
            let session = PromptTemplateEditSession(store: store, template: nil, prefill: starter.draft)
            XCTAssertNil(session.baseline); XCTAssertTrue(session.isDirty); XCTAssertEqual(session.draft.name, starter.title)
            XCTAssertFalse(PromptTemplateRenderer(session.draft.body).variables.isEmpty)
            XCTAssertEqual(store.templates, [existing]); XCTAssertEqual(try bytes(root), before)
            XCTAssertEqual(PromptTemplateEditSession(store: store, template: existing, prefill: starter.draft).draft, existing)
        }
    }
    func testMissingLibrariesAreNotCreatedByTemplatePrefill() async throws {
        let parent = try root(), projectsRoot = parent.appendingPathComponent("projects"), promptsRoot = parent.appendingPathComponent("prompts")
        let projects = ProjectsStore(location: .init(root: projectsRoot, error: nil)); await projects.reload()
        let prompts = PromptVaultStore(root: promptsRoot); await prompts.reload()
        _ = ProjectsEditSession(store: projects, project: nil, prefill: CosmosProjectStarter.cosmos.draft)
        _ = PromptTemplateEditSession(store: prompts, template: nil, prefill: CosmosPromptStarter.campaign.draft)
        XCTAssertFalse(FileManager.default.fileExists(atPath: projectsRoot.path)); XCTAssertFalse(FileManager.default.fileExists(atPath: promptsRoot.path))
    }
    func testExplicitSavePersistsPrefilledDraftThroughExistingFlow() async throws {
        let root = try root(), projects = ProjectsStore(location: .init(root: root.appendingPathComponent("projects"), error: nil)); await projects.reload()
        let session = ProjectsEditSession(store: projects, project: nil, prefill: CosmosProjectStarter.learningTool.draft)
        let saved = await session.save(); XCTAssertTrue(saved); XCTAssertFalse(session.isDirty); XCTAssertEqual(projects.projects.count, 1)
        let prompts = PromptVaultStore(root: root.appendingPathComponent("prompts")); await prompts.reload()
        let prompt = PromptTemplateEditSession(store: prompts, template: nil, prefill: CosmosPromptStarter.development.draft)
        let savedPrompt = await prompt.save(); XCTAssertTrue(savedPrompt); XCTAssertFalse(prompt.isDirty); XCTAssertEqual(prompts.templates.count, 1)
    }
    func testAIGuideRequiresSelectionGoalAndExistingPreviewValidation() {
        let empty = CosmosAITaskGuide(selectionComplete: false, goalEntered: false, previewReady: false)
        XCTAssertEqual(empty.status(1), .current); XCTAssertEqual(empty.status(2), .waiting); XCTAssertFalse(empty.permits(3))
        let selected = CosmosAITaskGuide(selectionComplete: true, goalEntered: false, previewReady: false)
        XCTAssertEqual(selected.status(1), .complete); XCTAssertEqual(selected.status(2), .current); XCTAssertTrue(selected.permits(2)); XCTAssertFalse(selected.permits(3))
        let invalidReferences = CosmosAITaskGuide(selectionComplete: true, goalEntered: true, previewReady: false)
        XCTAssertFalse(invalidReferences.permits(3)); XCTAssertEqual(invalidReferences.status(2), .current)
        let ready = CosmosAITaskGuide(selectionComplete: true, goalEntered: true, previewReady: true)
        XCTAssertEqual(ready.status(2), .complete); XCTAssertTrue(ready.permits(3)); XCTAssertFalse(ready.permits(4))
    }
    func testAIGuideFollowsRealPreparationAndSelectionReset() throws {
        let c = ZhuowangCampaign(name: "隔离活动", scopeType: .national, startDate: Date(), endDate: Date().addingTimeInterval(86400)), w = ZhuowangCampaignWorkflow.standard(campaignID: c.id)
        let model = AIWorkspaceTaskPreparation(read: { .init(campaigns: [c], workflows: [w]) }, referenceIsolationError: "未提供隔离根", copy: { _ in true })
        model.refresh(); XCTAssertNil(model.preview)
        model.selectCampaign(c.id); model.selectStep(w.steps[0].id); model.goal = "输出本次方案"
        let guide = CosmosAITaskGuide(selectionComplete: model.step != nil, goalEntered: !model.goal.isEmpty, previewReady: model.preview != nil)
        XCTAssertTrue(guide.permits(3)); model.selectCampaign(nil); XCTAssertTrue(model.goal.isEmpty); XCTAssertNil(model.preview)
    }
    func testOffscreenPageMatrix() async throws {
        let root = try root(), prefs = try preferences(); prefs.motion = .reduced
        let out = URL(fileURLWithPath: "/private/tmp/CosmosStep2A-screenshots")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let projectEmpty = ProjectsStore(location: .init(root: root.appendingPathComponent("project-empty"), error: nil)); await projectEmpty.reload()
        let projects = ProjectsStore(location: .init(root: root.appendingPathComponent("projects"), error: nil)); await projects.reload()
        let projectSaved = await projects.save(PersonalProject(name: "隔离 UI 项目", goal: "让日常工具更清楚、更好用。", status: .active, nextStep: "检查页面布局与下一步提示。", progress: [.init(body: "已完成第一轮页面改版。")]), expected: nil); XCTAssertTrue(projectSaved)
        let promptEmpty = PromptVaultStore(root: root.appendingPathComponent("prompt-empty")); await promptEmpty.reload()
        let prompts = PromptVaultStore(root: root.appendingPathComponent("prompts")); await prompts.reload()
        let promptSaved = await prompts.save(CosmosPromptStarter.campaign.draft, expectedRevision: nil); XCTAssertTrue(promptSaved)
        let notes = PersonalNotesStore(location: .init(root: root.appendingPathComponent("notes"), error: nil)); await notes.reload()
        let noteSaved = await notes.save(PersonalNote(title: "我的操作经验", body: "先记录问题，再记录已经验证的解决办法。", category: "经验"), expected: nil); XCTAssertTrue(noteSaved)
        let learning = LearningStore(root: root.appendingPathComponent("learning")); await learning.reload()
        let topic = LearningTopic(name: "SwiftUI", goal: "理解原生页面的状态与转场。", nextStep: "做一个小页面并记录观察。")
        let topicSaved = await learning.saveTopic(topic, expectedRevision: nil); XCTAssertTrue(topicSaved)
        let history = AIWorkspaceHandoffStore(location: .init(root: root.appendingPathComponent("handoffs"), error: nil)); await history.reload()
        let c = ZhuowangCampaign(name: "十月福利活动", scopeType: .national, startDate: Date(), endDate: Date().addingTimeInterval(86400)), w = ZhuowangCampaignWorkflow.standard(campaignID: c.id)
        let context = AIWorkspaceTaskContext(campaigns: [c], workflows: [w])
        func preparation(_ stage: Int) -> AIWorkspaceTaskPreparation {
            let model = AIWorkspaceTaskPreparation(read: { context }, referenceReader: ZhuowangAssetTextReader(allowedRoot: root), copy: { _ in true }); model.refresh()
            if stage >= 2 { model.selectCampaign(c.id); model.selectStep(w.steps[0].id) }
            if stage == 3 { model.goal = "整理本次活动策划思路，列出待确认问题。" }
            return model
        }
        let macSnapshot = MacEnvironmentSnapshot(readAt: Date(), systemVersion: .value("macOS 26.5（合成数据）"), hardwareModel: .value("MacBook Pro"), processor: .value("Apple Silicon"), architecture: .value("arm64"), physicalMemory: .value(32 * 1024 * 1024 * 1024), memoryPressure: .unknown("未读取"), disk: .value(.init(totalBytes: 1_000_000_000_000, availableBytes: 380_000_000_000)), battery: .value(.init(percentage: .value(78), power: .value("电池供电"), charging: .value(false))))
        let mac = MacEnvironmentViewModel(read: { macSnapshot }); mac.refresh(); try await Task.sleep(for: .milliseconds(40))
        let before = try bytes(root)
        for width in [1180, 900] {
            let height = width == 1180 ? 760 : 620
            for (appearance, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                func save<V: View>(_ view: V, _ name: String) throws {
                    let content = view.environment(\.cosmosPreferences, prefs).environment(\.cosmosNavigator, CosmosNavigator()).environment(\.colorScheme, scheme)
                        .frame(width: CGFloat(width), height: CGFloat(height)).background(Color(nsColor: .windowBackgroundColor))
                    let host = NSHostingView(rootView: content); host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                    host.frame = NSRect(x: 0, y: 0, width: width, height: height)
                    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false; window.appearance = host.appearance; window.contentView = host
                    defer { window.contentView = nil; window.close() }
                    host.layoutSubtreeIfNeeded(); RunLoop.current.run(until: Date().addingTimeInterval(0.15)); host.layoutSubtreeIfNeeded()
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds)); host.cacheDisplay(in: host.bounds, to: bitmap)
                    let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:])); XCTAssertGreaterThan(data.count, 1500)
                    try data.write(to: out.appendingPathComponent("\(name)-\(appearance)-\(width)x\(height).png"))
                }
                try save(ProjectsView(store: projectEmpty), "projects-empty"); try save(ProjectsView(store: projects), "projects-data")
                for stage in 1...3 {
                    let model = AIWorkspaceViewModel(detect: { nil })
                    try save(AIWorkspaceView(model: model, preparation: preparation(stage), history: history, initialStage: stage), "ai-stage-\(stage)")
                }
                try save(PromptVaultView(store: promptEmpty, model: PromptVaultViewModel(copy: { _ in true })), "prompts-empty")
                let promptModel = PromptVaultViewModel(copy: { _ in true }); promptModel.selectedID = prompts.templates.first?.id
                try save(PromptVaultView(store: prompts, model: promptModel), "prompts-data")
                let learningModel = LearningViewModel(); learningModel.selectedID = learning.topics.first?.id
                try save(LearningCenterView(store: learning, model: learningModel), "learning")
                try save(MacEnvironmentView(model: mac), "mac")
                try save(PersonalNotesView(store: notes), "notes")
            }
        }
        XCTAssertEqual(try bytes(root), before, "Rendering pages must not mutate any fixture library")
        print("Step2A screenshots: " + out.path)
    }
}
