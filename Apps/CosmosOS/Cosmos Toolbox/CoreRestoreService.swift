import Foundation
import Darwin

nonisolated struct CoreRestoreService {
    static let journalLimit = 256 * 1024
    let target: CoreRestoreTarget
    var checkpoint: (CoreRestoreCheckpoint) throws -> Void = { _ in }

    static func prepare(_ backup: URL) throws -> CoreRestorePlan {
        guard let (raw, revision) = try CoreBackupService.readFile(backup, limit: CoreBackupService.packageLimit) else { throw CoreRestoreError.invalid("备份不存在。") }
        let checked = try CoreBackupService.verifyBytes(raw, at: backup)
        let entries = try CoreBackupArchive.decode(raw)
        var payloads = [String: Data](), summaries = [String: String]()
        var warnings = ["仅恢复元数据。产物实体、外部资料及认证信息未包含；原文件路径只作历史引用，未检查或移动实体。",
            "Provider、Connection、Tool、Route 恢复为禁用/待配置；排除的端点、适配器及自由配置需重新设置，未进行联网或 CLI 验证。"]
        for item in checked.manifest.sources where item.status == "present" {
            let raw = entries[item.path!]!
            var safe = raw
            let object = try JSONSerialization.jsonObject(with: raw)
            if var values = object as? [[String: Any]], CoreBackupSource.configurationFields[item.id] != nil {
                for index in values.indices {
                    if item.id != "routes" { values[index]["isEnabled"] = false }
                    if item.id != "providers" { values[index]["status"] = "needsSetup" }
                    if item.id == "connections" { values[index]["allowsAutomaticSelection"] = false }
                    if item.id == "connections" || item.id == "routes" {
                        values[index]["supportsDirectExecution"] = false
                        values[index]["supportsAutomaticResultReturn"] = false
                    }
                }
                safe = try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys, .prettyPrinted])
            }
            guard safe.count <= CoreBackupService.sourceLimit else { throw CoreRestoreError.invalid("恢复转换后的数据源超过 16 MiB；未写入。") }
            try CoreBackupSource.validated(safe, id: item.id)
            payloads[item.id] = safe
            if let values = object as? [Any] { summaries[item.id] = "\(values.count) 项" }
            else if let value = object as? [String: Any] {
                summaries[item.id] = value.keys.sorted().filter { $0 != "schemaVersion" }.map { key in
                    "\(key)：\((value[key] as? [Any])?.count ?? 0) 项"
                }.joined(separator: "；")
            }
        }
        guard !payloads.isEmpty else { throw CoreRestoreError.invalid("备份没有实际恢复项。") }
        warnings += try associations(payloads)
        return CoreRestorePlan(backupURL: backup, packageHash: CoreBackupService.digest(raw), packageRevision: revision,
            manifest: checked.manifest, payloads: payloads, summaries: summaries, warnings: warnings)
    }

    private static func associations(_ payloads: [String: Data]) throws -> [String] {
        func array(_ id: String) throws -> [[String: Any]] {
            guard let raw = payloads[id] else { return [] }
            return try JSONSerialization.jsonObject(with: raw) as? [[String: Any]] ?? []
        }
        func id(_ object: [String: Any], _ key: String = "id") -> String { (object[key] as? String ?? "").uppercased() }
        let campaigns = Set(try array("campaigns").map { id($0) })
        let providers = Set(try array("providers").map { id($0) })
        let connections = try array("connections"), tools = Set(try array("tools").map { id($0) })
        let connectionIDs = Set(connections.map { id($0) })
        var warnings = [String]()
        for workflow in try array("workflows") {
            guard campaigns.contains(id(workflow,"campaignID")) else { throw CoreRestoreError.invalid("Workflow 的活动关联缺失，不能恢复；尚未写入。") }
            let steps = Set((workflow["steps"] as? [[String: Any]] ?? []).map { id($0) })
            let runs = workflow["aiRuns"] as? [[String: Any]] ?? [], runIDs = Set(runs.map { id($0) })
            for run in runs {
                guard steps.contains(id(run,"stepID")) else { throw CoreRestoreError.invalid("Run 的步骤关联缺失，未写入。") }
                if !providers.contains(id(run,"providerID")) { warnings.append("历史 Run 引用的 Provider 已不在配置中；保留历史身份，不补造配置。") }
            }
            for artifact in workflow["artifacts"] as? [[String: Any]] ?? [] {
                guard id(artifact,"campaignID") == id(workflow,"campaignID") else { throw CoreRestoreError.invalid("Artifact 属于其他活动，未写入。") }
                if artifact["stepID"] != nil && !steps.contains(id(artifact,"stepID")) { warnings.append("部分历史产物来源步骤已缺失；保留原引用。") }
                if artifact["runID"] != nil && !runIDs.contains(id(artifact,"runID")) { warnings.append("部分历史产物 Run 已缺失；保留原引用。") }
            }
            for approval in workflow["approvals"] as? [[String: Any]] ?? [] {
                guard steps.contains(id(approval,"stepID")) else { throw CoreRestoreError.invalid("Approval 的步骤关联缺失，未写入。") }
                if approval["runID"] != nil && !runIDs.contains(id(approval,"runID")) { warnings.append("历史 Approval 的 Run 已缺失；保留原引用。") }
            }
        }
        if connections.contains(where: { !providers.contains(id($0,"providerID")) }) { warnings.append("部分 Connection 的 Provider 已缺失；恢复为禁用待配置，不补造关联。") }
        if try array("routes").contains(where: { !connectionIDs.contains(id($0,"connectionID")) || !tools.contains(id($0,"toolIntegrationID")) }) {
            warnings.append("部分 Route 的连接或工具已缺失；保留身份并停用执行。")
        }
        // Handoff records are intentionally historical: deleted Campaign/Step references remain valid snapshots.
        return Array(Set(warnings)).sorted()
    }

    func journal() throws -> (CoreRestoreJournal, Data)? {
        guard let raw = try CoreBackupService.readFile(target.stateURL, limit: Self.journalLimit)?.0 else {
            if try CoreBackupService.kind(target.transactionRoot) != nil {
                try CoreBackupService.checkParents(target.stateURL)
                let names = try FileManager.default.contentsOfDirectory(atPath: target.transactionRoot.path)
                guard Set(names).isSubset(of: [".restore.lock"]) else { throw CoreRestoreError.invalid("恢复目录存在无事务归属的数据，已阻止加载；未清理或覆盖。") }
            }
            return nil
        }
        let value: CoreRestoreJournal
        do { value = try JSONDecoder().decode(CoreRestoreJournal.self, from: raw) }
        catch { throw CoreRestoreError.invalid("恢复事务标记无法解析，业务加载已阻止。") }
        guard value.version == 1, ["inProgress","failed","complete","started"].contains(value.state),
              value.receipts.count <= 10, Set(value.receipts.map(\.sourceID)).count == value.receipts.count,
              value.receipts.allSatisfy({ CoreBackupSource.ids.contains($0.sourceID) && ["planned","pending","written"].contains($0.phase)
                  && $0.hash.count == 64 && $0.hash.allSatisfy({ "0123456789abcdef".contains($0) }) }) else {
            throw CoreRestoreError.invalid("恢复事务标记结构无效，业务加载已阻止。")
        }
        return (value,raw)
    }

    func startup() throws -> String {
        if let (value, _) = try journal() {
            if value.state == "started" { return value.restoredInstallation ? "restored" : "existing" }
            if value.state == "complete" { return "readyToLoad" }
            return "interrupted"
        }
        return try target.occupied() ? "existing" : "empty"
    }

    func beginNewEnvironment() throws {
        try withLock {
            try target.requireEmpty()
            try saveJournal(.init(id:UUID(),state:"started",restoredInstallation:false,receipts:[]), expected:nil)
        }
    }

    func activateCompleted() throws {
        try withLock {
            guard let (snapshot,raw) = try journal(), snapshot.state == "complete" else { throw CoreRestoreError.invalid("没有已完成事务。") }
            var value = snapshot
            try checkProgress(value)
            try cleanStaging(value)
            value.state = "started"; value.receipts = []
            try saveJournal(value,expected:raw)
        }
    }

    func restore(_ plan: CoreRestorePlan) throws {
        let fresh = try Self.prepare(plan.backupURL)
        guard fresh.packageHash == plan.packageHash, fresh.packageRevision == plan.packageRevision else { throw CoreRestoreError.invalid("备份在预览后变化；请重新选择校验并确认。") }
        try target.requireEmpty()
        try withLock {
            try target.requireEmpty()
            var value = CoreRestoreJournal(id:UUID(),state:"inProgress",restoredInstallation:true,
                receipts:CoreBackupSource.ids.compactMap { id in plan.payloads[id].map { .init(sourceID:id,hash:CoreBackupService.digest($0)) } })
            try saveJournal(value,expected:nil)
            do {
                for receipt in value.receipts { _ = try insertFile(plan.payloads[receipt.sourceID]!, to:stagingURL(receipt.sourceID)) }
                try checkpoint(.prepared)
                for index in value.receipts.indices {
                    let id = value.receipts[index].sourceID, payload = plan.payloads[id]!
                    try checkpoint(.beforeWrite(id)); try checkProgress(value)
                    var raw = try requiredJournalBytes(value.id)
                    value.receipts[index].phase = "pending"; try saveJournal(value,expected:raw)
                    if let key = target.preferenceKey(id:id) { try target.preferences.restoreInsert(payload,key:key) }
                    else if let url = target.fileURL(id:id) { value.receipts[index].fileIdentity = try publishFile(from:stagingURL(id),to:url,expected:payload) }
                    else { throw CoreRestoreError.invalid("未知目标。") }
                    guard let readBack = try target.read(id:id), readBack.0 == payload else { throw CoreRestoreError.invalid("写后无法确认，保留事务门控。") }
                    raw = try requiredJournalBytes(value.id)
                    value.receipts[index].phase = "written"; try saveJournal(value,expected:raw)
                    try checkpoint(.afterWrite(id))
                }
                try checkpoint(.beforeCommit); try checkProgress(value)
                let raw = try requiredJournalBytes(value.id); value.state = "complete"
                try saveJournal(value,expected:raw)
            } catch {
                if let interrupted = error as? CoreRestoreError, case .simulatedInterruption = interrupted { throw error }
                if let (disk,raw) = try? journal(), disk.id == value.id {
                    var failed = disk; failed.state = "failed"; try? saveJournal(failed,expected:raw)
                }
                let reverted = (try? rollbackLocked()) ?? false
                throw CoreRestoreError.invalid(error.localizedDescription + (reverted ? "\n本次已确认创建的数据已回退；未覆盖已有数据，可重新选择备份。" : "\n无法安全回退全部条目，事务标记保留，业务加载已阻止；未删除变化或归属不明的数据。"))
            }
        }
    }

    func rollbackInterrupted() throws -> Bool { try withLock { try rollbackLocked() } }

    private func rollbackLocked() throws -> Bool {
        guard let (value,raw) = try journal(), ["failed","inProgress"].contains(value.state) else { return false }
        var safe = true
        for receipt in value.receipts.reversed() {
            guard let current = try target.read(id:receipt.sourceID) else { continue }
            guard receipt.phase == "written", CoreBackupService.digest(current.0) == receipt.hash else { safe = false; continue }
            if let key = target.preferenceKey(id:receipt.sourceID) {
                if try !target.preferences.restoreRemoveOwned(current.0,key:key) { safe = false }
            } else if let url = target.fileURL(id:receipt.sourceID), current.1 == receipt.fileIdentity {
                // Remove only the exact still-unmodified file recorded by this transaction.
                guard try target.read(id:receipt.sourceID)?.1 == receipt.fileIdentity else { safe = false; continue }
                try FileManager.default.removeItem(at:url)
            } else { safe = false }
        }
        guard safe else { return false }
        try cleanStaging(value)
        guard try requiredJournalBytes(value.id) == raw else { return false }
        try FileManager.default.removeItem(at:target.stateURL)
        return true
    }

    private func checkProgress(_ value: CoreRestoreJournal) throws {
        for id in CoreBackupSource.ids {
            let receipt = value.receipts.first { $0.sourceID == id }, current = try target.read(id:id)
            if receipt?.phase == "written" {
                guard let current, CoreBackupService.digest(current.0) == receipt?.hash,
                      target.preferenceKey(id:id) != nil || current.1 == receipt?.fileIdentity else { throw CoreRestoreError.invalid("恢复目标已被其他写入改变；未覆盖。") }
            } else if current != nil { throw CoreRestoreError.invalid("恢复目标出现新数据；未覆盖。") }
        }
        for key in CoreBackupSource.keys where try target.preferences.restoreRead(key + ".backup") != nil { throw CoreRestoreError.invalid("恢复目标出现业务备份，已中止。") }
        for (index,root) in target.roots.enumerated() {
            for name in [CoreRestoreTarget.fileNames[index]+".backup.json",CoreRestoreTarget.lockNames[index]] where try CoreBackupService.kind(root.appendingPathComponent(name)) != nil {
                throw CoreRestoreError.invalid("恢复目标出现备份或业务写锁，已中止。")
            }
        }
    }

    private func stagingURL(_ id:String) -> URL { target.transactionRoot.appendingPathComponent("payload-\(id).json") }
    private func cleanStaging(_ value:CoreRestoreJournal) throws {
        for receipt in value.receipts {
            let url = stagingURL(receipt.sourceID)
            if let current = try CoreBackupService.readFile(url,limit:CoreBackupService.sourceLimit) {
                guard CoreBackupService.digest(current.0) == receipt.hash else { throw CoreRestoreError.invalid("事务暂存资料已变化，未删除。") }
                try FileManager.default.removeItem(at:url)
            }
        }
    }
    private func requiredJournalBytes(_ id:UUID) throws -> Data {
        guard let (value,raw) = try journal(), value.id == id else { throw CoreRestoreError.invalid("事务标记变化，已停止。") }
        return raw
    }
    private func saveJournal(_ value:CoreRestoreJournal, expected:Data?) throws {
        let data = try JSONEncoder().encode(value)
        guard data.count <= Self.journalLimit else { throw CoreRestoreError.invalid("事务清单超限。") }
        let temporary = target.transactionRoot.appendingPathComponent(".state-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:temporary) }
        _ = try insertFile(data,to:temporary)
        guard try CoreBackupService.readFile(target.stateURL,limit:Self.journalLimit)?.0 == expected else { throw CoreRestoreError.invalid("事务标记出现并发变化。") }
        let flags:UInt32 = expected == nil ? UInt32(RENAME_EXCL) : 0
        guard renamex_np(temporary.path,target.stateURL.path,flags) == 0 else { throw CoreRestoreError.invalid("事务标记无法发布。") }
        try syncDirectory(target.transactionRoot)
    }
    /// Publish a complete staged file atomically without replacing any destination.
    /// Current production roots share Application Support's volume; EXDEV fails closed.
    private func publishFile(from staged:URL,to destination:URL,expected:Data) throws -> String {
        guard let source = try CoreBackupService.readFile(staged,limit:CoreBackupService.sourceLimit), source.0 == expected else {
            throw CoreRestoreError.invalid("事务暂存正文变化，未发布。")
        }
        try ensureDirectory(destination.deletingLastPathComponent())
        try CoreBackupService.checkParents(destination)
        guard link(staged.path,destination.path) == 0 else {
            throw CoreRestoreError.invalid("文件目标已存在、不可写或不在同一卷；未覆盖。")
        }
        try syncDirectory(destination.deletingLastPathComponent())
        guard let current = try CoreBackupService.readFile(destination,limit:CoreBackupService.sourceLimit), current.0 == expected,
              let original = try CoreBackupService.kind(staged), let installed = try CoreBackupService.kind(destination),
              original.st_dev == installed.st_dev, original.st_ino == installed.st_ino else {
            throw CoreRestoreError.invalid("文件原子发布结果无法确认，保留门控。")
        }
        return current.1
    }
    private func insertFile(_ data:Data,to url:URL) throws -> String {
        try ensureDirectory(url.deletingLastPathComponent())
        try CoreBackupService.checkParents(url)
        let fd = open(url.path,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0o600)
        guard fd >= 0 else { throw CoreRestoreError.invalid("目标文件已存在或无法创建，未覆盖。") }
        let handle = FileHandle(fileDescriptor:fd,closeOnDealloc:true)
        do { try handle.write(contentsOf:data);guard fsync(fd) == 0 else { throw CoreRestoreError.invalid("文件写入同步失败。") };try handle.close() }
        catch { try? handle.close();throw error }
        try syncDirectory(url.deletingLastPathComponent())
        guard let current = try CoreBackupService.readFile(url,limit:max(Self.journalLimit,CoreBackupService.sourceLimit)), current.0 == data else { throw CoreRestoreError.invalid("文件写后无法确认，保留门控。") }
        return current.1
    }
    private func ensureDirectory(_ url:URL) throws {
        try CoreBackupService.checkParents(url.appendingPathComponent("probe"))
        var path = URL(fileURLWithPath:"/")
        for component in url.path.split(separator:"/") {
            path.appendPathComponent(String(component))
            if let kind = try CoreBackupService.kind(path) {
                guard kind.st_mode & S_IFMT == S_IFDIR else { throw CoreRestoreError.invalid("拒绝恢复目标符号链接或非目录。") }
            } else if mkdir(path.path,0o700) != 0, errno != EEXIST { throw CoreRestoreError.invalid("无法创建恢复目录。") }
        }
    }
    private func syncDirectory(_ url:URL) throws {
        let fd = open(url.path,O_RDONLY|O_DIRECTORY|O_NOFOLLOW)
        guard fd >= 0 else { throw CoreRestoreError.invalid("无法同步目录。") }
        defer { close(fd) }
        guard fsync(fd) == 0 else { throw CoreRestoreError.invalid("目录同步失败，保留门控。") }
    }
    private func withLock<T>(_ operation:() throws -> T) throws -> T {
        try ensureDirectory(target.transactionRoot)
        let fd = open(target.transactionRoot.appendingPathComponent(".restore.lock").path,O_RDWR|O_CREAT|O_NOFOLLOW,0o600)
        guard fd >= 0 else { throw CoreRestoreError.invalid("恢复锁不可访问。") }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd,&info) == 0, info.st_mode & S_IFMT == S_IFREG, flock(fd,LOCK_EX|LOCK_NB) == 0 else { throw CoreRestoreError.invalid("恢复正在另一实例执行或锁状态无效。") }
        defer { flock(fd,LOCK_UN) }
        return try operation()
    }
}
