import Foundation
import CryptoKit
import Darwin

/// 只读来源：个人笔记库与提示词库。读取走各自既有的只读 `load()`，
/// 不创建缺失的库 / 锁 / 备份，不增加版本，不改任何元数据。
nonisolated struct ContentExportLibraries: Sendable {
    let notes: PersonalNotesFileStorage?
    let notesUnavailable: String?
    let prompts: PromptVaultFileStorage?
    let promptsUnavailable: String?

    init(notes: PersonalNotesFileStorage?, prompts: PromptVaultFileStorage?,
         notesUnavailable: String? = nil, promptsUnavailable: String? = nil) {
        self.notes = notes; self.prompts = prompts
        self.notesUnavailable = notesUnavailable; self.promptsUnavailable = promptsUnavailable
    }
    @MainActor init(notesLocation: PersonalNotesLocation?, promptLocation: PromptVaultLocation?) {
        notes = notesLocation?.root.map { PersonalNotesFileStorage(root: $0) }
        notesUnavailable = notesLocation.map { $0.root == nil ? ($0.error?.localizedDescription ?? "存储位置不可用") : nil } ?? "未配置个人笔记来源"
        prompts = promptLocation?.root.map { PromptVaultFileStorage(root: $0) }
        promptsUnavailable = promptLocation.map { $0.root == nil ? ($0.error?.localizedDescription ?? "存储位置不可用") : nil } ?? "未配置提示词来源"
    }
    /// 导出文件不得写进源库目录。
    var protectedRoots: [URL] { [notes?.root, prompts?.root].compactMap { $0 } }
}

nonisolated struct ContentExportManifest: Codable, Sendable {
    struct Reference: Codable, Sendable {
        let id: String, kind: String, name: String, location: String, notes: String
        let correctsReferenceID: String?
        let recordedAt: String
    }
    struct File: Codable, Sendable {
        let role: String                    // current | history
        let versionID: String?
        let versionNumber: Int?
        let name: String
        let category: String?
        let savedAt: String?
        /// true：savedAt 沿用升级前的模板更新时间，并非实际编辑时间。
        let savedAtIsInherited: Bool?
        let path: String
        let bytes: Int
        let sha256: String
    }
    struct Item: Codable, Sendable {
        let source: String
        let id: String
        let name: String
        let category: String?
        let archived: Bool
        let files: [File]
        let references: [Reference]?
    }
    var exportFormat = "CosmosContentExport"
    var formatVersion = 1
    var isCoreBackup = false
    var notice = "这是个人内容导出，不是 Cosmos 核心数据备份，不能用于恢复。"
    var exportedAt: String
    var history: String                     // currentOnly | includeHistory
    var items: [Item]
}

