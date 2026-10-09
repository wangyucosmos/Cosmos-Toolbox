import Foundation

// MARK: - Limits

/// Rejected, never truncated. Counts are Swift `Character`s except the entry body (UTF-8 bytes).
nonisolated enum LearningLimits {
    static let nameCharacters = 200
    static let goalCharacters = 4000
    static let nextStepCharacters = 1000
    static let resourceCharacters = 2048
    static let entryBodyBytes = 1024 * 1024
    static let durationMinutes = 1...1440
    static let documentBytes = 16 * 1024 * 1024
}

// MARK: - Calendar day

/// A local calendar day stored as `yyyy-MM-dd`. It is a label, not an instant, so a
/// time-zone change never reinterprets a saved study date.
nonisolated struct LearningDay: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    static let years = 1900...9999
    let year: Int
    let month: Int
    let day: Int

    init?(year: Int, month: Int, day: Int) {
        guard Self.years.contains(year), (1...12).contains(month),
              day >= 1, day <= Self.daysIn(year: year, month: month) else { return nil }
        self.year = year; self.month = month; self.day = day
    }

    /// Strict `yyyy-MM-dd`: exactly ten ASCII characters and a real proleptic-Gregorian date.
    /// Out-of-range values such as `2026-02-30` are rejected, never normalized.
    init?(string: String) {
        let bytes = Array(string.utf8)
        guard bytes.count == 10, bytes[4] == 0x2D, bytes[7] == 0x2D else { return nil }
        func number(_ range: Range<Int>) -> Int? {
            var value = 0
            for byte in bytes[range] {
                guard byte >= 0x30, byte <= 0x39 else { return nil }
                value = value * 10 + Int(byte - 0x30)
            }
            return value
        }
        guard let year = number(0..<4), let month = number(5..<7), let day = number(8..<10) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The local calendar day of `date` in `timeZone`.
    init(date: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let clamped = min(max(parts.year ?? Self.years.lowerBound, Self.years.lowerBound), Self.years.upperBound)
        self = Self(year: clamped, month: parts.month ?? 1, day: parts.day ?? 1)
            ?? Self(year: Self.years.lowerBound, month: 1, day: 1)!
    }

    static func today(now: Date = Date(), timeZone: TimeZone = .current) -> LearningDay {
        LearningDay(date: now, timeZone: timeZone)
    }

    /// Noon of this day in `timeZone`; used only to feed a date picker.
    func date(timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var parts = DateComponents()
        parts.year = year; parts.month = month; parts.day = day; parts.hour = 12
        return calendar.date(from: parts) ?? Date()
    }

    var string: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var description: String { string }

    static func < (lhs: LearningDay, rhs: LearningDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static func daysIn(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        default:
            let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return leap ? 29 : 28
        }
    }

    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let value = LearningDay(string: text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                debugDescription: "Invalid learning day: \(text)"))
        }
        self = value
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

// MARK: - Status

nonisolated enum LearningStatus: String, Codable, CaseIterable, Sendable {
    case planned, learning, completed
    var title: String {
        switch self {
        case .planned: return "计划中"
        case .learning: return "学习中"
        case .completed: return "已完成"
        }
    }
}

// MARK: - Topic

