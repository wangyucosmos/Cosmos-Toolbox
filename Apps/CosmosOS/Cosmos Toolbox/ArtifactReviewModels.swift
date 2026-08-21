import Foundation


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
    let content: String
    let prototypeExecutionProfile: ZhuowangPrototypeExecutionProfile?
    let sourceProviderID: UUID?
    let sourceName: String
    let executedAt: Date

    init(
        id: UUID = UUID(),
        draft: ZhuowangArtifactDraft,
        snapshot: ZhuowangWorkflowExecutionSnapshot?,
        providerName: String?
    ) {
        self.id = id
        name = draft.name
        versionLabel = "Draft"
        type = draft.type
        content = draft.content
        prototypeExecutionProfile =
            snapshot?.prototypeExecutionProfile
        sourceProviderID = snapshot?.providerID
        sourceName = Self.displaySourceName(
            providerName: providerName,
            providerID: snapshot?.providerID
        )
        executedAt = snapshot?.createdAt ?? Date()
    }

    init(
        id: UUID = UUID(),
        artifact: ZhuowangArtifact,
        providerName: String? = nil
    ) {
        self.id = id
        name = artifact.name
        versionLabel = "V\(artifact.version)"
        type = artifact.type
        content = Self.reviewContent(for: artifact)
        prototypeExecutionProfile =
            artifact.prototypeExecutionProfile
        sourceProviderID = artifact.providerID
        sourceName = Self.displaySourceName(
            providerName: providerName,
            providerID: artifact.providerID
        )
        executedAt = artifact.createdAt
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

    private static func reviewContent(
        for artifact: ZhuowangArtifact
    ) -> String {
        if let content = artifact.content,
           !content.isEmpty {
            return content
        }

        let location = artifact.location
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !location.isEmpty else {
            return ""
        }

        return (try? String(
            contentsOfFile: location,
            encoding: .utf8
        )) ?? ""
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
}


enum ArtifactDetailContentMode: Equatable {
    case preview
    case source

    static let initial: ArtifactDetailContentMode = .preview
}
