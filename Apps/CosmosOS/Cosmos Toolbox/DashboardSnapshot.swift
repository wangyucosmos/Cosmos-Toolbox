import Foundation

// MARK: - Source / section states

/// One read-only data source as the Dashboard sees it. The four states are
/// kept apart on purpose: "never created", "created but empty" (a `.loaded`
/// value that happens to be empty), "could not be read" and "blocked".
enum DashboardSource<Value> {
    case notBuilt
    case loaded(Value)
    case unreadable(String)
    case blocked(String)
}

enum DashboardSectionState<Value: Equatable>: Equatable {
    case notBuilt
    case loaded(Value)
    case unreadable(String)
    case blocked(String)
}

// MARK: - Raw data (decoded, not yet projected)

struct DashboardRaw {
    /// Time of this read. It is the snapshot time, not a data update time.
    var readAt: Date
    var campaigns: DashboardSource<[ZhuowangCampaign]>
    var workflows: DashboardSource<[ZhuowangCampaignWorkflow]>
    var workspace: DashboardSource<ZhuowangWorkspaceSnapshot>
    var prompts: DashboardSource<[PromptTemplate]>
    var learning: DashboardSource<LearningSnapshot>
}

// MARK: - Projected rows

enum DashboardActivityGroup: Int, Equatable {
    case needsAttention, awaitingReview, readyForNextStep, workflowNotCreated, noEnabledSteps, workflowUnreadable

    var title: String {
        switch self {
        case .needsAttention: return "失败或需修改"
        case .awaitingReview: return "生成中 / 待确认"
        case .readyForNextStep: return "下一步可推进"
        case .workflowNotCreated: return "Workflow 尚未创建"
        case .noEnabledSteps: return "没有启用的步骤"
        case .workflowUnreadable: return "Workflow 无法读取"
        }
    }
}

struct DashboardActivityRow: Identifiable, Equatable {
    let id: UUID
    let name: String
    let scopeName: String
    let group: DashboardActivityGroup
    /// One line grounded in the Workflow step states.
    let detail: String
    /// "x/y" over the *enabled* steps, `nil` when there is no progress to show.
    let progress: String?
    /// Calendar position of the Campaign's own start / end dates; not a task deadline.
    let phaseText: String
}

struct DashboardActivities: Equatable {
    var rows: [DashboardActivityRow]
    /// Campaigns that belong in the list but did not fit the display limit.
    var hiddenCount: Int
    var totalCount: Int
    /// Campaign status "已结束" (counted only, not listed).
    var endedCount: Int
    /// All enabled steps approved / completed / skipped (counted only, not listed).
    var stepsAllConfirmedCount: Int
    var attentionCount: Int
    var workflowNotCreatedCount: Int
    var noEnabledStepsCount: Int
    /// The Workflow data could not be read: no progress or Workflow counts are shown.
    var workflowUnreadable: Bool
    var workspaceUnavailable: Bool
}

struct DashboardMonthlyItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let month: String
    let confirmedOutputs: Int
    let outputTotal: Int
    /// Ordinary inputs only (the prize-pool relation is reported separately).
    let inputsReceived: Int
    let inputsNotApplicable: Int
    let inputsRequested: Int
    let prizePool: ZhuowangPrizePoolRelation
    /// Workflow progress, kept apart from the monthly checklist and from ZIP delivery.
    let workflowLine: String
}

struct DashboardPromptRow: Identifiable, Equatable {
    let id: UUID
    let name: String
    let category: String
}

struct DashboardPrompts: Equatable {
    var rows: [DashboardPromptRow]
    var favoriteCount: Int
    var templateCount: Int
}

struct DashboardLearningRow: Identifiable, Equatable {
    let id: UUID
    let name: String
    let statusTitle: String
    let lastStudyText: String
    /// The user's own text, exactly as saved; `nil` when it has no non-whitespace content.
    let nextStep: String?
}

struct DashboardLearning: Equatable {
    var rows: [DashboardLearningRow]
    var learningCount: Int
    var plannedCount: Int
}

