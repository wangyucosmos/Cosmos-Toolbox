import Foundation
import Combine

final class CosmosPromptSession: ObservableObject {
    let store: PromptVaultStore
    let model = PromptVaultViewModel()
    init(location: PromptVaultLocation) { store = PromptVaultStore(root: location.root, startupError: location.error) }
    func loadIfNeeded() async { if !store.loaded && !store.loading { await store.reload() } }
}
