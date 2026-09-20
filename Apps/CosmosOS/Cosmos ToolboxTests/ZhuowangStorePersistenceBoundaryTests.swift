import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class ZhuowangStorePersistenceBoundaryTests:
    ZhuowangStorePersistenceTestCase {

    func testCampaignAndWorkspaceKeysDoNotPolluteEachOther() throws {
        let suite = try makeSuite(label: "KeyIsolation")
        let campaignStore = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )
        let workspaceBefore = suite.defaults.data(
            forKey: ZhuowangWorkspaceStore.storageKey
        )

        XCTAssertEqual(
            campaignStore.addCampaign(
                name: "Campaign",
                scopeType: .other,
                startDate: Date(),
                endDate: Date()
            ),
            .succeeded
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            workspaceBefore
        )
        XCTAssertNil(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.backupKey
            )
        )
    }


    func testInjectedSuiteIsTheExactStoreReadSource() throws {
        let injected = try makeSuite(label: "Injected")
        let unrelated = try makeSuite(label: "Unrelated")
        let unrelatedCampaign = ZhuowangCampaign(
            name: "Wrong Domain",
            scopeType: .other,
            startDate: Date(),
            endDate: Date()
        )
        unrelated.defaults.set(
            try JSONEncoder().encode([
                unrelatedCampaign
            ]),
            forKey: ZhuowangCampaignStore.storageKey
        )

        let store = ZhuowangCampaignStore(
            persistenceConfiguration:
                injected.configuration
        )

        XCTAssertTrue(store.campaigns.isEmpty)
        XCTAssertEqual(
            store.persistenceConfiguration
                .domainIdentifier,
            injected.name
        )
    }


    func testSimulatedHistoricalSandboxDomainDoesNotAffectInjectedStore() throws {
        let historical = try makeSuite(label: "HistoricalSandbox")
        let injected = try makeSuite(label: "FormalInjected")
        historical.defaults.set(
            Data("historical-corrupt".utf8),
            forKey: ZhuowangWorkspaceStore.storageKey
        )

        let store = ZhuowangWorkspaceStore(
            persistenceConfiguration:
                injected.configuration
        )

        XCTAssertEqual(store.persistenceState, .healthy)
        XCTAssertFalse(store.provinces.isEmpty)
        XCTAssertEqual(
            historical.defaults.data(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            Data("historical-corrupt".utf8)
        )
    }


    func testSameKeyUsesSharedLockWhileDomainAndKeyRemainIsolated() {
        let first = ZhuowangPersistenceLockRegistry.lock(
            domainIdentifier: "domain-a",
            primaryKey: "key-a"
        )
        let same = ZhuowangPersistenceLockRegistry.lock(
            domainIdentifier: "domain-a",
            primaryKey: "key-a"
        )
        let differentDomain = ZhuowangPersistenceLockRegistry.lock(
            domainIdentifier: "domain-b",
            primaryKey: "key-a"
        )
        let differentKey = ZhuowangPersistenceLockRegistry.lock(
            domainIdentifier: "domain-a",
            primaryKey: "key-b"
        )

        XCTAssertTrue(first === same)
        XCTAssertFalse(first === differentDomain)
        XCTAssertFalse(first === differentKey)
    }


    func testSameKeyInDifferentSuitesDoesNotConflict() throws {
        let firstSuite = try makeSuite(label: "SuiteOne")
        let secondSuite = try makeSuite(label: "SuiteTwo")
        let first = ZhuowangCampaignStore(
            persistenceConfiguration:
                firstSuite.configuration
        )
        let second = ZhuowangCampaignStore(
            persistenceConfiguration:
                secondSuite.configuration
        )

        XCTAssertEqual(
            first.addCampaign(
                name: "First",
                scopeType: .other,
                startDate: Date(),
                endDate: Date()
            ),
            .succeeded
        )
        XCTAssertEqual(
            second.addCampaign(
                name: "Second",
                scopeType: .other,
                startDate: Date(),
                endDate: Date()
            ),
            .succeeded
        )
    }


#if DEBUG
    private var isolatedBundleID: String {
        CosmosDebugStorePersistenceBootstrap
            .isolatedBundleIdentifierPrefix
            + "run-unit-test"
    }

    private var isolatedSuiteName: String {
        CosmosDebugStorePersistenceBootstrap.suitePrefix
            + UUID().uuidString
    }

    private var productionBundleID: String {
        ZhuowangStorePersistenceConfiguration
            .productionDomainIdentifier
    }

    /// Counts factory calls; the factory itself always returns nil.
    private final class FactoryCalls {
        var count = 0

        var factory: (String) -> UserDefaults? {
            { [self] _ in
                count += 1
                return nil
            }
        }
    }


    // MARK: No suite argument → production, whatever the Bundle ID

    func testDebugBootstrapWithoutArgumentUsesProductionConfiguration() {
        for bundleID in [
            productionBundleID,
            isolatedBundleID,
            "com.example.unrelated",
            "",
            nil
        ] as [String?] {
            let result =
                CosmosDebugStorePersistenceBootstrap.resolve(
                    arguments: ["Cosmos Toolbox"],
                    bundleIdentifier: bundleID
                )

            guard case .ready(let configuration) = result else {
                return XCTFail(
                    "Expected production configuration for bundle \(String(describing: bundleID))"
                )
            }

            // By design a launch without the suite argument is a normal
            // production launch: Debug development builds and the formal
            // Bundle both read `UserDefaults.standard`.
            XCTAssertFalse(configuration.isIsolated)
            XCTAssertNil(configuration.isolationSuiteName)
            XCTAssertNil(configuration.isolationBundleIdentifier)
            XCTAssertEqual(
                configuration.domainIdentifier,
                productionBundleID
            )
        }
    }


    // MARK: Isolated Bundle + valid suite → isolated

    func testDebugBootstrapAcceptsIsolatedBundleWithUUIDSuite() {
        let suiteName = isolatedSuiteName
        var requestedNames: [String] = []
        let result =
            CosmosDebugStorePersistenceBootstrap.resolve(
                arguments: [
                    "Cosmos Toolbox",
                    CosmosDebugStorePersistenceBootstrap
                        .suiteArgument,
                    suiteName
                ],
                bundleIdentifier: isolatedBundleID,
                defaultsFactory: { name in
                    requestedNames.append(name)
                    return UserDefaults(suiteName: name)
                }
            )

        guard case .ready(let configuration) = result else {
            return XCTFail("Expected isolated configuration")
        }

        XCTAssertTrue(configuration.isIsolated)
        XCTAssertEqual(configuration.domainIdentifier, suiteName)
        XCTAssertEqual(configuration.isolationSuiteName, suiteName)
        XCTAssertEqual(
            configuration.isolationBundleIdentifier,
            isolatedBundleID
        )
        XCTAssertEqual(requestedNames, [suiteName])
        UserDefaults(suiteName: suiteName)?
            .removePersistentDomain(
                forName: suiteName
            )
    }


    // MARK: Production Bundle + valid suite → blocked, factory untouched

    func testDebugBootstrapProductionBundleWithValidSuiteIsBlocked() {
        let calls = FactoryCalls()
        let result =
            CosmosDebugStorePersistenceBootstrap.resolve(
                arguments: [
                    "Cosmos Toolbox",
                    CosmosDebugStorePersistenceBootstrap
                        .suiteArgument,
                    isolatedSuiteName
                ],
                bundleIdentifier: productionBundleID,
                defaultsFactory: calls.factory
            )

        guard case .blocked(let message) = result else {
            return XCTFail("Expected blocked bootstrap")
        }
        XCTAssertEqual(
            message,
            CosmosDebugStorePersistenceBootstrap.blockedBundleMessage
        )
        XCTAssertEqual(calls.count, 0)
    }


    // MARK: Unrelated / empty / nil Bundle + valid suite → blocked

    func testDebugBootstrapNonIsolatedBundlesWithValidSuiteAreBlocked() {
        for bundleID in [
            "com.example.unrelated",
            "com.wangyucosmos.Cosmos-ToolboxTests",
            "com.wangyucosmos.cosmostoolbox",
            "",
            nil
        ] as [String?] {
            let calls = FactoryCalls()
            let result =
                CosmosDebugStorePersistenceBootstrap.resolve(
                    arguments: [
                        "Cosmos Toolbox",
                        CosmosDebugStorePersistenceBootstrap
                            .suiteArgument,
                        isolatedSuiteName
                    ],
                    bundleIdentifier: bundleID,
                    defaultsFactory: calls.factory
                )

            guard case .blocked(let message) = result else {
                return XCTFail(
                    "Expected blocked bootstrap for bundle \(String(describing: bundleID))"
                )
            }
            XCTAssertEqual(
                message,
                CosmosDebugStorePersistenceBootstrap.blockedBundleMessage
            )
            XCTAssertEqual(calls.count, 0)
        }
    }


    // MARK: Isolated Bundle + invalid suite → blocked

    func testDebugBootstrapIsolatedBundleWithInvalidSuiteIsBlocked() {
        for suite in [
            "invalid-suite",
            CosmosDebugStorePersistenceBootstrap.suitePrefix
                + "not-a-uuid",
            productionBundleID
        ] {
            let calls = FactoryCalls()
            let result =
                CosmosDebugStorePersistenceBootstrap.resolve(
                    arguments: [
                        "Cosmos Toolbox",
                        CosmosDebugStorePersistenceBootstrap
                            .suiteArgument,
                        suite
                    ],
                    bundleIdentifier: isolatedBundleID,
                    defaultsFactory: calls.factory
                )

            guard case .blocked = result else {
                return XCTFail("Expected blocked bootstrap for suite \(suite)")
            }
            XCTAssertEqual(calls.count, 0)
        }
    }


    func testDebugBootstrapMissingSuiteValueFailsClosed() {
        for bundleID in [productionBundleID, isolatedBundleID] {
            let calls = FactoryCalls()
            let result =
                CosmosDebugStorePersistenceBootstrap.resolve(
                    arguments: [
                        "Cosmos Toolbox",
                        CosmosDebugStorePersistenceBootstrap
                            .suiteArgument
                    ],
                    bundleIdentifier: bundleID,
                    defaultsFactory: calls.factory
                )

            guard case .blocked(let message) = result else {
                return XCTFail("Expected blocked bootstrap")
            }
            XCTAssertFalse(message.isEmpty)
            XCTAssertEqual(calls.count, 0)
        }
    }


    func testDebugBootstrapProductionDomainAsSuiteFailsClosedAtEveryLayer() {
        // The configuration-level guard is independent of the bootstrap:
        // an isolated suite may never name the production domain.
        XCTAssertNil(
            ZhuowangStorePersistenceConfiguration.isolatedSuite(
                named: productionBundleID,
                defaultsFactory: { _ in
                    XCTFail("Factory must not be called for production")
                    return nil
                }
            )
        )
    }


    func testDebugBootstrapFactoryFailureDoesNotFallBackToStandard() {
        let suiteName = isolatedSuiteName
        var requestedName: String?
        let result =
            CosmosDebugStorePersistenceBootstrap.resolve(
                arguments: [
                    "Cosmos Toolbox",
                    CosmosDebugStorePersistenceBootstrap
                        .suiteArgument,
                    suiteName
                ],
                bundleIdentifier: isolatedBundleID,
                defaultsFactory: { name in
                    requestedName = name
                    return nil
                }
            )

        XCTAssertEqual(requestedName, suiteName)
        guard case .blocked = result else {
            return XCTFail("Expected blocked bootstrap")
        }
    }


    // MARK: Blocked result carries no configuration

    func testBlockedBootstrapCarriesNoConfiguration() {
        let result =
            CosmosDebugStorePersistenceBootstrap.resolve(
                arguments: [
                    "Cosmos Toolbox",
                    CosmosDebugStorePersistenceBootstrap
                        .suiteArgument,
                    isolatedSuiteName
                ],
                bundleIdentifier: productionBundleID
            )

        // `.blocked` only carries a message. The root view renders
        // `CosmosStoreBootstrapBlockedView` for it and never constructs
        // `DashboardView`, so no Campaign / Workspace / Workflow Store can
        // be created on this path (see `CosmosRootView.body`).
        if case .ready = result {
            XCTFail("Blocked bootstrap must not yield a configuration")
        }
    }
#endif
}
