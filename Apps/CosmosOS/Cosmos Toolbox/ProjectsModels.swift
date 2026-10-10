import Foundation

nonisolated enum ProjectsStatus: String, Codable, CaseIterable, Sendable { 
    case planned, active, completed
    var title: String { switch self { case .planned: return "计划中"; case .active: return "进行中"; case .completed: return "已完成" } }
}
nonisolated struct ProjectProgress: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var recordedAt = Date()
    var body: String
}
nonisolated struct ProjectReference: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case file, link }
    var id = UUID()
    var kind: Kind
    var name: String
    var location: String
    var createdAt = Date()
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.count <= 200, location.utf8.count <= 16384, !location.contains("\0"), createdAt.timeIntervalSinceReferenceDate.isFinite else { throw ProjectsError.invalidInput("引用名称或位置无效。") }
        switch kind {
        case .file:
            guard location.hasPrefix("/"), URL(fileURLWithPath: location).isFileURL else { throw ProjectsError.invalidInput("文件引用须为用户选取的绝对路径。") }
        case .link:
            guard let url = URL(string: location), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { throw ProjectsError.invalidInput("链接须为有效 http/https 地址，不能包含认证信息。") }
        }
    }
    func availability() -> String? {
        do { try validate() } catch { return error.localizedDescription }
        guard kind == .file else { return nil }
        guard FileManager.default.fileExists(atPath: location) else { return "文件引用已失效或不可访问；原路径保留。" }
        guard FileManager.default.isReadableFile(atPath: location) else { return "文件不可读取；原路径保留。" }
        return nil
    }
    var url: URL? { kind == .file ? URL(fileURLWithPath: location) : URL(string: location) }
}
nonisolated struct PersonalProject: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var goal = ""
    var status: ProjectsStatus = .planned
    var nextStep = ""
    var createdAt = Date()
    var updatedAt = Date()
    var isArchived = false
    var revision = 1
    var progress: [ProjectProgress] = []
    var references: [ProjectReference] = []
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 200,
              revision > 0, createdAt.timeIntervalSinceReferenceDate.isFinite, updatedAt.timeIntervalSinceReferenceDate.isFinite else { throw ProjectsError.invalidInput("名称必填且不超过 200 字符，身份与时间须有效。") }
        for text in [goal, nextStep] + progress.map(\.body) {
            guard !text.contains("\0"), text.utf8.count <= 1024 * 1024 else { throw ProjectsError.invalidInput("单段正文最多 1 MiB，不会截断；不能包含 NUL。") }
        }
        guard Set(progress.map(\.id)).count == progress.count, Set(references.map(\.id)).count == references.count,
              progress.allSatisfy({ !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.recordedAt.timeIntervalSinceReferenceDate.isFinite }) else { throw ProjectsError.invalidInput("进展或引用身份重复、记录正文为空或时间无效。") }
        for reference in references { try reference.validate() }
    }
}
nonisolated struct ProjectsDocument: Codable, Sendable {
    var schemaVersion = 1
    var projects: [PersonalProject] = []
    func validate() throws {
        guard schemaVersion == 1 else { throw ProjectsError.corruptData }
        guard Set(projects.map(\.id)).count == projects.count else { throw ProjectsError.corruptData }
        for project in projects { try project.validate() }
    }
}
nonisolated struct ProjectsSnapshot: Sendable { let projects: [PersonalProject]; let established: Bool }
nonisolated enum ProjectsLimits { static let documentBytes = 16 * 1024 * 1024 }
nonisolated enum ProjectsError: LocalizedError {
    case invalidInput(String), storage(String), writeFailed(String), conflict, corruptData, unsafePath, missingPrimaryWithBackup, uncertainWrite
    var locksSaving: Bool {
        switch self { case .invalidInput, .writeFailed: return false; default: return true }
    }
    var errorDescription: String? {
        switch self {
        case .invalidInput(let text), .storage(let text): return text
        case .writeFailed(let text): return "保存失败，草稿保留：\(text)"
        case .conflict: return "项目已在其他窗口或进程变化，草稿保留；请显式重新加载。"
        case .corruptData: return "项目库损坏或格式不受支持，写入已锁定；原文件未清空。"
        case .unsafePath: return "存储路径不安全或隔离配置缺失，读写已停止。"
        case .missingPrimaryWithBackup: return "主项目库缺失但备份存在，未自动恢复或重建，写入已锁定。"
        case .uncertainWrite: return "保存结果无法确认，草稿保留且写入锁定；请重新加载确认。"
        }
    }
}
nonisolated enum ProjectsCoding {
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys, .prettyPrinted]; e.dateEncodingStrategy = .custom { date, encoder in
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var c = encoder.singleValueContainer(); try c.encode(f.string(from: date))
        }; return e
    }
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: text) { return date }; f.formatOptions = [.withInternetDateTime]
            guard let date = f.date(from: text) else { throw ProjectsError.corruptData }; return date
        }; return d
    }
}
nonisolated enum ProjectsQuery {
    static func filter(_ projects: [PersonalProject], search: String, status: ProjectsStatus?, archived: Bool) -> [PersonalProject] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return projects.filter { $0.isArchived == archived && (status == nil || $0.status == status)
            && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.goal.localizedCaseInsensitiveContains(query)) }
            .sorted { $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt }
    }
}
