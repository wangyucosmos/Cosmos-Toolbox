import SwiftUI

/// The hub belongs to the shell; the two module pages are reused without internal changes.
struct CosmosKnowledgeDestinationView: View {
    let configuration: ZhuowangStorePersistenceConfiguration
    let isolatedRoot: URL?
    let notesLocation: PersonalNotesLocation
    let promptLocation: PromptVaultLocation
    @Environment(\.cosmosNavigator) private var navigator
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    @Namespace private var segment
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    sectionButton("个人笔记", .notes)
                    sectionButton("卓望知识与资产", .assets)
                }.padding(4).glassEffect(.regular, in: Capsule())
                Spacer()
            }.padding(.horizontal, 24).padding(.vertical, 10)
            Divider()
            if navigator.knowledgeSection == .notes { PersonalNotesView(location: notesLocation, promptLocation: promptLocation) }
            else { ZhuowangAssetCenterView(configuration: configuration, isolatedRoot: isolatedRoot) }
        }
    }
    private func sectionButton(_ title: String, _ section: CosmosKnowledgeSection) -> some View {
        Button { navigator.knowledgeSection = section } label: {
            Text(title).font(CosmosDesign.font(.body)).padding(.horizontal, 14).padding(.vertical, 7)
                .background {
                    if navigator.knowledgeSection == section {
                        Capsule().fill(Color.accentColor.opacity(0.14)).matchedGeometryEffect(id: "selection", in: segment)
                    }
                }
        }.buttonStyle(.plain)
            .accessibilityAddTraits(navigator.knowledgeSection == section ? .isSelected : [])
            .animation(preferences.reducesMotion(system: systemMotion) ? nil : CosmosDesign.motion, value: navigator.knowledgeSection)
    }
}
