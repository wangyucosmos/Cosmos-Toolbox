import Foundation

// MARK: - Navigation

enum ZhuowangNavigationItem: Equatable {
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
    var name: String
    var englishName: String
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
