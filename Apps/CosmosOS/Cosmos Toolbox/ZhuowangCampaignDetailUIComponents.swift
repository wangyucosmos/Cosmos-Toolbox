import SwiftUI

// Generic building blocks for the Campaign / Artifact windows.
// Nothing in this file knows about 卓望 step names or rules; callers pass
// titles, tones, versions and actions so the same pieces can serve another
// company workspace later.

// MARK: - Tone

enum CampaignUITone: Equatable {
    case neutral, accent, success, warning, danger, info, review

    var color: Color {
        switch self {
        case .neutral: return .secondary
        case .accent: return .accentColor
        case .success: return .green
        case .warning: return .orange
        case .danger: return .red
        case .info: return .blue
        case .review: return .purple
        }
    }
}


// MARK: - Motion

private struct CampaignUIAnimationModifier<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var system
    @Environment(\.cosmosPreferences) private var preferences

    func body(content: Content) -> some View {
        content.animation(preferences.reducesMotion(system: system) ? nil : animation, value: value)
    }
}

private struct CampaignUIEntranceModifier: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var system
    @Environment(\.cosmosPreferences) private var preferences

    func body(content: Content) -> some View {
        let reduced = preferences.reducesMotion(system: system)
        content
            .opacity(shown || reduced ? 1 : 0)
            .offset(y: shown || reduced ? 0 : 8)
            .onAppear {
                guard !shown, !reduced else { return }
                withAnimation(
                    .smooth(duration: CosmosDesign.animationNormal)
                        .delay(CosmosDesign.entranceDelay(index: index, reduced: reduced))
                ) { shown = true }
            }
    }
}

extension View {
    /// Applies `animation` for `value` changes unless motion is reduced (system or Cosmos preference).
    func campaignUIAnimation<Value: Equatable>(
        _ animation: Animation = CosmosDesign.motion,
        value: Value
    ) -> some View {
        modifier(CampaignUIAnimationModifier(animation: animation, value: value))
    }

    /// Staggered fade / lift on first appearance; instant when motion is reduced.
    func campaignUIEntrance(_ index: Int = 0) -> some View {
        modifier(CampaignUIEntranceModifier(index: index))
    }

    /// Standard card surface: system control background, hairline stroke, soft shadow.
    func campaignUICardSurface(
        padding: CGFloat = CosmosDesign.cardPadding,
        stroke: Color = Color.primary.opacity(0.065),
        fill: Color = Color(nsColor: .controlBackgroundColor)
    ) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusLarge, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.025), radius: 6, y: 2)
    }
}


// MARK: - Formatting

enum CampaignUIFormat {
    static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: date)
    }

    static func artifactIcon(_ type: ZhuowangArtifactType) -> String {
        switch type {
        case .markdown: return "doc.text"
        case .word: return "doc.richtext"
        case .pdf: return "doc.text"
        case .excel: return "tablecells"
        case .image: return "photo"
        case .figma: return "square.on.square"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .flowchart: return "point.3.connected.trianglepath.dotted"
        case .prompt: return "text.quote"
        case .url: return "link"
        case .other: return "doc"
        }
    }
}


// MARK: - Card

struct CampaignUICard<Content: View, Trailing: View>: View {
    let title: String
    var icon: String?
    var info: String?
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(title).font(CosmosDesign.font(.section))
                if let info { CosmosInfoButton(text: info) }
                Spacer(minLength: 8)
                trailing
            }
            content
        }
        .campaignUICardSurface()
    }
}

extension CampaignUICard where Trailing == EmptyView {
    init(title: String, icon: String? = nil, info: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, icon: icon, info: info, trailing: { EmptyView() }, content: content)
    }
}


// MARK: - Pills and chips

struct CampaignUIStatusPill: View {
    let text: String
    var icon: String?
    var tone: CampaignUITone = .neutral

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            } else {
                Circle().fill(tone.color).frame(width: 6, height: 6)
            }
            Text(text).font(.caption).fontWeight(.medium).lineLimit(1)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(tone.color.opacity(0.12), in: Capsule())
    }
}

/// A labelled capsule such as "AI · DeepSeek Harness" or "工具 · Figma".
/// The caption keeps two different kinds of thing (AI Provider vs Tool)
/// visibly separate even when both are shown on the same row.
struct CampaignUIChip: View {
    let caption: String
    let value: String?
    let icon: String
    var placeholder = "未选择"

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10.5, weight: .medium))
            Text(caption).foregroundStyle(.tertiary)
            Text(value ?? placeholder).fontWeight(.medium).lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(value == nil ? Color.secondary.opacity(0.7) : Color.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.055), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption)：\(value ?? placeholder)")
    }
}

struct CampaignUIVersionBadge: View {
    let version: Int
    var isCurrent = false

    var body: some View {
        HStack(spacing: 4) {
            Text("V\(version)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if isCurrent {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 10))
            }
        }
        .foregroundStyle(isCurrent ? Color.green : Color.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((isCurrent ? Color.green : Color.primary).opacity(isCurrent ? 0.12 : 0.06), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isCurrent ? "版本 \(version)，当前采用" : "版本 \(version)")
    }
}

enum CampaignUIFileState: Equatable {
    case present
    case missing
}

struct CampaignUIFilePill: View {
    let state: CampaignUIFileState

