import SwiftUI

// MARK: - Pure presentation model

/// Display rules for the Workflow tab. Everything here is a pure function of
/// the persisted Workflow; it never creates, mutates or adopts anything.
enum ZhuowangWorkflowUIModel {

    /// Same "done" set the progress workbench uses, so both screens agree.
    static let doneStatuses: Set<ZhuowangWorkflowStepStatus> = [.approved, .completed, .skipped]

    /// Enabled steps only, in Workflow order.
    static func enabledSteps(in workflow: ZhuowangCampaignWorkflow) -> [ZhuowangWorkflowStep] {
        workflow.steps
            .filter(\.isEnabled)
            .sorted {
                $0.sortOrder != $1.sortOrder ? $0.sortOrder < $1.sortOrder : $0.createdAt < $1.createdAt
            }
    }

    static func progress(of steps: [ZhuowangWorkflowStep]) -> (completed: Int, total: Int) {
        (steps.filter { doneStatuses.contains($0.status) }.count, steps.count)
    }

    /// First enabled step that is not done yet (the step the user should work on).
    static func nextStep(in steps: [ZhuowangWorkflowStep]) -> ZhuowangWorkflowStep? {
        steps.first { !doneStatuses.contains($0.status) }
    }

    /// The explicit selection, else the next open step, else the first step.
    static func effectiveStep(
        selectedID: UUID?,
        in steps: [ZhuowangWorkflowStep]
    ) -> ZhuowangWorkflowStep? {
        steps.first { $0.id == selectedID }
            ?? nextStep(in: steps)
            ?? steps.first
    }

    static func presentation(
        for status: ZhuowangWorkflowStepStatus
    ) -> (icon: String, tone: CampaignUITone) {
        switch status {
        case .notStarted: return ("lock", .neutral)
        case .ready: return ("play.circle.fill", .accent)
        case .running: return ("hourglass", .warning)
        case .waitingForApproval: return ("person.crop.circle.badge.questionmark", .review)
        case .approved: return ("checkmark.circle.fill", .success)
        case .needsRevision: return ("exclamationmark.arrow.triangle.2.circlepath", .warning)
        case .completed: return ("checkmark.circle.fill", .success)
        case .failed: return ("xmark.octagon.fill", .danger)
        case .skipped: return ("forward.circle", .neutral)
        }
    }

    /// Why a locked (not started) step cannot start yet: the first earlier
    /// enabled step that is still open.
    static func lockedReason(
        for step: ZhuowangWorkflowStep,
        in steps: [ZhuowangWorkflowStep]
    ) -> String? {
        guard step.status == .notStarted,
              let index = steps.firstIndex(where: { $0.id == step.id })
        else { return nil }
        guard let blocker = steps[..<index].last(where: { !doneStatuses.contains($0.status) })
        else { return nil }
        return "还差：先确认「\(blocker.title)」"
    }

    /// One current adopted version per step (the newest adopted artifact of the step).
    static func adoptedArtifact(
        for step: ZhuowangWorkflowStep,
        in artifacts: [ZhuowangArtifact]
    ) -> ZhuowangArtifact? {
        artifacts
            .filter { $0.stepID == step.id && $0.isApprovedVersion }
            .max { ($0.updatedAt, $0.version) < ($1.updatedAt, $1.version) }
    }

    /// Provider and Tool are separate inputs: the caller resolves each one.
    static func timelineItems(
        steps: [ZhuowangWorkflowStep],
        artifacts: [ZhuowangArtifact],
        providerName: (ZhuowangWorkflowStep) -> String?,
        toolName: (ZhuowangWorkflowStep) -> String?,
        canAct: (ZhuowangWorkflowStep) -> Bool,
        actionTitle: (ZhuowangWorkflowStep) -> String?
    ) -> [CampaignUITimelineItem] {
        steps.enumerated().map { index, step in
            let look = presentation(for: step.status)
            let adopted = adoptedArtifact(for: step, in: artifacts)
            let usesTool = !step.requiredCapabilities.isEmpty || !step.selectedToolIDs.isEmpty
            return CampaignUITimelineItem(
                id: step.id,
                position: index + 1,
                title: step.title,
                subtitle: step.englishTitle,
                statusText: step.status.title,
                statusIcon: look.icon,
                tone: look.tone,
                provider: providerName(step),
                tool: usesTool ? (toolName(step) ?? "") : nil,
                version: adopted?.version,
                versionIsCurrent: adopted != nil,
                note: lockedReason(for: step, in: steps),
                actionTitle: actionTitle(step),
                actionEnabled: canAct(step),
                isDone: doneStatuses.contains(step.status)
            )
        }
    }
}


