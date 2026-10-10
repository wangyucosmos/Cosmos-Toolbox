import Foundation
import Combine

@MainActor
final class KnowledgeSourceStore: ObservableObject {
    enum ScanState: Equatable { case idle, scanning, failed(String) }
    enum GitActivity: Equatable { case idle, checking, fetching, pulling }

    @Published private(set) var sources: [KnowledgeSource] = []
    @Published private(set) var revision = 0
    @Published private(set) var established = false
    @Published private(set) var loaded = false
    @Published private(set) var loading = false
    @Published private(set) var saving = false
    @Published private(set) var error: KnowledgeSourceError?
    @Published private(set) var indexes: [UUID: KnowledgeIndex] = [:]
    @Published private(set) var scanStates: [UUID: ScanState] = [:]
    @Published private(set) var gitStatuses: [UUID: KnowledgeGitStatus] = [:]
    @Published private(set) var gitActivity: [UUID: GitActivity] = [:]
    @Published private(set) var gitResults: [UUID: KnowledgeGitOperationResult] = [:]

    private let storage: KnowledgeSourceFileStorage?
    let location: KnowledgeSourcesLocation
    let gitService: KnowledgeSourceGitService
    private var scanTasks: [UUID: Task<Void, Never>] = [:]
    private var gitTasks: [UUID: Task<Void, Never>] = [:]

    var canSave: Bool { loaded && !loading && !saving && error?.locksSaving != true }

    init(location: KnowledgeSourcesLocation, gitService: KnowledgeSourceGitService = KnowledgeSourceGitService()) {
        self.location = location; self.gitService = gitService
        storage = location.root.map { KnowledgeSourceFileStorage(root: $0) }
        error = location.error
    }
    init(storage: KnowledgeSourceFileStorage, location: KnowledgeSourcesLocation? = nil,
         gitService: KnowledgeSourceGitService = KnowledgeSourceGitService()) {
        self.storage = storage; self.gitService = gitService
        self.location = location ?? KnowledgeSourcesLocation(root: storage.root, error: nil)
    }

    // MARK: Registry

    func reload() async {
        guard !saving, !loading, let storage else { return }
        loading = true; defer { loading = false }
        do { adopt(try await storage.load()); loaded = true; error = nil }
        catch { self.error = (error as? KnowledgeSourceError) ?? .storage(error.localizedDescription); loaded = false }
    }

    func dismissError() { if error?.locksSaving == false { error = nil } }

    /// 用户选择文件夹后登记。仅保存路径；不读取、不修改文件夹。
    @discardableResult
    func add(folder url: URL, displayName: String? = nil) async -> Bool {
        guard canSave, let storage else { return false }
        guard let canonical = KnowledgeSourceScanner.canonicalDirectory(url) else {
            error = .invalidInput("无法打开所选文件夹，未添加。"); return false
        }
        if location.isolated, !canonical.hasPrefix("/private/tmp/") {
            error = .invalidInput("隔离环境只允许登记 /private/tmp 下的文件夹。"); return false
        }
        let fallback = (canonical as NSString).lastPathComponent
        guard let name = KnowledgeSource.validName(displayName ?? fallback) ?? KnowledgeSource.validName(String(fallback.prefix(KnowledgeSourceLimits.nameCharacters))) else {
            error = .invalidInput("文件夹名称无效。"); return false
        }
        let source = KnowledgeSource(displayName: name, path: canonical)
        guard await mutate(.add(source, expectedRevision: revision)) else { return false }
        scan(source)
        return true
    }
    func remove(_ id: UUID) async {
        guard canSave else { return }
        if await mutate(.remove(id: id, expectedRevision: revision)) { discardState(id) }
    }
    func rename(_ id: UUID, to name: String) async { guard canSave else { return }; _ = await mutate(.rename(id: id, name: name, expectedRevision: revision)) }
    func setEnabled(_ id: UUID, _ enabled: Bool) async {
        guard canSave else { return }
        if await mutate(.setEnabled(id: id, enabled: enabled, expectedRevision: revision)) {
            if enabled, let source = sources.first(where: { $0.id == id }) { scan(source) } else { discardState(id) }
        }
    }

    private func mutate(_ mutation: KnowledgeSourceMutation) async -> Bool {
        guard let storage else { return false }
        saving = true; defer { saving = false }
        do { adopt(try await storage.apply(mutation)); error = nil; return true }
        catch {
            let mapped = (error as? KnowledgeSourceError) ?? .storage(error.localizedDescription)
            self.error = mapped
            if mapped == .conflict, let snapshot = try? await storage.load() { adopt(snapshot) }
            return false
        }
    }
    private func adopt(_ snapshot: KnowledgeSourcesSnapshot) {
        sources = snapshot.sources; revision = snapshot.revision; established = snapshot.established
    }
    private func discardState(_ id: UUID) {
        scanTasks[id]?.cancel(); scanTasks[id] = nil; gitTasks[id]?.cancel(); gitTasks[id] = nil
        indexes[id] = nil; scanStates[id] = nil; gitStatuses[id] = nil; gitActivity[id] = nil; gitResults[id] = nil
    }

