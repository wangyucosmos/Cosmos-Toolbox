import SwiftUI
import AppKit
import Combine

final class ZhuowangAssetCatalogViewModel: ObservableObject {
    @Published private(set) var entries: [ZhuowangAssetEntry] = []
    @Published private(set) var matches: [ZhuowangAssetMatch] = []
    @Published private(set) var revision = 0
    @Published private(set) var provinces: [ZhuowangProvince] = []
    @Published private(set) var campaigns: [ZhuowangCampaign] = []
    @Published private(set) var notices: [String] = []
    @Published private(set) var error: String?
    @Published private(set) var loading = false
    @Published var filter = ZhuowangAssetFilter() { didSet { scheduleSearch() } }
    private let reader: ZhuowangAssetCatalogReader
    let textReader: ZhuowangAssetTextReader
    private let isolationError: String?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var previewedIDs: Set<UUID> = []

    init(dataSource: any ZhuowangPersistenceDataSource, allowedRoot: URL? = nil, requiresIsolatedRoot: Bool = false) {
        reader = ZhuowangAssetCatalogReader(dataSource: dataSource)
        textReader = ZhuowangAssetTextReader(allowedRoot: allowedRoot)
        isolationError = requiresIsolatedRoot && allowedRoot == nil ? "隔离资产验证缺少临时文件根；已停止加载。" : nil
    }

    var unadoptedGroupCount: Int {
        Set(entries.filter { $0.adoptedCount == 0 }.map(\.groupID)).count
    }
    var conflictGroupCount: Int {
        Set(entries.filter { $0.adoptedCount > 1 }.map(\.groupID)).count
    }

    func refresh() {
        generation += 1; task?.cancel()
        for id in previewedIDs { ArtifactReviewWindowManager.shared.close(documentID: id) }
        previewedIDs.removeAll()
        revision += 1; matches = []; entries = []; error = nil; loading = true
        if let isolationError { error = isolationError; loading = false; return }
        do {
            let snapshot = try reader.read()
            entries = snapshot.entries; provinces = snapshot.provinces; campaigns = snapshot.campaigns; notices = snapshot.notices
        } catch { self.error = error.localizedDescription; loading = false; return }
        scheduleSearch(refreshCache: true, debounce: false)
    }

    func scheduleSearch(refreshCache: Bool = false, debounce: Bool = true) {
        generation += 1; let currentGeneration = generation
        task?.cancel(); loading = true; matches = []
        let candidates = entries.filter(filter.includes)
        let query = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
        task = Task { [weak self] in
            guard let self else { return }
            if debounce { try? await Task.sleep(for: .milliseconds(250)) }
            guard !Task.isCancelled, currentGeneration == self.generation else { return }
            if refreshCache { await self.textReader.invalidate() }
            var result: [ZhuowangAssetMatch] = []
            for entry in candidates {
                guard !Task.isCancelled, currentGeneration == self.generation else { return }
                let request = Self.request(for: entry)
                guard let body = await self.textReader.read(request) else { return }
                let metadataMatch = query.isEmpty || entry.artifact.name.localizedStandardContains(query)
                    || entry.campaignName.localizedStandardContains(query)
                let snippet = request.searchesText ? Self.snippet(body.text, query: query) : nil
                if metadataMatch || snippet != nil { result.append(ZhuowangAssetMatch(entry: entry, snippet: snippet)) }
            }
            guard !Task.isCancelled, currentGeneration == self.generation else { return }
            self.matches = result; self.loading = false
        }
    }

    func resolveDetail(id: UUID) async -> ZhuowangAssetBody? {
        let serial = generation
        guard let entry = entries.first(where: { $0.id == id }) else { return nil }
        let body = await textReader.read(Self.request(for: entry))
        guard serial == generation, entries.contains(entry), !Task.isCancelled else { return nil }
        return body
    }

    func registerPreview(id: UUID) { previewedIDs.insert(id) }

    static func request(for entry: ZhuowangAssetEntry) -> ZhuowangAssetTextRequest {
        let artifact = entry.artifact
        let media = ArtifactReviewMediaType.localFile(url: URL(fileURLWithPath: artifact.location), artifactType: artifact.type)
        let inline = ArtifactReviewMediaType.inlineText(artifactType: artifact.type)
        return ZhuowangAssetTextRequest(id: entry.id, content: artifact.content, location: artifact.location,
            readsTextFile: media.classification == .text || media.classification == .html,
            searchesText: inline.classification == .text || (artifact.content == nil || artifact.content == "") && media.classification == .text)
    }

    static func snippet(_ text: String?, query: String) -> String? {
        guard !query.isEmpty, let text, let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else { return nil }
        let start = text.index(range.lowerBound, offsetBy: -45, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 80, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[start..<end])
    }

    static func document(entry: ZhuowangAssetEntry, body: ZhuowangAssetBody) -> ArtifactReviewDocument {
        var artifact = entry.artifact
        artifact.content = body.text
        artifact.location = body.admittedPath ?? ""
        var projection = ArtifactReviewDocumentProjector.project(artifact: artifact, providerName: entry.campaignName + " · " + (entry.providerName ?? "未记录 Provider"))
        if entry.artifact.content == nil || entry.artifact.content == "",
           let path = body.admittedPath, Self.request(for: entry).readsTextFile {
            projection = ArtifactReviewDocumentProjection(id: entry.id, name: artifact.name,
                versionLabel: "V\(artifact.version)", type: artifact.type,
                payload: .localFile(ArtifactReviewLocalFileReference(url: URL(fileURLWithPath: path),
                    mediaType: .localFile(url: URL(fileURLWithPath: path), artifactType: artifact.type))),
                prototypeExecutionProfile: artifact.prototypeExecutionProfile, sourceProviderID: artifact.providerID,
                sourceName: entry.providerName ?? "未记录", executedAt: artifact.createdAt)
        }
        if body.text == nil && Self.request(for: entry).readsTextFile {
            projection = ArtifactReviewDocumentProjection(id: entry.id, name: artifact.name,
                versionLabel: "V\(artifact.version)", type: artifact.type,
                payload: .unavailable(ArtifactReviewUnavailablePayload(reason: .unreadableFile,
                    mediaType: .inlineText(artifactType: artifact.type))),
                prototypeExecutionProfile: artifact.prototypeExecutionProfile, sourceProviderID: artifact.providerID,
                sourceName: entry.providerName ?? "未记录", executedAt: artifact.createdAt)
        }
        return ArtifactReviewDocument(projection: projection, resolver: ArtifactPreviewInputResolver(
            fileExists: { _ in body.admittedPath != nil }, readUTF8Text: { _ in
                guard let text = body.text else { throw CocoaError(.fileReadNoPermission) }; return text
            }))
    }
}

struct ZhuowangAssetActions {
    var copy: (String) -> Void = { text in
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
    }
    var reveal: (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) }
    var preview: (ArtifactReviewDocument) -> Void = { ArtifactReviewWindowManager.shared.open(document: $0) }
}
