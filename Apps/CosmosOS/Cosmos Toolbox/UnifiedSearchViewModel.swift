import Foundation
import Combine

@MainActor
final class UnifiedSearchViewModel: ObservableObject {
    typealias Load = @Sendable () async -> UnifiedSearchSnapshot
    @Published private(set) var rows: [UnifiedSearchRow] = []
    @Published private(set) var states: [UnifiedSearchSource: UnifiedSearchState] = [:]
    @Published private(set) var notices: [String] = []
    @Published private(set) var loading = false
    @Published private(set) var query = UnifiedSearchQuery()
    private let load: Load
    private let debounce: Duration
    private var snapshot: UnifiedSearchSnapshot?
    private var generation = 0
    private var task: Task<Void, Never>?

    init(debounce: Duration = .milliseconds(180), load: @escaping Load) {
        self.debounce = debounce; self.load = load
    }
    func search(_ query: UnifiedSearchQuery, refresh: Bool = false) {
        self.query = query
        generation += 1; let serial = generation
        task?.cancel(); rows = []
        if refresh { snapshot = nil }
        guard !query.keyword.isEmpty else {
            loading = false; states = [:]; notices = []; return
        }
        if let snapshot { publish(snapshot, query: query); return }
        loading = true; states = [:]; notices = []
        let load = self.load, debounce = self.debounce
        task = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            let snapshot = await load()
            guard let self, !Task.isCancelled, serial == self.generation else { return }
            self.snapshot = snapshot
            self.publish(snapshot, query: query)
        }
    }
    private func publish(_ snapshot: UnifiedSearchSnapshot, query: UnifiedSearchQuery) {
        rows = snapshot.rows.filter(query.matches)
        states = snapshot.states; notices = snapshot.notices; loading = false
    }
    func cancel() {
        generation += 1; task?.cancel(); task = nil; loading = false
    }
}
