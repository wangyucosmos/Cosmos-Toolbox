import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

nonisolated private final class HandoffFailure: @unchecked Sendable {
    private let lock = NSLock()
    private var stage: AIWorkspaceHandoffStorageStage?
    func fail(_ value: AIWorkspaceHandoffStorageStage?) { lock.lock(); stage = value; lock.unlock() }
    func check(_ value: AIWorkspaceHandoffStorageStage) throws {
        lock.lock(); defer { lock.unlock() }
        if stage == value { throw AIWorkspaceHandoffError.storage("injected") }
    }
}

@MainActor
final class AIWorkspaceHandoffTests: XCTestCase {
    private var roots: [URL] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots = []; super.tearDown()
    }
    private func root() -> URL {
        let root = URL(fileURLWithPath: AIWorkspaceHandoffLocation.fixturePrefix + UUID().uuidString)
        roots.append(root); return root
    }
    private func fixture() -> AIWorkspaceTaskContext {
        let campaign = ZhuowangCampaign(name: "保存时活动", scopeType: .national,
            startDate: Date(timeIntervalSinceReferenceDate: 0), endDate: Date(timeIntervalSinceReferenceDate: 86400))
        let step = ZhuowangWorkflowStep(title: "保存时步骤", sortOrder: 10, status: .ready)
        return AIWorkspaceTaskContext(campaigns: [campaign], workflows: [ZhuowangCampaignWorkflow(campaignID: campaign.id, steps: [step])])
    }
    private func ready(read: @escaping () throws -> AIWorkspaceTaskContext,
                       copy: @escaping (String) -> Bool = { _ in true }) -> AIWorkspaceTaskPreparation {
        let model = AIWorkspaceTaskPreparation(read: read, copy: copy)
        model.refresh(); model.selectCampaign(model.context.campaigns[0].id)
        model.selectStep(model.steps[0].id); model.goal = "  原始目标\n"
        model.requirements = "原文 e\u{301} 😀\r\n不要截断\t尾部  \n"
        return model
    }
    private func record(_ text: String = "原文\r\n e\u{301} 😀\t尾部 \n", at: Date = Date(), id: UUID = UUID()) -> AIWorkspaceHandoffRecord {
        .init(id: id, recordedAt: at, campaignID: UUID(), campaignName: "活动", workflowID: UUID(), workflowName: "流程",
            stepID: UUID(), stepName: "步骤", toolIdentifier: "Claude", toolName: "Claude", goal: "目标", requirements: "要求", prompt: text)
    }
    private func store(_ root: URL, storage: AIWorkspaceHandoffFileStorage? = nil) -> AIWorkspaceHandoffStore {
        AIWorkspaceHandoffStore(location: .init(root: root, error: nil), storage: storage)
    }

    func testSaveReloadExactPromptAndSnapshotNames() async throws {
        var context = fixture()
        let model = ready(read: { context }), root = root(), history = store(root)
        await history.reload()
        let displayed = try XCTUnwrap(model.preview)
        await history.recordCurrent(model)
        let saved = try XCTUnwrap(history.records.first)
        XCTAssertEqual(Data(saved.prompt.utf8), Data(displayed.utf8))
        XCTAssertEqual(Data(saved.requirements.utf8), Data(model.requirements.utf8))
        context.campaigns[0].name = "改名活动"; context.workflows[0].steps[0].title = "改名步骤"
        context.workflows[0].name = "改名流程"
        let reloaded = try await AIWorkspaceHandoffFileStorage(root: root).load()
        XCTAssertEqual(reloaded, [saved])
        XCTAssertEqual(reloaded[0].campaignName, "保存时活动")
        XCTAssertEqual(reloaded[0].stepName, "保存时步骤")
        XCTAssertEqual(Data(reloaded[0].prompt.utf8), Data(displayed.utf8))
    }

    func testDeletedAssociationsRemainReadableAndCopyExactSnapshot() async throws {
        var context = fixture()
        let model = ready(read: { context }), root = root(), history = store(root)
        await history.reload(); await history.recordCurrent(model)
        let saved = try XCTUnwrap(history.records.first)
        context.workflows[0].steps = []
        XCTAssertTrue(model.associationStatus(for: saved).contains("步骤已不存在"))
        context.campaigns = []
        XCTAssertTrue(model.associationStatus(for: saved).contains("活动已不存在"))
        model.refresh()
        let loaded = try await AIWorkspaceHandoffFileStorage(root: root).load()
        var copied: String?
        let copier = AIWorkspaceHandoffCopyModel(copy: { copied = $0; return true })
        copier.copySnapshot(loaded[0])
        XCTAssertEqual(Data(copied!.utf8), Data(saved.prompt.utf8))
        XCTAssertEqual(copier.feedback, "已复制保存时的完整提示词快照")
    }

    func testCopyDoesNotRecordAndChangedPreviewNotice() async throws {
        let context = fixture(), model = ready(read: { context }), root = root(), history = store(root)
        await history.reload(); model.copyPreview()
        XCTAssertTrue(history.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: history.location.root!.path))
        model.requirements = "复制后更改"
        XCTAssertTrue(model.recordingNotice.contains("不是之前复制的版本"))
        let current = model.preview
        await history.recordCurrent(model)
        XCTAssertEqual(history.records[0].prompt, current)
        XCTAssertNotEqual(history.records[0].prompt, model.lastCopiedPrompt)
    }

    func testRepeatedClicksAndExplicitLaterHandoff() async throws {
        let context = fixture(), model = ready(read: { context }), history = store(root())
        await history.reload()
        async let first: Void = history.recordCurrent(model)
        async let second: Void = history.recordCurrent(model)
        _ = await (first, second)
        XCTAssertEqual(history.records.count, 1)
        await history.recordCurrent(model)
        XCTAssertEqual(history.records.count, 1)
        history.prepareAnotherHandoff()
        XCTAssertEqual(history.records.count, 1)
        await history.recordCurrent(model)
        XCTAssertEqual(history.records.count, 2)
        XCTAssertNotEqual(history.records[0].id, history.records[1].id)
        XCTAssertEqual(history.records[0].prompt, history.records[1].prompt)
    }

    func testContextChangeNeverSilentlySavesAndLostAssociationPreservesDraft() async throws {
        var context = fixture()
        let model = ready(read: { context }), history = store(root())
        await history.reload()
        context.campaigns[0].notes = "新资料"
        await history.recordCurrent(model)
        XCTAssertTrue(history.records.isEmpty)
        XCTAssertTrue(history.saveFeedback!.contains("上下文已更新，未记录"))
        XCTAssertTrue(model.preview!.contains("新资料"))
        let preview = model.preview, goal = model.goal, requirements = model.requirements
        context.workflows = []
        await history.recordCurrent(model)
        XCTAssertTrue(history.records.isEmpty)
        XCTAssertEqual(model.preview, preview)
        XCTAssertEqual(model.goal, goal); XCTAssertEqual(model.requirements, requirements)
        XCTAssertTrue(history.saveFeedback!.contains("关联已失效"))
    }

    func testWriteFailurePreservesExistingPrimaryAndCurrentDraftThenRetry() async throws {
        let root = root(), failure = HandoffFailure()
        let storage = AIWorkspaceHandoffFileStorage(root: root, hook: { try failure.check($0) })
        let first = record()
        _ = try await storage.append(first)
        let before = try Data(contentsOf: storage.primaryURL)
        let context = fixture(), model = ready(read: { context }), history = store(root, storage: storage)
        await history.reload()
        let displayed = model.preview, goal = model.goal, requirements = model.requirements
        failure.fail(.replace)
        await history.recordCurrent(model)
        XCTAssertEqual(try Data(contentsOf: storage.primaryURL), before)
        XCTAssertEqual(history.records, [first])
        XCTAssertEqual(model.preview, displayed); XCTAssertEqual(model.goal, goal); XCTAssertEqual(model.requirements, requirements)
        XCTAssertNotNil(history.saveFeedback)
        failure.fail(nil)
        await history.recordCurrent(model)
        XCTAssertEqual(history.records.count, 2)
        XCTAssertEqual(history.records.first { $0.id != first.id }?.prompt, displayed)
    }

    func testUncertainWriteRetrySameIdentityDoesNotDuplicate() async throws {
        let root = root(), failure = HandoffFailure()
        let storage = AIWorkspaceHandoffFileStorage(root: root, hook: { try failure.check($0) })
        let context = fixture(), model = ready(read: { context }), history = store(root, storage: storage)
        await history.reload(); failure.fail(.readBack)
        await history.recordCurrent(model)
        XCTAssertTrue(history.records.isEmpty)
        XCTAssertTrue(history.saveFeedback!.contains("未能确认"))
        failure.fail(nil)
        let disk = try await storage.load()
        XCTAssertEqual(disk.count, 1)
        await history.recordCurrent(model)
        XCTAssertEqual(history.records, disk)
        let final = try await storage.load()
        XCTAssertEqual(final.count, 1)
    }

    func testCorruptReadNeverClearsOverwritesOrFallsBackToBackup() async throws {
        let root = root(), storage = AIWorkspaceHandoffFileStorage(root: root)
        _ = try await storage.append(record())
        let good = try Data(contentsOf: storage.primaryURL)
        try good.write(to: storage.backupURL)
        let corrupt = Data("invalid JSON".utf8)
        try corrupt.write(to: storage.primaryURL)
        let history = store(root)
        await history.reload()
        XCTAssertNotNil(history.loadError); XCTAssertFalse(history.loaded)
        do { _ = try await storage.append(record()); XCTFail("must refuse") } catch {}
        XCTAssertEqual(try Data(contentsOf: storage.primaryURL), corrupt)
        XCTAssertEqual(try Data(contentsOf: storage.backupURL), good)
        try FileManager.default.removeItem(at: storage.primaryURL)
        do { _ = try await storage.load(); XCTFail("must refuse") }
        catch { XCTAssertEqual(error as? AIWorkspaceHandoffError, .missingPrimaryWithBackup) }
        do { _ = try await storage.append(record()); XCTFail("must refuse") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.primaryURL.path))
    }

    func testConcurrentStorageInstancesAppendWithoutLostRecordsAndBackupValid() async throws {
        let root = root(), one = AIWorkspaceHandoffFileStorage(root: root), two = AIWorkspaceHandoffFileStorage(root: root)
        let a = record(), b = record()
        async let first = one.append(a)
        async let second = two.append(b)
        _ = try await (first, second)
        let all = try await one.load()
        XCTAssertEqual(Set(all.map(\.id)), Set([a.id, b.id]))
        let backup = try JSONDecoder().decode(AIWorkspaceHandoffDocument.self, from: Data(contentsOf: one.backupURL))
        XCTAssertEqual(backup.records.count, 1)
        _ = try await one.append(a)
        let afterRetry = try await two.load()
        XCTAssertEqual(afterRetry.count, 2)
    }

    func testStageFailuresBeforeReplacementPreservePrimary() async throws {
        let root = root(), failure = HandoffFailure(), storage = AIWorkspaceHandoffFileStorage(root: root, hook: { try failure.check($0) })
        _ = try await storage.append(record())
        let before = try Data(contentsOf: storage.primaryURL)
        for stage in [AIWorkspaceHandoffStorageStage.read, .encode, .backup, .backupReadBack, .replace] {
            failure.fail(stage)
            do { _ = try await storage.append(record()); XCTFail("must fail") } catch {}
            XCTAssertEqual(try Data(contentsOf: storage.primaryURL), before)
        }
    }

    func testSymlinkAndInvalidSchemaRefusedWithoutChangingTarget() async throws {
        let root = root(), storage = AIWorkspaceHandoffFileStorage(root: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("target.json"), content = Data("protected".utf8)
        try content.write(to: target)
        try FileManager.default.createSymbolicLink(at: storage.primaryURL, withDestinationURL: target)
        do { _ = try await storage.append(record()); XCTFail("unsafe") } catch {}
        XCTAssertEqual(try Data(contentsOf: target), content)
        try FileManager.default.removeItem(at: storage.primaryURL)
        try Data("{\"schemaVersion\":99,\"records\":[]}".utf8).write(to: storage.primaryURL)
        let before = try Data(contentsOf: storage.primaryURL)
        do { _ = try await storage.load(); XCTFail("unknown schema") } catch {}
        do { _ = try await storage.append(record()); XCTFail("unknown schema") } catch {}
        XCTAssertEqual(try Data(contentsOf: storage.primaryURL), before)
    }

    func testBusinessSourceUntouchedByRecordingReadingAndHistoricalCopy() async throws {
        let source = HandoffBusinessSource(), context = fixture()
        source.bytes[ZhuowangCampaignStore.storageKey] = try JSONEncoder().encode(context.campaigns)
        source.bytes[ZhuowangWorkflowStore.workflowStorageKey] = try JSONEncoder().encode(context.workflows)
        let before = source.bytes
        let reader = AIWorkspaceTaskContextReader(source: source)
        let model = ready(read: { try reader.read() }), history = store(root())
        await history.reload(); model.copyPreview(); await history.recordCurrent(model); await history.reload()
        let record = history.records[0]
        _ = model.associationStatus(for: record)
        AIWorkspaceHandoffCopyModel(copy: { _ in true }).copySnapshot(record)
        XCTAssertEqual(source.bytes, before); XCTAssertEqual(source.writes, 0)
    }

    func testPrivateClipboardExactBytesAndFailureFeedback() {
        let board = NSPasteboard(name: .init("CosmosHandoffTests-\(UUID())"))
        defer { board.releaseGlobally() }
        let saved = record()
        let model = AIWorkspaceHandoffCopyModel(copy: { text in board.clearContents(); return board.setString(text, forType: .string) })
        model.copySnapshot(saved)
        XCTAssertEqual(Data(board.string(forType: .string)!.utf8), Data(saved.prompt.utf8))
        let failing = AIWorkspaceHandoffCopyModel(copy: { _ in false })
        failing.copySnapshot(saved); XCTAssertEqual(failing.feedback, "复制失败，请重试。")
    }

    func testLocationIsolationFailsClosedAndReadMissingDoesNotCreateDirectory() async throws {
        let root = root()
        let location = AIWorkspaceHandoffLocation.resolve(isIsolated: true,
            bundleIdentifier: CosmosDebugStorePersistenceBootstrap.isolatedBundleIdentifierPrefix + "handoff",
            arguments: [AIWorkspaceHandoffLocation.fixtureFlag, root.path])
        XCTAssertEqual(location.root?.path, root.path)
        XCTAssertNil(AIWorkspaceHandoffLocation.resolve(isIsolated: true, bundleIdentifier: "formal", arguments: []).root)
        XCTAssertNil(AIWorkspaceHandoffLocation.resolve(isIsolated: true,
            bundleIdentifier: CosmosDebugStorePersistenceBootstrap.isolatedBundleIdentifierPrefix + "handoff", arguments: []).root)
        let values = try await AIWorkspaceHandoffFileStorage(root: root).load()
        XCTAssertTrue(values.isEmpty); XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testNewestFirstFilterAndActualViewsRender() async throws {
        let root = root(), storage = AIWorkspaceHandoffFileStorage(root: root)
        let older = record(at: Date(timeIntervalSinceReferenceDate: 1)), newer = record(at: Date(timeIntervalSinceReferenceDate: 2))
        _ = try await storage.append(older); _ = try await storage.append(newer)
        let history = store(root); await history.reload()
        XCTAssertEqual(history.records.map(\.id), [newer.id, older.id])
        XCTAssertEqual(history.campaignFilters.count, 2)
        let context = fixture(), preparation = ready(read: { context })
        let list = NSHostingView(rootView: AIWorkspaceHandoffHistoryView(history: history, preparation: preparation))
        list.frame = NSRect(x: 0, y: 0, width: 1000, height: 800); list.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(list.fittingSize.height, 0)
        let detail = NSHostingView(rootView: AIWorkspaceHandoffDetailView(record: newer, association: { "关联缺失" }))
        detail.frame = list.frame; detail.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(detail.fittingSize.height, 0)
    }
}

nonisolated private final class HandoffBusinessSource: ZhuowangPersistenceDataSource {
    let domainIdentifier = "HandoffBusinessSource"
    var bytes: [String: Data] = [:]
    var writes = 0
    func data(forKey key: String) -> Data? { bytes[key] }
    func set(_ data: Data, forKey key: String) { writes += 1; bytes[key] = data }
}
