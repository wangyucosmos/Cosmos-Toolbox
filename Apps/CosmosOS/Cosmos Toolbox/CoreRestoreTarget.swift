import Foundation
import Darwin

nonisolated protocol CoreRestorePreferences: AnyObject {
    func restoreRead(_ key: String) throws -> Data?
    func restoreInsert(_ data: Data, key: String) throws
    func restoreRemoveOwned(_ data: Data, key: String) throws -> Bool
}

extension ZhuowangUserDefaultsDataSource: CoreRestorePreferences {
    func restoreRead(_ key: String) throws -> Data? { try coreBackupData(forKey: key) }
    func restoreInsert(_ data: Data, key: String) throws {
        let lock = ZhuowangPersistenceLockRegistry.lock(domainIdentifier: domainIdentifier, primaryKey: key)
        lock.lock(); defer { lock.unlock() }
        guard try coreBackupData(forKey: key) == nil else { throw CoreRestoreError.invalid("目标偏好已存在或变化，未覆盖。") }
        try coreRestoreSetAndSync(data, key: key)
    }
    func restoreRemoveOwned(_ data: Data, key: String) throws -> Bool {
        let lock = ZhuowangPersistenceLockRegistry.lock(domainIdentifier: domainIdentifier, primaryKey: key)
        lock.lock(); defer { lock.unlock() }
        guard let current = try coreBackupData(forKey: key) else { return true }
        guard current == data else { return false }
        try coreRestoreSetAndSync(nil, key: key)
        return true
    }
}

nonisolated struct CoreRestoreTarget {
    let preferences: any CoreRestorePreferences
    let roots: [URL]
    let transactionRoot: URL
    var stateURL: URL { transactionRoot.appendingPathComponent("state.json") }
    static let fileNames = ["templates", "learning", "handoffs"]
    static let lockNames = [".prompt.lock", ".learning.lock", ".handoffs.lock"]

    @MainActor static func resolve(configuration: ZhuowangStorePersistenceConfiguration) throws -> Self {
        guard let preferences = configuration.dataSource as? ZhuowangUserDefaultsDataSource else { throw CoreRestoreError.invalid("当前数据源不支持受控空环境恢复。") }
        let bundle = Bundle.main.bundleIdentifier, arguments = ProcessInfo.processInfo.arguments
#if DEBUG
        let isolated = configuration.isIsolated
#else
        let isolated = false
#endif
        let prompt = PromptVaultLocation.resolve(isIsolated: isolated, bundleIdentifier: bundle, arguments: arguments)
        let learning = LearningLocation.resolve(isIsolated: isolated, bundleIdentifier: bundle, arguments: arguments)
        let handoff = AIWorkspaceHandoffLocation.resolve(isIsolated: isolated, bundleIdentifier: bundle, arguments: arguments)
        guard let p = prompt.root, let l = learning.root, let h = handoff.root else { throw CoreRestoreError.invalid("恢复存储位置或隔离配置缺失，未回退正式数据。") }
        let control: URL
#if DEBUG
        if isolated {
            let flag = "--cosmos-core-restore-fixture-root", prefix = "/private/tmp/CosmosCoreRestorePhase1-"
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count,
                  let bundle, bundle.hasPrefix(CosmosDebugStorePersistenceBootstrap.isolatedBundleIdentifierPrefix) else { throw CoreRestoreError.invalid("缺少隔离恢复事务根，已停止启动。") }
            let path = arguments[index + 1]
            guard path.hasPrefix(prefix), UUID(uuidString: String(path.dropFirst(prefix.count))) != nil,
                  !path.contains("..") else { throw CoreRestoreError.invalid("隔离恢复事务根无效。") }
            control = URL(fileURLWithPath: path)
        } else {
            control = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Cosmos OS/CoreRestore")
        }
#else
        control = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Cosmos OS/CoreRestore")
#endif
        return Self(preferences: preferences, roots: [p,l,h], transactionRoot: control)
    }

    func fileURL(id: String) -> URL? {
        guard let index = CoreBackupSource.ids.firstIndex(of: id), index >= 7 else { return nil }
        return roots[index-7].appendingPathComponent(Self.fileNames[index-7] + ".json")
    }
    func preferenceKey(id: String) -> String? {
        guard let index = CoreBackupSource.ids.firstIndex(of: id), index < 7 else { return nil }
        return CoreBackupSource.keys[index]
    }
    func read(id: String) throws -> (Data, String?)? {
        if let key = preferenceKey(id: id) { return try preferences.restoreRead(key).map { ($0,nil) } }
        guard let url = fileURL(id: id) else { throw CoreRestoreError.invalid("未知恢复源。") }
        return try CoreBackupService.readFile(url, limit: CoreBackupService.sourceLimit).map { ($0.0,$0.1) }
    }
    func occupied() throws -> Bool {
        for key in CoreBackupSource.keys {
            if try preferences.restoreRead(key) != nil || preferences.restoreRead(key + ".backup") != nil { return true }
        }
        guard roots.count == 3 else { throw CoreRestoreError.invalid("恢复目标根配置无效。") }
        for (index, root) in roots.enumerated() {
            try CoreBackupService.checkParents(root.appendingPathComponent("probe"))
            for name in [Self.fileNames[index] + ".json", Self.fileNames[index] + ".backup.json", Self.lockNames[index]] {
                if try CoreBackupService.kind(root.appendingPathComponent(name)) != nil { return true }
            }
        }
        return false
    }
    func requireEmpty() throws {
        if try CoreBackupService.kind(transactionRoot) != nil {
            try CoreBackupService.checkParents(stateURL)
            let names = try FileManager.default.contentsOfDirectory(atPath: transactionRoot.path)
            guard Set(names).isSubset(of: [".restore.lock"]) else { throw CoreRestoreError.invalid("目标已有环境或未完成事务，拒绝覆盖。") }
        }
        guard try CoreBackupService.readFile(stateURL, limit: CoreRestoreService.journalLimit) == nil,
              !(try occupied()) else { throw CoreRestoreError.invalid("目标不是未建立的空环境；已有空载荷、主文件、备份、锁或环境标记均不能覆盖。") }
    }
}
