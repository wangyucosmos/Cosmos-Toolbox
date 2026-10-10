import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class AIWorkspaceTaskReferencesTests: XCTestCase {
    private var roots: [URL] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots = []; super.tearDown()
    }
    private func root() throws -> URL {
        let value = URL(fileURLWithPath: "/private/tmp/CosmosTaskReferences-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: value, withIntermediateDirectories: true)
        roots.append(value); return value
    }
    private func fixture(root: URL, content: String? = nil, raw: String = "  原文 e\u{301} 😀\r\n\t尾部  \n") throws -> AIWorkspaceTaskContext {
        let campaign = ZhuowangCampaign(name: "资料活动", scopeType: .national, startDate: Date(), endDate: Date())
        let second = ZhuowangCampaign(name: "其他活动", scopeType: .other, startDate: Date(), endDate: Date())
        let steps = [ZhuowangWorkflowStep(title: "当前步骤", sortOrder: 10), ZhuowangWorkflowStep(title: "另一步骤", sortOrder: 20)]
        let file = root.appendingPathComponent("V1.md")
        try Data(raw.utf8).write(to: file)
        let current = ZhuowangArtifact(campaignID: campaign.id, stepID: steps[0].id, name: "同一方案", type: .markdown,
            logicalKey: "plan", location: file.path, content: content, version: 1, isApprovedVersion: true)
        let historical = ZhuowangArtifact(campaignID: campaign.id, stepID: steps[1].id, name: "同一方案", type: .markdown,
            logicalKey: "plan", content: "历史 V3 原文", version: 3)
        return AIWorkspaceTaskContext(campaigns: [campaign, second], workflows: [
            .init(campaignID: campaign.id, steps: steps, artifacts: [current, historical]),
            .init(campaignID: second.id, steps: [ZhuowangWorkflowStep(title: "其他步骤", sortOrder: 10)], artifacts: [
                .init(campaignID: second.id, name: "外部活动资料", type: .markdown, content: "不应混入", isApprovedVersion: true)])])
    }
    private func ready(read: @escaping () throws -> AIWorkspaceTaskContext, root: URL,
                       copy: @escaping (String) -> Bool = { _ in true }) -> AIWorkspaceTaskPreparation {
        let model = AIWorkspaceTaskPreparation(read: read, referenceReader: ZhuowangAssetTextReader(allowedRoot: root), copy: copy)
        model.refresh(); model.selectCampaign(model.context.campaigns[0].id); model.selectStep(model.steps[0].id)
        model.goal = "本次目标"; return model
    }
    private func copy(_ model: AIWorkspaceTaskPreparation) async {
        if let task = model.copyPreview() { await task.value }
    }

    func testDefaultNoReadsCurrentAdoptedFirstAndOnlyCurrentCampaign() async throws {
        let root = try root(), context = try fixture(root: root), reader = ZhuowangAssetTextReader(allowedRoot: root)
        let model = AIWorkspaceTaskPreparation(read: { context }, referenceReader: reader)
        model.refresh(); model.selectCampaign(context.campaigns[0].id); model.selectStep(model.steps[0].id); model.goal = "目标"
        XCTAssertTrue(model.referenceSelection.selections.isEmpty)
        let stats = await reader.statistics()
        XCTAssertEqual(stats.diskReads, 0)
        XCTAssertEqual(model.referenceSelection.entries.map(\.artifact.version), [1, 3])
        XCTAssertFalse(model.referenceSelection.entries.contains { $0.artifact.name == "外部活动资料" })
        XCTAssertFalse(model.preview!.contains("原文 e"))
    }

    func testSelectedFileOriginalBytesAndFinalPreviewCopySnapshotMatch() async throws {
        let root = try root(), context = try fixture(root: root)
        let source = ReferenceBusinessSource()
        source.bytes[ZhuowangCampaignStore.storageKey] = try JSONEncoder().encode(context.campaigns)
        source.bytes[ZhuowangWorkflowStore.workflowStorageKey] = try JSONEncoder().encode(context.workflows)
        let before = source.bytes, file = URL(fileURLWithPath: context.workflows[0].artifacts[0].location)
        let fileBefore = try Data(contentsOf: file)
        let reader = AIWorkspaceTaskContextReader(source: source)
        var copied: String?
        let model = ready(read: { try reader.read() }, root: root, copy: { copied = $0; return true })
        await model.referenceSelection.select(context.workflows[0].artifacts[0].id)
        let body = try XCTUnwrap(model.referenceSelection.selections.first?.body?.text)
        XCTAssertEqual(Data(body.utf8), fileBefore)
        let displayed = try XCTUnwrap(model.preview)
        XCTAssertTrue(displayed.contains(body))
        XCTAssertTrue(displayed.contains("正文来源：本地文件正文"))
        await copy(model)
        XCTAssertEqual(Data(copied!.utf8), Data(displayed.utf8))
        let history = AIWorkspaceHandoffStore(location: .init(root: root.appendingPathComponent("history"), error: nil))
        await history.reload(); await history.recordCurrent(model)
        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(Data(history.records[0].prompt.utf8), Data(displayed.utf8))
        let loaded = try await AIWorkspaceHandoffFileStorage(root: root.appendingPathComponent("history")).load()
        XCTAssertEqual(Data(loaded[0].prompt.utf8), Data(displayed.utf8))
        model.referenceSelection.remove(context.workflows[0].artifacts[0].id)
        XCTAssertFalse(model.preview!.contains(body))
        XCTAssertEqual(source.bytes, before); XCTAssertEqual(source.writes, 0)
        XCTAssertEqual(try Data(contentsOf: file), fileBefore)
        var historicalCopy: String?
        AIWorkspaceHandoffCopyModel(copy: { historicalCopy = $0; return true }).copySnapshot(loaded[0])
        XCTAssertEqual(Data(historicalCopy!.utf8), Data(displayed.utf8))
    }

    func testExplicitHistoricalVersionUnadoptedAndConflictLabels() async throws {
        let root = try root(); var context = try fixture(root: root)
        let model = ready(read: { context }, root: root)
        let historical = context.workflows[0].artifacts[1]
        await model.referenceSelection.select(historical.id)
        XCTAssertTrue(model.preview!.contains("历史参考（非当前采用）"))
        XCTAssertTrue(model.preview!.contains("历史 V3 原文"))
        XCTAssertTrue(model.preview!.contains(historical.id.uuidString))
        context.workflows[0].artifacts[0].isApprovedVersion = false
        do { try await model.revalidateReferencesForDelivery(); XCTFail("must confirm") } catch {}
        XCTAssertTrue(model.preview!.contains("未采用参考，当前采用版本未确定"))
        context.workflows[0].artifacts[0].isApprovedVersion = true
        context.workflows[0].artifacts[1].isApprovedVersion = true
        do { try await model.revalidateReferencesForDelivery(); XCTFail("must confirm") } catch {}
        XCTAssertTrue(model.preview!.contains("采用冲突，当前采用版本无法确定"))
        XCTAssertFalse(model.preview!.contains("采用状态：当前采用版本"))
    }

    func testActivitySwitchClearsAndStepSwitchExplicitlyRetainsSameActivity() async throws {
        let root = try root(), context = try fixture(root: root), model = ready(read: { context }, root: root)
        await model.referenceSelection.select(context.workflows[0].artifacts[0].id)
        model.selectStep(model.steps[1].id)
        XCTAssertEqual(model.referenceSelection.selections.count, 1)
        XCTAssertTrue(model.referenceSelection.feedback!.contains("保留当前活动明确选中的"))
        model.goal = "另一步骤目标"
        XCTAssertTrue(model.preview!.contains("本地文件正文"))
        model.selectCampaign(context.campaigns[1].id)
        XCTAssertTrue(model.referenceSelection.selections.isEmpty)
        XCTAssertEqual(model.referenceSelection.entries.map(\.artifact.name), ["外部活动资料"])
    }

    func testLateReadCannotRestorePreviousCampaignSelection() async throws {
        let root = try root(), context = try fixture(root: root), model = ready(read: { context }, root: root)
        let id = context.workflows[0].artifacts[0].id
        let task = Task { await model.referenceSelection.select(id) }
        await Task.yield()
        model.selectCampaign(context.campaigns[1].id)
        await task.value
        XCTAssertTrue(model.referenceSelection.selections.isEmpty)
        XCTAssertFalse(model.referenceSelection.entries.contains { $0.id == id })
    }

    func testMetadataPriorityMismatchAndExactUnicodeCacheChange() async throws {
        let root = try root(); var context = try fixture(root: root, content: "元数据正文", raw: "不同文件正文")
        let model = ready(read: { context }, root: root)
        await model.referenceSelection.select(context.workflows[0].artifacts[0].id)
        let body = model.referenceSelection.selections[0].body!
        XCTAssertEqual(body.text, "元数据正文")
        XCTAssertEqual(body.source, "元数据正文")
        XCTAssertTrue(body.comparison.contains("正文不一致"))
        context.workflows[0].artifacts[0].content = "é"
        do { try await model.revalidateReferencesForDelivery(); XCTFail("changed") } catch {}
        context.workflows[0].artifacts[0].content = "e\u{301}"
        do { try await model.revalidateReferencesForDelivery(); XCTFail("raw bytes changed") } catch {}
        XCTAssertEqual(Data(model.referenceSelection.selections[0].body!.text!.utf8), Data("e\u{301}".utf8))
    }

    func testFileChangeBlocksCopyUpdatesPreviewThenAllowsExplicitRetry() async throws {
        let root = try root(), context = try fixture(root: root), file = URL(fileURLWithPath: context.workflows[0].artifacts[0].location)
        var copied = [String]()
        let model = ready(read: { context }, root: root, copy: { copied.append($0); return true })
        await model.referenceSelection.select(context.workflows[0].artifacts[0].id)
        try Data("更新后的文件正文".utf8).write(to: file, options: .atomic)
        await copy(model)
        XCTAssertTrue(copied.isEmpty)
        XCTAssertTrue(model.copyFeedback!.contains("已变化"))
        XCTAssertTrue(model.preview!.contains("更新后的文件正文"))
        await copy(model)
        XCTAssertEqual(copied, [model.preview!])
    }

    func testFileRevisionChangeDetectedEvenWhenMetadataRemainsPreferred() async throws {
        let root = try root(), context = try fixture(root: root, content: "保留元数据", raw: "不同的旧文件")
        let model = ready(read: { context }, root: root)
        await model.referenceSelection.select(context.workflows[0].artifacts[0].id)
        let file = URL(fileURLWithPath: context.workflows[0].artifacts[0].location)
        let previous = model.preview
        try Data("不同的新文件".utf8).write(to: file, options: .atomic)
        do { try await model.revalidateReferencesForDelivery(); XCTFail("must detect file revision") } catch {}
        XCTAssertEqual(model.preview, previous)
        XCTAssertTrue(model.referenceSelection.feedback!.contains("文件修订"))
    }

    func testAdoptionChangeBlocksRecordAndRequiresUpdatedPreviewConfirmation() async throws {
        let root = try root(); var context = try fixture(root: root)
        let model = ready(read: { context }, root: root), history = AIWorkspaceHandoffStore(location: .init(root: root.appendingPathComponent("history"), error: nil))
        await history.reload(); await model.referenceSelection.select(context.workflows[0].artifacts[0].id)
        context.workflows[0].artifacts[0].isApprovedVersion = false
        context.workflows[0].artifacts[1].isApprovedVersion = true
        await history.recordCurrent(model)
        XCTAssertTrue(history.records.isEmpty)
        XCTAssertTrue(history.saveFeedback!.contains("已变化"))
        XCTAssertTrue(model.preview!.contains("采用状态：历史参考（非当前采用）"))
        let updated = model.preview
        await history.recordCurrent(model)
        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.records[0].prompt, updated)
    }

    func testMissingInvalidUTF8AndSymlinkNeverPretendAdded() async throws {
        let root = try root(); var context = try fixture(root: root)
        let file = URL(fileURLWithPath: context.workflows[0].artifacts[0].location)
        try FileManager.default.removeItem(at: file)
        let model = ready(read: { context }, root: root), id = context.workflows[0].artifacts[0].id
        await model.referenceSelection.select(id)
        XCTAssertNil(model.preview); XCTAssertNotNil(model.referenceSelection.selections[0].error)
        try Data([0xFF, 0xFE]).write(to: file)
        await model.referenceSelection.select(id)
        XCTAssertNil(model.preview)
        XCTAssertTrue(model.referenceSelection.selections[0].error!.contains("UTF-8"))
        try FileManager.default.removeItem(at: file)
        let target = root.appendingPathComponent("target.md"); try Data("protected".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: target)
        await model.referenceSelection.select(id)
        XCTAssertNil(model.preview)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "protected")
        context.workflows[0].artifacts[0].content = "可用的元数据来源"
        model.refresh(); await model.referenceSelection.select(id)
        XCTAssertTrue(model.preview!.contains("正文来源：元数据正文"))
        XCTAssertTrue(model.preview!.contains("拒绝符号链接"))
    }

    func testPerBodyAndWholePromptLimitsRejectWithoutTruncation() async throws {
        let root = try root(); var context = try fixture(root: root)
        context.workflows[0].artifacts[0].content = String(repeating: "x", count: ZhuowangAssetTextReader.bodyLimit + 1)
        let model = ready(read: { context }, root: root), first = context.workflows[0].artifacts[0].id
        await model.referenceSelection.select(first)
        XCTAssertNil(model.preview)
        XCTAssertTrue(model.referenceSelection.selections[0].error!.contains("2 MiB"))
        model.referenceSelection.remove(first)
        context.workflows[0].artifacts = (0..<3).map { index in
            ZhuowangArtifact(campaignID: context.campaigns[0].id, name: "大资料\(index)", type: .markdown,
                content: String(repeating: "a", count: 1500 * 1024), isApprovedVersion: true)
        }
        model.refresh()
        for entry in model.referenceSelection.entries { await model.referenceSelection.select(entry.id) }
        XCTAssertNil(model.preview)
        XCTAssertTrue(model.validation!.contains("4 MiB"))
        XCTAssertEqual(model.referenceSelection.selections[0].body?.text?.utf8.count, 1500 * 1024)
        model.referenceSelection.remove(model.referenceSelection.selections[0].id)
        XCTAssertNotNil(model.preview)
    }

    func testUnsupportedTypesOnlyMetadataAndIsolationFailsClosed() async throws {
        let root = try root(); var context = try fixture(root: root)
        for type in [ZhuowangArtifactType.image, .pdf, .html, .figma, .word, .excel] {
            context.workflows[0].artifacts.append(.init(campaignID: context.campaigns[0].id,
                name: type.title, type: type, content: "不应读取", isApprovedVersion: true))
        }
        let reader = ZhuowangAssetTextReader(allowedRoot: root)
        let model = AIWorkspaceTaskPreparation(read: { context }, referenceReader: reader, referenceIsolationError: "缺少隔离根")
        model.refresh(); model.selectCampaign(context.campaigns[0].id); model.selectStep(model.steps[0].id); model.goal = "目标"
        for entry in model.referenceSelection.entries where entry.artifact.type != .markdown {
            XCTAssertFalse(AIWorkspaceTaskReferenceSelection.supportsBody(entry))
            await model.referenceSelection.select(entry.id)
        }
        XCTAssertTrue(model.referenceSelection.selections.isEmpty)
        XCTAssertFalse(model.preview!.contains("不应读取"))
        await model.referenceSelection.select(context.workflows[0].artifacts[0].id)
        XCTAssertNil(model.preview)
        let stats = await reader.statistics(); XCTAssertEqual(stats.diskReads, 0)
    }

    func testRemovedArtifactBlocksDeliveryAndDuplicateIdentityExplained() async throws {
        let root = try root(); var context = try fixture(root: root)
        let model = ready(read: { context }, root: root)
        await model.referenceSelection.select(context.workflows[0].artifacts[0].id)
        context.workflows[0].artifacts = []
        await copy(model)
        XCTAssertNil(model.preview)
        XCTAssertNotNil(model.referenceSelection.selections[0].error)
        model.referenceSelection.remove(model.referenceSelection.selections[0].id)
        context = try fixture(root: root)
        context.workflows[0].artifacts.append(context.workflows[0].artifacts[0])
        model.refresh(); model.selectCampaign(context.campaigns[0].id)
        XCTAssertNotNil(model.referenceSelection.catalogError)
        XCTAssertTrue(model.referenceSelection.entries.isEmpty)
    }

    func testActualSelectionViewLayoutAndPrivateClipboard() async throws {
        let root = try root(), context = try fixture(root: root)
        let board = NSPasteboard(name: .init("CosmosReferences-\(UUID())")); defer { board.releaseGlobally() }
        let model = ready(read: { context }, root: root, copy: { text in board.clearContents(); return board.setString(text, forType: .string) })
        await model.referenceSelection.select(context.workflows[0].artifacts[1].id)
        let view = NSHostingView(rootView: AIWorkspaceTaskReferencesView(selection: model.referenceSelection))
        view.frame = NSRect(x: 0, y: 0, width: 1000, height: 1000); view.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(view.fittingSize.height, 0)
        await copy(model)
        XCTAssertEqual(Data(board.string(forType: .string)!.utf8), Data(model.preview!.utf8))
    }
}

nonisolated private final class ReferenceBusinessSource: ZhuowangPersistenceDataSource {
    let domainIdentifier = "ReferenceBusinessSource"
    var bytes: [String: Data] = [:]
    var writes = 0
    func data(forKey key: String) -> Data? { bytes[key] }
    func set(_ data: Data, forKey key: String) { writes += 1; bytes[key] = data }
}
