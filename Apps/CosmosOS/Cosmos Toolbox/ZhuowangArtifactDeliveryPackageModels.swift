import Foundation


// MARK: - Store Snapshot

struct ZhuowangArtifactDeliverySnapshot {

    let campaignID: UUID
    let artifacts: [ZhuowangArtifact]
    let steps: [ZhuowangWorkflowStep]
}


// MARK: - Candidate

enum ZhuowangArtifactDeliveryUnavailableReason:
    Equatable {

    case noAdoptedVersion
    case multipleAdoptedVersions
    case externalReference
    case missingLocation
    case relativeSourcePath
    case workspaceUnavailable
    case outsideCampaignWorkspace
    case missingFile
    case symbolicLink
    case notRegularFile
    case unreadableFile

    var title: String {
        switch self {
        case .noAdoptedVersion:
            return "没有当前采用版本"
        case .multipleAdoptedVersions:
            return "存在多个采用版本，请先修复数据"
        case .externalReference:
            return "外部链接不属于本地交付文件"
        case .missingLocation:
            return "没有本地文件位置"
        case .relativeSourcePath:
            return "文件位置不是绝对路径"
        case .workspaceUnavailable:
            return "Campaign 正式 Workspace 不可用"
        case .outsideCampaignWorkspace:
            return "文件不在当前 Campaign 正式 Workspace 内"
        case .missingFile:
            return "本地文件不存在"
        case .symbolicLink:
            return "符号链接不可导出"
        case .notRegularFile:
            return "不是普通本地文件"
        case .unreadableFile:
            return "本地文件不可读取"
        }
    }
}


struct ZhuowangArtifactDeliveryCandidate:
    Identifiable,
    Equatable {

    let groupKey: String
    let artifactID: UUID?
    let name: String
    let stepTitle: String
    let stepSortOrder: Int
    let version: Int?
    let fileName: String?
    let unavailableReason:
        ZhuowangArtifactDeliveryUnavailableReason?

    var id: String {
        groupKey
    }

    var isEligible: Bool {
        artifactID != nil
            && unavailableReason == nil
    }

    var versionText: String {
        version.map { "V\($0)" }
            ?? "—"
    }

    var fileStatusText: String {
        unavailableReason?.title
            ?? "已采用、已落盘、可导出"
    }
}


// MARK: - Export Request / Result

struct ZhuowangArtifactDeliverySelection:
    Hashable {

    let groupKey: String
    let artifactID: UUID
}


struct ZhuowangArtifactDeliveryRequest {

    let campaign: ZhuowangCampaign
    let provinceName: String?
    let campaignWorkspaceURL: URL
    let selections:
        Set<ZhuowangArtifactDeliverySelection>
    let destinationURL: URL
}


struct ZhuowangArtifactDeliveryResult {

    let archiveURL: URL
    let manifest: ZhuowangArtifactDeliveryManifest
}


// MARK: - Manifest

struct ZhuowangArtifactDeliveryManifest:
    Codable,
    Equatable {

    struct Campaign:
        Codable,
        Equatable {

        let id: String
        let name: String
        let province: String?
    }

    struct Item:
        Codable,
        Equatable {

        let step: String
        let name: String
        let artifactID: String
        let logicalKey: String
        let version: Int
        let relativePath: String
        let byteCount: UInt64
        let sha256: String
    }

    let schemaVersion: Int
    let campaign: Campaign
    let exportedAt: String
    let items: [Item]
}


// MARK: - Export Error

enum ZhuowangArtifactDeliveryError:
    LocalizedError,
    Equatable {

    case noSelection
    case campaignChanged
    case selectionNoLongerAvailable(String, String)
    case invalidDestination
    case destinationParentUnavailable
    case destinationAlreadyExists
    case unsafeArchivePath
    case sourceChanged(String)
    case copyVerificationFailed(String)
    case archiveToolUnavailable
    case archiveCreationFailed
    case archiveVerificationFailed
    case publishFailed

    var errorDescription: String? {
        switch self {
        case .noSelection:
            return "请至少选择一个可导出的工作产物。"
        case .campaignChanged:
            return "Campaign 状态已变化，交付包没有生成。请重新打开导出界面后再试。"
        case .selectionNoLongerAvailable(
            let name,
            let reason
        ):
            return "“\(name)”已不满足导出条件：\(reason)。交付包没有生成。"
        case .invalidDestination:
            return "请选择有效的本地 ZIP 保存位置。"
        case .destinationParentUnavailable:
            return "所选保存目录不可用，交付包没有生成。"
        case .destinationAlreadyExists:
            return "目标 ZIP 已存在。为保护用户文件，Cosmos OS 不会覆盖它。"
        case .unsafeArchivePath:
            return "检测到不安全的包内路径，交付包没有生成。"
        case .sourceChanged(let name):
            return "复制期间“\(name)”发生变化，交付包已取消。"
        case .copyVerificationFailed(let name):
            return "“\(name)”的复制文件未通过哈希核验，交付包已取消。"
        case .archiveToolUnavailable:
            return "本机 ZIP 工具不可用，交付包没有生成。"
        case .archiveCreationFailed:
            return "ZIP 创建失败，临时文件已清理。"
        case .archiveVerificationFailed:
            return "ZIP 内容未通过完整性核验，临时文件已清理。"
        case .publishFailed:
            return "ZIP 无法安全放到所选位置，临时文件已清理。"
        }
    }
}
