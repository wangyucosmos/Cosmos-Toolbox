import Foundation

final class ZhuowangWorkspaceFileManager {

    static let shared =
        ZhuowangWorkspaceFileManager()

    private let fileManager =
        FileManager.default

    private init() { }


    // MARK: - Root

    var cosmosRootURL: URL {

        let documentsURL =
            fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]

        return documentsURL
            .appendingPathComponent(
                "Cosmos OS",
                isDirectory: true
            )
    }


    var workspacesRootURL: URL {

        cosmosRootURL
            .appendingPathComponent(
                "Workspaces",
                isDirectory: true
            )
    }


    var zhuowangRootURL: URL {

        workspacesRootURL
            .appendingPathComponent(
                "卓望",
                isDirectory: true
            )
    }


    // MARK: - Campaign Directory

    func campaignDirectoryURL(
        provinceName: String?,
        campaignName: String
    ) -> URL {

        let safeCampaignName =
            sanitizedPathComponent(
                campaignName
            )

        if let provinceName,
           !provinceName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty {

            let safeProvinceName =
                sanitizedPathComponent(
                    provinceName
                )

            return zhuowangRootURL
                .appendingPathComponent(
                    safeProvinceName,
                    isDirectory: true
                )
                .appendingPathComponent(
                    safeCampaignName,
                    isDirectory: true
                )
        }

        return zhuowangRootURL
            .appendingPathComponent(
                "全国及其他",
                isDirectory: true
            )
            .appendingPathComponent(
                safeCampaignName,
                isDirectory: true
            )
    }


    // MARK: - Workflow Directories

    func briefDirectoryURL(
        provinceName: String?,
        campaignName: String
    ) -> URL {

        campaignDirectoryURL(
            provinceName:
                provinceName,
            campaignName:
                campaignName
        )
        .appendingPathComponent(
            "01_需求整理",
            isDirectory: true
        )
    }


    func ideaDirectoryURL(
        provinceName: String?,
        campaignName: String
    ) -> URL {

        campaignDirectoryURL(
            provinceName:
                provinceName,
            campaignName:
                campaignName
        )
        .appendingPathComponent(
            "02_策划思路",
            isDirectory: true
        )
    }


    func planDirectoryURL(
        provinceName: String?,
        campaignName: String
    ) -> URL {

        campaignDirectoryURL(
            provinceName:
                provinceName,
            campaignName:
                campaignName
        )
        .appendingPathComponent(
            "03_完整策划案",
            isDirectory: true
        )
    }


    func pageStructureDirectoryURL(
        provinceName: String?,
        campaignName: String
    ) -> URL {

        campaignDirectoryURL(
            provinceName:
                provinceName,
            campaignName:
                campaignName
        )
        .appendingPathComponent(
            "04_页面结构",
            isDirectory: true
        )
    }


    func prototypeDirectoryURL(
        provinceName: String?,
        campaignName: String
    ) -> URL {

        campaignDirectoryURL(
            provinceName:
                provinceName,
            campaignName:
                campaignName
        )
        .appendingPathComponent(
            "05_Figma原型",
            isDirectory: true
        )
    }


    func customerServiceDirectoryURL(
        provinceName: String?,
        campaignName: String
    ) -> URL {

        campaignDirectoryURL(
            provinceName:
                provinceName,
            campaignName:
                campaignName
        )
        .appendingPathComponent(
            "06_客服文档",
            isDirectory: true
        )
    }


    func assetsDirectoryURL(
        provinceName: String?,
        campaignName: String
    ) -> URL {

        campaignDirectoryURL(
            provinceName:
                provinceName,
            campaignName:
                campaignName
        )
        .appendingPathComponent(
            "Assets",
            isDirectory: true
        )
    }


    // MARK: - Directory For Workflow Step

    func directoryURL(
        for stepKind:
            ZhuowangWorkflowStepKind,
        provinceName: String?,
        campaignName: String
    ) -> URL {

        switch stepKind {

        case .brief:
            return briefDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )

        case .idea:
            return ideaDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )

        case .plan:
            return planDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )

        case .pageStructure:
            return pageStructureDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )

        case .prototype:
            return prototypeDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )

        case .customerService:
            return customerServiceDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )

        case .prompt,
             .flowchart,
             .asset,
             .review,
             .custom:

            return assetsDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )
        }
    }


    // MARK: - Create Structure

    @discardableResult
    func createCampaignWorkspace(
        provinceName: String?,
        campaignName: String
    ) throws -> URL {

        let campaignURL =
            campaignDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )

        let directories = [
            campaignURL,
            briefDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            ),
            ideaDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            ),
            planDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            ),
            pageStructureDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            ),
            prototypeDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            ),
            customerServiceDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            ),
            assetsDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )
        ]

        for directory in directories {

            try fileManager
                .createDirectory(
                    at: directory,
                    withIntermediateDirectories:
                        true,
                    attributes:
                        nil
                )
        }

        return campaignURL
    }


    // MARK: - Write Markdown Artifact

    @discardableResult
    func writeMarkdownArtifact(
        provinceName: String?,
        campaignName: String,
        stepKind: ZhuowangWorkflowStepKind,
        artifactName: String,
        version: Int,
        content: String
    ) throws -> URL {

        _ =
            try createCampaignWorkspace(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )

        let cleanContent =
            content.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanContent.isEmpty else {

            throw ZhuowangWorkspaceFileError
                .emptyContent
        }

        let directory =
            directoryURL(
                for: stepKind,
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )

        let safeArtifactName =
            sanitizedPathComponent(
                artifactName
            )

        let fileName =
            "\(safeArtifactName)_V\(version).md"

        let fileURL =
            directory
                .appendingPathComponent(
                    fileName,
                    isDirectory: false
                )

        try cleanContent.write(
            to: fileURL,
            atomically: true,
            encoding: .utf8
        )

        return fileURL
    }


    // MARK: - Discover Existing Local Artifacts

    /// Scans an existing campaign workspace and rebuilds a neutral description
    /// of Markdown artifacts already present on disk.
    ///
    /// This is intentionally read-only. It never renames, rewrites, or deletes
    /// user files. It exists so Cosmos OS can rebuild metadata after a local
    /// database / UserDefaults migration problem.
    func discoverMarkdownArtifacts(
        provinceName: String?,
        campaignName: String
    ) -> [ZhuowangDiscoveredLocalArtifact] {

        let stepKinds: [ZhuowangWorkflowStepKind] = [
            .brief,
            .idea,
            .plan,
            .pageStructure,
            .prototype,
            .customerService
        ]

        var results: [ZhuowangDiscoveredLocalArtifact] = []
        var seenPaths = Set<String>()

        for stepKind in stepKinds {

            for directory in recoveryCandidateDirectories(
                for: stepKind,
                provinceName: provinceName,
                campaignName: campaignName
            ) {

                guard
                    fileManager.fileExists(
                        atPath: directory.path
                    ),
                    let files =
                        try? fileManager.contentsOfDirectory(
                            at: directory,
                            includingPropertiesForKeys: [
                                .contentModificationDateKey
                            ],
                            options: [
                                .skipsHiddenFiles
                            ]
                        )
                else {
                    continue
                }

                for fileURL in files
                    where fileURL.pathExtension
                        .lowercased() == "md" {

                    guard
                        seenPaths.insert(
                            fileURL.path
                        ).inserted,
                        let parsed =
                            parseArtifactFileName(
                                fileURL
                            ),
                        let content =
                            try? String(
                                contentsOf: fileURL,
                                encoding: .utf8
                            )
                    else {
                        continue
                    }

                    let values =
                        try? fileURL.resourceValues(
                            forKeys: [
                                .contentModificationDateKey
                            ]
                        )

                    results.append(
                        ZhuowangDiscoveredLocalArtifact(
                            stepKind: stepKind,
                            artifactName:
                                parsed.name,
                            version:
                                parsed.version,
                            fileURL:
                                fileURL,
                            content:
                                content,
                            modifiedAt:
                                values?
                                    .contentModificationDate
                                ?? Date.distantPast
                        )
                    )
                }
            }
        }

        return results.sorted {

            if $0.stepKind
                != $1.stepKind {

                return recoverySortOrder(
                    for: $0.stepKind
                )
                < recoverySortOrder(
                    for: $1.stepKind
                )
            }

            if $0.artifactName
                != $1.artifactName {

                return $0.artifactName
                    < $1.artifactName
            }

            return $0.version
                < $1.version
        }
    }


    private func recoveryCandidateDirectories(
        for stepKind: ZhuowangWorkflowStepKind,
        provinceName: String?,
        campaignName: String
    ) -> [URL] {

        let canonical =
            directoryURL(
                for: stepKind,
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )

        guard stepKind == .prototype else {
            return [canonical]
        }

        let campaignURL =
            campaignDirectoryURL(
                provinceName:
                    provinceName,
                campaignName:
                    campaignName
            )

        // Keep backward compatibility with the old Figma-specific folder
        // while allowing future generic prototype folder names.
        return [
            canonical,
            campaignURL.appendingPathComponent(
                "05_产品原型",
                isDirectory: true
            ),
            campaignURL.appendingPathComponent(
                "05_原型设计",
                isDirectory: true
            )
        ]
    }


    private func parseArtifactFileName(
        _ fileURL: URL
    ) -> (
        name: String,
        version: Int
    )? {

        let stem =
            fileURL
                .deletingPathExtension()
                .lastPathComponent

        guard
            let versionRange =
                stem.range(
                    of: "_V[0-9]+$",
                    options: .regularExpression
                )
        else {
            return nil
        }

        let versionToken =
            stem[versionRange]

        let numberText =
            versionToken
                .dropFirst(2)

        guard
            let version =
                Int(numberText)
        else {
            return nil
        }

        let rawName =
            String(
                stem[
                    ..<versionRange.lowerBound
                ]
            )

        return (
            displayArtifactName(
                from: rawName
            ),
            version
        )
    }


    private func displayArtifactName(
        from fileStem: String
    ) -> String {

        if fileStem.hasSuffix(
            "_AI采用结果"
        ) {

            let prefix =
                String(
                    fileStem.dropLast(
                        "_AI采用结果".count
                    )
                )

            return "\(prefix) · AI 采用结果"
        }

        return fileStem
            .replacingOccurrences(
                of: "_",
                with: " "
            )
    }


    private func recoverySortOrder(
        for stepKind: ZhuowangWorkflowStepKind
    ) -> Int {

        switch stepKind {

        case .brief:
            return 10

        case .idea:
            return 20

        case .plan:
            return 30

        case .pageStructure:
            return 40

        case .prototype:
            return 50

        case .customerService:
            return 60

        default:
            return 999
        }
    }


    // MARK: - Helpers

    private func sanitizedPathComponent(
        _ value: String
    ) -> String {

        let trimmed =
            value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let forbiddenCharacters =
            CharacterSet(
                charactersIn:
                    "/:\\?%*|\"<>·"
            )

        let components =
            trimmed.components(
                separatedBy:
                    forbiddenCharacters
            )

        let cleaned =
            components
                .joined(
                    separator: "_"
                )
                .replacingOccurrences(
                    of: "__",
                    with: "_"
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        return cleaned.isEmpty
            ? "未命名"
            : cleaned
    }
}


// MARK: - Discovered Local Artifact

struct ZhuowangDiscoveredLocalArtifact {

    let stepKind: ZhuowangWorkflowStepKind
    let artifactName: String
    let version: Int
    let fileURL: URL
    let content: String
    let modifiedAt: Date
}


// MARK: - File Error

enum ZhuowangWorkspaceFileError:
    LocalizedError {

    case emptyContent

    var errorDescription: String? {

        switch self {

        case .emptyContent:
            return "工作产物正文为空，无法保存为 Markdown 文件。"
        }
    }
}

