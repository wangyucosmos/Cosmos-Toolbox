import Foundation
@preconcurrency import CoreGraphics


enum ArtifactPDFUnsafeFeature: String, Equatable {
    case acroForm
    case widget
    case javaScript
    case openAction
    case additionalActions
    case submitForm
    case importData
    case resetForm
    case embeddedFiles
    case fileAttachment
    case sound
    case movie
    case richMedia
    case threeD
    case unknownAction
    case chainedAction
}


enum ArtifactPDFPreviewError: Error, Equatable {
    case cancelled
    case timedOut
    case missingFile
    case unreadableFile
    case changedFile
    case unsupportedFormat
    case declaredFormatMismatch
    case corruptFile
    case encryptedDocument
    case fileTooLarge
    case pageCountExceeded
    case invalidPageSize
    case pageDimensionExceeded
    case pageAreaExceeded
    case unsafeFeature(ArtifactPDFUnsafeFeature)

    var isRecoverable: Bool {
        switch self {
        case .missingFile, .unreadableFile, .changedFile, .timedOut:
            return true
        default:
            return false
        }
    }

    var title: String {
        switch self {
        case .cancelled:
            return "PDF 加载已取消"
        case .timedOut:
            return "PDF 加载超过时间限制"
        case .missingFile:
            return "PDF 文件不存在"
        case .unreadableFile:
            return "无法读取 PDF 文件"
        case .changedFile:
            return "PDF 文件已发生变化"
        case .unsupportedFormat:
            return "不支持此文件格式"
        case .declaredFormatMismatch:
            return "PDF 格式与文件声明不一致"
        case .corruptFile:
            return "PDF 已损坏或无法安全解析"
        case .encryptedDocument:
            return "暂不支持加密 PDF"
        case .fileTooLarge:
            return "PDF 文件超过安全大小限制"
        case .pageCountExceeded:
            return "PDF 页数超过安全限制"
        case .invalidPageSize:
            return "PDF 页面尺寸无效"
        case .pageDimensionExceeded:
            return "PDF 页面单边尺寸超过安全限制"
        case .pageAreaExceeded:
            return "PDF 页面面积超过安全限制"
        case .unsafeFeature:
            return "PDF 包含 Phase 1 不允许的交互内容"
        }
    }

    var message: String {
        switch self {
        case .missingFile, .unreadableFile, .changedFile:
            return "原文件可能已被移动、替换或修改。请确认文件状态后重新加载。"
        case .timedOut:
            return "预览已停止等待。底层同步解析可能仍在受控单并发队列中结束。"
        case .unsupportedFormat, .declaredFormatMismatch:
            return "PDF Renderer 不会调用其他程序或解码器宽松打开该文件。"
        case .encryptedDocument:
            return "PDF Renderer Phase 1 不提供密码输入或解锁流程。"
        case .fileTooLarge, .pageCountExceeded,
             .pageDimensionExceeded, .pageAreaExceeded:
            return "该文件超过 PDF Preview Phase 1 的资源预算，未进入 PDFView。"
        case .unsafeFeature:
            return "为保持只读安全边界，该文档未进入 PDFView，原文件未被修改。"
        case .corruptFile, .invalidPageSize:
            return "Renderer 已停止处理该文件，原始 Artifact 未被修改。"
        case .cancelled:
            return ""
        }
    }
}


struct ArtifactPDFPageMetadata: Equatable {
    let widthPoints: Double
    let heightPoints: Double
}


struct ArtifactPDFPreviewMetadata: Equatable {
    let fileSize: Int64
    let pages: [ArtifactPDFPageMetadata]
    let blockedExternalActionCount: Int

    var pageCount: Int { pages.count }
}


struct ArtifactPDFStructuredInspection: Equatable {
    let metadata: ArtifactPDFPreviewMetadata
}


