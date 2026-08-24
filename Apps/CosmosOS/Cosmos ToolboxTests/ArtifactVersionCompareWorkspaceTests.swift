import XCTest
import WebKit
@testable import Cosmos_Toolbox


final class ArtifactVersionCompareWorkspaceTests: XCTestCase {

    func testCompareRequiresAtLeastTwoManagedVersions() {
        let item = makeItems().first!

        XCTAssertNil(
            ArtifactVersionCompareState(
                items: [item],
                selectedArtifactID: item.artifactID
            )
        )
    }

    func testDefaultComparisonUsesCurrentAndHighestOtherVersion() throws {
        let items = makeItems()
        let current = try item(version: 3, in: items)
        let state = try XCTUnwrap(
            ArtifactVersionCompareState(
                items: items,
                selectedArtifactID: current.artifactID
            )
        )

        XCTAssertEqual(state.leftArtifactID, current.artifactID)
        XCTAssertEqual(
            state.rightArtifactID,
            try item(version: 4, in: items).artifactID
        )
    }

    func testSelectedHistoricalVersionBecomesRightComparison() throws {
        let items = makeItems()
        let selectedV1 = try item(version: 1, in: items)
        let state = try XCTUnwrap(
            ArtifactVersionCompareState(
                items: items,
                selectedArtifactID: selectedV1.artifactID
            )
        )

        XCTAssertEqual(
            state.leftArtifactID,
            try item(version: 3, in: items).artifactID
        )
        XCTAssertEqual(state.rightArtifactID, selectedV1.artifactID)
    }

    func testSelectingOppositeVersionSwapsSides() throws {
        let items = makeItems()
        let availableIDs = Set(items.map(\.artifactID))
        let v3 = try item(version: 3, in: items)
        let v4 = try item(version: 4, in: items)
        var state = try XCTUnwrap(
            ArtifactVersionCompareState(
                items: items,
                selectedArtifactID: v3.artifactID
            )
        )

        state.selectLeft(
            v4.artifactID,
            availableArtifactIDs: availableIDs
        )
        XCTAssertEqual(state.leftArtifactID, v4.artifactID)
        XCTAssertEqual(state.rightArtifactID, v3.artifactID)

        state.selectRight(
            v4.artifactID,
            availableArtifactIDs: availableIDs
        )
        XCTAssertEqual(state.leftArtifactID, v3.artifactID)
        XCTAssertEqual(state.rightArtifactID, v4.artifactID)
        XCTAssertNotEqual(state.leftArtifactID, state.rightArtifactID)
    }

    func testSwitchingOneSideKeepsOtherSideAndModesIndependent() throws {
        let items = makeItems()
        let availableIDs = Set(items.map(\.artifactID))
        let v1 = try item(version: 1, in: items)
        let v3 = try item(version: 3, in: items)
        let v4 = try item(version: 4, in: items)
        var state = try XCTUnwrap(
            ArtifactVersionCompareState(
                items: items,
                selectedArtifactID: v3.artifactID
            )
        )

        state.leftDisplayMode = .source
        state.rightDisplayMode = .preview
        state.sharedMobileViewport = .width375
        state.selectLeft(
            v1.artifactID,
            availableArtifactIDs: availableIDs
        )

        XCTAssertEqual(state.leftArtifactID, v1.artifactID)
        XCTAssertEqual(state.rightArtifactID, v4.artifactID)
        XCTAssertEqual(state.leftDisplayMode, .source)
        XCTAssertEqual(state.rightDisplayMode, .preview)
        XCTAssertEqual(state.sharedMobileViewport, .width375)
    }

    func testComparisonDocumentsUseArtifactIdentityContentAndProvenance() throws {
        let items = makeItems()

        for item in items {
            XCTAssertEqual(item.document.id, item.artifactID)
            XCTAssertEqual(item.document.versionLabel, "V\(item.version)")
            XCTAssertTrue(
                item.document.content.contains("Version \(item.version)")
            )
        }

        let legacy = try item(version: 1, in: items)
        XCTAssertEqual(legacy.document.sourceName, "未记录")
        XCTAssertEqual(legacy.document.fidelityDisplayName, "未记录")

        let current = try item(version: 3, in: items)
        XCTAssertTrue(current.isCurrent)
        XCTAssertFalse(legacy.isCurrent)
    }

