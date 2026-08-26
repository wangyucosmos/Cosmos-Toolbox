import Foundation
@preconcurrency import CoreGraphics
@preconcurrency import ImageIO
import UniformTypeIdentifiers


enum ArtifactImagePreviewFormat: String, Equatable {
    case png
    case jpeg

    var displayName: String {
        switch self {
        case .png:
            return "PNG"
        case .jpeg:
            return "JPEG"
        }
    }
}


struct ArtifactImagePreviewMetadata: Equatable {
    let format: ArtifactImagePreviewFormat
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSize: Int64
    let colorSpaceName: String
}


struct ArtifactImagePreviewResult {
    let image: CGImage
    let metadata: ArtifactImagePreviewMetadata
}


nonisolated protocol ArtifactImagePreviewLoading {
    func load(
        reference: ArtifactReviewLocalFileReference
    ) async throws -> ArtifactImagePreviewResult
}


enum ArtifactImagePreviewError: Error, Equatable {
    case cancelled
    case missingFile
    case unreadableFile
    case changedFile
    case unsupportedFormat
    case declaredFormatMismatch
    case corruptFile
    case multipleFrames
    case fileTooLarge
    case invalidDimensions
    case dimensionsTooLarge
    case pixelCountTooLarge
    case decompressionBudgetExceeded
    case invalidColorSpace

    var isRecoverable: Bool {
        switch self {
        case .missingFile, .unreadableFile, .changedFile:
            return true
        default:
            return false
        }
    }

    var title: String {
        switch self {
        case .cancelled:
            return "图片加载已取消"
        case .missingFile:
            return "图片文件不存在"
        case .unreadableFile:
            return "无法读取图片文件"
        case .changedFile:
            return "图片文件已发生变化"
        case .unsupportedFormat:
            return "不支持此图片格式"
        case .declaredFormatMismatch:
            return "图片格式与文件声明不一致"
        case .corruptFile:
            return "图片文件已损坏或无法安全解码"
        case .multipleFrames:
            return "暂不支持多帧图片"
        case .fileTooLarge:
            return "图片文件超过安全大小限制"
        case .invalidDimensions:
            return "图片像素尺寸无效"
        case .dimensionsTooLarge:
            return "图片单边尺寸超过安全限制"
        case .pixelCountTooLarge:
            return "图片总像素超过安全限制"
        case .decompressionBudgetExceeded:
            return "图片预计解压内存超过安全限制"
        case .invalidColorSpace:
            return "图片色彩空间无法安全处理"
        }
    }

    var message: String {
        switch self {
        case .missingFile, .unreadableFile, .changedFile:
            return "原文件可能已被移动、替换或修改。请确认文件状态后重新加载。"
        case .unsupportedFormat:
            return "Image Renderer Phase 1 仅支持单帧静态 PNG 和 JPEG。"
        case .declaredFormatMismatch:
            return "为保护 Artifact 边界，Renderer 不会按其他格式宽松尝试解码。"
        case .multipleFrames:
            return "GIF、APNG 和其他多帧内容不会静默降级为第一帧。"
        case .fileTooLarge, .dimensionsTooLarge,
             .pixelCountTooLarge, .decompressionBudgetExceeded:
            return "该文件超过 Image Preview Phase 1 的资源预算，未执行完整解码。"
        case .corruptFile, .invalidDimensions, .invalidColorSpace:
            return "Renderer 已停止处理该文件，原始 Artifact 未被修改。"
        case .cancelled:
            return ""
        }
    }
}


