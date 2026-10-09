import XCTest
import Foundation
import SwiftUI
import AppKit
@testable import Cosmos_Toolbox

/// 全国月度会员促活 Phase 1: project type + monthly checklist. Synthetic metadata,
/// virtual locations and in-memory data sources only; no file is read or written.
@MainActor
final class ZhuowangMonthlyPromotionTests: XCTestCase {

    // MARK: Helpers

    func makeSource(_ extra: [String: Data] = [:]) -> ZhuowangInMemoryPersistenceDataSource {
        ZhuowangInMemoryPersistenceDataSource(storage: extra)
    }

    func makeStore(_ source: ZhuowangInMemoryPersistenceDataSource) -> ZhuowangCampaignStore {
        ZhuowangCampaignStore(persistenceConfiguration: isolatedConfiguration(dataSource: source))
    }

    let start = Date(timeIntervalSince1970: 1_790_000_000)
    var end: Date { start.addingTimeInterval(30 * 86_400) }

    @discardableResult
    func addMonthly(_ store: ZhuowangCampaignStore, _ name: String, month: String,
                    reference: UUID? = nil, created: Date? = nil) -> ZhuowangCampaign {
        let result = store.addCampaign(name: name, scopeType: .national, moduleID: "national",
            startDate: start, endDate: end, monthlyMonth: month, referenceCampaignID: reference)
        XCTAssertEqual(result, .succeeded, name)
        return store.campaigns.first { $0.name == name }!
    }

    @discardableResult
    func update(_ store: ZhuowangCampaignStore, _ campaign: ZhuowangCampaign,
                _ mutation: ZhuowangMonthlyMutation) -> ZhuowangMonthlyMutationResult {
        let revision = store.campaign(id: campaign.id)?.monthly?.revision ?? 0
        return store.updateMonthlyPlan(campaignID: campaign.id, expectedRevision: revision, mutation)
    }

    func plan(_ store: ZhuowangCampaignStore, _ campaign: ZhuowangCampaign) -> ZhuowangMonthlyPlan {
        store.campaign(id: campaign.id)!.monthly!
    }

    let idea = "monthly.output.idea"
    let rules = "monthly.output.mainPageRules"

    @discardableResult
    func register(_ store: ZhuowangCampaignStore, _ campaign: ZhuowangCampaign, key: String? = nil,
                  location: String = "/virtual/final.docx", label: String = "V1", note: String = "") -> (ZhuowangMonthlyMutationResult, UUID) {
        let id = UUID()
        let result = update(store, campaign, .addRegistration(outputKey: key ?? idea, id: id, location: location,
            versionLabel: label, note: note, at: Date()))
        return (result, id)
    }

    func shanghaiParts(_ date: Date) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    // MARK: Definition

    func testDefinitionHasSevenOutputsSevenInputsAndStableIdentities() {
        XCTAssertEqual(ZhuowangMonthlyDefinition.outputs.count, 7)
        XCTAssertEqual(ZhuowangMonthlyDefinition.inputs.count, 7)
        XCTAssertEqual(Set(ZhuowangMonthlyDefinition.outputs.map(\.key)).count, 7)
        XCTAssertEqual(Set(ZhuowangMonthlyDefinition.inputs.map(\.key)).count, 7)
        XCTAssertTrue((ZhuowangMonthlyDefinition.outputs.map(\.key) + ZhuowangMonthlyDefinition.inputs.map(\.key))
            .allSatisfy { $0.hasPrefix("monthly.") })
        XCTAssertEqual(ZhuowangMonthlyDefinition.outputs.map(\.title),
            ["思路与文案方案", "主活动页原型", "掌厅引导页文案", "动效稿", "客服文档", "掌厅活动规则", "主活动页活动规则"])
        XCTAssertEqual(ZhuowangMonthlyDefinition.outputs.map(\.suggestedOffsetDays), [-21, -10, -7, -6, -8, -7, -2])
        let standard: Set<ZhuowangWorkflowStepKind> = [.brief, .idea, .plan, .pageStructure, .prototype, .customerService]
        XCTAssertTrue(ZhuowangMonthlyDefinition.outputs.allSatisfy { standard.contains($0.stepKind) })
        XCTAssertEqual(ZhuowangMonthlyDefinition.inputs.filter { $0.kind == .prizePoolRelation }.map(\.key),
                       [ZhuowangMonthlyPlan.prizePoolKey])
        XCTAssertTrue(ZhuowangMonthlyDefinition.suggestedDatesNote.contains("初版约定"))
        XCTAssertTrue(ZhuowangMonthlyDefinition.suggestedDatesNote.contains("不是截止日期"))
        XCTAssertTrue(ZhuowangMonthlyDefinition.suggestedDatesNote.contains("不会提醒"))
    }

    // MARK: Month and dates

    func testActivityMonthIsStrictYYYYMM() {
        for valid in ["2026-11", "2026-01", "2026-12", "1900-01", "9999-12"] {
            XCTAssertEqual(ZhuowangActivityMonth(string: valid)?.string, valid)
        }
        for invalid in ["2026-13", "2026-00", "2026-1", "26-11", "2026/11", "2026-11-01", " 2026-11", "2026-11 ", "２０２６-11", "", "abcd-ef", "1899-12", "10000-01"] {
            XCTAssertNil(ZhuowangActivityMonth(string: invalid), invalid)
        }
        XCTAssertEqual(ZhuowangActivityMonth(string: "2026-01")?.previous?.string, "2025-12")
        XCTAssertEqual(ZhuowangActivityMonth(string: "2026-11")?.previous?.string, "2026-10")
        XCTAssertNil(ZhuowangActivityMonth(string: "1900-01")?.previous)
        XCTAssertLessThan(ZhuowangActivityMonth(string: "2025-12")!, ZhuowangActivityMonth(string: "2026-01")!)
    }