    // MARK: Scanning (background, memory only)

    func scanEnabledSourcesIfNeeded() {
        for source in sources where source.isEnabled && indexes[source.id] == nil && scanStates[source.id] != .scanning { scan(source) }
    }
    func rescanAll() { for source in sources where source.isEnabled { scan(source) } }

    func scan(_ source: KnowledgeSource) {
        guard source.isEnabled else { return }
        scanTasks[source.id]?.cancel()
        scanStates[source.id] = .scanning
        let id = source.id
        scanTasks[id] = Task { [weak self] in
            let result: Result<KnowledgeIndex, Error> = await Task.detached(priority: .utility) {
                Result { try KnowledgeSourceScanner.scan(source: source, mode: .full) }
            }.value
            guard let self, !Task.isCancelled, self.sources.contains(where: { $0.id == id && $0.isEnabled }) else { return }
            switch result {
            case .success(let index): self.indexes[id] = index; self.scanStates[id] = .idle
            case .failure(let error): self.scanStates[id] = .failed(error.localizedDescription)
            }
            self.scanTasks[id] = nil
        }
        if KnowledgeSourceGitService.isRepository(source.rootURL) { refreshGit(source.id) }
    }

    // MARK: Git (user-triggered only)

    func refreshGit(_ id: UUID) {
        guard let source = sources.first(where: { $0.id == id }), KnowledgeSourceGitService.isRepository(source.rootURL),
              (gitActivity[id] ?? .idle) == .idle else { return }
        gitActivity[id] = .checking
        let service = gitService, root = source.rootURL
        gitTasks[id] = Task { [weak self] in
            let status = await service.status(root: root)
            guard let self, !Task.isCancelled else { return }
            self.gitStatuses[id] = status; self.gitActivity[id] = .idle; self.gitTasks[id] = nil
        }
    }

    func fetchRemote(_ id: UUID) {
        guard let source = sources.first(where: { $0.id == id }), (gitActivity[id] ?? .idle) == .idle else { return }
        gitActivity[id] = .fetching; gitResults[id] = nil
        let service = gitService, root = source.rootURL
        gitTasks[id] = Task { [weak self] in
            let result = await service.fetch(root: root)
            let status = await service.status(root: root)
            guard let self, !Task.isCancelled else { return }
            self.gitResults[id] = result; self.gitStatuses[id] = status; self.gitActivity[id] = .idle; self.gitTasks[id] = nil
        }
    }

    /// 调用方必须已向用户展示确认对话框。
    func pullRemote(_ id: UUID) {
        guard let source = sources.first(where: { $0.id == id }), (gitActivity[id] ?? .idle) == .idle else { return }
        gitActivity[id] = .pulling; gitResults[id] = nil
        let service = gitService, root = source.rootURL
        gitTasks[id] = Task { [weak self] in
            let result = await service.pull(root: root)
            let status = await service.status(root: root)
            guard let self, !Task.isCancelled else { return }
            self.gitResults[id] = result; self.gitStatuses[id] = status; self.gitActivity[id] = .idle; self.gitTasks[id] = nil
            if result.outcome == .success, let current = self.sources.first(where: { $0.id == id }) { self.scan(current) }   // 拉取后自动重新扫描
        }
    }

    func cancelGit(_ id: UUID) { gitTasks[id]?.cancel() }

    /// 等待指定来源的扫描结束（测试与打开请求使用）。
    func waitForScan(_ id: UUID) async {
        while scanStates[id] == .scanning { try? await Task.sleep(for: .milliseconds(20)) }
    }
    func waitForGit(_ id: UUID) async {
        while (gitActivity[id] ?? .idle) != .idle { try? await Task.sleep(for: .milliseconds(20)) }
    }
}

/// 页内搜索：防抖、可取消、后台执行，过期结果不覆盖新查询。
@MainActor
final class KnowledgeSourceSearchModel: ObservableObject {
    @Published private(set) var hits: [KnowledgeSearchHit] = []
    @Published private(set) var searching = false
    private var generation = 0
    private var task: Task<Void, Never>?

    func search(_ query: String, in index: KnowledgeIndex?, debounce: Duration = .milliseconds(200)) {
        generation += 1; let serial = generation
        task?.cancel()
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index, !keyword.isEmpty else { hits = []; searching = false; return }
        searching = true
        task = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            let found = await Task.detached(priority: .userInitiated) { try? KnowledgeSourceSearch.search(keyword, in: index) }.value
            guard let self, !Task.isCancelled, serial == self.generation else { return }
            self.hits = found ?? []; self.searching = false
        }
    }
    func cancel() { generation += 1; task?.cancel(); task = nil; searching = false }
}
