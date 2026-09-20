import Foundation


// MARK: - Public Store State

enum ZhuowangStorePersistenceState: Equatable {

    case healthy
    case lockedCorruptPrimary(hasValidBackup: Bool)
    case staleConflict
    case writeVerificationFailed

    var allowsMutations: Bool {
        self == .healthy
    }

    var userMessage: String? {
        switch self {
        case .healthy:
            return nil

        case .lockedCorruptPrimary(let hasValidBackup):
            if hasValidBackup {
                return "检测到有效备份，当前数据已锁定，尚未执行自动恢复。"
            }

            return "当前数据无法读取，Store 已锁定以防止覆盖原始数据。"

        case .staleConflict:
            return "检测到其他 Store 实例已更新数据。当前实例已锁定，未覆盖较新的内容。"

        case .writeVerificationFailed:
            // This state is reached from several paths (initial write,
            // encoding failure, backup write / read-back failure, primary
            // write / read-back failure), so the wording must stay true for
            // all of them: it neither promises the backup is valid nor that
            // the primary is unchanged.
            return "持久化校验失败，当前界面未发布本次变更。主数据或备份状态可能已经变化，Store 已锁定，请停止继续操作，并在重启前核对数据。"
        }
    }
}


enum ZhuowangStoreMutationFailure: Equatable {

    case invalidInput
    case itemNotFound
    case lockedCorruptPrimary(hasValidBackup: Bool)
    case staleConflict
    case writeVerificationFailed
}


enum ZhuowangStoreMutationResult: Equatable {

    case succeeded
    case rejected(ZhuowangStoreMutationFailure)

    var succeeded: Bool {
        self == .succeeded
    }

    var userMessage: String? {
        switch self {
        case .succeeded:
            return nil

        case .rejected(.invalidInput):
            return "输入内容无效，未保存任何修改。"

        case .rejected(.itemNotFound):
            return "目标数据已不存在，未保存任何修改。"

        case .rejected(
            .lockedCorruptPrimary(
                let hasValidBackup
            )
        ):
            return ZhuowangStorePersistenceState
                .lockedCorruptPrimary(
                    hasValidBackup:
                        hasValidBackup
                )
                .userMessage

        case .rejected(.staleConflict):
            return ZhuowangStorePersistenceState
                .staleConflict
                .userMessage

        case .rejected(
            .writeVerificationFailed
        ):
            return ZhuowangStorePersistenceState
                .writeVerificationFailed
                .userMessage
        }
    }
}


// MARK: - Data Source

// The persistence helper layer below is explicitly `nonisolated`: it is
// designed to be thread-safe on its own (see `ZhuowangPersistenceLockRegistry`)
// so that concurrency tests can exercise the real lock from many threads.
// The Stores that own it stay on the main actor (module default isolation).

nonisolated protocol ZhuowangPersistenceDataSource: AnyObject {

    var domainIdentifier: String { get }

    func data(forKey key: String) -> Data?

    func set(
        _ data: Data,
        forKey key: String
    )
}


nonisolated final class ZhuowangUserDefaultsDataSource:
    ZhuowangPersistenceDataSource {

    let domainIdentifier: String

    private let defaults: UserDefaults

    init(
        defaults: UserDefaults,
        domainIdentifier: String
    ) {
        self.defaults = defaults
        self.domainIdentifier = domainIdentifier
    }

    func data(
        forKey key: String
    ) -> Data? {
        defaults.data(forKey: key)
    }

    func set(
        _ data: Data,
        forKey key: String
    ) {
        defaults.set(data, forKey: key)
    }
}


struct ZhuowangStorePersistenceConfiguration {

    /// The formal production UserDefaults domain.
    ///
    /// This is intentionally a fixed literal rather than
    /// `Bundle.main.bundleIdentifier`: when the App is launched under a
    /// temporary Bundle ID for isolated acceptance, the guard below must
    /// still reject any attempt to point an "isolated" suite at the formal
    /// production domain. Do not derive this value at runtime.
    static let productionDomainIdentifier =
        "com.wangyucosmos.Cosmos-Toolbox"

    let dataSource: any ZhuowangPersistenceDataSource

    var domainIdentifier: String {
        dataSource.domainIdentifier
    }

    static var production: ZhuowangStorePersistenceConfiguration {
        ZhuowangStorePersistenceConfiguration(
            dataSource: ZhuowangUserDefaultsDataSource(
                defaults: .standard,
                domainIdentifier: productionDomainIdentifier
            )
        )
    }

#if DEBUG
    // Isolation metadata only exists in DEBUG builds. Release builds have
    // exactly one configuration (production) and no suite-injection API.

    let isIsolated: Bool
    let isolationSuiteName: String?

    /// The temporary Bundle ID the App was launched under when the
    /// isolated suite was accepted. `nil` for unit-test configurations
    /// that never went through the DEBUG bootstrap.
    let isolationBundleIdentifier: String?

