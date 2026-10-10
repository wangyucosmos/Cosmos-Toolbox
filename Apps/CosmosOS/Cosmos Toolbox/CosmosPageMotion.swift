import SwiftUI

extension EnvironmentValues {
    @Entry var cosmosGlassNamespace: Namespace.ID? = nil
}

struct CosmosEntrance: ViewModifier {
    var index: Int
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    @State private var visible = false
    func body(content: Content) -> some View {
        let reduced = preferences.reducesMotion(system: systemMotion)
        content.opacity(visible || reduced ? 1 : 0)
            .offset(y: visible || reduced ? 0 : 8)
            .task {
                withAnimation(reduced ? nil : CosmosDesign.motion.delay(CosmosDesign.entranceDelay(index: index, reduced: reduced))) { visible = true }
            }
    }
}
extension View {
    func cosmosEntrance(_ index: Int = 0) -> some View { modifier(CosmosEntrance(index: index)) }
}

struct CosmosSegmentedControl<Value: Hashable>: View {
    let title: String
    let options: [(Value, String)]
    @Binding var selection: Value
    @Namespace private var indicator
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button { selection = option.0 } label: {
                    Text(option.1).font(CosmosDesign.font(.body)).padding(.horizontal, 12).padding(.vertical, 7)
                        .background {
                            if selection == option.0 {
                                RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.14))
                                    .matchedGeometryEffect(id: "selected", in: indicator)
                            }
                        }
                }.buttonStyle(.plain).accessibilityLabel(title + "：" + option.1)
                    .accessibilityAddTraits(selection == option.0 ? .isSelected : [])
            }
        }.padding(4).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .animation(CosmosDesign.pageAnimation(reduced: preferences.reducesMotion(system: systemMotion)), value: selection)
    }
}

struct CosmosContentPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(18).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.06)) }
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