/// Everything the Home shows, projected from `DashboardRaw` for one point in time.
struct DashboardProjected: Equatable {
    var activities: DashboardSectionState<DashboardActivities>
    var monthly: DashboardSectionState<[DashboardMonthlyItem]>
    var prompts: DashboardSectionState<DashboardPrompts>
    var learning: DashboardSectionState<DashboardLearning>
}

// MARK: - Projection (pure; date-dependent parts take `now`)

enum DashboardProjection {

    static let activityLimit = 5
    static let monthlyLimit = 2
    static let promptLimit = 5
    static let learningLimit = 3

    private static let doneStatuses: Set<ZhuowangWorkflowStepStatus> = [.approved, .completed, .skipped]

    static func project(_ raw: DashboardRaw, now: Date, calendar: Calendar = .current) -> DashboardProjected {
        DashboardProjected(
            activities: activities(raw, now: now, calendar: calendar),
            monthly: monthly(raw),
            prompts: prompts(raw),
            learning: learning(raw, now: now, calendar: calendar)
        )
    }

    // MARK: Activities

    static func activities(_ raw: DashboardRaw, now: Date, calendar: Calendar) -> DashboardSectionState<DashboardActivities> {
        let campaigns: [ZhuowangCampaign]
        switch raw.campaigns {
        case .notBuilt: return .notBuilt
        case .unreadable(let reason): return .unreadable(reason)
        case .blocked(let reason): return .blocked(reason)
        case .loaded(let value): campaigns = value
        }

        var workflows: [ZhuowangCampaignWorkflow] = []
        var workflowUnreadable = false
        switch raw.workflows {
        case .loaded(let value): workflows = value
        case .notBuilt: workflows = []               // never created: Workflows genuinely do not exist yet
        case .unreadable, .blocked: workflowUnreadable = true   // a failure is not "not created"
        }

        var provinces: [ZhuowangProvince] = [], modules: [ZhuowangModule] = []
        var workspaceUnavailable = false
        if case .loaded(let workspace) = raw.workspace {
            provinces = workspace.provinces; modules = workspace.modules
        } else {
            workspaceUnavailable = true
        }

        let progress = ZhuowangCampaignProgressBuilder.build(
            campaigns: campaigns, workflows: workflows, provinces: provinces, modules: modules,
            now: now, calendar: calendar,
            // No file checks: the delivery counter is always zero, and the
            // delivery-dependent `category` / `nextActionText` are never used.
            deliverableCounter: { _, _, _, _ in 0 })

        var entries: [(row: DashboardActivityRow, updatedAt: Date, createdAt: Date)] = []
        var ended = 0, allConfirmed = 0, attention = 0, notCreated = 0, noSteps = 0

        for item in progress {
            let campaign = item.campaign
            let scope = workspaceUnavailable ? "范围信息不可用" : item.scopeName
            let isEnded = campaign.status == .completed
            if isEnded { ended += 1 }

            let group: DashboardActivityGroup
            var detail = ""
            var progressText: String?
            var complete = false

            if workflowUnreadable {
                group = .workflowUnreadable
                detail = "Workflow 数据无法读取，未显示进度（不等于尚未创建）"
            } else if !item.hasWorkflow {
                group = .workflowNotCreated
                detail = "Workflow 尚未创建"
                notCreated += 1
            } else if item.totalSteps == 0 {
                // Zero enabled steps is never reported as "done".
                group = .noEnabledSteps
                detail = "没有启用的 Workflow 步骤"
                noSteps += 1
            } else {
                progressText = "\(item.completedSteps)/\(item.totalSteps)"
                if !item.attentionSteps.isEmpty {
                    group = .needsAttention
                    detail = "处理 " + item.attentionSteps.map { "\($0.label)（\($0.status.title)）" }.joined(separator: "、")
                    attention += 1
                } else if let next = item.nextStep {
                    switch next.status {
                    case .running, .waitingForApproval:
                        group = .awaitingReview
                        detail = "\(next.label)：\(next.status.title)"
                    default:
                        group = .readyForNextStep
                        detail = next.status == .ready ? "开始 \(next.label)" : "\(next.label)（\(next.status.title)）"
                    }
                } else {
                    // Every enabled step is done; counted only, never listed.
                    group = .readyForNextStep
                    detail = "启用步骤均已确认"
                    complete = true
                    allConfirmed += 1
                }
            }

            guard !isEnded, !complete else { continue }
            entries.append((
                DashboardActivityRow(id: campaign.id, name: campaign.name, scopeName: scope, group: group,
                    detail: detail, progress: progressText, phaseText: "活动期：" + item.datePhase.title),
                campaign.updatedAt, campaign.createdAt))
        }

        entries.sort { lhs, rhs in
            if lhs.row.group.rawValue != rhs.row.group.rawValue { return lhs.row.group.rawValue < rhs.row.group.rawValue }
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.row.id.uuidString < rhs.row.id.uuidString
        }

        return .loaded(DashboardActivities(
            rows: Array(entries.prefix(activityLimit).map(\.row)),
            hiddenCount: max(0, entries.count - activityLimit),
            totalCount: campaigns.count,
            endedCount: ended,
            stepsAllConfirmedCount: allConfirmed,
            attentionCount: attention,
            workflowNotCreatedCount: notCreated,
            noEnabledStepsCount: noSteps,
            workflowUnreadable: workflowUnreadable,
            workspaceUnavailable: workspaceUnavailable))
    }

