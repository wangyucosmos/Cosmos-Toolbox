import Foundation
import CryptoKit
import Darwin


// MARK: - Testable Export Checkpoints

enum ZhuowangArtifactDeliveryCheckpoint:
    Equatable {

    case afterSourceHash
    case afterCopies
    case afterArchive
    case beforePublish
}


// MARK: - Delivery Package Service

struct ZhuowangArtifactDeliveryPackageService {

    typealias SnapshotProvider =
        () -> ZhuowangArtifactDeliverySnapshot

    typealias CheckpointHandler = (
        ZhuowangArtifactDeliveryCheckpoint,
        URL
    ) throws -> Void

    private let fileManager: FileManager
    private let archiveExecutableURL: URL
    private let now: () -> Date
    private let checkpointHandler:
        CheckpointHandler?

    init(
        fileManager: FileManager = .default,
        archiveExecutableURL: URL = URL(
            fileURLWithPath: "/usr/bin/ditto"
        ),
        now: @escaping () -> Date = Date.init,
        checkpointHandler:
            CheckpointHandler? = nil
    ) {
        self.fileManager = fileManager
        self.archiveExecutableURL = archiveExecutableURL
        self.now = now
        self.checkpointHandler = checkpointHandler
    }


    // MARK: Candidate Evaluation

    func candidates(
        snapshot: ZhuowangArtifactDeliverySnapshot,
        campaignWorkspaceURL: URL
    ) -> [ZhuowangArtifactDeliveryCandidate] {

        let grouped = Dictionary(
            grouping: snapshot.artifacts.filter {
                $0.campaignID == snapshot.campaignID
            },
            by: \.versionGroupKey
        )

        return grouped.map { groupKey, artifacts in
            makeCandidate(
                groupKey: groupKey,
                artifacts: artifacts,
                steps: snapshot.steps,
                campaignWorkspaceURL:
                    campaignWorkspaceURL
            )
        }
        .sorted {
            if $0.stepSortOrder
                != $1.stepSortOrder {
                return $0.stepSortOrder
                    < $1.stepSortOrder
            }

            return $0.name.localizedStandardCompare(
                $1.name
            ) == .orderedAscending
        }
    }


    // MARK: Export

    func export(
        request: ZhuowangArtifactDeliveryRequest,
        snapshotProvider: SnapshotProvider
    ) throws -> ZhuowangArtifactDeliveryResult {

        guard !request.selections.isEmpty else {
            throw ZhuowangArtifactDeliveryError.noSelection
        }

        try validateDestination(
            request.destinationURL
        )

        // This provider is intentionally invoked only at export time. The
        // selection UI may be stale; the service always re-reads Store state
        // before it trusts an adopted version.
        let liveSnapshot = snapshotProvider()

        guard liveSnapshot.campaignID
            == request.campaign.id else {
            throw ZhuowangArtifactDeliveryError
                .campaignChanged
        }

        let liveCandidates = candidates(
            snapshot: liveSnapshot,
            campaignWorkspaceURL:
                request.campaignWorkspaceURL
        )

        let candidateByGroup = Dictionary(
            uniqueKeysWithValues:
                liveCandidates.map {
                    ($0.groupKey, $0)
                }
        )

        var selectedArtifacts: [
            (
                artifact: ZhuowangArtifact,
                step: ZhuowangWorkflowStep?
            )
        ] = []

        for selection in request.selections.sorted(
            by: {
                $0.groupKey < $1.groupKey
            }
        ) {

            let groupKey = selection.groupKey

            guard let candidate =
                candidateByGroup[groupKey]
            else {
                throw ZhuowangArtifactDeliveryError
                    .selectionNoLongerAvailable(
                        groupKey,
                        "逻辑产物已不存在"
                    )
            }

            guard candidate.isEligible,
                  let artifactID = candidate.artifactID,
                  artifactID == selection.artifactID,
                  let artifact = liveSnapshot.artifacts
                    .first(where: {
                        $0.id == artifactID
                    })
            else {
                throw ZhuowangArtifactDeliveryError
                    .selectionNoLongerAvailable(
                        candidate.name,
                        candidate.isEligible
                            ? "采用版本已变化"
                            : candidate.unavailableReason?
                                .title
                                ?? "采用状态已变化"
                    )
            }

            let step = artifact.stepID.flatMap {
                stepID in

                liveSnapshot.steps.first {
                    $0.id == stepID
                }
            }

            selectedArtifacts.append(
                (artifact, step)
            )
        }

        selectedArtifacts.sort {
            let leftOrder =
                $0.step?.sortOrder
                ?? Int.max
            let rightOrder =
                $1.step?.sortOrder
                ?? Int.max

            if leftOrder != rightOrder {
                return leftOrder < rightOrder
            }

            return $0.artifact.name
                .localizedStandardCompare(
                    $1.artifact.name
                ) == .orderedAscending
        }

        return try buildAndPublishArchive(
            request: request,
            selectedArtifacts:
                selectedArtifacts
        )
    }


