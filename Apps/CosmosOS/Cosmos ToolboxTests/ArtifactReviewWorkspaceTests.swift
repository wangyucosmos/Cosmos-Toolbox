import XCTest
import WebKit
@testable import Cosmos_Toolbox


final class ArtifactReviewWorkspaceTests: XCTestCase {

    func testHTMLArtifactCanEnterReviewWorkspace() {
        let document = makeDraftDocument()
        let registry = ArtifactPreviewRendererRegistry()
        let workspace = ArtifactReviewWorkspace(
            document: document,
            rendererRegistry: registry,
            windowContext: ArtifactReviewWindowContext()
        )

        XCTAssertEqual(document.type, .html)
        XCTAssertEqual(
            registry.rendererIdentifier(for: document.type),
            .html
        )
        _ = workspace.body
    }


    func testUnknownArtifactUsesSafeFallbackRenderer() {
        let document = ArtifactReviewDocument(
            artifact: ZhuowangArtifact(
                campaignID: UUID(),
                name: "未来产物",
                type: .other,
                content: "future artifact"
            )
        )
        let registry = ArtifactPreviewRendererRegistry()

        XCTAssertEqual(
            registry.rendererIdentifier(for: document.type),
            .unsupported
        )
        XCTAssertEqual(
            registry.renderer(for: document.type).presentationStyle,
            .adaptiveCanvas
        )
    }


    func testHTMLRendererCreatesRealNonPersistentWebView() {
        let document = makeDraftDocument()
        let renderer = HTMLArtifactPreviewRenderer()
        let webView = ArtifactHTMLWebViewFactory.makeWebView()

        XCTAssertTrue(renderer.supports(artifactType: .html))
        XCTAssertFalse(renderer.supports(artifactType: .figma))
        XCTAssertNotEqual(renderer.previewHTML(for: document), document.content)
        XCTAssertTrue(
            renderer.previewHTML(for: document).contains(
                ArtifactHTMLPreviewSecurityPolicy.marker
            )
        )
        XCTAssertFalse(webView.configuration.websiteDataStore.isPersistent)
    }


    func testHTMLWithoutCSPReceivesRendererSecurityPolicy() {
        let originalHTML = """
        <html><head><title>Legacy</title></head>
        <body><script>window.ready = true</script></body></html>
        """

        let securedHTML = ArtifactHTMLPreviewSecurityPolicy
            .securedHTML(from: originalHTML)

        XCTAssertEqual(
            securedHTML.components(
                separatedBy: ArtifactHTMLPreviewSecurityPolicy.marker
            ).count - 1,
            1
        )
        XCTAssertLessThan(
            securedHTML.range(
                of: ArtifactHTMLPreviewSecurityPolicy.marker
            )!.lowerBound,
            securedHTML.range(of: "<title>")!.lowerBound
        )
        XCTAssertEqual(originalHTML.contains("renderer-v1"), false)
    }


    func testHTMLWithExistingCSPStillReceivesIndependentRendererPolicy() {
        let originalHTML = """
        <html><head>
        <meta http-equiv="Content-Security-Policy" content="default-src https:">
        </head><body>Existing CSP</body></html>
        """

        let securedHTML = ArtifactHTMLPreviewSecurityPolicy
            .securedHTML(from: originalHTML)

        XCTAssertTrue(securedHTML.contains("default-src https:"))
        XCTAssertTrue(
            securedHTML.contains(
                ArtifactHTMLPreviewSecurityPolicy.marker
            )
        )
        XCTAssertTrue(
            securedHTML.contains(
                ArtifactHTMLPreviewSecurityPolicy.contentSecurityPolicy
            )
        )
        XCTAssertEqual(
            securedHTML.components(
                separatedBy: "Content-Security-Policy"
            ).count - 1,
            2
        )
    }