    // MARK: Monthly

    static func monthly(_ raw: DashboardRaw) -> DashboardSectionState<[DashboardMonthlyItem]> {
        let campaigns: [ZhuowangCampaign]
        switch raw.campaigns {
        case .notBuilt: return .notBuilt
        case .unreadable(let reason): return .unreadable(reason)
        case .blocked(let reason): return .blocked(reason)
        case .loaded(let value): campaigns = value
        }

        var workflowByCampaign: [UUID: ZhuowangCampaignWorkflow] = [:]
        var workflowState: DashboardSource<Void> = .notBuilt
        switch raw.workflows {
        case .loaded(let value):
            workflowByCampaign = Dictionary(value.map { ($0.campaignID, $0) }, uniquingKeysWith: { first, _ in first })
            workflowState = .loaded(())
        case .notBuilt: workflowState = .notBuilt
        case .unreadable(let reason): workflowState = .unreadable(reason)
        case .blocked(let reason): workflowState = .blocked(reason)
        }

        let monthly = campaigns.compactMap { campaign -> (ZhuowangCampaign, ZhuowangMonthlyPlan)? in
            campaign.monthly.map { (campaign, $0) }
        }.sorted { lhs, rhs in
            let a = ZhuowangActivityMonth(string: lhs.1.activityMonth), b = ZhuowangActivityMonth(string: rhs.1.activityMonth)
            switch (a, b) {
            case let (a?, b?) where a != b: return a > b
            case (.some, .none): return true
            case (.none, .some): return false
            default: break
            }
            // Same month (duplicates are allowed): newer Campaign first, then a stable id order.
            if lhs.0.createdAt != rhs.0.createdAt { return lhs.0.createdAt > rhs.0.createdAt }
            return lhs.0.id.uuidString < rhs.0.id.uuidString
        }

        let items = monthly.prefix(monthlyLimit).map { campaign, plan -> DashboardMonthlyItem in
            let receipts = ZhuowangMonthlyDefinition.inputs.filter { $0.kind == .receipt }
            var received = 0, notApplicable = 0, requested = 0
            for definition in receipts {
                switch plan.input(definition.key)?.status ?? .requested {
                case .received: received += 1
                case .notApplicable: notApplicable += 1
                case .requested: requested += 1
                }
            }
            let line: String
            switch workflowState {
            case .unreadable, .blocked: line = "Workflow 数据无法读取"
            case .notBuilt: line = "Workflow 尚未创建"
            case .loaded:
                if let workflow = workflowByCampaign[campaign.id] {
                    let enabled = workflow.steps.filter(\.isEnabled)
                    if enabled.isEmpty {
                        line = "没有启用的 Workflow 步骤"
                    } else {
                        let done = enabled.filter { doneStatuses.contains($0.status) }.count
                        line = "Workflow \(done)/\(enabled.count) 个启用步骤已确认"
                    }
                } else {
                    line = "Workflow 尚未创建"
                }
            }
            return DashboardMonthlyItem(
                id: campaign.id, name: campaign.name, month: plan.activityMonth,
                confirmedOutputs: ZhuowangMonthlyRules.confirmedOutputCount(plan),
                outputTotal: ZhuowangMonthlyDefinition.outputs.count,
                inputsReceived: received, inputsNotApplicable: notApplicable, inputsRequested: requested,
                prizePool: plan.prizePoolRelation, workflowLine: line)
        }
        return .loaded(Array(items))
    }

