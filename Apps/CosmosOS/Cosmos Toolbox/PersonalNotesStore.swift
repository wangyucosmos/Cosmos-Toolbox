import Foundation
import Combine

@MainActor
final class PersonalNotesStore: ObservableObject {
    @Published private(set) var notes: [PersonalNote] = []
    /// 主文件是否已存在（区分“尚未建立”与“真实空库”）。
    @Published private(set) var established = false
    @Published private(set) var loaded = false
    @Published private(set) var loading = false
    @Published private(set) var saving = false
    @Published private(set) var error: PersonalNotesError?
    private let storage: PersonalNotesFileStorage?
    let storageIdentity: String
    let location: PersonalNotesLocation
    var canSave: Bool { loaded && !loading && !saving && error?.locksSaving != true }

    init(location: PersonalNotesLocation) {
        self.location = location
        storage = location.root.map { PersonalNotesFileStorage(root: $0) }
        storageIdentity = location.root?.path ?? "blocked"; error = location.error
    }
    init(storage: PersonalNotesFileStorage, location: PersonalNotesLocation? = nil) {
        self.storage = storage; storageIdentity = storage.root.path
        self.location = location ?? PersonalNotesLocation(root: storage.root, error: nil)
    }

    func reload() async {
        guard !saving, !loading, let storage else { return }
        loading = true; defer { loading = false }
        do { adopt(try await storage.load()); loaded = true; error = nil }
        catch { self.error = (error as? PersonalNotesError) ?? .storage(error.localizedDescription); loaded = false }
    }

    /// 失败时不发布任何结果：`notes` 保持原值，草稿由调用方保留。
    @discardableResult
    func save(_ note: PersonalNote, newReferences: [NoteReference] = [], expected: Int?) async -> Bool {
        guard canSave, let storage else { return false }
        saving = true; defer { saving = false }
        do {
            let result = try await storage.apply(.save(note, newReferences: newReferences, expectedRevision: expected))
            adopt(result.snapshot); error = nil; return true
        } catch {
            self.error = (error as? PersonalNotesError) ?? .storage(error.localizedDescription)
            return false
        }
    }

    enum RestoreOutcome: Equatable { case restored, unchanged, failed }
    /// 把所选历史版本的标题、正文、分类保存为新的当前内容版本。快照由磁盘最新文档按版本 UUID 取得。
    func restore(noteID: UUID, versionID: UUID, expectedRevision: Int) async -> RestoreOutcome {
        guard canSave, let storage else { return .failed }
        saving = true; defer { saving = false }
        do {
            let result = try await storage.apply(.restore(noteID: noteID, versionID: versionID, expectedRevision: expectedRevision))
            adopt(result.snapshot); error = nil
            return result.changed ? .restored : .unchanged
        } catch {
            self.error = (error as? PersonalNotesError) ?? .storage(error.localizedDescription)
            return .failed
        }
    }

    func setFavorite(_ note: PersonalNote) async {
        var candidate = note; candidate.isFavorite.toggle()
        _ = await save(candidate, expected: note.revision)
    }
    func setArchived(_ note: PersonalNote) async {
        var candidate = note; candidate.isArchived.toggle()
        _ = await save(candidate, expected: note.revision)
    }
    private func adopt(_ snapshot: PersonalNotesSnapshot) { notes = snapshot.notes; established = snapshot.established }
}

/// 存储位置与（仅 DEBUG 隔离时的）引用文件打开边界。
/// 正式数据：`~/Library/Application Support/Cosmos OS/PersonalNotes/notes.json`。
struct PersonalNotesLocation {
    let root: URL?
    let error: PersonalNotesError?
    /// DEBUG 隔离启动：文件引用只能打开位于 `referenceRoot` 内的文件；缺根则拒绝。Release 恒为 false。
    var isolated = false
    var referenceRoot: URL? = nil

    /// 隔离环境下的文件打开门控；返回失败原因，nil 表示允许继续既有的受控打开检查。
    func openBlockReason(for reference: NoteReference) -> String? {
        guard isolated, reference.kind == .file else { return nil }
        guard let referenceRoot else { return "隔离引用打开缺少临时根，未访问原文件。" }
        if let reason = UnifiedSearchNavigator.isolatedContainmentFailure(location: reference.location, root: referenceRoot) {
            return "隔离引用打开被阻止：\(reason)，未访问原文件。"
        }
        return nil
    }

    static func resolve(isIsolated: Bool, bundleIdentifier: String?, arguments: [String], referenceRoot: URL? = nil) -> Self {
#if DEBUG
        let flag = "--cosmos-notes-fixture-root", prefix = "/private/tmp/CosmosPersonalNotesPhase1-"
        if isIsolated || arguments.contains(flag) {
            guard isIsolated, let bundleIdentifier,
                  bundleIdentifier.hasPrefix(CosmosDebugStorePersistenceBootstrap.isolatedBundleIdentifierPrefix),
                  let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
                return Self(root: nil, error: .unsafePath)
            }
            let path = arguments[index + 1]
            guard path.hasPrefix(prefix), UUID(uuidString: String(path.dropFirst(prefix.count))) != nil,
                  !path.contains("..") else { return Self(root: nil, error: .unsafePath) }
            return Self(root: URL(fileURLWithPath: path, isDirectory: true), error: nil, isolated: true, referenceRoot: referenceRoot)
        }
#endif
        do { return Self(root: try PersonalNotesFileStorage.productionRoot(), error: nil) }
        catch { return Self(root: nil, error: .storage(error.localizedDescription)) }
    }
}