    func testDefaultPeriodIsPreviousMonthEnd17ToMonthEnd17InShanghai() throws {
        let november = try XCTUnwrap(ZhuowangMonthlyRules.defaultPeriod(for: ZhuowangActivityMonth(string: "2026-11")!))
        XCTAssertEqual(shanghaiParts(november.start), DateComponents(year: 2026, month: 10, day: 31, hour: 17, minute: 0))
        XCTAssertEqual(shanghaiParts(november.end), DateComponents(year: 2026, month: 11, day: 30, hour: 17, minute: 0))
        let october = try XCTUnwrap(ZhuowangMonthlyRules.defaultPeriod(for: ZhuowangActivityMonth(string: "2026-10")!))
        XCTAssertEqual(shanghaiParts(october.start), DateComponents(year: 2026, month: 9, day: 30, hour: 17, minute: 0))
        let leap = try XCTUnwrap(ZhuowangMonthlyRules.defaultPeriod(for: ZhuowangActivityMonth(string: "2028-02")!))
        XCTAssertEqual(shanghaiParts(leap.end), DateComponents(year: 2028, month: 2, day: 29, hour: 17, minute: 0))
        XCTAssertEqual(shanghaiParts(leap.start), DateComponents(year: 2028, month: 1, day: 31, hour: 17, minute: 0))
        let january = try XCTUnwrap(ZhuowangMonthlyRules.defaultPeriod(for: ZhuowangActivityMonth(string: "2027-01")!))
        XCTAssertEqual(shanghaiParts(january.start), DateComponents(year: 2026, month: 12, day: 31, hour: 17, minute: 0))
        XCTAssertNil(ZhuowangMonthlyRules.defaultPeriod(for: ZhuowangActivityMonth(string: "1900-01")!))
    }

    func testChangingTheMonthNeverOverwritesHandEditedDates() throws {
        let edited = (start: start, end: end)
        let untouched = ZhuowangMonthlyRules.datesAfterMonthChange(current: edited, newMonth: "2026-12", userEditedDates: true)
        XCTAssertEqual(untouched.start, edited.start); XCTAssertEqual(untouched.end, edited.end)
        let followed = ZhuowangMonthlyRules.datesAfterMonthChange(current: edited, newMonth: "2026-12", userEditedDates: false)
        XCTAssertEqual(shanghaiParts(followed.start), DateComponents(year: 2026, month: 11, day: 30, hour: 17, minute: 0))
        let invalid = ZhuowangMonthlyRules.datesAfterMonthChange(current: edited, newMonth: "2026-13", userEditedDates: false)
        XCTAssertEqual(invalid.start, edited.start)
    }

    func testSuggestedDaysAreReferenceDaysRelativeToTheStartCalendarDay() throws {
        let november = try XCTUnwrap(ZhuowangMonthlyRules.defaultPeriod(for: ZhuowangActivityMonth(string: "2026-11")!))
        let day = try XCTUnwrap(ZhuowangMonthlyRules.suggestedDay(start: november.start, offsetDays: -21))
        XCTAssertEqual(shanghaiParts(day), DateComponents(year: 2026, month: 10, day: 10, hour: 0, minute: 0))
        let t = try XCTUnwrap(ZhuowangMonthlyRules.suggestedDay(start: november.start, offsetDays: 0))
        XCTAssertEqual(shanghaiParts(t).day, 31)
    }

    // MARK: Old data and ordinary Campaigns

    func testOldCampaignDataDecodesWithoutMonthlyAndLoadingWritesNothing() throws {
        let id = UUID().uuidString
        let raw = Data("""
        [{"updatedAt":0,"id":"\(id)","name":"旧活动","englishName":"","scopeType":"national","moduleID":"national",
          "startDate":0,"endDate":86400,"status":"planning","notes":"","createdAt":0}]
        """.utf8)
        let source = makeSource([ZhuowangCampaignStore.storageKey: raw])
        let store = makeStore(source)
        XCTAssertEqual(store.persistenceState, .healthy)
        XCTAssertEqual(store.campaigns.count, 1)
        XCTAssertNil(store.campaigns[0].monthly); XCTAssertFalse(store.campaigns[0].isMonthlyMemberActivation)
        XCTAssertEqual(source.writeCount, 0)
        XCTAssertEqual(source.storage[ZhuowangCampaignStore.storageKey], raw)
    }

