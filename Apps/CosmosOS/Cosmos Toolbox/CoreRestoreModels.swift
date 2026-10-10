import Foundation

nonisolated struct CoreRestorePlan {
    let backupURL: URL
    let packageHash: String
    let packageRevision: String
    let manifest: CoreBackupManifest
    let payloads: [String: Data]
    let summaries: [String: String]
    let warnings: [String]
}

nonisolated struct CoreRestoreJournal: Codable {
    var version = 1
    let id: UUID
    var state: String
    var restoredInstallation: Bool
    var receipts: [CoreRestoreReceipt]
}

nonisolated struct CoreRestoreReceipt: Codable {
    let sourceID: String
    let hash: String
    var phase: String = "planned"
    var fileIdentity: String?
}

nonisolated enum CoreRestoreError: LocalizedError {
    case invalid(String), simulatedInterruption
    var errorDescription: String? {
        switch self {
        case .invalid(let text): return text
        case .simulatedInterruption: return "恢复中断；事务标记保留，业务加载已阻止。"
        }
    }
}

nonisolated enum CoreRestoreCheckpoint: Equatable {
    case prepared, beforeWrite(String), afterWrite(String), beforeCommit
}

/// Set only by the startup gate, before any business Store can be constructed.
enum CoreRestoreRuntime {
    static var restoredInstallation = false
}
