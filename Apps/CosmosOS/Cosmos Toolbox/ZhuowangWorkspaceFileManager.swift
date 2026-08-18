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

