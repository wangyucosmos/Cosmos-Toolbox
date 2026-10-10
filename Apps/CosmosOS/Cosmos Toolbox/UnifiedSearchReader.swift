import Foundation

/// Decode only searchable fields. JSON containers are read, but bodies, runs and histories
/// are not decoded, retained in the projection or searched. No business Store is constructed.
nonisolated struct UnifiedSearchReader {
    let readPreference: @Sendable (String) throws -> Data?
    let roots: [UnifiedSearchSource: URL]
    var blocked: [UnifiedSearchSource: String] = [:]
    static let limit = 16 * 1024 * 1024

    private struct Campaign: Decodable {
        let id: UUID; let name: String; let notes: String
        let provinceID: UUID?; let moduleID: String?
    }
    private struct ReferenceOwner: Decodable { let id: UUID; let externalReferences: [CampaignExternalReference]? }
    private struct NamedID: Decodable { let id: UUID; let name: String }
    private struct Module: Decodable { let id: String; let name: String }
    private struct Workspace: Decodable { let provinces: [NamedID]; let modules: [Module] }
    private struct Artifact: Decodable {
        let id: UUID; let campaignID: UUID; let name: String; let type: String
        let logicalKey: String?; let version: Int; let isApprovedVersion: Bool
        var group: String {
            let key = logicalKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return campaignID.uuidString + "::" + (key.isEmpty ? name : key)
        }
    }
    private struct Workflow: Decodable { let id: UUID; let campaignID: UUID; let artifacts: [Artifact] }
    private struct Project: Decodable {
        let id: UUID; let name: String; let goal: String; let nextStep: String; let isArchived: Bool
    }
    private struct ProjectDocument: Decodable { let schemaVersion: Int; let projects: [Project] }
    private struct Prompt: Decodable {
        let id: UUID; let name: String; let category: String?; let isArchived: Bool?
    }
    private struct PromptDocument: Decodable { let schemaVersion: Int; let templates: [Prompt] }
    private struct Topic: Decodable {
        let id: UUID; let name: String; let goal: String?; let nextStep: String?; let isArchived: Bool?
    }
    private struct LearningDocument: Decodable { let schemaVersion: Int; let topics: [Topic] }
    private enum ReadError: LocalizedError {
        case invalid(String)
        var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
    }

    private func preference(_ key: String) throws -> Data? {
        let before = try readPreference(key)
        if before == nil, try readPreference(key + ".backup") != nil {
            throw ReadError.invalid("主数据缺失但备份存在；未恢复或重建。")
        }
        guard before == (try readPreference(key)) else { throw ReadError.invalid("读取期间数据变化，请刷新。") }
        if let before, before.count > Self.limit { throw ReadError.invalid("元数据超过 16 MiB，未截断。") }
        return before
    }
    private func file(_ source: UnifiedSearchSource, name: String) throws -> Data? {
        if let reason = blocked[source] { throw ReadError.invalid(reason) }
        guard let root = roots[source] else { throw ReadError.invalid("缺少明确存储根，未回退正式位置。") }
        let value = try CoreBackupService.readFile(root.appendingPathComponent(name + ".json"), limit: Self.limit)
        if value == nil, try CoreBackupService.readFile(root.appendingPathComponent(name + ".backup.json"), limit: Self.limit) != nil {
            throw ReadError.invalid("主数据缺失但备份存在；未恢复或重建。")
        }
        return value?.0
    }
    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        guard !data.contains(0), String(data: data, encoding: .utf8) != nil else { throw ReadError.invalid("不是有效 UTF-8 元数据。") }
        return try JSONDecoder().decode(type, from: data)
    }
    private func unique(_ ids: [UUID]) throws {
        guard Set(ids).count == ids.count else { throw ReadError.invalid("稳定身份重复，无法可靠导航。") }
    }
    func read() -> UnifiedSearchSnapshot {
        var result = UnifiedSearchSnapshot()
        func load<T>(_ sources: [UnifiedSearchSource], _ operation: () throws -> T?) -> T? {
            do {
                let value = try operation()
                for source in sources { result.states[source] = value == nil ? .missing : .ready }
                return value
            } catch {
                for source in sources { result.states[source] = .failed(error.localizedDescription) }
                return nil
            }
        }
        let campaigns: [Campaign] = load([.campaign]) {
            guard let data = try preference("cosmos.zhuowang.campaigns.v1") else { return nil }
            let values = try decode([Campaign].self, data); try unique(values.map(\.id))
            return values
        } ?? []
        var workspace: Workspace?
        do {
            if let data = try preference("cosmos.zhuowang.workspace.v1") {
                let value = try decode(Workspace.self, data); try unique(value.provinces.map(\.id))
                guard Set(value.modules.map(\.id)).count == value.modules.count else { throw ReadError.invalid("模块身份重复。") }
                workspace = value
            } else { result.notices.append("省份/模块归属数据尚未建立；不会按名称猜关联。") }
        } catch { result.notices.append("省份/模块归属无法读取：" + error.localizedDescription) }
        func scope(_ campaign: Campaign?) -> String {
            guard let campaign else { return "所属活动缺失或不可读取" }
            if let id = campaign.provinceID {
                return workspace?.provinces.first { $0.id == id }?.name ?? "省份归属不可用（\(id.uuidString)）"
            }
            if let id = campaign.moduleID { return workspace?.modules.first { $0.id == id }?.name ?? "模块归属不可用（\(id)）" }
            return "全国及其他 / 未关联模块"
        }
        func field(_ label: String, _ text: String) -> UnifiedSearchField { .init(label: label, text: text) }
        for campaign in campaigns {
            result.rows.append(.init(id: .init(source: .campaign, objectID: campaign.id), name: campaign.name,
                ownership: scope(campaign), fields: [field("名称", campaign.name), field("活动说明", campaign.notes)], campaignID: campaign.id))
        }
        let owners: [ReferenceOwner] = load([.reference]) {
            guard let data = try preference("cosmos.zhuowang.campaigns.v1") else { return nil }
            let values = try decode([ReferenceOwner].self, data)
            try unique(values.map(\.id))
            let refs = values.flatMap { $0.externalReferences ?? [] }; try unique(refs.map(\.id))
            guard values.allSatisfy({ owner in (owner.externalReferences ?? []).allSatisfy { $0.campaignID == owner.id && $0.isValid } }) else {
                throw ReadError.invalid("引用记录的身份、归属或格式无效。")
            }
            return values
        } ?? []
        for owner in owners {
            let campaign = campaigns.first { $0.id == owner.id }
            for ref in owner.externalReferences ?? [] {
                result.rows.append(.init(id: .init(source: .reference, objectID: ref.id), name: ref.name,
                    ownership: (campaign?.name ?? "活动名称不可读取（\(owner.id.uuidString)）") + " · " + scope(campaign),
                    fields: [field("名称", ref.name), field("版本标签", ref.versionLabel), field("备注", ref.notes), field("位置", ref.location)],
                    campaignID: owner.id, reference: ref))
            }
        }
        let workflows: [Workflow] = load([.artifact]) {
            guard let data = try preference("cosmos.zhuowang.workflows.v1") else { return nil }
            let values = try decode([Workflow].self, data)
            try unique(values.map(\.id)); try unique(values.map(\.campaignID)); try unique(values.flatMap(\.artifacts).map(\.id))
            guard values.allSatisfy({ workflow in workflow.artifacts.allSatisfy { $0.campaignID == workflow.campaignID } }) else {
                throw ReadError.invalid("Artifact 的活动关联与 Workflow 不一致。")
            }
            return values
        } ?? []
        let artifacts = workflows.flatMap(\.artifacts)
        let adopted = Dictionary(grouping: artifacts, by: \.group).mapValues { $0.filter(\.isApprovedVersion).count }
        let missingAdoption = Set(artifacts.filter { adopted[$0.group] == 0 }.map(\.group)).count
        if missingAdoption > 0 { result.notices.append("Artifact 有 \(missingAdoption) 个未采用组，默认隐藏；勾选历史版本查看。") }
        if adopted.values.contains(where: { $0 > 1 }) { result.notices.append("Artifact 存在采用冲突；冲突组保留全部版本并明确标识，不自动选择。") }
        for artifact in artifacts {
            let campaign = campaigns.first { $0.id == artifact.campaignID }
            let type = Self.typeTitle(artifact.type)
            result.rows.append(.init(id: .init(source: .artifact, objectID: artifact.id), name: artifact.name,
                ownership: (campaign?.name ?? "活动缺失或不可读取") + " · " + scope(campaign) + " · V\(artifact.version)",
                fields: [field("名称", artifact.name), field("类型", type + " / " + artifact.type), field("活动", campaign?.name ?? ""), field("省份/模块", scope(campaign))],
                historical: !artifact.isApprovedVersion, adoptionConflict: (adopted[artifact.group] ?? 0) > 1, campaignID: artifact.campaignID))
        }
        let projects: [Project] = load([.project]) {
            guard let data = try file(.project, name: "projects") else { return nil }
            let doc = try decode(ProjectDocument.self, data)
            guard doc.schemaVersion == 1 else { throw ReadError.invalid("项目库版本不受支持。") }
            try unique(doc.projects.map(\.id)); return doc.projects
        } ?? []
        result.rows += projects.map { .init(id: .init(source: .project, objectID: $0.id), name: $0.name,
            ownership: "个人项目", fields: [field("名称", $0.name), field("目标", $0.goal), field("下一步", $0.nextStep)], archived: $0.isArchived) }
        let prompts: [Prompt] = load([.prompt]) {
            guard let data = try file(.prompt, name: "templates") else { return nil }
            let doc = try decode(PromptDocument.self, data)
            guard doc.schemaVersion == 1 else { throw ReadError.invalid("提示词库版本不受支持。") }
            try unique(doc.templates.map(\.id)); return doc.templates
        } ?? []
        result.rows += prompts.map { .init(id: .init(source: .prompt, objectID: $0.id), name: $0.name,
            ownership: $0.category ?? "未分类", fields: [field("名称", $0.name), field("分类", $0.category ?? "")], archived: $0.isArchived ?? false) }
        let topics: [Topic] = load([.learning]) {
            guard let data = try file(.learning, name: "learning") else { return nil }
            let doc = try decode(LearningDocument.self, data)
            guard doc.schemaVersion == 1 else { throw ReadError.invalid("学习库版本不受支持。") }
            try unique(doc.topics.map(\.id)); return doc.topics
        } ?? []
        result.rows += topics.map { .init(id: .init(source: .learning, objectID: $0.id), name: $0.name,
            ownership: "学习主题", fields: [field("名称", $0.name), field("目标", $0.goal ?? ""), field("下一步", $0.nextStep ?? "")], archived: $0.isArchived ?? false) }
        result.rows.sort { $0.id.source.rawValue == $1.id.source.rawValue ? $0.id.objectID.uuidString < $1.id.objectID.uuidString : $0.id.source.rawValue < $1.id.source.rawValue }
        return result
    }
    private static func typeTitle(_ type: String) -> String {
        ["markdown": "Markdown", "word": "Word", "pdf": "PDF", "excel": "Excel", "image": "图片", "figma": "Figma", "html": "HTML", "flowchart": "流程图", "prompt": "提示词", "url": "链接", "other": "其他"][type] ?? type
    }
}
