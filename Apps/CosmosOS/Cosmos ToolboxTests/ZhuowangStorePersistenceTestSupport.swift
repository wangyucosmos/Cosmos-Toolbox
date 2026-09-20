import XCTest
@testable import Cosmos_Toolbox

@MainActor
class ZhuowangStorePersistenceTestCase: XCTestCase {

    /// Every suite created by this test case has this prefix and ends in a
    /// fresh UUID, so cleanup can never touch the production domain or any
    /// suite the test did not create itself.
    ///
    /// Note: `removePersistentDomain` empties the domain, but cfprefsd still
    /// leaves a zero-key plist file per suite in `~/Library/Preferences`
    /// (observed to be re-created at process exit even when unlinked in
    /// `tearDown`). Those empty files carry no data and are removed manually
    /// under explicit authorisation; see the development log.
    static let testSuitePrefix =
        "com.wangyucosmos.Cosmos-Toolbox.StorePhase1.Tests."

    private var suiteNames: [String] = []

    override func tearDown() {
        for suiteName in suiteNames {
            UserDefaults(suiteName: suiteName)?
                .removePersistentDomain(
                    forName: suiteName
                )
        }

        suiteNames = []
        super.tearDown()
    }

    func makeSuite(
        label: String = "Store"
    ) throws -> (
        name: String,
        defaults: UserDefaults,
        configuration: ZhuowangStorePersistenceConfiguration
    ) {
        let suiteName =
            "\(Self.testSuitePrefix)\(label).\(UUID().uuidString)"

        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: suiteName)
        )

        defaults.removePersistentDomain(
            forName: suiteName
        )

        let configuration = try XCTUnwrap(
            ZhuowangStorePersistenceConfiguration
                .isolatedSuite(named: suiteName)
        )

        suiteNames.append(suiteName)

        return (
            suiteName,
            defaults,
            configuration
        )
    }


    /// Same as `makeSuite`, but every Store write into the suite is
    /// recorded so tests can assert "no write happened" instead of only
    /// "bytes look the same afterwards".
    func makeRecordedSuite(
        label: String = "Store"
    ) throws -> (
        name: String,
        defaults: UserDefaults,
        recorder: ZhuowangRecordingPersistenceDataSource,
        configuration: ZhuowangStorePersistenceConfiguration
    ) {
        let suite = try makeSuite(label: label)

        let recorder = ZhuowangRecordingPersistenceDataSource(
            wrapping: ZhuowangUserDefaultsDataSource(
                defaults: suite.defaults,
                domainIdentifier: suite.name
            )
        )

        return (
            suite.name,
            suite.defaults,
            recorder,
            isolatedConfiguration(dataSource: recorder)
        )
    }
}


// MARK: - Write Recording

/// One recorded `set(_:forKey:)` call.
nonisolated struct ZhuowangRecordedWrite: Equatable {

    let key: String
    let data: Data
}


/// Test-only decorator that forwards to any data source and records every
/// write (key + exact bytes). Reads are forwarded untouched.
final class ZhuowangRecordingPersistenceDataSource:
    ZhuowangPersistenceDataSource {

    private let base: any ZhuowangPersistenceDataSource

    private(set) var writeLog: [ZhuowangRecordedWrite] = []

    var writeCount: Int {
        writeLog.count
    }

    var domainIdentifier: String {
        base.domainIdentifier
    }

    init(
        wrapping base: any ZhuowangPersistenceDataSource
    ) {
        self.base = base
    }

    func writeCount(forKey key: String) -> Int {
        writeLog.filter { $0.key == key }.count
    }

    func writes(forKey key: String) -> [Data] {
        writeLog.filter { $0.key == key }.map(\.data)
    }

    func resetWriteLog() {
        writeLog = []
    }

    func data(
        forKey key: String
    ) -> Data? {
        base.data(forKey: key)
    }

    func set(
        _ data: Data,
        forKey key: String
    ) {
        writeLog.append(
            ZhuowangRecordedWrite(key: key, data: data)
        )
        base.set(data, forKey: key)
    }
}


// MARK: - In-Memory Data Source

/// Test-only in-memory data source with failure injection and a full
/// write log (write count, per-key count, key and exact bytes per write).
@MainActor
final class ZhuowangInMemoryPersistenceDataSource:
    ZhuowangPersistenceDataSource {

    let domainIdentifier: String

    var storage: [String: Data]

    /// Writes to these keys are replaced by unreadable bytes, simulating a
    /// store that accepted the call but did not persist the candidate.
    var corruptWritesForKeys: Set<String> = []

    private(set) var writeLog: [ZhuowangRecordedWrite] = []

    var writeCount: Int {
        writeLog.count
    }

    init(
        domainIdentifier: String = UUID().uuidString,
        storage: [String: Data] = [:]
    ) {
        self.domainIdentifier = domainIdentifier
        self.storage = storage
    }

    func writeCount(forKey key: String) -> Int {
        writeLog.filter { $0.key == key }.count
    }

    func writes(forKey key: String) -> [Data] {
        writeLog.filter { $0.key == key }.map(\.data)
    }

    func resetWriteLog() {
        writeLog = []
    }

    func data(
        forKey key: String
    ) -> Data? {
        storage[key]
    }

    func set(
        _ data: Data,
        forKey key: String
    ) {
        writeLog.append(
            ZhuowangRecordedWrite(key: key, data: data)
        )

        if corruptWritesForKeys.contains(key) {
            storage[key] = Data("corrupt-write".utf8)
        } else {
            storage[key] = data
        }
    }
}


// MARK: - Thread-Safe In-Memory Data Source (concurrency tests)

