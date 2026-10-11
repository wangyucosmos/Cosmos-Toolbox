#if DEBUG
import Foundation

/// Opt-in, memory-only diagnostic trace. Tests export synthetic-data timing outside the repository.
nonisolated final class CosmosExperienceTrace: @unchecked Sendable {
    static let shared = CosmosExperienceTrace()
    private let lock = NSLock()
    private var origin: TimeInterval?
    private var events: [(String, Double)] = []
    func start() { lock.lock(); defer { lock.unlock() }; origin = ProcessInfo.processInfo.systemUptime; events = [] }
    func mark(_ name: String) {
        lock.lock(); defer { lock.unlock() }
        guard let origin else { return }
        events.append((name, (ProcessInfo.processInfo.systemUptime - origin) * 1000))
    }
    func finish() -> [(String, Double)] {
        lock.lock(); defer { lock.unlock() }; origin = nil; return events
    }
    static func timed<T>(_ name: String, _ action: () throws -> T) rethrows -> T {
        shared.mark(name + ".begin"); defer { shared.mark(name + ".end") }; return try action()
    }
}
#endif