// MARK: - Timeline data

/// Everything one timeline row shows. `tool == nil` means the step does not
/// use a tool at all; `tool == ""` means it does but none is chosen yet.
struct CampaignUITimelineItem: Identifiable, Equatable {
    let id: UUID
    let position: Int
    let title: String
    let subtitle: String
    let statusText: String
    let statusIcon: String
    let tone: CampaignUITone
    let provider: String?
    let tool: String?
    let version: Int?
    let versionIsCurrent: Bool
    let note: String?
    let actionTitle: String?
    let actionEnabled: Bool
    let isDone: Bool
}


// MARK: - Timeline view

/// Vertical step rail. Rows are generic: the caller decides the labels,
/// tones and the action, so another company's Workflow can reuse it.
struct CampaignUITimeline: View {
    let items: [CampaignUITimelineItem]
    @Binding var selection: UUID?
    var providerCaption = "AI"
    var toolCaption = "工具"
    let onAction: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                CampaignUITimelineRow(
                    item: item,
                    isSelected: item.id == selection,
                    isFirst: index == 0,
                    isLast: index == items.count - 1,
                    nextIsDone: index + 1 < items.count ? items[index + 1].isDone : false,
                    providerCaption: providerCaption,
                    toolCaption: toolCaption,
                    select: { selection = item.id },
                    act: { onAction(item.id) }
                )
                .campaignUIEntrance(index)
            }
        }
    }
}

private struct CampaignUITimelineRow: View {
    let item: CampaignUITimelineItem
    let isSelected: Bool
    let isFirst: Bool
    let isLast: Bool
    let nextIsDone: Bool
    let providerCaption: String
    let toolCaption: String
    let select: () -> Void
    let act: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            rail
            card
                .padding(.bottom, isLast ? 0 : 10)
        }
    }

    private var rail: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(item.tone.color.opacity(item.isDone ? 0.16 : 0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: item.statusIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(item.tone.color)
                    .contentTransition(.symbolEffect(.replace))
            }
            .overlay {
                if isSelected {
                    Circle().stroke(Color.accentColor, lineWidth: 2).frame(width: 36, height: 36)
                }
            }
            .frame(width: 36, height: 36)
            if !isLast {
                RoundedRectangle(cornerRadius: 1)
                    .fill(item.isDone && nextIsDone ? Color.green.opacity(0.45) : Color.primary.opacity(0.12))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 36)
        .campaignUIAnimation(value: isSelected)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%02d", item.position))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
                Text(item.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 6)
                CampaignUIStatusPill(text: item.statusText, tone: item.tone)
            }
            HStack(spacing: 6) {
                CampaignUIChip(caption: providerCaption, value: item.provider, icon: "sparkles", placeholder: "未选择")
                if let tool = item.tool {
                    CampaignUIChip(caption: toolCaption, value: tool.isEmpty ? nil : tool,
                                   icon: "wrench.and.screwdriver", placeholder: "未选择")
                }
                if let version = item.version {
                    CampaignUIVersionBadge(version: version, isCurrent: item.versionIsCurrent)
                }
                Spacer(minLength: 0)
            }
            if item.note != nil || item.actionTitle != nil {
                HStack(spacing: 8) {
                    if let note = item.note {
                        Label(note, systemImage: "lock").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if let title = item.actionTitle {
                        Button(title, action: act)
                            .buttonStyle(.glass)
                            .controlSize(.small)
                            .disabled(!item.actionEnabled)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusMedium, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusMedium, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(hovering ? 0.14 : 0.06),
                        lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusMedium, style: .continuous))
        .onTapGesture(perform: select)
        .onHover { hovering = $0 }
        .campaignUIAnimation(value: isSelected)
        .campaignUIAnimation(value: hovering)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("第 \(item.position) 步 \(item.title)，\(item.statusText)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
