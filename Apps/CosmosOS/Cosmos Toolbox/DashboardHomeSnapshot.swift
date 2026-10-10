import Foundation

// These read-only projections deliberately carry no bodies, histories or editing Stores.
nonisolated enum DashboardHomeSource<Value: Sendable>: Sendable {
    case loaded(Value), missing, failed(String)
    var value: Value? { if case .loaded(let value) = self { return value }; return nil }
    var error: String? { if case .failed(let text) = self { return text }; return nil }
}
nonisolated struct DashboardHomeCampaign: Decodable, Sendable {
    let id: UUID; let name: String; let scopeType: String; let provinceID: UUID?; let moduleID: String?
    let startDate: Date; let endDate: Date; let updatedAt: Date
}
nonisolated struct DashboardHomeWorkflow: Decodable, Sendable {
    struct Step: Decodable, Sendable { let isEnabled: Bool; let status: String }
    let campaignID: UUID; let steps: [Step]
}
nonisolated struct DashboardHomeWorkspace: Decodable, Sendable {
    struct Province: Decodable, Sendable { let id: UUID; let name: String; let isEnabled: Bool? }
    struct Module: Decodable, Sendable { let id: String; let name: String }
    let provinces: [Province]; let modules: [Module]
}
nonisolated struct DashboardHomeBar: Identifiable, Equatable, Sendable {
    let id: String; let label: String; let count: Int
}
nonisolated struct DashboardHomeRecent: Identifiable, Equatable, Sendable {
    var id: UnifiedSearchID { row.id }
    let row: UnifiedSearchRow; let updatedAt: Date
}
nonisolated struct DashboardHomeData: Sendable {
    var total: Int? = 0
    var ongoing: Int? = 0
    var attention: Int? = 0
    var noteCount: Int? = 0
    var promptCount: Int? = 0
    var learningCount: Int? = 0
    var distribution: [DashboardHomeBar] = []
    var workflow: [DashboardHomeBar] = []
    var weeks: [DashboardHomeBar] = []
    var recent: [DashboardHomeRecent] = []
    var errors: [String: String] = [:]
    var campaignBytes: Data?
    var workflowBytes: Data?
    var workspaceBytes: Data?
    var deliveryError: String?
    var readAt: Date?
}