nonisolated struct ArtifactImagePreviewSecurityPolicy: Equatable {
    static let maximumFileSize: Int64 = 50 * 1_024 * 1_024
    static let maximumDimension = 16_384
    static let maximumPixelCount = 36_000_000
    static let maximumEstimatedPeakBytes: Int64 = 224 * 1_024 * 1_024
    static let bytesPerPixel = 4
    static let rowAlignment = 64

    func validateFileSize(_ fileSize: Int64) throws {
        guard fileSize >= 0 else {
            throw ArtifactImagePreviewError.unreadableFile
        }
        guard fileSize <= Self.maximumFileSize else {
            throw ArtifactImagePreviewError.fileTooLarge
        }
    }

    func validateDimensions(width: Int, height: Int) throws {
        guard width > 0, height > 0 else {
            throw ArtifactImagePreviewError.invalidDimensions
        }
        guard width <= Self.maximumDimension,
              height <= Self.maximumDimension else {
            throw ArtifactImagePreviewError.dimensionsTooLarge
        }

        let (pixelCount, pixelOverflow) = width.multipliedReportingOverflow(
            by: height
        )
        guard !pixelOverflow else {
            throw ArtifactImagePreviewError.pixelCountTooLarge
        }
        guard pixelCount <= Self.maximumPixelCount else {
            throw ArtifactImagePreviewError.pixelCountTooLarge
        }

        _ = try estimatedPeakBytes(width: width, height: height)
    }

    func estimatedPeakBytes(width: Int, height: Int) throws -> Int64 {
        guard width > 0, height > 0 else {
            throw ArtifactImagePreviewError.invalidDimensions
        }

        let (rawRowBytes, rowOverflow) = width.multipliedReportingOverflow(
            by: Self.bytesPerPixel
        )
        guard !rowOverflow else {
            throw ArtifactImagePreviewError.decompressionBudgetExceeded
        }

        let alignmentRemainder = rawRowBytes % Self.rowAlignment
        let padding = alignmentRemainder == 0
            ? 0
            : Self.rowAlignment - alignmentRemainder
        let (alignedRowBytes, alignmentOverflow) =
            rawRowBytes.addingReportingOverflow(padding)
        guard !alignmentOverflow else {
            throw ArtifactImagePreviewError.decompressionBudgetExceeded
        }

        let (decodedBytes, decodedOverflow) =
            alignedRowBytes.multipliedReportingOverflow(by: height)
        guard !decodedOverflow else {
            throw ArtifactImagePreviewError.decompressionBudgetExceeded
        }

        let (weightedBytes, weightingOverflow) =
            decodedBytes.multipliedReportingOverflow(by: 3)
        guard !weightingOverflow else {
            throw ArtifactImagePreviewError.decompressionBudgetExceeded
        }

        let estimatedBytes = weightedBytes / 2
        guard let estimatedBytes64 = Int64(exactly: estimatedBytes),
              estimatedBytes64 <= Self.maximumEstimatedPeakBytes else {
            throw ArtifactImagePreviewError.decompressionBudgetExceeded
        }
        return estimatedBytes64
    }
}


nonisolated struct ArtifactImageFileFingerprint: Equatable {
    let fileSize: Int64
    let modificationDate: Date?
    let resourceIdentifier: String?
}


actor ArtifactImageDecodeGate {
    static let shared = ArtifactImageDecodeGate()

    private(set) var activeOperationCount = 0
    private(set) var maximumObservedOperationCount = 0

    func perform<T>(_ operation: () throws -> T) throws -> T {
        try Task.checkCancellation()
        activeOperationCount += 1
        maximumObservedOperationCount = max(
            maximumObservedOperationCount,
            activeOperationCount
        )
        defer { activeOperationCount -= 1 }

        let value = try operation()
        try Task.checkCancellation()
        return value
    }
}