    // MARK: Prompts

    static func prompts(_ raw: DashboardRaw) -> DashboardSectionState<DashboardPrompts> {
        switch raw.prompts {
        case .notBuilt: return .notBuilt
        case .unreadable(let reason): return .unreadable(reason)
        case .blocked(let reason): return .blocked(reason)
        case .loaded(let templates):
            let favorites = templates.filter { $0.isFavorite && !$0.isArchived }.sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
            return .loaded(DashboardPrompts(
                rows: favorites.prefix(promptLimit).map {
                    DashboardPromptRow(id: $0.id, name: $0.name, category: $0.category ?? "未分类")
                },
                favoriteCount: favorites.count,
                templateCount: templates.filter { !$0.isArchived }.count))
        }
    }

    // MARK: Learning

    static func learning(_ raw: DashboardRaw, now: Date, calendar: Calendar) -> DashboardSectionState<DashboardLearning> {
        switch raw.learning {
        case .notBuilt: return .notBuilt
        case .unreadable(let reason): return .unreadable(reason)
        case .blocked(let reason): return .blocked(reason)
        case .loaded(let snapshot):
            let today = LearningDay.today(now: now, timeZone: calendar.timeZone)
            // Same ordering as the learning module: most recent study first; archived excluded there.
            let model = LearningViewModel(copy: { _ in false })
            let summaries = model.summaries(topics: snapshot.topics, entries: snapshot.entries)
                .filter { $0.topic.status != .completed }
            let active = snapshot.topics.filter { !$0.isArchived }
            return .loaded(DashboardLearning(
                rows: summaries.prefix(learningLimit).map { summary in
                    let topic = summary.topic
                    let last: String
                    if let entry = summary.lastEntry {
                        last = "上次学习：" + (entry.studyDay == today ? "今天" : entry.studyDay.string)
                    } else {
                        last = "尚无学习记录"
                    }
                    return DashboardLearningRow(
                        id: topic.id, name: topic.name, statusTitle: topic.status.title,
                        lastStudyText: last, nextStep: topic.hasNextStep ? topic.nextStep : nil)
                },
                learningCount: active.filter { $0.status == .learning }.count,
                plannedCount: active.filter { $0.status == .planned }.count))
        }
    }
}

// MARK: - Display state with stale-value handling

/// What a section currently shows. A failed refresh never presents old data as
/// freshly read: the last successful value is kept only together with its time
/// and the error.
struct DashboardSectionDisplay<Value: Equatable>: Equatable {
    var state: DashboardSectionState<Value>
    /// Snapshot time of the read that produced `state` when it is `.loaded`.
    var loadedAt: Date?
    var stale: DashboardStale<Value>?

    static var initial: Self { Self(state: .notBuilt, loadedAt: nil, stale: nil) }
}

struct DashboardStale<Value: Equatable>: Equatable {
    var value: Value
    var loadedAt: Date
}

struct DashboardDisplay: Equatable {
    /// Time of the last read attempt (a snapshot time, not a data update time).
    var readAt: Date?
    var hasLoaded = false
    var activities = DashboardSectionDisplay<DashboardActivities>.initial
    var monthly = DashboardSectionDisplay<[DashboardMonthlyItem]>.initial
    var prompts = DashboardSectionDisplay<DashboardPrompts>.initial
    var learning = DashboardSectionDisplay<DashboardLearning>.initial

