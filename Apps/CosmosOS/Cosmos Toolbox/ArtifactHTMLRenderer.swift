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
                securedHTML: previewHTML(for: document)
            )
        )
    }

    /// Builds an in-memory Preview copy without mutating the Review Document.
    func previewHTML(
        for document: ArtifactReviewDocument
    ) -> String {
        ArtifactHTMLPreviewSecurityPolicy.securedHTML(
            from: document.content
        )
    }
}


// MARK: - Preview Security Policy

enum ArtifactHTMLPreviewSecurityPolicy {

    static let marker =
        "data-cosmos-preview-security=\"renderer-v1\""

    static let contentSecurityPolicy = [
        "default-src 'none'",
        "connect-src 'none'",
        "form-action 'none'",
        "base-uri 'none'",
        "frame-src 'none'",
        "object-src 'none'",
        "worker-src 'none'",
        "script-src 'unsafe-inline'",
        "style-src 'unsafe-inline'",
        "img-src data: blob:",
        "font-src data:",
        "media-src data: blob:"
    ].joined(separator: "; ") + ";"

    static let contentRuleListIdentifier =
        "cosmos.artifact-html-preview.network-isolation.v1"

    /// Omitting resource-type makes each rule apply to every WebKit resource
    /// category, including documents, raw fetch/XHR, scripts and media.
    static let encodedContentRuleList = #"""
    [
      {
        "trigger": { "url-filter": "^https?://" },
        "action": { "type": "block" }
      },
      {
        "trigger": { "url-filter": "^wss?://" },
        "action": { "type": "block" }
      },
      {
        "trigger": { "url-filter": "^file://" },
        "action": { "type": "block" }
      }
    ]
    """#

    private static var cspMetaTag: String {
        "<meta \(marker) http-equiv=\"Content-Security-Policy\" content=\"\(contentSecurityPolicy)\">"
    }

    static func securedHTML(
        from originalHTML: String
    ) -> String {
        if let headRange = originalHTML.range(
            of: "<head\\b[^>]*>",
            options: [
                .regularExpression,
                .caseInsensitive
            ]
        ) {
            var securedHTML = originalHTML
            securedHTML.insert(
                contentsOf: "\n\(cspMetaTag)",
                at: headRange.upperBound
            )
            return securedHTML
        }

        if let htmlRange = originalHTML.range(
            of: "<html\\b[^>]*>",
            options: [
                .regularExpression,
                .caseInsensitive
            ]
        ) {
            var securedHTML = originalHTML
            securedHTML.insert(
                contentsOf: "\n<head>\(cspMetaTag)</head>",
                at: htmlRange.upperBound
            )
            return securedHTML
        }

        return """
        <!doctype html>
        <html>
        <head>\(cspMetaTag)</head>
        <body>
        \(originalHTML)
        </body>
        </html>
        """
    }

    static let unavailablePreviewHTML = """
    <!doctype html>
    <html>
    <head>\(cspMetaTag)</head>
    <body style="font-family: -apple-system; padding: 24px;">
    Preview security initialization failed. Artifact content was not loaded.
    </body>
    </html>
    """
}


enum ArtifactHTMLPreviewContentRules {

    static func compile(
        completion: @escaping (Result<WKContentRuleList, Error>) -> Void
    ) {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier:
                ArtifactHTMLPreviewSecurityPolicy.contentRuleListIdentifier,
            encodedContentRuleList:
                ArtifactHTMLPreviewSecurityPolicy.encodedContentRuleList
        ) { ruleList, error in
            if let ruleList {
                completion(.success(ruleList))
            } else {
                completion(
                    .failure(
                        error
                            ?? ArtifactHTMLPreviewSecurityError
                                .contentRuleUnavailable
                    )
                )
            }
        }
    }
}


enum ArtifactHTMLPreviewSecurityError: Error {
    case contentRuleUnavailable
}


enum ArtifactHTMLPreviewNavigationPolicy {

    /// `loadHTMLString` and same-document anchors use about:blank. data/blob
    /// remain available to CSP-approved subresources but are not navigation
    /// destinations.
    static let allowedNavigationSchemes: Set<String> = [
        "about"
    ]

    static func decision(
        for url: URL?
    ) -> WKNavigationActionPolicy {
        guard
            let scheme = url?.scheme?.lowercased(),
            allowedNavigationSchemes.contains(scheme)
        else {
            return .cancel
        }

        return .allow
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

    let securedHTML: String

    func makeNSView(
        context: Context
    ) -> WKWebView {
        let webView = ArtifactHTMLWebViewFactory.makeWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.prepareSecurity(
            for: webView
        )
        return webView
    }

    func updateNSView(
        _ webView: WKWebView,
        context: Context
    ) {
        context.coordinator.updatePreview(
            securedHTML,
            in: webView
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator:
        NSObject,
        WKNavigationDelegate {

        private var lastSecuredHTML: String?
        private var pendingSecuredHTML: String?
        private var areContentRulesReady = false

        func prepareSecurity(
            for webView: WKWebView
        ) {
            ArtifactHTMLPreviewContentRules.compile {
                [weak self, weak webView] result in

                DispatchQueue.main.async {
                    guard
                        let self,
                        let webView
                    else {
                        return
                    }

                    switch result {
                    case .success(let ruleList):
                        webView.configuration
                            .userContentController
                            .add(ruleList)
                        self.areContentRulesReady = true
                        self.loadPendingPreview(
                            in: webView
                        )

                    case .failure:
                        self.pendingSecuredHTML = nil
                        webView.loadHTMLString(
                            ArtifactHTMLPreviewSecurityPolicy
                                .unavailablePreviewHTML,
                            baseURL: nil
                        )
                    }
                }
            }
        }

        func updatePreview(
            _ securedHTML: String,
            in webView: WKWebView
        ) {
            guard lastSecuredHTML != securedHTML else {
                return
            }

            lastSecuredHTML = securedHTML
            pendingSecuredHTML = securedHTML
            loadPendingPreview(in: webView)
        }

        private func loadPendingPreview(
            in webView: WKWebView
        ) {
            guard
                areContentRulesReady,
                let pendingSecuredHTML
            else {
                return
            }

            self.pendingSecuredHTML = nil
            webView.loadHTMLString(
                pendingSecuredHTML,
                baseURL: nil
            )
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(
                ArtifactHTMLPreviewNavigationPolicy.decision(
                    for: navigationAction.request.url
                )
            )
        }
    }
}