    func testCompareSelectionDoesNotMutateCurrentArtifactFlags() throws {
        let items = makeItems()
        let originalItems = items
        let availableIDs = Set(items.map(\.artifactID))
        let v1 = try item(version: 1, in: items)
        var state = try XCTUnwrap(
            ArtifactVersionCompareState(
                items: items,
                selectedArtifactID: v1.artifactID
            )
        )

        state.selectRight(
            try item(version: 4, in: items).artifactID,
            availableArtifactIDs: availableIDs
        )

        XCTAssertEqual(items, originalItems)
        XCTAssertEqual(items.filter(\.isCurrent).map(\.version), [3])
    }

    func testBothHTMLPreviewsUseSecurityPolicyWhileSourceStaysOriginal() {
        let items = makeItems()
        let renderer = HTMLArtifactPreviewRenderer()

        for item in items {
            let originalSource = item.document.content
            let previewHTML = renderer.previewHTML(for: item.document)

            XCTAssertEqual(item.document.content, originalSource)
            XCTAssertNotEqual(previewHTML, originalSource)
            XCTAssertTrue(
                previewHTML.contains(
                    ArtifactHTMLPreviewSecurityPolicy.marker
                )
            )
        }
    }

    func testRendererFallbackRemainsAvailableInComparePane() {
        let artifact = ZhuowangArtifact(
            campaignID: campaignID,
            name: "未来版本",
            type: .other,
            logicalKey: logicalKey,
            content: "Unsupported",
            version: 5
        )
        let document = ArtifactReviewDocument(artifact: artifact)
        let registry = ArtifactPreviewRendererRegistry()

        XCTAssertEqual(
            registry.rendererIdentifier(for: document.type),
            .unsupported
        )
        XCTAssertEqual(document.id, artifact.id)
    }

    func testCompareWindowIdentityIgnoresSelectedPairAndOrder() {
        let first = ArtifactVersionCompareWindowIdentity(
            campaignID: campaignID,
            versionGroupKey: logicalKey
        )
        let second = ArtifactVersionCompareWindowIdentity(
            campaignID: campaignID,
            versionGroupKey: logicalKey
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.rawValue, second.rawValue)
        XCTAssertFalse(first.rawValue.contains("V1"))
        XCTAssertFalse(first.rawValue.contains("V4"))
    }

    func testCompareWorkspaceBuildsWithSharedReviewPanes() throws {
        let items = makeItems()
        let state = try XCTUnwrap(
            ArtifactVersionCompareState(
                items: items,
                selectedArtifactID: try item(
                    version: 3,
                    in: items
                ).artifactID
            )
        )
        let workspace = ArtifactVersionCompareWorkspace(
            artifactName: "产品原型设计",
            items: items,
            windowContext: ArtifactReviewWindowContext(),
            initialState: state
        )

        _ = workspace.body
    }

