import Foundation
import Combine

@MainActor
final class ProjectsStore: ObservableObject {
    @Published private(set) var projects: [PersonalProject] = []
    @Published private(set) var established = false
    @Published private(set) var loaded = false
    @Published private(set) var loading = false
    @Published private(set) var saving = false
    @Published private(set) var error: ProjectsError?
    private let storage: ProjectsFileStorage?
    let storageIdentity: String
    var canSave: Bool { loaded && !loading && !saving && error?.locksSaving != true }
    init(location: ProjectsLocation) {
        storage = location.root.map { ProjectsFileStorage(root: $0) }
        storageIdentity = location.root?.path ?? "blocked"; error = location.error
    }
    init(storage: ProjectsFileStorage) { self.storage = storage; storageIdentity = storage.root.path }
    func reload() async {
        guard !saving, !loading, let storage else { return }
        loading = true; defer { loading = false }
        do { adopt(try await storage.load()); loaded = true; error = nil }
        catch { self.error = (error as? ProjectsError) ?? .storage(error.localizedDescription); loaded = false }
    }
    func save(_ project: PersonalProject, expected: Int?) async -> Bool {
        guard canSave, let storage else { return false }
        saving = true; defer { saving = false }
        do { adopt(try await storage.apply(.save(project, expectedRevision: expected))); error = nil; return true }
        catch { self.error = (error as? ProjectsError) ?? .storage(error.localizedDescription); return false }
    }
    private func adopt(_ snapshot: ProjectsSnapshot) { projects = snapshot.projects; established = snapshot.established }
}
struct ProjectsLocation {
    let root: URL?
    let error: ProjectsError?
    static func resolve(isIsolated: Bool, bundleIdentifier: String?, arguments: [String]) -> Self {
#if DEBUG
        let flag = "--cosmos-projects-fixture-root", prefix = "/private/tmp/CosmosProjectsPhase1-"
        if isIsolated || arguments.contains(flag) {
            guard isIsolated, let bundleIdentifier,
                  bundleIdentifier.hasPrefix(CosmosDebugStorePersistenceBootstrap.isolatedBundleIdentifierPrefix),
                  let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return Self(root: nil, error: .unsafePath) }
            let path = arguments[index + 1]
            guard path.hasPrefix(prefix), UUID(uuidString: String(path.dropFirst(prefix.count))) != nil, !path.contains("..") else { return Self(root: nil, error: .unsafePath) }
            return Self(root: URL(fileURLWithPath: path, isDirectory: true), error: nil)
        }
#endif
        do { return Self(root: try ProjectsFileStorage.productionRoot(), error: nil) }
        catch { return Self(root: nil, error: .storage(error.localizedDescription)) }
    }
}
