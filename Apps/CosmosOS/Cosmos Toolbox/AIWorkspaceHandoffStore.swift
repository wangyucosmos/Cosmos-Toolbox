import AppKit
import Combine
import Foundation

final class AIWorkspaceHandoffStore: ObservableObject {
    @Published private(set) var records: [AIWorkspaceHandoffRecord] = []
    @Published private(set) var loading = false
    @Published private(set) var saving = false
    @Published private(set) var loaded = false
    @Published private(set) var loadError: String?
    @Published private(set) var saveFeedback: String?
    @Published private(set) var lastSavedPrompt: String?
    private let storage: AIWorkspaceHandoffFileStorage?
    private var pendingRecord: AIWorkspaceHandoffRecord?
    private let clock: () -> Date
    let location: AIWorkspaceHandoffLocation

    init(location: AIWorkspaceHandoffLocation, clock: @escaping () -> Date = { Date() },
         storage: AIWorkspaceHandoffFileStorage? = nil) {
        self.location = location
        self.storage = storage ?? location.root.map { AIWorkspaceHandoffFileStorage(root: $0) }
        self.clock = clock
        loadError = location.error?.localizedDescription
    }

    func reload() async {
        guard let storage, !saving, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            publish(try await storage.load())
            loaded = true; loadError = nil
        } catch {
            loaded = false; loadError = error.localizedDescription
        }
    }

    private func publish(_ values: [AIWorkspaceHandoffRecord]) {
        records = values.sorted {
            $0.recordedAt == $1.recordedAt ? $0.id.uuidString < $1.id.uuidString : $0.recordedAt > $1.recordedAt
        }
    }

    func alreadyRecorded(_ preview: String?) -> Bool {
        guard let preview, let lastSavedPrompt else { return false }
        return Data(preview.utf8) == Data(lastSavedPrompt.utf8)
    }

    /// Explicitly arms a later, intentional handoff of the same text. Never writes by itself.
    func prepareAnotherHandoff() {
        guard !saving else { return }
        lastSavedPrompt = nil; pendingRecord = nil; saveFeedback = "可再次记录当前预览为新的一次交接。"
    }

    func recordCurrent(_ preparation: AIWorkspaceTaskPreparation) async {
        guard !saving, !loading, !alreadyRecorded(preparation.preview) else { return }
        guard let storage, loaded, loadError == nil else {
            saveFeedback = loadError ?? "请先加载交接记录，再保存。"; return
        }
        saving = true
        defer { saving = false }
        do {
            guard let displayed = preparation.preview else {
                saveFeedback = preparation.validation; return
            }
            try await preparation.revalidateReferencesForDelivery()
            guard let current = preparation.preview, Data(current.utf8) == Data(displayed.utf8) else {
                saveFeedback = "预览已变化，未记录；请核对后再次记录。"; return
            }
            let retry = pendingRecord.flatMap { pending -> AIWorkspaceHandoffRecord? in
                guard let preview = preparation.preview,
                      Data(pending.prompt.utf8) == Data(preview.utf8),
                      pending.campaignID == preparation.campaignID,
                      pending.workflowID == preparation.workflow?.id,
                      Data(pending.goal.utf8) == Data(preparation.goal.utf8),
                      Data(pending.requirements.utf8) == Data(preparation.requirements.utf8),
                      pending.toolIdentifier == preparation.tool.id,
                      pending.stepID == preparation.stepID else { return nil }
                return pending
            }
            let record = try preparation.snapshotForRecording(id: retry?.id ?? UUID(), at: retry?.recordedAt ?? clock())
            pendingRecord = record
            publish(try await storage.append(record))
            lastSavedPrompt = record.prompt
            pendingRecord = nil
            saveFeedback = "已记录点击时的完整预览快照；这不代表已发送、执行或完成。"
        } catch { saveFeedback = error.localizedDescription }
    }

    var campaignFilters: [(id: UUID, name: String)] {
        var seen = Set<UUID>()
        return records.compactMap { record in
            guard seen.insert(record.campaignID).inserted else { return nil }
            return (record.campaignID, record.campaignName)
        }
    }
}

struct AIWorkspaceHandoffLocation {
    let root: URL?
    let error: AIWorkspaceHandoffError?
    static let fixtureFlag = "--cosmos-ai-handoff-fixture-root"
    static let fixturePrefix = "/private/tmp/CosmosAIHandoffPhase3-"

    static func resolve(isIsolated: Bool, bundleIdentifier: String?, arguments: [String]) -> Self {
#if DEBUG
        let index = arguments.firstIndex(of: fixtureFlag)
        if isIsolated || index != nil {
            guard isIsolated, let bundleIdentifier,
                  bundleIdentifier.hasPrefix(CosmosDebugStorePersistenceBootstrap.isolatedBundleIdentifierPrefix),
                  let index, index + 1 < arguments.count else { return Self(root: nil, error: .unsafePath) }
            let path = arguments[index + 1]
            guard path.hasPrefix(fixturePrefix), UUID(uuidString: String(path.dropFirst(fixturePrefix.count))) != nil,
                  !path.contains("..") else { return Self(root: nil, error: .unsafePath) }
            return Self(root: URL(fileURLWithPath: path, isDirectory: true), error: nil)
        }
#endif
        do { return Self(root: try AIWorkspaceHandoffFileStorage.productionRoot(), error: nil) }
        catch { return Self(root: nil, error: .storage(error.localizedDescription)) }
    }
}

final class AIWorkspaceHandoffCopyModel: ObservableObject {
    @Published private(set) var feedback: String?
    private let copy: (String) -> Bool
    init(copy: @escaping (String) -> Bool = { text in
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }) { self.copy = copy }
    func copySnapshot(_ record: AIWorkspaceHandoffRecord) {
        feedback = copy(record.prompt) ? "已复制保存时的完整提示词快照" : "复制失败，请重试。"
    }
}
