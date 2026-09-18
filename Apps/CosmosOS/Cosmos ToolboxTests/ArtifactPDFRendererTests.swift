import XCTest
import AppKit
import Combine
import SwiftUI
@preconcurrency import CoreGraphics
@preconcurrency import PDFKit
@preconcurrency @testable import Cosmos_Toolbox


@MainActor
final class ArtifactPDFRendererTests: XCTestCase {
    func testPDFProjectsToTypedRendererWithoutUTF8Decode() throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let url = try fixtures.makePDF()
        var utf8ReadCount = 0
        let resolver = ArtifactPreviewInputResolver(
            fileExists: { FileManager.default.fileExists(atPath: $0.path) },
            readUTF8Text: { _ in
                utf8ReadCount += 1
                return "unexpected"
            }
        )
        let document = makeDocument(url: url, resolver: resolver)

        XCTAssertEqual(document.previewInput.mediaType.classification, .pdf)
        XCTAssertNotNil(document.previewInput.localFileReference)
        XCTAssertNil(document.previewInput.sourceText)
        XCTAssertEqual(document.content, "")
        XCTAssertEqual(utf8ReadCount, 0)
        XCTAssertEqual(
            ArtifactPreviewRendererRegistry().rendererIdentifier(
                for: document.previewInput
            ),
            .pdf
        )
    }

    func testPDFCapabilitiesHideSourceAndMobileViewportButAllowFullPreview()
        throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let document = makeDocument(url: try fixtures.makePDF())
        let renderer = ArtifactPreviewRendererRegistry().renderer(
            for: document.previewInput
        )

        XCTAssertTrue(renderer.capabilities.supportsPreview)
        XCTAssertFalse(renderer.capabilities.supportsSource)
        XCTAssertTrue(renderer.capabilities.supportsFullPreview)
        XCTAssertFalse(renderer.capabilities.supportsMobileViewport)

        var state = ArtifactReviewWorkspaceState(
            displayMode: .source,
            presentationMode: .fullPreview,
            mobileViewport: .width375
        )
        state.normalize(for: renderer.capabilities)
        XCTAssertEqual(state.displayMode, .preview)
        XCTAssertEqual(state.presentationMode, .fullPreview)
    }

    func testRealPDFStructureParsesPageMetadata() throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let data = try Data(contentsOf: fixtures.makePDF(pageCount: 3))

        let result = try ArtifactPDFStructureInspector().inspect(
            data: data,
            fileSize: Int64(data.count)
        )

        XCTAssertEqual(result.metadata.pageCount, 3)
        XCTAssertEqual(result.metadata.pages[0].widthPoints, 612, accuracy: 0.1)
        XCTAssertEqual(result.metadata.pages[0].heightPoints, 792, accuracy: 0.1)
        XCTAssertEqual(result.metadata.blockedExternalActionCount, 0)
    }

    func testRealExternalURIIsClassifiedForBlocking() throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let annotation = "<< /Type /Annot /Subtype /Link "
            + "/Rect [20 20 180 60] "
            + "/A << /S /URI /URI (https://example.com) >> >>"
        let data = try Data(
            contentsOf: fixtures.makeRawPDF(annotation: annotation)
        )

        let result = try ArtifactPDFStructureInspector().inspect(
            data: data,
            fileSize: Int64(data.count)
        )

        XCTAssertEqual(result.metadata.blockedExternalActionCount, 1)
    }

    func testRealInternalGoToIsAllowed() throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let annotation = "<< /Type /Annot /Subtype /Link "
            + "/Rect [20 20 180 60] "
            + "/A << /S /GoTo /D [3 0 R /Fit] >> >>"
        let data = try Data(
            contentsOf: fixtures.makeRawPDF(annotation: annotation)
        )

        XCTAssertNoThrow(
            try ArtifactPDFStructureInspector().inspect(
                data: data,
                fileSize: Int64(data.count)
            )
        )
    }

    func testRealCatalogFeaturesFailClosed() throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let cases: [(String, [String], ArtifactPDFPreviewError)] = [
            (
                "/OpenAction 5 0 R",
                ["<< /S /JavaScript /JS (app.alert\\(1\\)) >>"],
                .unsafeFeature(.openAction)
            ),
            (
                "/AA << /WC << /S /JavaScript /JS (x) >> >>",
                [],
                .unsafeFeature(.additionalActions)
            ),
            (
                "/AcroForm 5 0 R",
                ["<< /Fields [] >>"],
                .unsafeFeature(.acroForm)
            ),
            (
                "/Names << /JavaScript 5 0 R >>",
                ["<< /Names [] >>"],
                .unsafeFeature(.javaScript)
            ),
            (
                "/Names << /EmbeddedFiles 5 0 R >>",
                ["<< /Names [] >>"],
                .unsafeFeature(.embeddedFiles)
            )
        ]

        for (catalogExtras, objects, expectedError) in cases {
            let data = try Data(
                contentsOf: fixtures.makeRawPDF(
                    catalogExtras: catalogExtras,
                    extraObjects: objects
                )
            )
            XCTAssertThrowsError(
                try ArtifactPDFStructureInspector().inspect(
                    data: data,
                    fileSize: Int64(data.count)
                )
            ) { error in
                XCTAssertEqual(error as? ArtifactPDFPreviewError, expectedError)
            }
        }
    }

    func testRealDangerousAnnotationFeaturesFailClosed() throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let cases: [(String, ArtifactPDFPreviewError)] = [
            ("<< /Type /Annot /Subtype /Widget /Rect [0 0 10 10] >>",
             .unsafeFeature(.widget)),
            ("<< /Type /Annot /Subtype /FileAttachment /Rect [0 0 10 10] >>",
             .unsafeFeature(.fileAttachment)),
            ("<< /Type /Annot /Subtype /Sound /Rect [0 0 10 10] >>",
             .unsafeFeature(.sound)),
            ("<< /Type /Annot /Subtype /Movie /Rect [0 0 10 10] >>",
             .unsafeFeature(.movie)),
            ("<< /Type /Annot /Subtype /RichMedia /Rect [0 0 10 10] >>",
             .unsafeFeature(.richMedia)),
            ("<< /Type /Annot /Subtype /3D /Rect [0 0 10 10] >>",
             .unsafeFeature(.threeD)),
            ("<< /Type /Annot /Subtype /Link /Rect [0 0 10 10] /A << /S /JavaScript /JS (x) >> >>",
             .unsafeFeature(.javaScript)),
            ("<< /Type /Annot /Subtype /Link /Rect [0 0 10 10] /A << /S /SubmitForm >> >>",
             .unsafeFeature(.submitForm)),
            ("<< /Type /Annot /Subtype /Link /Rect [0 0 10 10] /A << /S /ImportData >> >>",
             .unsafeFeature(.importData)),
            ("<< /Type /Annot /Subtype /Link /Rect [0 0 10 10] /A << /S /ResetForm >> >>",
             .unsafeFeature(.resetForm)),
            ("<< /Type /Annot /Subtype /Link /Rect [0 0 10 10] /A << /S /Unknown >> >>",
             .unsafeFeature(.unknownAction))
        ]

        for (annotation, expectedError) in cases {
            let data = try Data(
                contentsOf: fixtures.makeRawPDF(annotation: annotation)
            )
            XCTAssertThrowsError(
                try ArtifactPDFStructureInspector().inspect(
                    data: data,
                    fileSize: Int64(data.count)
                )
            ) { error in
                XCTAssertEqual(error as? ArtifactPDFPreviewError, expectedError)
            }
        }
    }

    func testRealPlainAnnotationIsAllowed() throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let annotation = "<< /Type /Annot /Subtype /Text "
            + "/Rect [20 20 80 80] /Contents (Review note) >>"
        let data = try Data(
            contentsOf: fixtures.makeRawPDF(annotation: annotation)
        )

        XCTAssertNoThrow(
            try ArtifactPDFStructureInspector().inspect(
                data: data,
                fileSize: Int64(data.count)
            )
        )
    }

    func testEncryptedPDFIsRejectedByProductionInspector() throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let data = try Data(contentsOf: fixtures.makeEncryptedPDF())

        XCTAssertThrowsError(
            try ArtifactPDFStructureInspector().inspect(
                data: data,
                fileSize: Int64(data.count)
            )
        ) { error in
            XCTAssertEqual(
                error as? ArtifactPDFPreviewError,
                .encryptedDocument
            )
        }
    }

    func testPolicyEnforcesFilePageAndPageBoxBudgets() {
        let policy = ArtifactPDFPreviewSecurityPolicy()

        XCTAssertNoThrow(
            try policy.validateFileSize(
                ArtifactPDFPreviewSecurityPolicy.maximumFileSize
            )
        )
        XCTAssertThrowsError(
            try policy.validateFileSize(
                ArtifactPDFPreviewSecurityPolicy.maximumFileSize + 1
            )
        )
        XCTAssertNoThrow(
            try policy.validatePageCount(
                ArtifactPDFPreviewSecurityPolicy.maximumPageCount
            )
        )
        XCTAssertThrowsError(
            try policy.validatePageCount(
                ArtifactPDFPreviewSecurityPolicy.maximumPageCount + 1
            )
        )
        XCTAssertThrowsError(
            try policy.validatePageSize(
                CGSize(
                    width:
                        ArtifactPDFPreviewSecurityPolicy
                            .maximumPageDimension + 1,
                    height: 100
                )
            )
        )
        XCTAssertThrowsError(
            try policy.validatePageSize(
                CGSize(width: 5_000, height: 5_000)
            )
        )
    }

    func testMissingCorruptAndDisguisedFilesFailClosed() async throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let missingURL = fixtures.url.appendingPathComponent("missing.pdf")
        let corruptURL = try fixtures.write(
            Data("%PDF-corrupt".utf8),
            name: "corrupt.pdf"
        )
        let fakeURL = try fixtures.write(
            Data("not a pdf".utf8),
            name: "fake.pdf"
        )
        let loader = ArtifactPDFPreviewLoader()

        await assertLoaderError(.missingFile) {
            try await loader.load(reference: reference(for: missingURL))
        }
        await assertLoaderError(.corruptFile) {
            try await loader.load(reference: reference(for: corruptURL))
        }
        await assertLoaderError(.unsupportedFormat) {
            try await loader.load(reference: reference(for: fakeURL))
        }
    }

    func testLoaderDetectsFingerprintChangeAndSerializesHeavyWork()
        async throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let url = try fixtures.makePDF()
        let data = try Data(contentsOf: url)
        let original = ArtifactPDFFileFingerprint(
            fileSize: Int64(data.count),
            modificationDate: Date(timeIntervalSince1970: 1),
            resourceIdentifier: "one"
        )
        let changed = ArtifactPDFFileFingerprint(
            fileSize: Int64(data.count),
            modificationDate: Date(timeIntervalSince1970: 2),
            resourceIdentifier: "one"
        )
        var fingerprints = [original, changed]
        let loader = ArtifactPDFPreviewLoader(
            loadGate: ArtifactPDFLoadGate(),
            fingerprintProvider: { _ in fingerprints.removeFirst() },
            dataReader: { _ in data }
        )

        await assertLoaderError(.changedFile) {
            try await loader.load(reference: reference(for: url))
        }

        let gate = ArtifactPDFLoadGate()
        let slowInspector = SlowPDFInspector(metadata: metadata())
        let first = ArtifactPDFPreviewLoader(
            inspector: slowInspector,
            loadGate: gate
        )
        let second = ArtifactPDFPreviewLoader(
            inspector: slowInspector,
            loadGate: gate
        )
        async let firstResult = first.load(reference: reference(for: url))
        async let secondResult = second.load(reference: reference(for: url))
        _ = try await (firstResult, secondResult)
        let maximumObservedOperationCount =
            await gate.maximumObservedOperationCount
        XCTAssertEqual(maximumObservedOperationCount, 1)
    }

    func testZoomStateClampsToTenAndFourHundredPercent() {
        var mode = ArtifactPDFZoomMode.fitPage
        mode.zoomOut(currentScale: 0.10)
        XCTAssertEqual(mode, .percentage(0.10))
        mode.zoomIn(currentScale: 4.00)
        XCTAssertEqual(mode, .percentage(4.00))
        mode = .fitWidth
        mode.zoomIn(currentScale: 1.0)
        XCTAssertEqual(mode, .percentage(1.25))
    }

    func testApplyZoomDefersAndPublishesOnlyFinalScale() async throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let url = try fixtures.makePDF()
        let data = try Data(contentsOf: url)
        let document = try XCTUnwrap(PDFDocument(data: data))
        let viewModel = ArtifactPDFPreviewViewModel(
            documentID: UUID(),
            reference: reference(for: url)
        )
        let view = ArtifactSecurePDFView(
            frame: NSRect(x: 0, y: 0, width: 600, height: 600)
        )
        view.secureDocument = document
        let session = viewModel.rendererBindingSession()
        session.attach(view, document: document)

        var publications: [Double] = []
        let observation = viewModel.$currentScale
            .dropFirst()
            .sink { publications.append($0) }

        session.applyZoom(
            .percentage(1.25),
            availableSize: CGSize(width: 600, height: 600)
        )
        session.applyZoom(
            .percentage(1.50),
            availableSize: CGSize(width: 600, height: 600)
        )
        session.applyZoom(
            .percentage(2.00),
            availableSize: CGSize(width: 600, height: 600)
        )

        XCTAssertEqual(viewModel.currentScale, 1.0, accuracy: 0.000_01)
        await drainDeferredPublications()
        XCTAssertEqual(viewModel.currentScale, 2.0, accuracy: 0.000_01)
        XCTAssertEqual(publications, [2.0])

        session.scheduleScaleSynchronization(2.000_05)
        await drainDeferredPublications()
        XCTAssertEqual(publications, [2.0])

        session.tearDown()
        withExtendedLifetime(observation) {}
    }

    func testScaleSynchronizationRejectsOldGenerationAndClosedRenderer()
        async throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let url = try fixtures.makePDF()
        let data = try Data(contentsOf: url)
        let inspection = try ArtifactPDFStructureInspector().inspect(
            data: data,
            fileSize: Int64(data.count)
        )
        let document = try XCTUnwrap(PDFDocument(data: data))
        let viewModel = ArtifactPDFPreviewViewModel(
            documentID: UUID(),
            reference: reference(for: url),
            loader: LatePDFLoader(
                result: ArtifactPDFPreviewLoadResult(
                    data: data,
                    metadata: inspection.metadata
                ),
                delayNanoseconds: 100_000_000
            )
        )

        let oldSession = viewModel.rendererBindingSession()
        let oldView = ArtifactSecurePDFView(frame: .zero)
        oldSession.attach(oldView, document: document)
        oldSession.scheduleScaleSynchronization(3.0)
        viewModel.load()
        let currentSession = viewModel.rendererBindingSession()
        let currentView = ArtifactSecurePDFView(frame: .zero)
        currentSession.attach(currentView, document: document)
        currentSession.scheduleScaleSynchronization(1.5)
        await drainDeferredPublications()
        XCTAssertEqual(viewModel.currentScale, 1.5, accuracy: 0.000_01)
        XCTAssertTrue(oldSession.didTearDownRendererBindings)
        XCTAssertEqual(oldSession.observerTokenCount, 0)
        XCTAssertNil(oldView.document)
        XCTAssertNil(oldView.delegate)

        NotificationCenter.default.post(
            name: .PDFViewScaleChanged,
            object: oldView
        )
        NotificationCenter.default.post(
            name: .PDFViewPageChanged,
            object: oldView
        )
        await drainDeferredPublications()
        XCTAssertEqual(viewModel.currentScale, 1.5, accuracy: 0.000_01)

        oldSession.scheduleScaleSynchronization(4.0)
        currentSession.scheduleScaleSynchronization(4.0)
        viewModel.cancel()
        await drainDeferredPublications()
        XCTAssertEqual(viewModel.currentScale, 1.5, accuracy: 0.000_01)
        XCTAssertNil(viewModel.pdfDocument)
    }

    func testBindingSessionCancelRemovesAllRendererBindings()
        async throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let data = try Data(contentsOf: fixtures.makePDF(pageCount: 2))
        let document = try XCTUnwrap(PDFDocument(data: data))
        let viewModel = ArtifactPDFPreviewViewModel(
            documentID: UUID(),
            reference: reference(
                for: fixtures.url.appendingPathComponent("fixture.pdf")
            )
        )
        let view = ArtifactSecurePDFView(frame: .zero)
        let session = viewModel.rendererBindingSession()
        session.attach(view, document: document)
        weak var delegate = session.securityDelegate

        XCTAssertNotNil(view.document)
        XCTAssertNotNil(view.delegate)
        XCTAssertTrue(view.hasActiveSecurityDelegate)
        XCTAssertTrue(view.hasRetainedSecurityDelegate)
        XCTAssertEqual(session.observerTokenCount, 2)
        XCTAssertFalse(session.didTearDownRendererBindings)
        XCTAssertFalse(view.didTearDownRendererBindings)

        session.scheduleScaleSynchronization(2.0)
        XCTAssertTrue(session.hasPendingStatePublication)
        viewModel.cancel()

        XCTAssertNil(view.document)
        XCTAssertNil(view.delegate)
        XCTAssertFalse(view.hasRetainedSecurityDelegate)
        XCTAssertNil(session.securityDelegate)
        XCTAssertNil(delegate)
        XCTAssertEqual(session.observerTokenCount, 0)
        XCTAssertFalse(session.hasPendingStatePublication)
        XCTAssertTrue(session.didTearDownRendererBindings)
        XCTAssertTrue(view.didTearDownRendererBindings)

        let scaleAfterCancel = viewModel.currentScale
        let pageAfterCancel = viewModel.currentPage
        let pageEntryAfterCancel = viewModel.pageEntry
        NotificationCenter.default.post(
            name: .PDFViewScaleChanged,
            object: view
        )
        NotificationCenter.default.post(
            name: .PDFViewPageChanged,
            object: view
        )
        await drainDeferredPublications()
        XCTAssertEqual(viewModel.currentScale, scaleAfterCancel)
        XCTAssertEqual(viewModel.currentPage, pageAfterCancel)
        XCTAssertEqual(viewModel.pageEntry, pageEntryAfterCancel)
    }

    func testBindingSessionTeardownIsIdempotentInBothCallOrders()
        throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let data = try Data(contentsOf: fixtures.makePDF())
        let document = try XCTUnwrap(PDFDocument(data: data))

        var firstViewModel: ArtifactPDFPreviewViewModel? =
            ArtifactPDFPreviewViewModel(
                documentID: UUID(),
                reference: reference(
                    for: fixtures.url.appendingPathComponent("fixture.pdf")
                )
            )
        var firstCoordinator: ArtifactPDFViewBridge.Coordinator? =
            ArtifactPDFViewBridge.Coordinator(
                viewModel: try XCTUnwrap(firstViewModel)
            )
        let firstView = ArtifactSecurePDFView(frame: .zero)
        firstCoordinator?.bindingSession.attach(
            firstView,
            document: document
        )
        weak var firstSession = firstCoordinator?.bindingSession

        firstViewModel?.cancel()
        firstViewModel?.cancel()
        if let firstCoordinator {
            ArtifactPDFViewBridge.dismantleNSView(
                firstView,
                coordinator: firstCoordinator
            )
        }
        XCTAssertTrue(firstView.didTearDownRendererBindings)
        XCTAssertNil(firstView.document)
        XCTAssertNil(firstView.delegate)
        XCTAssertEqual(firstSession?.observerTokenCount, 0)
        firstCoordinator = nil
        firstViewModel = nil
        XCTAssertNil(firstSession)

        var secondViewModel: ArtifactPDFPreviewViewModel? =
            ArtifactPDFPreviewViewModel(
                documentID: UUID(),
                reference: reference(
                    for: fixtures.url.appendingPathComponent("fixture.pdf")
                )
            )
        var secondCoordinator: ArtifactPDFViewBridge.Coordinator? =
            ArtifactPDFViewBridge.Coordinator(
                viewModel: try XCTUnwrap(secondViewModel)
            )
        let secondView = ArtifactSecurePDFView(frame: .zero)
        secondCoordinator?.bindingSession.attach(
            secondView,
            document: document
        )
        weak var secondSession = secondCoordinator?.bindingSession

        if let secondCoordinator {
            ArtifactPDFViewBridge.dismantleNSView(
                secondView,
                coordinator: secondCoordinator
            )
        }
        secondViewModel?.cancel()
        secondViewModel?.cancel()
        XCTAssertTrue(secondView.didTearDownRendererBindings)
        XCTAssertNil(secondView.document)
        XCTAssertNil(secondView.delegate)
        XCTAssertEqual(secondSession?.observerTokenCount, 0)
        secondCoordinator = nil
        secondViewModel = nil
        XCTAssertNil(secondSession)
    }

    func testPDFKitInspectorMakesAnnotationsReadOnlyAndStripsURLActions()
        throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let annotation = "<< /Type /Annot /Subtype /Link "
            + "/Rect [20 20 180 60] "
            + "/A << /S /URI /URI (https://example.com) >> >>"
        let data = try Data(
            contentsOf: fixtures.makeRawPDF(annotation: annotation)
        )
        let structured = try ArtifactPDFStructureInspector().inspect(
            data: data,
            fileSize: Int64(data.count)
        )
        let document = try XCTUnwrap(PDFDocument(data: data))

        try ArtifactPDFKitDocumentInspector().prepare(
            document,
            expectedMetadata: structured.metadata
        )

        let pdfAnnotation = try XCTUnwrap(
            document.page(at: 0)?.annotations.first
        )
        XCTAssertTrue(pdfAnnotation.isReadOnly)
        XCTAssertNil(pdfAnnotation.url)
        if let remainingAction = pdfAnnotation.action {
            let urlAction = try XCTUnwrap(remainingAction as? PDFActionURL)
            XCTAssertNil(urlAction.url)
        }
    }

    func testSecurePDFViewAllowsOnlyInternalGoToAndBlocksCommandCopy()
        throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let data = try Data(contentsOf: fixtures.makePDF(pageCount: 2))
        let document = try XCTUnwrap(PDFDocument(data: data))
        let view = ArtifactSecurePDFView(
            frame: NSRect(x: 0, y: 0, width: 600, height: 600)
        )
        view.secureDocument = document
        let secondPage = try XCTUnwrap(document.page(at: 1))
        view.perform(
            PDFActionGoTo(
                destination: PDFDestination(
                    page: secondPage,
                    at: CGPoint(x: 0, y: secondPage.bounds(for: .cropBox).maxY)
                )
            )
        )
        XCTAssertTrue(view.currentPage === secondPage)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("sentinel", forType: .string)
        view.allowsSecureCopy = false
        let commandC = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "c",
                charactersIgnoringModifiers: "c",
                isARepeat: false,
                keyCode: 8
            )
        )
        XCTAssertTrue(view.performKeyEquivalent(with: commandC))
        XCTAssertEqual(pasteboard.string(forType: .string), "sentinel")

        let copyItem = NSMenuItem(
            title: "Copy",
            action: #selector(ArtifactSecurePDFView.copy(_:)),
            keyEquivalent: "c"
        )
        XCTAssertFalse(view.validateUserInterfaceItem(copyItem))
        view.allowsSecureCopy = document.allowsCopying
        view.currentSelection = secondPage.selection(
            for: secondPage.bounds(for: .cropBox)
        )
        XCTAssertEqual(
            view.validateUserInterfaceItem(copyItem),
            document.allowsCopying && view.currentSelection != nil
        )
        XCTAssertTrue(
            view.tryToPerform(
                NSSelectorFromString("saveDocument:"),
                with: nil
            )
        )

        view.perform(PDFActionURL(url: URL(string: "https://example.com")!))
        XCTAssertTrue(view.currentPage === secondPage)
        view.secureDocument = nil
    }

    func testIndependentPDFViewModelsKeepZoomStateSeparate() throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let url = try fixtures.makePDF()
        let left = ArtifactPDFPreviewViewModel(
            documentID: UUID(),
            reference: reference(for: url)
        )
        let right = ArtifactPDFPreviewViewModel(
            documentID: UUID(),
            reference: reference(for: url)
        )

        left.zoomIn()

        XCTAssertEqual(left.zoomMode, .percentage(1.25))
        XCTAssertEqual(right.zoomMode, .fitPage)
        XCTAssertNotEqual(left.documentID, right.documentID)
    }

    func testLoadTimeoutInvalidatesLatePDFKitResult() async throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let url = try fixtures.makePDF()
        let data = try Data(contentsOf: url)
        let inspection = try ArtifactPDFStructureInspector().inspect(
            data: data,
            fileSize: Int64(data.count)
        )
        let loader = LatePDFLoader(
            result: ArtifactPDFPreviewLoadResult(
                data: data,
                metadata: inspection.metadata
            ),
            delayNanoseconds: 60_000_000
        )
        let viewModel = ArtifactPDFPreviewViewModel(
            documentID: UUID(),
            reference: reference(for: url),
            loader: loader,
            loadTimeoutNanoseconds: 5_000_000
        )

        viewModel.load()
        try await Task.sleep(nanoseconds: 20_000_000)
        guard case .failed(let error) = viewModel.loadState else {
            return XCTFail("Expected timeout failure")
        }
        XCTAssertEqual(error, .timedOut)

        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertNil(viewModel.pdfDocument)
        guard case .failed(let finalError) = viewModel.loadState else {
            return XCTFail("Late result replaced timeout state")
        }
        XCTAssertEqual(finalError, .timedOut)
    }

    func testCancellationAndPageNavigationKeepDocumentLifecycleBounded()
        async throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let url = try fixtures.makePDF(pageCount: 2)
        let data = try Data(contentsOf: url)
        let inspection = try ArtifactPDFStructureInspector().inspect(
            data: data,
            fileSize: Int64(data.count)
        )
        let result = ArtifactPDFPreviewLoadResult(
            data: data,
            metadata: inspection.metadata
        )
        let cancelled = ArtifactPDFPreviewViewModel(
            documentID: UUID(),
            reference: reference(for: url),
            loader: LatePDFLoader(
                result: result,
                delayNanoseconds: 40_000_000
            )
        )
        cancelled.load()
        cancelled.cancel()
        try await Task.sleep(nanoseconds: 70_000_000)
        XCTAssertNil(cancelled.pdfDocument)

        let ready = ArtifactPDFPreviewViewModel(
            documentID: UUID(),
            reference: reference(for: url),
            loader: LatePDFLoader(result: result, delayNanoseconds: 0)
        )
        ready.load()
        try await Task.sleep(nanoseconds: 30_000_000)
        guard case .ready = ready.loadState else {
            return XCTFail("Expected ready PDF")
        }
        let view = ArtifactSecurePDFView(
            frame: NSRect(x: 0, y: 0, width: 600, height: 600)
        )
        let session = ready.rendererBindingSession()
        session.attach(view, document: ready.pdfDocument)
        ready.goToPage(2)
        await drainDeferredPublications()
        XCTAssertEqual(ready.currentPage, 2)
        XCTAssertEqual(ready.pageEntry, "2")
        ready.cancel()
        XCTAssertNil(ready.pdfDocument)
        XCTAssertNil(view.document)
    }

    func testMixedRegistrySelectionRemainsTypeSpecific() throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        defer { XCTAssertTrue(fixtures.remove()) }
        let pdf = makeDocument(url: try fixtures.makePDF())
        let html = ArtifactReviewDocument(
            projection: ArtifactReviewDocumentProjection(
                id: UUID(),
                name: "HTML",
                versionLabel: "V1",
                type: .html,
                payload: .inlineText(
                    ArtifactReviewInlineText(
                        text: "<html></html>",
                        mediaType: .inlineText(artifactType: .html)
                    )
                ),
                prototypeExecutionProfile: nil,
                sourceProviderID: nil,
                sourceName: "Fixture",
                executedAt: Date()
            )
        )
        let unsupported = ArtifactPreviewInput(
            payload: .unavailable(
                ArtifactReviewUnavailablePayload(
                    reason: .unsupportedMediaType,
                    mediaType: ArtifactReviewMediaType(
                        legacyArtifactType: .word
                    )
                )
            ),
            resolvedContent: .unavailable(.unsupportedMediaType)
        )
        let registry = ArtifactPreviewRendererRegistry()

        XCTAssertEqual(registry.rendererIdentifier(for: pdf.previewInput), .pdf)
        XCTAssertEqual(registry.rendererIdentifier(for: html.previewInput), .html)
        XCTAssertEqual(registry.rendererIdentifier(for: unsupported), .unsupported)
    }

    func testFixtureWindowSmokeBuildsReviewFullPreviewAndCompareShapes()
        async throws {
        let fixtures = try ArtifactPDFFixtureFactory()
        let pdfURL = try fixtures.makePDF(pageCount: 3)
        let pdfDocument = makeDocument(url: pdfURL)
        let secondPDF = makeDocument(
            id: UUID(),
            url: try fixtures.makePDF(pageCount: 2, name: "second.pdf")
        )
        let htmlDocument = ArtifactReviewDocument(
            artifact: ZhuowangArtifact(
                campaignID: UUID(),
                name: "Fixture HTML",
                type: .html,
                content: "<html><body><button>Fixture</button></body></html>"
            )
        )
        let imageDocument = makeImageDocument(
            url: try fixtures.makePNG(name: "fixture.png")
        )
        let unsupportedDocument = ArtifactReviewDocument(
            artifact: ZhuowangArtifact(
                campaignID: UUID(),
                name: "Fixture Unsupported",
                type: .other,
                content: "unsupported"
            )
        )

        let reviewWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        reviewWindow.animationBehavior = .none
        reviewWindow.isReleasedWhenClosed = false
        reviewWindow.appearance = NSAppearance(named: .darkAqua)
        reviewWindow.title = "Single Review / Full Preview"
        reviewWindow.contentViewController = NSHostingController(
            rootView: ArtifactReviewWorkspace(
                document: pdfDocument,
                windowContext: ArtifactReviewWindowContext(),
                initialState: ArtifactReviewWorkspaceState(
                    displayMode: .preview,
                    presentationMode: .fullPreview,
                    mobileViewport: .width390
                )
            )
        )

        func compareWindow(
            name: String,
            left: ArtifactReviewDocument,
            right: ArtifactReviewDocument,
            appearance: NSAppearance.Name
        ) throws -> NSWindow {
            let items = [
                ArtifactVersionComparisonItem(
                    artifactID: left.id,
                    version: 1,
                    isCurrent: true,
                    document: left
                ),
                ArtifactVersionComparisonItem(
                    artifactID: right.id,
                    version: 2,
                    isCurrent: false,
                    document: right
                )
            ]
            let state = try XCTUnwrap(
                ArtifactVersionCompareState(
                    items: items,
                    selectedArtifactID: right.id
                )
            )
            let window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: 1_240,
                    height: 760
                ),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.animationBehavior = .none
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: appearance)
            window.title = name
            window.contentViewController = NSHostingController(
                rootView: ArtifactVersionCompareWorkspace(
                    artifactName: name,
                    items: items,
                    windowContext: ArtifactReviewWindowContext(),
                    initialState: state
                )
            )
            return window
        }

        let compareWindows = try [
            compareWindow(
                name: "PDF | PDF",
                left: pdfDocument,
                right: secondPDF,
                appearance: .aqua
            ),
            compareWindow(
                name: "HTML | PDF",
                left: htmlDocument,
                right: pdfDocument,
                appearance: .darkAqua
            ),
            compareWindow(
                name: "Image | PDF",
                left: imageDocument,
                right: pdfDocument,
                appearance: .aqua
            ),
            compareWindow(
                name: "PDF | Unsupported",
                left: pdfDocument,
                right: unsupportedDocument,
                appearance: .darkAqua
            )
        ]
        let allWindows = [reviewWindow] + compareWindows
        defer {
            allWindows.forEach {
                $0.orderOut(nil)
                $0.contentViewController = nil
                $0.close()
            }
            XCTAssertTrue(fixtures.remove())
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: fixtures.url.path)
            )
        }

        reviewWindow.orderFront(nil)
        compareWindows.forEach { $0.orderFront(nil) }
        reviewWindow.setContentSize(NSSize(width: 1_080, height: 780))
        compareWindows.forEach {
            $0.setContentSize(NSSize(width: 1_320, height: 800))
        }

        let expectedWindows: [(NSWindow, Int)] = [
            (reviewWindow, 1),
            (compareWindows[0], 2),
            (compareWindows[1], 1),
            (compareWindows[2], 1),
            (compareWindows[3], 1)
        ]
        var retainedPDFViews: [ArtifactSecurePDFView] = []
        var retainedSessions: [ArtifactPDFRendererBindingSession] = []
        for (window, expectedCount) in expectedWindows {
            guard let views = try await waitForPDFViews(
                in: window,
                expectedCount: expectedCount
            ) else {
                return
            }
            XCTAssertEqual(views.count, expectedCount)
            XCTAssertTrue(views.allSatisfy { $0.document != nil })
            XCTAssertTrue(views.allSatisfy(\.hasActiveSecurityDelegate))
            XCTAssertTrue(views.allSatisfy(\.hasRetainedSecurityDelegate))
            let sessions = views.compactMap(\.rendererBindingSession)
            XCTAssertEqual(sessions.count, expectedCount)
            XCTAssertTrue(sessions.allSatisfy { $0.observerTokenCount == 2 })
            XCTAssertTrue(
                sessions.allSatisfy {
                    !$0.didTearDownRendererBindings
                }
            )
            retainedPDFViews.append(contentsOf: views)
            retainedSessions.append(contentsOf: sessions)
        }
        XCTAssertEqual(retainedPDFViews.count, 6)
        XCTAssertEqual(retainedSessions.count, 6)
        XCTAssertTrue(retainedPDFViews.allSatisfy { $0.document != nil })
        let maximumObservedLoadCount =
            await ArtifactPDFLoadGate.shared.maximumObservedOperationCount
        let activeLoadCount =
            await ArtifactPDFLoadGate.shared.activeOperationCount
        XCTAssertEqual(maximumObservedLoadCount, 1)
        XCTAssertEqual(activeLoadCount, 0)
        let retainedViewModels = retainedSessions.compactMap(\.viewModel)
        XCTAssertEqual(retainedViewModels.count, 6)

        reviewWindow.orderOut(nil)
        compareWindows.forEach { $0.orderOut(nil) }
        reviewWindow.close()
        compareWindows.forEach { $0.close() }
        allWindows.forEach { $0.contentViewController = nil }

        let didRelease = try await waitUntil(timeout: .seconds(3)) {
            retainedPDFViews.allSatisfy {
                $0.document == nil
                    && $0.delegate == nil
                    && !$0.hasActiveSecurityDelegate
                    && !$0.hasRetainedSecurityDelegate
                    && $0.rendererBindingSession == nil
                    && $0.didTearDownRendererBindings
                }
                && retainedSessions.allSatisfy {
                    $0.securityDelegate == nil
                        && $0.observerTokenCount == 0
                        && !$0.hasPendingStatePublication
                        && $0.didTearDownRendererBindings
                }
                && allWindows.allSatisfy {
                    !$0.isVisible && $0.contentViewController == nil
                }
        }
        XCTAssertTrue(
            didRelease,
            "PDF Renderer teardown timed out: "
                + retainedPDFViews.map {
                    "document=\($0.document != nil), "
                        + "delegate=\($0.hasActiveSecurityDelegate), "
                        + "retainedDelegate="
                        + "\($0.hasRetainedSecurityDelegate), "
                        + "tornDown=\($0.didTearDownRendererBindings)"
                }.joined(separator: " | ")
                + "; sessions="
                + retainedSessions.map {
                    "observers=\($0.observerTokenCount), "
                        + "pending=\($0.hasPendingStatePublication), "
                        + "tornDown=\($0.didTearDownRendererBindings)"
                }.joined(separator: " | ")
        )
        XCTAssertTrue(retainedPDFViews.allSatisfy { $0.document == nil })
        XCTAssertTrue(
            retainedPDFViews.allSatisfy { !$0.hasActiveSecurityDelegate }
        )
        XCTAssertTrue(
            retainedPDFViews.allSatisfy { !$0.hasRetainedSecurityDelegate }
        )
        XCTAssertTrue(
            retainedPDFViews.allSatisfy(\.didTearDownRendererBindings)
        )
        XCTAssertTrue(
            retainedSessions.allSatisfy { $0.observerTokenCount == 0 }
        )
        XCTAssertTrue(
            retainedSessions.allSatisfy { !$0.hasPendingStatePublication }
        )

        let stateAfterClose = retainedViewModels.map {
            ($0.currentScale, $0.currentPage, $0.pageEntry)
        }
        retainedPDFViews.forEach {
            NotificationCenter.default.post(
                name: .PDFViewScaleChanged,
                object: $0
            )
            NotificationCenter.default.post(
                name: .PDFViewPageChanged,
                object: $0
            )
        }
        await drainDeferredPublications()
        for (index, viewModel) in retainedViewModels.enumerated() {
            XCTAssertEqual(
                viewModel.currentScale,
                stateAfterClose[index].0
            )
            XCTAssertEqual(
                viewModel.currentPage,
                stateAfterClose[index].1
            )
            XCTAssertEqual(
                viewModel.pageEntry,
                stateAfterClose[index].2
            )
        }
    }

    private func waitForPDFViews(
        in window: NSWindow,
        expectedCount: Int,
        timeout: Duration = .seconds(8)
    ) async throws -> [ArtifactSecurePDFView]? {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        guard try await waitUntil(clock: clock, deadline: deadline, condition: {
            window.isVisible
                && window.contentViewController?.view.window === window
        }) else {
            XCTFail(
                "Fixture window did not appear: "
                    + rendererDiagnostics(in: window)
            )
            return nil
        }

        guard try await waitUntil(clock: clock, deadline: deadline, condition: {
            securePDFViews(in: window).count == expectedCount
        }) else {
            XCTFail(
                "PDF Renderer view count did not become ready: expected="
                    + "\(expectedCount), "
                    + rendererDiagnostics(in: window)
            )
            return nil
        }

        guard try await waitUntil(clock: clock, deadline: deadline, condition: {
            let views = securePDFViews(in: window)
            return views.count == expectedCount
                && views.allSatisfy { $0.document != nil }
        }) else {
            XCTFail(
                "PDF Renderer document did not become ready: expected="
                    + "\(expectedCount), "
                    + rendererDiagnostics(in: window)
            )
            return nil
        }

        guard try await waitUntil(clock: clock, deadline: deadline, condition: {
            let views = securePDFViews(in: window)
            return views.count == expectedCount
                && views.allSatisfy { view in
                    guard let session = view.rendererBindingSession else {
                        return false
                    }
                    return view.hasActiveSecurityDelegate
                        && view.hasRetainedSecurityDelegate
                        && session.securityDelegate != nil
                        && session.observerTokenCount == 2
                        && !session.didTearDownRendererBindings
                }
        }) else {
            XCTFail(
                "PDF Renderer bindings did not become ready: expected="
                    + "\(expectedCount), "
                    + rendererDiagnostics(in: window)
            )
            return nil
        }

        let views = securePDFViews(in: window)
        guard views.count == expectedCount else {
            XCTFail(
                "PDFView count changed after readiness: expected="
                    + "\(expectedCount), actual=\(views.count), "
                    + rendererDiagnostics(in: window)
            )
            return nil
        }
        return views
    }

    @MainActor
    private func waitUntil(
        timeout: Duration,
        pollingInterval: Duration = .milliseconds(20),
        condition: @MainActor () -> Bool
    ) async throws -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        return try await waitUntil(
            clock: clock,
            deadline: deadline,
            pollingInterval: pollingInterval,
            condition: condition
        )
    }

    @MainActor
    private func waitUntil(
        clock: ContinuousClock,
        deadline: ContinuousClock.Instant,
        pollingInterval: Duration = .milliseconds(20),
        condition: @MainActor () -> Bool
    ) async throws -> Bool {

        while !condition() {
            try Task.checkCancellation()
            let now = clock.now
            guard now < deadline else {
                return condition()
            }
            try await clock.sleep(
                until: min(
                    deadline,
                    now.advanced(by: pollingInterval)
                ),
                tolerance: .milliseconds(2)
            )
        }
        return true
    }

    private func rendererDiagnostics(in window: NSWindow) -> String {
        let root = window.contentViewController?.view
        let views = root.map(descendants) ?? []
        let pdfViews = views.compactMap { $0 as? ArtifactSecurePDFView }
        let visiblePDFText = views.compactMap { view -> String? in
            guard let field = view as? NSTextField,
                  field.stringValue.localizedCaseInsensitiveContains("PDF")
            else {
                return nil
            }
            return field.stringValue.replacingOccurrences(
                of: NSHomeDirectory(),
                with: "<home>"
            )
        }
        let state: String
        if !pdfViews.isEmpty {
            state = pdfViews.allSatisfy { $0.document != nil }
                ? "ready"
                : "ready-without-document"
        } else if views.contains(where: { $0 is NSProgressIndicator }) {
            state = "loading"
        } else if !visiblePDFText.isEmpty {
            state = "failed-or-fallback"
        } else {
            state = "unknown"
        }
        let rendererTypes = Array(
            Set(
                views.map { String(describing: type(of: $0)) }
                    .filter {
                        $0.localizedCaseInsensitiveContains("PDF")
                            || $0.localizedCaseInsensitiveContains("Progress")
                    }
            )
        ).sorted().joined(separator: ",")
        let pdfViewStates = pdfViews.map { view in
            let session = view.rendererBindingSession
            let loadState: String
            switch session?.viewModel?.loadState {
            case .idle:
                loadState = "idle"
            case .loading:
                loadState = "loading"
            case .ready:
                loadState = "ready"
            case .failed(let error):
                loadState = "failed(\(error.title))"
            case nil:
                loadState = "unavailable"
            }
            return "document=\(view.document != nil), "
                + "delegate=\(view.delegate != nil), "
                + "retainedDelegate=\(view.hasRetainedSecurityDelegate), "
                + "session=\(session != nil), "
                + "observers=\(session?.observerTokenCount ?? 0), "
                + "tornDown="
                + "\(session?.didTearDownRendererBindings ?? false), "
                + "loadState=\(loadState)"
        }
        return "title=\(window.title), "
            + "identifier=\(window.identifier?.rawValue ?? "none"), "
            + "visible=\(window.isVisible), state=\(state), "
            + "pdfViews=\(pdfViews.count), "
            + "pdfText=\(visiblePDFText), "
            + "rendererTypes=[\(rendererTypes)], "
            + "pdfViewStates=[\(pdfViewStates.joined(separator: " | "))]"
    }

    private func securePDFViews(
        in window: NSWindow
    ) -> [ArtifactSecurePDFView] {
        guard let root = window.contentViewController?.view else {
            return []
        }
        return descendants(of: root).compactMap {
            $0 as? ArtifactSecurePDFView
        }
    }

    private func descendants(of view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }

    private func drainDeferredPublications() async {
        for _ in 0..<4 {
            await Task.yield()
        }
    }

    private func makeImageDocument(url: URL) -> ArtifactReviewDocument {
        ArtifactReviewDocument(
            projection: ArtifactReviewDocumentProjection(
                id: UUID(),
                name: url.lastPathComponent,
                versionLabel: "V1",
                type: .image,
                payload: .localFile(
                    ArtifactReviewLocalFileReference(
                        url: url,
                        mediaType: .localFile(
                            url: url,
                            artifactType: .image
                        )
                    )
                ),
                prototypeExecutionProfile: nil,
                sourceProviderID: nil,
                sourceName: "Image Fixture",
                executedAt: Date()
            )
        )
    }

    private func makeDocument(
        id: UUID = UUID(),
        url: URL,
        resolver: ArtifactPreviewInputResolver? = nil
    ) -> ArtifactReviewDocument {
        ArtifactReviewDocument(
            projection: ArtifactReviewDocumentProjection(
                id: id,
                name: url.deletingPathExtension().lastPathComponent,
                versionLabel: "V1",
                type: .pdf,
                payload: .localFile(reference(for: url)),
                prototypeExecutionProfile: nil,
                sourceProviderID: nil,
                sourceName: "PDF Fixture",
                executedAt: Date()
            ),
            resolver: resolver ?? .init()
        )
    }

    private func reference(
        for url: URL
    ) -> ArtifactReviewLocalFileReference {
        ArtifactReviewLocalFileReference(
            url: url,
            mediaType: .localFile(url: url, artifactType: .pdf)
        )
    }

    private func metadata(pageCount: Int = 1) -> ArtifactPDFPreviewMetadata {
        ArtifactPDFPreviewMetadata(
            fileSize: 128,
            pages: Array(
                repeating: ArtifactPDFPageMetadata(
                    widthPoints: 612,
                    heightPoints: 792
                ),
                count: pageCount
            ),
            blockedExternalActionCount: 0
        )
    }

    private func assertLoaderError(
        _ expected: ArtifactPDFPreviewError,
        operation: () async throws -> ArtifactPDFPreviewLoadResult
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected \(expected)")
        } catch let error as ArtifactPDFPreviewError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}


