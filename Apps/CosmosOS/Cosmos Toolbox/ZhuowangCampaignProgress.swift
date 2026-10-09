import Foundation


// MARK: - Campaign Progress (read-only projection)

/// Calendar position of a Campaign, derived only from the start / end dates
/// the user entered for the Campaign. It is not a task deadline.
enum ZhuowangCampaignDatePhase: String, CaseIterable, Identifiable {
    case upcoming
    case ongoing
    case ended

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .upcoming:
            return "即将开始"
        case .ongoing:
            return "进行中"
        case .ended:
            return "已结束"
        }
    }
}


/// Where a Campaign stands in the Workflow, in priority order. Each
/// Campaign belongs to exactly one category.
enum ZhuowangCampaignActionCategory: Int, CaseIterable, Identifiable {
    case needsAttention
    case awaitingReview
    case readyForNextStep
    case deliverable
    case completedFilesUnavailable
    case workflowNotCreated

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .needsAttention:
            return "失败或需修改"
        case .awaitingReview:
            return "生成中 / 待确认"
        case .readyForNextStep:
            return "下一步可推进"
        case .deliverable:
            return "可以交付"
        case .completedFilesUnavailable:
            return "六步已确认，交付文件不可用"
        case .workflowNotCreated:
            return "尚未开始 Workflow"
        }
    }

    var systemImage: String {
        switch self {
        case .needsAttention:
            return "exclamationmark.triangle"
        case .awaitingReview:
            return "hourglass"
        case .readyForNextStep:
            return "arrow.right.circle"
        case .deliverable:
            return "shippingbox"
        case .completedFilesUnavailable:
            return "doc.badge.ellipsis"
        case .workflowNotCreated:
            return "circle.dashed"
        }
    }
}


struct ZhuowangCampaignStepProgress: Equatable {
    let stepID: UUID
    /// 1-based position among the enabled steps.
    let position: Int
    let title: String
    let status: ZhuowangWorkflowStepStatus

    var label: String {
        String(format: "%02d ", position) + title
    }
}


struct ZhuowangCampaignProgress: Identifiable, Equatable {

    let campaign: ZhuowangCampaign
    let province: ZhuowangProvince?
    let module: ZhuowangModule?
    let scopeName: String

    let hasWorkflow: Bool
    let completedSteps: Int
    let totalSteps: Int
    /// First enabled step, in order, that is not yet approved / completed.
    let nextStep: ZhuowangCampaignStepProgress?
    /// Enabled steps whose status is failed or needs revision.
    let attentionSteps: [ZhuowangCampaignStepProgress]

    /// Logical artifacts with exactly one currently adopted version.
    let adoptedArtifactCount: Int
    /// Logical artifacts with more than one adopted version (data issue).
    let adoptionConflictCount: Int
    /// Adopted artifacts the delivery package can currently include.
    let deliverableFileCount: Int

    let datePhase: ZhuowangCampaignDatePhase
    /// Days until start (upcoming), until end (ongoing) or since end (ended).
    let dayDistance: Int

    var id: UUID {
        campaign.id
    }

    var isWorkflowComplete: Bool {
        hasWorkflow && totalSteps > 0 && completedSteps == totalSteps
    }

    var category: ZhuowangCampaignActionCategory {
        if !hasWorkflow {
            return .workflowNotCreated
        }
        if !attentionSteps.isEmpty {
            return .needsAttention
        }
        if let nextStep {
            switch nextStep.status {
            case .running, .waitingForApproval:
                return .awaitingReview
            default:
                return .readyForNextStep
            }
        }
        return deliverableFileCount > 0
            ? .deliverable
            : .completedFilesUnavailable
    }

    /// One-line description of the next action, grounded in Workflow state.
    var nextActionText: String {
        switch category {
        case .workflowNotCreated:
            return "打开活动的 AI Workflow 后开始 01 需求整理"
        case .needsAttention:
            let steps = attentionSteps
                .map { "\($0.label)（\($0.status.title)）" }
                .joined(separator: "、")
            return "处理 " + steps
        case .awaitingReview:
            guard let nextStep else {
                return ""
            }
            return "\(nextStep.label)：\(nextStep.status.title)"
        case .readyForNextStep:
            guard let nextStep else {
                return ""
            }
            return nextStep.status == .ready
                ? "开始 \(nextStep.label)"
                : "\(nextStep.label)（\(nextStep.status.title)）"
        case .deliverable:
            return "\(deliverableFileCount) 个采用产物可导出交付包"
        case .completedFilesUnavailable:
            return "采用产物没有可交付的本地文件，请在工作产物中核对"
        }
    }
}


// MARK: - Builder

enum ZhuowangCampaignProgressBuilder {

    /// Counts adopted artifacts the delivery package would currently accept.
    typealias DeliverableCounter = @MainActor (
        _ campaign: ZhuowangCampaign,
        _ provinceName: String?,
        _ artifacts: [ZhuowangArtifact],
        _ steps: [ZhuowangWorkflowStep]
    ) -> Int

    private static let doneStatuses: Set<ZhuowangWorkflowStepStatus> = [
        .approved, .completed, .skipped
    ]

    private static let attentionStatuses: Set<ZhuowangWorkflowStepStatus> = [
        .failed, .needsRevision
    ]

