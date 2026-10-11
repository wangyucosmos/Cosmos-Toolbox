import SwiftUI

/// Company content and progress are supplied by the caller.
struct CosmosWorkspaceNavigationRow: View {
    let icon: String
    let title: String
    var letter: String? = nil
    var iconIdentity: String? = nil
    var subdued = false
    var subtitle = ""
    var count: Int? = nil
    var attention = false
    var selected = false
    let action: () -> Void
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                CosmosSquareIcon(letter: letter, symbol: icon, identity: iconIdentity ?? title, subdued: subdued)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(.body, weight: selected ? .semibold : .medium))
                    if !subtitle.isEmpty { Text(subtitle).font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 4)
                if attention { Circle().fill(.orange).frame(width: 6, height: 6).accessibilityLabel("有活动需要关注") }
                if let count { Text(count.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 3).background(.quaternary, in: Capsule()) }
            }.padding(10).contentShape(RoundedRectangle(cornerRadius: 10))
                .background(selected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).cosmosRowFeedback()
            .animation(CosmosDesign.pageAnimation(reduced: preferences.reducesMotion(system: systemMotion)), value: selected)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct CosmosWorkflowMiniProgress: View {
    let completed: Int
    let total: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text("Workflow"); Spacer(); Text(total == 0 ? "尚未开始" : "\(completed) / \(total)") }
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    Capsule().fill(total > 0 && index < completed ? Color.accentColor : Color.primary.opacity(0.09)).frame(height: 4)
                }
            }
        }.accessibilityLabel("Workflow 已完成 \(completed) 个，共 \(total) 个启用步骤")
    }
}

struct CosmosWorkCard<Status: View>: View {
    let title: String
    let scope: String
    let dates: String
    let completed: Int
    let total: Int
    let adopted: Int
    let attention: Bool
    var compact = false
    @ViewBuilder var status: Status
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title).font(.headline).lineLimit(2)
                        Text(scope).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    status
                }
                Label(dates, systemImage: "calendar").font(.caption).foregroundStyle(.secondary)
                CosmosWorkflowMiniProgress(completed: completed, total: total)
                HStack {
                    Label("采用产物 \(adopted)", systemImage: "doc.text").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if attention { Label("需关注", systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.orange) }
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(CosmosInteractiveCardStyle()).accessibilityLabel(title + "，" + scope + (attention ? "，需关注" : ""))
    }
}
