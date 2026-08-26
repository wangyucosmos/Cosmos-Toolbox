import Foundation
import UniformTypeIdentifiers


// MARK: - Review Payload

struct ArtifactReviewMediaType: Equatable {

    let uniformTypeIdentifier: String?
    let mimeType: String?
    let fileExtension: String?
    let legacyArtifactType: ZhuowangArtifactType

    init(
        uniformTypeIdentifier: String? = nil,
        mimeType: String? = nil,
        fileExtension: String? = nil,
        legacyArtifactType: ZhuowangArtifactType
    ) {
        self.uniformTypeIdentifier = uniformTypeIdentifier
        self.mimeType = mimeType
        self.fileExtension = fileExtension?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        self.legacyArtifactType = legacyArtifactType
    }

    static func inlineText(
        artifactType: ZhuowangArtifactType
    ) -> ArtifactReviewMediaType {
        switch artifactType {
        case .html:
            return ArtifactReviewMediaType(
                uniformTypeIdentifier: "public.html",
                mimeType: "text/html",
                legacyArtifactType: artifactType
            )
        case .markdown:
            return ArtifactReviewMediaType(
                uniformTypeIdentifier: "net.daringfireball.markdown",
                mimeType: "text/markdown",
                legacyArtifactType: artifactType
            )
        case .prompt, .flowchart:
            return ArtifactReviewMediaType(
                uniformTypeIdentifier: "public.plain-text",
                mimeType: "text/plain",
                legacyArtifactType: artifactType
            )
        default:
            return ArtifactReviewMediaType(
                legacyArtifactType: artifactType
            )
        }
    }

    static func localFile(
        url: URL,
        artifactType: ZhuowangArtifactType
    ) -> ArtifactReviewMediaType {
        let fileExtension = url.pathExtension.lowercased()
        let uniformType = fileExtension.isEmpty
            ? nil
            : UTType(filenameExtension: fileExtension)

        return ArtifactReviewMediaType(
            uniformTypeIdentifier: uniformType?.identifier,
            mimeType: uniformType?.preferredMIMEType,
            fileExtension: fileExtension.isEmpty ? nil : fileExtension,
            legacyArtifactType: artifactType
        )
    }

    var classification: ArtifactReviewMediaClassification {
        let classifications = [
            Self.classification(
                uniformTypeIdentifier: uniformTypeIdentifier
            ),
            Self.classification(mimeType: mimeType),
            Self.classification(fileExtension: fileExtension),
            Self.classification(artifactType: legacyArtifactType)
        ].compactMap { $0 }

        guard let first = classifications.first else {
            return .unknown
        }

        return classifications.dropFirst().allSatisfy { $0 == first }
            ? first
            : .conflicting
    }

    private static func classification(
        uniformTypeIdentifier: String?
    ) -> ArtifactReviewMediaClassification? {
        guard let uniformTypeIdentifier,
              let type = UTType(uniformTypeIdentifier)
        else {
            return nil
        }

        if type.conforms(to: .html) {
            return .html
        }
        if type.conforms(to: .text) {
            return .text
        }
        if type.conforms(to: .image) {
            return .image
        }
        if type.conforms(to: .pdf)
            || type.conforms(to: .data) {
            return .binary
        }
        return nil
    }

    private static func classification(
        mimeType: String?
    ) -> ArtifactReviewMediaClassification? {
        let cleanMIME = mimeType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let cleanMIME, !cleanMIME.isEmpty else {
            return nil
        }

        if cleanMIME == "text/html"
            || cleanMIME == "application/xhtml+xml" {
            return .html
        }
        if cleanMIME.hasPrefix("text/")
            || cleanMIME == "application/json" {
            return .text
        }
        if cleanMIME.hasPrefix("image/") {
            return .image
        }
        if cleanMIME == "application/pdf"
            || cleanMIME == "application/octet-stream" {
            return .binary
        }
        return nil
    }

