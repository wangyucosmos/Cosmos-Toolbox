import XCTest
import AppKit
import SwiftUI
@preconcurrency import CoreGraphics
@preconcurrency import ImageIO
import UniformTypeIdentifiers
@testable import Cosmos_Toolbox


@MainActor
final class ArtifactImageRendererTests: XCTestCase {

    private static var retainedSmokeWindows: [NSWindow] = []

    func testPNGAndJPEGProjectToTypedImageRendererWithoutUTF8Decode()
        throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }

        let pngURL = try fixtures.makeImage(
            format: .png,
            fileExtension: "png"
        )
        let jpegURL = try fixtures.makeImage(
            format: .jpeg,
            fileExtension: "jpg"
        )
        var utf8ReadCount = 0
        let resolver = ArtifactPreviewInputResolver(
            fileExists: { FileManager.default.fileExists(atPath: $0.path) },
            readUTF8Text: { _ in
                utf8ReadCount += 1
                return "unexpected"
            }
        )

        for url in [pngURL, jpegURL] {
            let projection = makeProjection(url: url)
            let document = ArtifactReviewDocument(
                projection: projection,
                resolver: resolver
            )

            XCTAssertEqual(document.previewInput.mediaType.classification, .image)
            XCTAssertNotNil(document.previewInput.localFileReference)
            XCTAssertNil(document.previewInput.sourceText)
            XCTAssertEqual(document.content, "")
            XCTAssertEqual(
                ArtifactPreviewRendererRegistry().rendererIdentifier(
                    for: document.previewInput
                ),
                .image
            )
        }
        XCTAssertEqual(utf8ReadCount, 0)
        XCTAssertTrue(fixtures.remove())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixtures.url.path))
    }

    func testPNGAndJPEGSignaturesDecodeWithMinimalMetadata() async throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let loader = ArtifactImagePreviewLoader()

        let pngURL = try fixtures.makeImage(
            format: .png,
            fileExtension: "png",
            width: 24,
            height: 12
        )
        let jpegURL = try fixtures.makeImage(
            format: .jpeg,
            fileExtension: "jpeg",
            width: 30,
            height: 18
        )

        let png = try await loader.load(reference: reference(for: pngURL))
        let jpeg = try await loader.load(reference: reference(for: jpegURL))

        XCTAssertEqual(png.metadata.format, .png)
        XCTAssertEqual(png.metadata.pixelWidth, 24)
        XCTAssertEqual(png.metadata.pixelHeight, 12)
        XCTAssertGreaterThan(png.metadata.fileSize, 0)
        XCTAssertFalse(png.metadata.colorSpaceName.isEmpty)
        XCTAssertEqual(jpeg.metadata.format, .jpeg)
        XCTAssertEqual(jpeg.metadata.pixelWidth, 30)
        XCTAssertEqual(jpeg.metadata.pixelHeight, 18)
    }

    func testDeclaredPNGWithActualJPEGIsRejected() async throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let url = try fixtures.makeImage(
            format: .jpeg,
            fileExtension: "png"
        )

        let error = await imageError {
            try await ArtifactImagePreviewLoader().load(
                reference: reference(for: url)
            )
        }
        XCTAssertEqual(error, .declaredFormatMismatch)
    }

    func testDeclaredJPEGWithActualPNGIsRejected() async throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let url = try fixtures.makeImage(
            format: .png,
            fileExtension: "jpg"
        )

        let error = await imageError {
            try await ArtifactImagePreviewLoader().load(
                reference: reference(for: url)
            )
        }
        XCTAssertEqual(error, .declaredFormatMismatch)
    }

    func testExtensionlessTypedImageUsesActualSignature() async throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let url = try fixtures.makeImage(
            format: .png,
            fileExtension: nil
        )
        let mediaType = ArtifactReviewMediaType(
            legacyArtifactType: .image
        )

        let result = try await ArtifactImagePreviewLoader().load(
            reference: ArtifactReviewLocalFileReference(
                url: url,
                mediaType: mediaType
            )
        )
        XCTAssertEqual(result.metadata.format, .png)
    }

    func testCorruptTruncatedAndUnknownImagesFailSafely() async throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let corruptURL = try fixtures.makeBytes(
            [0x89, 0x50, 0x4E, 0x47],
            fileExtension: "png"
        )
        let unknownURL = try fixtures.makeBytes(
            Array("not an image".utf8),
            fileExtension: "png"
        )

        for url in [corruptURL, unknownURL] {
            let error = await imageError {
                try await ArtifactImagePreviewLoader().load(
                    reference: reference(for: url)
                )
            }
            XCTAssertEqual(error, .corruptFile)
        }
    }

    func testMissingFileFailsRecoverably() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        let error = await imageError {
            try await ArtifactImagePreviewLoader().load(
                reference: reference(for: url)
            )
        }
        XCTAssertEqual(error, .missingFile)
        XCTAssertTrue(error?.isRecoverable == true)
    }

    func testGIFAndMultiFramePNGAreNeverSilentlyDecoded() async throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let gifURL = try fixtures.makeAnimatedImage(
            type: .gif,
            fileExtension: "gif"
        )
        let apngURL = try fixtures.makeAnimatedImage(
            type: .png,
            fileExtension: "png"
        )

        let gifError = await imageError {
            try await ArtifactImagePreviewLoader().load(
                reference: reference(for: gifURL)
            )
        }
        let apngError = await imageError {
            try await ArtifactImagePreviewLoader().load(
                reference: reference(for: apngURL)
            )
        }
        XCTAssertEqual(gifError, .multipleFrames)
        XCTAssertEqual(apngError, .multipleFrames)
    }

    func testUnsupportedStaticImageFormatsAreRejected() async throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let tiffURL = try fixtures.makeImage(
            format: .tiff,
            fileExtension: "tiff"
        )

        let error = await imageError {
            try await ArtifactImagePreviewLoader().load(
                reference: reference(for: tiffURL)
            )
        }
        XCTAssertEqual(error, .unsupportedFormat)
    }

    func testSecurityPolicyEnforcesFileAndDimensionLimits() throws {
        let policy = ArtifactImagePreviewSecurityPolicy()

        XCTAssertNoThrow(
            try policy.validateFileSize(
                ArtifactImagePreviewSecurityPolicy.maximumFileSize
            )
        )
        XCTAssertThrowsError(
            try policy.validateFileSize(
                ArtifactImagePreviewSecurityPolicy.maximumFileSize + 1
            )
        ) { error in
            XCTAssertEqual(error as? ArtifactImagePreviewError, .fileTooLarge)
        }
        XCTAssertNoThrow(
            try policy.validateDimensions(width: 8_192, height: 4_320)
        )
        XCTAssertThrowsError(
            try policy.validateDimensions(width: 16_385, height: 1)
        ) { error in
            XCTAssertEqual(
                error as? ArtifactImagePreviewError,
                .dimensionsTooLarge
            )
        }
        XCTAssertThrowsError(
            try policy.validateDimensions(width: 10_000, height: 3_601)
        ) { error in
            XCTAssertEqual(
                error as? ArtifactImagePreviewError,
                .pixelCountTooLarge
            )
        }
    }

    func testDecompressionBudgetUsesAlignmentAndRejectsOverflow() throws {
        let policy = ArtifactImagePreviewSecurityPolicy()

        let accepted = try policy.estimatedPeakBytes(
            width: 16_384,
            height: 2_300
        )
        XCTAssertLessThanOrEqual(
            accepted,
            ArtifactImagePreviewSecurityPolicy.maximumEstimatedPeakBytes
        )
        XCTAssertThrowsError(
            try policy.estimatedPeakBytes(width: Int.max, height: Int.max)
        ) { error in
            XCTAssertEqual(
                error as? ArtifactImagePreviewError,
                .decompressionBudgetExceeded
            )
        }
    }

    func testOrientationIsAppliedBeforeFinalDimensionResult() async throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let url = try fixtures.makeImage(
            format: .jpeg,
            fileExtension: "jpg",
            width: 40,
            height: 20,
            orientation: 6
        )

        let result = try await ArtifactImagePreviewLoader().load(
            reference: reference(for: url)
        )
        XCTAssertEqual(result.metadata.pixelWidth, 20)
        XCTAssertEqual(result.metadata.pixelHeight, 40)
    }

    func testSRGBAndDisplayP3ColorSpacesRemainSafe() async throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let sRGBURL = try fixtures.makeImage(
            format: .png,
            fileExtension: "png",
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        let p3URL = try fixtures.makeImage(
            format: .png,
            fileExtension: "png",
            colorSpace: CGColorSpace(name: CGColorSpace.displayP3)
        )

        let loader = ArtifactImagePreviewLoader()
        let sRGB = try await loader.load(reference: reference(for: sRGBURL))
        let p3 = try await loader.load(reference: reference(for: p3URL))

        XCTAssertFalse(sRGB.metadata.colorSpaceName.isEmpty)
        XCTAssertFalse(p3.metadata.colorSpaceName.isEmpty)
    }

    func testChangedFingerprintDiscardsDecodedResult() async throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let url = try fixtures.makeImage(
            format: .png,
            fileExtension: "png"
        )
        var callCount = 0
        let loader = ArtifactImagePreviewLoader(
            fingerprintProvider: { _ in
                callCount += 1
                return ArtifactImageFileFingerprint(
                    fileSize: 100 + Int64(callCount),
                    modificationDate: Date(timeIntervalSince1970: 1),
                    resourceIdentifier: "fixture"
                )
            }
        )

        let error = await imageError {
            try await loader.load(reference: reference(for: url))
        }
        XCTAssertEqual(error, .changedFile)
        XCTAssertEqual(callCount, 2)
    }

    func testCancelledTaskNeverPublishesDecodedResult() async throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let url = try fixtures.makeImage(
            format: .png,
            fileExtension: "png"
        )
        let task = Task {
            try await ArtifactImagePreviewLoader().load(
                reference: reference(for: url)
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Cancelled decode must not return an image")
        } catch let error as ArtifactImagePreviewError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("Unexpected cancellation error: \(error)")
        }
    }

    func testSharedDecodeGateSerializesHeavyOperations() async throws {
        let gate = ArtifactImageDecodeGate()

        async let first: Int = gate.perform {
            Thread.sleep(forTimeInterval: 0.04)
            return 1
        }
        async let second: Int = gate.perform {
            Thread.sleep(forTimeInterval: 0.04)
            return 2
        }

        let values = try await [first, second]
        XCTAssertEqual(Set(values), Set([1, 2]))
        let maximum = await gate.maximumObservedOperationCount
        XCTAssertEqual(maximum, 1)
    }

    func testImageCapabilitiesExcludeSourceAndMobileViewport() {
        let capabilities = ArtifactImagePreviewRenderer().capabilities

        XCTAssertTrue(capabilities.supportsPreview)
        XCTAssertFalse(capabilities.supportsSource)
        XCTAssertTrue(capabilities.supportsFullPreview)
        XCTAssertFalse(capabilities.supportsMobileViewport)

        var state = ArtifactReviewWorkspaceState(
            displayMode: .source,
            presentationMode: .fullPreview,
            mobileViewport: .width375
        )
        state.normalize(for: capabilities)
        XCTAssertEqual(state.displayMode, .preview)
        XCTAssertEqual(state.presentationMode, .fullPreview)
    }

    func testZoomFitActualSizeBoundsAndDisplayScale() {
        let pixelSize = CGSize(width: 400, height: 200)

        var state = ArtifactImageZoomState.fit
        XCTAssertEqual(
            state.scale(
                imagePixelSize: pixelSize,
                availablePointSize: CGSize(width: 500, height: 500),
                displayScale: 2
            ),
            1
        )
        XCTAssertEqual(
            state.scale(
                imagePixelSize: pixelSize,
                availablePointSize: CGSize(width: 100, height: 100),
                displayScale: 2
            ),
            0.5
        )

        state.showActualSize()
        XCTAssertEqual(state.percentageValue, 1)
        for _ in 0..<20 { state.zoomIn() }
        XCTAssertEqual(state.percentageValue, 4)
        for _ in 0..<20 { state.zoomOut() }
        XCTAssertEqual(state.percentageValue, 0.10)
        state.reset()
        XCTAssertEqual(state, .fit)
    }

    func testImageAndHTMLMixedCompareCapabilitiesRemainIndependent()
        throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let imageURL = try fixtures.makeImage(
            format: .png,
            fileExtension: "png"
        )
        let imageDocument = ArtifactReviewDocument(
            projection: makeProjection(url: imageURL)
        )
        let htmlDocument = ArtifactReviewDocument(
            artifact: ZhuowangArtifact(
                campaignID: UUID(),
                name: "HTML",
                type: .html,
                content: "<html><body>Mixed</body></html>"
            )
        )
        let unsupportedDocument = ArtifactReviewDocument(
            artifact: ZhuowangArtifact(
                campaignID: UUID(),
                name: "Unsupported",
                type: .other,
                content: "unsupported"
            )
        )
        let registry = ArtifactPreviewRendererRegistry()

        XCTAssertEqual(
            registry.rendererIdentifier(for: imageDocument.previewInput),
            .image
        )
        XCTAssertFalse(
            registry.renderer(for: imageDocument.previewInput)
                .capabilities.supportsSource
        )
        XCTAssertTrue(
            registry.renderer(for: htmlDocument.previewInput)
                .capabilities.supportsSource
        )
        XCTAssertTrue(
            registry.renderer(for: htmlDocument.previewInput)
                .capabilities.supportsMobileViewport
        )
        XCTAssertEqual(
            registry.rendererIdentifier(for: unsupportedDocument.previewInput),
            .unsupported
        )

        let mixedItems = [
            ArtifactVersionComparisonItem(
                artifactID: imageDocument.id,
                version: 1,
                isCurrent: true,
                document: imageDocument
            ),
            ArtifactVersionComparisonItem(
                artifactID: htmlDocument.id,
                version: 2,
                isCurrent: false,
                document: htmlDocument
            )
        ]
        var state = try XCTUnwrap(
            ArtifactVersionCompareState(
                items: mixedItems,
                selectedArtifactID: htmlDocument.id
            )
        )
        state.leftDisplayMode = .source
        state.rightDisplayMode = .source
        state.normalizeDisplayModes(
            leftSupportsSource: false,
            rightSupportsSource: true
        )
        XCTAssertEqual(state.leftDisplayMode, .preview)
        XCTAssertEqual(state.rightDisplayMode, .source)
    }

    func testDocumentIdentityCreatesIndependentImageModels() throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let firstURL = try fixtures.makeImage(
            format: .png,
            fileExtension: "png"
        )
        let secondURL = try fixtures.makeImage(
            format: .jpeg,
            fileExtension: "jpg"
        )
        let firstDocument = ArtifactReviewDocument(
            projection: makeProjection(id: UUID(), url: firstURL)
        )
        let secondDocument = ArtifactReviewDocument(
            projection: makeProjection(id: UUID(), url: secondURL)
        )
        let firstModel = ArtifactImagePreviewViewModel(
            documentID: firstDocument.id,
            reference: try XCTUnwrap(
                firstDocument.previewInput.localFileReference
            )
        )
        let secondModel = ArtifactImagePreviewViewModel(
            documentID: secondDocument.id,
            reference: try XCTUnwrap(
                secondDocument.previewInput.localFileReference
            )
        )
        firstModel.zoomState = .percentage(2)

        XCTAssertNotEqual(firstModel.documentID, secondModel.documentID)
        XCTAssertEqual(firstModel.zoomState, .percentage(2))
        XCTAssertEqual(secondModel.zoomState, .fit)
    }

    func testFixtureReviewAndCompareWindowsRenderWithoutStore() throws {
        let fixtures = try ArtifactImageFixtureFactory()
        defer { fixtures.remove() }
        let pngURL = try fixtures.makeImage(
            format: .png,
            fileExtension: "png",
            width: 320,
            height: 640
        )
        let jpegURL = try fixtures.makeImage(
            format: .jpeg,
            fileExtension: "jpg",
            width: 640,
            height: 320
        )
        let leftDocument = ArtifactReviewDocument(
            projection: makeProjection(id: UUID(), url: pngURL)
        )
        let rightDocument = ArtifactReviewDocument(
            projection: makeProjection(id: UUID(), url: jpegURL)
        )
        let htmlDocument = ArtifactReviewDocument(
            artifact: ZhuowangArtifact(
                campaignID: UUID(),
                name: "Fixture HTML",
                type: .html,
                content: "<html><body><button>Fixture</button></body></html>"
            )
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
        reviewWindow.contentViewController = NSHostingController(
            rootView: ArtifactReviewWorkspace(
                document: leftDocument,
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
                name: "Image | Image",
                left: leftDocument,
                right: rightDocument,
                appearance: .aqua
            ),
            compareWindow(
                name: "HTML | Image",
                left: htmlDocument,
                right: leftDocument,
                appearance: .darkAqua
            ),
            compareWindow(
                name: "Image | HTML",
                left: leftDocument,
                right: htmlDocument,
                appearance: .aqua
            ),
            compareWindow(
                name: "Image | Unsupported",
                left: leftDocument,
                right: unsupportedDocument,
                appearance: .darkAqua
            )
        ]

        reviewWindow.orderFront(nil)
        compareWindows.forEach { $0.orderFront(nil) }
        reviewWindow.setContentSize(NSSize(width: 1_080, height: 780))
        compareWindows.forEach {
            $0.setContentSize(NSSize(width: 1_320, height: 800))
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        XCTAssertNotNil(reviewWindow.contentViewController?.view)
        compareWindows.forEach {
            XCTAssertNotNil($0.contentViewController?.view)
            XCTAssertGreaterThanOrEqual($0.contentLayoutRect.width, 1_180)
            XCTAssertGreaterThanOrEqual($0.contentLayoutRect.height, 720)
        }
        reviewWindow.orderOut(nil)
        compareWindows.forEach { $0.orderOut(nil) }
        reviewWindow.close()
        compareWindows.forEach { $0.close() }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        Self.retainedSmokeWindows.append(reviewWindow)
        Self.retainedSmokeWindows.append(contentsOf: compareWindows)
        XCTAssertTrue(fixtures.remove())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixtures.url.path))
    }

    private func makeProjection(
        id: UUID = UUID(),
        url: URL
    ) -> ArtifactReviewDocumentProjection {
        ArtifactReviewDocumentProjection(
            id: id,
            name: url.lastPathComponent,
            versionLabel: "Fixture",
            type: .image,
            payload: .localFile(reference(for: url)),
            prototypeExecutionProfile: nil,
            sourceProviderID: nil,
            sourceName: "Test Fixture",
            executedAt: Date(timeIntervalSince1970: 1)
        )
    }

    private func reference(
        for url: URL
    ) -> ArtifactReviewLocalFileReference {
        ArtifactReviewLocalFileReference(
            url: url,
            mediaType: .localFile(
                url: url,
                artifactType: .image
            )
        )
    }

    private func imageError(
        _ operation: () async throws -> ArtifactImagePreviewResult
    ) async -> ArtifactImagePreviewError? {
        do {
            _ = try await operation()
            return nil
        } catch let error as ArtifactImagePreviewError {
            return error
        } catch {
            return .corruptFile
        }
    }
}