nonisolated struct LearningTopic: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    /// Stored exactly as typed, including whitespace and newlines.
    var goal: String
    var status: LearningStatus
    /// The user's own next action. Stored exactly as typed; never inferred.
    var nextStep: String
    var resourceURL: String?
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date
    var revision: Int

    init(id: UUID = UUID(), name: String, goal: String = "", status: LearningStatus = .planned,
         nextStep: String = "", resourceURL: String? = nil, isArchived: Bool = false,
         createdAt: Date = Date(), updatedAt: Date? = nil, revision: Int = 1) {
        self.id = id; self.name = name; self.goal = goal; self.status = status
        self.nextStep = nextStep; self.resourceURL = resourceURL; self.isArchived = isArchived
        self.createdAt = createdAt; self.updatedAt = updatedAt ?? createdAt; self.revision = revision
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, goal, status, nextStep, resourceURL, isArchived, createdAt, updatedAt, revision
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        goal = try c.decodeIfPresent(String.self, forKey: .goal) ?? ""
        status = try c.decodeIfPresent(LearningStatus.self, forKey: .status) ?? .planned
        nextStep = try c.decodeIfPresent(String.self, forKey: .nextStep) ?? ""
        resourceURL = try c.decodeIfPresent(String.self, forKey: .resourceURL)
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        revision = try c.decodeIfPresent(Int.self, forKey: .revision) ?? 1
    }

    /// "Has a next step" is judged on non-whitespace content; the stored text is never rewritten.
    var hasNextStep: Bool { !nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    static func validateNextStep(_ text: String) throws {
        guard text.count <= LearningLimits.nextStepCharacters else {
            throw LearningError.invalidInput("下一步超过 \(LearningLimits.nextStepCharacters) 字符上限；未保存也未截断。")
        }
    }

    /// Only the name and link are trimmed. Goal and next step keep their exact text.
    func validated() throws -> LearningTopic {
        var result = self
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.name.isEmpty else { throw LearningError.invalidInput("主题名称不能为空。") }
        guard result.name.rangeOfCharacter(from: .newlines) == nil else {
            throw LearningError.invalidInput("主题名称不能包含换行。")
        }
        guard result.name.count <= LearningLimits.nameCharacters else {
            throw LearningError.invalidInput("主题名称超过 \(LearningLimits.nameCharacters) 字符上限；未保存也未截断。")
        }
        guard goal.count <= LearningLimits.goalCharacters else {
            throw LearningError.invalidInput("学习目标超过 \(LearningLimits.goalCharacters) 字符上限；未保存也未截断。")
        }
        try Self.validateNextStep(nextStep)
        result.resourceURL = try Self.normalizedResource(resourceURL)
        guard revision > 0 else { throw LearningError.invalidInput("主题版本无效。") }
        return result
    }

    static func normalizedResource(_ text: String?) throws -> String? {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let message = "资料链接须为 http 或 https 地址，或留空。"
        guard trimmed.count <= LearningLimits.resourceCharacters else {
            throw LearningError.invalidInput("资料链接超过 \(LearningLimits.resourceCharacters) 字符上限；未保存也未截断。")
        }
        let blocked = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        guard trimmed.unicodeScalars.allSatisfy({ !blocked.contains($0) }),
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty else { throw LearningError.invalidInput(message) }
        return trimmed
    }
}

// MARK: - Entry