    private static func classification(
        fileExtension: String?
    ) -> ArtifactReviewMediaClassification? {
        switch fileExtension?.lowercased() {
        case "html", "htm":
            return .html
        case "md", "markdown", "txt", "json":
            return .text
        case "png", "jpg", "jpeg", "gif", "apng", "heic", "heif",
             "webp", "tif", "tiff", "svg":
            return .image
        case "pdf":
            return .binary
        default:
            return nil
        }
    }

    private static func classification(
        artifactType: ZhuowangArtifactType
    ) -> ArtifactReviewMediaClassification? {
        switch artifactType {
        case .html:
            return .html
        case .markdown, .prompt, .flowchart:
            return .text
        case .image:
            return .image
        case .pdf, .word, .excel:
            return .binary
        default:
            return nil
        }
    }
}


enum ArtifactReviewMediaClassification: Equatable {
    case html
    case text
    case image
    case binary
    case unknown
    case conflicting
}


struct ArtifactReviewInlineText: Equatable {
    let text: String
    let mediaType: ArtifactReviewMediaType
}


struct ArtifactReviewLocalFileReference: Equatable {
    let url: URL
    let mediaType: ArtifactReviewMediaType
}


enum ArtifactReviewUnavailableReason: Equatable {
    case missingLocation
    case fileMissing
    case unreadableFile
    case unsupportedMediaType
    case conflictingMediaType
}


struct ArtifactReviewUnavailablePayload: Equatable {
    let reason: ArtifactReviewUnavailableReason
    let mediaType: ArtifactReviewMediaType
}


enum ArtifactReviewPayload: Equatable {
    case inlineText(ArtifactReviewInlineText)
    case localFile(ArtifactReviewLocalFileReference)
    case unavailable(ArtifactReviewUnavailablePayload)

    var mediaType: ArtifactReviewMediaType {
        switch self {
        case .inlineText(let payload):
            return payload.mediaType
        case .localFile(let reference):
            return reference.mediaType
        case .unavailable(let payload):
            return payload.mediaType
        }
    }
}


enum ArtifactPreviewResolvedContent: Equatable {
    case text(String)
    case localFile(ArtifactReviewLocalFileReference)
    case unavailable(ArtifactReviewUnavailableReason)
}


struct ArtifactPreviewInput: Equatable {
    let payload: ArtifactReviewPayload
    let resolvedContent: ArtifactPreviewResolvedContent

    var mediaType: ArtifactReviewMediaType {
        payload.mediaType
    }

    var sourceText: String? {
        guard case .text(let text) = resolvedContent else {
            return nil
        }
        return text
    }

    var localFileReference: ArtifactReviewLocalFileReference? {
        guard case .localFile(let reference) = resolvedContent else {
            return nil
        }
        return reference
    }
}


struct ArtifactPreviewInputResolver {

    private let fileExists: (URL) -> Bool
    private let readUTF8Text: (URL) throws -> String

    init(
        fileExists: @escaping (URL) -> Bool = {
            FileManager.default.fileExists(atPath: $0.path)
        },
        readUTF8Text: @escaping (URL) throws -> String = {
            try String(contentsOf: $0, encoding: .utf8)
        }
    ) {
        self.fileExists = fileExists
        self.readUTF8Text = readUTF8Text
    }

