import SwiftUI

/// Presentation items keep routing status separate from editable category names.
struct ZhuowangCategoryBarItem: Identifiable, Equatable {
    let id: String
    let title: String
    let unsupported: Bool

    static func items(categories: [ZhuowangCategory]) -> [Self] {
        [.init(id: "overview", title: "概览", unsupported: false),
         .init(id: "campaign", title: "活动", unsupported: false)]
        + categories.filter { $0.id != "overview" && $0.id != "campaign" }.map {
            .init(id: $0.id, title: $0.name, unsupported: ZhuowangCategoryRoute(categoryID: $0.id) == .unsupported)
        }
    }
}

struct ZhuowangCategoryBar: View {
    let items: [ZhuowangCategoryBarItem]
    @Binding var selection: String
    @Namespace private var glass
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    private var reduced: Bool { preferences.reducesMotion(system: systemMotion) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(items) { item in
                            ZhuowangCategoryTag(item: item, selected: selection == item.id, glass: glass, reduced: reduced) {
                                selection = item.id
                            }.id(item.id)
                        }
                    }.padding(.vertical, 4).padding(.horizontal, 2)
                }
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { _, value in
                withAnimation(reduced ? nil : CosmosDesign.motion) { proxy.scrollTo(value, anchor: .center) }
            }
            .animation(reduced ? nil : CosmosDesign.motion, value: selection)
        }.accessibilityLabel("工作分类")
    }
}

private struct ZhuowangCategoryTag: View {
    let item: ZhuowangCategoryBarItem
    let selected: Bool
    let glass: Namespace.ID
    let reduced: Bool
    let action: () -> Void
    @State private var hovering = false

    private var label: some View {
        HStack(spacing: 6) {
            Text(item.title).font(.system(size: 14, weight: selected ? .semibold : .medium))
            if item.unsupported { Image(systemName: "circle.dashed").font(.system(size: 10)).foregroundStyle(.secondary) }
        }.foregroundStyle(selected ? Color.primary : item.unsupported ? Color.secondary : Color.primary)
            .padding(.horizontal, 16).frame(height: 34)
            .contentShape(Capsule())
    }
    var body: some View {
        Button(action: action) {
            Group {
                if selected {
                    label.glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
                        .glassEffectID("selected-category", in: glass)
                        .glassEffectTransition(reduced ? .identity : .matchedGeometry)
                } else {
                    label.background(hovering ? Color.primary.opacity(0.05) : .clear, in: Capsule())
                }
            }
        }.buttonStyle(.plain).onHover { hovering = $0 }
            .help(item.unsupported ? "尚未接入" : item.title)
            .accessibilityLabel(item.title + (item.unsupported ? "，尚未接入" : ""))
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("workspace-category-" + item.id)
    }
}
