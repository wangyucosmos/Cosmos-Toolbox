import AppKit
import Combine

nonisolated enum UnifiedSearchDestination: Equatable {
    case campaign(UUID), artifact(UUID, campaignID: UUID), project(UUID), prompt(UUID), learning(UUID), note(UUID)
    case reference(CampaignExternalReference)

    static func resolve(_ requested: UnifiedSearchRow, in snapshot: UnifiedSearchSnapshot,
                        isolated: Bool) throws -> Self {
        guard let current = snapshot.rows.first(where: { $0.id == requested.id }),
              current.campaignID == requested.campaignID else {
            throw NavigationError.message("原对象已不存在、归属变化或来源不可读取；没有打开其他同名对象，请刷新。")
        }
        switch current.id.source {
        case .campaign:
            guard !isolated else { throw NavigationError.message("隔离环境已阻止活动详情：既有详情会自动恢复/迁移，本模块不回退正式 Workspace。导航目标为活动 ID：\(current.id.objectID)。") }
            return .campaign(current.id.objectID)
        case .artifact:
            guard let campaignID = current.campaignID else { throw NavigationError.message("Artifact 活动身份缺失。") }
            return .artifact(current.id.objectID, campaignID: campaignID)
        case .project: return .project(current.id.objectID)
        case .prompt: return .prompt(current.id.objectID)
        case .learning: return .learning(current.id.objectID)
        case .note: return .note(current.id.objectID)
        case .reference:
            guard let ref = current.reference, ref == requested.reference else {
                throw NavigationError.message("引用记录已变化，请刷新后核对；没有自动打开。")
            }
            return .reference(ref)
        }
    }
    nonisolated enum NavigationError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
    }
}

