import SwiftUI
import WebKit


// MARK: - HTML Artifact Renderer

struct HTMLArtifactPreviewRenderer:
    ArtifactPreviewRenderer {

    let identifier: ArtifactPreviewRendererIdentifier = .html
    let presentationStyle: ArtifactPreviewPresentationStyle = .mobileDevice

    func supports(
        artifactType: ZhuowangArtifactType
    ) -> Bool {
        artifactType == .html
    }

    func makePreview(
        document: ArtifactReviewDocument,
        viewport: ArtifactReviewMobileViewport
    ) -> AnyView {
        AnyView(
            HTMLArtifactRenderedContent(
                html: previewHTML(for: document)
            )
        )
    }

    /// Renderer contract deliberately returns the Artifact content unchanged.
    /// Validation and normalization remain upstream responsibilities.
    func previewHTML(
        for document: ArtifactReviewDocument
    ) -> String {
        document.content
    }
}


enum ArtifactHTMLWebViewFactory {

    static func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        return WKWebView(
            frame: .zero,
            configuration: configuration
        )
    }
}


private struct HTMLArtifactRenderedContent:
    NSViewRepresentable {

    let html: String

    func makeNSView(
        context: Context
    ) -> WKWebView {
        let webView = ArtifactHTMLWebViewFactory.makeWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(
        _ webView: WKWebView,
        context: Context
    ) {
        guard context.coordinator.lastHTML != html else {
            return
        }

        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator:
        NSObject,
        WKNavigationDelegate {

        var lastHTML = ""

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let scheme = navigationAction.request.url?.scheme else {
                decisionHandler(.allow)
                return
            }

            decisionHandler(
                ["about", "data", "blob"].contains(scheme)
                    ? .allow
                    : .cancel
            )
        }
    }
}