    func resolve(
        _ payload: ArtifactReviewPayload
    ) -> ArtifactPreviewInput {
        switch payload {
        case .inlineText(let inlineText):
            guard inlineText.mediaType.classification != .conflicting else {
                return unavailableInput(
                    payload: payload,
                    reason: .conflictingMediaType
                )
            }
            return ArtifactPreviewInput(
                payload: payload,
                resolvedContent: .text(inlineText.text)
            )

        case .localFile(let reference):
            guard fileExists(reference.url) else {
                return unavailableInput(
                    payload: payload,
                    reason: .fileMissing
                )
            }

            switch reference.mediaType.classification {
            case .html, .text:
                do {
                    return ArtifactPreviewInput(
                        payload: payload,
                        resolvedContent: .text(
                            try readUTF8Text(reference.url)
                        )
                    )
                } catch {
                    return unavailableInput(
                        payload: payload,
                        reason: .unreadableFile
                    )
                }
            case .image:
                return ArtifactPreviewInput(
                    payload: payload,
                    resolvedContent: .localFile(reference)
                )
            case .conflicting:
                return unavailableInput(
                    payload: payload,
                    reason: .conflictingMediaType
                )
            case .binary, .unknown:
                return unavailableInput(
                    payload: payload,
                    reason: .unsupportedMediaType
                )
            }

        case .unavailable(let unavailable):
            return ArtifactPreviewInput(
                payload: payload,
                resolvedContent: .unavailable(unavailable.reason)
            )
        }
    }

    private func unavailableInput(
        payload: ArtifactReviewPayload,
        reason: ArtifactReviewUnavailableReason
    ) -> ArtifactPreviewInput {
        ArtifactPreviewInput(
            payload: payload,
            resolvedContent: .unavailable(reason)
        )
    }
}


struct ArtifactReviewDocumentProjection: Equatable {
    let id: UUID
    let name: String
    let versionLabel: String
    let type: ZhuowangArtifactType
    let payload: ArtifactReviewPayload
    let prototypeExecutionProfile: ZhuowangPrototypeExecutionProfile?
    let sourceProviderID: UUID?
    let sourceName: String
    let executedAt: Date
}


enum ArtifactReviewDocumentProjector {

    static func project(
        artifact: ZhuowangArtifact,
        providerName: String? = nil
    ) -> ArtifactReviewDocumentProjection {
        ArtifactReviewDocumentProjection(
            id: artifact.id,
            name: artifact.name,
            versionLabel: "V\(artifact.version)",
            type: artifact.type,
            payload: payload(for: artifact),
            prototypeExecutionProfile:
                artifact.prototypeExecutionProfile,
            sourceProviderID: artifact.providerID,
            sourceName: displaySourceName(
                providerName: providerName,
                providerID: artifact.providerID
            ),
            executedAt: artifact.createdAt
        )
    }

    static func project(
        id: UUID,
        draft: ZhuowangArtifactDraft,
        snapshot: ZhuowangWorkflowExecutionSnapshot?,
        providerName: String?
    ) -> ArtifactReviewDocumentProjection {
        ArtifactReviewDocumentProjection(
            id: id,
            name: draft.name,
            versionLabel: "Draft",
            type: draft.type,
            payload: .inlineText(
                ArtifactReviewInlineText(
                    text: draft.content,
                    mediaType: .inlineText(
                        artifactType: draft.type
                    )
                )
            ),
            prototypeExecutionProfile:
                snapshot?.prototypeExecutionProfile,
            sourceProviderID: snapshot?.providerID,
            sourceName: displaySourceName(
                providerName: providerName,
                providerID: snapshot?.providerID
            ),
            executedAt: snapshot?.createdAt ?? Date()
        )
    }

    private static func payload(
        for artifact: ZhuowangArtifact
    ) -> ArtifactReviewPayload {
        if let content = artifact.content,
           !content.isEmpty {
            return .inlineText(
                ArtifactReviewInlineText(
                    text: content,
                    mediaType: .inlineText(
                        artifactType: artifact.type
                    )
                )
            )
        }

        let location = artifact.location
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else {
            return .unavailable(
                ArtifactReviewUnavailablePayload(
                    reason: .missingLocation,
                    mediaType: .inlineText(
                        artifactType: artifact.type
                    )
                )
            )
        }

        let fileURL = URL(fileURLWithPath: location)
        return .localFile(
            ArtifactReviewLocalFileReference(
                url: fileURL,
                mediaType: .localFile(
                    url: fileURL,
                    artifactType: artifact.type
                )
            )
        )
    }

