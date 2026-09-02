import Foundation
import UniformTypeIdentifiers


struct ArtifactPDFPreviewLoadResult: Equatable {
    let data: Data
    let metadata: ArtifactPDFPreviewMetadata
}


nonisolated protocol ArtifactPDFPreviewLoading {
    func load(
        reference: ArtifactReviewLocalFileReference
    ) async throws -> ArtifactPDFPreviewLoadResult
}


nonisolated struct ArtifactPDFFileFingerprint: Equatable {
    let fileSize: Int64
    let modificationDate: Date?
    let resourceIdentifier: String?
}


actor ArtifactPDFLoadGate {
    static let shared = ArtifactPDFLoadGate()

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


nonisolated struct ArtifactPDFPreviewLoader: ArtifactPDFPreviewLoading {
    let policy: ArtifactPDFPreviewSecurityPolicy
    let inspector: any ArtifactPDFStructureInspecting
    let loadGate: ArtifactPDFLoadGate

    private let fingerprintProvider:
        (URL) throws -> ArtifactPDFFileFingerprint
    private let dataReader: (URL) throws -> Data

    init(
        policy: ArtifactPDFPreviewSecurityPolicy = .init(),
        inspector: (any ArtifactPDFStructureInspecting)? = nil,
        loadGate: ArtifactPDFLoadGate = .shared,
        fingerprintProvider: @escaping
            (URL) throws -> ArtifactPDFFileFingerprint =
                ArtifactPDFPreviewLoader.defaultFingerprint,
        dataReader: @escaping (URL) throws -> Data = {
            try Data(contentsOf: $0, options: .uncached)
        }
    ) {
        self.policy = policy
        self.inspector = inspector
            ?? ArtifactPDFStructureInspector(policy: policy)
        self.loadGate = loadGate
        self.fingerprintProvider = fingerprintProvider
        self.dataReader = dataReader
    }

    func load(
        reference: ArtifactReviewLocalFileReference
    ) async throws -> ArtifactPDFPreviewLoadResult {
        do {
            return try await loadGate.perform {
                try loadSynchronously(reference: reference)
            }
        } catch is CancellationError {
            throw ArtifactPDFPreviewError.cancelled
        }
    }

    private func loadSynchronously(
        reference: ArtifactReviewLocalFileReference
    ) throws -> ArtifactPDFPreviewLoadResult {
        try Task.checkCancellation()
        let url = reference.url
        guard url.isFileURL else {
            throw ArtifactPDFPreviewError.unreadableFile
        }
        try validateDeclaredPDF(reference.mediaType)

        let didAccessSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let initialFingerprint = try fingerprintProvider(url)
        try policy.validateFileSize(initialFingerprint.fileSize)
        try Task.checkCancellation()

        let data: Data
        do {
            data = try dataReader(url)
        } catch {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ArtifactPDFPreviewError.missingFile
            }
            throw ArtifactPDFPreviewError.unreadableFile
        }
        guard Int64(data.count) == initialFingerprint.fileSize else {
            throw ArtifactPDFPreviewError.changedFile
        }
        try Task.checkCancellation()

        let inspection = try inspector.inspect(
            data: data,
            fileSize: initialFingerprint.fileSize
        )
        let finalFingerprint = try fingerprintProvider(url)
        guard finalFingerprint == initialFingerprint else {
            throw ArtifactPDFPreviewError.changedFile
        }
        try Task.checkCancellation()

        return ArtifactPDFPreviewLoadResult(
            data: data,
            metadata: inspection.metadata
        )
    }

    static func defaultFingerprint(
        for url: URL
    ) throws -> ArtifactPDFFileFingerprint {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ArtifactPDFPreviewError.missingFile
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
                throw ArtifactPDFPreviewError.unreadableFile
            }
            return ArtifactPDFFileFingerprint(
                fileSize: fileSize64,
                modificationDate: values.contentModificationDate,
                resourceIdentifier: values.fileResourceIdentifier.map {
                    String(reflecting: $0)
                }
            )
        } catch let error as ArtifactPDFPreviewError {
            throw error
        } catch {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ArtifactPDFPreviewError.missingFile
            }
            throw ArtifactPDFPreviewError.unreadableFile
        }
    }

    private func validateDeclaredPDF(
        _ mediaType: ArtifactReviewMediaType
    ) throws {
        var hasPDFDeclaration = false

        if let identifier = mediaType.uniformTypeIdentifier,
           let type = UTType(identifier) {
            guard type.conforms(to: .pdf) else {
                throw ArtifactPDFPreviewError.declaredFormatMismatch
            }
            hasPDFDeclaration = true
        }
        if let mimeType = mediaType.mimeType?.lowercased() {
            guard mimeType == "application/pdf" else {
                throw ArtifactPDFPreviewError.declaredFormatMismatch
            }
            hasPDFDeclaration = true
        }
        if let fileExtension = mediaType.fileExtension?.lowercased(),
           !fileExtension.isEmpty {
            guard fileExtension == "pdf" else {
                throw ArtifactPDFPreviewError.declaredFormatMismatch
            }
            hasPDFDeclaration = true
        }

        switch mediaType.legacyArtifactType {
        case .pdf:
            hasPDFDeclaration = true
        case .figma, .url, .other:
            break
        default:
            throw ArtifactPDFPreviewError.declaredFormatMismatch
        }

        guard hasPDFDeclaration else {
            throw ArtifactPDFPreviewError.declaredFormatMismatch
        }
    }
}