    func testOrdinaryCampaignsNeverGainMonthlyFieldsAndStayUnaffected() throws {
        let source = makeSource(); let store = makeStore(source)
        XCTAssertEqual(store.addCampaign(name: "普通全国活动", scopeType: .national, moduleID: "national",
            startDate: start, endDate: end), .succeeded)
        let ordinary = try XCTUnwrap(store.campaigns.first)
        XCTAssertNil(ordinary.monthly)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(ordinary), as: UTF8.self).contains("monthly"))
        let monthly = addMonthly(store, "十一月促活", month: "2026-11")
        XCTAssertEqual(store.campaigns.first { $0.id == ordinary.id }, ordinary, "adding a monthly Campaign leaves others untouched")
        let result = update(store, ordinary, .setPrizePool(relation: .shared, note: ""))
        XCTAssertEqual(result, .violation(.notMonthlyCampaign))
        XCTAssertEqual(store.updateMonthlyPlan(campaignID: UUID(), expectedRevision: 1, .setPrizePool(relation: .shared, note: "")),
                       .violation(.campaignNotFound))
        XCTAssertNotNil(monthly.monthly)
    }

    // MARK: Creation

    func testCreatingAMonthlyCampaignStartsBlankAndNationalAndCreatesNoWorkflow() throws {
        let source = makeSource(); let store = makeStore(source)
        let campaign = addMonthly(store, "十一月促活", month: "2026-11")
        let plan = try XCTUnwrap(campaign.monthly)
        XCTAssertEqual(campaign.scopeType, .national); XCTAssertNil(campaign.provinceID); XCTAssertEqual(campaign.moduleID, "national")
        XCTAssertEqual(plan.activityMonth, "2026-11"); XCTAssertEqual(plan.revision, 1)
        XCTAssertTrue(plan.outputs.isEmpty); XCTAssertTrue(plan.inputs.isEmpty)
        XCTAssertEqual(plan.prizePoolRelation, .pending); XCTAssertEqual(plan.prizePoolNote, "")
        XCTAssertNil(plan.referenceCampaignID)
        XCTAssertNil(source.storage[ZhuowangWorkflowStore.workflowStorageKey], "creation writes no Workflow")
        XCTAssertEqual(ZhuowangMonthlyRules.confirmedOutputCount(plan), 0)
        XCTAssertEqual(ZhuowangMonthlyRules.settledInputCount(plan), 0)
        XCTAssertTrue(store.campaigns(forProvinceID: UUID()).isEmpty)
    }

    func testCreationRefusesInvalidMonthScopeDatesAndReferences() throws {
        let store = makeStore(makeSource())
        let october = addMonthly(store, "十月", month: "2026-10")
        let ordinaryResult = store.addCampaign(name: "普通", scopeType: .national, moduleID: "national", startDate: start, endDate: end)
        XCTAssertEqual(ordinaryResult, .succeeded)
        let ordinary = try XCTUnwrap(store.campaigns.first { $0.name == "普通" })
        let before = store.campaigns
        func attempt(_ name: String, scope: ZhuowangCampaignScopeType = .national, month: String, reference: UUID? = nil,
                     end: Date? = nil) -> ZhuowangStoreMutationResult {
            store.addCampaign(name: name, scopeType: scope, moduleID: "national", startDate: start, endDate: end ?? self.end,
                monthlyMonth: month, referenceCampaignID: reference)
        }
        XCTAssertEqual(attempt("坏月份", month: "2026-13"), .rejected(.invalidInput))
        XCTAssertEqual(attempt("省份范围", scope: .province, month: "2026-11"), .rejected(.invalidInput))
        XCTAssertEqual(attempt("日期倒置", month: "2026-11", end: start.addingTimeInterval(-60)), .rejected(.invalidInput))
        XCTAssertEqual(attempt("参考缺失", month: "2026-11", reference: UUID()), .rejected(.invalidInput))
        XCTAssertEqual(attempt("参考非月度", month: "2026-11", reference: ordinary.id), .rejected(.invalidInput))
        XCTAssertEqual(attempt("参考同月", month: "2026-10", reference: october.id), .rejected(.invalidInput))
        XCTAssertEqual(attempt("参考未来", month: "2026-09", reference: october.id), .rejected(.invalidInput))
        XCTAssertEqual(store.campaigns, before, "nothing was written by refused creations")
        XCTAssertEqual(attempt("合法", month: "2026-11", reference: october.id), .succeeded)
    }

    func testNewMonthCopiesNothingFromTheReferenceAndKeepsOnlyItsIdentity() throws {
        let source = makeSource(); let store = makeStore(source)
        let october = addMonthly(store, "十月促活", month: "2026-10")
        let (registered, registrationID) = register(store, october, location: "https://example.com/oct-doc", label: "V1.1", note: "上期备注")
        XCTAssertEqual(registered, .succeeded)
        XCTAssertEqual(update(store, october, .confirmRegistration(outputKey: idea, registrationID: registrationID)), .succeeded)
        XCTAssertEqual(update(store, october, .setInput(key: "monthly.input.prizeTable", status: .received, note: "已收到")), .succeeded)
        XCTAssertEqual(update(store, october, .setPrizePool(relation: .shared, note: "与主页共用")), .succeeded)
        let november = addMonthly(store, "十一月促活", month: "2026-11", reference: october.id)
        let plan = try XCTUnwrap(november.monthly)
        XCTAssertEqual(plan.referenceCampaignID, october.id)
        XCTAssertTrue(plan.outputs.isEmpty); XCTAssertTrue(plan.inputs.isEmpty)
        XCTAssertEqual(plan.prizePoolRelation, .pending, "the prize-pool relation is re-decided every month")
        XCTAssertEqual(plan.prizePoolNote, "")
        XCTAssertEqual(ZhuowangMonthlyRules.confirmedOutputCount(plan), 0)
        XCTAssertEqual(ZhuowangMonthlyRules.settledInputCount(plan), 0)
        // The reference is live: later changes of the previous period show up, but never count for this one.
        XCTAssertEqual(update(store, october, .addRegistration(outputKey: idea, id: UUID(), location: "/virtual/oct-v2.md",
            versionLabel: "V2", note: "", at: Date())), .succeeded)
        let live = store.campaign(id: october.id)?.monthly?.output(idea)?.current
        XCTAssertEqual(live?.location, "/virtual/oct-v2.md")
        XCTAssertEqual(ZhuowangMonthlyRules.confirmedOutputCount(try XCTUnwrap(store.campaign(id: november.id)?.monthly)), 0)
        XCTAssertNil(source.storage[ZhuowangWorkflowStore.workflowStorageKey])
    }

    func testDefaultReferenceCandidateIsTheLatestEarlierMonthlyCampaign() throws {
        let store = makeStore(makeSource())
        _ = store.addCampaign(name: "普通", scopeType: .national, moduleID: "national", startDate: start, endDate: end)
        let september = addMonthly(store, "九月", month: "2026-09")
        let october = addMonthly(store, "十月", month: "2026-10")
        let november = addMonthly(store, "十一月", month: "2026-11")
        let campaigns = store.campaigns
        XCTAssertEqual(ZhuowangMonthlyRules.defaultReferenceCandidate(forMonth: "2026-11", in: campaigns)?.id, october.id)
        XCTAssertEqual(ZhuowangMonthlyRules.defaultReferenceCandidate(forMonth: "2026-11", excluding: november.id, in: campaigns)?.id, october.id)
        XCTAssertEqual(ZhuowangMonthlyRules.defaultReferenceCandidate(forMonth: "2026-10", in: campaigns)?.id, september.id)
        XCTAssertNil(ZhuowangMonthlyRules.defaultReferenceCandidate(forMonth: "2026-09", in: campaigns), "never the same or a later month")
        XCTAssertNil(ZhuowangMonthlyRules.defaultReferenceCandidate(forMonth: "bad", in: campaigns))
        XCTAssertEqual(ZhuowangMonthlyRules.defaultReferenceCandidate(forMonth: "2026-12", in: campaigns)?.id, november.id)
        // Same-month duplicates: both are earlier than the next month; the newer one is chosen.
        let duplicate = addMonthly(store, "十月返工", month: "2026-10")
        XCTAssertEqual(ZhuowangMonthlyRules.defaultReferenceCandidate(forMonth: "2026-11", excluding: november.id, in: store.campaigns)?.id,
                       store.campaigns.filter { $0.monthly?.activityMonth == "2026-10" }.max { $0.createdAt < $1.createdAt }?.id)
        XCTAssertEqual(ZhuowangMonthlyRules.campaignsWithMonth("2026-10", in: store.campaigns).count, 2, "duplicates are only reported")
        XCTAssertEqual(ZhuowangMonthlyRules.campaignsWithMonth("2026-10", excluding: duplicate.id, in: store.campaigns).count, 1)
    }

    // MARK: Reference handling

    func testReferenceChangesAreValidatedAndNeverReplacedAutomatically() throws {
        let store = makeStore(makeSource())
        let october = addMonthly(store, "十月", month: "2026-10")
        let november = addMonthly(store, "十一月", month: "2026-11")
        let december = addMonthly(store, "十二月", month: "2026-12")
        let ordinaryResult = store.addCampaign(name: "普通", scopeType: .national, moduleID: "national", startDate: start, endDate: end)
        XCTAssertEqual(ordinaryResult, .succeeded)
        let ordinary = try XCTUnwrap(store.campaigns.first { $0.name == "普通" })
        XCTAssertEqual(update(store, november, .setReference(october.id)), .succeeded)
        XCTAssertEqual(update(store, november, .setReference(december.id)), .violation(.referenceNotEarlier))
        XCTAssertEqual(update(store, november, .setReference(november.id)), .violation(.referenceNotEarlier))
        XCTAssertEqual(update(store, november, .setReference(ordinary.id)), .violation(.referenceNotMonthly))
        XCTAssertEqual(update(store, november, .setReference(UUID())), .violation(.referenceNotFound))
        XCTAssertEqual(plan(store, november).referenceCampaignID, october.id, "a refused change keeps the old reference")
        XCTAssertEqual(update(store, november, .setActivityMonth("2026-10")), .violation(.referenceNotEarlier))
        XCTAssertEqual(update(store, november, .setActivityMonth("2026-1")), .violation(.invalidMonth))
        XCTAssertEqual(update(store, november, .setReference(nil)), .succeeded)
        XCTAssertNil(plan(store, november).referenceCampaignID)
        // A deleted reference is reported, not silently swapped for another Campaign.
        XCTAssertEqual(update(store, november, .setReference(october.id)), .succeeded)
        XCTAssertEqual(ZhuowangMonthlyRules.referenceState(of: plan(store, november), in: store.campaigns), .resolved(october.id))
        XCTAssertEqual(store.deleteCampaign(id: october.id), .succeeded)
        XCTAssertEqual(ZhuowangMonthlyRules.referenceState(of: plan(store, november), in: store.campaigns), .missing)
        XCTAssertEqual(plan(store, november).referenceCampaignID, october.id)
        var notMonthly = plan(store, november); notMonthly.referenceCampaignID = ordinary.id
        XCTAssertEqual(ZhuowangMonthlyRules.referenceState(of: notMonthly, in: store.campaigns), .notMonthly)
        XCTAssertEqual(ZhuowangMonthlyRules.referenceState(of: ZhuowangMonthlyPlan(activityMonth: "2026-11"), in: store.campaigns), .none)
    }

    // MARK: Registrations

    func testLocationsMustBeExplicitAbsolutePathsOrHttpLinksAndAreNeverOpened() throws {
        for good in ["/virtual/月度/客服文档 V1.1.docx", "https://example.com/a?b=1", "HTTP://Example.com/x", "  /virtual/a  "] {
            guard case .success = ZhuowangMonthlyRules.normalizedLocation(good) else { return XCTFail(good) }
        }
        guard case .success(let trimmed) = ZhuowangMonthlyRules.normalizedLocation("  /virtual/a  ") else { return XCTFail() }
        XCTAssertEqual(trimmed.location, "/virtual/a"); XCTAssertEqual(trimmed.kind, .localPath)
        guard case .success(let link) = ZhuowangMonthlyRules.normalizedLocation("https://example.com") else { return XCTFail() }
        XCTAssertEqual(link.kind, .link)
        guard case .failure(let blank) = ZhuowangMonthlyRules.normalizedLocation("   \n ") else { return XCTFail("blank accepted") }
        XCTAssertEqual(blank, .emptyLocation)
        for bad in ["a/b", "./a", "~/a", "file:///virtual/a", "ftp://example.com/a", "mailto:a@b.c", "javascript:alert(1)",
                    "http://", "https://exa mple.com", "/", "//server/share", "/a/../b", "/..", "/a\nb", "/a\u{0}b", "C:\\x",
                    "/" + String(repeating: "a", count: 2100)] {
            guard case .failure = ZhuowangMonthlyRules.normalizedLocation(bad) else { return XCTFail("accepted: \(bad)") }
        }
    }

    func testRegistrationsAppendKeepHistoryAndTheNewestBecomesCurrentWithoutConfirming() throws {
        let store = makeStore(makeSource()); let campaign = addMonthly(store, "月", month: "2026-11")
        XCTAssertNil(plan(store, campaign).output(idea), "no record is created until something is registered")
        let note = "  \n原文\t备注 😀 e\u{301}  \n"
        let (first, firstID) = register(store, campaign, location: " /virtual/v1.docx ", label: "  V1  ", note: note)
        XCTAssertEqual(first, .succeeded)
        var record = try XCTUnwrap(plan(store, campaign).output(idea))
        XCTAssertEqual(record.registrations.count, 1); XCTAssertEqual(record.currentRegistrationID, firstID)
        XCTAssertEqual(record.registrations[0].location, "/virtual/v1.docx"); XCTAssertEqual(record.registrations[0].versionLabel, "V1")
        XCTAssertEqual(Data(record.registrations[0].note.utf8), Data(note.utf8), "note kept exactly")
        XCTAssertFalse(record.isConfirmed); XCTAssertNil(record.confirmedRegistrationID)
        let (second, secondID) = register(store, campaign, location: "https://example.com/v2", label: "V1")   // same label, different identity
        XCTAssertEqual(second, .succeeded)
        record = try XCTUnwrap(plan(store, campaign).output(idea))
        XCTAssertEqual(record.registrations.map(\.id), [firstID, secondID], "history is append-only")
        XCTAssertEqual(record.currentRegistrationID, secondID)
        XCTAssertNotEqual(firstID, secondID)
        XCTAssertEqual(record.registrations[0].location, "/virtual/v1.docx", "older entries are not rewritten")
        // Refused registrations change nothing.
        let before = plan(store, campaign)
        XCTAssertEqual(register(store, campaign, location: "  ").0, .violation(.emptyLocation))
        XCTAssertEqual(register(store, campaign, location: "relative/path").0, .violation(.invalidLocation))
        XCTAssertEqual(register(store, campaign, label: String(repeating: "v", count: 61)).0, .violation(.tooLong))
        XCTAssertEqual(register(store, campaign, note: String(repeating: "n", count: 4001)).0, .violation(.tooLong))
        XCTAssertEqual(register(store, campaign, key: "monthly.output.unknown").0, .violation(.unknownItem))
        XCTAssertEqual(plan(store, campaign), before)
        // Another output is independent.
        XCTAssertNil(plan(store, campaign).output(rules))
    }

    func testConfirmationBelongsToOneRegistrationAndNeedsACurrentRecord() throws {
        let store = makeStore(makeSource()); let campaign = addMonthly(store, "月", month: "2026-11")
        XCTAssertEqual(update(store, campaign, .confirmRegistration(outputKey: idea, registrationID: UUID())), .violation(.noCurrentRegistration))
        let (_, first) = register(store, campaign, location: "/virtual/v1")
        let (_, second) = register(store, campaign, location: "/virtual/v2")
        XCTAssertEqual(update(store, campaign, .confirmRegistration(outputKey: idea, registrationID: first)), .violation(.notCurrentRegistration),
                       "only the current record can be confirmed")
        XCTAssertEqual(update(store, campaign, .confirmRegistration(outputKey: idea, registrationID: UUID())), .violation(.registrationNotFound))
        XCTAssertEqual(update(store, campaign, .confirmRegistration(outputKey: idea, registrationID: second)), .succeeded)
        var record = try XCTUnwrap(plan(store, campaign).output(idea))
        XCTAssertTrue(record.isConfirmed); XCTAssertEqual(record.confirmedRegistrationID, second); XCTAssertNotNil(record.confirmedAt)
        XCTAssertEqual(ZhuowangMonthlyRules.confirmedOutputCount(plan(store, campaign)), 1)
        // Re-selecting the same current record keeps the confirmation.
        XCTAssertEqual(update(store, campaign, .setCurrentRegistration(outputKey: idea, registrationID: second)), .succeeded)
        XCTAssertTrue(try XCTUnwrap(plan(store, campaign).output(idea)).isConfirmed)
        // Changing the current record clears the confirmation; it must be confirmed again explicitly.
        XCTAssertEqual(update(store, campaign, .setCurrentRegistration(outputKey: idea, registrationID: first)), .succeeded)
        record = try XCTUnwrap(plan(store, campaign).output(idea))
        XCTAssertFalse(record.isConfirmed); XCTAssertNil(record.confirmedRegistrationID); XCTAssertEqual(record.currentRegistrationID, first)
        XCTAssertEqual(ZhuowangMonthlyRules.confirmedOutputCount(plan(store, campaign)), 0)
        XCTAssertEqual(update(store, campaign, .confirmRegistration(outputKey: idea, registrationID: first)), .succeeded)
        // A newly registered record also clears the old confirmation and is not auto-confirmed.
        let (_, third) = register(store, campaign, location: "/virtual/v3")
        record = try XCTUnwrap(plan(store, campaign).output(idea))
        XCTAssertFalse(record.isConfirmed); XCTAssertEqual(record.currentRegistrationID, third)
        XCTAssertEqual(record.registrations.count, 3, "history preserved")
        XCTAssertEqual(update(store, campaign, .setCurrentRegistration(outputKey: idea, registrationID: UUID())), .violation(.registrationNotFound))
        XCTAssertEqual(update(store, campaign, .confirmRegistration(outputKey: idea, registrationID: third)), .succeeded)
        XCTAssertEqual(update(store, campaign, .clearConfirmation(outputKey: idea)), .succeeded)
        XCTAssertFalse(try XCTUnwrap(plan(store, campaign).output(idea)).isConfirmed)
        // A confirmation id that is not the current record never counts as confirmed.
        var forged = try XCTUnwrap(plan(store, campaign).output(idea))
        forged.confirmedRegistrationID = first
        XCTAssertFalse(forged.isConfirmed)
    }

    // MARK: Inputs

    func testInputsUseThreeStatesAndThePrizePoolRelationIsSeparate() throws {
        let store = makeStore(makeSource()); let campaign = addMonthly(store, "月", month: "2026-11")
        let prize = "monthly.input.prizeTable", contact = "monthly.input.contactObtained"
        XCTAssertNil(plan(store, campaign).input(prize), "default is 待要 without a stored record")
        XCTAssertFalse(ZhuowangMonthlyRules.isInputSettled(ZhuowangMonthlyDefinition.input(prize)!, in: plan(store, campaign)))
        XCTAssertEqual(update(store, campaign, .setInput(key: prize, status: .received, note: " 已收到\n奖品表 V1 ")), .succeeded)
        XCTAssertEqual(plan(store, campaign).input(prize)?.status, .received)
        XCTAssertEqual(plan(store, campaign).input(prize)?.note, " 已收到\n奖品表 V1 ")
        XCTAssertEqual(update(store, campaign, .setInput(key: contact, status: .notApplicable, note: "")), .succeeded)
        XCTAssertEqual(ZhuowangMonthlyRules.settledInputCount(plan(store, campaign)), 2)
        XCTAssertEqual(update(store, campaign, .setInput(key: ZhuowangMonthlyPlan.prizePoolKey, status: .received, note: "")), .violation(.unknownItem))
        XCTAssertEqual(update(store, campaign, .setInput(key: "monthly.input.unknown", status: .received, note: "")), .violation(.unknownItem))
        XCTAssertEqual(update(store, campaign, .setInput(key: prize, status: .received, note: String(repeating: "n", count: 4001))), .violation(.tooLong))
        XCTAssertEqual(plan(store, campaign).prizePoolRelation, .pending)
        XCTAssertEqual(update(store, campaign, .setPrizePool(relation: .independent, note: "掌厅单独奖池")), .succeeded)
        XCTAssertEqual(plan(store, campaign).prizePoolRelation, .independent)
        XCTAssertEqual(ZhuowangMonthlyRules.settledInputCount(plan(store, campaign)), 3)
        XCTAssertEqual(update(store, campaign, .setPrizePool(relation: .pending, note: "")), .succeeded)
        XCTAssertEqual(ZhuowangMonthlyRules.settledInputCount(plan(store, campaign)), 2)
        // The stored data holds no contact detail field at all.
        let json = String(decoding: try JSONEncoder().encode(plan(store, campaign)), as: UTF8.self)
        XCTAssertFalse(json.lowercased().contains("phone")); XCTAssertFalse(json.contains("联系方式"))
    }

    func testOutputProgressInputProgressWorkflowAndDeliveryAreSeparateConcepts() throws {
        let source = makeSource(); let store = makeStore(source)
        let campaign = addMonthly(store, "月", month: "2026-11")
        for definition in ZhuowangMonthlyDefinition.inputs where definition.kind == .receipt {
            update(store, campaign, .setInput(key: definition.key, status: .received, note: ""))
        }
        update(store, campaign, .setPrizePool(relation: .shared, note: ""))
        XCTAssertEqual(ZhuowangMonthlyRules.settledInputCount(plan(store, campaign)), 7)
        XCTAssertEqual(ZhuowangMonthlyRules.confirmedOutputCount(plan(store, campaign)), 0, "inputs never complete outputs")
        let (_, id) = register(store, campaign)
        XCTAssertEqual(ZhuowangMonthlyRules.confirmedOutputCount(plan(store, campaign)), 0, "a registered but unconfirmed output does not count")
        update(store, campaign, .confirmRegistration(outputKey: idea, registrationID: id))
        XCTAssertEqual(ZhuowangMonthlyRules.confirmedOutputCount(plan(store, campaign)), 1)
        XCTAssertEqual(ZhuowangMonthlyDefinition.outputs.count, 7)
    }

    // MARK: Workflow stays untouched

    func testWorkflowHintsAreReadOnlyAndNeverMeanCompletion() throws {
        var workflow = ZhuowangCampaignWorkflow.standard(campaignID: UUID())
        let step = try XCTUnwrap(workflow.steps.first { $0.kind == .customerService })
        workflow.artifacts.append(ZhuowangArtifact(campaignID: workflow.campaignID, stepID: step.id, name: "客服文档",
            type: .markdown, location: "/virtual/cs.md", version: 1, isApprovedVersion: true))
        let definition = try XCTUnwrap(ZhuowangMonthlyDefinition.output("monthly.output.customerServiceDoc"))
        let hint = ZhuowangMonthlyRules.stepHint(for: definition, workflow: workflow)
        XCTAssertTrue(hint.workflowExists); XCTAssertEqual(hint.stepTitle, "客服文档"); XCTAssertEqual(hint.adoptedArtifactCount, 1)
        let none = ZhuowangMonthlyRules.stepHint(for: definition, workflow: nil)
        XCTAssertFalse(none.workflowExists); XCTAssertEqual(none.adoptedArtifactCount, 0)
        let idea = ZhuowangMonthlyRules.stepHint(for: try XCTUnwrap(ZhuowangMonthlyDefinition.output("monthly.output.idea")), workflow: workflow)
        XCTAssertEqual(idea.adoptedArtifactCount, 0)
        // The hint is the only link: the plan has no record and progress stays 0 although a step artifact is adopted.
        XCTAssertEqual(ZhuowangMonthlyRules.confirmedOutputCount(ZhuowangMonthlyPlan(activityMonth: "2026-11")), 0)
    }

    func testPlanChangesNeverTouchWorkflowDataOrCreateWorkflows() throws {
        let source = makeSource(); let store = makeStore(source)
        let campaign = addMonthly(store, "月", month: "2026-11")
        var workflow = ZhuowangCampaignWorkflow.standard(campaignID: campaign.id)
        workflow.steps[5].status = .approved
        let encoded = try JSONEncoder().encode([workflow])
        source.set(encoded, forKey: ZhuowangWorkflowStore.workflowStorageKey)
        source.resetWriteLog()
        let workflowStore = ZhuowangWorkflowStore(persistenceConfiguration: isolatedConfiguration(dataSource: source))
        source.resetWriteLog()
        let before = source.storage[ZhuowangWorkflowStore.workflowStorageKey]
        let (_, id) = register(store, campaign)
        update(store, campaign, .confirmRegistration(outputKey: idea, registrationID: id))
        update(store, campaign, .setInput(key: "monthly.input.prizeTable", status: .received, note: ""))
        update(store, campaign, .setPrizePool(relation: .shared, note: ""))
        _ = ZhuowangMonthlyRules.stepHint(for: ZhuowangMonthlyDefinition.outputs[0], workflow: workflowStore.workflow(forCampaignID: campaign.id))
        XCTAssertEqual(source.storage[ZhuowangWorkflowStore.workflowStorageKey], before)
        XCTAssertEqual(source.writeCount(forKey: ZhuowangWorkflowStore.workflowStorageKey), 0)
        XCTAssertEqual(workflowStore.workflows.count, 1)
        XCTAssertEqual(workflowStore.workflow(forCampaignID: campaign.id)?.steps[5].status, .approved)
        XCTAssertNil(workflowStore.workflow(forCampaignID: UUID()), "reading never creates a Workflow")
        XCTAssertEqual(workflowStore.workflows.count, 1)
    }

    // MARK: Protected writes

    func testStaleRevisionIsRefusedAndOtherCampaignsAreKept() throws {
        let source = makeSource(); let store = makeStore(source)
        let other = addMonthly(store, "别的月", month: "2026-09")
        let campaign = addMonthly(store, "月", month: "2026-11")
        let otherBefore = try XCTUnwrap(store.campaign(id: other.id))
        let staleRevision = plan(store, campaign).revision
        XCTAssertEqual(store.updateMonthlyPlan(campaignID: campaign.id, expectedRevision: staleRevision,
            .setInput(key: "monthly.input.prizeTable", status: .received, note: "第一份")), .succeeded)
        XCTAssertEqual(store.updateMonthlyPlan(campaignID: campaign.id, expectedRevision: staleRevision,
            .setInput(key: "monthly.input.prizeTable", status: .notApplicable, note: "过时的第二份")), .violation(.stale))
        XCTAssertEqual(plan(store, campaign).input("monthly.input.prizeTable")?.note, "第一份")
        XCTAssertEqual(plan(store, campaign).revision, staleRevision + 1)
        XCTAssertEqual(store.campaign(id: other.id), otherBefore)
        // Two stores over the same data: the second one's baseline is stale.
        let second = makeStore(source)
        XCTAssertEqual(store.updateMonthlyPlan(campaignID: campaign.id, expectedRevision: plan(store, campaign).revision,
            .setPrizePool(relation: .shared, note: "")), .succeeded)
        let result = second.updateMonthlyPlan(campaignID: campaign.id, expectedRevision: plan(second, campaign).revision,
            .setPrizePool(relation: .independent, note: ""))
        XCTAssertEqual(result, .store(.rejected(.staleConflict)))
        XCTAssertEqual(makeStore(source).campaign(id: campaign.id)?.monthly?.prizePoolRelation, .shared)
    }

    func testAStaleCampaignCopyCannotOverwriteThePlanButOrdinaryEditsStillWork() throws {
        let store = makeStore(makeSource())
        let other = addMonthly(store, "别的月", month: "2026-09")
        let campaign = addMonthly(store, "月", month: "2026-11")
        var staleCopy = try XCTUnwrap(store.campaign(id: campaign.id))
        update(store, campaign, .setPrizePool(relation: .shared, note: "较新的计划"))
        staleCopy.notes = "活动备注可以照常保存"; staleCopy.status = .active
        XCTAssertEqual(store.updateCampaign(staleCopy), .succeeded)
        let saved = try XCTUnwrap(store.campaign(id: campaign.id))
        XCTAssertEqual(saved.notes, "活动备注可以照常保存"); XCTAssertEqual(saved.status, .active)
        XCTAssertEqual(saved.monthly?.prizePoolRelation, .shared, "the plan is only changed through its own revision-checked path")
        XCTAssertEqual(saved.monthly?.prizePoolNote, "较新的计划")
        XCTAssertNotNil(store.campaign(id: other.id)?.monthly)
    }

    func testPlanEditsKeepCampaignOrderAndNeverReorderTheList() throws {
        let store = makeStore(makeSource())
        _ = addMonthly(store, "甲", month: "2026-09"); _ = addMonthly(store, "乙", month: "2026-10")
        let target = addMonthly(store, "丙", month: "2026-11")
        let order = store.campaigns.map(\.id)
        update(store, target, .setPrizePool(relation: .shared, note: ""))
        XCTAssertEqual(store.campaigns.map(\.id), order)
    }

    func testNewPlanFieldsRoundTripAndTolerateMissingKeys() throws {
        let store = makeStore(makeSource()); let campaign = addMonthly(store, "月", month: "2026-11")
        let (_, id) = register(store, campaign, note: "x")
        update(store, campaign, .confirmRegistration(outputKey: idea, registrationID: id))
        let current = try XCTUnwrap(store.campaign(id: campaign.id)?.monthly)
        let again = try JSONDecoder().decode(ZhuowangMonthlyPlan.self, from: try JSONEncoder().encode(current))
        XCTAssertEqual(again, current)
        let minimal = try JSONDecoder().decode(ZhuowangMonthlyPlan.self, from: Data("{\"activityMonth\":\"2026-11\"}".utf8))
        XCTAssertEqual(minimal.revision, 1); XCTAssertEqual(minimal.prizePoolRelation, .pending); XCTAssertTrue(minimal.outputs.isEmpty)
        // Records for keys this build does not know are preserved, not dropped.
        var future = current
        future.outputs.append(ZhuowangMonthlyOutputRecord(key: "monthly.output.future"))
        let kept = try JSONDecoder().decode(ZhuowangMonthlyPlan.self, from: try JSONEncoder().encode(future))
        XCTAssertEqual(kept.outputs.map(\.key).last, "monthly.output.future")
    }

    // MARK: Rendering (injected components, no Campaign detail window)

    func testMonthlyChecklistAndCreateFormRenderOffscreen() throws {
        let source = makeSource(); let store = makeStore(source)
        let october = addMonthly(store, "十月促活", month: "2026-10")
        let (_, id) = register(store, october, location: "https://example.com/oct", label: "V1.1")
        update(store, october, .confirmRegistration(outputKey: idea, registrationID: id))
        let november = addMonthly(store, "十一月促活", month: "2026-11", reference: october.id)
        register(store, november, location: "/virtual/nov-doc.docx", label: "V1", note: "备注")
        register(store, november, location: "/virtual/nov-doc-v2.docx", label: "V2")
        update(store, november, .setPrizePool(relation: .independent, note: "单独奖池"))
        let workflowStore = ZhuowangWorkflowStore(persistenceConfiguration: isolatedConfiguration(dataSource: source))
        let root = URL(fileURLWithPath: "/private/tmp/CosmosMonthlyPhase1-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func png<V: View>(_ view: V, _ name: String) throws {
            let renderer = ImageRenderer(content: view)
            let image = try XCTUnwrap(renderer.nsImage, name)
            let rep = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
            let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
            try data.write(to: root.appendingPathComponent(name + ".png"))
            XCTAssertGreaterThan(data.count, 1000, name)
        }
        try png(ZhuowangMonthlyChecklistView(store: store, workflowStore: workflowStore, campaignID: november.id)
            .frame(width: 800, height: 1800), "checklist")
        try png(ZhuowangMonthlyChecklistView(store: store, workflowStore: workflowStore, campaignID: UUID()).frame(width: 600, height: 300), "not-monthly")
        let module = ZhuowangModule(id: "national", name: "全国促活", englishName: "National", icon: "globe", usesProvinces: false)
        try png(ZhuowangCampaignCreateView(store: store, province: nil, module: module), "create-form")
        XCTAssertEqual(workflowStore.workflows.count, 0, "rendering created no Workflow")
        XCTAssertEqual(source.writeCount(forKey: ZhuowangWorkflowStore.workflowStorageKey), 0)
    }
}
