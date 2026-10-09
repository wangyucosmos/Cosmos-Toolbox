import Foundation

struct ZhuowangAssetCatalogSnapshot {
    let entries: [ZhuowangAssetEntry]
    let provinces: [ZhuowangProvince]
    let campaigns: [ZhuowangCampaign]
    let notices: [String]
}

struct ZhuowangAssetCatalogReader {
    let dataSource: any ZhuowangPersistenceDataSource

    func read() throws -> ZhuowangAssetCatalogSnapshot {
        let keys = [ZhuowangCampaignStore.storageKey, ZhuowangWorkspaceStore.storageKey,
                    ZhuowangWorkflowStore.workflowStorageKey, "cosmos.zhuowang.ai.providers.v1"]
        // Two bounded attempts; never publish a snapshot observed changing.
        for _ in 0..<2 {
            let before = keys.map { dataSource.data(forKey: $0) }
            var notices: [String] = []
            func decode<T: Decodable>(_ type: T.Type, index: Int, name: String, missing: T) throws -> T {
                guard let data = before[index] else {
                    notices.append("\(name)数据尚未建立；未写入默认值。")
                    return missing
                }
                do { return try JSONDecoder().decode(type, from: data) }
                catch { throw CatalogError.message("\(name)数据无法读取；未恢复备份或改写原数据。") }
            }
            let campaigns = try decode([ZhuowangCampaign].self, index: 0, name: "活动", missing: [])
            let workspace = try decode(ZhuowangWorkspaceSnapshot.self, index: 1, name: "工作区",
                missing: ZhuowangWorkspaceSnapshot(modules: [], provinces: [], categories: []))
            let workflows = try decode([ZhuowangCampaignWorkflow].self, index: 2, name: "Workflow", missing: [])
            // Provider labels are optional; malformed labels do not hide assets.
            let providers = before[3].flatMap { try? JSONDecoder().decode([ZhuowangAIProvider].self, from: $0) } ?? []
            guard before == keys.map({ dataSource.data(forKey: $0) }) else { continue }
            let artifacts = workflows.flatMap(\.artifacts)
            guard Set(artifacts.map(\.id)).count == artifacts.count else {
                throw CatalogError.message("资产 ID 重复，无法可靠选择具体版本；请核对元数据。")
            }
            let groups = Dictionary(grouping: artifacts) { $0.campaignID.uuidString + "::" + $0.versionGroupKey }
            let entries = workflows.flatMap { workflow in
                workflow.artifacts.map { artifact in
                    let campaign = campaigns.first { $0.id == artifact.campaignID }
                    let province = workspace.provinces.first { $0.id == campaign?.provinceID }
                    let module = workspace.modules.first { $0.id == campaign?.moduleID }
                    let providerID = artifact.providerID ?? workflow.aiRuns.first { $0.id == artifact.runID }?.providerID
                    return ZhuowangAssetEntry(artifact: artifact,
                        campaignName: campaign?.name ?? "所属活动缺失",
                        provinceID: campaign?.provinceID,
                        scopeName: province?.name ?? module?.name ?? (campaign == nil ? "关联缺失" : "全国及其他 / 省份未关联"),
                        stepName: workflow.steps.first { $0.id == artifact.stepID && workflow.campaignID == artifact.campaignID }?.title ?? "Step 未关联或缺失",
                        providerName: providers.first { $0.id == providerID }?.name,
                        adoptedCount: groups[artifact.campaignID.uuidString + "::" + artifact.versionGroupKey]?.filter(\.isApprovedVersion).count ?? 0)
                }
            }.sorted {
                if $0.artifact.updatedAt != $1.artifact.updatedAt { return $0.artifact.updatedAt > $1.artifact.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
            return ZhuowangAssetCatalogSnapshot(entries: entries, provinces: workspace.provinces,
                campaigns: campaigns, notices: notices)
        }
        throw CatalogError.message("读取期间数据发生变化；请刷新。未发布不一致快照。")
    }

    enum CatalogError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
    }
}
