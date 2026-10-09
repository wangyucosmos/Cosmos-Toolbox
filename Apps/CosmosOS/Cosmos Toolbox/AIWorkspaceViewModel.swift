import Foundation
import Combine

/// Drives the AI 工作台 page. Detection is manual; the last completed result is
/// kept in memory (via the cache) and never persisted. Leaving the page cancels
/// an unfinished detection, and a superseded run can never overwrite a newer
/// result.
final class AIWorkspaceViewModel: ObservableObject {

    typealias Detect = @Sendable () async -> AIWorkspaceSnapshot?

    @Published private(set) var snapshot: AIWorkspaceSnapshot?
    @Published private(set) var isDetecting = false

    private let cache: AIWorkspaceResultCache
    private let detect: Detect
    private var generation = 0
    private var task: Task<Void, Never>?

    init(
        cache: AIWorkspaceResultCache = AIWorkspaceResultCache(),
        detect: @escaping Detect = { await AIWorkspaceToolProbe.live().detectAll() }
    ) {
        self.cache = cache
        self.detect = detect
        self.snapshot = cache.snapshot
    }

    /// Starts one detection. Ignored while one is already running.
    func refresh() {
        guard !isDetecting else { return }
        generation += 1
        let mine = generation
        isDetecting = true
        let detect = self.detect
        task = Task { [weak self] in
            let result = await detect()
            guard let self, self.generation == mine, !Task.isCancelled else { return }
            if let result {
                self.snapshot = result
                self.cache.snapshot = result
            }
            self.isDetecting = false
            self.task = nil
        }
    }

    /// Cancels an unfinished detection (page left). A finished result stays.
    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        isDetecting = false
    }
}