nonisolated enum DashboardHomeAggregation {
    static func project(campaigns: DashboardHomeSource<[DashboardHomeCampaign]>,
                        workflows: DashboardHomeSource<[DashboardHomeWorkflow]>,
                        workspace: DashboardHomeSource<DashboardHomeWorkspace>,
                        prompts: DashboardHomeSource<[PromptTemplate]>,
                        notes: DashboardHomeSource<[PersonalNote]>,
                        learning: DashboardHomeSource<LearningSnapshot>, now: Date, calendar: Calendar) -> DashboardHomeData {
        var result = DashboardHomeData(); result.readAt = now
        let all = campaigns.value ?? []
        if let error = campaigns.error { result.total = nil; result.ongoing = nil; result.attention = nil; result.errors["campaigns"] = error }
        else {
            result.total = all.count
            let today = calendar.startOfDay(for: now)
            result.ongoing = all.filter {
                let start = calendar.startOfDay(for: $0.startDate)
                return start <= today && today <= max(start, calendar.startOfDay(for: $0.endDate))
            }.count
        }
        if let error = workflows.error { result.attention = nil; result.errors["workflow"] = error }
        else if campaigns.error == nil {
            let byCampaign = Dictionary((workflows.value ?? []).map { ($0.campaignID, $0) }, uniquingKeysWith: { first, _ in first })
            result.attention = all.filter { campaign in
                (byCampaign[campaign.id]?.steps ?? []).contains { $0.isEnabled && ["failed", "needsRevision"].contains($0.status) }
            }.count
            let ids = Set(all.map(\.id))
            let steps = byCampaign.values.filter { ids.contains($0.campaignID) }.flatMap { $0.steps.filter(\.isEnabled) }
            let titles = [("notStarted", "未开始"), ("ready", "可开始"), ("running", "生成中"), ("waitingForApproval", "等待确认"), ("approved", "已确认"), ("completed", "已完成"), ("failed", "失败"), ("needsRevision", "需修改"), ("skipped", "已跳过")]
            result.workflow = titles.compactMap { key, title in
                let count = steps.filter { $0.status == key }.count
                return count == 0 ? nil : DashboardHomeBar(id: key, label: title, count: count)
            }
        }
        if let error = workspace.error { result.errors["distribution"] = error }
        else if campaigns.error == nil {
            let provinces = workspace.value?.provinces ?? [], modules = workspace.value?.modules ?? []
            let groups = Dictionary(grouping: all) { campaign -> String in
                if let id = campaign.provinceID { return "province:" + id.uuidString }
                if let id = campaign.moduleID { return "module:" + id }
                return campaign.scopeType
            }
            result.distribution = groups.map { key, rows in
                let first = rows[0]
                let label: String
                if let id = first.provinceID {
                    if let province = provinces.first(where: { $0.id == id }) { label = province.name + (province.isEnabled == false ? "（已停用）" : "") }
                    else { label = "未知省份" }
                } else if let id = first.moduleID { label = modules.first { $0.id == id }?.name ?? "未知模块" }
                else { label = first.scopeType == "national" ? "全国" : "其他" }
                return DashboardHomeBar(id: key, label: label, count: rows.count)
            }.sorted { $0.count == $1.count ? $0.id < $1.id : $0.count > $1.count }
        }
        var recent: [DashboardHomeRecent] = all.map {
            DashboardHomeRecent(row: UnifiedSearchRow(id: UnifiedSearchID(source: .campaign, objectID: $0.id), name: $0.name, ownership: "卓望工作", fields: [], campaignID: $0.id), updatedAt: $0.updatedAt)
        }
        if let error = prompts.error { result.promptCount = nil; result.errors["prompts"] = error }
        else {
            let active = (prompts.value ?? []).filter { !$0.isArchived }; result.promptCount = active.count
            recent += active.map { DashboardHomeRecent(row: UnifiedSearchRow(id: UnifiedSearchID(source: .prompt, objectID: $0.id), name: $0.name, ownership: $0.category ?? "提示词库", fields: []), updatedAt: $0.updatedAt) }
        }
        if let error = notes.error { result.noteCount = nil; result.errors["notes"] = error }
        else {
            let active = (notes.value ?? []).filter { !$0.isArchived }; result.noteCount = active.count
            recent += active.map { DashboardHomeRecent(row: UnifiedSearchRow(id: UnifiedSearchID(source: .note, objectID: $0.id), name: $0.title, ownership: $0.category ?? "个人笔记", fields: []), updatedAt: $0.updatedAt) }
        }
        result.recent = Array(recent.sorted { $0.updatedAt == $1.updatedAt ? $0.id.objectID.uuidString < $1.id.objectID.uuidString : $0.updatedAt > $1.updatedAt }.prefix(8))
        if let error = learning.error { result.learningCount = nil; result.errors["learning"] = error }
        else {
            let snapshot = learning.value ?? LearningSnapshot()
            let activeIDs = Set(snapshot.topics.filter { !$0.isArchived }.map(\.id))
            let today = calendar.startOfDay(for: now)
            let since = calendar.date(byAdding: .day, value: -6, to: today)!
            let entries = snapshot.entries.filter { activeIDs.contains($0.topicID) && $0.studyDay.date(timeZone: calendar.timeZone) < calendar.date(byAdding: .day, value: 1, to: today)! }
            result.learningCount = entries.filter { $0.studyDay.date(timeZone: calendar.timeZone) >= since }.count
            let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)!.start
            result.weeks = (0..<8).map { index in
                let start = calendar.date(byAdding: .weekOfYear, value: index - 7, to: currentWeek)!
                let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
                let label = start.formatted(.dateTime.month(.defaultDigits).day().locale(Locale(identifier: "zh_CN")))
                return DashboardHomeBar(id: String(index), label: label, count: entries.filter {
                    let date = $0.studyDay.date(timeZone: calendar.timeZone); return start <= date && date < end
                }.count)
            }
        }
        result.deliveryError = campaigns.error ?? workflows.error ?? workspace.error
        return result
    }
}