    // MARK: Candidate Construction

    private func makeCandidate(
        groupKey: String,
        artifacts: [ZhuowangArtifact],
        steps: [ZhuowangWorkflowStep],
        campaignWorkspaceURL: URL
    ) -> ZhuowangArtifactDeliveryCandidate {

        let sortedVersions = artifacts.sorted {
            $0.version > $1.version
        }

        let approved = sortedVersions.filter {
            $0.isApprovedVersion
        }

        let fallbackName = sortedVersions.first?
            .name
            ?? groupKey

        guard approved.count == 1,
              let artifact = approved.first
        else {
            let fallbackStep = sortedVersions.first?
                .stepID.flatMap { stepID in
                    steps.first { $0.id == stepID }
                }

            return ZhuowangArtifactDeliveryCandidate(
                groupKey: groupKey,
                artifactID: nil,
                name: fallbackName,
                stepTitle:
                    fallbackStep?.title
                    ?? "未关联",
                stepSortOrder:
                    fallbackStep?.sortOrder
                    ?? Int.max,
                version: nil,
                fileName: nil,
                unavailableReason:
                    approved.isEmpty
                    ? .noAdoptedVersion
                    : .multipleAdoptedVersions
            )
        }

        let step = artifact.stepID.flatMap {
            stepID in

            steps.first {
                $0.id == stepID
            }
        }

        let unavailableReason: ZhuowangArtifactDeliveryUnavailableReason?
        let sourceURL: URL?

        do {
            sourceURL = try validatedSourceURL(
                for: artifact,
                campaignWorkspaceURL:
                    campaignWorkspaceURL
            )
            unavailableReason = nil
        } catch let reason as ZhuowangArtifactDeliveryUnavailableReasonError {
            sourceURL = nil
            unavailableReason = reason.reason
        } catch {
            sourceURL = nil
            unavailableReason = .unreadableFile
        }

        return ZhuowangArtifactDeliveryCandidate(
            groupKey: groupKey,
            artifactID:
                unavailableReason == nil
                ? artifact.id
                : nil,
            name: artifact.name,
            stepTitle:
                step?.title
                ?? "未关联",
            stepSortOrder:
                step?.sortOrder
                ?? Int.max,
            version: artifact.version,
            fileName:
                sourceURL?.lastPathComponent,
            unavailableReason:
                unavailableReason
        )
    }


    // MARK: Archive Transaction