/// Test-only data source that may be used from many threads at once.
/// Besides the write log it tracks how many callers are inside
/// `data(forKey:)` / `set(_:forKey:)` simultaneously, so a test can prove
/// that the persistence helper's shared lock really serialises access.
nonisolated final class ZhuowangConcurrentInMemoryDataSource:
    ZhuowangPersistenceDataSource, @unchecked Sendable {

    let domainIdentifier: String

    private let stateLock = NSLock()
    private var storage: [String: Data]
    private var log: [ZhuowangRecordedWrite] = []
    private var inFlight = 0
    private var observedMaxInFlight = 0

    /// Artificial delay inside every access, widening the race window.
    let accessDelay: TimeInterval

    init(
        domainIdentifier: String = UUID().uuidString,
        storage: [String: Data] = [:],
        accessDelay: TimeInterval = 0.002
    ) {
        self.domainIdentifier = domainIdentifier
        self.storage = storage
        self.accessDelay = accessDelay
    }

    var writeLog: [ZhuowangRecordedWrite] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return log
    }

    var writeCount: Int {
        writeLog.count
    }

    func writeCount(forKey key: String) -> Int {
        writeLog.filter { $0.key == key }.count
    }

    /// The highest number of overlapping accesses ever observed.
    /// `1` means every access was fully serialised.
    var maxConcurrentAccesses: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return observedMaxInFlight
    }

    func snapshot(forKey key: String) -> Data? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storage[key]
    }

    private func enter() {
        stateLock.lock()
        inFlight += 1
        observedMaxInFlight = max(observedMaxInFlight, inFlight)
        stateLock.unlock()
    }

    private func leave() {
        stateLock.lock()
        inFlight -= 1
        stateLock.unlock()
    }

    func data(
        forKey key: String
    ) -> Data? {
        enter()
        defer { leave() }

        Thread.sleep(forTimeInterval: accessDelay)

        stateLock.lock()
        defer { stateLock.unlock() }
        return storage[key]
    }

    func set(
        _ data: Data,
        forKey key: String
    ) {
        enter()
        defer { leave() }

        Thread.sleep(forTimeInterval: accessDelay)

        stateLock.lock()
        defer { stateLock.unlock() }
        log.append(ZhuowangRecordedWrite(key: key, data: data))
        storage[key] = data
    }
}


// MARK: - Configuration Helper

@MainActor
func isolatedConfiguration(
    dataSource: any ZhuowangPersistenceDataSource
) -> ZhuowangStorePersistenceConfiguration {
    ZhuowangStorePersistenceConfiguration(
        dataSource: dataSource,
        isIsolated: true,
        isolationSuiteName:
            dataSource.domainIdentifier
    )
}


// MARK: - Hand-Written Fixtures

/// Raw persisted payloads written by hand, never produced by the
/// production `JSONEncoder()`. They deliberately use a non-canonical key
/// order and legal whitespace so that any decode → re-encode round trip
/// would change the bytes and be caught by a byte-for-byte assertion.
enum ZhuowangHandWrittenPayload {

    /// A Campaign whose `id` and dates are fixed.
    /// Dates are seconds since the Foundation reference date (2001-01-01).
    static let campaignID =
        UUID(uuidString: "7A1B2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D")!

    static let singleCampaign: Data = Data(
        """
        [ {
            "status" : "active",
            "notes" : "hand-written fixture",
            "endDate" : 200,
            "createdAt" : 100,
            "startDate" : 100,
            "name" : "Hand Written",
            "updatedAt" : 100,
            "scopeType" : "other",
            "englishName" : "Hand Written EN",
            "id" : "7A1B2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D"
        } ]
        """.utf8
    )

    /// A second, independent legacy-shaped Campaign payload: two items,
    /// optional keys present as null / absent, different spacing.
    static let legacyCampaigns: Data = Data(
        """
        [{"id":"11111111-2222-4333-8444-555555555555","scopeType":"province","provinceID":"10000000-0000-0000-0000-000000000001","moduleID":null,"name":"Legacy One","englishName":"","startDate":1000,"endDate":2000,"status":"planning","notes":"","createdAt":1000,"updatedAt":1000},
         {"updatedAt":3000,"createdAt":3000,"notes":"legacy two","status":"completed","endDate":4000,"startDate":3000,"englishName":"Two","name":"Legacy Two","scopeType":"national","id":"66666666-7777-4888-8999-AAAAAAAAAAAA"}]
        """.utf8
    )

    static let provinceID =
        UUID(uuidString: "20000000-0000-0000-0000-000000000009")!

    static let singleWorkspace: Data = Data(
        """
        {
          "categories" : [ { "icon" : "folder", "englishName" : "Category EN", "name" : "Category", "id" : "category" } ],
          "provinces"  : [ { "englishName" : "Province EN", "name" : "Province", "id" : "20000000-0000-0000-0000-000000000009" } ],
          "modules"    : [ { "usesProvinces" : true, "icon" : "folder", "englishName" : "Module EN", "name" : "Module", "id" : "module" } ]
        }
        """.utf8
    )

    /// A second, independent legacy-shaped Workspace payload.
    static let legacyWorkspace: Data = Data(
        """
        {"provinces":[{"id":"10000000-0000-0000-0000-000000000001","name":"河南","englishName":"Henan"},{"id":"10000000-0000-0000-0000-000000000002","name":"安徽","englishName":"Anhui"}],
         "modules":[{"id":"welfare","name":"福利中心","englishName":"Welfare Center","icon":"gift","usesProvinces":true}],
         "categories":[{"id":"overview","name":"总览","englishName":"Overview","icon":"square.grid.2x2"},{"id":"campaign","name":"活动","englishName":"Campaign","icon":"megaphone"}]}
        """.utf8
    )
}
