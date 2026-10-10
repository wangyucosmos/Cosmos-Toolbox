import Foundation
import Combine

@MainActor
final class MacEnvironmentViewModel: ObservableObject {
    typealias Read = @Sendable () async -> MacEnvironmentSnapshot
    @Published private(set) var snapshot: MacEnvironmentSnapshot?
    @Published private(set) var isReading = false
    private let read: Read
    private var generation = 0
    private var task: Task<Void, Never>?

    init(read: @escaping Read = { await MacEnvironmentService().readInBackground() }) { self.read = read }
    func loadIfNeeded() { if snapshot == nil { refresh() } }
    func refresh() {
        guard !isReading else { return }
        generation += 1
        let mine = generation, read = self.read
        isReading = true
        task = Task { [weak self] in
            let value = await read()
            guard let self, self.generation == mine, !Task.isCancelled else { return }
            self.snapshot = value
            self.isReading = false
            self.task = nil
        }
    }
    func cancel() {
        generation += 1
        task?.cancel(); task = nil; isReading = false
    }
}