    var body: some View {
        switch state {
        case .present: CampaignUIStatusPill(text: "已落盘", icon: "checkmark.circle.fill", tone: .success)
        case .missing: CampaignUIStatusPill(text: "未落盘", icon: "exclamationmark.circle", tone: .warning)
        }
    }
}


// MARK: - Progress ring

struct CampaignUIProgressRing: View {
    let completed: Int
    let total: Int
    var size: CGFloat = 46
    var lineWidth: CGFloat = 5

    private var fraction: Double {
        total > 0 ? min(1, Double(completed) / Double(total)) : 0
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(fraction >= 1 ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .campaignUIAnimation(.smooth(duration: CosmosDesign.animationSlow), value: fraction)
            Text(total > 0 ? "\(completed)/\(total)" : "—")
                .font(.system(size: size * 0.26, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Workflow 进度")
        .accessibilityValue(total > 0 ? "已完成 \(completed)，共 \(total) 步" : "尚未开始")
    }
}


// MARK: - Rows and notices

struct CampaignUIMetaRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CosmosDesign.spacingM) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(.secondary)
            Text(title).frame(width: 76, alignment: .leading).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(CosmosDesign.font(.body))
        .padding(.vertical, 6)
    }
}

struct CampaignUIKeyValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout).fontWeight(.medium).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CampaignUINotice: View {
    let text: String
    var icon = "info.circle"
    var tone: CampaignUITone = .neutral

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(tone.color)
            Text(text).font(.callout).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(tone.color.opacity(0.08), in: RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusSmall, style: .continuous))
    }
}

/// Window / sheet header: tinted icon tile, title, caption and trailing controls.
struct CampaignUIHeader<Trailing: View>: View {
    let icon: String
    let title: String
    var subtitle = ""
    var info: String?
    var tone: CampaignUITone = .accent
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: CosmosDesign.spacingM) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tone.color)
                .frame(width: 40, height: 40)
                .background(tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.title2).fontWeight(.semibold).lineLimit(1)
                    if let info { CosmosInfoButton(text: info) }
                }
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, CosmosDesign.spacingL)
        .padding(.vertical, CosmosDesign.spacingM)
    }
}

extension CampaignUIHeader where Trailing == EmptyView {
    init(icon: String, title: String, subtitle: String = "", info: String? = nil, tone: CampaignUITone = .accent) {
        self.init(icon: icon, title: title, subtitle: subtitle, info: info, tone: tone, trailing: { EmptyView() })
    }
}

/// Section title used above a grid or list inside a tab (not a card).
struct CampaignUISectionTitle<Trailing: View>: View {
    let title: String
    var count: Int?
    var info: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(CosmosDesign.font(.section))
            if let count {
                Text("\(count)").font(.caption).fontWeight(.medium).foregroundStyle(.secondary).monospacedDigit()
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
            if let info { CosmosInfoButton(text: info) }
            Spacer(minLength: 8)
            trailing
        }
    }
}

extension CampaignUISectionTitle where Trailing == EmptyView {
    init(_ title: String, count: Int? = nil, info: String? = nil) {
        self.init(title: title, count: count, info: info, trailing: { EmptyView() })
    }
}


// MARK: - Artifact card

struct CampaignUIArtifactCard: View {
    let icon: String
    let name: String
    let typeTitle: String
    let version: Int
    let isCurrent: Bool
    let versionCount: Int
    let fileState: CampaignUIFileState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.tint)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Spacer(minLength: 8)
                    CampaignUIVersionBadge(version: version, isCurrent: isCurrent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(versionCount > 1 ? "\(typeTitle) · 共 \(versionCount) 个版本" : "\(typeTitle) · 仅此版本")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 6) {
                    if isCurrent { CampaignUIStatusPill(text: "当前采用", icon: "checkmark.seal.fill", tone: .success) }
                    CampaignUIFilePill(state: fileState)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        }
        .buttonStyle(CosmosInteractiveCardStyle())
        .help("查看工作产物")
        .accessibilityLabel("\(name)，\(typeTitle)，V\(version)")
    }
}


// MARK: - Segmented tabs

struct CampaignUITabItem<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let icon: String
}

/// Window-level segmented control. The selected pill slides between segments
/// (matched geometry) and the container is the only Liquid Glass surface.
struct CampaignUISegmentedTabs<ID: Hashable>: View {
    let items: [CampaignUITabItem<ID>]
    @Binding var selection: ID
    var isDisabled = false
    @Namespace private var indicator
    @Environment(\.accessibilityReduceMotion) private var system
    @Environment(\.cosmosPreferences) private var preferences

    var body: some View {
        let reduced = preferences.reducesMotion(system: system)
        HStack(spacing: 2) {
            ForEach(items) { item in
                let selected = item.id == selection
                Button {
                    guard !isDisabled, !selected else { return }
                    if reduced { selection = item.id }
                    else { withAnimation(CosmosDesign.motion) { selection = item.id } }
                } label: {
                    Label(item.title, systemImage: item.icon)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 13, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.accentColor : Color.primary.opacity(0.78))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.14))
                                    .matchedGeometryEffect(id: "campaign-ui-tab-indicator", in: indicator)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .opacity(isDisabled && !selected ? 0.45 : 1)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .glassEffect(.regular, in: Capsule())
        .disabled(isDisabled)
    }
}