nonisolated struct ArtifactPDFPreviewSecurityPolicy: Equatable {
    static let maximumFileSize: Int64 = 50 * 1_024 * 1_024
    static let maximumPageCount = 500
    static let maximumPageDimension = 7_200.0
    static let maximumPageArea = 16_000_000.0
    static let minimumZoom = 0.10
    static let maximumZoom = 4.00
    static let loadTimeoutNanoseconds: UInt64 = 8_000_000_000

    func validateFileSize(_ fileSize: Int64) throws {
        guard fileSize >= 0 else {
            throw ArtifactPDFPreviewError.unreadableFile
        }
        guard fileSize <= Self.maximumFileSize else {
            throw ArtifactPDFPreviewError.fileTooLarge
        }
    }

    func validatePageCount(_ pageCount: Int) throws {
        guard pageCount > 0 else {
            throw ArtifactPDFPreviewError.corruptFile
        }
        guard pageCount <= Self.maximumPageCount else {
            throw ArtifactPDFPreviewError.pageCountExceeded
        }
    }

    func validatePageSize(_ size: CGSize) throws {
        let width = size.width
        let height = size.height
        guard width.isFinite, height.isFinite,
              width > 0, height > 0 else {
            throw ArtifactPDFPreviewError.invalidPageSize
        }
        guard width <= Self.maximumPageDimension,
              height <= Self.maximumPageDimension else {
            throw ArtifactPDFPreviewError.pageDimensionExceeded
        }
        let area = width * height
        guard area.isFinite,
              area <= Self.maximumPageArea else {
            throw ArtifactPDFPreviewError.pageAreaExceeded
        }
    }
}


nonisolated protocol ArtifactPDFStructureInspecting {
    func inspect(
        data: Data,
        fileSize: Int64
    ) throws -> ArtifactPDFStructuredInspection
}


