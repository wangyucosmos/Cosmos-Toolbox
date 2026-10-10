import Foundation

struct ZhuowangAssetEntry: Identifiable, Equatable {
    let artifact: ZhuowangArtifact
    let campaignName: String
    let provinceID: UUID?
    let scopeName: String
    let stepName: String
    let providerName: String?
    let adoptedCount: Int
    var id: UUID { artifact.id }
    var groupID: String { artifact.campaignID.uuidString + "::" + artifact.versionGroupKey }
    var adoptionLabel: String {
        if adoptedCount > 1 { return artifact.isApprovedVersion ? "采用冲突 · 已标记采用" : "采用冲突 · 未采用版本" }
        return artifact.isApprovedVersion ? "当前采用" : "未采用 / 历史版本"
    }
}

struct ZhuowangAssetFilter: Equatable {
    var query = ""
    var allVersions = false
    var provinceID: UUID?
    var campaignID: UUID?
    var type: ZhuowangArtifactType?

    func includes(_ entry: ZhuowangAssetEntry) -> Bool {
        (allVersions || entry.artifact.isApprovedVersion || entry.adoptedCount > 1)
        && (provinceID == nil || entry.provinceID == provinceID)
        && (campaignID == nil || entry.artifact.campaignID == campaignID)
        && (type == nil || entry.artifact.type == type)
    }
}

struct ZhuowangAssetMatch: Identifiable {
    let entry: ZhuowangAssetEntry
    let snippet: String?
    var id: UUID { entry.id }
}

nonisolated struct ZhuowangAssetTextRequest: Hashable, Sendable {
    let id: UUID
    let content: String?
    let location: String
    let readsTextFile: Bool
    let searchesText: Bool
}

nonisolated struct ZhuowangAssetBody: Equatable, Sendable {
    let text: String?
    let source: String
    let fileStatus: String
    let comparison: String
    let admittedPath: String?
    let limitation: String?
    var fileRevision: String? = nil
    var canCopy: Bool { text != nil }
}
