import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

final class AIWorkspaceTaskPreparationTests: XCTestCase {
    private func fixture() -> AIWorkspaceTaskContext {
        let province = ZhuowangProvince(id: UUID(), name: "自定义省份", englishName: "", isEnabled: true)
        let first = ZhuowangCampaign(name: "活动甲", scopeType: .province, provinceID: province.id,
            startDate: Date(timeIntervalSince1970: 0), endDate: Date(timeIntervalSince1970: 86400), notes: "主题甲")
        let second = ZhuowangCampaign(name: "活动乙", scopeType: .national, startDate: first.startDate, endDate: first.endDate)
        let steps = [ZhuowangWorkflowStep(title: "策划", sortOrder: 20, status: .ready, notes: "说明甲"),
                     ZhuowangWorkflowStep(title: "自定义步骤", sortOrder: 30, requiresApproval: false)]
        let current = ZhuowangArtifact(campaignID: first.id, stepID: steps[0].id, name: "方案", type: .markdown,
            logicalKey: "plan", location: "/private/tmp/甲/方案_V1.md", content: "绝不能加入提示词的正文", version: 1, isApprovedVersion: true)
        let other = ZhuowangArtifact(campaignID: first.id, stepID: steps[0].id, name: "方案", type: .markdown,
            logicalKey: "plan", version: 3)
        return AIWorkspaceTaskContext(campaigns: [first, second], workflows: [
            ZhuowangCampaignWorkflow(campaignID: first.id, steps: steps, artifacts: [current, other]),
            ZhuowangCampaignWorkflow(campaignID: second.id, steps: [ZhuowangWorkflowStep(title: "需求", sortOrder: 10)])],
            workspace: ZhuowangWorkspaceSnapshot(modules: [], provinces: [province], categories: []))
    }

    private func ready(_ context: AIWorkspaceTaskContext, copy: @escaping (String) -> Bool = { _ in true }) -> AIWorkspaceTaskPreparation {
        let model = AIWorkspaceTaskPreparation(read: { context }, copy: copy)
        model.refresh()
        model.selectCampaign(context.campaigns[0].id)
        model.selectStep(context.workflows[0].steps[0].id)
        model.goal = "完成本次方案"
        return model
    }

    func testRealAssociationAndMetadataOnlyAdoptedOlderVersion() throws {
        let model = ready(fixture())
        let text = try XCTUnwrap(model.preview)
        XCTAssertTrue(text.contains("自定义省份"))
        XCTAssertTrue(text.contains("主题甲"))
        XCTAssertTrue(text.contains("说明甲"))
        XCTAssertTrue(text.contains("V1 · Markdown · 当前采用版本"))
        XCTAssertTrue(text.contains("V3 · Markdown · 其他版本，仅供参考"))
        XCTAssertTrue(text.contains("/private/tmp/甲/方案_V1.md"))
        XCTAssertFalse(text.contains("绝不能加入提示词的正文"))
        XCTAssertFalse(text.contains("活动乙"))
        XCTAssertTrue(text.contains("具体格式及详细完成标准未在步骤模型中独立记录"))
    }

    func testSwitchClearsInputsAndNeverCarriesPreviousContext() throws {
        let model = ready(fixture())
        model.requirements = "上次要求"
        model.selectStep(model.steps[1].id)
        XCTAssertEqual(model.goal, "")
        XCTAssertEqual(model.requirements, "")
        XCTAssertNil(model.preview)
        model.goal = "新目标"
        XCTAssertFalse(try XCTUnwrap(model.preview).contains("说明甲"))
        // Use the identities from this model, not another fixture.
        model.selectCampaign(model.context.campaigns[1].id)
        XCTAssertNil(model.stepID)
        XCTAssertEqual(model.goal, "")
        XCTAssertEqual(model.requirements, "")
        model.selectStep(model.steps[0].id)
        model.goal = "乙的目标"
        let text = try XCTUnwrap(model.preview)
        XCTAssertTrue(text.contains("活动乙"))
        XCTAssertFalse(text.contains("主题甲"))
        XCTAssertFalse(text.contains("方案_V1"))
    }

    func testEmptyStatesGoalAndNoInventedWorkflow() {
        var context = AIWorkspaceTaskContext()
        let model = AIWorkspaceTaskPreparation(read: { context })
        model.refresh()
        XCTAssertTrue(model.validation!.contains("没有已有活动"))
        context = fixture(); context.workflows = []
        model.refresh(); model.selectCampaign(context.campaigns[0].id)
        XCTAssertTrue(model.validation!.contains("尚无 Workflow"))
        context.workflows = [ZhuowangCampaignWorkflow(campaignID: context.campaigns[0].id)]
        model.refresh()
        XCTAssertTrue(model.validation!.contains("没有步骤"))
        context.workflows[0].steps = [ZhuowangWorkflowStep(title: "步骤", sortOrder: 0)]
        model.refresh(); model.selectStep(model.steps[0].id)
        model.goal = "  \n"
        XCTAssertNil(model.preview)
        XCTAssertEqual(model.validation, "请填写本次目标。")
    }

    func testConflictUnadoptedAndCrossCampaignArtifacts() throws {
        var context = fixture()
        context.workflows[0].artifacts[1].isApprovedVersion = true
        var text = try XCTUnwrap(ready(context).preview)
        XCTAssertTrue(text.contains("采用冲突，无法确定当前采用版本"))
        XCTAssertFalse(text.contains("· 当前采用版本"))
        context.workflows[0].artifacts[0].isApprovedVersion = false
        context.workflows[0].artifacts[1].isApprovedVersion = false
        context.workflows[0].artifacts.append(ZhuowangArtifact(campaignID: context.campaigns[1].id,
            name: "错误活动产物", type: .markdown, isApprovedVersion: true))
        text = try XCTUnwrap(ready(context).preview)
        XCTAssertTrue(text.contains("参考产物，当前采用版本未确定"))
        XCTAssertFalse(text.contains("错误活动产物"))
    }

