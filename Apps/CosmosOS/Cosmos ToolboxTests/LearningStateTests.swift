import XCTest
import AppKit
import SwiftUI
@testable import Cosmos_Toolbox

@MainActor
final class TerminationLog { var lines: [String] = [] }

@MainActor
final class FakeTerminationParticipant: CosmosTerminationParticipant {
    let name: String
    let log: TerminationLog
    var blocked = false
    var work: Bool
    let approves: Bool
    private(set) var frozen = false
    private(set) var resolveCount = 0
    init(_ name: String, log: TerminationLog, work: Bool, approves: Bool = true) {
        self.name = name; self.log = log; self.work = work; self.approves = approves
    }
    var terminationBlocked: Bool { blocked || frozen }
    var hasUnsavedWork: Bool { work }
    func freezeForTermination() { frozen = true; log.lines.append("freeze " + name) }
    func unfreezeAfterTermination() { frozen = false; log.lines.append("unfreeze " + name) }
    func resolveUnsavedWork() async -> Bool {
        resolveCount += 1; log.lines.append("resolve " + name)
        await Task.yield()
        if approves { work = false }
        return approves
    }
}

@MainActor
final class LearningStateTests: XCTestCase {
    var roots: [URL] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots = []; super.tearDown()
    }
    final class DayBox { var value = learningToday }
    func newRoot() -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosLearningPhase1-" + UUID().uuidString, isDirectory: true)
        roots.append(root); return root
    }
    func makeStore(box: DayBox = DayBox(), root: URL? = nil) async -> LearningStore {
        let store = LearningStore(storage: LearningFileStorage(root: root ?? newRoot()), today: { box.value })
        await store.reload(); return store
    }
    @discardableResult
    func addTopic(_ store: LearningStore, _ topic: LearningTopic) async -> LearningTopic {
        let saved = await store.saveTopic(topic, expectedRevision: nil)
        XCTAssertTrue(saved)
        return store.topics.first { $0.id == topic.id }!
    }
    @discardableResult
    func addEntry(_ store: LearningStore, _ topic: LearningTopic, _ body: String, _ day: String = "2026-10-09",
                  createdAt: Date = Date()) async -> LearningEntry {
        let entry = LearningEntry(topicID: topic.id, studyDay: LearningDay(string: day)!, body: body, createdAt: createdAt)
        let saved = await store.saveEntry(entry, expectedRevision: nil)
        XCTAssertTrue(saved)
        return store.entries.first { $0.id == entry.id }!
    }
    func ids(_ summaries: [LearningTopicSummary]) -> [UUID] { summaries.map(\.id) }

    // MARK: Search, filters and ordering

    func testSearchStatusArchiveAndNextStepFilters() async {
        let store = await makeStore(), model = LearningViewModel(copy: { _ in true })
        let a = await addTopic(store, LearningTopic(name: "Swift 并发", goal: "掌握 actor", status: .learning, nextStep: "读 Sendable"))
        let b = await addTopic(store, LearningTopic(name: "Figma", status: .planned, nextStep: "   \n"))
        let c = await addTopic(store, LearningTopic(name: "旧主题", status: .completed, resourceURL: "https://example.com/Legacy"))
        _ = await store.setArchived(c, true)
        await addEntry(store, a, "学了 TaskGroup 和 e\u{301}")
        func match() -> [UUID] { ids(model.summaries(topics: store.topics, entries: store.entries)) }
        XCTAssertEqual(Set(match()), [a.id, b.id])
        model.query = "taskgroup"; XCTAssertEqual(match(), [a.id])          // note body, case-insensitive
        model.query = "ACTOR"; XCTAssertEqual(match(), [a.id])              // goal
        model.query = "sendable"; XCTAssertEqual(match(), [a.id])           // next step
        model.query = "figma"; XCTAssertEqual(match(), [b.id])              // name
        model.query = "  "; XCTAssertEqual(Set(match()), [a.id, b.id])      // blank query ignored
        model.query = ""
        model.onlyNextStep = true; XCTAssertEqual(match(), [a.id])          // whitespace-only is not a next step
        XCTAssertEqual(store.topics.first { $0.id == b.id }?.nextStep, "   \n", "stored text is not rewritten")
        model.onlyNextStep = false
        model.statusFilter = .planned; XCTAssertEqual(match(), [b.id])
        model.statusFilter = .completed; XCTAssertTrue(match().isEmpty)
        model.showArchived = true; XCTAssertEqual(match(), [c.id])
        model.query = "legacy"; XCTAssertEqual(match(), [c.id])             // link
        model.statusFilter = nil; model.query = "nothing"; XCTAssertTrue(match().isEmpty)
    }

    func testTopicsAreOrderedByMostRecentStudyThenCreation() async {
        let store = await makeStore(), model = LearningViewModel(copy: { _ in true })
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let none = await addTopic(store, LearningTopic(name: "无记录", createdAt: base.addingTimeInterval(500)))
        let older = await addTopic(store, LearningTopic(name: "较早", createdAt: base))
        let sameA = await addTopic(store, LearningTopic(name: "同日甲", createdAt: base))
        let sameB = await addTopic(store, LearningTopic(name: "同日乙", createdAt: base))
        await addEntry(store, older, "x", "2026-10-05", createdAt: base.addingTimeInterval(400))
        await addEntry(store, sameA, "x", "2026-10-09", createdAt: base.addingTimeInterval(10))
        await addEntry(store, sameB, "x", "2026-10-09", createdAt: base.addingTimeInterval(20))
        let order = ids(model.summaries(topics: store.topics, entries: store.entries))
        XCTAssertEqual(order, [sameB.id, sameA.id, older.id, none.id])
        XCTAssertEqual(ids(model.summaries(topics: Array(store.topics.reversed()), entries: Array(store.entries.reversed()))), order)
        XCTAssertEqual(model.summaries(topics: store.topics, entries: store.entries).first?.lastEntry?.studyDay.string, "2026-10-09")
        XCTAssertNil(model.summaries(topics: store.topics, entries: store.entries).last?.lastEntry)
    }

    func testHistoryIsNewestFirstWithStableSameDayOrder() async {
        let store = await makeStore(), model = LearningViewModel(copy: { _ in true })
        let topic = await addTopic(store, LearningTopic(name: "A")), other = await addTopic(store, LearningTopic(name: "B"))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let a = await addEntry(store, topic, "早", "2026-10-09", createdAt: base)
        let b = await addEntry(store, topic, "晚", "2026-10-09", createdAt: base.addingTimeInterval(30))
        let c = await addEntry(store, topic, "旧", "2026-10-01", createdAt: base.addingTimeInterval(60))
        await addEntry(store, other, "别的主题")
        XCTAssertEqual(model.history(topicID: topic.id, entries: store.entries).map(\.id), [b.id, a.id, c.id])
        XCTAssertEqual(model.history(topicID: topic.id, entries: Array(store.entries.reversed())).map(\.id), [b.id, a.id, c.id])
        XCTAssertTrue(model.history(topicID: UUID(), entries: store.entries).isEmpty)
    }

    func testCopyLinkIsExactAndMissingLinkWritesNothing() async {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("CosmosLearningTests-" + UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("sentinel", forType: .string)
        let model = LearningViewModel(copy: { text in pasteboard.clearContents(); return pasteboard.setString(text, forType: .string) })
        let none = LearningTopic(name: "n"), count = pasteboard.changeCount
        XCTAssertFalse(model.copyLink(none)); XCTAssertEqual(pasteboard.changeCount, count)
        let linked = LearningTopic(name: "n", resourceURL: "https://example.com/a?b=1&c=中文")
        XCTAssertTrue(model.copyLink(linked))
        XCTAssertEqual(pasteboard.string(forType: .string), "https://example.com/a?b=1&c=中文")
    }

    func testSelectionIsClearedWhenTheTopicVanishes() {
        let model = LearningViewModel(copy: { _ in true }), topic = LearningTopic(name: "n")
        model.selectedID = topic.id
        model.reconcileSelection([topic]); XCTAssertEqual(model.selectedID, topic.id)
        model.reconcileSelection([]); XCTAssertNil(model.selectedID)
    }

    // MARK: Topic editing session

    func testTopicSessionDetectsByteLevelChangesAndPreservesWhitespaceThroughSave() async {
        let store = await makeStore()
        let session = LearningTopicEditSession(store: store, topic: nil)
        XCTAssertFalse(session.isDirty)
        session.name = "  Python  "; session.goal = "  目标\r\n\t"; session.nextStep = "   "
        XCTAssertTrue(session.isDirty)
        let saved = await session.save()
        XCTAssertTrue(saved); XCTAssertFalse(session.isDirty)
        XCTAssertEqual(session.name, "Python")
        XCTAssertEqual(Data(store.topics[0].goal.utf8), Data("  目标\r\n\t".utf8))
        XCTAssertEqual(Data(store.topics[0].nextStep.utf8), Data("   ".utf8))
        session.goal = "é"; _ = await session.save()
        session.goal = "e\u{301}"; XCTAssertTrue(session.isDirty)
        session.goal = "é"; XCTAssertFalse(session.isDirty)
    }

    func testTopicSessionKeepsDraftOnInvalidInputConflictAndArchive() async {
        let store = await makeStore()
        let topic = await addTopic(store, LearningTopic(name: "A"))
        let one = LearningTopicEditSession(store: store, topic: topic), two = LearningTopicEditSession(store: store, topic: topic)
        one.name = "   "
        let blank = await one.save()
        XCTAssertFalse(blank); XCTAssertTrue(one.isDirty); XCTAssertTrue(store.canSave)
        one.name = "甲"; one.goal = "第一份"; two.goal = "第二份"
        let first = await one.save(), second = await two.save()
        XCTAssertTrue(first); XCTAssertFalse(second)
        XCTAssertEqual(store.error, .conflict); XCTAssertEqual(two.goal, "第二份"); XCTAssertTrue(two.isDirty)
        await two.reload()
        XCTAssertEqual(two.goal, "第一份"); XCTAssertFalse(two.isDirty)
        // The topic is archived elsewhere while an editor is open.
        let open = LearningTopicEditSession(store: store, topic: store.topics[0])
        open.goal = "归档后的草稿"
        _ = await store.setArchived(store.topics[0], true)
        let refused = await open.save()
        // Archiving bumped the topic revision, so the stale editor is refused as a conflict first;
        // the archived-with-matching-revision case is covered at the storage boundary.
        XCTAssertFalse(refused); XCTAssertEqual(store.error, .conflict)
        XCTAssertEqual(open.goal, "归档后的草稿"); XCTAssertTrue(open.isDirty)
        XCTAssertEqual(store.topics[0].goal, "第一份")
        XCTAssertTrue(open.draftText.contains("归档后的草稿"))
    }

    func testCloseChoicesSaveDiscardCancelAndSaveFailure() async {
        let store = await makeStore()
        let session = LearningTopicEditSession(store: store, topic: nil)
        session.name = "n"; session.goal = "g"
        let cancel = await session.allowClose(choice: .cancel), discard = await session.allowClose(choice: .discard)
        XCTAssertFalse(cancel); XCTAssertTrue(discard); XCTAssertTrue(session.isDirty)
        let save = await session.allowClose(choice: .save)
        XCTAssertTrue(save); XCTAssertFalse(session.isDirty)
        let clean = await session.allowClose(choice: .cancel)
        XCTAssertTrue(clean, "a clean session never blocks closing")
        let failing = LearningTopicEditSession(store: store, topic: nil)
        failing.goal = "只有目标没有名称"
        let blocked = await failing.allowClose(choice: .save)
        XCTAssertFalse(blocked); XCTAssertTrue(failing.isDirty)
    }

    // MARK: Entry editing session

    func testDurationParsingIsStrict() async {
        let store = await makeStore()
        let topic = await addTopic(store, LearningTopic(name: "A"))
        let session = LearningEntryEditSession(store: store, topic: topic, entry: nil, today: learningToday)
        // `.none` = rejected; `.some(nil)` = blank (not recorded); `.some(n)` = minutes.
        func result(_ text: String) -> Int?? {
            session.durationText = text
            do { return .some(try session.parseDuration()) } catch { return .none }
        }
        XCTAssertEqual(result(""), .some(nil)); XCTAssertEqual(result("  "), .some(nil))
        XCTAssertEqual(result("30"), .some(30)); XCTAssertEqual(result(" 1440 "), .some(1440)); XCTAssertEqual(result("1"), .some(1))
        for bad in ["0", "1441", "-5", "+5", "1.5", "三十", "٣", "30分钟", "1e2", "０５"] {
            XCTAssertNil(result(bad), bad)
        }
    }

    func testNewEntryAndCombinedNextStepSave() async {
        let store = await makeStore()
        let topic = await addTopic(store, LearningTopic(name: "Swift", status: .learning, nextStep: "读第一章"))
        let session = LearningEntryEditSession(store: store, topic: topic, entry: nil, today: learningToday)
        XCTAssertFalse(session.isDirty); XCTAssertEqual(session.day, learningToday); XCTAssertEqual(session.nextStep, "读第一章")
        session.body = "\n  读完第一章。\r\n"; session.durationText = "45"
        let plain = await session.save()
        XCTAssertTrue(plain); XCTAssertEqual(store.topics[0].revision, topic.revision, "untouched next step is not written")
        XCTAssertEqual(Data(store.entries[0].body.utf8), Data("\n  读完第一章。\r\n".utf8))
        XCTAssertEqual(store.entries[0].durationMinutes, 45); XCTAssertFalse(session.isDirty)
        let next = LearningEntryEditSession(store: store, topic: store.topics[0], entry: nil, today: learningToday)
        next.body = "第二次"; next.nextStep = "  读第二章 "
        XCTAssertTrue(next.isDirty)
        let combined = await next.save()
        XCTAssertTrue(combined); XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.topics[0].nextStep, "  读第二章 "); XCTAssertEqual(store.topics[0].status, .learning)
        // No automatic status change, no progress field.
        XCTAssertEqual(store.topics[0].status, .learning)
    }

    func testCombinedSaveFailsAsAWholeWhenTheTopicChangedUnderneath() async {
        let store = await makeStore()
        let topic = await addTopic(store, LearningTopic(name: "A", nextStep: "旧"))
        let session = LearningEntryEditSession(store: store, topic: topic, entry: nil, today: learningToday)
        session.body = "草稿正文"; session.nextStep = "我的新下一步"
        var edit = topic; edit.goal = "别处修改"
        _ = await store.saveTopic(edit, expectedRevision: topic.revision)
        let saved = await session.save()
        XCTAssertFalse(saved); XCTAssertEqual(store.error, .conflict)
        XCTAssertTrue(store.entries.isEmpty); XCTAssertEqual(store.topics[0].nextStep, "旧")
        XCTAssertEqual(session.body, "草稿正文"); XCTAssertEqual(session.nextStep, "我的新下一步"); XCTAssertTrue(session.isDirty)
        XCTAssertTrue(session.draftText.contains("草稿正文"))
    }

    func testEditingAnOldEntryKeepsItsDateAcrossATimeZoneShiftButRejectsNewFutureDates() async {
        let box = DayBox()
        let store = await makeStore(box: box)
        let topic = await addTopic(store, LearningTopic(name: "A"))
        box.value = LearningDay(string: "2026-10-10")!
        let entry = await addEntry(store, topic, "东边写的", "2026-10-10")
        box.value = learningToday                        // now "yesterday" by the local calendar
        let session = LearningEntryEditSession(store: store, topic: topic, entry: entry, today: learningToday)
        XCTAssertFalse(session.isDirty)
        session.body = "只改正文"
        let kept = await session.save()
        XCTAssertTrue(kept); XCTAssertEqual(store.entries[0].studyDay.string, "2026-10-10")
        session.day = LearningDay(string: "2026-10-12")!
        let future = await session.save()
        XCTAssertFalse(future); XCTAssertEqual(store.error, .futureDate); XCTAssertTrue(session.isDirty)
        session.day = LearningDay(string: "2026-10-01")!
        let past = await session.save()
        XCTAssertTrue(past); XCTAssertEqual(store.entries[0].studyDay.string, "2026-10-01")
        let created = LearningEntryEditSession(store: store, topic: topic, entry: nil, today: learningToday)
        created.day = LearningDay(string: "2026-10-10")!; created.body = "新建未来"
        let refused = await created.save()
        XCTAssertFalse(refused); XCTAssertEqual(store.error, .futureDate); XCTAssertEqual(store.entries.count, 1)
    }

    func testEntrySessionKeepsDraftWhenTheTopicGetsArchivedAndStaleEntriesConflict() async {
        let store = await makeStore()
        let topic = await addTopic(store, LearningTopic(name: "A"))
        let entry = await addEntry(store, topic, "原文")
        let one = LearningEntryEditSession(store: store, topic: topic, entry: entry, today: learningToday)
        let two = LearningEntryEditSession(store: store, topic: topic, entry: entry, today: learningToday)
        one.body = "第一份"; two.body = "第二份"
        let first = await one.save(), second = await two.save()
        XCTAssertTrue(first); XCTAssertFalse(second); XCTAssertEqual(store.error, .conflict); XCTAssertEqual(two.body, "第二份")
        await two.reload()
        XCTAssertEqual(two.body, "第一份")
        two.body = "归档后"
        _ = await store.setArchived(store.topics[0], true)
        let late = await two.save()
        XCTAssertFalse(late); XCTAssertEqual(store.error, .topicArchived); XCTAssertEqual(two.body, "归档后")
        XCTAssertEqual(store.entries[0].body, "第一份")
    }

    func testStatusArchiveAndRestoreGoThroughTheStoreAndNeverChangeStatusAutomatically() async {
        let store = await makeStore()
        let topic = await addTopic(store, LearningTopic(name: "A"))
        XCTAssertEqual(topic.status, .planned)
        await addEntry(store, topic, "记录不会改变状态")
        XCTAssertEqual(store.topics[0].status, .planned)
        let changed = await store.setStatus(store.topics[0], .completed)
        XCTAssertTrue(changed)
        let stale = await store.setStatus(topic, .learning)                 // stale revision
        XCTAssertFalse(stale); XCTAssertEqual(store.error, .conflict); XCTAssertEqual(store.topics[0].status, .completed)
        _ = await store.setArchived(store.topics[0], true)
        let readOnly = await store.setStatus(store.topics[0], .learning)
        XCTAssertFalse(readOnly); XCTAssertEqual(store.error, .topicArchived)
        _ = await store.setArchived(store.topics[0], false)
        XCTAssertEqual(store.topics[0].status, .completed); XCTAssertEqual(store.entries.count, 1)
        let reopened = LearningStore(storage: LearningFileStorage(root: roots[0]), today: { learningToday })
        await reopened.reload()
        XCTAssertEqual(reopened.topics, store.topics); XCTAssertEqual(reopened.entries, store.entries)
    }

    // MARK: Shared quit protection

    func runQuit(_ participants: [any CosmosTerminationParticipant], coordinator: CosmosTerminationCoordinator)
        async -> (reply: NSApplication.TerminateReply, answers: [Bool]) {
        var answers: [Bool] = []
        let reply = coordinator.request(participants: participants) { answers.append($0) }
        if reply == .terminateLater {
            for _ in 0..<50 where answers.isEmpty { await Task.yield(); try? await Task.sleep(nanoseconds: 2_000_000) }
            try? await Task.sleep(nanoseconds: 30_000_000)           // a duplicate reply would show up here
        }
        return (reply, answers)
    }

    func testQuitWithNoDraftsKeepsTheOriginalImmediateBehavior() async {
        let log = TerminationLog()
        let prompt = FakeTerminationParticipant("prompt", log: log, work: false)
        let learning = FakeTerminationParticipant("learning", log: log, work: false)
        let result = await runQuit([prompt, learning], coordinator: CosmosTerminationCoordinator())
        XCTAssertEqual(result.reply, .terminateNow); XCTAssertTrue(result.answers.isEmpty); XCTAssertTrue(log.lines.isEmpty)
    }

    func testQuitIsCancelledWhileASaveOrCloseIsInFlight() async {
        let log = TerminationLog()
        let prompt = FakeTerminationParticipant("prompt", log: log, work: true)
        let learning = FakeTerminationParticipant("learning", log: log, work: true)
        learning.blocked = true
        let result = await runQuit([prompt, learning], coordinator: CosmosTerminationCoordinator())
        XCTAssertEqual(result.reply, .terminateCancel); XCTAssertTrue(log.lines.isEmpty); XCTAssertEqual(prompt.resolveCount, 0)
    }

    func testBothModulesWithDraftsAreFrozenFirstThenResolvedThenRepliedOnce() async {
        let log = TerminationLog(), coordinator = CosmosTerminationCoordinator()
        let prompt = FakeTerminationParticipant("prompt", log: log, work: true)
        let learning = FakeTerminationParticipant("learning", log: log, work: true)
        let result = await runQuit([prompt, learning], coordinator: coordinator)
        XCTAssertEqual(result.reply, .terminateLater); XCTAssertEqual(result.answers, [true])
        XCTAssertEqual(Array(log.lines.prefix(4)), ["freeze prompt", "freeze learning", "resolve prompt", "resolve learning"])
        XCTAssertEqual(prompt.resolveCount, 1); XCTAssertEqual(learning.resolveCount, 1)
        XCTAssertFalse(prompt.frozen); XCTAssertFalse(learning.frozen); XCTAssertFalse(coordinator.pending)
        let again = await runQuit([prompt, learning], coordinator: coordinator)
        XCTAssertEqual(again.reply, .terminateNow, "a finished request leaves the coordinator reusable")
    }

    func testOnlyTheModuleWithDraftsIsAsked() async {
        let log = TerminationLog()
        let prompt = FakeTerminationParticipant("prompt", log: log, work: false)
        let learning = FakeTerminationParticipant("learning", log: log, work: true)
        let result = await runQuit([prompt, learning], coordinator: CosmosTerminationCoordinator())
        XCTAssertEqual(result.answers, [true]); XCTAssertEqual(prompt.resolveCount, 0); XCTAssertEqual(learning.resolveCount, 1)
    }

    func testLearningAgreesThenPromptCancelsCancelsQuitAndRestoresBothModules() async {
        for order in [0, 1] {
            let log = TerminationLog(), coordinator = CosmosTerminationCoordinator()
            let prompt = FakeTerminationParticipant("prompt", log: log, work: true, approves: false)
            let learning = FakeTerminationParticipant("learning", log: log, work: true, approves: true)
            let participants: [any CosmosTerminationParticipant] = order == 0 ? [learning, prompt] : [prompt, learning]
            let result = await runQuit(participants, coordinator: coordinator)
            XCTAssertEqual(result.reply, .terminateLater); XCTAssertEqual(result.answers, [false], "order \(order)")
            XCTAssertFalse(prompt.frozen); XCTAssertFalse(learning.frozen); XCTAssertFalse(coordinator.pending)
            XCTAssertTrue(prompt.work, "the cancelled draft is still there")
            XCTAssertEqual(log.lines.filter { $0.hasPrefix("unfreeze") }.count, 2)
        }
    }

    func testFirstCancelStopsTheChainWithoutAskingTheRest() async {
        let log = TerminationLog()
        let prompt = FakeTerminationParticipant("prompt", log: log, work: true, approves: false)
        let learning = FakeTerminationParticipant("learning", log: log, work: true)
        let result = await runQuit([prompt, learning], coordinator: CosmosTerminationCoordinator())
        XCTAssertEqual(result.answers, [false]); XCTAssertEqual(learning.resolveCount, 0)
        XCTAssertFalse(prompt.frozen); XCTAssertFalse(learning.frozen)
    }

    func testASecondQuitRequestWhilePendingIsCancelledAndNeverRepliesTwice() async {
        let log = TerminationLog(), coordinator = CosmosTerminationCoordinator()
        let prompt = FakeTerminationParticipant("prompt", log: log, work: true)
        let learning = FakeTerminationParticipant("learning", log: log, work: false)
        var answers: [Bool] = []
        let first = coordinator.request(participants: [prompt, learning]) { answers.append($0) }
        XCTAssertEqual(first, .terminateLater); XCTAssertTrue(coordinator.pending)
        let second = coordinator.request(participants: [prompt, learning]) { answers.append($0) }
        XCTAssertEqual(second, .terminateCancel)
        for _ in 0..<50 where answers.isEmpty { await Task.yield(); try? await Task.sleep(nanoseconds: 2_000_000) }
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(answers, [true]); XCTAssertEqual(prompt.resolveCount, 1)
    }

    func testRealManagersFreezeNewEditorsAndSaveDraftsOnQuit() async throws {
        let store = await makeStore()
        let learning = LearningEditorWindowManager(), prompt = PromptTemplateWindowManager()
        learning.chooseClose = { _ in .save }
        XCTAssertFalse(prompt.hasUnsavedWork); XCTAssertFalse(prompt.terminationBlocked)
        prompt.freezeForTermination(); XCTAssertTrue(prompt.terminationBlocked)
        prompt.unfreezeAfterTermination(); XCTAssertFalse(prompt.terminationBlocked)
        let promptOK = await prompt.resolveUnsavedWork()
        XCTAssertTrue(promptOK)
        learning.openTopic(store: store, topic: nil)
        defer { NSApp.windows.filter { $0.identifier?.rawValue.hasPrefix(store.storageIdentity) == true }.forEach { $0.close() } }
        let session = try XCTUnwrap(learning.openSessions.first as? LearningTopicEditSession)
        XCTAssertFalse(learning.hasUnsavedWork)
        session.name = "窗口里的主题"; session.goal = " 保留空白 "
        XCTAssertTrue(learning.hasUnsavedWork)
        // Pending quit: the editor is frozen and no new editor can slip past the protection.
        learning.freezeForTermination()
        XCTAssertTrue(session.terminationPending); XCTAssertTrue(learning.terminationBlocked)
        learning.openTopic(store: store, topic: nil); learning.openEntry(store: store, topic: LearningTopic(name: "x"), entry: nil)
        XCTAssertEqual(learning.openSessions.count, 1)
        learning.unfreezeAfterTermination()
        XCTAssertFalse(session.terminationPending); XCTAssertFalse(learning.terminationBlocked)
        // Coordinator over the real managers: cancel keeps the draft, save writes it exactly once.
        let coordinator = CosmosTerminationCoordinator()
        learning.chooseClose = { _ in .cancel }
        let cancelled = await runQuit([prompt, learning], coordinator: coordinator)
        XCTAssertEqual(cancelled.answers, [false]); XCTAssertTrue(learning.hasUnsavedWork); XCTAssertTrue(store.topics.isEmpty)
        XCTAssertFalse(session.terminationPending)
        learning.chooseClose = { _ in .save }
        let saved = await runQuit([prompt, learning], coordinator: coordinator)
        XCTAssertEqual(saved.answers, [true]); XCTAssertFalse(learning.hasUnsavedWork)
        XCTAssertEqual(store.topics.count, 1); XCTAssertEqual(store.topics[0].goal, " 保留空白 ")
        // A failing save blocks quitting and keeps the draft.
        session.name = "  "; session.goal = "失败中的草稿"
        let failed = await runQuit([prompt, learning], coordinator: coordinator)
        XCTAssertEqual(failed.answers, [false]); XCTAssertTrue(learning.hasUnsavedWork); XCTAssertEqual(session.goal, "失败中的草稿")
    }

    // MARK: Rendering

    func testRealViewsRenderOffscreen() async throws {
        let root = newRoot()
        let store = LearningStore(storage: LearningFileStorage(root: root), today: { learningToday })
        await store.reload()
        let topic = await addTopic(store, LearningTopic(name: "Swift 并发", goal: "掌握 actor", status: .learning,
            nextStep: "读 Sendable", resourceURL: "https://example.com/swift"))
        await addEntry(store, topic, String(repeating: "第一行\n", count: 12), "2026-10-09")
        let model = LearningViewModel(copy: { _ in true })
        func png<V: View>(_ view: V, _ name: String) throws {
            let renderer = ImageRenderer(content: view)
            let image = try XCTUnwrap(renderer.nsImage, name)
            let rep = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
            let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
            try data.write(to: root.appendingPathComponent(name + ".png"))
            XCTAssertGreaterThan(data.count, 1000, name)
        }
        try png(LearningCenterView(location: LearningLocation(root: root, error: nil)).frame(width: 1060, height: 700), "center")
        try png(LearningTopicDetailView(topic: store.topics[0], history: store.entries, store: store, model: model)
            .frame(width: 560, height: 700), "detail")
        try png(LearningTopicEditorView(session: LearningTopicEditSession(store: store, topic: store.topics[0]), store: store), "topic-editor")
        try png(LearningEntryEditorView(session: LearningEntryEditSession(store: store, topic: store.topics[0], entry: nil,
            today: learningToday), store: store), "entry-editor")
        try png(LearningCenterView(location: LearningLocation(root: nil, error: .unsafePath)).frame(width: 760, height: 520), "blocked")
    }
}