nonisolated struct ContentExportService: Sendable {
    let libraries: ContentExportLibraries
    var now: @Sendable () -> Date = { Date() }
    var temporaryRoot: URL = FileManager.default.temporaryDirectory
    /// 测试夹具与故障注入点；生产代码为空操作。
    var checkpoint: @Sendable (ContentExportCheckpoint) throws -> Void = { _ in }

    init(libraries: ContentExportLibraries) { self.libraries = libraries }

    // MARK: Reading (read-only)

    private func readNotes() async throws -> [PersonalNote] {
        guard let storage = libraries.notes else {
            throw ContentExportError.sourceUnavailable("个人笔记：" + (libraries.notesUnavailable ?? "存储位置不可用"))
        }
        do { return try await storage.load().notes }
        catch { throw ContentExportError.sourceUnavailable("个人笔记：" + error.localizedDescription) }
    }
    private func readTemplates() async throws -> [PromptTemplate] {
        guard let storage = libraries.prompts else {
            throw ContentExportError.sourceUnavailable("提示词库：" + (libraries.promptsUnavailable ?? "存储位置不可用"))
        }
        do { return try await storage.load() }
        catch { throw ContentExportError.sourceUnavailable("提示词库：" + error.localizedDescription) }
    }
    @concurrent
    func readRecords(_ source: ContentExportSource) async throws -> [ContentExportRecord] {
        switch source {
        case .personalNote: return try await readNotes().map(ContentExportRecord.init(note:))
        case .promptTemplate: return try await readTemplates().map(ContentExportRecord.init(template:))
        }
    }

    /// 选择界面用：每个来源独立读取，错误如实抛出，不会伪装成空列表。
    @concurrent
    func listing(_ source: ContentExportSource) async throws -> [ContentExportListingRow] {
        switch source {
        case .personalNote:
            return try await readNotes().map {
                ContentExportListingRow(source: .personalNote, recordID: $0.id, name: $0.title, category: $0.category,
                    isArchived: $0.isArchived, contentVersion: $0.contentVersion, versionCount: $0.versions.count,
                    referenceCount: $0.references.count, updatedAt: $0.updatedAt)
            }
        case .promptTemplate:
            return try await readTemplates().map {
                ContentExportListingRow(source: .promptTemplate, recordID: $0.id, name: $0.name, category: $0.category,
                    isArchived: $0.isArchived, contentVersion: $0.contentVersion, versionCount: max($0.versions.count, 1),
                    referenceCount: 0, updatedAt: $0.updatedAt)
            }
        }
    }

    // MARK: Rules

    static func restrict(_ record: ContentExportRecord, rule: ContentExportSelectionRule) throws -> ContentExportRecord {
        switch rule {
        case .singleCurrent(let expected):
            guard record.current.versionID == expected else { throw ContentExportError.sourceChanged(record.name) }
            return record.restricting(to: [record.current])
        case .singleSpecific(let versionID):
            guard let version = record.versions.first(where: { $0.versionID == versionID }) else {
                throw ContentExportError.versionMissing(record.name)
            }
            return record.restricting(to: [version])
        case .batch(.currentOnly):
            return record.restricting(to: [record.current])
        case .batch(.includeHistory):
            return record
        }
    }

    // MARK: Prepare

    @concurrent
    func prepare(single request: ContentExportSingleRequest) async throws -> ContentExportPlan {
        let records = try await readRecords(request.source)
        guard let record = records.first(where: { $0.id == request.id }) else { throw ContentExportError.recordMissing("所选记录") }
        let rule: ContentExportSelectionRule
        switch request.version {
        case .current(let expected): rule = .singleCurrent(expectedVersionID: expected)
        case .specific(let id): rule = .singleSpecific(id)
        }
        let frozen = try Self.restrict(record, rule: rule)
        let version = frozen.current
        var base = ContentExportFileName.safeDisplay(version.name)
        if case .specific = request.version, let number = version.number { base += "_v\(number)" }
        let bytes = version.bodyData.count
        var notices = ["单个 .md 只含已保存正文的原文字节（\(bytes) 字节）：不含标题、分类、引用或任何元数据，不添加换行或 front matter。",
                       "导出的是已保存版本；未保存草稿、变量填写结果和剪贴板内容都不包含，也不会被保存或放弃。"]
        if bytes == 0 { notices.append("正文为空，将导出一个空文件。") }
        if request.source == .promptTemplate { notices.append("提示词中的 {{变量}} 表达式保持字面原文，不展开。") }
        let row = ContentExportPreview.Row(id: frozen.selection.id.uuidString, source: frozen.source.label, name: version.name,
            category: version.category ?? "未分类", archived: frozen.isArchived, versionSummary: Self.versionSummary(version, isCurrent: version.versionID == record.current.versionID),
            fileCount: 1, bytes: bytes, referenceCount: 0)
        let plan = ContentExportPlan(kind: .singleMarkdown, rule: rule, records: [frozen], fingerprints: [:],
            suggestedFileName: base + ".md",
            preview: ContentExportPreview(rows: [row], fileCount: 1, totalBytes: bytes, notices: notices))
        return Self.withFingerprints(plan)
    }

    @concurrent
    func prepare(batch request: ContentExportBatchRequest) async throws -> ContentExportPlan {
        var unique: [ContentExportSelection] = []
        var seen = Set<ContentExportSelection>()
        for selection in request.selections where seen.insert(selection).inserted { unique.append(selection) }
        guard !unique.isEmpty else { throw ContentExportError.noSelection }
        let rule = ContentExportSelectionRule.batch(request.scope)
        var cache: [ContentExportSource: [ContentExportRecord]] = [:]
        var frozen: [ContentExportRecord] = []
        for selection in unique {
            if cache[selection.source] == nil { cache[selection.source] = try await readRecords(selection.source) }
            guard let record = cache[selection.source]?.first(where: { $0.id == selection.id }) else {
                throw ContentExportError.recordMissing("所选\(selection.source.label)")
            }
            frozen.append(try Self.restrict(record, rule: rule))
        }
        frozen.sort {
            if $0.source.sortRank != $1.source.sortRank { return $0.source.sortRank < $1.source.sortRank }
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.id.uuidString < $1.id.uuidString
        }
        var rows: [ContentExportPreview.Row] = []
        var files = 0, total = 0
        for record in frozen {
            let bytes = record.versions.reduce(0) { $0 + $1.bodyData.count }
            files += record.versions.count; total += bytes
            let summary: String
            if request.scope == .includeHistory {
                summary = record.current.versionID == nil ? "无版本历史，仅当前内容" : "当前 v\(record.current.number ?? 0) + 历史共 \(record.versions.count) 个版本"
            } else {
                summary = record.current.versionID == nil ? "当前内容（升级前，无版本号）" : "当前内容 v\(record.current.number ?? 0)"
            }
            rows.append(.init(id: record.selection.id.uuidString, source: record.source.label, name: record.name,
                category: record.category ?? "未分类", archived: record.isArchived, versionSummary: summary,
                fileCount: record.versions.count, bytes: bytes, referenceCount: record.references.count))
        }
        let notices = Self.batchNotices(frozen, scope: request.scope)
        let stamp = DateFormatter.contentExportFileStamp.string(from: now())
        let plan = ContentExportPlan(kind: .archive, rule: rule, records: frozen, fingerprints: [:],
            suggestedFileName: "Cosmos内容导出_\(stamp).zip",
            preview: ContentExportPreview(rows: rows, fileCount: files, totalBytes: total, notices: notices))
        return Self.withFingerprints(plan)
    }

    private static func withFingerprints(_ plan: ContentExportPlan) -> ContentExportPlan {
        var map: [ContentExportSelection: String] = [:]
        for record in plan.records { map[record.selection] = plan.fingerprint(of: record) }
        return ContentExportPlan(kind: plan.kind, rule: plan.rule, records: plan.records, fingerprints: map,
            suggestedFileName: plan.suggestedFileName, preview: plan.preview)
    }

    private static func versionSummary(_ version: ContentExportVersion, isCurrent: Bool) -> String {
        guard let number = version.number else { return "当前内容（升级前，无版本号）" }
        return isCurrent ? "v\(number)（当前内容）" : "v\(number)（历史版本）"
    }

    private static func batchNotices(_ records: [ContentExportRecord], scope: ContentExportScope) -> [String] {
        var notices = ["导出为内容 ZIP：每条记录一个文件夹，current.md 是已保存的当前内容原文；manifest.json 记录来源、稳定 ID、版本、保存时间、字节数与 SHA-256。"]
        if scope == .includeHistory {
            notices.append("包含全部已保存的历史版本（history/vNNN.md）。")
            let legacy = records.filter { $0.current.versionID == nil }.count
            if legacy > 0 { notices.append("\(legacy) 条提示词保存于版本历史功能之前，没有历史版本，只导出当前内容；不编造版本号或日期。") }
        } else {
            notices.append("仅导出当前内容；不包含历史版本。")
        }
        let noteRecords = records.filter { $0.source == .personalNote }
        let referenceCount = noteRecords.reduce(0) { $0 + $1.references.count }
        if referenceCount > 0 {
            notices.append("所选个人笔记共有 \(referenceCount) 条引用与更正记录：登记的本机文件路径和链接会写入 manifest.json 随包导出，分享前请确认；不会读取或复制文件实体，也不会抓取网页。")
        } else if !noteRecords.isEmpty {
            notices.append("所选个人笔记没有文件或链接引用。")
        }
        let archived = records.filter(\.isArchived).count
        if archived > 0 { notices.append("其中 \(archived) 条是已归档记录（因你明确选择而包含）。") }
        notices.append("导出的是已保存版本；未保存草稿、变量填写结果和剪贴板内容都不包含，也不会被保存或放弃。提示词中的 {{变量}} 表达式保持字面原文。")
        notices.append("这不是核心数据备份：不能用于恢复，也不会被核心备份校验或恢复流程识别。")
        return notices
    }

    // MARK: Export

    @concurrent
    func export(plan: ContentExportPlan, to requested: URL,
                cancellation: ContentExportCancellation = ContentExportCancellation()) async throws -> ContentExportResult {
        try cancellation.check()
        let destination = try validateDestination(requested, plan: plan)
        try await recheck(plan)
        try checkpoint(.afterRecheck)
        try cancellation.check()

        let workDir = temporaryRoot.appendingPathComponent("CosmosContentExport-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workDir) }       // 只清理本次专属临时目录
        let exportedAt = now()
        let built = try await blocking { try self.buildAndVerify(plan: plan, workDir: workDir, exportedAt: exportedAt) }

        try cancellation.check()
        try await recheck(plan)
        try checkpoint(.afterSecondRecheck)
        try cancellation.check()          // 此后进入发布：不可取消

        try await blocking { try self.publish(built: built, destination: destination, kind: plan.kind) }
        return ContentExportResult(url: destination, kind: plan.kind, entryCount: built.entryCount,
            byteCount: built.byteCount, sha256: built.sha256)
    }

    /// 准备后重新读取并按指纹核对每条选中记录；无关记录的变化不会影响结果。
    @concurrent
    private func recheck(_ plan: ContentExportPlan) async throws {
        var cache: [ContentExportSource: [ContentExportRecord]] = [:]
        for record in plan.records {
            if cache[record.source] == nil { cache[record.source] = try await readRecords(record.source) }
            guard let fresh = cache[record.source]?.first(where: { $0.id == record.id }) else {
                throw ContentExportError.recordMissing(record.name)
            }
            let restricted = try Self.restrict(fresh, rule: plan.rule)
            guard plan.fingerprints[record.selection] == plan.fingerprint(of: restricted) else {
                throw ContentExportError.sourceChanged(record.name)
            }
        }
    }

    private func blocking<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do { continuation.resume(returning: try work()) }
                catch let error as ContentExportError { continuation.resume(throwing: error) }
                catch { continuation.resume(throwing: ContentExportError.buildFailed(error.localizedDescription)) }
            }
        }
    }

    // MARK: Destination

    private func lstatKind(_ path: String) -> (exists: Bool, mode: mode_t) {
        var info = stat()
        if lstat(path, &info) == 0 { return (true, info.st_mode & S_IFMT) }
        return (false, 0)
    }

    func validateDestination(_ requested: URL, plan: ContentExportPlan) throws -> URL {
        guard requested.isFileURL, requested.path.hasPrefix("/"), !requested.path.contains("\0"),
              !requested.path.split(separator: "/").contains("..") else {
            throw ContentExportError.destinationInvalid("路径无效")
        }
        let allowed = plan.kind == .singleMarkdown ? ["md", "markdown"] : ["zip"]
        guard allowed.contains(requested.pathExtension.lowercased()) else {
            throw ContentExportError.destinationInvalid(plan.kind == .singleMarkdown ? "文件扩展名须为 .md" : "文件扩展名须为 .zip")
        }
        let name = requested.lastPathComponent
        guard !name.isEmpty, name.utf8.count <= 200 else { throw ContentExportError.destinationInvalid("文件名为空或过长") }
        let parent = requested.deletingLastPathComponent().resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory), isDirectory.boolValue,
              access(parent.path, W_OK | X_OK) == 0 else {
            throw ContentExportError.destinationInvalid("保存文件夹不存在或不可写")
        }
        let parentParts = parent.standardizedFileURL.pathComponents
        for root in libraries.protectedRoots {
            let rootParts = root.resolvingSymlinksInPath().standardizedFileURL.pathComponents
            if parentParts.count >= rootParts.count, Array(parentParts.prefix(rootParts.count)) == rootParts {
                throw ContentExportError.destinationInvalid("不能保存到源数据目录内，避免改动源库")
            }
        }
        let destination = parent.appendingPathComponent(name)
        guard !lstatKind(destination.path).exists else { throw ContentExportError.destinationExists }
        return destination
    }

    // MARK: Build + verify (off the main thread)

    struct Built: Sendable {
        let file: URL
        let byteCount: Int
        let sha256: String
        let entryCount: Int
    }

    private func buildAndVerify(plan: ContentExportPlan, workDir: URL, exportedAt: Date) throws -> Built {
        let output = workDir.appendingPathComponent("output")
        do {
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700])
        } catch { throw ContentExportError.buildFailed("无法创建临时目录") }

        let payload: Data
        var expected: [(path: String, data: Data)] = []
        switch plan.kind {
        case .singleMarkdown:
            guard plan.records.count == 1, plan.records[0].versions.count == 1 else { throw ContentExportError.buildFailed("单条导出范围无效") }
            payload = plan.records[0].versions[0].bodyData
        case .archive:
            expected = try Self.archiveEntries(plan: plan, exportedAt: exportedAt)
            payload = try ContentExportZip.encode(expected, date: exportedAt)
        }
        do { try payload.write(to: output, options: [.withoutOverwriting]) }
        catch { throw ContentExportError.buildFailed("无法写入临时文件") }
        try checkpoint(.afterBuild)

        // 独立读回：不使用刚生成的内存数据。
        guard let readBack = try? Data(contentsOf: output), readBack == payload else {
            throw ContentExportError.verifyFailed("临时文件读回与生成内容不一致")
        }
        if plan.kind == .archive { try Self.verifyArchive(readBack, expected: expected) }
        try checkpoint(.afterVerify)
        return Built(file: output, byteCount: payload.count, sha256: Self.hex(SHA256.hash(data: payload)),
                     entryCount: plan.kind == .archive ? expected.count : 1)
    }

    static func hex(_ digest: SHA256.Digest) -> String { digest.map { String(format: "%02x", $0) }.joined() }
    static func sha(_ data: Data) -> String { hex(SHA256.hash(data: data)) }

    static func archiveEntries(plan: ContentExportPlan, exportedAt: Date) throws -> [(path: String, data: Data)] {
        var content: [(path: String, data: Data)] = []
        var items: [ContentExportManifest.Item] = []
        for record in plan.records {
            let folder = "\(record.source.directory)/\(ContentExportFileName.safeDisplay(record.name))--\(record.id.uuidString.lowercased())"
            var files: [ContentExportManifest.File] = []
            func add(_ version: ContentExportVersion, role: String, path: String) {
                let data = version.bodyData
                content.append((path, data))
                files.append(.init(role: role, versionID: version.versionID?.uuidString, versionNumber: version.number,
                    name: version.name, category: version.category, savedAt: version.savedAt.map(ContentExportTime.string),
                    savedAtIsInherited: version.isUpgradeBaseline ? true : nil, path: path, bytes: data.count, sha256: sha(data)))
            }
            add(record.current, role: "current", path: folder + "/current.md")
            for version in record.versions.dropLast() {
                add(version, role: "history", path: folder + "/history/" + String(format: "v%03d.md", version.number ?? 0))
            }
            let references: [ContentExportManifest.Reference]? = record.source == .personalNote
                ? record.references.map {
                    .init(id: $0.id.uuidString, kind: $0.kind.rawValue, name: $0.name, location: $0.location, notes: $0.notes,
                          correctsReferenceID: $0.correctsReferenceID?.uuidString, recordedAt: ContentExportTime.string($0.recordedAt))
                } : nil
            items.append(.init(source: record.source.rawValue, id: record.id.uuidString, name: record.name, category: record.category,
                archived: record.isArchived, files: files, references: references))
        }
        let manifest = ContentExportManifest(exportedAt: ContentExportTime.string(exportedAt),
            history: plan.scope == .includeHistory ? "includeHistory" : "currentOnly", items: items)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let manifestData = try encoder.encode(manifest)
        return [("说明.md", Data(readme(plan: plan, exportedAt: exportedAt).utf8)), ("manifest.json", manifestData)] + content
    }

    private static func readme(plan: ContentExportPlan, exportedAt: Date) -> String {
        let notes = plan.records.filter { $0.source == .personalNote }.count
        let prompts = plan.records.count - notes
        let fileCount = plan.records.reduce(0) { $0 + $1.versions.count }
        return """
        # Cosmos OS 内容导出包

        导出时间：\(ContentExportTime.string(exportedAt))
        范围：\(plan.scope == .includeHistory ? "当前内容 + 全部历史版本" : "仅当前内容")
        内容：个人笔记 \(notes) 条，提示词 \(prompts) 条，共 \(fileCount) 个 Markdown 文件。

        ## 目录
        - `notes/`、`prompts/`：每条记录一个文件夹，文件夹名为「显示名称--稳定 ID」。
        - `current.md`：导出时已保存的当前内容原文。
        - `history/vNNN.md`：历史版本原文（仅在选择包含历史时出现）。
        - `manifest.json`：每个文件的来源、稳定 ID、版本编号、保存时间、字节数与 SHA-256，可用于核对。

        ## 使用边界
        - 这是内容导出，不是 Cosmos 核心数据备份：不能用于恢复，核心备份校验与恢复不会识别它。
        - Markdown 文件就是已保存正文的原文字节，不含标题、分类或其它元数据；提示词里的 {{变量}} 保持原样。
        - 个人笔记的文件 / 链接引用只在 manifest.json 中登记路径或链接，不含文件实体或网页内容；分享前请确认这些位置可以公开。
        - 未保存草稿、变量填写结果和剪贴板内容均不包含。
        """ + "\n"
    }

    static func verifyArchive(_ data: Data, expected: [(path: String, data: Data)]) throws {
        let decoded = try ContentExportZip.decode(data)
        guard decoded.count == expected.count else { throw ContentExportError.verifyFailed("条目数量不一致") }
        for (actual, wanted) in zip(decoded, expected) {
            guard actual.path == wanted.path, actual.data == wanted.data else {
                throw ContentExportError.verifyFailed("条目内容与冻结快照不一致：\(wanted.path)")
            }
        }
        // 清单自洽：路径、字节数与 SHA-256 与包内文件逐一核对，且无清单外的内容文件。
        guard let manifestEntry = decoded.first(where: { $0.path == "manifest.json" }),
              let manifest = try? JSONDecoder().decode(ContentExportManifest.self, from: manifestEntry.data) else {
            throw ContentExportError.verifyFailed("manifest.json 无法解析")
        }
        var listed = Set<String>()
        for file in manifest.items.flatMap(\.files) {
            guard let entry = decoded.first(where: { $0.path == file.path }), entry.data.count == file.bytes,
                  sha(entry.data) == file.sha256, listed.insert(file.path).inserted else {
                throw ContentExportError.verifyFailed("清单与包内文件不一致：\(file.path)")
            }
        }
        let unexpected = Set(decoded.map(\.path)).subtracting(listed).subtracting(["manifest.json", "说明.md"])
        guard unexpected.isEmpty else { throw ContentExportError.verifyFailed("包内存在清单外的文件") }
    }

    // MARK: Publish (no-overwrite)

    private func fileSHA256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return Self.hex(hasher.finalize())
    }

    private func publish(built: Built, destination: URL, kind: ContentExportPlan.Kind) throws {
        try checkpoint(.beforePublish)
        guard !lstatKind(destination.path).exists else { throw ContentExportError.destinationExists }
        let parent = destination.deletingLastPathComponent()
        let part = parent.appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).part")
        var partPublished = false
        defer { if !partPublished { unlink(part.path) } }                // 只清理本次的 .part

        let fd = open(part.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o644)
        guard fd >= 0 else { throw ContentExportError.publishFailed(String(cString: strerror(errno))) }
        var closed = false
        defer { if !closed { close(fd) } }
        do {
            let source = try FileHandle(forReadingFrom: built.file)
            defer { try? source.close() }
            let target = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
            while let chunk = try source.read(upToCount: 1 << 20), !chunk.isEmpty { try target.write(contentsOf: chunk) }
            try target.synchronize()
        } catch { throw ContentExportError.publishFailed("写入失败：\(error.localizedDescription)") }
        closed = true
        guard close(fd) == 0 else { throw ContentExportError.publishFailed(String(cString: strerror(errno))) }
        try checkpoint(.afterPartWritten)

        guard try fileSHA256(part) == built.sha256 else { throw ContentExportError.publishFailed("暂存文件校验不一致") }
        var partInfo = stat()
        guard lstat(part.path, &partInfo) == 0 else { throw ContentExportError.publishFailed("暂存文件丢失") }

        // 原子且不覆盖：RENAME_EXCL；文件系统不支持时退回 link()（目标存在即 EEXIST）。
        if renamex_np(part.path, destination.path, UInt32(RENAME_EXCL)) == 0 {
            partPublished = true
        } else if errno == EEXIST {
            throw ContentExportError.destinationExists
        } else if errno == ENOTSUP || errno == EINVAL {
            if link(part.path, destination.path) != 0 {
                if errno == EEXIST { throw ContentExportError.destinationExists }
                throw ContentExportError.publishFailed(String(cString: strerror(errno)))
            }
        } else {
            throw ContentExportError.publishFailed(String(cString: strerror(errno)))
        }

        var finalInfo = stat()
        guard lstat(destination.path, &finalInfo) == 0, finalInfo.st_ino == partInfo.st_ino, finalInfo.st_dev == partInfo.st_dev,
              finalInfo.st_mode & S_IFMT == S_IFREG else {
            throw ContentExportError.publishFailed("发布后的目标已被其它程序替换，未做任何删除")
        }
        guard (try? fileSHA256(destination)) == built.sha256 else {
            unlink(destination.path)                                        // 仍是本次发布的同一 inode
            throw ContentExportError.publishFailed("发布后校验不一致，已移除本次发布的文件")
        }
    }
}

nonisolated extension DateFormatter {
    static let contentExportFileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