    static func merged<V: Equatable>(
        previous: DashboardSectionDisplay<V>,
        new: DashboardSectionState<V>,
        readAt: Date
    ) -> DashboardSectionDisplay<V> {
        switch new {
        case .loaded:
            return DashboardSectionDisplay(state: new, loadedAt: readAt, stale: nil)
        case .unreadable:
            // Keep the last good value (if any), clearly marked as old.
            var stale = previous.stale
            if case .loaded(let value) = previous.state, let at = previous.loadedAt {
                stale = DashboardStale(value: value, loadedAt: at)
            }
            return DashboardSectionDisplay(state: new, loadedAt: nil, stale: stale)
        case .notBuilt, .blocked:
            return DashboardSectionDisplay(state: new, loadedAt: nil, stale: nil)
        }
    }

    func merging(_ projected: DashboardProjected, readAt: Date) -> DashboardDisplay {
        var next = self
        next.readAt = readAt
        next.hasLoaded = true
        next.activities = Self.merged(previous: activities, new: projected.activities, readAt: readAt)
        next.monthly = Self.merged(previous: monthly, new: projected.monthly, readAt: readAt)
        next.prompts = Self.merged(previous: prompts, new: projected.prompts, readAt: readAt)
        next.learning = Self.merged(previous: learning, new: projected.learning, readAt: readAt)
        return next
    }
}

// MARK: - Navigation targets

/// Cards only ever open an existing module; there is no shortcut into a Campaign
/// detail window (opening one runs recovery / migration code).
enum DashboardCard {
    case campaigns, monthly, prompts, learning

    var target: SidebarItem {
        switch self {
        case .campaigns, .monthly: return .zhuowang
        case .prompts: return .promptVault
        case .learning: return .learningCenter
        }
    }
}

// MARK: - Greeting (from the real clock)

enum DashboardGreeting {
    static func text(now: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: now) {
        case 5..<11: return "早上好"
        case 11..<13: return "中午好"
        case 13..<18: return "下午好"
        default: return "晚上好"
        }
    }

    static func dateText(now: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: now)
    }
}

// MARK: - Read-only reading

/// Last decoded values, reused only while the stored bytes are unchanged.
/// Date-dependent projections are always recomputed, never cached.
final class DashboardReadCache {
    var campaignsBytes: Data?
    var campaigns: [ZhuowangCampaign]?
    var workflowsBytes: Data?
    var workflows: [ZhuowangCampaignWorkflow]?
}

/// Pure decoders that run off the main actor.
nonisolated enum DashboardDecoding {
    static func campaigns(_ data: Data) -> [ZhuowangCampaign]? {
        try? JSONDecoder().decode([ZhuowangCampaign].self, from: data)
    }
    static func workflows(_ data: Data) -> [ZhuowangCampaignWorkflow]? {
        try? JSONDecoder().decode([ZhuowangCampaignWorkflow].self, from: data)
    }
}

enum DashboardLocation {
    case root(URL)
    case blocked(String)
}

/// Reads the persisted data of the finished modules without creating a single
/// business Store: nothing is written, restored, migrated or created, and no
/// directory is scanned. File-backed modules use their own read-only `load()`.
struct DashboardReader {
    let dataSource: any ZhuowangPersistenceDataSource
    let promptLocation: DashboardLocation
    let learningLocation: DashboardLocation

    private var keys: [String] {
        [ZhuowangCampaignStore.storageKey, ZhuowangWorkspaceStore.storageKey, ZhuowangWorkflowStore.workflowStorageKey]
    }

    /// Two back-to-back reads must agree; otherwise the data is changing under us.
    private func capture() -> [Data?]? {
        for _ in 0..<2 {
            let first = keys.map { dataSource.data(forKey: $0) }
            let second = keys.map { dataSource.data(forKey: $0) }
            if first == second { return first }
        }
        return nil
    }

