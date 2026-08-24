import SwiftUI


// MARK: - Renderer Contract

struct ArtifactPreviewRendererIdentifier:
    RawRepresentable,
    Hashable {

    let rawValue: String

    static let html =
        ArtifactPreviewRendererIdentifier(rawValue: "html")

    static let unsupported =
        ArtifactPreviewRendererIdentifier(rawValue: "unsupported")
}


enum ArtifactPreviewPresentationStyle: Equatable {
    case mobileDevice
    case adaptiveCanvas
}


struct ArtifactPreviewRendererCapabilities: Equatable {
    let supportsPreview: Bool
    let supportsSource: Bool
    let supportsFullPreview: Bool
    let supportsMobileViewport: Bool

    static let html = ArtifactPreviewRendererCapabilities(
        supportsPreview: true,
        supportsSource: true,
        supportsFullPreview: true,
        supportsMobileViewport: true
    )

    static let fallback = ArtifactPreviewRendererCapabilities(
        supportsPreview: true,
        supportsSource: false,
        supportsFullPreview: false,
        supportsMobileViewport: false
    )
}


struct ArtifactPreviewContext: Equatable {
    let mobileViewport: ArtifactReviewMobileViewport?
}


/// Type-erased rendering boundary used by ArtifactReviewWorkspace.
/// Future Figma, Pixso, Image and PDF renderers register here without
/// changing Workflow or the Workspace shell.
protocol ArtifactPreviewRenderer {

    var identifier: ArtifactPreviewRendererIdentifier { get }
    var presentationStyle: ArtifactPreviewPresentationStyle { get }
    var capabilities: ArtifactPreviewRendererCapabilities { get }

    func supports(
        input: ArtifactPreviewInput
    ) -> Bool

    func makePreview(
        document: ArtifactReviewDocument,
        input: ArtifactPreviewInput,
        context: ArtifactPreviewContext
    ) -> AnyView
}


struct ArtifactPreviewRendererRegistry {

    private let renderers: [any ArtifactPreviewRenderer]
    private let fallbackRenderer: any ArtifactPreviewRenderer

    init(
        renderers: [any ArtifactPreviewRenderer] = [
            HTMLArtifactPreviewRenderer()
        ],
        fallbackRenderer: any ArtifactPreviewRenderer =
            UnsupportedArtifactPreviewRenderer()
    ) {
        self.renderers = renderers
        self.fallbackRenderer = fallbackRenderer
    }

    func renderer(
        for input: ArtifactPreviewInput
    ) -> any ArtifactPreviewRenderer {
        renderers.first {
            $0.supports(input: input)
        } ?? fallbackRenderer
    }

    func rendererIdentifier(
        for input: ArtifactPreviewInput
    ) -> ArtifactPreviewRendererIdentifier {
        renderer(for: input).identifier
    }
}


// MARK: - Unsupported Artifact Fallback

struct UnsupportedArtifactPreviewRenderer:
    ArtifactPreviewRenderer {

    let identifier: ArtifactPreviewRendererIdentifier = .unsupported
    let presentationStyle: ArtifactPreviewPresentationStyle = .adaptiveCanvas
    let capabilities: ArtifactPreviewRendererCapabilities = .fallback

    func supports(
        input: ArtifactPreviewInput
    ) -> Bool {
        false
    }

    func makePreview(
        document: ArtifactReviewDocument,
        input: ArtifactPreviewInput,
        context: ArtifactPreviewContext
    ) -> AnyView {
        AnyView(
            VStack(spacing: CosmosDesign.spacingM) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.secondary)

                Text("暂不支持此 Artifact 的可视化预览")
                    .font(.headline)

                Text("\(document.typeDisplayName) Renderer 可在后续阶段通过 Registry 接入。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(CosmosDesign.spacingXL)
        )
    }
}