    func testPreviewAndCopyAlwaysMatchLatestInputAndTool() throws {
        let context = fixture()
        var copied: String?
        let model = ready(context, copy: { copied = $0; return true })
        model.copyPreview()
        XCTAssertEqual(copied, model.preview)
        XCTAssertEqual(model.copyFeedback, "已复制当前任务提示词")
        model.goal = "修改后目标"; model.requirements = "新增要求"; model.tool = .codex
        XCTAssertNil(model.copyFeedback)
        model.copyPreview()
        XCTAssertEqual(copied, model.preview)
        XCTAssertTrue(copied!.contains("任务交接 · Codex"))
        XCTAssertTrue(copied!.contains("新增要求"))
        XCTAssertFalse(copied!.contains("完成本次方案"))
    }

    func testCopyFailureAndInvalidSelectionNeverCallsClipboard() {
        var calls = 0
        let model = ready(fixture(), copy: { _ in calls += 1; return false })
        model.copyPreview()
        XCTAssertEqual(model.copyFeedback, "复制失败，请重试。")
        model.selectStep(UUID())
        model.copyPreview()
        XCTAssertEqual(calls, 1)
        XCTAssertNil(model.preview)
    }

    func testCopyRevalidatesChangedAndDeletedData() {
        var context = fixture(), copied = [String]()
        let model = AIWorkspaceTaskPreparation(read: { context }, copy: { copied.append($0); return true })
        model.refresh(); model.selectCampaign(context.campaigns[0].id)
        model.selectStep(model.steps[0].id); model.goal = "目标"
        context.workflows[0].steps[0].notes = "更新后的说明"
        model.copyPreview()
        XCTAssertTrue(copied.isEmpty)
        XCTAssertEqual(model.copyFeedback, "上下文已更新，请核对当前预览后再次复制。")
        model.copyPreview(); XCTAssertEqual(copied.count, 1)
        context.workflows[0].steps = []
        model.copyPreview(); XCTAssertEqual(copied.count, 1)
        XCTAssertNil(model.stepID); XCTAssertEqual(model.goal, "")
        context.campaigns = []
        model.refresh(); XCTAssertNil(model.campaignID)
    }

    func testReaderNeverWritesOrRecoversAndFailureClearsPreview() throws {
        let source = TaskMemorySource(), context = fixture()
        source.bytes[ZhuowangCampaignStore.storageKey] = try JSONEncoder().encode(context.campaigns)
        source.bytes[ZhuowangWorkflowStore.workflowStorageKey] = try JSONEncoder().encode(context.workflows)
        source.bytes[ZhuowangWorkspaceStore.storageKey] = try JSONEncoder().encode(context.workspace)
        let reader = AIWorkspaceTaskContextReader(source: source)
        let before = source.bytes
        let model = AIWorkspaceTaskPreparation(read: { try reader.read() }, copy: { _ in true })
        model.refresh(); model.selectCampaign(context.campaigns[0].id); model.selectStep(model.steps[0].id)
        model.goal = "目标"; model.copyPreview()
        XCTAssertEqual(source.bytes, before); XCTAssertEqual(source.writes, 0)
        source.bytes[ZhuowangWorkflowStore.workflowBackupStorageKey] = source.bytes[ZhuowangWorkflowStore.workflowStorageKey]
        source.bytes[ZhuowangWorkflowStore.workflowStorageKey] = Data("corrupt".utf8)
        model.refresh()
        XCTAssertNil(model.preview); XCTAssertNotNil(model.error)
        XCTAssertFalse(source.reads.contains(ZhuowangWorkflowStore.workflowBackupStorageKey))
        XCTAssertEqual(source.writes, 0)
        let empty = TaskMemorySource()
        XCTAssertTrue(try AIWorkspaceTaskContextReader(source: empty).read().campaigns.isEmpty)
        XCTAssertEqual(empty.writes, 0)
    }

    func testDuplicateIdentityFailsClosed() throws {
        let source = TaskMemorySource(), context = fixture()
        source.bytes[ZhuowangCampaignStore.storageKey] = try JSONEncoder().encode([context.campaigns[0], context.campaigns[0]])
        XCTAssertThrowsError(try AIWorkspaceTaskContextReader(source: source).read())
        XCTAssertEqual(source.writes, 0)
    }

    func testOffscreenRealPreparationViewAndPrivateClipboard() throws {
        let board = NSPasteboard(name: .init("CosmosTaskTests-\(UUID())"))
        defer { board.releaseGlobally() }
        let model = ready(fixture(), copy: { text in board.clearContents(); return board.setString(text, forType: .string) })
        model.copyPreview()
        XCTAssertEqual(board.string(forType: .string), model.preview)
        let view = NSHostingView(rootView: AIWorkspaceTaskPreparationView(model: model))
        view.frame = NSRect(x: 0, y: 0, width: 900, height: 1500)
        view.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(view.fittingSize.height, 0)
    }
}

nonisolated private final class TaskMemorySource: ZhuowangPersistenceDataSource {
    let domainIdentifier = "AIWorkspaceTaskTests"
    var bytes: [String: Data] = [:]
    var reads: [String] = []
    var writes = 0
    func data(forKey key: String) -> Data? { reads.append(key); return bytes[key] }
    func set(_ data: Data, forKey key: String) { writes += 1; bytes[key] = data }
}
