import SwiftUI

extension EnvironmentValues {
    @Entry var cosmosShellOwnsTransition = false
    @Entry var cosmosPageToolbarVisible = true
}

/// System scroll transitions replace timed first-appearance animation.
private struct CosmosScrollReveal: ViewModifier {
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    func body(content: Content) -> some View {
        let reduced = preferences.reducesMotion(system: systemMotion)
        content.scrollTransition(.interactive, axis: .vertical) { view, phase in
            view.opacity(reduced || phase.isIdentity ? 1 : 0.82)
                .scaleEffect(reduced || phase.isIdentity ? 1 : 0.98)
                .offset(y: reduced || phase.isIdentity ? 0 : 4)
        }
    }
}
private struct CosmosSymbolReplacement: ViewModifier {
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    func body(content: Content) -> some View {
        content.contentTransition(preferences.reducesMotion(system: systemMotion) ? .identity : .symbolEffect(.replace))
    }
}
extension View {
    func cosmosSymbolReplacement() -> some View { modifier(CosmosSymbolReplacement()) }
    func cosmosScrollReveal() -> some View { modifier(CosmosScrollReveal()) }
}

struct CosmosContentPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(18).background(CosmosDesign.surface, in: RoundedRectangle(cornerRadius: CosmosDesign.surfaceRadius))
    }
}

struct CosmosRowFeedback: ViewModifier {
    @State private var hovering = false
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    func body(content: Content) -> some View {
        content.frame(maxWidth: .infinity, alignment: .leading).padding(6)
            .background(hovering ? Color.accentColor.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .onHover { hovering = $0 }
            .animation(CosmosDesign.pageAnimation(reduced: preferences.reducesMotion(system: systemMotion)), value: hovering)
    }
}
extension View { func cosmosRowFeedback() -> some View { modifier(CosmosRowFeedback()) } }