    private func buildAndPublishArchive(
        request: ZhuowangArtifactDeliveryRequest,
        selectedArtifacts: [(
            artifact: ZhuowangArtifact,
            step: ZhuowangWorkflowStep?
        )]
    ) throws -> ZhuowangArtifactDeliveryResult {

        let parentURL = request.destinationURL
            .deletingLastPathComponent()

        let transactionURL = parentURL
            .appendingPathComponent(
                ".cosmos-delivery-\(UUID().uuidString)",
                isDirectory: true
            )

        let stagingURL = transactionURL
            .appendingPathComponent(
                "package",
                isDirectory: true
            )

        let verificationURL = transactionURL
            .appendingPathComponent(
                "verification",
                isDirectory: true
            )

        let temporaryArchiveURL = transactionURL
            .appendingPathComponent(
                "delivery.zip",
                isDirectory: false
            )

        var createdFinalArchive = false
        var exportSucceeded = false

        defer {
            try? fileManager.removeItem(
                at: transactionURL
            )

            if createdFinalArchive,
               !exportSucceeded {
                try? fileManager.removeItem(
                    at: request.destinationURL
                )
            }
        }

        do {
            try fileManager.createDirectory(
                at: transactionURL,
                withIntermediateDirectories: false
            )

            try fileManager.createDirectory(
                at: stagingURL,
                withIntermediateDirectories: false
            )
        } catch {
            throw ZhuowangArtifactDeliveryError
                .destinationParentUnavailable
        }

        var manifestItems: [
            ZhuowangArtifactDeliveryManifest.Item
        ] = []

        for item in selectedArtifacts {
            let artifact = item.artifact
            let sourceURL: URL

            do {
                sourceURL = try validatedSourceURL(
                    for: artifact,
                    campaignWorkspaceURL:
                        request.campaignWorkspaceURL
                )
            } catch let reason as ZhuowangArtifactDeliveryUnavailableReasonError {
                throw ZhuowangArtifactDeliveryError
                    .selectionNoLongerAvailable(
                        artifact.name,
                        reason.reason.title
                    )
            }

            let before = try fingerprint(
                sourceURL
            )

            try checkpointHandler?(
                .afterSourceHash,
                sourceURL
            )

            let relativePath = try packageRelativePath(
                artifact: artifact,
                step: item.step,
                sourceURL: sourceURL
            )

            let copiedURL = stagingURL
                .appendingPathComponent(
                    relativePath,
                    isDirectory: false
                )

            try fileManager.createDirectory(
                at: copiedURL
                    .deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            do {
                try fileManager.copyItem(
                    at: sourceURL,
                    to: copiedURL
                )
            } catch {
                throw ZhuowangArtifactDeliveryError
                    .copyVerificationFailed(
                        artifact.name
                    )
            }

            let after = try fingerprint(sourceURL)
            guard before == after else {
                throw ZhuowangArtifactDeliveryError
                    .sourceChanged(artifact.name)
            }

            let copied = try fingerprint(copiedURL)
            guard before == copied else {
                throw ZhuowangArtifactDeliveryError
                    .copyVerificationFailed(
                        artifact.name
                    )
            }

            manifestItems.append(
                ZhuowangArtifactDeliveryManifest.Item(
                    step:
                        item.step?.title
                        ?? "未关联",
                    name: artifact.name,
                    artifactID:
                        artifact.id.uuidString,
                    logicalKey:
                        cleanLogicalKey(artifact),
                    version: artifact.version,
                    relativePath: relativePath,
                    byteCount: before.byteCount,
                    sha256: before.sha256
                )
            )
        }

        try checkpointHandler?(
            .afterCopies,
            stagingURL
        )

        let exportDate = now()
        let manifest = ZhuowangArtifactDeliveryManifest(
            schemaVersion: 1,
            campaign: .init(
                id: request.campaign.id.uuidString,
                name: request.campaign.name,
                province:
                    request.provinceName
            ),
            exportedAt:
                Self.iso8601String(exportDate),
            items: manifestItems
        )

        let manifestData = try encodeManifest(
            manifest
        )
        let checklistData = Data(
            deliveryChecklist(
                manifest: manifest
            ).utf8
        )

        let manifestURL = stagingURL
            .appendingPathComponent("manifest.json")
        let checklistURL = stagingURL
            .appendingPathComponent("交付清单.md")

        try manifestData.write(
            to: manifestURL,
            options: .atomic
        )
        try checklistData.write(
            to: checklistURL,
            options: .atomic
        )

        try createArchive(
            sourceDirectory: stagingURL,
            archiveURL: temporaryArchiveURL
        )

        try checkpointHandler?(
            .afterArchive,
            temporaryArchiveURL
        )

        try verifyArchive(
            archiveURL: temporaryArchiveURL,
            verificationURL: verificationURL,
            manifestItems: manifestItems,
            manifestData: manifestData,
            checklistData: checklistData
        )

        let archiveFingerprint = try fingerprint(
            temporaryArchiveURL
        )

        try checkpointHandler?(
            .beforePublish,
            request.destinationURL
        )

        guard !fileManager.fileExists(
            atPath: request.destinationURL.path
        ) else {
            throw ZhuowangArtifactDeliveryError
                .destinationAlreadyExists
        }

        do {
            try fileManager.moveItem(
                at: temporaryArchiveURL,
                to: request.destinationURL
            )
            createdFinalArchive = true
        } catch {
            if fileManager.fileExists(
                atPath: request.destinationURL.path
            ) {
                throw ZhuowangArtifactDeliveryError
                    .destinationAlreadyExists
            }

            throw ZhuowangArtifactDeliveryError
                .publishFailed
        }

        let finalFingerprint = try fingerprint(
            request.destinationURL
        )

        guard finalFingerprint
            == archiveFingerprint else {
            throw ZhuowangArtifactDeliveryError
                .publishFailed
        }

        exportSucceeded = true

        return ZhuowangArtifactDeliveryResult(
            archiveURL: request.destinationURL,
            manifest: manifest
        )
    }


    // MARK: Source Validation

    private func validatedSourceURL(
        for artifact: ZhuowangArtifact,
        campaignWorkspaceURL: URL
    ) throws -> URL {

        if artifact.type == .url
            || artifact.type == .figma {
            throw ZhuowangArtifactDeliveryUnavailableReasonError(
                .externalReference
            )
        }

        let location = artifact.location
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !location.isEmpty else {
            throw ZhuowangArtifactDeliveryUnavailableReasonError(
                .missingLocation
            )
        }

        guard (location as NSString)
            .isAbsolutePath else {
            throw ZhuowangArtifactDeliveryUnavailableReasonError(
                .relativeSourcePath
            )
        }

        guard !(location as NSString).pathComponents
            .contains("..") else {
            throw ZhuowangArtifactDeliveryUnavailableReasonError(
                .outsideCampaignWorkspace
            )
        }

        let workspaceURL = campaignWorkspaceURL
            .standardizedFileURL
        let sourceURL = URL(
            fileURLWithPath: location,
            isDirectory: false
        )
        .standardizedFileURL

        guard fileManager.fileExists(
            atPath: workspaceURL.path
        ) else {
            throw ZhuowangArtifactDeliveryUnavailableReasonError(
                .workspaceUnavailable
            )
        }

        guard fileManager.fileExists(
            atPath: sourceURL.path
        ) else {
            throw ZhuowangArtifactDeliveryUnavailableReasonError(
                .missingFile
            )
        }

        do {
            try validateWorkspaceAncestry(
                from: workspaceURL,
                through: sourceURL
            )
        } catch let reason as ZhuowangArtifactDeliveryUnavailableReasonError {
            throw reason
        } catch {
            throw ZhuowangArtifactDeliveryUnavailableReasonError(
                .unreadableFile
            )
        }

        do {
            let values = try sourceURL.resourceValues(
                forKeys: [
                    .isRegularFileKey,
                    .isReadableKey,
                    .isSymbolicLinkKey
                ]
            )

            guard values.isSymbolicLink != true else {
                throw ZhuowangArtifactDeliveryUnavailableReasonError(
                    .symbolicLink
                )
            }

            guard values.isRegularFile == true else {
                throw ZhuowangArtifactDeliveryUnavailableReasonError(
                    .notRegularFile
                )
            }

            guard values.isReadable == true else {
                throw ZhuowangArtifactDeliveryUnavailableReasonError(
                    .unreadableFile
                )
            }
        } catch let reason as ZhuowangArtifactDeliveryUnavailableReasonError {
            throw reason
        } catch {
            throw ZhuowangArtifactDeliveryUnavailableReasonError(
                .unreadableFile
            )
        }

        return sourceURL
    }


    private func validateWorkspaceAncestry(
        from rootURL: URL,
        through sourceURL: URL
    ) throws {
        func status(_ url: URL) throws -> stat {
            var value = stat()
            guard lstat(url.path, &value) == 0 else {
                throw ZhuowangArtifactDeliveryUnavailableReasonError(
                    .unreadableFile
                )
            }
            return value
        }

        let root = try status(rootURL)
        guard root.st_mode & S_IFMT != S_IFLNK else {
            throw ZhuowangArtifactDeliveryUnavailableReasonError(
                .symbolicLink
            )
        }
        guard root.st_mode & S_IFMT == S_IFDIR else {
            throw ZhuowangArtifactDeliveryUnavailableReasonError(
                .workspaceUnavailable
            )
        }

        // Directory identity follows the mounted filesystem's case and
        // Unicode semantics without treating distinct case-sensitive paths
        // as aliases. Inspect the original ancestry to reject symlinks.
        let source = try status(sourceURL)
        var hasSymbolicLink = source.st_mode & S_IFMT == S_IFLNK
        var current = sourceURL.deletingLastPathComponent()
        while true {
            let ancestor = try status(current)
            hasSymbolicLink = hasSymbolicLink
                || ancestor.st_mode & S_IFMT == S_IFLNK
            if ancestor.st_dev == root.st_dev,
               ancestor.st_ino == root.st_ino {
                guard !hasSymbolicLink else {
                    throw ZhuowangArtifactDeliveryUnavailableReasonError(
                        .symbolicLink
                    )
                }
                return
            }
            let parent = current.deletingLastPathComponent()
            guard parent.path != current.path else {
                throw ZhuowangArtifactDeliveryUnavailableReasonError(
                    .outsideCampaignWorkspace
                )
            }
            current = parent
        }
    }


    // MARK: Package Paths

    private func packageRelativePath(
        artifact: ZhuowangArtifact,
        step: ZhuowangWorkflowStep?,
        sourceURL: URL
    ) throws -> String {

        let stepFolder = Self.stepFolder(
            step
        )
        let safeFileName = Self.safeFileName(
            sourceURL.lastPathComponent
        )

        let relativePath = [
            "Files",
            stepFolder,
            artifact.id.uuidString,
            safeFileName
        ]
        .joined(separator: "/")

        guard Self.isSafeArchiveRelativePath(
            relativePath
        ) else {
            throw ZhuowangArtifactDeliveryError
                .unsafeArchivePath
        }

        return relativePath
    }


    private static func stepFolder(
        _ step: ZhuowangWorkflowStep?
    ) -> String {

        guard let step else {
            return "99_未关联"
        }

        switch step.kind {
        case .brief:
            return "01_需求整理"
        case .idea:
            return "02_策划思路"
        case .plan:
            return "03_完整策划案"
        case .pageStructure:
            return "04_页面结构"
        case .prototype:
            return "05_产品原型"
        case .customerService:
            return "06_客服文档"
        case .prompt:
            return "90_Prompt"
        case .flowchart:
            return "91_流程图"
        case .asset:
            return "92_素材"
        case .review:
            return "93_评审"
        case .custom:
            return "99_自定义"
        }
    }


    private static func safeFileName(
        _ original: String
    ) -> String {

        let trimmed = original.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let invalid = CharacterSet(
            charactersIn: "/\\:\0"
        )

        let pieces = trimmed.components(
            separatedBy: invalid
        )

        let candidate = pieces
            .filter { !$0.isEmpty }
            .joined(separator: "_")

        if candidate.isEmpty
            || candidate == "."
            || candidate == ".."
            || candidate.hasPrefix(".") {
            return "artifact"
        }

        return candidate
    }


    private static func isSafeArchiveRelativePath(
        _ path: String
    ) -> Bool {

        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\\")
        else {
            return false
        }

        let components = path.split(
            separator: "/",
            omittingEmptySubsequences: false
        )

        return !components.isEmpty
            && components.allSatisfy {
                !$0.isEmpty
                    && $0 != "."
                    && $0 != ".."
            }
    }


    // MARK: Manifest / Checklist

    private func encodeManifest(
        _ manifest: ZhuowangArtifactDeliveryManifest
    ) throws -> Data {

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]

        return try encoder.encode(manifest)
    }


