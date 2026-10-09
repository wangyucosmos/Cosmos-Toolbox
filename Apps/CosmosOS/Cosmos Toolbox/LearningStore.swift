import Foundation
import Combine

/// UI-facing state for the learning center. Every mutation goes through the storage transaction;
/// published state only changes after the storage has verified the write.
final class LearningStore: ObservableObject {
    @Published private(set) var topics: [LearningTopic] = []
    @Published private(set) var entries: [LearningEntry] = []
    @Published private(set) var error: LearningError?
    @Published private(set) var loading = false
    @Published private(set) var saving = false
    @Published private(set) var loaded = false
    private let storage: LearningFileStorage?
    private let today: () -> LearningDay
    let storageIdentity: String
    var canSave: Bool { loaded && !loading && !saving && error?.locksSaving != true }

    init(root: URL?, startupError: LearningError? = nil,
         today: @escaping () -> LearningDay = { LearningDay.today() }) {
        storage = root.map { LearningFileStorage(root: $0) }
        storageIdentity = root?.path ?? "blocked"
        self.today = today
        error = startupError
    }

    init(storage: LearningFileStorage, today: @escaping () -> LearningDay = { LearningDay.today() }) {
        self.storage = storage; storageIdentity = storage.root.path; self.today = today
    }

    func reload() async {
        guard let storage, !saving else { return }
        loading = true
        defer { loading = false }
        do {
            let snapshot = try await storage.load()
            topics = snapshot.topics; entries = snapshot.entries; error = nil; loaded = true
        } catch {
            self.error = (error as? LearningError) ?? .storage(error.localizedDescription)
            loaded = false
        }
    }

    @discardableResult
    func saveTopic(_ topic: LearningTopic, expectedRevision: Int?) async -> Bool {
        await run(.saveTopic(topic, expectedRevision: expectedRevision))
    }

    /// Saves an entry; when `nextStep` is given the topic's next step is updated in the same transaction.
    @discardableResult
    func saveEntry(_ entry: LearningEntry, expectedRevision: Int?, nextStep: LearningNextStepUpdate? = nil) async -> Bool {
        await run(.saveEntry(entry, expectedRevision: expectedRevision, nextStep: nextStep, today: today()))
    }

    @discardableResult
    func setStatus(_ topic: LearningTopic, _ status: LearningStatus) async -> Bool {
        await run(.changeTopic(id: topic.id, expectedRevision: topic.revision, change: .status(status)))
    }

    @discardableResult
    func setArchived(_ topic: LearningTopic, _ archived: Bool) async -> Bool {
        await run(.changeTopic(id: topic.id, expectedRevision: topic.revision, change: .archived(archived)))
    }

    private func run(_ mutation: LearningMutation) async -> Bool {
        guard canSave, let storage else { return false }
        saving = true
        defer { saving = false }
        do {
            let snapshot = try await storage.apply(mutation)
            topics = snapshot.topics; entries = snapshot.entries; error = nil
            return true
        } catch {
            self.error = (error as? LearningError) ?? .storage(error.localizedDescription)
            return false
        }
    }
}

struct LearningLocation {
    let root: URL?
    let error: LearningError?
    static let fixtureFlag = "--cosmos-learning-fixture-root"
    static let fixturePrefix = "/private/tmp/CosmosLearningPhase1-"

    /// DEBUG isolation fails closed: an isolated run without a valid temporary root never falls
    /// back to the production directory.
    static func resolve(isIsolated: Bool, bundleIdentifier: String?, arguments: [String]) -> Self {
#if DEBUG
        let index = arguments.firstIndex(of: fixtureFlag)
        if isIsolated || index != nil {
            guard isIsolated, let bundleIdentifier,
                  bundleIdentifier.hasPrefix(CosmosDebugStorePersistenceBootstrap.isolatedBundleIdentifierPrefix),
                  let index, index + 1 < arguments.count else { return Self(root: nil, error: .unsafePath) }
            let path = arguments[index + 1]
            guard path.hasPrefix(fixturePrefix),
                  UUID(uuidString: String(path.dropFirst(fixturePrefix.count))) != nil,
                  !path.contains("..") else { return Self(root: nil, error: .unsafePath) }
            return Self(root: URL(fileURLWithPath: path, isDirectory: true), error: nil)
        }
#endif
        do { return Self(root: try LearningFileStorage.productionRoot(), error: nil) }
        catch { return Self(root: nil, error: .storage(error.localizedDescription)) }
    }
}