@MainActor
final class UnifiedSearchNavigator: ObservableObject {
    @Published var message: String?
    @Published var referenceRow: UnifiedSearchRow?
    private let reader: UnifiedSearchReader
    private let configuration: ZhuowangStorePersistenceConfiguration
    private let projects: ProjectsLocation
    private let prompts: PromptVaultLocation
    private let learning: LearningLocation
    private let notes: PersonalNotesLocation
    private let assetRoot: URL?
    private let systemOpen: (URL) -> Bool
    private var generation = 0
    private var isolated: Bool {
#if DEBUG
        configuration.isIsolated
#else
        false
#endif
    }
    init(reader: UnifiedSearchReader, configuration: ZhuowangStorePersistenceConfiguration,
         projects: ProjectsLocation, prompts: PromptVaultLocation, learning: LearningLocation,
         notes: PersonalNotesLocation = PersonalNotesLocation(root: nil, error: .unsafePath),
         assetRoot: URL?, systemOpen: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }) {
        self.reader = reader; self.configuration = configuration
        self.projects = projects; self.prompts = prompts; self.learning = learning; self.notes = notes
        self.assetRoot = assetRoot; self.systemOpen = systemOpen
    }
    func open(_ row: UnifiedSearchRow) async {
        generation += 1; let serial = generation
        do {
            let reader = self.reader
            let snapshot = await Task.detached { reader.read() }.value
            guard serial == generation, !Task.isCancelled else { return }
            let destination = try UnifiedSearchDestination.resolve(row, in: snapshot, isolated: isolated)
            switch destination {
            case .reference:
                referenceRow = snapshot.rows.first { $0.id == row.id }
            case .campaign(let id):
                // Only an explicit user action constructs the existing editing Stores.
                // The search reader never invokes these or the detail's recovery lifecycle.
                let store = ZhuowangCampaignStore(persistenceConfiguration: configuration)
                let workspace = ZhuowangWorkspaceStore(persistenceConfiguration: configuration)
                guard let campaign = store.campaign(id: id), store.persistenceState.allowsMutations,
                      workspace.persistenceState.allowsMutations else { throw unavailable() }
                let workflow = ZhuowangWorkflowStore(persistenceConfiguration: configuration)
                ZhuowangCampaignWindowManager.shared.open(campaign: campaign, store: store, workflowStore: workflow,
                    province: workspace.provinces.first { $0.id == campaign.provinceID },
                    module: workspace.modules.first { $0.id == campaign.moduleID })
            case .artifact(let id, let campaignID):
                guard !isolated || assetRoot != nil else { throw unavailable("隔离 Artifact 导航缺少临时文件根，已阻止。") }
                let model = ZhuowangAssetCatalogViewModel(dataSource: configuration.dataSource,
                    allowedRoot: assetRoot, requiresIsolatedRoot: isolated)
                model.filter = ZhuowangAssetFilter(allVersions: true, campaignID: campaignID)
                model.refresh()
                guard let entry = model.entries.first(where: { $0.id == id && $0.artifact.campaignID == campaignID }) else { throw unavailable() }
                ZhuowangAssetDetailWindowManager.shared.open(model: model, entry: entry)
            case .project(let id):
                let store = ProjectsStore(location: projects); await store.reload()
                guard serial == generation, !Task.isCancelled else { return }
                guard store.loaded, let project = store.projects.first(where: { $0.id == id }) else { throw unavailable(store.error?.localizedDescription) }
                ProjectsWindowManager.shared.open(store: store, project: project)
            case .prompt(let id):
                let store = PromptVaultStore(root: prompts.root, startupError: prompts.error); await store.reload()
                guard serial == generation, !Task.isCancelled else { return }
                guard store.loaded, let template = store.templates.first(where: { $0.id == id }) else { throw unavailable(store.error?.localizedDescription) }
                PromptTemplateWindowManager.shared.open(store: store, template: template)
            case .learning(let id):
                let store = LearningStore(root: learning.root, startupError: learning.error); await store.reload()
                guard serial == generation, !Task.isCancelled else { return }
                guard store.loaded, let topic = store.topics.first(where: { $0.id == id }) else { throw unavailable(store.error?.localizedDescription) }
                LearningEditorWindowManager.shared.openTopic(store: store, topic: topic)
            case .note(let id):
                // 重新读取最新元数据后按 UUID 打开既有原生笔记窗口；不跳同名对象。
                let store = PersonalNotesStore(location: notes); await store.reload()
                guard serial == generation, !Task.isCancelled else { return }
                guard store.loaded, let note = store.notes.first(where: { $0.id == id }) else { throw unavailable(store.error?.localizedDescription) }
                PersonalNoteWindowManager.shared.open(store: store, note: note)
            }
        } catch { message = error.localizedDescription }
    }
    func openReference(_ row: UnifiedSearchRow) async {
        do {
            let reader = self.reader
            let snapshot = await Task.detached { reader.read() }.value
            let destination = try UnifiedSearchDestination.resolve(row, in: snapshot, isolated: isolated)
            guard case .reference(let ref) = destination else { throw unavailable() }
            if isolated && ref.kind == .file {
                guard let assetRoot else { throw unavailable("隔离引用打开缺少临时根，未访问原文件。") }
                if let reason = Self.isolatedContainmentFailure(location: ref.location, root: assetRoot) {
                    throw unavailable("隔离引用打开被阻止：\(reason)，未访问原文件。")
                }
            }
            let url = try ref.openURL()
            if !systemOpen(url) { throw unavailable("系统未能打开引用，登记记录仍保留。") }
        } catch { message = error.localizedDescription }
    }
    /// nil means `location` resolves to a strict descendant of `root`. Both sides are canonicalised
    /// with realpath (so legitimate system aliases such as /tmp -> /private/tmp compare equal and any
    /// symlink escape lands outside the root) and compared by path components, never by string prefix.
    nonisolated static func isolatedContainmentFailure(location: String, root: URL) -> String? {
        guard location.hasPrefix("/"), !location.contains("\0"),
              !location.split(separator: "/").contains("..") else { return "路径不是绝对路径或包含路径穿越" }
        guard let canonicalRoot = canonicalComponents(root.path) else { return "临时根无法解析" }
        guard let canonicalTarget = canonicalComponents(location) else { return "引用路径无法解析（文件缺失或不可访问）" }
        guard canonicalTarget.count > canonicalRoot.count,
              Array(canonicalTarget.prefix(canonicalRoot.count)) == canonicalRoot else { return "路径在临时根之外" }
        return nil
    }
    private nonisolated static func canonicalComponents(_ path: String) -> [String]? {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard realpath(path, &buffer) != nil else { return nil }
        return String(cString: buffer).split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }
    private func unavailable(_ text: String? = nil) -> UnifiedSearchDestination.NavigationError {
        .message(text ?? "对象或必要来源不可读取；没有打开其他同名对象，请刷新。")
    }
}