    private func deliveryChecklist(
        manifest: ZhuowangArtifactDeliveryManifest
    ) -> String {

        var lines = [
            "# 交付清单",
            "",
            "- Campaign：\(manifest.campaign.name)",
            "- Campaign ID：\(manifest.campaign.id)",
            "- 省份：\(manifest.campaign.province ?? "未记录")",
            "- 导出时间：\(manifest.exportedAt)",
            "- 文件数量：\(manifest.items.count)",
            "",
            "## 文件",
            ""
        ]

        for (index, item) in manifest
            .items.enumerated() {

            lines.append("### \(index + 1). \(item.name) V\(item.version)")
            lines.append("")
            lines.append("- 步骤：\(item.step)")
            lines.append("- Artifact ID：\(item.artifactID)")
            lines.append("- 逻辑键：\(item.logicalKey)")
            lines.append("- 包内路径：\(item.relativePath)")
            lines.append("- 字节数：\(item.byteCount)")
            lines.append("- SHA-256：\(item.sha256)")
            lines.append("")
        }

        return lines.joined(separator: "\n")
            + "\n"
    }


    private func cleanLogicalKey(
        _ artifact: ZhuowangArtifact
    ) -> String {

        let value = artifact.logicalKey?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            ?? ""

        return value.isEmpty
            ? artifact.versionGroupKey
            : value
    }


