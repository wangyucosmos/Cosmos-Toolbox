import Foundation
import Combine

nonisolated struct CampaignExternalReference: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable { case file, link, correction }

    let id: UUID
    let campaignID: UUID
    let kind: Kind
    let name: String
    let versionLabel: String
    let location: String
    let notes: String
    let recordedAt: Date
    let correctsReferenceID: UUID?

    init(id: UUID = UUID(), campaignID: UUID, kind: Kind, name: String,
         versionLabel: String = "", location: String = "", notes: String = "",
         recordedAt: Date = Date(), correctsReferenceID: UUID? = nil) {
        self.id = id; self.campaignID = campaignID; self.kind = kind
        self.name = name; self.versionLabel = versionLabel; self.location = location
        self.notes = notes; self.recordedAt = recordedAt; self.correctsReferenceID = correctsReferenceID
    }

    var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch kind {
        case .file:
            return correctsReferenceID == nil && location.hasPrefix("/") &&
                !location.contains("\0") && !location.split(separator: "/").contains("..")
        case .link: return correctsReferenceID == nil && Self.webURL(location) != nil
        case .correction:
            return correctsReferenceID != nil && location.isEmpty &&
                !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    static func webURL(_ text: String) -> URL? {
        guard !text.contains(where: { $0.isWhitespace }),
              let parts = URLComponents(string: text),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              let host = parts.host, !host.isEmpty, let url = parts.url else { return nil }
        return url
    }

    /// Metadata only; never reads contents or repairs the saved path.
    func openURL() throws -> URL {
        guard isValid else { throw ReferenceError.unavailable("引用格式无效，记录仍保留。") }
        switch kind {
        case .link: return Self.webURL(location)!
        case .correction: throw ReferenceError.unavailable("更正说明没有可打开的文件或链接。")
        case .file:
            let url = URL(fileURLWithPath: location)
            var ancestor = url
            while ancestor.path != "/" {
                let values = try? ancestor.resourceValues(forKeys: [.isSymbolicLinkKey])
                if values?.isSymbolicLink == true {
                    throw ReferenceError.unavailable("路径包含符号链接，未打开；请另行登记明确的原文件。")
                }
                ancestor.deleteLastPathComponent()
            }
            guard FileManager.default.fileExists(atPath: location) else {
                throw ReferenceError.unavailable("原文件不存在或不可访问，可能已移动或删除；登记记录仍保留，不自动修复路径。")
            }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isReadableKey])
            guard values.isRegularFile == true, values.isReadable == true else {
                throw ReferenceError.unavailable("原路径不是可读取的普通文件；登记记录仍保留。")
            }
            return url
        }
    }

    enum ReferenceError: LocalizedError {
        case unavailable(String)
        var errorDescription: String? { if case let .unavailable(message) = self { return message }; return nil }
    }
}

@MainActor
final class CampaignReferenceDraft: ObservableObject {
    @Published var kind: CampaignExternalReference.Kind = .file
    @Published var name = ""
    @Published var versionLabel = ""
    @Published var location = ""
    @Published var notes = ""
    @Published var message: String?
    private(set) var expectedCount = 0
    private(set) var correctsReferenceID: UUID?

    func begin(records: [CampaignExternalReference], correcting: UUID? = nil) {
        kind = correcting == nil ? .file : .correction
        name = correcting == nil ? "" : "更正说明"
        versionLabel = ""; location = ""; notes = ""; message = nil
        expectedCount = records.count; correctsReferenceID = correcting
    }

    func save(store: ZhuowangCampaignStore, campaignID: UUID) -> Bool {
        let record = CampaignExternalReference(campaignID: campaignID, kind: kind, name: name,
            versionLabel: versionLabel, location: location, notes: notes, correctsReferenceID: correctsReferenceID)
        guard record.isValid else { message = "请填写名称并选择文件、填写有效 http/https 链接，或填写更正原文。"; return false }
        let result = store.appendReference(record, expectedCount: expectedCount)
        guard result.succeeded else { message = result.userMessage; return false }
        return true
    }
}
