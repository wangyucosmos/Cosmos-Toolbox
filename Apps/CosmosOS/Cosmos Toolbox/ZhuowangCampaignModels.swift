import Foundation

// MARK: - Campaign Status

enum ZhuowangCampaignStatus: String, Codable, CaseIterable, Identifiable {

    case planning
    case designing
    case pendingLaunch
    case active
    case completed

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .planning:
            return "策划中"
        case .designing:
            return "设计中"
        case .pendingLaunch:
            return "待上线"
        case .active:
            return "进行中"
        case .completed:
            return "已结束"
        }
    }

    var englishTitle: String {
        switch self {
        case .planning:
            return "Planning"
        case .designing:
            return "Designing"
        case .pendingLaunch:
            return "Pending Launch"
        case .active:
            return "Active"
        case .completed:
            return "Completed"
        }
    }

    var systemImage: String {
        switch self {
        case .planning:
            return "pencil.and.outline"
        case .designing:
            return "paintbrush"
        case .pendingLaunch:
            return "clock"
        case .active:
            return "play.circle"
        case .completed:
            return "checkmark.circle"
        }
    }
}


// MARK: - Campaign Scope Type

enum ZhuowangCampaignScopeType: String, Codable {

    case province
    case national
    case other
}


// MARK: - Campaign

struct ZhuowangCampaign:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID

    var name: String

    /// English auxiliary name.
    /// Can remain empty if the project does not need an English title.
    var englishName: String

    /// Province / national / other.
    var scopeType: ZhuowangCampaignScopeType

    /// Stores the related province UUID when scopeType == .province.
    var provinceID: UUID?

    /// Stores the related workspace module ID when needed.
    /// Example: national / quiz.
    var moduleID: String?

    var startDate: Date

    var endDate: Date

    var status: ZhuowangCampaignStatus

    var notes: String

    var createdAt: Date

    var updatedAt: Date


    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        name: String,
        englishName: String = "",
        scopeType: ZhuowangCampaignScopeType,
        provinceID: UUID? = nil,
        moduleID: String? = nil,
        startDate: Date,
        endDate: Date,
        status: ZhuowangCampaignStatus = .planning,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.scopeType = scopeType
        self.provinceID = provinceID
        self.moduleID = moduleID
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


// MARK: - Convenience

extension ZhuowangCampaign {

    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"

        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    var isActiveNow: Bool {
        let now = Date()

        return status == .active
            && now >= startDate
            && now <= endDate
    }
}