    // MARK: ZIP Creation / Verification

    private func createArchive(
        sourceDirectory: URL,
        archiveURL: URL
    ) throws {

        guard fileManager.isExecutableFile(
            atPath: archiveExecutableURL.path
        ) else {
            throw ZhuowangArtifactDeliveryError
                .archiveToolUnavailable
        }

        try runArchiveTool(
            arguments: [
                "-c",
                "-k",
                "--norsrc",
                "--noextattr",
                sourceDirectory.path + "/",
                archiveURL.path
            ],
            failure:
                .archiveCreationFailed
        )

        try normalizeZIPUTF8Flags(at: archiveURL)
    }


    // ditto writes UTF-8 names without bit 11. Validate both records before
    // changing only their flags, leaving compressed bytes and offsets intact.
    func normalizeZIPUTF8Flags(at archiveURL: URL) throws {
        let handle = try FileHandle(forUpdating: archiveURL)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()

        func read(_ offset: UInt64, _ count: Int) throws -> Data {
            guard offset <= size, UInt64(count) <= size - offset else {
                throw ZhuowangArtifactDeliveryError.archiveVerificationFailed
            }
            try handle.seek(toOffset: offset)
            let data = try handle.read(upToCount: count) ?? Data()
            guard data.count == count else {
                throw ZhuowangArtifactDeliveryError.archiveVerificationFailed
            }
            return data
        }
        func number(_ data: Data, _ offset: Int, _ count: Int) -> UInt64 {
            (0..<count).reduce(UInt64(0)) {
                $0 | UInt64(data[offset + $1]) << ($1 * 8)
            }
        }
        func rejectUnless(_ condition: Bool) throws {
            guard condition else {
                throw ZhuowangArtifactDeliveryError.archiveVerificationFailed
            }
        }

        try rejectUnless(size >= 22)
        let tailSize = Int(min(size, 65_557))
        let tail = try read(size - UInt64(tailSize), tailSize)
        let endIndex = stride(from: tailSize - 22, through: 0, by: -1).first {
            number(tail, $0, 4) == 0x06054b50
                && $0 + 22 + Int(number(tail, $0 + 20, 2)) == tailSize
        }
        guard let endIndex else {
            throw ZhuowangArtifactDeliveryError.archiveVerificationFailed
        }
        let endOffset = size - UInt64(tailSize) + UInt64(endIndex)
        try rejectUnless(number(tail, endIndex + 4, 2) == 0
            && number(tail, endIndex + 6, 2) == 0
            && number(tail, endIndex + 8, 2) == number(tail, endIndex + 10, 2))
        var count = number(tail, endIndex + 10, 2)
        var centralSize = number(tail, endIndex + 12, 4)
        var centralOffset = number(tail, endIndex + 16, 4)
        if count == 0xffff || centralSize == 0xffffffff || centralOffset == 0xffffffff {
            try rejectUnless(endOffset >= 20)
            let locator = try read(endOffset - 20, 20)
            try rejectUnless(number(locator, 0, 4) == 0x07064b50
                && number(locator, 4, 4) == 0 && number(locator, 16, 4) == 1)
            let zip64 = try read(number(locator, 8, 8), 56)
            try rejectUnless(number(zip64, 0, 4) == 0x06064b50
                && number(zip64, 4, 8) >= 44
                && number(zip64, 16, 4) == 0 && number(zip64, 20, 4) == 0
                && number(zip64, 24, 8) == number(zip64, 32, 8))
            count = number(zip64, 32, 8)
            centralSize = number(zip64, 40, 8)
            centralOffset = number(zip64, 48, 8)
        }
        try rejectUnless(centralOffset <= endOffset
            && centralSize <= endOffset - centralOffset
            && count <= centralSize / 46)
        let centralEnd = centralOffset + centralSize
        var cursor = centralOffset
        var patches: [(UInt64, UInt16)] = []
        var seenLocalOffsets = Set<UInt64>()

        for _ in 0..<count {
            try rejectUnless(cursor <= centralEnd && centralEnd - cursor >= 46)
            let header = try read(cursor, 46)
            try rejectUnless(number(header, 0, 4) == 0x02014b50)
            let flags = UInt16(number(header, 8, 2))
            let nameSize = Int(number(header, 28, 2))
            let extraSize = Int(number(header, 30, 2))
            let commentSize = Int(number(header, 32, 2))
            let recordSize = 46 + nameSize + extraSize + commentSize
            try rejectUnless(UInt64(recordSize) <= centralEnd - cursor
                && flags & 1 == 0 && number(header, 34, 2) == 0)
            let name = try read(cursor + 46, nameSize)
            let comment = try read(cursor + UInt64(46 + nameSize + extraSize), commentSize)
            try rejectUnless(!name.isEmpty && !name.contains(0)
                && String(data: name, encoding: .utf8) != nil
                && String(data: comment, encoding: .utf8) != nil)

            var localOffset = number(header, 42, 4)
            if localOffset == 0xffffffff {
                let extra = try read(cursor + UInt64(46 + nameSize), extraSize)
                var extraCursor = 0
                var foundOffset = false
                while extraCursor + 4 <= extra.count {
                    let tag = number(extra, extraCursor, 2)
                    let length = Int(number(extra, extraCursor + 2, 2))
                    try rejectUnless(length <= extra.count - extraCursor - 4)
                    if tag == 1 {
                        var index = extraCursor + 4
                        if number(header, 24, 4) == 0xffffffff { index += 8 }
                        if number(header, 20, 4) == 0xffffffff { index += 8 }
                        try rejectUnless(index + 8 <= extraCursor + 4 + length)
                        localOffset = number(extra, index, 8)
                        foundOffset = true
                        break
                    }
                    extraCursor += 4 + length
                }
                try rejectUnless(foundOffset)
            }
            try rejectUnless(localOffset < centralOffset
                && centralOffset - localOffset >= 30
                && seenLocalOffsets.insert(localOffset).inserted)
            let local = try read(localOffset, 30)
            try rejectUnless(number(local, 0, 4) == 0x04034b50
                && number(local, 6, 2) == UInt64(flags)
                && number(local, 8, 2) == number(header, 10, 2)
                && number(local, 26, 2) == UInt64(nameSize))
            let localName = try read(localOffset + 30, nameSize)
            try rejectUnless(localName == name)
            patches.append((localOffset + 6, flags | 0x0800))
            patches.append((cursor + 8, flags | 0x0800))
            cursor += UInt64(recordSize)
        }
        try rejectUnless(cursor == centralEnd)

        // No writes occur until every name and paired header is validated.
        for (offset, flags) in patches {
            try handle.seek(toOffset: offset)
            try handle.write(contentsOf: Data([
                UInt8(flags & 0xff), UInt8(flags >> 8)
            ]))
        }
        try handle.synchronize()
    }