    private static func displaySourceName(
        providerName: String?,
        providerID: UUID?
    ) -> String {
        let cleanName = providerName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""

        if !cleanName.isEmpty {
            return cleanName
        }

        return providerID == nil
            ? "未记录"
            : "已记录 Provider"
    }
}


// MARK: - Artifact Review Document

/// Immutable Preview-layer input. It captures Artifact/Draft provenance once
/// and never consults the current Workflow selection while the review is open.
struct ArtifactReviewDocument:
    Identifiable,
    Equatable {

    let id: UUID
    let name: String
    let versionLabel: String
    let type: ZhuowangArtifactType
    let payload: ArtifactReviewPayload
    let previewInput: ArtifactPreviewInput
    let prototypeExecutionProfile: ZhuowangPrototypeExecutionProfile?
    let sourceProviderID: UUID?
    let sourceName: String
    let executedAt: Date

    init(
        id: UUID,
        draft: ZhuowangArtifactDraft,
        snapshot: ZhuowangWorkflowExecutionSnapshot?,
        providerName: String?
    ) {
        self.init(
            projection: ArtifactReviewDocumentProjector.project(
                id: id,
                draft: draft,
                snapshot: snapshot,
                providerName: providerName
            )
        )
    }

    init(
        artifact: ZhuowangArtifact,
        providerName: String? = nil
    ) {
        self.init(
            projection: ArtifactReviewDocumentProjector.project(
                artifact: artifact,
                providerName: providerName
            )
        )
    }

    init(
        projection: ArtifactReviewDocumentProjection,
        resolver: ArtifactPreviewInputResolver = .init()
    ) {
        id = projection.id
        name = projection.name
        versionLabel = projection.versionLabel
        type = projection.type
        payload = projection.payload
        previewInput = resolver.resolve(projection.payload)
        prototypeExecutionProfile =
            projection.prototypeExecutionProfile
        sourceProviderID = projection.sourceProviderID
        sourceName = projection.sourceName
        executedAt = projection.executedAt
    }

    var content: String {
        previewInput.sourceText ?? ""
    }

    var typeDisplayName: String {
        switch type {
        case .html:
            return "HTML Prototype"
        case .figma:
            return "Figma Prototype"
        case .image:
            return "Image"
        case .pdf:
            return "PDF"
        default:
            return type.title
        }
    }

    var fidelityDisplayName: String {
        prototypeExecutionProfile?.fidelity.title
            ?? "未记录"
    }

    var styleDisplayName: String {
        prototypeExecutionProfile?.style.title
            ?? "未记录"
    }

}


// MARK: - Review State

enum ArtifactReviewDisplayMode:
    String,
    CaseIterable,
    Identifiable {

    case preview
    case source

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preview:
            return "Preview"
        case .source:
            return "Source"
        }
    }
}


enum ArtifactReviewPresentationMode: Equatable {
    case workspace
    case fullPreview
}


enum ArtifactReviewMobileViewport:
    Int,
    CaseIterable,
    Identifiable {

    case width375 = 375
    case width390 = 390

    var id: Int { rawValue }

    var title: String {
        "\(rawValue)px"
    }

    var width: CGFloat {
        CGFloat(rawValue)
    }
}


struct ArtifactReviewWorkspaceState: Equatable {

    var displayMode: ArtifactReviewDisplayMode = .preview
    var presentationMode: ArtifactReviewPresentationMode = .workspace
    var mobileViewport: ArtifactReviewMobileViewport = .width390

    mutating func toggleFullPreview() {
        presentationMode = presentationMode == .workspace
            ? .fullPreview
            : .workspace
    }

    mutating func normalize(
        for capabilities: ArtifactPreviewRendererCapabilities
    ) {
        if displayMode == .source,
           !capabilities.supportsSource {
            displayMode = .preview
        }
        if presentationMode == .fullPreview,
           !capabilities.supportsFullPreview {
            presentationMode = .workspace
        }
    }
}


enum ArtifactDetailContentMode: Equatable {
    case preview
    case source

    static let initial: ArtifactDetailContentMode = .preview
}