    func testPreviewCSPDefinesAllRequiredResourceBoundaries() {
        let csp = ArtifactHTMLPreviewSecurityPolicy
            .contentSecurityPolicy

        let requiredDirectives = [
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
        ]

        for directive in requiredDirectives {
            XCTAssertTrue(csp.contains(directive), directive)
        }

        XCTAssertFalse(csp.contains("unsafe-eval"))
        XCTAssertFalse(csp.contains("http:"))
        XCTAssertFalse(csp.contains("https:"))
        XCTAssertFalse(csp.contains("ws:"))
        XCTAssertFalse(csp.contains("wss:"))
    }


    func testWebKitContentRulesCompileAndBlockEveryExternalResourceType() {
        let encodedRules = ArtifactHTMLPreviewSecurityPolicy
            .encodedContentRuleList
        let compilation = expectation(
            description: "Preview content rules compile"
        )

        XCTAssertTrue(encodedRules.contains("^https?://"))
        XCTAssertTrue(encodedRules.contains("^wss?://"))
        XCTAssertTrue(encodedRules.contains("^file://"))
        XCTAssertFalse(encodedRules.contains("resource-type"))

        ArtifactHTMLPreviewContentRules.compile { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("Content rules should compile: \(error)")
            }
            compilation.fulfill()
        }