    private func verifyArchive(
        archiveURL: URL,
        verificationURL: URL,
        manifestItems: [
            ZhuowangArtifactDeliveryManifest.Item
        ],
        manifestData: Data,
        checklistData: Data
    ) throws {

        do {
            try fileManager.createDirectory(
                at: verificationURL,
                withIntermediateDirectories: false
            )

            try runArchiveTool(
                arguments: [
                    "-x",
                    "-k",
                    archiveURL.path,
                    verificationURL.path
                ],
                failure:
                    .archiveVerificationFailed
            )

            let expectedPaths = Set(
                manifestItems.map {
                    Self.normalizedArchivePath(
                        $0.relativePath
                    )
                }
                    + [
                        "manifest.json",
                        "交付清单.md"
                    ]
            )

            let actualPaths = try regularFilePaths(
                under: verificationURL
            )

            guard actualPaths == expectedPaths else {
                throw ZhuowangArtifactDeliveryError
                    .archiveVerificationFailed
            }

            for item in manifestItems {
                guard Self.isSafeArchiveRelativePath(
                    item.relativePath
                ) else {
                    throw ZhuowangArtifactDeliveryError
                        .archiveVerificationFailed
                }

                let extractedURL = verificationURL
                    .appendingPathComponent(
                        item.relativePath
                    )

                let extracted = try fingerprint(
                    extractedURL
                )

                guard extracted.byteCount
                        == item.byteCount,
                      extracted.sha256
                        == item.sha256
                else {
                    throw ZhuowangArtifactDeliveryError
                        .archiveVerificationFailed
                }
            }

            let extractedManifest = try Data(
                contentsOf: verificationURL
                    .appendingPathComponent(
                        "manifest.json"
                    )
            )
            let extractedChecklist = try Data(
                contentsOf: verificationURL
                    .appendingPathComponent(
                        "交付清单.md"
                    )
            )

            guard extractedManifest == manifestData,
                  extractedChecklist == checklistData
            else {
                throw ZhuowangArtifactDeliveryError
                    .archiveVerificationFailed
            }
        } catch let error as ZhuowangArtifactDeliveryError {
            throw error
        } catch {
            throw ZhuowangArtifactDeliveryError
                .archiveVerificationFailed
        }
    }


