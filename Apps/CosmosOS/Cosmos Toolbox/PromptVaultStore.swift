import Foundation
import Combine

final class PromptVaultStore: ObservableObject {
    @Published private(set) var templates: [PromptTemplate] = []
    @Published private(set) var error: PromptVaultError?
    @Published private(set) var loading = false
    @Published private(set) var saving = false
    @Published private(set) var loaded = false
    private let storage: PromptVaultFileStorage?
    let storageIdentity: String
    var canSave: Bool { loaded && !loading && !saving && error?.locksSaving != true }

    init(root: URL?, startupError: PromptVaultError? = nil) {
        storage = root.map { PromptVaultFileStorage(root: $0) }
        storageIdentity = root?.path ?? "blocked"
        error = startupError
    }
    init(storage: PromptVaultFileStorage) {
        self.storage = storage; storageIdentity = storage.root.path
    }
    func reload() async {
        guard let storage, !saving else { return }
        loading = true
        defer { loading = false }
        do { templates = try await storage.load(); error = nil; loaded = true }
        catch { self.error = (error as? PromptVaultError) ?? .storage(error.localizedDescription); loaded = false }
    }
    @discardableResult
    func save(_ template: PromptTemplate, expectedRevision: Int?) async -> Bool {
        guard canSave, let storage else { return false }
        saving = true
        defer { saving = false }
        do {
            templates = try await storage.save(template, expectedRevision: expectedRevision)
            error = nil; return true
        } catch {
            self.error = (error as? PromptVaultError) ?? .storage(error.localizedDescription)
            return false
        }
    }
    func setFavorite(_ template: PromptTemplate) async {
        var candidate = template; candidate.isFavorite.toggle()
        _ = await save(candidate, expectedRevision: template.revision)
    }
    func setArchived(_ template: PromptTemplate) async {
        var candidate = template; candidate.isArchived.toggle()
        _ = await save(candidate, expectedRevision: template.revision)
    }
}

struct PromptVaultLocation {
    let root: URL?
    let error: PromptVaultError?
    static func resolve(isIsolated: Bool, bundleIdentifier: String?, arguments: [String]) -> Self {
#if DEBUG
        let flag = "--cosmos-prompt-fixture-root"
        let index = arguments.firstIndex(of: flag)
        if isIsolated || index != nil {
            guard isIsolated, let bundleIdentifier,
                  bundleIdentifier.hasPrefix(CosmosDebugStorePersistenceBootstrap.isolatedBundleIdentifierPrefix),
                  let index, index + 1 < arguments.count else { return Self(root: nil, error: .unsafePath) }
            let path = arguments[index + 1]
            let prefix = "/private/tmp/CosmosPromptVaultPhase1-"
            guard path.hasPrefix(prefix), UUID(uuidString: String(path.dropFirst(prefix.count))) != nil,
                  !path.contains("..") else { return Self(root: nil, error: .unsafePath) }
            return Self(root: URL(fileURLWithPath: path, isDirectory: true), error: nil)
        }
#endif
        do { return Self(root: try PromptVaultFileStorage.productionRoot(), error: nil) }
        catch { return Self(root: nil, error: .storage(error.localizedDescription)) }
    }
}
