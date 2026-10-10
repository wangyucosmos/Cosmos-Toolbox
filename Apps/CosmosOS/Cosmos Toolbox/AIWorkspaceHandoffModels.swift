import Foundation

nonisolated struct AIWorkspaceHandoffRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let recordedAt: Date
    let campaignID: UUID
    let campaignName: String
    let workflowID: UUID
    let workflowName: String
    let stepID: UUID
    let stepName: String
    let toolIdentifier: String
    let toolName: String
    let goal: String
    let requirements: String
    let prompt: String
}

nonisolated struct AIWorkspaceHandoffDocument: Codable, Sendable {
    var schemaVersion = 1
    var records: [AIWorkspaceHandoffRecord] = []

    func validate() throws {
        guard schemaVersion == 1, Set(records.map(\.id)).count == records.count,
              records.allSatisfy({ !$0.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && !$0.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && $0.recordedAt.timeIntervalSinceReferenceDate.isFinite }) else {
            throw AIWorkspaceHandoffError.corruptData
        }
    }
}

nonisolated enum AIWorkspaceHandoffError: LocalizedError, Equatable {
    case storage(String), writeFailed(String), unsafePath, corruptData, missingPrimaryWithBackup, conflict, uncertainWrite
    var errorDescription: String? {
        switch self {
        case .storage(let text): return "交接记录读取失败：" + text
        case .writeFailed(let text): return "交接记录保存失败，已有主文件未被替换：" + text
        case .unsafePath: return "交接存储路径不安全或隔离配置缺失，已停止读写。"
        case .corruptData: return "交接记录无法解析，未清空、恢复或覆盖数据。"
        case .missingPrimaryWithBackup: return "交接主文件缺失但备份存在，已停止保存；未自动重建。"
        case .conflict: return "交接记录在读写期间发生变化，未覆盖新数据。"
        case .uncertainWrite: return "写入后未能确认结果，请刷新核对；重试同一次记录不会创建重复 ID。"
        }
    }
}