    private func regularFilePaths(
        under rootURL: URL
    ) throws -> Set<String> {

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isDirectoryKey,
                .isSymbolicLinkKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            throw ZhuowangArtifactDeliveryError
                .archiveVerificationFailed
        }

        var paths = Set<String>()
        let canonicalRoot = try Self
            .canonicalExistingURL(rootURL)

        for case let url as URL in enumerator {
            let values = try url.resourceValues(
                forKeys: [
                    .isRegularFileKey,
                    .isDirectoryKey,
                    .isSymbolicLinkKey
                ]
            )

            if values.isSymbolicLink == true {
                throw ZhuowangArtifactDeliveryError
                    .archiveVerificationFailed
            }

            if values.isDirectory == true {
                continue
            }

            guard values.isRegularFile == true else {
                throw ZhuowangArtifactDeliveryError
                    .archiveVerificationFailed
            }

            let canonicalURL = try Self
                .canonicalExistingURL(url)

            guard Self.isWithin(
                canonicalURL,
                root: canonicalRoot,
                allowRoot: false
            ) else {
                throw ZhuowangArtifactDeliveryError
                    .archiveVerificationFailed
            }

            let suffix = canonicalURL.path.dropFirst(
                canonicalRoot.path.count
            )

            guard suffix.first == "/" else {
                throw ZhuowangArtifactDeliveryError
                    .archiveVerificationFailed
            }

            let relative = Self.normalizedArchivePath(
                String(suffix.dropFirst())
            )

            guard Self.isSafeArchiveRelativePath(
                relative
            ) else {
                throw ZhuowangArtifactDeliveryError
                    .archiveVerificationFailed
            }

            paths.insert(relative)
        }