    func testTwoHTMLWebViewsKeepJavaScriptStateIsolated() throws {
        let loaded = expectation(description: "Both previews loaded")
        loaded.expectedFulfillmentCount = 2
        let interaction = expectation(description: "Left interaction isolated")
        let ruleCompilation = expectation(description: "Rules compile")
        let securedHTML = ArtifactHTMLPreviewSecurityPolicy.securedHTML(
            from: """
            <html><head></head><body data-clicked="no">
            <button id="probe" onclick="document.body.dataset.clicked='yes'">
            Probe
            </button>
            </body></html>
            """
        )
        var leftWebView: WKWebView?
        var rightWebView: WKWebView?
        var leftObserver: ArtifactCompareTestNavigationObserver?
        var rightObserver: ArtifactCompareTestNavigationObserver?

        ArtifactHTMLPreviewContentRules.compile { result in
            DispatchQueue.main.async {
                guard case .success(let ruleList) = result else {
                    XCTFail("Preview rules should compile")
                    ruleCompilation.fulfill()
                    loaded.fulfill()
                    loaded.fulfill()
                    interaction.fulfill()
                    return
                }

                let left = ArtifactHTMLWebViewFactory.makeWebView()
                let right = ArtifactHTMLWebViewFactory.makeWebView()
                left.configuration.userContentController.add(ruleList)
                right.configuration.userContentController.add(ruleList)

                let leftNavigationObserver =
                    ArtifactCompareTestNavigationObserver {
                        loaded.fulfill()
                    }
                let rightNavigationObserver =
                    ArtifactCompareTestNavigationObserver {
                        loaded.fulfill()
                    }

                leftWebView = left
                rightWebView = right
                leftObserver = leftNavigationObserver
                rightObserver = rightNavigationObserver
                left.navigationDelegate = leftNavigationObserver
                right.navigationDelegate = rightNavigationObserver
                left.loadHTMLString(securedHTML, baseURL: nil)
                right.loadHTMLString(securedHTML, baseURL: nil)
                ruleCompilation.fulfill()
            }
        }

        wait(for: [ruleCompilation, loaded], timeout: 8)

        leftWebView?.evaluateJavaScript(
            "document.getElementById('probe').click(); document.body.dataset.clicked"
        ) { leftValue, leftError in
            XCTAssertNil(leftError)
            XCTAssertEqual(leftValue as? String, "yes")

            rightWebView?.evaluateJavaScript(
                "document.body.dataset.clicked"
            ) { rightValue, rightError in
                XCTAssertNil(rightError)
                XCTAssertEqual(rightValue as? String, "no")
                interaction.fulfill()
            }
        }

        wait(for: [interaction], timeout: 5)
        withExtendedLifetime(leftWebView) {}
        withExtendedLifetime(rightWebView) {}
        withExtendedLifetime(leftObserver) {}
        withExtendedLifetime(rightObserver) {}
    }

    private let campaignID = UUID(
        uuidString: "10000000-0000-0000-0000-000000000001"
    )!
    private let logicalKey = "workflow.prototypeDesign.primary"

    private func makeItems() -> [ArtifactVersionComparisonItem] {
        [
            makeItem(version: 1, isCurrent: false, hasProvenance: false),
            makeItem(version: 3, isCurrent: true, hasProvenance: true),
            makeItem(version: 4, isCurrent: false, hasProvenance: true)
        ]
    }

    private func makeItem(
        version: Int,
        isCurrent: Bool,
        hasProvenance: Bool
    ) -> ArtifactVersionComparisonItem {
        let artifactID = UUID(
            uuidString: String(
                format: "20000000-0000-0000-0000-%012d",
                version
            )
        )!
        let providerID = hasProvenance
            ? UUID(uuidString: "30000000-0000-0000-0000-000000000001")
            : nil
        let artifact = ZhuowangArtifact(
            id: artifactID,
            campaignID: campaignID,
            name: "产品原型设计",
            type: .html,
            logicalKey: logicalKey,
            providerID: providerID,
            capability: hasProvenance ? .prototypeDesign : nil,
            prototypeExecutionProfile: hasProvenance ? .default : nil,
            content: "<html><head></head><body>Version \(version)</body></html>",
            version: version,
            isApprovedVersion: isCurrent,
            createdAt: Date(timeIntervalSince1970: TimeInterval(version)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(version))
        )
        let document = ArtifactReviewDocument(
            artifact: artifact,
            providerName: hasProvenance ? "DeepSeek Harness" : nil
        )

        return ArtifactVersionComparisonItem(
            artifactID: artifact.id,
            version: artifact.version,
            isCurrent: artifact.isApprovedVersion,
            document: document
        )
    }

    private func item(
        version: Int,
        in items: [ArtifactVersionComparisonItem]
    ) throws -> ArtifactVersionComparisonItem {
        try XCTUnwrap(
            items.first {
                $0.version == version
            }
        )
    }
}


private final class ArtifactCompareTestNavigationObserver:
    NSObject,
    WKNavigationDelegate {

    private let onFinish: () -> Void

    init(
        onFinish: @escaping () -> Void
    ) {
        self.onFinish = onFinish
    }

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        onFinish()
    }
}
