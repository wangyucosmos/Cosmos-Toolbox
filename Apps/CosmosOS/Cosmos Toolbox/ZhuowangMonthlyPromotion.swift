import Foundation

// MARK: - Activity month

/// `YYYY-MM` label of the month a monthly Campaign belongs to. It is a label,
/// kept separate from the real start / end dates.
struct ZhuowangActivityMonth: Hashable, Comparable {
    static let years = 1900...9999
    let year: Int
    let month: Int

    init?(year: Int, month: Int) {
        guard Self.years.contains(year), (1...12).contains(month) else { return nil }
        self.year = year; self.month = month
    }

    /// Strict: exactly seven ASCII characters `YYYY-MM`, month 01–12.
    init?(string: String) {
        let bytes = Array(string.utf8)
        guard bytes.count == 7, bytes[4] == 0x2D else { return nil }
        func number(_ range: Range<Int>) -> Int? {
            var value = 0
            for byte in bytes[range] {
                guard byte >= 0x30, byte <= 0x39 else { return nil }
                value = value * 10 + Int(byte - 0x30)
            }
            return value
        }
        guard let year = number(0..<4), let month = number(5..<7) else { return nil }
        self.init(year: year, month: month)
    }

    var string: String { String(format: "%04d-%02d", year, month) }

    var previous: ZhuowangActivityMonth? {
        month == 1
            ? ZhuowangActivityMonth(year: year - 1, month: 12)
            : ZhuowangActivityMonth(year: year, month: month - 1)
    }

