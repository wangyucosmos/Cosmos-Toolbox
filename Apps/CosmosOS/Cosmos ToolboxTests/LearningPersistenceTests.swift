import XCTest
import Foundation
@testable import Cosmos_Toolbox

nonisolated final class LearningStageFailure: @unchecked Sendable {
    private let lock = NSLock()
    private var stage: LearningStorageStage?
    func fail(_ stage: LearningStorageStage?) { lock.lock(); self.stage = stage; lock.unlock() }
    func check(_ value: LearningStorageStage) throws {
        lock.lock(); defer { lock.unlock() }
        if stage == value { throw LearningError.storage("injected") }
    }
}

let learningToday = LearningDay(string: "2026-10-09")!

@MainActor
final class LearningPersistenceTests: XCTestCase {
    var roots: [URL] = []
    override func tearDown() {
        for root in roots {
            chmod(root.path, 0o700)
            try? FileManager.default.removeItem(at: root)
        }
        roots = []; super.tearDown()
    }
    func root() -> URL {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosLearningPhase1-" + UUID().uuidString, isDirectory: true)
        roots.append(root); return root
    }
    func writeRaw(_ root: URL, _ data: Data, name: String = "learning.json") throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try data.write(to: root.appendingPathComponent(name))
    }
    func assertFailure(_ expected: LearningError, _ operation: () async throws -> Void,
                       file: StaticString = #filePath, line: UInt = #line) async {
        do { try await operation(); XCTFail("expected \(expected)", file: file, line: line) }
        catch { XCTAssertEqual(error as? LearningError, expected, file: file, line: line) }
    }
    @discardableResult
    func addTopic(_ storage: LearningFileStorage, _ topic: LearningTopic = LearningTopic(name: "Swift")) async throws -> LearningTopic {
        let snapshot = try await storage.apply(.saveTopic(topic, expectedRevision: nil))
        return snapshot.topics.first { $0.id == topic.id }!
    }
    @discardableResult
    func addEntry(_ storage: LearningFileStorage, topic: LearningTopic, body: String = "学了泛型",
                  day: LearningDay = learningToday, duration: Int? = nil,
                  createdAt: Date = Date()) async throws -> LearningEntry {
        let entry = LearningEntry(topicID: topic.id, studyDay: day, body: body, durationMinutes: duration, createdAt: createdAt)
        let snapshot = try await storage.apply(.saveEntry(entry, expectedRevision: nil, nextStep: nil, today: learningToday))
        return snapshot.entries.first { $0.id == entry.id }!
    }

    // MARK: Calendar day

    func testDayParsingIsStrictAndNeverNormalizes() {
        for valid in ["2024-02-29", "2000-02-29", "2026-10-09", "1900-01-01", "9999-12-31"] {
            XCTAssertEqual(LearningDay(string: valid)?.string, valid)
        }
        for invalid in ["2023-02-29", "1900-02-29", "2026-02-30", "2026-04-31", "2026-13-01", "2026-00-10",
                        "2026-10-00", "2026-1-01", "2026-01-1", " 2026-01-01", "2026-01-01 ", "2026/01/01",
                        "２０２６-01-01", "1899-12-31", "10000-01-01", "2026-10-09T00:00", "", "abcd-ef-gh", "+026-01-01"] {
            XCTAssertNil(LearningDay(string: invalid), invalid)
        }
        XCTAssertNil(LearningDay(year: 2026, month: 2, day: 29))
        XCTAssertLessThan(LearningDay(string: "2026-10-09")!, LearningDay(string: "2026-10-10")!)
        XCTAssertLessThan(LearningDay(string: "2025-12-31")!, LearningDay(string: "2026-01-01")!)
    }

    func testStoredDayIsALabelAndTodayFollowsTheGivenZone() throws {
        // 2026-10-09 23:30 in New York is already 2026-10-10 in Tokyo; the saved label must not move.
        let instant = ISO8601DateFormatter().date(from: "2026-10-10T03:30:00Z")!
        let newYork = TimeZone(identifier: "America/New_York")!, tokyo = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertEqual(LearningDay.today(now: instant, timeZone: newYork).string, "2026-10-09")
        XCTAssertEqual(LearningDay.today(now: instant, timeZone: tokyo).string, "2026-10-10")
        let entry = LearningEntry(topicID: UUID(), studyDay: LearningDay(string: "2026-10-09")!, body: "x")
        let data = try JSONEncoder().encode(entry)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"studyDate\":\"2026-10-09\""))
        let decoded = try JSONDecoder().decode(LearningEntry.self, from: data)
        XCTAssertEqual(decoded.studyDay.string, "2026-10-09")
        XCTAssertEqual(LearningDay(date: decoded.studyDay.date(timeZone: tokyo), timeZone: tokyo).string, "2026-10-09")
        let invalid = Data(String(decoding: data, as: UTF8.self).replacingOccurrences(of: "2026-10-09", with: "2026-02-30").utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(LearningEntry.self, from: invalid))
    }

    // MARK: Validation

    func testTopicValidationTrimsOnlyNameAndLinkAndKeepsExactText() throws {
        let topic = LearningTopic(name: "  Swift 并发  ", goal: " \n\t ", nextStep: "  \r\n  ", resourceURL: "  https://Example.com/a  ")
        let valid = try topic.validated()
        XCTAssertEqual(valid.name, "Swift 并发")
        XCTAssertEqual(Data(valid.goal.utf8), Data(" \n\t ".utf8))
        XCTAssertEqual(Data(valid.nextStep.utf8), Data("  \r\n  ".utf8))
        XCTAssertFalse(valid.hasNextStep)
        XCTAssertEqual(valid.resourceURL, "https://Example.com/a")
        XCTAssertTrue(LearningTopic(name: "n", nextStep: " 读第三章 ").hasNextStep)
        XCTAssertThrowsError(try LearningTopic(name: "  \n ").validated())
        XCTAssertThrowsError(try LearningTopic(name: "a\nb").validated())
        XCTAssertThrowsError(try LearningTopic(name: String(repeating: "名", count: 201)).validated())
        XCTAssertNoThrow(try LearningTopic(name: String(repeating: "名", count: 200)).validated())
        XCTAssertThrowsError(try LearningTopic(name: "n", goal: String(repeating: "a", count: 4001)).validated())
        XCTAssertThrowsError(try LearningTopic(name: "n", nextStep: String(repeating: "a", count: 1001)).validated())
        XCTAssertNoThrow(try LearningTopic(name: "n", nextStep: String(repeating: "a", count: 1000)).validated())
    }

    func testResourceLinkAcceptsOnlyHTTPAndHTTPS() throws {
        XCTAssertNil(try LearningTopic(name: "n", resourceURL: "   ").validated().resourceURL)
        XCTAssertEqual(try LearningTopic(name: "n", resourceURL: "http://localhost:8080/x?y=1").validated().resourceURL,
                       "http://localhost:8080/x?y=1")
        for bad in ["ftp://example.com", "file:///etc/passwd", "javascript:alert(1)", "example.com", "http://",
                    "https://exa mple.com", "https://example.com/\nx", "mailto:a@b.c",
                    "https://example.com/" + String(repeating: "a", count: 2100)] {
            XCTAssertThrowsError(try LearningTopic(name: "n", resourceURL: bad).validated(), bad)
        }
    }

    func testEntryValidationBodyDurationAndLimits() throws {
        func entry(_ body: String, _ minutes: Int? = nil) -> LearningEntry {
            LearningEntry(topicID: UUID(), studyDay: learningToday, body: body, durationMinutes: minutes)
        }
        XCTAssertThrowsError(try entry(" \n\t\r\n ").validated())
        let raw = "\t\r\n😀 e\u{301}\n  "
        XCTAssertEqual(Data(try entry(raw).validated().body.utf8), Data(raw.utf8))
        XCTAssertNoThrow(try entry("x", nil).validated())
        XCTAssertNoThrow(try entry("x", 1).validated())
        XCTAssertNoThrow(try entry("x", 1440).validated())
        for bad in [0, -5, 1441] { XCTAssertThrowsError(try entry("x", bad).validated(), "\(bad)") }
        XCTAssertNoThrow(try entry(String(repeating: "a", count: LearningLimits.entryBodyBytes)).validated())
        XCTAssertThrowsError(try entry(String(repeating: "a", count: LearningLimits.entryBodyBytes + 1)).validated())
    }

    func testOldMinimalJSONDecodesWithDefaults() async throws {
        let root = root(), topicID = UUID().uuidString
        let json = """
        {"schemaVersion":1,"topics":[{"id":"\(topicID)","name":"旧主题","createdAt":"2026-01-02T03:04:05Z"}],
         "entries":[{"id":"\(UUID().uuidString)","topicID":"\(topicID)","studyDate":"2026-01-02","body":"旧记录",
         "createdAt":"2026-01-02T03:04:05Z"}]}
        """
        try writeRaw(root, Data(json.utf8))
        let snapshot = try await LearningFileStorage(root: root).load()
        XCTAssertEqual(snapshot.topics[0].status, .planned); XCTAssertEqual(snapshot.topics[0].goal, "")
        XCTAssertEqual(snapshot.topics[0].nextStep, ""); XCTAssertFalse(snapshot.topics[0].isArchived)
        XCTAssertEqual(snapshot.topics[0].revision, 1); XCTAssertNil(snapshot.entries[0].durationMinutes)
        XCTAssertEqual(snapshot.entries[0].revision, 1)
    }

    // MARK: Round trip, backup, exact text

    func testFirstLoadCreatesNothingAndRoundTripKeepsExactText() async throws {
        let root = root(), storage = LearningFileStorage(root: root)
        let empty = try await storage.load()
        XCTAssertEqual(empty, LearningSnapshot()); XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        let goal = " \n目标\r\n\t😀 e\u{301}  ", next = "   \n"
        let topic = try await addTopic(storage, LearningTopic(name: "  Python  ", goal: goal, status: .learning, nextStep: next))
        let raw = try Data(contentsOf: storage.primaryURL)
        XCTAssertEqual(topic.name, "Python"); XCTAssertEqual(Data(topic.goal.utf8), Data(goal.utf8))
        XCTAssertEqual(Data(topic.nextStep.utf8), Data(next.utf8))
        let body = "\t\r\n😀 e\u{301}\n{{x}}  \n"
        let entry = try await addEntry(storage, topic: topic, body: body, duration: 45)
        XCTAssertEqual(try Data(contentsOf: storage.backupURL), raw)
        let reopened = try await LearningFileStorage(root: root).load()
        XCTAssertEqual(Data(reopened.entries[0].body.utf8), Data(body.utf8))
        XCTAssertEqual(reopened.entries[0].durationMinutes, 45)
        XCTAssertEqual(reopened.entries[0].id, entry.id)
        XCTAssertEqual(Data(reopened.topics[0].goal.utf8), Data(goal.utf8))
        XCTAssertEqual(reopened.topics[0].status, .learning)
        let before = try Data(contentsOf: storage.primaryURL)
        _ = try await storage.load()
        XCTAssertEqual(try Data(contentsOf: storage.primaryURL), before)
        let attrs = try FileManager.default.attributesOfItem(atPath: storage.primaryURL.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testSameDayEntriesAreAllowedAndOrderIsStable() async throws {
        let storage = LearningFileStorage(root: root())
        let topic = try await addTopic(storage)
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let first = try await addEntry(storage, topic: topic, body: "上午", createdAt: base)
        let second = try await addEntry(storage, topic: topic, body: "下午", createdAt: base.addingTimeInterval(60))
        let older = try await addEntry(storage, topic: topic, body: "昨天", day: LearningDay(string: "2026-10-08")!,
                                       createdAt: base.addingTimeInterval(120))
        let sorted = [first, older, second].sorted(by: LearningEntry.isNewer).map(\.id)
        XCTAssertEqual(sorted, [second.id, first.id, older.id])
        XCTAssertEqual([second, first].shuffled().sorted(by: LearningEntry.isNewer).map(\.id), [second.id, first.id])
    }

    // MARK: Stale writes and unrelated preservation

    func testStaleTopicAndEntryAreRefusedAndUnrelatedRecordsSurvive() async throws {
        let root = root(), one = LearningFileStorage(root: root), two = LearningFileStorage(root: root)
        let a = try await addTopic(one, LearningTopic(name: "A")), b = try await addTopic(one, LearningTopic(name: "B"))
        let entryB = try await addEntry(one, topic: b, body: "b1")
        var editedA = a; editedA.goal = "A 新目标"
        _ = try await two.apply(.saveTopic(editedA, expectedRevision: 1))
        // The other store still holds A at revision 1 and B's entry at revision 1: B's entry is unrelated.
        var editedEntry = entryB; editedEntry.body = "b2"
        _ = try await one.apply(.saveEntry(editedEntry, expectedRevision: 1, nextStep: nil, today: learningToday))
        var staleA = a; staleA.goal = "stale"
        await assertFailure(.conflict) { _ = try await one.apply(.saveTopic(staleA, expectedRevision: 1)) }
        var staleEntry = entryB; staleEntry.body = "stale body"
        await assertFailure(.conflict) {
            _ = try await two.apply(.saveEntry(staleEntry, expectedRevision: 1, nextStep: nil, today: learningToday))
        }
        let final = try await LearningFileStorage(root: root).load()
        XCTAssertEqual(final.topics.first { $0.id == a.id }?.goal, "A 新目标")
        XCTAssertEqual(final.topics.first { $0.id == a.id }?.revision, 2)
        XCTAssertEqual(final.entries.first?.body, "b2")
        XCTAssertEqual(final.topics.count, 2)
        await assertFailure(.conflict) { _ = try await one.apply(.saveTopic(LearningTopic(name: "dup", revision: 1), expectedRevision: 5)) }
    }

    func testConcurrentWritersToDifferentRecordsBothPersist() async throws {
        let root = root(), one = LearningFileStorage(root: root), two = LearningFileStorage(root: root)
        let a = try await addTopic(one, LearningTopic(name: "A")), b = try await addTopic(one, LearningTopic(name: "B"))
        var ea = a; ea.nextStep = "A next"
        var eb = b; eb.nextStep = "B next"
        async let r1 = one.apply(.saveTopic(ea, expectedRevision: 1))
        async let r2 = two.apply(.saveTopic(eb, expectedRevision: 1))
        _ = try await (r1, r2)
        let final = try await LearningFileStorage(root: root).load()
        XCTAssertEqual(final.topics.first { $0.id == a.id }?.nextStep, "A next")
        XCTAssertEqual(final.topics.first { $0.id == b.id }?.nextStep, "B next")
    }

    // MARK: Archive and topic checks inside the transaction

    func testArchiveKeepsEntriesAndIsReadOnlyUntilRestored() async throws {
        let storage = LearningFileStorage(root: root())
        let topic = try await addTopic(storage, LearningTopic(name: "A", status: .learning))
        let entry = try await addEntry(storage, topic: topic, body: "保留")
        let archived = try await storage.apply(.changeTopic(id: topic.id, expectedRevision: 1, change: .archived(true)))
        XCTAssertTrue(archived.topics[0].isArchived); XCTAssertEqual(archived.topics[0].status, .learning)
        XCTAssertEqual(archived.entries.map(\.id), [entry.id]); XCTAssertEqual(archived.topics[0].revision, 2)
        var edit = archived.topics[0]; edit.goal = "x"
        await assertFailure(.topicArchived) { _ = try await storage.apply(.saveTopic(edit, expectedRevision: 2)) }
        await assertFailure(.topicArchived) {
            _ = try await storage.apply(.changeTopic(id: topic.id, expectedRevision: 2, change: .status(.completed)))
        }
        // A caller that still believes the topic is active (stale copy) cannot add or edit records.
        let late = LearningEntry(topicID: topic.id, studyDay: learningToday, body: "晚到的记录")
        await assertFailure(.topicArchived) {
            _ = try await storage.apply(.saveEntry(late, expectedRevision: nil, nextStep: nil, today: learningToday))
        }
        var editedOld = entry; editedOld.body = "改"
        await assertFailure(.topicArchived) {
            _ = try await storage.apply(.saveEntry(editedOld, expectedRevision: 1, nextStep: nil, today: learningToday))
        }
        await assertFailure(.topicArchived) {
            _ = try await storage.apply(.saveEntry(late, expectedRevision: nil,
                nextStep: LearningNextStepUpdate(expectedTopicRevision: 2, nextStep: "n"), today: learningToday))
        }
        let restored = try await storage.apply(.changeTopic(id: topic.id, expectedRevision: 2, change: .archived(false)))
        XCTAssertFalse(restored.topics[0].isArchived); XCTAssertEqual(restored.entries.count, 1)
        XCTAssertEqual(restored.entries[0].body, "保留"); XCTAssertEqual(restored.topics[0].revision, 3)
        await assertFailure(.conflict) {
            _ = try await storage.apply(.changeTopic(id: topic.id, expectedRevision: 2, change: .archived(true)))
        }
    }

    func testStatusChangeNeverTouchesOtherFieldsAndEntryNeedsAnExistingTopic() async throws {
        let storage = LearningFileStorage(root: root())
        let topic = try await addTopic(storage, LearningTopic(name: "A", goal: " g ", nextStep: " n "))
        let changed = try await storage.apply(.changeTopic(id: topic.id, expectedRevision: 1, change: .status(.completed)))
        XCTAssertEqual(changed.topics[0].status, .completed); XCTAssertEqual(changed.topics[0].goal, " g ")
        XCTAssertEqual(changed.topics[0].nextStep, " n ")
        let orphan = LearningEntry(topicID: UUID(), studyDay: learningToday, body: "x")
        await assertFailure(.topicMissing) {
            _ = try await storage.apply(.saveEntry(orphan, expectedRevision: nil, nextStep: nil, today: learningToday))
        }
        await assertFailure(.topicMissing) {
            _ = try await storage.apply(.changeTopic(id: UUID(), expectedRevision: 1, change: .archived(true)))
        }
        var moved = try await addEntry(storage, topic: topic); moved = LearningEntry(id: moved.id, topicID: UUID(),
            studyDay: moved.studyDay, body: "move")
        await assertFailure(.topicMissing) {
            _ = try await storage.apply(.saveEntry(moved, expectedRevision: 1, nextStep: nil, today: learningToday))
        }
    }

    // MARK: Combined entry + next step

    func testCombinedSaveUpdatesEntryAndNextStepAtomically() async throws {
        let storage = LearningFileStorage(root: root())
        let topic = try await addTopic(storage, LearningTopic(name: "A", nextStep: "旧"))
        let entry = LearningEntry(topicID: topic.id, studyDay: learningToday, body: "今天学了")
        let update = LearningNextStepUpdate(expectedTopicRevision: 1, nextStep: "  新的下一步\n")
        let snapshot = try await storage.apply(.saveEntry(entry, expectedRevision: nil, nextStep: update, today: learningToday))
        XCTAssertEqual(snapshot.entries.count, 1)
        XCTAssertEqual(Data(snapshot.topics[0].nextStep.utf8), Data("  新的下一步\n".utf8))
        XCTAssertEqual(snapshot.topics[0].revision, 2)
        // Unchanged text does not bump the topic, but a matching baseline is still required.
        let second = LearningEntry(topicID: topic.id, studyDay: learningToday, body: "再学一次")
        let same = LearningNextStepUpdate(expectedTopicRevision: 2, nextStep: "  新的下一步\n")
        let again = try await storage.apply(.saveEntry(second, expectedRevision: nil, nextStep: same, today: learningToday))
        XCTAssertEqual(again.topics[0].revision, 2); XCTAssertEqual(again.entries.count, 2)
    }

    func testCombinedSaveWritesNothingWhenEitherBaselineIsStale() async throws {
        let storage = LearningFileStorage(root: root())
        let topic = try await addTopic(storage, LearningTopic(name: "A", nextStep: "旧"))
        let entry = try await addEntry(storage, topic: topic, body: "v1")
        var edited = topic; edited.goal = "别处改了目标"
        _ = try await storage.apply(.saveTopic(edited, expectedRevision: 1))           // topic -> r2
        let before = try await storage.load()
        let fresh = LearningEntry(topicID: topic.id, studyDay: learningToday, body: "新记录")
        await assertFailure(.conflict) {
            _ = try await storage.apply(.saveEntry(fresh, expectedRevision: nil,
                nextStep: LearningNextStepUpdate(expectedTopicRevision: 1, nextStep: "x"), today: learningToday))
        }
        var staleEntry = entry; staleEntry.body = "v2"
        await assertFailure(.conflict) {
            _ = try await storage.apply(.saveEntry(staleEntry, expectedRevision: 7,
                nextStep: LearningNextStepUpdate(expectedTopicRevision: 2, nextStep: "x"), today: learningToday))
        }
        let after = try await storage.load()
        XCTAssertEqual(after, before)
        XCTAssertEqual(after.topics[0].nextStep, "旧")
        // Without a next-step change, a stale topic copy does not block saving the entry itself.
        _ = try await storage.apply(.saveEntry(fresh, expectedRevision: nil, nextStep: nil, today: learningToday))
        let final = try await storage.load()
        XCTAssertEqual(final.entries.count, 2); XCTAssertEqual(final.topics[0].revision, 2)
    }

    func testNextStepLimitInCombinedSaveRejectsWithoutPartialWrite() async throws {
        let storage = LearningFileStorage(root: root())
        let topic = try await addTopic(storage)
        let entry = LearningEntry(topicID: topic.id, studyDay: learningToday, body: "x")
        let tooLong = LearningNextStepUpdate(expectedTopicRevision: 1, nextStep: String(repeating: "a", count: 1001))
        do {
            _ = try await storage.apply(.saveEntry(entry, expectedRevision: nil, nextStep: tooLong, today: learningToday))
            XCTFail("expected failure")
        } catch { XCTAssertTrue(error is LearningError) }
        let snapshot = try await storage.load()
        XCTAssertTrue(snapshot.entries.isEmpty)
    }

    // MARK: Dates

    func testFutureDatesAreRejectedButAnUntouchedOldDateSurvivesATimeZoneShift() async throws {
        let storage = LearningFileStorage(root: root())
        let topic = try await addTopic(storage)
        let tomorrow = LearningDay(string: "2026-10-10")!
        let future = LearningEntry(topicID: topic.id, studyDay: tomorrow, body: "未来")
        await assertFailure(.futureDate) {
            _ = try await storage.apply(.saveEntry(future, expectedRevision: nil, nextStep: nil, today: learningToday))
        }
        // Saved while "today" was 2026-10-10 (e.g. east of here), later edited where today is still 2026-10-09.
        let saved = try await storage.apply(.saveEntry(future, expectedRevision: nil, nextStep: nil, today: tomorrow))
        var bodyOnly = saved.entries[0]; bodyOnly.body = "只改正文"
        let edited = try await storage.apply(.saveEntry(bodyOnly, expectedRevision: 1, nextStep: nil, today: learningToday))
        XCTAssertEqual(edited.entries[0].studyDay, tomorrow); XCTAssertEqual(edited.entries[0].body, "只改正文")
        var moved = edited.entries[0]; moved.studyDay = LearningDay(string: "2026-10-11")!
        await assertFailure(.futureDate) {
            _ = try await storage.apply(.saveEntry(moved, expectedRevision: 2, nextStep: nil, today: learningToday))
        }
        var back = edited.entries[0]; back.studyDay = LearningDay(string: "2026-09-01")!
        let corrected = try await storage.apply(.saveEntry(back, expectedRevision: 2, nextStep: nil, today: learningToday))
        XCTAssertEqual(corrected.entries[0].studyDay.string, "2026-09-01")
    }

    // MARK: Failure protection

    func testPreReplaceFailuresAreRetryableAndLeaveDiskUntouched() async throws {
        let root = root(), failure = LearningStageFailure()
        let storage = LearningFileStorage(root: root, hook: { try failure.check($0) })
        let topic = try await addTopic(storage)
        let before = try Data(contentsOf: storage.primaryURL)
        for stage in [LearningStorageStage.encode, .backup, .backupReadBack, .replace] {
            failure.fail(stage)
            var edit = topic; edit.goal = "改 \(stage)"
            do { _ = try await storage.apply(.saveTopic(edit, expectedRevision: 1)); XCTFail("expected \(stage)") }
            catch let error as LearningError {
                guard case .writeFailed = error else { return XCTFail("\(stage) -> \(error)") }
                XCTAssertFalse(error.locksSaving)
            }
            XCTAssertEqual(try Data(contentsOf: storage.primaryURL), before, "\(stage)")
        }
        failure.fail(nil)
        var edit = topic; edit.goal = "最终"
        let snapshot = try await storage.apply(.saveTopic(edit, expectedRevision: 1))
        XCTAssertEqual(snapshot.topics[0].goal, "最终"); XCTAssertEqual(snapshot.topics[0].revision, 2)
    }

    func testRealWriteFailureBeforeRenameIsRetryableNotUncertain() async throws {
        let root = root(), storage = LearningFileStorage(root: root)
        let topic = try await addTopic(storage)
        let before = try Data(contentsOf: storage.primaryURL)
        XCTAssertEqual(chmod(root.path, 0o500), 0)   // existing files stay writable; new temporary files cannot be created
        var edit = topic; edit.goal = "无法写入"
        do { _ = try await storage.apply(.saveTopic(edit, expectedRevision: 1)); XCTFail("expected failure") }
        catch let error as LearningError {
            guard case .writeFailed = error else { return XCTFail("\(error)") }
            XCTAssertFalse(error.locksSaving)
        }
        XCTAssertEqual(chmod(root.path, 0o700), 0)
        XCTAssertEqual(try Data(contentsOf: storage.primaryURL), before)
        let ok = try await storage.apply(.saveTopic(edit, expectedRevision: 1))
        XCTAssertEqual(ok.topics[0].goal, "无法写入")
    }

    func testReadBackFailureAfterReplaceIsUncertainAndLocksUntilReload() async throws {
        let root = root(), failure = LearningStageFailure()
        let storage = LearningFileStorage(root: root, hook: { try failure.check($0) })
        let store = LearningStore(storage: storage, today: { learningToday })
        await store.reload()
        let topic = LearningTopic(name: "草稿主题")
        let ok = await store.saveTopic(topic, expectedRevision: nil)
        XCTAssertTrue(ok)
        let saved = store.topics[0]
        failure.fail(.readBack)
        var edit = saved; edit.goal = "待确认"
        let uncertain = await store.saveTopic(edit, expectedRevision: saved.revision)
        XCTAssertFalse(uncertain); XCTAssertEqual(store.error, .uncertainWrite)
        XCTAssertEqual(store.topics[0].goal, "", "uncertain state must not be published")
        XCTAssertFalse(store.canSave)
        failure.fail(nil)
        let locked = await store.saveTopic(edit, expectedRevision: saved.revision)
        XCTAssertFalse(locked)
        await store.reload()
        XCTAssertNil(store.error); XCTAssertTrue(store.canSave)
        XCTAssertEqual(store.topics[0].goal, "待确认", "reload shows the real disk state")
    }

    func testStorePublishesOnlyVerifiedStateAndKeepsRetryableFailuresUnlocked() async throws {
        let root = root(), failure = LearningStageFailure()
        let store = LearningStore(storage: LearningFileStorage(root: root, hook: { try failure.check($0) }), today: { learningToday })
        await store.reload()
        _ = await store.saveTopic(LearningTopic(name: "A"), expectedRevision: nil)
        failure.fail(.backup)
        var edit = store.topics[0]; edit.goal = "x"
        let failed = await store.saveTopic(edit, expectedRevision: 1)
        XCTAssertFalse(failed); XCTAssertEqual(store.topics[0].goal, "")
        guard case .writeFailed = store.error else { return XCTFail("\(String(describing: store.error))") }
        XCTAssertTrue(store.canSave)
        failure.fail(nil)
        let retried = await store.saveTopic(edit, expectedRevision: 1)
        XCTAssertTrue(retried); XCTAssertNil(store.error); XCTAssertEqual(store.topics[0].goal, "x")
    }

    // MARK: Corruption and unsafe storage

    func testCorruptAndUnsupportedFilesBlockSavingAndAreNeverOverwritten() async throws {
        let id = UUID().uuidString
        let topicJSON = "{\"id\":\"\(id)\",\"name\":\"T\",\"createdAt\":\"2026-01-02T03:04:05Z\"}"
        let cases: [(String, Data, LearningError)] = [
            ("garbage", Data("not json".utf8), .corruptData),
            ("invalid utf8", Data([0xFF, 0xFE, 0x7B, 0x7D]), .corruptData),
            ("nul", Data("{\u{0}}".utf8), .corruptData),
            ("future schema", Data("{\"schemaVersion\":2,\"topics\":[],\"entries\":[]}".utf8), .unsupportedSchema),
            ("duplicate", Data("{\"schemaVersion\":1,\"topics\":[\(topicJSON),\(topicJSON)],\"entries\":[]}".utf8), .duplicateIdentity),
            ("orphan", Data("{\"schemaVersion\":1,\"topics\":[\(topicJSON)],\"entries\":[{\"id\":\"\(UUID().uuidString)\",\"topicID\":\"\(UUID().uuidString)\",\"studyDate\":\"2026-01-02\",\"body\":\"b\",\"createdAt\":\"2026-01-02T03:04:05Z\"}]}".utf8), .orphanRecord),
            ("impossible day", Data("{\"schemaVersion\":1,\"topics\":[\(topicJSON)],\"entries\":[{\"id\":\"\(UUID().uuidString)\",\"topicID\":\"\(id)\",\"studyDate\":\"2026-02-30\",\"body\":\"b\",\"createdAt\":\"2026-01-02T03:04:05Z\"}]}".utf8), .corruptData),
            ("unknown status", Data("{\"schemaVersion\":1,\"topics\":[{\"id\":\"\(id)\",\"name\":\"T\",\"status\":\"paused\",\"createdAt\":\"2026-01-02T03:04:05Z\"}],\"entries\":[]}".utf8), .corruptData),
            ("blank body", Data("{\"schemaVersion\":1,\"topics\":[\(topicJSON)],\"entries\":[{\"id\":\"\(UUID().uuidString)\",\"topicID\":\"\(id)\",\"studyDate\":\"2026-01-02\",\"body\":\"  \",\"createdAt\":\"2026-01-02T03:04:05Z\"}]}".utf8), .corruptData),
        ]
        for (label, data, expected) in cases {
            let root = root(), storage = LearningFileStorage(root: root)
            try writeRaw(root, data)
            await assertFailure(expected, { _ = try await storage.load() })
            await assertFailure(expected, { _ = try await storage.apply(.saveTopic(LearningTopic(name: "新"), expectedRevision: nil)) })
            XCTAssertEqual(try Data(contentsOf: storage.primaryURL), data, label)
            XCTAssertFalse(FileManager.default.fileExists(atPath: storage.backupURL.path), label)
            let store = LearningStore(storage: storage, today: { learningToday })
            await store.reload()
            XCTAssertFalse(store.canSave, label); XCTAssertTrue(store.topics.isEmpty, label)
        }
    }

    func testMissingPrimaryWithBackupIsNotInitializedOrRestored() async throws {
        let root = root(), storage = LearningFileStorage(root: root)
        let backup = Data("{\"schemaVersion\":1,\"topics\":[],\"entries\":[]}".utf8)
        try writeRaw(root, backup, name: "learning.backup.json")
        await assertFailure(.missingPrimaryWithBackup) { _ = try await storage.load() }
        await assertFailure(.missingPrimaryWithBackup) {
            _ = try await storage.apply(.saveTopic(LearningTopic(name: "x"), expectedRevision: nil))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.primaryURL.path))
        XCTAssertEqual(try Data(contentsOf: storage.backupURL), backup)
    }

    func testSymbolicLinksAndWrongFileTypesAreRefused() async throws {
        let root = root(), storage = LearningFileStorage(root: root)
        let outside = root.deletingLastPathComponent().appendingPathComponent("CosmosLearningPhase1-" + UUID().uuidString)
        roots.append(outside)
        try Data("{}".utf8).write(to: outside)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: storage.primaryURL, withDestinationURL: outside)
        await assertFailure(.unsafePath) { _ = try await storage.load() }
        await assertFailure(.unsafePath) { _ = try await storage.apply(.saveTopic(LearningTopic(name: "x"), expectedRevision: nil)) }
        XCTAssertEqual(try Data(contentsOf: outside), Data("{}".utf8))
        try FileManager.default.removeItem(at: storage.primaryURL)
        try FileManager.default.createDirectory(at: storage.primaryURL, withIntermediateDirectories: false)
        await assertFailure(.unsafePath) { _ = try await storage.load() }
        try FileManager.default.removeItem(at: storage.primaryURL)
        try FileManager.default.createDirectory(at: storage.backupURL, withIntermediateDirectories: false)
        await assertFailure(.unsafePath) { _ = try await storage.load() }
        // A symbolic link anywhere in the root path is refused too.
        let linkRoot = root.deletingLastPathComponent().appendingPathComponent("CosmosLearningPhase1-" + UUID().uuidString)
        roots.append(linkRoot)
        try FileManager.default.createSymbolicLink(at: linkRoot, withDestinationURL: root)
        await assertFailure(.unsafePath) { _ = try await LearningFileStorage(root: linkRoot).load() }
    }

    func testOversizedLibraryIsRejectedNotTruncated() async throws {
        let root = root(), storage = LearningFileStorage(root: root)
        try writeRaw(root, Data(repeating: 0x61, count: LearningLimits.documentBytes + 1))
        do { _ = try await storage.load(); XCTFail("expected failure") }
        catch let error as LearningError { guard case .storage = error else { return XCTFail("\(error)") } }
        XCTAssertEqual(try Data(contentsOf: storage.primaryURL).count, LearningLimits.documentBytes + 1)
    }

    func testSaveThatWouldExceedTheDocumentLimitIsRefusedWithoutChangingTheFile() async throws {
        let root = root(), storage = LearningFileStorage(root: root)
        let topic = LearningTopic(name: "大")
        let body = String(repeating: "a", count: LearningLimits.entryBodyBytes)
        let entries = (0..<15).map { _ in LearningEntry(topicID: topic.id, studyDay: learningToday, body: body) }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let document = LearningDocument(schemaVersion: 1, topics: [topic], entries: entries)
        let data = try encoder.encode(document)
        XCTAssertLessThan(data.count, LearningLimits.documentBytes)
        try writeRaw(root, data)
        let loaded = try await storage.load()
        XCTAssertEqual(loaded.entries.count, 15)
        let extra = LearningEntry(topicID: topic.id, studyDay: learningToday, body: body)
        do {
            _ = try await storage.apply(.saveEntry(extra, expectedRevision: nil, nextStep: nil, today: learningToday))
            XCTFail("expected rejection")
        } catch { XCTAssertTrue(error is LearningError) }
        XCTAssertEqual(try Data(contentsOf: storage.primaryURL), data)
    }

    // MARK: Isolation

    func testDebugLocationFailsClosed() {
        let bundle = "com.wangyucosmos.cosmostoolbox.persistenceui.learningtests"
        let root = "/private/tmp/CosmosLearningPhase1-" + UUID().uuidString
        let flag = LearningLocation.fixtureFlag
        XCTAssertNil(LearningLocation.resolve(isIsolated: true, bundleIdentifier: bundle, arguments: []).root)
        XCTAssertNil(LearningLocation.resolve(isIsolated: true, bundleIdentifier: "com.wangyucosmos.Cosmos-Toolbox", arguments: [flag, root]).root)
        XCTAssertNil(LearningLocation.resolve(isIsolated: false, bundleIdentifier: bundle, arguments: [flag, root]).root)
        XCTAssertNil(LearningLocation.resolve(isIsolated: true, bundleIdentifier: bundle, arguments: [flag, "/tmp/unapproved"]).root)
        XCTAssertNil(LearningLocation.resolve(isIsolated: true, bundleIdentifier: bundle, arguments: [flag, root + "/../x"]).root)
        XCTAssertNil(LearningLocation.resolve(isIsolated: true, bundleIdentifier: bundle, arguments: [flag, "/private/tmp/CosmosLearningPhase1-notauuid"]).root)
        XCTAssertNil(LearningLocation.resolve(isIsolated: true, bundleIdentifier: bundle, arguments: [flag]).root)
        XCTAssertEqual(LearningLocation.resolve(isIsolated: true, bundleIdentifier: bundle, arguments: [flag, root]).root?.path, root)
        // Blocked locations never become a store with a production directory.
        let blocked = LearningLocation.resolve(isIsolated: true, bundleIdentifier: bundle, arguments: [])
        XCTAssertNotNil(blocked.error)
        XCTAssertEqual(LearningStore(root: blocked.root, startupError: blocked.error).storageIdentity, "blocked")
    }

    func testTestsRunInTemporaryHostAndNeverTouchExistingBusinessKeys() async throws {
        XCTAssertTrue(Bundle.main.bundleIdentifier?.hasPrefix("com.wangyucosmos.cosmostoolbox.persistenceui.") == true)
        let production = try LearningFileStorage.productionRoot()
        XCTAssertTrue(production.path.hasSuffix("Cosmos OS/Learning"))
        let defaults = UserDefaults.standard, key = "cosmos.zhuowang.campaigns.v1"
        let original = defaults.object(forKey: key)
        defer { if let original { defaults.set(original, forKey: key) } else { defaults.removeObject(forKey: key) } }
        defaults.set(Data("sentinel".utf8), forKey: key)
        let snapshot = { defaults.dictionaryRepresentation().filter { $0.key.hasPrefix("cosmos.zhuowang.") }.compactMapValues { $0 as? Data } }
        let before = snapshot()
        let root = root(), storage = LearningFileStorage(root: root)
        XCTAssertNotEqual(storage.root.path, production.path)
        let topic = try await addTopic(storage)
        try await addEntry(storage, topic: topic)
        XCTAssertEqual(snapshot(), before)
        XCTAssertTrue(storage.root.path.hasPrefix("/private/tmp/CosmosLearningPhase1-"))
    }
}