        wait(for: [compilation], timeout: 5)
    }


    func testNavigationPolicyOnlyAllowsLocalAboutNavigation() {
        let allowedURLs = [
            URL(string: "about:blank")!,
            URL(string: "about:blank#section")!
        ]
        let blockedURLs = [
            URL(string: "http://example.com")!,
            URL(string: "https://example.com")!,
            URL(string: "file:///tmp/example.html")!,
            URL(string: "mailto:test@example.com")!,
            URL(string: "data:text/html,Blocked")!,
            URL(string: "blob:https://example.com/id")!
        ]

        for url in allowedURLs {
            XCTAssertEqual(
                ArtifactHTMLPreviewNavigationPolicy.decision(for: url),
                .allow
            )
        }

        for url in blockedURLs {
            XCTAssertEqual(
                ArtifactHTMLPreviewNavigationPolicy.decision(for: url),
                .cancel
            )
        }

        XCTAssertEqual(
            ArtifactHTMLPreviewNavigationPolicy.decision(for: nil),
            .cancel
        )
    }


    func testSecuredPreviewKeepsInlineCSSJavaScriptAndButtonInteraction() {
        let interaction = expectation(
            description: "Inline button interaction completes"
        )
        let originalHTML = """
        <html><head><style>button { color: red; }</style></head>
        <body data-clicked="no">
        <button id="probe" onclick="document.body.dataset.clicked='yes'">
        Probe
        </button>
        </body></html>
        """
        let securedHTML = ArtifactHTMLPreviewSecurityPolicy
            .securedHTML(from: originalHTML)
        var retainedWebView: WKWebView?
        var retainedObserver: ArtifactHTMLTestNavigationObserver?

        ArtifactHTMLPreviewContentRules.compile { result in
            DispatchQueue.main.async {
                guard case .success(let ruleList) = result else {
                    XCTFail("Preview content rules should compile")
                    interaction.fulfill()
                    return
                }

                let webView = ArtifactHTMLWebViewFactory.makeWebView()
                webView.configuration.userContentController.add(ruleList)

                let observer = ArtifactHTMLTestNavigationObserver {
                    loadedWebView in
                    loadedWebView.evaluateJavaScript(
                        "document.getElementById('probe').click(); document.body.dataset.clicked"
                    ) { value, error in
                        XCTAssertNil(error)
                        XCTAssertEqual(value as? String, "yes")
                        interaction.fulfill()
                    }
                }

                retainedWebView = webView
                retainedObserver = observer
                webView.navigationDelegate = observer
                webView.loadHTMLString(securedHTML, baseURL: nil)
            }
        }

        wait(for: [interaction], timeout: 8)
        withExtendedLifetime(retainedWebView) {}
        withExtendedLifetime(retainedObserver) {}
    }


    func testPreviewSecurityDoesNotMutateDocumentOrLocalFile() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).html")
        let originalHTML =
            "<html><head></head><body>Immutable Source</body></html>"
        try originalHTML.write(
            to: fileURL,
            atomically: true,
            encoding: .utf8
        )
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        let originalData = try Data(contentsOf: fileURL)
        let artifact = ZhuowangArtifact(
            campaignID: UUID(),
            name: "Immutable Artifact",
            type: .html,
            location: fileURL.path,
            content: nil,
            version: 1
        )
        let document = ArtifactReviewDocument(artifact: artifact)
        let securedHTML = HTMLArtifactPreviewRenderer()
            .previewHTML(for: document)

        XCTAssertEqual(document.content, originalHTML)
        XCTAssertNotEqual(securedHTML, originalHTML)
        XCTAssertEqual(try Data(contentsOf: fileURL), originalData)
        XCTAssertEqual(
            try String(contentsOf: fileURL, encoding: .utf8),
            originalHTML
        )
    }


    func testHeadlessLegacyHTMLWithoutProvenanceDegradesSafely() throws {
        let originalHTML = """
        <html><body>
        <button onclick="document.body.dataset.ready='yes'">Legacy</button>
        </body></html>
        """
        let artifact = ZhuowangArtifact(
            campaignID: UUID(),
            name: "无 Head 历史原型",
            type: .html,
            content: originalHTML,
            version: 1
        )
        let document = ArtifactReviewDocument(artifact: artifact)
        let securedHTML = HTMLArtifactPreviewRenderer()
            .previewHTML(for: document)

        XCTAssertEqual(document.sourceName, "未记录")
        XCTAssertEqual(document.content, originalHTML)
        XCTAssertTrue(securedHTML.contains("<head>"))
        XCTAssertTrue(
            securedHTML.contains(
                ArtifactHTMLPreviewSecurityPolicy.marker
            )
        )
        XCTAssertLessThan(
            securedHTML.range(
                of: ArtifactHTMLPreviewSecurityPolicy.marker
            )!.lowerBound,
            securedHTML.range(of: "<body>")!.lowerBound
        )
    }


    func testReviewInformationUsesFrozenArtifactProvenance() {
        let snapshot = makeSnapshot(
            profile: ZhuowangPrototypeExecutionProfile(
                fidelity: .low,
                style: .grayscaleWireframe
            )
        )
        let document = ArtifactReviewDocument(
            draft: makeDraft(),
            snapshot: snapshot,
            providerName: "DeepSeek Harness"
        )

        XCTAssertEqual(document.versionLabel, "Draft")
        XCTAssertEqual(document.typeDisplayName, "HTML Prototype")
        XCTAssertEqual(document.fidelityDisplayName, "Low-fi")
        XCTAssertEqual(document.styleDisplayName, "黑白灰线框")
        XCTAssertEqual(document.sourceProviderID, snapshot.providerID)
        XCTAssertEqual(document.sourceName, "DeepSeek Harness")
        XCTAssertEqual(document.executedAt, snapshot.createdAt)
    }


    func testMobilePreviewNeverChangesArtifactHTML() {
        let document = makeDraftDocument()
        let renderer = HTMLArtifactPreviewRenderer()
        let originalHTML = document.content

        for viewport in ArtifactReviewMobileViewport.allCases {
            XCTAssertTrue([375, 390].contains(viewport.rawValue))
            XCTAssertEqual(document.content, originalHTML)
            XCTAssertNotEqual(renderer.previewHTML(for: document), originalHTML)
            _ = renderer.makePreview(
                document: document,
                viewport: viewport
            )
        }
    }


    func testFullPreviewStateTogglesWithoutChangingReviewContent() {
        var state = ArtifactReviewWorkspaceState()

        XCTAssertEqual(state.presentationMode, .workspace)

        state.toggleFullPreview()
        XCTAssertEqual(state.presentationMode, .fullPreview)

        state.toggleFullPreview()
        XCTAssertEqual(state.presentationMode, .workspace)
        XCTAssertEqual(state.displayMode, .preview)
        XCTAssertEqual(state.mobileViewport, .width390)
    }


    func testLegacyArtifactWithoutProvenanceStillOpensLocalContent() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).html")
        let html = "<html><head></head><body>Legacy V1</body></html>"
        try html.write(
            to: fileURL,
            atomically: true,
            encoding: .utf8
        )
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let legacyArtifact = ZhuowangArtifact(
            campaignID: UUID(),
            name: "历史产品原型",
            type: .html,
            location: fileURL.path,
            content: nil,
            version: 1,
            isApprovedVersion: true
        )
        let document = ArtifactReviewDocument(
            artifact: legacyArtifact
        )

        XCTAssertEqual(document.versionLabel, "V1")
        XCTAssertEqual(document.content, html)
        XCTAssertEqual(document.fidelityDisplayName, "未记录")
        XCTAssertEqual(document.styleDisplayName, "未记录")
        XCTAssertEqual(document.sourceName, "未记录")
        XCTAssertEqual(
            ArtifactPreviewRendererRegistry()
                .rendererIdentifier(for: document.type),
            .html
        )
    }


    func testAdoptedHTMLVersionsCanEnterReviewWorkspace() {
        let registry = ArtifactPreviewRendererRegistry()
        let html = "<html><head></head><body>Adopted</body></html>"

        for version in [1, 2, 3] {
            let artifact = ZhuowangArtifact(
                campaignID: UUID(),
                name: "产品原型设计",
                type: .html,
                content: html,
                version: version,
                isApprovedVersion: version == 3
            )
            let document = ArtifactReviewDocument(
                artifact: artifact,
                providerName: "DeepSeek Harness"
            )

            XCTAssertEqual(document.versionLabel, "V\(version)")
            XCTAssertEqual(document.content, html)
            XCTAssertEqual(
                registry.rendererIdentifier(for: document.type),
                .html
            )
        }
    }


    func testArtifactDetailDefaultsToPreviewWorkspace() {
        XCTAssertEqual(ArtifactDetailContentMode.initial, .preview)
        XCTAssertNotEqual(ArtifactDetailContentMode.initial, .source)
    }


    private func makeDraftDocument() -> ArtifactReviewDocument {
        ArtifactReviewDocument(
            draft: makeDraft(),
            snapshot: makeSnapshot(profile: .default),
            providerName: "DeepSeek Harness"
        )
    }

    private func makeDraft() -> ZhuowangArtifactDraft {
        ZhuowangArtifactDraft(
            logicalKey: "workflow.prototypeDesign.primary",
            name: "产品原型设计",
            type: .html,
            content: "<html><head></head><body>Review</body></html>",
            preferredFileExtension: "html"
        )
    }

    private func makeSnapshot(
        profile: ZhuowangPrototypeExecutionProfile
    ) -> ZhuowangWorkflowExecutionSnapshot {
        ZhuowangWorkflowExecutionSnapshot(
            workflowID: UUID(),
            workflowStepID: UUID(),
            providerID: UUID(),
            connectionID: UUID(),
            toolIntegrationID: ZhuowangBuiltInIntegrationIDs.htmlPrototypeTool,
            routeID: ZhuowangBuiltInIntegrationIDs.deepSeekHTMLRoute,
            capability: .prototypeDesign,
            adapterIdentifier: "deepseek-harness-html-prototype",
            prototypeExecutionProfile: profile,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}


private final class ArtifactHTMLTestNavigationObserver:
    NSObject,
    WKNavigationDelegate {

    private let onFinish: (WKWebView) -> Void

    init(
        onFinish: @escaping (WKWebView) -> Void
    ) {
        self.onFinish = onFinish
    }

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        onFinish(webView)
    }
}
