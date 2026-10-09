import Foundation
import Combine

/// Drives the Home: reads once when it appears, again on manual refresh, and
/// re-projects (without re-reading) when the calendar day changes. No polling.
final class DashboardHomeViewModel: ObservableObject {

    typealias Load = (_ cache: DashboardReadCache, _ now: Date) async -> DashboardRaw

    @Published private(set) var display = DashboardDisplay()
    @Published private(set) var loading = false
    /// "Now" for greeting and date-dependent projections; updated at each read / re-projection.
    @Published private(set) var now: Date

    private let load: Load
    private let clock: () -> Date
    private let calendar: Calendar
    private let cache: DashboardReadCache
    private var lastRaw: DashboardRaw?
    private var generation = 0
    private var task: Task<Void, Never>?
    private var observer: AnyCancellable?

    init(
        cache: DashboardReadCache = DashboardReadCache(),
        calendar: Calendar = .current,
        clock: @escaping () -> Date = { Date() },
        observeDayChange: Bool = true,
        load: @escaping Load
    ) {
        self.cache = cache
        self.calendar = calendar
        self.clock = clock
        self.load = load
        self.now = clock()
        if observeDayChange {
            // A new day invalidates date-derived labels ("今天", 活动期) without any re-read.
            observer = NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
                .sink { [weak self] _ in self?.reproject() }
        }
    }

    /// Reads all sources again. A result that arrives after a newer refresh was
    /// requested (or after `cancel()`) is discarded.
    func refresh() {
        generation += 1
        let current = generation
        task?.cancel()
        loading = true
        let readAt = clock()
        task = Task { [weak self] in
            guard let self else { return }
            let raw = await self.load(self.cache, readAt)
            guard !Task.isCancelled, current == self.generation else { return }
            self.lastRaw = raw
            self.apply(raw)
            self.loading = false
        }
    }

    /// Recomputes every date-dependent projection from the already-read data.
    func reproject() {
        guard let lastRaw else { return }
        apply(lastRaw)
    }

    func cancel() {
        generation += 1
        task?.cancel()
        loading = false
    }

    private func apply(_ raw: DashboardRaw) {
        now = clock()
        let projected = DashboardProjection.project(raw, now: now, calendar: calendar)
        display = display.merging(projected, readAt: raw.readAt)
    }
}
