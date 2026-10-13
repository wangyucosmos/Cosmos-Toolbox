import SwiftUI

/// The hub belongs to the shell; the module pages are reused without internal changes.
struct CosmosKnowledgeDestinationView: View {
    let configuration: ZhuowangStorePersistenceConfiguration
    let isolatedRoot: URL?
    let notesLocation: PersonalNotesLocation
    let promptLocation: PromptVaultLocation
    let knowledgeSourcesLocation: KnowledgeSourcesLocation
    @Environment(\.cosmosNavigator) private var navigator
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    var body: some View {
        VStack(spacing: 0) {
            if navigator.knowledgeSection == .notes { PersonalNotesView(location: notesLocation, promptLocation: promptLocation) }
            else if navigator.knowledgeSection == .assets { ZhuowangAssetCenterView(configuration: configuration, isolatedRoot: isolatedRoot) }
            else {
                KnowledgeSourcesRootView(location: knowledgeSourcesLocation,
                    suggestedFolder: configuration.isIsolatedForUI || knowledgeSourcesLocation.root == nil ? nil : KnowledgeSourcesRootView.defaultSuggestion())
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("知识库分区", selection: Self.sectionBinding(navigator: navigator)) {
                    Text("个人笔记").tag(CosmosKnowledgeSection.notes)
                    Text("卓望知识与资产").tag(CosmosKnowledgeSection.assets)
                    Text("我的知识库").tag(CosmosKnowledgeSection.sources)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("知识库分区")
            }
        }
    }

    static func sectionBinding(navigator: CosmosNavigator) -> Binding<CosmosKnowledgeSection> {
        Binding(get: { navigator.knowledgeSection }, set: { navigator.knowledgeSection = $0 })
    }
}
