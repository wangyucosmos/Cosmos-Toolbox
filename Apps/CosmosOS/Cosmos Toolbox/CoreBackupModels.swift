import Foundation

nonisolated struct CoreBackupManifest: Codable {
    var format = "CosmosCoreMetadata"
    var version = 2
    var exportedAt: Date
    var exclusions = CoreBackupSource.exclusions
    var sources: [CoreBackupEntry]
}

nonisolated struct CoreBackupEntry: Codable {
    let id: String
    let status: String
    let path: String?
    let bytes: Int
    let sha256: String?
    let transformation: String?
}

nonisolated struct CoreBackupResult {
    let url: URL
    let manifest: CoreBackupManifest
    var summary: String {
        let present = manifest.sources.filter { $0.status == "present" }.count
        return "校验通过：\(present) 个已建立数据源，\(manifest.sources.count - present) 个尚未建立。\(manifest.version == 1 ? "旧版本未包含 Projects；不会伪造项目数据。" : "")格式 V\(manifest.version)；仅元数据，不包含产物或引用文件实体。"
    }
}

nonisolated enum CoreBackupError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        if case .invalid(let text) = self { return text }; return nil
    }
}