    /// Pure projection of persisted data. It never creates a Workflow and
    /// never changes status, adoption or files.
    static func build(
        campaigns: [ZhuowangCampaign],
        workflows: [ZhuowangCampaignWorkflow],
        provinces: [ZhuowangProvince],
        modules: [ZhuowangModule],
        now: Date,
        calendar: Calendar = .current,
        deliverableCounter: DeliverableCounter? = nil
    ) -> [ZhuowangCampaignProgress] {

        let countDeliverables: DeliverableCounter = deliverableCounter ?? {
            Self.deliveryPackageCount(campaign: $0, provinceName: $1, artifacts: $2, steps: $3)
        }

        let workflowByCampaign = Dictionary(
            workflows.map { ($0.campaignID, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return campaigns.map { campaign in
            let province = campaign.provinceID.flatMap { id in
                provinces.first { $0.id == id }
            }
            let module = campaign.moduleID.flatMap { id in
                modules.first { $0.id == id }
            }
            let workflow = workflowByCampaign[campaign.id]

            let steps = (workflow?.steps ?? [])
                .filter(\.isEnabled)
                .sorted { $0.sortOrder < $1.sortOrder }
            let progressSteps = steps.enumerated().map { index, step in
                ZhuowangCampaignStepProgress(
                    stepID: step.id,
                    position: index + 1,
                    title: step.title,
                    status: step.status
                )
            }

            let artifacts = (workflow?.artifacts ?? []).filter {
                $0.campaignID == campaign.id
            }
            let adoptedPerGroup = Dictionary(grouping: artifacts, by: \.versionGroupKey)
                .mapValues { $0.filter(\.isApprovedVersion).count }
            let adoptedCount = adoptedPerGroup.values.filter { $0 == 1 }.count

            let (phase, distance) = datePhase(campaign, now: now, calendar: calendar)

            return ZhuowangCampaignProgress(
                campaign: campaign,
                province: province,
                module: module,
                scopeName: scopeName(campaign, province: province, module: module),
                hasWorkflow: workflow != nil,
                completedSteps: progressSteps.filter { doneStatuses.contains($0.status) }.count,
                totalSteps: progressSteps.count,
                nextStep: progressSteps.first { !doneStatuses.contains($0.status) },
                attentionSteps: progressSteps.filter { attentionStatuses.contains($0.status) },
                adoptedArtifactCount: adoptedCount,
                adoptionConflictCount: adoptedPerGroup.values.filter { $0 > 1 }.count,
                deliverableFileCount: adoptedCount > 0
                    ? countDeliverables(campaign, province?.pathName, artifacts, workflow?.steps ?? [])
                    : 0,
                datePhase: phase,
                dayDistance: distance
            )
        }
    }


    /// Uses the accepted delivery-package eligibility rules unchanged.
    static func deliveryPackageCount(
        campaign: ZhuowangCampaign,
        provinceName: String?,
        artifacts: [ZhuowangArtifact],
        steps: [ZhuowangWorkflowStep]
    ) -> Int {
        ZhuowangArtifactDeliveryPackageService()
            .candidates(
                snapshot: ZhuowangArtifactDeliverySnapshot(
                    campaignID: campaign.id,
                    artifacts: artifacts,
                    steps: steps
                ),
                campaignWorkspaceURL: ZhuowangWorkspaceFileManager.shared
                    .campaignDirectoryURL(
                        provinceName: provinceName,
                        campaignName: campaign.name
                    )
            )
            .filter(\.isEligible)
            .count
    }


    /// Compares calendar days of the Campaign's own start / end dates.
    static func datePhase(
        _ campaign: ZhuowangCampaign,
        now: Date,
        calendar: Calendar
    ) -> (ZhuowangCampaignDatePhase, Int) {
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: campaign.startDate)
        let end = max(start, calendar.startOfDay(for: campaign.endDate))

        func days(_ from: Date, _ to: Date) -> Int {
            calendar.dateComponents([.day], from: from, to: to).day ?? 0
        }

        if today < start {
            return (.upcoming, days(today, start))
        }
        if today > end {
            return (.ended, days(end, today))
        }
        return (.ongoing, days(today, end))
    }


    private static func scopeName(
        _ campaign: ZhuowangCampaign,
        province: ZhuowangProvince?,
        module: ZhuowangModule?
    ) -> String {
        if let province {
            return province.name
        }
        if let module {
            return module.name
        }
        switch campaign.scopeType {
        case .province:
            return "未知省份"
        case .national:
            return "全国"
        case .other:
            return "其他"
        }
    }
}


// MARK: - Filter

struct ZhuowangCampaignWorkbenchFilter: Equatable {

    enum Scope: Hashable {
        case all
        case province(UUID)
        case module(String)
    }

    var scope: Scope = .all
    var status: ZhuowangCampaignStatus?
    var query = ""

    var isActive: Bool {
        scope != .all
            || status != nil
            || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func matches(_ progress: ZhuowangCampaignProgress) -> Bool {
        switch scope {
        case .all:
            break
        case .province(let id):
            guard progress.campaign.provinceID == id else {
                return false
            }
        case .module(let id):
            guard progress.campaign.moduleID == id else {
                return false
            }
        }

        if let status, progress.campaign.status != status {
            return false
        }

        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty
            || progress.campaign.name.localizedCaseInsensitiveContains(text)
            || progress.campaign.englishName.localizedCaseInsensitiveContains(text)
    }
}