    static func < (lhs: ZhuowangActivityMonth, rhs: ZhuowangActivityMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

// MARK: - Fixed checklist definition (from the monthly process document)

/// How an input is tracked.
enum ZhuowangMonthlyInputKind: Equatable {
    /// 待要 / 已到 / 不适用
    case receipt
    /// 待确认 / 共用 / 独立 — decided anew every month.
    case prizePoolRelation
}

/// One of the seven monthly deliverables. `key` is the stable identity;
/// titles are display text and never used to associate stored data.
struct ZhuowangMonthlyOutputDefinition: Identifiable, Equatable {
    let key: String
    let title: String
    /// The existing six-step Workflow step this output is *sourced from*.
    /// Only a hint: it never means the output is done.
    let stepKind: ZhuowangWorkflowStepKind
    let formText: String
    /// Process-document reference day relative to T (the activity start).
    let suggestedOffsetDays: Int
    var id: String { key }
}

/// One of the seven inputs requested from the business side.
struct ZhuowangMonthlyInputDefinition: Identifiable, Equatable {
    let key: String
    let title: String
    let kind: ZhuowangMonthlyInputKind
    var id: String { key }
}

enum ZhuowangMonthlyDefinition {

    /// Process-document reference only (初版约定): not a reminder, not a deadline.
    static let suggestedDatesNote = "建议日来自流程文档（初版约定），仅供参考，不是截止日期，也不会提醒。"

    /// Inputs: ask from T−14, must have arrived by T−8 (reference only).
    static let inputsSuggestedOffsetDays = -8

    static let outputs: [ZhuowangMonthlyOutputDefinition] = [
        .init(key: "monthly.output.idea", title: "思路与文案方案",
              stepKind: .idea, formText: "Markdown 方案", suggestedOffsetDays: -21),
        .init(key: "monthly.output.mainPagePrototype", title: "主活动页原型",
              stepKind: .prototype, formText: "Figma 或 HTML 原型（主长图 + 弹窗）", suggestedOffsetDays: -10),
        .init(key: "monthly.output.zhangtingCopy", title: "掌厅引导页文案",
              stepKind: .pageStructure, formText: "10 个槽位的替换文案表", suggestedOffsetDays: -7),
        .init(key: "monthly.output.motionPreview", title: "动效稿",
              stepKind: .prototype, formText: "给领导看的手机链接", suggestedOffsetDays: -6),
        .init(key: "monthly.output.customerServiceDoc", title: "客服文档",
              stepKind: .customerService, formText: "Word 文档", suggestedOffsetDays: -8),
        .init(key: "monthly.output.zhangtingRules", title: "掌厅活动规则",
              stepKind: .customerService, formText: "Word 文档（1 页）", suggestedOffsetDays: -7),
        .init(key: "monthly.output.mainPageRules", title: "主活动页活动规则",
              stepKind: .customerService, formText: "Word 文档", suggestedOffsetDays: -2)
    ]

    static let inputs: [ZhuowangMonthlyInputDefinition] = [
        .init(key: "monthly.input.prizeTable", title: "奖品表", kind: .receipt),
        .init(key: "monthly.input.trafficPackage", title: "0 元流量包方案编号与排除口径", kind: .receipt),
        .init(key: "monthly.input.activityTime", title: "活动时间书面确认与活动链接", kind: .receipt),
        .init(key: ZhuowangMonthlyPlan.prizePoolKey, title: "掌厅奖池是否与主活动页共用", kind: .prizePoolRelation),
        .init(key: "monthly.input.lotteryParameters", title: "抽奖数值（中奖率、连抽倍率等）", kind: .receipt),
        .init(key: "monthly.input.couponTerms", title: "券类奖品权益条款原文", kind: .receipt),
        .init(key: "monthly.input.contactObtained", title: "业务联系人（仅记录是否已拿到）", kind: .receipt)
    ]

    static func output(_ key: String) -> ZhuowangMonthlyOutputDefinition? {
        outputs.first { $0.key == key }
    }

    static func input(_ key: String) -> ZhuowangMonthlyInputDefinition? {
        inputs.first { $0.key == key }
    }
}

// MARK: - Plan data (stored on the Campaign)

enum ZhuowangMonthlyInputStatus: String, Codable, CaseIterable {
    case requested, received, notApplicable
    var title: String {
        switch self {
        case .requested: return "待要"
        case .received: return "已到"
        case .notApplicable: return "不适用"
        }
    }
}

enum ZhuowangPrizePoolRelation: String, Codable, CaseIterable {
    case pending, shared, independent
    var title: String {
        switch self {
        case .pending: return "待确认"
        case .shared: return "共用"
        case .independent: return "独立"
        }
    }
}

/// A registered location of a real deliverable. Registration only records
/// where it is: nothing is opened, read, copied or checked.
struct ZhuowangMonthlyRegistration: Codable, Identifiable, Hashable {
    let id: UUID
    /// Absolute local path or http(s) link, trimmed.
    var location: String
    /// Free-text label ("V1.1"); not an identity.
    var versionLabel: String
    /// Exact text as typed.
    var note: String
    let createdAt: Date
}

struct ZhuowangMonthlyOutputRecord: Codable, Hashable {
    let key: String
    var registrations: [ZhuowangMonthlyRegistration] = []
    /// At most one; `nil` while there are no registrations.
    var currentRegistrationID: UUID?
    /// Explicit finalization of one specific registration.
    var confirmedRegistrationID: UUID?
    var confirmedAt: Date?

    var current: ZhuowangMonthlyRegistration? {
        registrations.first { $0.id == currentRegistrationID }
    }

    /// Confirmed only when the confirmation refers to the *current* record.
    var isConfirmed: Bool {
        guard let confirmedRegistrationID, let current else { return false }
        return current.id == confirmedRegistrationID
    }
}

struct ZhuowangMonthlyInputRecord: Codable, Hashable {
    let key: String
    var status: ZhuowangMonthlyInputStatus
    var note: String
}

struct ZhuowangMonthlyPlan: Codable, Hashable {
    static let prizePoolKey = "monthly.input.prizePoolRelation"

    /// `YYYY-MM` label (validated on every write).
    var activityMonth: String
    /// Identity of the previous period's Campaign; its content is never copied.
    var referenceCampaignID: UUID?
    var outputs: [ZhuowangMonthlyOutputRecord]
    var inputs: [ZhuowangMonthlyInputRecord]
    var prizePoolRelation: ZhuowangPrizePoolRelation
    var prizePoolNote: String
    /// Optimistic-concurrency token for this plan only.
    var revision: Int

    init(activityMonth: String, referenceCampaignID: UUID? = nil) {
        self.activityMonth = activityMonth
        self.referenceCampaignID = referenceCampaignID
        outputs = []; inputs = []
        prizePoolRelation = .pending; prizePoolNote = ""
        revision = 1
    }

    private enum CodingKeys: String, CodingKey {
        case activityMonth, referenceCampaignID, outputs, inputs, prizePoolRelation, prizePoolNote, revision
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activityMonth = try c.decode(String.self, forKey: .activityMonth)
        referenceCampaignID = try c.decodeIfPresent(UUID.self, forKey: .referenceCampaignID)
        outputs = try c.decodeIfPresent([ZhuowangMonthlyOutputRecord].self, forKey: .outputs) ?? []
        inputs = try c.decodeIfPresent([ZhuowangMonthlyInputRecord].self, forKey: .inputs) ?? []
        prizePoolRelation = try c.decodeIfPresent(ZhuowangPrizePoolRelation.self, forKey: .prizePoolRelation) ?? .pending
        prizePoolNote = try c.decodeIfPresent(String.self, forKey: .prizePoolNote) ?? ""
        revision = try c.decodeIfPresent(Int.self, forKey: .revision) ?? 1
    }

    func output(_ key: String) -> ZhuowangMonthlyOutputRecord? { outputs.first { $0.key == key } }
    func input(_ key: String) -> ZhuowangMonthlyInputRecord? { inputs.first { $0.key == key } }

    /// Month-specific state is never carried over: a new plan always starts blank.
    static func blank(activityMonth: String, referenceCampaignID: UUID?) -> ZhuowangMonthlyPlan {
        ZhuowangMonthlyPlan(activityMonth: activityMonth, referenceCampaignID: referenceCampaignID)
    }
}

// MARK: - Violations and mutations

enum ZhuowangMonthlyViolation: Error, Equatable {
    case invalidMonth
    case campaignNotFound
    case notMonthlyCampaign
    case stale
    case referenceNotFound
    case referenceNotMonthly
    case referenceNotEarlier
    case unknownItem
    case emptyLocation
    case invalidLocation
    case tooLong
    case registrationNotFound
    case noCurrentRegistration
    case notCurrentRegistration
    case invalidDates

    var message: String {
        switch self {
        case .invalidMonth: return "月份须为 YYYY-MM（例如 2026-11）；未保存。"
        case .campaignNotFound: return "活动已不存在；未保存。"
        case .notMonthlyCampaign: return "该活动不是月度会员促活类型；未保存。"
        case .stale: return "清单已被更新，未覆盖较新内容。你的输入仍保留，请核对最新内容后再保存。"
        case .referenceNotFound: return "上期参考活动不存在；请重新选择，不会自动换成其他活动。"
        case .referenceNotMonthly: return "上期参考活动不是月度会员促活类型；请重新选择。"
        case .referenceNotEarlier: return "上期参考必须是本活动月份之前的另一期月度活动；未保存。"
        case .unknownItem: return "未知的清单项；未保存。"
        case .emptyLocation: return "位置不能为空；未保存。"
        case .invalidLocation: return "位置须为明确的绝对路径（以 / 开头），或 http/https 链接；未保存。"
        case .tooLong: return "内容超过长度上限；未保存也未截断。"
        case .registrationNotFound: return "该登记记录不存在；未保存。"
        case .noCurrentRegistration: return "没有当前登记记录，不能确认定稿。"
        case .notCurrentRegistration: return "只能确认当前选择的登记记录；未保存。"
        case .invalidDates: return "结束时间不能早于开始时间；未保存。"
        }
    }
}

enum ZhuowangMonthlyMutation {
    case setActivityMonth(String)
    case setReference(UUID?)
    case addRegistration(outputKey: String, id: UUID, location: String, versionLabel: String, note: String, at: Date)
    case setCurrentRegistration(outputKey: String, registrationID: UUID)
    case confirmRegistration(outputKey: String, registrationID: UUID)
    case clearConfirmation(outputKey: String)
    case setInput(key: String, status: ZhuowangMonthlyInputStatus, note: String)
    case setPrizePool(relation: ZhuowangPrizePoolRelation, note: String)
}

enum ZhuowangMonthlyMutationResult: Equatable {
    case succeeded
    case violation(ZhuowangMonthlyViolation)
    case store(ZhuowangStoreMutationResult)

    var succeeded: Bool { self == .succeeded }

    var message: String? {
        switch self {
        case .succeeded: return nil
        case .violation(let violation): return violation.message
        case .store(let result): return result.userMessage ?? "操作失败，未保存任何修改。"
        }
    }
}

// MARK: - Rules

enum ZhuowangMonthlyRules {

    static let versionLabelLimit = 60
    static let noteLimit = 4000
    static let locationLimit = 2048

    // MARK: Location

    enum LocationKind: Equatable { case localPath, link }

    /// Registered locations are never opened or checked. A local location must
    /// be an explicit absolute path; a link must be http/https.
    static func normalizedLocation(_ raw: String) -> Result<(location: String, kind: LocationKind), ZhuowangMonthlyViolation> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyLocation) }
        guard trimmed.count <= locationLimit else { return .failure(.tooLong) }
        let blocked = CharacterSet.controlCharacters.union(.newlines)
        guard trimmed.unicodeScalars.allSatisfy({ !blocked.contains($0) }) else {
            return .failure(.invalidLocation)
        }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            guard !trimmed.unicodeScalars.contains(where: { CharacterSet.whitespaces.contains($0) }),
                  let components = URLComponents(string: trimmed),
                  let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
                  let host = components.host, !host.isEmpty else { return .failure(.invalidLocation) }
            return .success((trimmed, .link))
        }
        if trimmed.hasPrefix("/"), trimmed != "/", !trimmed.hasPrefix("//"),
           !trimmed.split(separator: "/", omittingEmptySubsequences: true).contains("..") {
            return .success((trimmed, .localPath))
        }
        return .failure(.invalidLocation)
    }

    // MARK: Applying a mutation to the latest persisted plan

    /// Applies `mutation` to `plan` (the latest persisted plan). Returns the
    /// violation and leaves `plan` untouched when the change is refused.
    static func apply(
        _ mutation: ZhuowangMonthlyMutation,
        to plan: inout ZhuowangMonthlyPlan,
        campaignID: UUID,
        campaigns: [ZhuowangCampaign]
    ) -> ZhuowangMonthlyViolation? {
        var next = plan

        func outputIndex(_ key: String) -> Int? {
            guard ZhuowangMonthlyDefinition.output(key) != nil else { return nil }
            if let index = next.outputs.firstIndex(where: { $0.key == key }) { return index }
            next.outputs.append(ZhuowangMonthlyOutputRecord(key: key))
            return next.outputs.count - 1
        }

        switch mutation {
        case .setActivityMonth(let text):
            guard ZhuowangActivityMonth(string: text) != nil else { return .invalidMonth }
            if let reference = next.referenceCampaignID,
               let violation = validateReference(
                   reference, month: text, selfID: campaignID, campaigns: campaigns) {
                // A previously valid reference that no longer precedes the new month blocks the change.
                return violation
            }
            next.activityMonth = text

        case .setReference(let id):
            if let id {
                if let violation = validateReference(
                    id, month: next.activityMonth, selfID: campaignID, campaigns: campaigns) {
                    return violation
                }
            }
            next.referenceCampaignID = id

        case .addRegistration(let key, let id, let location, let label, let note, let date):
            guard ZhuowangMonthlyDefinition.output(key) != nil else { return .unknownItem }
            let normalized: (location: String, kind: LocationKind)
            switch normalizedLocation(location) {
            case .success(let value): normalized = value
            case .failure(let violation): return violation
            }
            let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleanLabel.count <= versionLabelLimit, note.count <= noteLimit else { return .tooLong }
            guard let index = outputIndex(key) else { return .unknownItem }
            // Append-only history. The newest registration becomes the current
            // one; a different current record clears any earlier confirmation.
            next.outputs[index].registrations.append(
                ZhuowangMonthlyRegistration(
                    id: id, location: normalized.location, versionLabel: cleanLabel,
                    note: note, createdAt: date))
            next.outputs[index].currentRegistrationID = id
            next.outputs[index].confirmedRegistrationID = nil
            next.outputs[index].confirmedAt = nil

        case .setCurrentRegistration(let key, let registrationID):
            guard let index = outputIndex(key) else { return .unknownItem }
            guard next.outputs[index].registrations.contains(where: { $0.id == registrationID }) else {
                return .registrationNotFound
            }
            if next.outputs[index].currentRegistrationID != registrationID {
                next.outputs[index].currentRegistrationID = registrationID
                next.outputs[index].confirmedRegistrationID = nil
                next.outputs[index].confirmedAt = nil
            }

        case .confirmRegistration(let key, let registrationID):
            guard let index = outputIndex(key) else { return .unknownItem }
            guard next.outputs[index].current != nil else { return .noCurrentRegistration }
            guard next.outputs[index].currentRegistrationID == registrationID else {
                return next.outputs[index].registrations.contains { $0.id == registrationID }
                    ? .notCurrentRegistration : .registrationNotFound
            }
            next.outputs[index].confirmedRegistrationID = registrationID
            next.outputs[index].confirmedAt = Date()

        case .clearConfirmation(let key):
            guard let index = outputIndex(key) else { return .unknownItem }
            next.outputs[index].confirmedRegistrationID = nil
            next.outputs[index].confirmedAt = nil

        case .setInput(let key, let status, let note):
            guard let definition = ZhuowangMonthlyDefinition.input(key),
                  definition.kind == .receipt else { return .unknownItem }
            guard note.count <= noteLimit else { return .tooLong }
            if let index = next.inputs.firstIndex(where: { $0.key == key }) {
                next.inputs[index].status = status
                next.inputs[index].note = note
            } else {
                next.inputs.append(ZhuowangMonthlyInputRecord(key: key, status: status, note: note))
            }

        case .setPrizePool(let relation, let note):
            guard note.count <= noteLimit else { return .tooLong }
            next.prizePoolRelation = relation
            next.prizePoolNote = note
        }

        next.revision += 1
        plan = next
        return nil
    }

    // MARK: Reference

    /// A reference must be another monthly Campaign whose month precedes `month`.
    static func validateReference(
        _ id: UUID,
        month: String,
        selfID: UUID,
        campaigns: [ZhuowangCampaign]
    ) -> ZhuowangMonthlyViolation? {
        guard id != selfID else { return .referenceNotEarlier }
        guard let reference = campaigns.first(where: { $0.id == id }) else { return .referenceNotFound }
        guard let plan = reference.monthly else { return .referenceNotMonthly }
        guard let own = ZhuowangActivityMonth(string: month),
              let theirs = ZhuowangActivityMonth(string: plan.activityMonth),
              theirs < own else { return .referenceNotEarlier }
        return nil
    }

    /// Default candidate: the latest monthly Campaign of an earlier month.
    /// Never the Campaign itself, never the same or a later month.
    static func defaultReferenceCandidate(
        forMonth month: String,
        excluding selfID: UUID? = nil,
        in campaigns: [ZhuowangCampaign]
    ) -> ZhuowangCampaign? {
        guard let own = ZhuowangActivityMonth(string: month) else { return nil }
        let candidates: [(ZhuowangCampaign, ZhuowangActivityMonth)] = campaigns.compactMap { campaign in
            guard campaign.id != selfID, let plan = campaign.monthly,
                  let theirs = ZhuowangActivityMonth(string: plan.activityMonth), theirs < own
            else { return nil }
            return (campaign, theirs)
        }
        return candidates.max { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            if lhs.0.createdAt != rhs.0.createdAt { return lhs.0.createdAt < rhs.0.createdAt }
            return lhs.0.id.uuidString > rhs.0.id.uuidString
        }?.0
    }

    /// Other monthly Campaigns with the same month label (a warning only).
    static func campaignsWithMonth(
        _ month: String,
        excluding selfID: UUID? = nil,
        in campaigns: [ZhuowangCampaign]
    ) -> [ZhuowangCampaign] {
        campaigns.filter { $0.id != selfID && $0.monthly?.activityMonth == month }
    }

    enum ReferenceState: Equatable {
        case none
        case resolved(UUID)
        case missing
        case notMonthly
    }

    /// Live state of the stored reference; never silently replaced.
    static func referenceState(of plan: ZhuowangMonthlyPlan, in campaigns: [ZhuowangCampaign]) -> ReferenceState {
        guard let id = plan.referenceCampaignID else { return .none }
        guard let reference = campaigns.first(where: { $0.id == id }) else { return .missing }
        return reference.monthly == nil ? .notMonthly : .resolved(id)
    }

    // MARK: Dates

    static let shanghai = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!

    private static var shanghaiCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = shanghai
        return calendar
    }

    private static func lastDayAt17(_ month: ZhuowangActivityMonth) -> Date? {
        let calendar = shanghaiCalendar
        var first = DateComponents()
        first.year = month.year; first.month = month.month; first.day = 1
        guard let firstDate = calendar.date(from: first),
              let days = calendar.range(of: .day, in: .month, for: firstDate) else { return nil }
        var parts = DateComponents()
        parts.year = month.year; parts.month = month.month; parts.day = days.count
        parts.hour = 17; parts.minute = 0
        return calendar.date(from: parts)
    }

    /// Previous month's last day 17:00 → this month's last day 17:00, Shanghai time.
    static func defaultPeriod(for month: ZhuowangActivityMonth) -> (start: Date, end: Date)? {
        guard let previous = month.previous,
              let start = lastDayAt17(previous), let end = lastDayAt17(month) else { return nil }
        return (start, end)
    }

    /// Changing the month never overwrites dates the user already edited.
    static func datesAfterMonthChange(
        current: (start: Date, end: Date),
        newMonth: String,
        userEditedDates: Bool
    ) -> (start: Date, end: Date) {
        guard !userEditedDates,
              let month = ZhuowangActivityMonth(string: newMonth),
              let period = defaultPeriod(for: month) else { return current }
        return period
    }

    /// T = the activity start; suggestion = T + offset days, as a Shanghai calendar day.
    static func suggestedDay(start: Date, offsetDays: Int) -> Date? {
        let calendar = shanghaiCalendar
        return calendar.date(byAdding: .day, value: offsetDays, to: calendar.startOfDay(for: start))
    }

    // MARK: Progress (kept separate from Workflow and from ZIP delivery)

    /// "月度成品已确认": outputs whose explicit confirmation refers to the current registration.
    static func confirmedOutputCount(_ plan: ZhuowangMonthlyPlan) -> Int {
        ZhuowangMonthlyDefinition.outputs.filter { plan.output($0.key)?.isConfirmed == true }.count
    }

    /// Whether an input counts as settled (received, not applicable, or pool relation decided).
    static func isInputSettled(_ definition: ZhuowangMonthlyInputDefinition, in plan: ZhuowangMonthlyPlan) -> Bool {
        switch definition.kind {
        case .prizePoolRelation:
            return plan.prizePoolRelation != .pending
        case .receipt:
            let status = plan.input(definition.key)?.status ?? .requested
            return status != .requested
        }
    }

    static func settledInputCount(_ plan: ZhuowangMonthlyPlan) -> Int {
        ZhuowangMonthlyDefinition.inputs.filter { isInputSettled($0, in: plan) }.count
    }

    // MARK: Workflow source hint (read-only)

    struct StepHint: Equatable {
        let stepTitle: String?
        let adoptedArtifactCount: Int
        let workflowExists: Bool
    }

    /// Only a source hint: an adopted artifact on the mapped step does **not**
    /// mean the monthly output is finished (e.g. a Markdown customer-service
    /// document is not the external Word final).
    static func stepHint(for definition: ZhuowangMonthlyOutputDefinition, workflow: ZhuowangCampaignWorkflow?) -> StepHint {
        guard let workflow else { return StepHint(stepTitle: nil, adoptedArtifactCount: 0, workflowExists: false) }
        guard let step = workflow.steps.first(where: { $0.kind == definition.stepKind }) else {
            return StepHint(stepTitle: nil, adoptedArtifactCount: 0, workflowExists: true)
        }
        let adopted = workflow.artifacts.filter { $0.stepID == step.id && $0.isApprovedVersion }.count
        return StepHint(stepTitle: step.title, adoptedArtifactCount: adopted, workflowExists: true)
    }
}