nonisolated struct LearningEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let topicID: UUID
    var studyDay: LearningDay
    /// Stored exactly as typed.
    var body: String
    /// Whole minutes; `nil` means "not recorded".
    var durationMinutes: Int?
    let createdAt: Date
    var updatedAt: Date
    var revision: Int

    init(id: UUID = UUID(), topicID: UUID, studyDay: LearningDay, body: String,
         durationMinutes: Int? = nil, createdAt: Date = Date(), updatedAt: Date? = nil, revision: Int = 1) {
        self.id = id; self.topicID = topicID; self.studyDay = studyDay; self.body = body
        self.durationMinutes = durationMinutes; self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt; self.revision = revision
    }

    private enum CodingKeys: String, CodingKey {
        case id, topicID, studyDay = "studyDate", body, durationMinutes, createdAt, updatedAt, revision
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        topicID = try c.decode(UUID.self, forKey: .topicID)
        studyDay = try c.decode(LearningDay.self, forKey: .studyDay)
        body = try c.decode(String.self, forKey: .body)
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        revision = try c.decodeIfPresent(Int.self, forKey: .revision) ?? 1
    }

    func validated() throws -> LearningEntry {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LearningError.invalidInput("学习笔记须包含非空白内容；未保存。")
        }
        guard body.utf8.count <= LearningLimits.entryBodyBytes else {
            throw LearningError.invalidInput("学习笔记超过 1 MiB 上限；未保存也未截断。")
        }
        if let durationMinutes {
            guard LearningLimits.durationMinutes.contains(durationMinutes) else {
                throw LearningError.invalidInput("时长须为 1–1440 的整数分钟，或留空。")
            }
        }
        guard revision > 0 else { throw LearningError.invalidInput("记录版本无效。") }
        return self
    }

    /// Newest study day first; ties keep the newest creation first, then a stable id order.
    static func isNewer(_ lhs: LearningEntry, than rhs: LearningEntry) -> Bool {
        if lhs.studyDay != rhs.studyDay { return lhs.studyDay > rhs.studyDay }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

// MARK: - Document

nonisolated struct LearningSnapshot: Equatable, Sendable {
    var topics: [LearningTopic] = []
    var entries: [LearningEntry] = []
}

nonisolated struct LearningDocument: Codable, Sendable {
    var schemaVersion: Int = 1
    var topics: [LearningTopic] = []
    var entries: [LearningEntry] = []

    var snapshot: LearningSnapshot { LearningSnapshot(topics: topics, entries: entries) }

    func validate() throws {
        guard schemaVersion == 1 else { throw LearningError.unsupportedSchema }
        guard Set(topics.map(\.id)).count == topics.count,
              Set(entries.map(\.id)).count == entries.count else { throw LearningError.duplicateIdentity }
        let topicIDs = Set(topics.map(\.id))
        for topic in topics { _ = try topic.validated() }
        for entry in entries {
            _ = try entry.validated()
            guard topicIDs.contains(entry.topicID) else { throw LearningError.orphanRecord }
        }
    }
}

// MARK: - Errors

nonisolated enum LearningError: Error, LocalizedError, Equatable, Sendable {
    case invalidInput(String)
    case futureDate
    case topicMissing
    case topicArchived
    case unsupportedSchema, duplicateIdentity, corruptData, orphanRecord, missingPrimaryWithBackup
    case unsafePath
    case conflict
    /// A failure certainly before the primary file was replaced; saving may be retried.
    case writeFailed(String)
    /// A failure to read or reach storage; saving stays locked until an explicit reload succeeds.
    case storage(String)
    /// The primary replacement may have happened but could not be confirmed.
    case uncertainWrite

    var errorDescription: String? {
        switch self {
        case .invalidInput(let reason): return reason
        case .futureDate: return "学习日期不能晚于今天（按本机当前日历日）；未保存。"
        case .topicMissing: return "所属学习主题已不存在，未保存。草稿已保留。"
        case .topicArchived: return "该主题已归档，只读；请先恢复再编辑或记录。草稿已保留。"
        case .unsupportedSchema: return "学习库格式不受当前版本支持，已禁止保存；原文件未被自动替换。"
        case .duplicateIdentity: return "学习库存在重复身份，已禁止保存；请核对原文件。"
        case .corruptData: return "学习库无法解码，已禁止保存；不会用空库覆盖原文件。"
        case .orphanRecord: return "学习库中存在找不到所属主题的记录，已禁止保存；请核对原文件。"
        case .missingPrimaryWithBackup: return "学习库主文件不存在但备份仍在，已禁止初始化；尚未自动恢复。"
        case .unsafePath: return "存储路径不是安全的普通文件／目录，或包含符号链接；已停止操作。"
        case .conflict: return "主题、记录或磁盘数据已变化，未覆盖较新内容。草稿已保留；请复制草稿或显式重新加载。"
        case .writeFailed(let reason): return "保存未完成，原文件未被替换：\(reason)。草稿已保留，可重试。"
        case .storage(let reason): return "学习库文件操作失败：\(reason)。草稿已保留。"
        case .uncertainWrite: return "主文件替换可能已发生，但读回校验失败。界面未发布本次修改，草稿已保留；已锁定继续保存，请显式重新加载核对磁盘数据。"
        }
    }

    var locksSaving: Bool {
        switch self {
        case .invalidInput, .futureDate, .topicMissing, .topicArchived, .conflict, .writeFailed: return false
        default: return true
        }
    }
}
