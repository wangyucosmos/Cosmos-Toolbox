import Foundation
import Darwin

/// Explicit source list: never initializes a Store or scans a preference domain.
nonisolated struct CoreBackupSource {
    static let legacyIDs = ["campaigns", "workspace", "workflows", "providers", "connections", "tools", "routes", "prompts", "learning", "handoffs"]
    /// V2 增加 projects；V3 增加 notes。旧包按其版本的固定源清单校验，不把新源硬套到旧包。
    static let idsV2 = legacyIDs + ["projects"]
    static let ids = idsV2 + ["notes"]
    static func ids(forVersion version: Int) -> [String] {
        switch version { case 1: return legacyIDs; case 2: return idsV2; default: return ids }
    }
    static let keys = ["cosmos.zhuowang.campaigns.v1", "cosmos.zhuowang.workspace.v1", "cosmos.zhuowang.workflows.v1",
        "cosmos.zhuowang.ai.providers.v1", "cosmos.zhuowang.ai.connections.v1", "cosmos.zhuowang.ai.toolIntegrations.v1", "cosmos.zhuowang.ai.agentToolRoutes.v1"]
    static let exclusions = ["活动引用仅备份登记记录，不含原文件或网页；产物实体文件、外部知识库、源码仓库、Evidence/Quarantine、Word WIP、系统/工具环境不包含；登记路径仍依赖原文件。",
        "不读取 Keychain、认证文件或凭据；不整域导出 UserDefaults。",
        "Provider 排除 configurationIdentifier 和未知字段；Connection/Tool/Route 排除 configuration、endpointOrPath、adapterIdentifier、notes 和未知字段（不判断自由配置是否含凭据）。"]
    /// V3 新增：个人笔记引用只备份登记记录。V1/V2 的排除说明保持原文，旧包校验不变。
    static let notesExclusion = "个人笔记的文件/链接引用只备份登记记录（名称、位置、更正说明），不含文件实体或网页内容；笔记正文与全部内容历史随包保存。"
    static let currentExclusions = exclusions + [notesExclusion]
    static func exclusions(forVersion version: Int) -> [String] { version >= 3 ? currentExclusions : exclusions }
    static let fileRootCount = 5
    let readPreference: (String) throws -> Data?
    let fileRoots: [URL]
    let isolationError: String?

    @MainActor init(configuration: ZhuowangStorePersistenceConfiguration, promptRoot: URL?, learningRoot: URL?, handoffRoot: URL?, projectsRoot: URL?, notesRoot: URL?) {
        let dataSource = configuration.dataSource
        readPreference = { key in
            if let source = dataSource as? ZhuowangUserDefaultsDataSource { return try source.coreBackupData(forKey: key) }
            return dataSource.data(forKey: key)
        }
        fileRoots = [promptRoot, learningRoot, handoffRoot, projectsRoot, notesRoot].compactMap { $0 }
        isolationError = fileRoots.count == Self.fileRootCount ? nil : "文件存储位置或隔离配置不可用；导出已停止，不回退正式目录。"
    }

    init(readPreference: @escaping (String) throws -> Data?, fileRoots: [URL]) {
        self.readPreference = readPreference; self.fileRoots = fileRoots
        isolationError = fileRoots.count == Self.fileRootCount ? nil : "缺少明确存储根。"
    }

    struct Snapshot: Equatable {
        var data: [Data?]
        var revisions: [String?]
    }

    func capture() throws -> Snapshot {
        if let isolationError { throw CoreBackupError.invalid(isolationError) }
        var data = [Data?](), revisions = [String?]()
        for key in Self.keys {
            let raw = try readPreference(key)
            if raw == nil, try readPreference(key + ".backup") != nil {
                throw CoreBackupError.invalid("\(Self.ids[data.count]) 主数据缺失但已有备份；未恢复，也不以空数据替代。")
            }
            if let raw, raw.count > CoreBackupService.sourceLimit { throw CoreBackupError.invalid("数据源超过 16 MiB。") }
            data.append(raw); revisions.append(nil)
        }
        let names = ["templates", "learning", "handoffs", "projects", "notes"]
        for (index, root) in fileRoots.enumerated() {
            let file = root.appendingPathComponent(names[index] + ".json")
            let value = try CoreBackupService.readFile(file, limit: CoreBackupService.sourceLimit)
            if value == nil, try CoreBackupService.readFile(root.appendingPathComponent(names[index] + ".backup.json"), limit: CoreBackupService.sourceLimit) != nil {
                throw CoreBackupError.invalid("\(Self.ids[7 + index]) 主文件缺失但已有备份；未恢复或重建。")
            }
            data.append(value?.0); revisions.append(value?.1)
        }
        return Snapshot(data: data, revisions: revisions)
    }

    static func validated(_ data: Data, id: String) throws {
        guard !data.contains(0), String(data: data, encoding: .utf8) != nil else { throw CoreBackupError.invalid("\(id)：不是有效 UTF-8 JSON。") }
        let decoder = JSONDecoder()
        func unique<T: Identifiable>(_ values: [T]) throws where T.ID: Hashable {
            guard Set(values.map(\.id)).count == values.count else { throw CoreBackupError.invalid("\(id)：重复身份。") }
        }
        do {
            switch id {
            case "campaigns":
                let campaigns = try decoder.decode([ZhuowangCampaign].self, from: data)
                try unique(campaigns)
                for campaign in campaigns {
                    let records = campaign.referenceRecords
                    try unique(records)
                    guard records.allSatisfy({ $0.campaignID == campaign.id && $0.isValid }) else {
                        throw CoreBackupError.invalid("活动引用结构无效。")
                    }
                    var preceding = Set<UUID>()
                    for record in records {
                        if let corrected = record.correctsReferenceID, !preceding.contains(corrected) {
                            throw CoreBackupError.invalid("更正引用的历史目标无效。")
                        }
                        preceding.insert(record.id)
                    }
                }
            case "workspace":
                let value = try decoder.decode(ZhuowangWorkspaceSnapshot.self, from: data)
                try unique(value.provinces); try unique(value.modules); try unique(value.categories)
            case "workflows":
                let values = try decoder.decode([ZhuowangCampaignWorkflow].self, from: data)
                try unique(values)
                guard Set(values.map(\.campaignID)).count == values.count else { throw CoreBackupError.invalid("Workflow 活动关联重复。") }
                for value in values { try unique(value.steps); try unique(value.artifacts); try unique(value.aiRuns); try unique(value.approvals) }
            case "providers": try unique(decoder.decode([ZhuowangAIProvider].self, from: data))
            case "connections": try unique(decoder.decode([ZhuowangAIConnection].self, from: data))
            case "tools": try unique(decoder.decode([ZhuowangExternalToolIntegration].self, from: data))
            case "routes": try unique(decoder.decode([ZhuowangAgentToolRoute].self, from: data))
            case "prompts": try decoder.decode(PromptVaultDocument.self, from: data).validate()
            case "learning":
                decoder.dateDecodingStrategy = .custom { decoder in
                    let value = try decoder.singleValueContainer().decode(String.self)
                    let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = formatter.date(from: value) { return date }
                    formatter.formatOptions = [.withInternetDateTime]
                    guard let date = formatter.date(from: value) else { throw CoreBackupError.invalid("学习记录日期格式无效。") }
                    return date
                }
                try decoder.decode(LearningDocument.self, from: data).validate()
            case "projects": try ProjectsCoding.decoder().decode(ProjectsDocument.self, from: data).validate()
            case "notes": try PersonalNotesCoding.decoder().decode(PersonalNotesDocument.self, from: data).validate()
            case "handoffs": try decoder.decode(AIWorkspaceHandoffDocument.self, from: data).validate()
            default: throw CoreBackupError.invalid("未知数据源。")
            }
        } catch { throw CoreBackupError.invalid("\(id)：必要数据结构无法解析或校验；未发布完整备份。") }
    }

    static let configurationFields: [String: Set<String>] = [
        "providers": ["id", "name", "kind", "modelName", "isEnabled", "isVisible", "createdAt", "updatedAt"],
        "connections": ["id", "providerID", "name", "mode", "status", "executionStyle", "capabilities", "allowsAutomaticSelection", "supportsDirectExecution", "supportsAutomaticResultReturn", "isEnabled", "createdAt", "updatedAt"],
        "tools": ["id", "kind", "name", "status", "mode", "capabilities", "isEnabled", "createdAt", "updatedAt"],
        "routes": ["id", "connectionID", "toolIntegrationID", "status", "executionMode", "supportsDirectExecution", "supportsAutomaticResultReturn", "createdAt", "updatedAt"]]

    static func sanitized(_ raw: Data, id: String) throws -> Data {
        try validated(raw, id: id)
        guard let fields = configurationFields[id] else { return raw }
        guard let objects = try JSONSerialization.jsonObject(with: raw) as? [[String: Any]] else { throw CoreBackupError.invalid("配置结构无效。") }
        let safe = objects.map { $0.filter { fields.contains($0.key) } }
        let result = try JSONSerialization.data(withJSONObject: safe, options: [.sortedKeys, .prettyPrinted])
        try validated(result, id: id)
        return result
    }
}
