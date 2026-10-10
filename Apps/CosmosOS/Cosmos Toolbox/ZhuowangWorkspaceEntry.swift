import Foundation

/// Shared admission policy for the overview, list and an already-open draft.
struct ZhuowangWorkspaceEntry {
    static func canCreate(
        workspaceWritable: Bool, campaignWritable: Bool,
        province: ZhuowangProvince?, module: ZhuowangModule?,
        isProvinceEnabled: (UUID) -> Bool
    ) -> Bool {
        workspaceWritable && campaignWritable
        && (province.map { isProvinceEnabled($0.id) } ?? (module != nil))
    }

    static func createdCampaign(
        result: ZhuowangStoreMutationResult, previousIDs: Set<UUID>,
        campaigns: [ZhuowangCampaign]
    ) -> ZhuowangCampaign? {
        guard result.succeeded else { return nil }
        return campaigns.first { !previousIDs.contains($0.id) }
    }
}