private nonisolated struct SlowPDFInspector: ArtifactPDFStructureInspecting {
    let metadata: ArtifactPDFPreviewMetadata

    func inspect(
        data: Data,
        fileSize: Int64
    ) throws -> ArtifactPDFStructuredInspection {
        Thread.sleep(forTimeInterval: 0.05)
        return ArtifactPDFStructuredInspection(metadata: metadata)
    }
}


private nonisolated struct LatePDFLoader: ArtifactPDFPreviewLoading {
    let result: ArtifactPDFPreviewLoadResult
    let delayNanoseconds: UInt64

    func load(
        reference: ArtifactReviewLocalFileReference
    ) async throws -> ArtifactPDFPreviewLoadResult {
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return result
    }
}


private final class ArtifactPDFFixtureFactory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "Cosmos-PDF-Fixtures-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    @discardableResult
    func remove() -> Bool {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            return !FileManager.default.fileExists(atPath: url.path)
        } catch {
            return false
        }
    }

    func makePDF(
        pageCount: Int = 1,
        name: String = "fixture.pdf"
    ) throws -> URL {
        let destination = url.appendingPathComponent(name)
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(url: destination as CFURL),
              let context = CGContext(
                consumer: consumer,
                mediaBox: &mediaBox,
                nil
              ) else {
            throw FixtureError.creationFailed
        }

        for index in 0..<pageCount {
            context.beginPDFPage(nil)
            let text = "Cosmos PDF Fixture Page \(index + 1)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 18),
                .foregroundColor: NSColor.black
            ]
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(
                cgContext: context,
                flipped: false
            )
            text.draw(
                at: CGPoint(x: 48, y: 720),
                withAttributes: attributes
            )
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }
        context.closePDF()
        return destination
    }

    func makeEncryptedPDF() throws -> URL {
        let destination = url.appendingPathComponent("encrypted.pdf")
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let options: [CFString: Any] = [
            kCGPDFContextUserPassword: "secret",
            kCGPDFContextOwnerPassword: "owner"
        ]
        guard let consumer = CGDataConsumer(url: destination as CFURL),
              let context = CGContext(
                consumer: consumer,
                mediaBox: &mediaBox,
                options as CFDictionary
              ) else {
            throw FixtureError.creationFailed
        }
        context.beginPDFPage(nil)
        context.endPDFPage()
        context.closePDF()
        return destination
    }

    func makePNG(name: String) throws -> URL {
        let destination = url.appendingPathComponent(name)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 64,
            pixelsHigh: 64,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw FixtureError.creationFailed
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 64, height: 64)).fill()
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw FixtureError.creationFailed
        }
        try data.write(to: destination, options: .atomic)
        return destination
    }

    func makeRawPDF(
        catalogExtras: String = "",
        annotation: String? = nil,
        extraObjects: [String] = []
    ) throws -> URL {
        let destination = url.appendingPathComponent(
            "raw-\(UUID().uuidString).pdf"
        )
        var objects = [
            "<< /Type /Catalog /Pages 2 0 R \(catalogExtras) >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
                + "/Resources << >> /Contents 4 0 R "
                + (annotation == nil ? "" : "/Annots [5 0 R] ")
                + ">>",
            "<< /Length 0 >>\nstream\n\nendstream"
        ]
        if let annotation {
            objects.append(annotation)
        }
        objects.append(contentsOf: extraObjects)

        var data = Data("%PDF-1.7\n".utf8)
        var offsets: [Int] = [0]
        for (index, object) in objects.enumerated() {
            offsets.append(data.count)
            data.append(Data("\(index + 1) 0 obj\n".utf8))
            data.append(Data(object.utf8))
            data.append(Data("\nendobj\n".utf8))
        }
        let xrefOffset = data.count
        data.append(Data("xref\n0 \(objects.count + 1)\n".utf8))
        data.append(Data("0000000000 65535 f \n".utf8))
        for offset in offsets.dropFirst() {
            data.append(
                Data(String(format: "%010d 00000 n \n", offset).utf8)
            )
        }
        data.append(
            Data(
                ("trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\n"
                    + "startxref\n\(xrefOffset)\n%%EOF\n").utf8
            )
        )
        try data.write(to: destination, options: .atomic)
        return destination
    }

    func write(
        _ data: Data,
        name: String
    ) throws -> URL {
        let destination = url.appendingPathComponent(name)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private enum FixtureError: Error {
        case creationFailed
    }
}
