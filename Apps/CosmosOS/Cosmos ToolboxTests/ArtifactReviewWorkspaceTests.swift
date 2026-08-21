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
        XCTAssertEqual(renderer.previewHTML(for: document), document.content)
        XCTAssertFalse(webView.configuration.websiteDataStore.isPersistent)
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
            XCTAssertEqual(renderer.previewHTML(for: document), originalHTML)
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