nonisolated struct ArtifactPDFStructureInspector:
    ArtifactPDFStructureInspecting {

    let policy: ArtifactPDFPreviewSecurityPolicy

    init(policy: ArtifactPDFPreviewSecurityPolicy = .init()) {
        self.policy = policy
    }

    func inspect(
        data: Data,
        fileSize: Int64
    ) throws -> ArtifactPDFStructuredInspection {
        guard data.starts(with: Data("%PDF-".utf8)) else {
            throw ArtifactPDFPreviewError.unsupportedFormat
        }
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider) else {
            throw ArtifactPDFPreviewError.corruptFile
        }
        guard !document.isEncrypted, document.isUnlocked else {
            throw ArtifactPDFPreviewError.encryptedDocument
        }

        let pageCount = document.numberOfPages
        try policy.validatePageCount(pageCount)
        guard let catalog = document.catalog else {
            throw ArtifactPDFPreviewError.corruptFile
        }

        try inspectCatalog(catalog)

        var pages: [ArtifactPDFPageMetadata] = []
        var blockedExternalActionCount = 0
        pages.reserveCapacity(pageCount)

        for pageIndex in 1...pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: pageIndex) else {
                throw ArtifactPDFPreviewError.corruptFile
            }
            let pageBox = page.getBoxRect(.cropBox)
            try policy.validatePageSize(pageBox.size)
            pages.append(
                ArtifactPDFPageMetadata(
                    widthPoints: pageBox.width,
                    heightPoints: pageBox.height
                )
            )
            guard let pageDictionary = page.dictionary else {
                throw ArtifactPDFPreviewError.corruptFile
            }
            blockedExternalActionCount += try inspectPage(pageDictionary)
        }

        return ArtifactPDFStructuredInspection(
            metadata: ArtifactPDFPreviewMetadata(
                fileSize: fileSize,
                pages: pages,
                blockedExternalActionCount: blockedExternalActionCount
            )
        )
    }

    private func inspectCatalog(
        _ catalog: CGPDFDictionaryRef
    ) throws {
        if hasObject(catalog, key: "AcroForm") {
            throw ArtifactPDFPreviewError.unsafeFeature(.acroForm)
        }
        if hasObject(catalog, key: "OpenAction") {
            throw ArtifactPDFPreviewError.unsafeFeature(.openAction)
        }
        if hasObject(catalog, key: "AA") {
            throw ArtifactPDFPreviewError.unsafeFeature(.additionalActions)
        }
        if hasObject(catalog, key: "AF")
            || hasObject(catalog, key: "Collection") {
            throw ArtifactPDFPreviewError.unsafeFeature(.embeddedFiles)
        }

        if let names = dictionary(catalog, key: "Names") {
            if hasObject(names, key: "JavaScript") {
                throw ArtifactPDFPreviewError.unsafeFeature(.javaScript)
            }
            if hasObject(names, key: "EmbeddedFiles") {
                throw ArtifactPDFPreviewError.unsafeFeature(.embeddedFiles)
            }
        }
    }

    private func inspectPage(
        _ page: CGPDFDictionaryRef
    ) throws -> Int {
        if hasObject(page, key: "AA") {
            throw ArtifactPDFPreviewError.unsafeFeature(.additionalActions)
        }
        if hasObject(page, key: "AF") {
            throw ArtifactPDFPreviewError.unsafeFeature(.embeddedFiles)
        }
        guard let annotations = array(page, key: "Annots") else {
            return 0
        }

        var blockedCount = 0
        for index in 0..<CGPDFArrayGetCount(annotations) {
            guard let annotation = dictionary(annotations, index: index) else {
                throw ArtifactPDFPreviewError.corruptFile
            }
            blockedCount += try inspectAnnotation(annotation)
        }
        return blockedCount
    }

    private func inspectAnnotation(
        _ annotation: CGPDFDictionaryRef
    ) throws -> Int {
        guard let subtype = name(annotation, key: "Subtype") else {
            throw ArtifactPDFPreviewError.corruptFile
        }

        switch subtype {
        case "Widget":
            throw ArtifactPDFPreviewError.unsafeFeature(.widget)
        case "FileAttachment":
            throw ArtifactPDFPreviewError.unsafeFeature(.fileAttachment)
        case "Sound":
            throw ArtifactPDFPreviewError.unsafeFeature(.sound)
        case "Movie", "Screen":
            throw ArtifactPDFPreviewError.unsafeFeature(.movie)
        case "RichMedia":
            throw ArtifactPDFPreviewError.unsafeFeature(.richMedia)
        case "3D":
            throw ArtifactPDFPreviewError.unsafeFeature(.threeD)
        default:
            break
        }

        if hasObject(annotation, key: "AA") {
            throw ArtifactPDFPreviewError.unsafeFeature(.additionalActions)
        }
        if hasObject(annotation, key: "AF") {
            throw ArtifactPDFPreviewError.unsafeFeature(.embeddedFiles)
        }

        guard let action = dictionary(annotation, key: "A") else {
            return 0
        }
        return try inspectAnnotationAction(action)
    }

    private func inspectAnnotationAction(
        _ action: CGPDFDictionaryRef
    ) throws -> Int {
        if hasObject(action, key: "Next") {
            throw ArtifactPDFPreviewError.unsafeFeature(.chainedAction)
        }
        guard let actionName = name(action, key: "S") else {
            throw ArtifactPDFPreviewError.unsafeFeature(.unknownAction)
        }

        switch actionName {
        case "GoTo":
            guard hasObject(action, key: "D") else {
                throw ArtifactPDFPreviewError.unsafeFeature(.unknownAction)
            }
            return 0
        case "URI", "Launch", "GoToR", "Named":
            return 1
        case "JavaScript":
            throw ArtifactPDFPreviewError.unsafeFeature(.javaScript)
        case "SubmitForm":
            throw ArtifactPDFPreviewError.unsafeFeature(.submitForm)
        case "ImportData":
            throw ArtifactPDFPreviewError.unsafeFeature(.importData)
        case "ResetForm":
            throw ArtifactPDFPreviewError.unsafeFeature(.resetForm)
        default:
            throw ArtifactPDFPreviewError.unsafeFeature(.unknownAction)
        }
    }

    private func hasObject(
        _ dictionary: CGPDFDictionaryRef,
        key: String
    ) -> Bool {
        var object: CGPDFObjectRef?
        return CGPDFDictionaryGetObject(dictionary, key, &object)
    }

    private func dictionary(
        _ dictionary: CGPDFDictionaryRef,
        key: String
    ) -> CGPDFDictionaryRef? {
        var value: CGPDFDictionaryRef?
        return CGPDFDictionaryGetDictionary(dictionary, key, &value)
            ? value
            : nil
    }

    private func array(
        _ dictionary: CGPDFDictionaryRef,
        key: String
    ) -> CGPDFArrayRef? {
        var value: CGPDFArrayRef?
        return CGPDFDictionaryGetArray(dictionary, key, &value)
            ? value
            : nil
    }

    private func dictionary(
        _ array: CGPDFArrayRef,
        index: Int
    ) -> CGPDFDictionaryRef? {
        var value: CGPDFDictionaryRef?
        return CGPDFArrayGetDictionary(array, index, &value)
            ? value
            : nil
    }

    private func name(
        _ dictionary: CGPDFDictionaryRef,
        key: String
    ) -> String? {
        var value: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dictionary, key, &value),
              let value else {
            return nil
        }
        return String(cString: value)
    }
}