private final class ArtifactImageFixtureFactory {
    enum StaticFormat {
        case png
        case jpeg
        case tiff

        var type: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            case .tiff: return .tiff
            }
        }
    }

    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "CosmosImageRendererFixtures-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    @discardableResult
    func remove() -> Bool {
        try? FileManager.default.removeItem(at: url)
        return !FileManager.default.fileExists(atPath: url.path)
    }

    func makeImage(
        format: StaticFormat,
        fileExtension: String?,
        width: Int = 32,
        height: Int = 24,
        orientation: Int = 1,
        colorSpace: CGColorSpace? = CGColorSpace(
            name: CGColorSpace.sRGB
        )
    ) throws -> URL {
        let image = try makeCGImage(
            width: width,
            height: height,
            colorSpace: colorSpace
        )
        let destinationURL = fileURL(extension: fileExtension)
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            format.type.identifier as CFString,
            1,
            nil
        ) else {
            throw FixtureError.destinationUnavailable
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImagePropertyOrientation: orientation] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureError.finalizeFailed
        }
        return destinationURL
    }

    func makeAnimatedImage(
        type: UTType,
        fileExtension: String
    ) throws -> URL {
        let destinationURL = fileURL(extension: fileExtension)
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            type.identifier as CFString,
            2,
            nil
        ) else {
            throw FixtureError.destinationUnavailable
        }
        CGImageDestinationAddImage(
            destination,
            try makeCGImage(width: 16, height: 12, colorSpace: nil),
            nil
        )
        CGImageDestinationAddImage(
            destination,
            try makeCGImage(width: 16, height: 12, colorSpace: nil),
            nil
        )
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureError.finalizeFailed
        }
        return destinationURL
    }

    func makeBytes(
        _ bytes: [UInt8],
        fileExtension: String
    ) throws -> URL {
        let destinationURL = fileURL(extension: fileExtension)
        try Data(bytes).write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    private func fileURL(extension fileExtension: String?) -> URL {
        let baseURL = url.appendingPathComponent(UUID().uuidString)
        guard let fileExtension else { return baseURL }
        return baseURL.appendingPathExtension(fileExtension)
    }

    private func makeCGImage(
        width: Int,
        height: Int,
        colorSpace: CGColorSpace?
    ) throws -> CGImage {
        let safeColorSpace = colorSpace
            ?? CGColorSpace(name: CGColorSpace.sRGB)
        guard let safeColorSpace,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: safeColorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw FixtureError.contextUnavailable
        }
        context.setFillColor(
            CGColor(
                colorSpace: safeColorSpace,
                components: [0.18, 0.55, 0.88, 0.65]
            ) ?? CGColor(gray: 0.5, alpha: 0.65)
        )
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            throw FixtureError.imageUnavailable
        }
        return image
    }

    enum FixtureError: Error {
        case contextUnavailable
        case imageUnavailable
        case destinationUnavailable
        case finalizeFailed
    }
}