    init(
        dataSource: any ZhuowangPersistenceDataSource,
        isIsolated: Bool = false,
        isolationSuiteName: String? = nil,
        isolationBundleIdentifier: String? = nil
    ) {
        self.dataSource = dataSource
        self.isIsolated = isIsolated
        self.isolationSuiteName = isolationSuiteName
        self.isolationBundleIdentifier = isolationBundleIdentifier
    }

    static func isolatedSuite(
        named suiteName: String,
        bundleIdentifier: String? = nil,
        defaultsFactory: (String) -> UserDefaults? = {
            UserDefaults(suiteName: $0)
        }
    ) -> ZhuowangStorePersistenceConfiguration? {

        guard
            suiteName != productionDomainIdentifier,
            let defaults = defaultsFactory(suiteName)
        else {
            return nil
        }

        return ZhuowangStorePersistenceConfiguration(
            dataSource: ZhuowangUserDefaultsDataSource(
                defaults: defaults,
                domainIdentifier: suiteName
            ),
            isIsolated: true,
            isolationSuiteName: suiteName,
            isolationBundleIdentifier: bundleIdentifier
        )
    }
#else
    init(
        dataSource: any ZhuowangPersistenceDataSource
    ) {
        self.dataSource = dataSource
    }
#endif
}


#if DEBUG
enum CosmosDebugStorePersistenceBootstrap {

    static let suiteArgument =
        "--cosmos-store-phase1-suite"

    static let suitePrefix =
        "com.wangyucosmos.Cosmos-Toolbox.StorePhase1.UI."

    /// Only an App whose Bundle ID starts with this prefix may accept an
    /// isolated suite. Campaign / Workspace Stores read the injected suite,
    /// but the Workflow and AI Stores still use `UserDefaults.standard`,
    /// i.e. the domain of the *running Bundle ID*. Accepting a suite under
    /// the production Bundle ID would therefore show an isolation banner
    /// while those Stores silently touch the formal domain.
    static let isolatedBundleIdentifierPrefix =
        "com.wangyucosmos.cosmostoolbox.persistenceui."

    static let blockedBundleMessage =
        "检测到隔离suite参数，但当前App不是获准的临时UI验收Bundle，已阻止启动。"

    case ready(ZhuowangStorePersistenceConfiguration)
    case blocked(String)

    static func resolve(
        arguments: [String] =
            ProcessInfo.processInfo.arguments,
        bundleIdentifier: String? =
            Bundle.main.bundleIdentifier,
        defaultsFactory: (String) -> UserDefaults? = {
            UserDefaults(suiteName: $0)
        }
    ) -> CosmosDebugStorePersistenceBootstrap {

        guard
            let argumentIndex =
                arguments.firstIndex(
                    of: suiteArgument
                )
        else {
            return .ready(.production)
        }

        let valueIndex =
            arguments.index(after: argumentIndex)

        guard valueIndex < arguments.endIndex else {
            return .blocked(
                "已指定 Store Phase 1 隔离参数，但缺少 suite 名称。为保护正式数据，Workspace 已停止加载。"
            )
        }

        // An isolated suite is only honoured inside an isolated Bundle.
        // The production Bundle ID, an empty / unreadable Bundle ID, or any
        // Bundle ID outside the temporary UI prefix is refused *before* the
        // suite name is examined and before any factory call.
        guard
            let bundleIdentifier,
            !bundleIdentifier.isEmpty,
            bundleIdentifier !=
                ZhuowangStorePersistenceConfiguration
                .productionDomainIdentifier,
            bundleIdentifier.hasPrefix(
                isolatedBundleIdentifierPrefix
            )
        else {
            return .blocked(blockedBundleMessage)
        }

        let suiteName = arguments[valueIndex]

        guard
            suiteName.hasPrefix(suitePrefix),
            suiteName !=
                ZhuowangStorePersistenceConfiguration
                .productionDomainIdentifier
        else {
            return .blocked(
                "Store Phase 1 suite 名称无效。为保护正式数据，Workspace 已停止加载。"
            )
        }

        let uuidText =
            String(
                suiteName.dropFirst(
                    suitePrefix.count
                )
            )

        guard UUID(uuidString: uuidText) != nil else {
            return .blocked(
                "Store Phase 1 suite 必须以随机 UUID 结尾。为保护正式数据，Workspace 已停止加载。"
            )
        }

        guard
            let configuration =
                ZhuowangStorePersistenceConfiguration
                .isolatedSuite(
                    named: suiteName,
                    bundleIdentifier: bundleIdentifier,
                    defaultsFactory:
                        defaultsFactory
                )
        else {
            return .blocked(
                "无法创建 Store Phase 1 隔离 suite。未回退到正式 UserDefaults。"
            )
        }

        return .ready(configuration)
    }
}
#endif


// MARK: - Protected Persistence

nonisolated struct ZhuowangPersistenceLockKey: Hashable {

    let domainIdentifier: String
    let primaryKey: String
}


