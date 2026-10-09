import Foundation

// MARK: - Navigation

enum ZhuowangNavigationItem: Equatable {
    case workbench
    case province(UUID)
    case module(String)
}


// MARK: - Workspace Module

struct ZhuowangModule:
    Identifiable,
    Codable,
    Hashable {

    let id: String
    var name: String
    var englishName: String
    var icon: String
    var usesProvinces: Bool
}


// MARK: - Province

struct ZhuowangProvince:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID

    /// Display name only. Renaming never moves files.
    var name: String
    var englishName: String

    /// Stopped provinces cannot receive new Campaigns, but every historical
    /// Campaign / Artifact / file stays reachable. Missing in old data → true.
    var isEnabled: Bool

    /// Stable folder name under the Zhuowang workspace root. Fixed when the
    /// province is created (or, for provinces created before this field
    /// existed, when it is first renamed). `nil` means "still the legacy
    /// behavior": the folder is derived from `name`, which cannot have
    /// changed yet because the first rename pins it.
    var directoryName: String?

    init(
        id: UUID,
        name: String,
        englishName: String,
        isEnabled: Bool = true,
        directoryName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.isEnabled = isEnabled
        self.directoryName = directoryName
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, englishName, isEnabled, directoryName
    }

    /// Backward-compatible: provinces saved before `isEnabled` /
    /// `directoryName` existed must keep decoding, otherwise the whole
    /// Workspace snapshot would be treated as corrupt and locked.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        englishName = try c.decode(String.self, forKey: .englishName)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        directoryName = try c.decodeIfPresent(String.self, forKey: .directoryName)
    }

    /// The name every file-path construction must use. UI shows `name`.
    var pathName: String { directoryName ?? name }
}


// MARK: - Category

struct ZhuowangCategory:
    Identifiable,
    Codable,
    Hashable {

    let id: String
    var name: String
    var englishName: String
    var icon: String
}


// MARK: - Workspace Snapshot

struct ZhuowangWorkspaceSnapshot:
    Codable {

    let modules: [ZhuowangModule]
    let provinces: [ZhuowangProvince]
    let categories: [ZhuowangCategory]
}
