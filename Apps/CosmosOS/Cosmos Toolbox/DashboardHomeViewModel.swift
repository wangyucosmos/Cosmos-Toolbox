import Foundation
import Combine

/// Drives the Home: reads once when it appears, again on manual refresh, and
/// re-projects (without re-reading) when the calendar day changes. No polling.
final class DashboardHomeViewModel: ObservableObject {

    typealias Load = (_ cache: DashboardReadCache, _ now: Date) async -> DashboardRaw

    @Published private(set) var display = DashboardDisplay()
    @Published private(set) var loading = false
    @Published private(set) var homeData = DashboardHomeData()
    @Published private(set) var delivery: DashboardDeliveryState = .loading
    typealias HomeLoad = @Sendable (Date, Calendar) async -> DashboardHomeData
    typealias Delivery = @MainActor ([ZhuowangCampaign], [ZhuowangCampaignWorkflow], ZhuowangWorkspaceSnapshot?, Date, Calendar) throws -> Int
    private var homeLoad: HomeLoad?
    private var deliveryCalculation: Delivery?
    private var isolated = false
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
        homeLoad: HomeLoad? = nil,
        deliveryCalculation: Delivery? = nil,
        isolated: Bool = false,
        load: @escaping Load
    ) {
        self.homeLoad = homeLoad
        self.deliveryCalculation = deliveryCalculation
        self.isolated = isolated
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
        if let homeLoad {
            refreshHome(homeLoad)
            return
        }
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
        if homeLoad != nil { refresh(); return }
        guard let lastRaw else { return }
        apply(lastRaw)
    }

    func cancel() {
        generation += 1
        task?.cancel()
        loading = false
    }

    private func refreshHome(_ load: @escaping HomeLoad) {
        guard !loading else { return }
        generation += 1
        let serial = generation, now = clock(), calendar = calendar
        loading = true; delivery = .loading
        task = Task { [weak self] in
            let data = await load(now, calendar)
            guard let self, !Task.isCancelled, serial == self.generation else { return }
            self.homeData = data; self.now = now; self.loading = false
            // Publish the background sources before the one allowed main-thread check.
            await Task.yield()
            guard !Task.isCancelled, serial == self.generation else { return }
            if let error = data.deliveryError { self.delivery = .failed(error); return }
            if self.isolated && self.deliveryCalculation == nil {
                self.delivery = .failed("隔离环境未注入交付检查；已阻止访问正式 Workspace")
                return
            }
            let decoded = await Task.detached {
                (data.campaignBytes.flatMap(DashboardDecoding.campaigns),
                 data.workflowBytes.flatMap(DashboardDecoding.workflows),
                 data.workspaceBytes.flatMap(DashboardDecoding.workspace))
            }.value
            guard !Task.isCancelled, serial == self.generation else { return }
            do {
                if let calculation = self.deliveryCalculation {
                    self.delivery = .loaded(try calculation(decoded.0 ?? [], decoded.1 ?? [], decoded.2, now, calendar))
                } else {
                    let rows = ZhuowangCampaignProgressBuilder.build(campaigns: decoded.0 ?? [], workflows: decoded.1 ?? [],
                        provinces: decoded.2?.provinces ?? [], modules: decoded.2?.modules ?? [], now: now, calendar: calendar)
                    self.delivery = .loaded(rows.filter { $0.category == .deliverable }.count)
                }
            } catch { self.delivery = .failed(error.localizedDescription) }
        }
    }

    /// Synthetic, already-published data for deterministic offscreen acceptance.
    convenience init(snapshot: DashboardHomeData, delivery: DashboardDeliveryState) {
        self.init(observeDayChange: false, load: { _, now in
            DashboardRaw(readAt: now, campaigns: .notBuilt, workflows: .notBuilt, workspace: .notBuilt, prompts: .notBuilt, learning: .notBuilt)
        })
        homeData = snapshot; self.delivery = delivery
        now = snapshot.readAt ?? Date()
    }

    private func apply(_ raw: DashboardRaw) {
        now = clock()
        let projected = DashboardProjection.project(raw, now: now, calendar: calendar)
        display = display.merging(projected, readAt: raw.readAt)
    }
}

nonisolated enum DashboardDeliveryState: Equatable { case loading, loaded(Int), failed(String)
    var value: Int? { if case .loaded(let value) = self { return value }; return nil }
    var error: String? { if case .failed(let value) = self { return value }; return nil }
    var isLoading: Bool { self == .loading }
}