nonisolated struct DashboardHomeReader {
    let readPreference: @Sendable (String) throws -> Data?
    let prompts: URL?; let notes: URL?; let learning: URL?
    let blocked: [String: String]
    static let keys = ["cosmos.zhuowang.campaigns.v1", "cosmos.zhuowang.workflows.v1", "cosmos.zhuowang.workspace.v1"]
    func load(now: Date, calendar: Calendar) async -> DashboardHomeData {
        async let promptData = loadPrompts()
        async let noteData = loadNotes()
        async let learningData = loadLearning()
        let core = await Task.detached(priority: .userInitiated) {
            Self.keys.map { key -> DashboardHomeSource<Data> in
                do {
                    let first = try readPreference(key), second = try readPreference(key)
                    guard first == second else { return .failed("读取期间数据变化，请刷新") }
                    guard let first else {
                        if try readPreference(key + ".backup") != nil { return .failed("主数据缺失但已有备份；未恢复或初始化") }
                        return .missing
                    }
                    guard first.count <= UnifiedSearchReader.limit else { return .failed("来源超过 16 MiB") }
                    return .loaded(first)
                } catch { return .failed(error.localizedDescription) }
            }
        }.value
        let p = await promptData, n = await noteData, l = await learningData
        return await Task.detached(priority: .userInitiated) {
            func decode<T: Decodable & Sendable>(_ type: T.Type, _ source: DashboardHomeSource<Data>, id: String) -> DashboardHomeSource<T> {
                switch source {
                case .missing: return .missing
                case .failed(let error): return .failed(error)
                case .loaded(let data):
                    do { try CoreBackupSource.validated(data, id: id); return .loaded(try JSONDecoder().decode(type, from: data)) }
                    catch { return .failed(error.localizedDescription) }
                }
            }
            let c = decode([DashboardHomeCampaign].self, core[0], id: "campaigns")
            let w = decode([DashboardHomeWorkflow].self, core[1], id: "workflows")
            let space = decode(DashboardHomeWorkspace.self, core[2], id: "workspace")
            var result = DashboardHomeAggregation.project(campaigns: c, workflows: w, workspace: space, prompts: p, notes: n, learning: l, now: now, calendar: calendar)
            result.campaignBytes = c.error == nil ? core[0].value : nil
            result.workflowBytes = w.error == nil ? core[1].value : nil
            result.workspaceBytes = space.error == nil ? core[2].value : nil
            return result
        }.value
    }
    private func loadPrompts() async -> DashboardHomeSource<[PromptTemplate]> {
        guard let prompts else { return .failed(blocked["prompts"] ?? "提示词位置不可用") }
        do { return .loaded(try await PromptVaultFileStorage(root: prompts).load()) } catch { return .failed(error.localizedDescription) }
    }
    private func loadNotes() async -> DashboardHomeSource<[PersonalNote]> {
        guard let notes else { return .failed(blocked["notes"] ?? "笔记位置不可用") }
        do { return .loaded(try await PersonalNotesFileStorage(root: notes).load().notes) } catch { return .failed(error.localizedDescription) }
    }
    private func loadLearning() async -> DashboardHomeSource<LearningSnapshot> {
        guard let learning else { return .failed(blocked["learning"] ?? "学习位置不可用") }
        do { return .loaded(try await LearningFileStorage(root: learning).load()) } catch { return .failed(error.localizedDescription) }
    }
}

extension DashboardDecoding {
    nonisolated static func workspace(_ data: Data) -> ZhuowangWorkspaceSnapshot? { try? JSONDecoder().decode(ZhuowangWorkspaceSnapshot.self, from: data) }
}