nonisolated struct ArtifactImagePreviewLoader: ArtifactImagePreviewLoading {
    let policy: ArtifactImagePreviewSecurityPolicy
    let decodeGate: ArtifactImageDecodeGate
    private let fingerprintProvider:
        (URL) throws -> ArtifactImageFileFingerprint

    init(
        policy: ArtifactImagePreviewSecurityPolicy = .init(),
        decodeGate: ArtifactImageDecodeGate = .shared,
        fingerprintProvider: @escaping
            (URL) throws -> ArtifactImageFileFingerprint =
                ArtifactImagePreviewLoader.defaultFingerprint
    ) {
        self.policy = policy
        self.decodeGate = decodeGate
        self.fingerprintProvider = fingerprintProvider
    }

    func load(
        reference: ArtifactReviewLocalFileReference
    ) async throws -> ArtifactImagePreviewResult {
        do {
            return try await decodeGate.perform {
                try decode(reference: reference)
            }
        } catch is CancellationError {
            throw ArtifactImagePreviewError.cancelled
        }
    }

    private func decode(
        reference: ArtifactReviewLocalFileReference
    ) throws -> ArtifactImagePreviewResult {
        try Task.checkCancellation()

        let url = reference.url
        guard url.isFileURL else {
            throw ArtifactImagePreviewError.unreadableFile
        }

        let didAccessSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let initialFingerprint = try fingerprintProvider(url)
        try policy.validateFileSize(initialFingerprint.fileSize)
        try Task.checkCancellation()

        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            sourceOptions
        ) else {
            throw ArtifactImagePreviewError.corruptFile
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else {
            throw ArtifactImagePreviewError.corruptFile
        }
        guard frameCount == 1 else {
            throw ArtifactImagePreviewError.multipleFrames
        }

        let format = try actualFormat(for: source)
        try validateDeclaredFormat(
            reference.mediaType,
            matches: format
        )

        guard let properties = CGImageSourceCopyPropertiesAtIndex(
            source,
            0,
            nil
        ) as? [CFString: Any],
              let rawWidth = number(
                properties[kCGImagePropertyPixelWidth]
              ),
              let rawHeight = number(
                properties[kCGImagePropertyPixelHeight]
              ) else {
            throw ArtifactImagePreviewError.corruptFile
        }

        try policy.validateDimensions(width: rawWidth, height: rawHeight)

        let orientation = number(
            properties[kCGImagePropertyOrientation]
        ) ?? 1
        let swapsDimensions = [5, 6, 7, 8].contains(orientation)
        let orientedWidth = swapsDimensions ? rawHeight : rawWidth
        let orientedHeight = swapsDimensions ? rawWidth : rawHeight
        try policy.validateDimensions(
            width: orientedWidth,
            height: orientedHeight
        )
        try Task.checkCancellation()

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize:
                max(rawWidth, rawHeight),
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        guard let decodedImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions
        ) else {
            throw ArtifactImagePreviewError.corruptFile
        }

        try policy.validateDimensions(
            width: decodedImage.width,
            height: decodedImage.height
        )
        guard decodedImage.width == orientedWidth,
              decodedImage.height == orientedHeight else {
            throw ArtifactImagePreviewError.corruptFile
        }

        let normalizedImage = try normalizedColorImage(decodedImage)
        let finalFingerprint = try fingerprintProvider(url)
        guard finalFingerprint == initialFingerprint else {
            throw ArtifactImagePreviewError.changedFile
        }
        try Task.checkCancellation()

        return ArtifactImagePreviewResult(
            image: normalizedImage.image,
            metadata: ArtifactImagePreviewMetadata(
                format: format,
                pixelWidth: normalizedImage.image.width,
                pixelHeight: normalizedImage.image.height,
                fileSize: finalFingerprint.fileSize,
                colorSpaceName: normalizedImage.colorSpaceName
            )
        )
    }

    static func defaultFingerprint(
        for url: URL
    ) throws -> ArtifactImageFileFingerprint {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ArtifactImagePreviewError.missingFile
        }

        do {
            let values = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .fileResourceIdentifierKey,
                .isRegularFileKey,
                .isReadableKey
            ])
            guard values.isRegularFile == true,
                  values.isReadable == true,
                  let fileSize = values.fileSize,
                  let fileSize64 = Int64(exactly: fileSize) else {
                throw ArtifactImagePreviewError.unreadableFile
            }
            return ArtifactImageFileFingerprint(
                fileSize: fileSize64,
                modificationDate: values.contentModificationDate,
                resourceIdentifier: values.fileResourceIdentifier.map {
                    String(reflecting: $0)
                }
            )
        } catch let error as ArtifactImagePreviewError {
            throw error
        } catch {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ArtifactImagePreviewError.missingFile
            }
            throw ArtifactImagePreviewError.unreadableFile
        }
    }

    private func actualFormat(
        for source: CGImageSource
    ) throws -> ArtifactImagePreviewFormat {
        guard let identifier = CGImageSourceGetType(source) as String?,
              let type = UTType(identifier) else {
            throw ArtifactImagePreviewError.corruptFile
        }
        if type.conforms(to: .png) {
            return .png
        }
        if type.conforms(to: .jpeg) {
            return .jpeg
        }
        throw ArtifactImagePreviewError.unsupportedFormat
    }

    private func validateDeclaredFormat(
        _ mediaType: ArtifactReviewMediaType,
        matches actualFormat: ArtifactImagePreviewFormat
    ) throws {
        var declaredFormats = Set<ArtifactImagePreviewFormat>()

        if let identifier = mediaType.uniformTypeIdentifier,
           let type = UTType(identifier) {
            if type.conforms(to: .png) {
                declaredFormats.insert(.png)
            } else if type.conforms(to: .jpeg) {
                declaredFormats.insert(.jpeg)
            } else if type.conforms(to: .image), type != .image {
                throw ArtifactImagePreviewError.unsupportedFormat
            }
        }

        if let mimeType = mediaType.mimeType?.lowercased() {
            switch mimeType {
            case "image/png":
                declaredFormats.insert(.png)
            case "image/jpeg", "image/jpg":
                declaredFormats.insert(.jpeg)
            default:
                if mimeType.hasPrefix("image/") {
                    throw ArtifactImagePreviewError.unsupportedFormat
                }
            }
        }

        if let fileExtension = mediaType.fileExtension?.lowercased(),
           !fileExtension.isEmpty {
            switch fileExtension {
            case "png":
                declaredFormats.insert(.png)
            case "jpg", "jpeg":
                declaredFormats.insert(.jpeg)
            default:
                throw ArtifactImagePreviewError.unsupportedFormat
            }
        }

        guard declaredFormats.count <= 1,
              declaredFormats.first == nil
                || declaredFormats.first == actualFormat else {
            throw ArtifactImagePreviewError.declaredFormatMismatch
        }
    }

    private func normalizedColorImage(
        _ image: CGImage
    ) throws -> (image: CGImage, colorSpaceName: String) {
        if let colorSpace = image.colorSpace {
            guard colorSpace.model != .unknown,
                  colorSpace.model != .pattern else {
                throw ArtifactImagePreviewError.invalidColorSpace
            }
            return (
                image,
                colorSpace.name as String?
                    ?? String(describing: colorSpace.model)
            )
        }

        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: sRGB,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw ArtifactImagePreviewError.invalidColorSpace
        }
        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        guard let convertedImage = context.makeImage() else {
            throw ArtifactImagePreviewError.invalidColorSpace
        }
        return (convertedImage, "sRGB")
    }

    private func number(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }
}