        return paths
    }


    private static func normalizedArchivePath(
        _ path: String
    ) -> String {
        path.precomposedStringWithCanonicalMapping
    }


    private func runArchiveTool(
        arguments: [String],
        failure: ZhuowangArtifactDeliveryError
    ) throws {

        let process = Process()
        process.executableURL = archiveExecutableURL
        process.arguments = arguments

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw failure
        }

        guard process.terminationStatus == 0 else {
            throw failure
        }
    }


    // MARK: Fingerprints

    private struct FileFingerprint:
        Equatable {

        let byteCount: UInt64
        let sha256: String
    }


    private func fingerprint(
        _ fileURL: URL
    ) throws -> FileFingerprint {

        let handle: FileHandle

        do {
            handle = try FileHandle(
                forReadingFrom: fileURL
            )
        } catch {
            throw ZhuowangArtifactDeliveryError
                .archiveVerificationFailed
        }

        defer {
            try? handle.close()
        }

        var digest = SHA256()
        var byteCount: UInt64 = 0

        while true {
            let data: Data

            do {
                data = try handle.read(
                    upToCount: 1_048_576
                ) ?? Data()
            } catch {
                throw ZhuowangArtifactDeliveryError
                    .archiveVerificationFailed
            }

            guard !data.isEmpty else {
                break
            }

            byteCount += UInt64(data.count)
            digest.update(data: data)
        }

        let hash = digest.finalize()
            .map {
                String(
                    format: "%02x",
                    $0
                )
            }
            .joined()

        return FileFingerprint(
            byteCount: byteCount,
            sha256: hash
        )
    }


    // MARK: Destination Validation

    private func validateDestination(
        _ destinationURL: URL
    ) throws {

        guard destinationURL.isFileURL,
              destinationURL.pathExtension
                .lowercased() == "zip",
              (destinationURL.path as NSString)
                .isAbsolutePath
        else {
            throw ZhuowangArtifactDeliveryError
                .invalidDestination
        }

        guard !fileManager.fileExists(
            atPath: destinationURL.path
        ) else {
            throw ZhuowangArtifactDeliveryError
                .destinationAlreadyExists
        }

        let parentURL = destinationURL
            .deletingLastPathComponent()

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(
            atPath: parentURL.path,
            isDirectory: &isDirectory
        ),
        isDirectory.boolValue else {
            throw ZhuowangArtifactDeliveryError
                .destinationParentUnavailable
        }
    }


    // MARK: Utilities

    private static func canonicalExistingURL(
        _ url: URL
    ) throws -> URL {

        guard let pointer = realpath(
            url.path,
            nil
        ) else {
            throw ZhuowangArtifactDeliveryError
                .archiveVerificationFailed
        }

        defer {
            free(pointer)
        }

        return URL(
            fileURLWithPath:
                String(cString: pointer)
        )
    }


    private static func isWithin(
        _ url: URL,
        root: URL,
        allowRoot: Bool
    ) -> Bool {

        if allowRoot,
           url.path == root.path {
            return true
        }

        return url.path.hasPrefix(
            root.path + "/"
        )
    }


    private static func iso8601String(
        _ date: Date
    ) -> String {

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter.string(
            from: date
        )
    }
}


// MARK: - Internal Validation Error

private struct ZhuowangArtifactDeliveryUnavailableReasonError:
    Error {

    let reason:
        ZhuowangArtifactDeliveryUnavailableReason

    init(
        _ reason:
            ZhuowangArtifactDeliveryUnavailableReason
    ) {
        self.reason = reason
    }
}
