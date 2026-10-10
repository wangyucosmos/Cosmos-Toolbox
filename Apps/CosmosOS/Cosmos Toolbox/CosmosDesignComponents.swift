import SwiftUI

extension CosmosDesign {
    enum TextRole { case title, section, body, caption, metric }
    static func font(_ role: TextRole) -> Font {
        let size: CGFloat
        let weight: Font.Weight
        switch role {
        case .title: size = 28; weight = .semibold
        case .section: size = 17; weight = .semibold
        case .body: size = 13; weight = .regular
        case .caption: size = 11; weight = .regular
        case .metric: size = 29; weight = .semibold
        }
        return .system(size: size * CosmosUIPreferences.shared.textSize.scale, weight: weight)
    }
    static let motion = Animation.spring(response: 0.3, dampingFraction: 0.86)
    static let panelShadow: CGFloat = 8
}

struct CosmosInfoButton: View {
    let text: String
    @State private var showing = false
    var body: some View {
        Button("详细说明", systemImage: "info.circle") { showing.toggle() }
            .labelStyle(.iconOnly).buttonStyle(.borderless).foregroundStyle(.secondary)
            .popover(isPresented: $showing) { Text(text).font(CosmosDesign.font(.body)).textSelection(.enabled).padding(20).frame(width: 360) }
    }
}

struct CosmosPageHeader<Actions: View>: View {
    let title: String
    var subtitle = ""
    var info: String? = nil
    @ViewBuilder var actions: Actions
    init(_ title: String, subtitle: String = "", info: String? = nil, @ViewBuilder actions: () -> Actions) {
        self.title = title; self.subtitle = subtitle; self.info = info; self.actions = actions()
    }
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) { Text(title).font(CosmosDesign.font(.title)); if let info { CosmosInfoButton(text: info) } }
                if !subtitle.isEmpty { Text(subtitle).font(CosmosDesign.font(.body)).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            actions
        }
    }
}
extension CosmosPageHeader where Actions == EmptyView {
    init(_ title: String, subtitle: String = "", info: String? = nil) { self.init(title, subtitle: subtitle, info: info) { EmptyView() } }
}

struct CosmosInteractiveCardStyle: ButtonStyle {
    var selected = false
    var focused = false
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    @Environment(\.cosmosPreferences) private var preferences
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        let reduced = preferences.reducesMotion(system: systemMotion)
        configuration.label
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(selected || focused ? Color.accentColor : Color.primary.opacity(hovering ? 0.17 : 0.06), lineWidth: focused ? 2 : 1) }
            .shadow(color: .black.opacity(hovering ? 0.07 : 0.02), radius: hovering ? CosmosDesign.panelShadow : 3, y: hovering ? 3 : 1)
            .scaleEffect(reduced ? 1 : configuration.isPressed ? 0.99 : hovering ? 1.008 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .onHover { hovering = $0 }
            .animation(reduced ? nil : CosmosDesign.motion, value: hovering)
            .animation(reduced ? nil : CosmosDesign.motion, value: configuration.isPressed)
    }
}

struct CosmosCard<Content: View>: View {
    let icon: String
    let title: String
    var englishTitle: String = ""
    var action: (() -> Void)?
    var arrow = true
    @ViewBuilder let content: Content
    @FocusState private var focused: Bool
    init(icon: String, title: String, englishTitle: String = "", arrow: Bool = true, action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.icon = icon; self.title = title; self.englishTitle = englishTitle; self.arrow = arrow; self.action = action; self.content = content()
    }
    private var label: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Label(title, systemImage: icon).font(CosmosDesign.font(.section)); Spacer(); if action != nil && arrow { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) } }
            content
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder var body: some View {
        if let action {
            Button(action: action) { label }.buttonStyle(CosmosInteractiveCardStyle(focused: focused)).focused($focused)
        } else { label.modifier(CosmosCardStyle(isHovering: false)) }
    }
}

struct CosmosMetricTile: View {
    let icon: String
    let title: String
    var value: Int?
    var detail: String? = nil
    var loading = false
    var selected = false
    let action: () -> Void
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    @Environment(\.cosmosPreferences) private var preferences
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Image(systemName: icon).foregroundStyle(selected ? Color.accentColor : Color.secondary); Spacer(); if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor) } }
                if loading { ProgressView().frame(height: 35) }
                else { Text(value.map(String.init) ?? "—").font(CosmosDesign.font(.metric)).monospacedDigit().contentTransition(.numericText()) }
                Text(title).font(CosmosDesign.font(.body)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                if let detail { Text(detail).font(CosmosDesign.font(.caption)).foregroundStyle(value == nil ? Color.orange : Color.secondary).lineLimit(3) }
            }.frame(maxWidth: .infinity, minHeight: 103, alignment: .leading)
        }.buttonStyle(CosmosInteractiveCardStyle(selected: selected, focused: focused)).focused($focused)
            .animation(preferences.reducesMotion(system: systemMotion) ? nil : CosmosDesign.motion, value: value)
            .accessibilityLabel(title + "，" + (loading ? "正在计算" : value.map(String.init) ?? "无法读取") + (detail.map { "，" + $0 } ?? ""))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct CosmosEmptyState: View {
    let icon: String
    let title: String
    var detail: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(.secondary)
            Text(title).font(CosmosDesign.font(.section))
            if let detail { Text(detail).font(CosmosDesign.font(.body)).foregroundStyle(.secondary).multilineTextAlignment(.center) }
            if let actionTitle, let action { Button(actionTitle, action: action).buttonStyle(.glass) }
        }.frame(maxWidth: .infinity, minHeight: 130).padding(12)
    }
}

struct CosmosChartCard<Content: View>: View {
    let title: String
    let icon: String
    var empty = false
    var loading = false
    var error: String? = nil
    var action: () -> Void
    @ViewBuilder let content: Content
    var body: some View {
        CosmosCard(icon: icon, title: title, action: action) {
            if loading { ProgressView().frame(maxWidth: .infinity, minHeight: 180) }
            else if let error { CosmosEmptyState(icon: "exclamationmark.triangle", title: "无法读取", detail: error) }
            else if empty { CosmosEmptyState(icon: icon, title: "尚无数据", detail: "打开对应模块添加记录") }
            else { content.frame(height: 185) }
        }
    }
}

struct CosmosGlassToolbarGroup<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { GlassEffectContainer(spacing: 8) { HStack(spacing: 8) { content }.buttonStyle(.glass).foregroundStyle(.primary) } }
}
