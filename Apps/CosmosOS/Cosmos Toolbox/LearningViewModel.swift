import Foundation
import Combine
import AppKit

struct LearningTopicSummary: Identifiable, Equatable {
    let topic: LearningTopic
    /// The most recent study record, if any. Derived on demand; never stored on the topic.
    let lastEntry: LearningEntry?
    var id: UUID { topic.id }
}

final class LearningViewModel: ObservableObject {
    @Published var query = ""
    @Published var statusFilter: LearningStatus?
    @Published var showArchived = false
    @Published var onlyNextStep = false
    @Published var selectedID: UUID?
    @Published private(set) var copyMessage = ""
    private let copy: (String) -> Bool

    init(copy: @escaping (String) -> Bool = { text in
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }) { self.copy = copy }

    /// Filtered topics, most recently studied first. Topics without records follow, newest first.
    func summaries(topics: [LearningTopic], entries: [LearningEntry]) -> [LearningTopicSummary] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let grouped = Dictionary(grouping: entries, by: \.topicID)
        return topics.compactMap { topic -> LearningTopicSummary? in
            guard topic.isArchived == showArchived,
                  statusFilter == nil || topic.status == statusFilter,
                  !onlyNextStep || topic.hasNextStep else { return nil }
            let own = grouped[topic.id] ?? []
            if !search.isEmpty {
                let fields = [topic.name, topic.goal, topic.nextStep, topic.resourceURL ?? ""]
                guard fields.contains(where: { $0.localizedStandardContains(search) })
                        || own.contains(where: { $0.body.localizedStandardContains(search) }) else { return nil }
            }
            return LearningTopicSummary(topic: topic, lastEntry: own.min(by: LearningEntry.isNewer))
        }.sorted { lhs, rhs in
            switch (lhs.lastEntry, rhs.lastEntry) {
            case let (a?, b?):
                if a.id != b.id { return LearningEntry.isNewer(a, than: b) }
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): break
            }
            if lhs.topic.createdAt != rhs.topic.createdAt { return lhs.topic.createdAt > rhs.topic.createdAt }
            return lhs.topic.id.uuidString < rhs.topic.id.uuidString
        }
    }

    func history(topicID: UUID, entries: [LearningEntry]) -> [LearningEntry] {
        entries.filter { $0.topicID == topicID }.sorted(by: LearningEntry.isNewer)
    }

    func reconcileSelection(_ topics: [LearningTopic]) {
        if let selectedID, !topics.contains(where: { $0.id == selectedID }) { self.selectedID = nil }
    }

    @discardableResult func copyLink(_ topic: LearningTopic) -> Bool {
        guard let link = topic.resourceURL else { copyMessage = "没有可复制的链接。"; return false }
        let succeeded = copy(link)
        copyMessage = succeeded ? "已复制链接。" : "剪贴板写入失败，请重试。"
        return succeeded
    }
}