/// Process-wide registry of per-(domain, primary key) locks.
///
/// The enum is `nonisolated` so the helper can be used from any thread;
/// the global `locks` dictionary is therefore only ever read or mutated
/// while `registryLock` is held (see `lock(domainIdentifier:primaryKey:)`).
/// Returned `NSLock` instances are never removed, so a caller may keep one.
nonisolated enum ZhuowangPersistenceLockRegistry {

    private static let registryLock = NSLock()

    /// Guarded exclusively by `registryLock`.
    private static var locks:
        [ZhuowangPersistenceLockKey: NSLock] = [:]

    static func lock(
        domainIdentifier: String,
        primaryKey: String
    ) -> NSLock {

        let key = ZhuowangPersistenceLockKey(
            domainIdentifier:
                domainIdentifier,
            primaryKey:
                primaryKey
        )

        registryLock.lock()
        defer { registryLock.unlock() }

        if let existing = locks[key] {
            return existing
        }

        let lock = NSLock()
        locks[key] = lock
        return lock
    }
}


nonisolated enum ZhuowangPersistenceLoadResult<Value> {

    case loaded(
        value: Value,
        baselineData: Data
    )

    case lockedCorruptPrimary(
        hasValidBackup: Bool
    )

    case writeVerificationFailed
}


nonisolated enum ZhuowangPersistenceTransactionResult<Value> {

    case committed(
        value: Value,
        baselineData: Data
    )

    case rejectedMutation

    case lockedCorruptPrimary(
        hasValidBackup: Bool
    )

    case staleConflict
    case writeVerificationFailed
}


nonisolated struct ZhuowangProtectedPersistence<Value: Codable> {

    let dataSource: any ZhuowangPersistenceDataSource
    let primaryKey: String
    let backupKey: String

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var sharedLock: NSLock {
        ZhuowangPersistenceLockRegistry.lock(
            domainIdentifier:
                dataSource.domainIdentifier,
            primaryKey:
                primaryKey
        )
    }

    func loadOrInitialize(
        defaultValue: @autoclosure () -> Value
    ) -> ZhuowangPersistenceLoadResult<Value> {

        sharedLock.lock()
        defer { sharedLock.unlock() }

        if let primaryData =
            dataSource.data(
                forKey: primaryKey
            ) {

            guard
                let decoded =
                    try? decoder.decode(
                        Value.self,
                        from: primaryData
                    )
            else {
                return .lockedCorruptPrimary(
                    hasValidBackup:
                        hasValidBackup()
                )
            }

            return .loaded(
                value: decoded,
                baselineData: primaryData
            )
        }

        let initialValue = defaultValue()

        guard
            let encoded =
                try? encoder.encode(
                    initialValue
                )
        else {
            return .writeVerificationFailed
        }

        dataSource.set(
            encoded,
            forKey: primaryKey
        )

        guard
            let readBack =
                dataSource.data(
                    forKey: primaryKey
                ),
            readBack == encoded,
            let decoded =
                try? decoder.decode(
                    Value.self,
                    from: readBack
                )
        else {
            return .writeVerificationFailed
        }

        return .loaded(
            value: decoded,
            baselineData: readBack
        )
    }

    func transact(
        baselineData: Data,
        mutate: (inout Value) -> Bool
    ) -> ZhuowangPersistenceTransactionResult<Value> {

        sharedLock.lock()
        defer { sharedLock.unlock() }

        guard
            let currentData =
                dataSource.data(
                    forKey: primaryKey
                ),
            currentData == baselineData
        else {
            return .staleConflict
        }

        guard
            var candidate =
                try? decoder.decode(
                    Value.self,
                    from: currentData
                )
        else {
            return .lockedCorruptPrimary(
                hasValidBackup:
                    hasValidBackup()
            )
        }

        guard mutate(&candidate) else {
            return .rejectedMutation
        }

        guard
            let candidateData =
                try? encoder.encode(
                    candidate
                )
        else {
            return .writeVerificationFailed
        }

        // The current primary has already decoded successfully, so it is safe
        // to become the single last-known-good backup.
        dataSource.set(
            currentData,
            forKey: backupKey
        )

        guard
            dataSource.data(
                forKey: backupKey
            ) == currentData
        else {
            return .writeVerificationFailed
        }

        dataSource.set(
            candidateData,
            forKey: primaryKey
        )

        guard
            let readBack =
                dataSource.data(
                    forKey: primaryKey
                ),
            readBack == candidateData,
            let decoded =
                try? decoder.decode(
                    Value.self,
                    from: readBack
                )
        else {
            return .writeVerificationFailed
        }

        return .committed(
            value: decoded,
            baselineData: readBack
        )
    }

    private func hasValidBackup() -> Bool {

        guard
            let backupData =
                dataSource.data(
                    forKey: backupKey
                )
        else {
            return false
        }

        return (
            try? decoder.decode(
                Value.self,
                from: backupData
            )
        ) != nil
    }
}
