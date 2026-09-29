import SwiftUI


struct ArtifactTextPreviewRenderer:
    ArtifactPreviewRenderer {

    let identifier:
        ArtifactPreviewRendererIdentifier = .text

    let presentationStyle:
        ArtifactPreviewPresentationStyle = .adaptiveCanvas

    let capabilities =
        ArtifactPreviewRendererCapabilities.text

    func supports(
        input: ArtifactPreviewInput
    ) -> Bool {
        input.mediaType.classification == .text
        && input.sourceText != nil
    }

    func makePreview(
        document: ArtifactReviewDocument,
        input: ArtifactPreviewInput,
        context: ArtifactPreviewContext
    ) -> AnyView {
        AnyView(
            ScrollView([.horizontal, .vertical]) {
                Text(previewText(for: input))
                    .font(
                        .system(
                            size: 14,
                            design: .monospaced
                        )
                    )
                    .textSelection(.enabled)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(CosmosDesign.spacingL)
            }
            .background(
                Color.primary.opacity(0.018)
            )
        )
    }

    func previewText(
        for input: ArtifactPreviewInput
    ) -> String {
        input.sourceText ?? ""
    }
}