    func load(cache: DashboardReadCache, now: Date) async -> DashboardRaw {
        let changing = "数据在读取期间发生变化；请稍后刷新"
        var campaigns: DashboardSource<[ZhuowangCampaign]> = .unreadable(changing)
        var workflows: DashboardSource<[ZhuowangCampaignWorkflow]> = .unreadable(changing)
        var workspace: DashboardSource<ZhuowangWorkspaceSnapshot> = .unreadable(changing)

        if let bytes = capture() {
            let campaignBytes = bytes[0], workspaceBytes = bytes[1], workflowBytes = bytes[2]

            // Decoding (the heavy part) runs in the background; unchanged bytes reuse the last decode.
            let reusableCampaigns: [ZhuowangCampaign]? =
                (campaignBytes != nil && campaignBytes == cache.campaignsBytes) ? cache.campaigns : nil
            let reusableWorkflows: [ZhuowangCampaignWorkflow]? =
                (workflowBytes != nil && workflowBytes == cache.workflowsBytes) ? cache.workflows : nil

            async let decodedCampaigns: [ZhuowangCampaign]? = {
                guard let data = campaignBytes else { return nil }
                if let reusableCampaigns { return reusableCampaigns }
                return await Task.detached { DashboardDecoding.campaigns(data) }.value
            }()
            async let decodedWorkflows: [ZhuowangCampaignWorkflow]? = {
                guard let data = workflowBytes else { return nil }
                if let reusableWorkflows { return reusableWorkflows }
                return await Task.detached { DashboardDecoding.workflows(data) }.value
            }()
            let campaignValue = await decodedCampaigns, workflowValue = await decodedWorkflows

            if let data = campaignBytes {
                if let value = campaignValue {
                    campaigns = .loaded(value); cache.campaignsBytes = data; cache.campaigns = value
                } else {
                    campaigns = .unreadable("活动数据无法读取；未恢复备份或改写原数据。")
                    cache.campaignsBytes = nil; cache.campaigns = nil
                }
            } else {
                campaigns = .notBuilt; cache.campaignsBytes = nil; cache.campaigns = nil
            }

            if let data = workflowBytes {
                if let value = workflowValue {
                    workflows = .loaded(value); cache.workflowsBytes = data; cache.workflows = value
                } else {
                    workflows = .unreadable("Workflow 数据无法读取；未恢复备份或改写原数据。")
                    cache.workflowsBytes = nil; cache.workflows = nil
                }
            } else {
                workflows = .notBuilt; cache.workflowsBytes = nil; cache.workflows = nil
            }

            // The workspace snapshot only holds names; it is small and decoded here.
            if let data = workspaceBytes {
                if let value = try? JSONDecoder().decode(ZhuowangWorkspaceSnapshot.self, from: data) {
                    workspace = .loaded(value)
                } else {
                    workspace = .unreadable("工作区数据无法读取。")
                }
            } else {
                workspace = .notBuilt
            }
        }

        return DashboardRaw(
            readAt: now,
            campaigns: campaigns, workflows: workflows, workspace: workspace,
            prompts: await loadPrompts(), learning: await loadLearning())
    }

    // MARK: File-backed modules (their own read-only loaders)

    private func loadPrompts() async -> DashboardSource<[PromptTemplate]> {
        switch promptLocation {
        case .blocked(let reason): return .blocked(reason)
        case .root(let root):
            let storage = PromptVaultFileStorage(root: root)
            do {
                let templates = try await storage.load()
                // An empty result is "never created" only when the file does not exist.
                if templates.isEmpty, !FileManager.default.fileExists(atPath: storage.primaryURL.path) { return .notBuilt }
                return .loaded(templates)
            } catch {
                return .unreadable((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    private func loadLearning() async -> DashboardSource<LearningSnapshot> {
        switch learningLocation {
        case .blocked(let reason): return .blocked(reason)
        case .root(let root):
            let storage = LearningFileStorage(root: root)
            do {
                let snapshot = try await storage.load()
                if snapshot.topics.isEmpty, snapshot.entries.isEmpty,
                   !FileManager.default.fileExists(atPath: storage.primaryURL.path) { return .notBuilt }
                return .loaded(snapshot)
            } catch {
                return .unreadable((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }
}
