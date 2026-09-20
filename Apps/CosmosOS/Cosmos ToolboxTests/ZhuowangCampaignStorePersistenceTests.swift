import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class ZhuowangCampaignStorePersistenceTests:
    ZhuowangStorePersistenceTestCase {

    func testMissingPrimaryInitializesOnlyOnce() throws {
        let suite = try makeRecordedSuite(label: "CampaignInit")

        let first = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )
        let firstData = try XCTUnwrap(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.storageKey
            )
        )

        // First load: the primary was missing, so exactly one primary
        // write is expected and no backup write.
        XCTAssertEqual(first.persistenceState, .healthy)
        XCTAssertEqual(
            suite.recorder.writeCount(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            1
        )
        XCTAssertEqual(
            suite.recorder.writeCount(
                forKey: ZhuowangCampaignStore.backupKey
            ),
            0
        )
        XCTAssertEqual(
            suite.recorder.writes(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            [firstData]
        )

        let writesBeforeSecond = suite.recorder.writeCount

        let second = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )

        // Second load: primary exists → zero additional writes of any kind.
        XCTAssertEqual(second.persistenceState, .healthy)
        XCTAssertEqual(
            suite.recorder.writeCount - writesBeforeSecond,
            0
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            firstData
        )
        XCTAssertNil(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.backupKey
            )
        )
    }


    func testValidPayloadLoadsWithoutReencodingOrBackup() throws {
        let suite = try makeRecordedSuite(label: "CampaignLoad")
        let raw = ZhuowangHandWrittenPayload.singleCampaign

        // Sanity: the fixture must not already be what the production
        // encoder would produce, otherwise this test proves nothing.
        let decoded = try JSONDecoder().decode(
            [ZhuowangCampaign].self,
            from: raw
        )
        XCTAssertNotEqual(
            try JSONEncoder().encode(decoded),
            raw
        )

        suite.defaults.set(
            raw,
            forKey: ZhuowangCampaignStore.storageKey
        )

        let store = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )

        XCTAssertEqual(store.persistenceState, .healthy)
        XCTAssertEqual(store.campaigns.count, 1)
        XCTAssertEqual(
            store.campaigns.first?.id,
            ZhuowangHandWrittenPayload.campaignID
        )
        XCTAssertEqual(store.campaigns.first?.name, "Hand Written")
        XCTAssertEqual(store.campaigns.first?.status, .active)

        // Byte-for-byte unchanged and no write at all.
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            raw
        )
        XCTAssertEqual(
            suite.recorder.writeCount(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            0
        )
        XCTAssertEqual(
            suite.recorder.writeCount(
                forKey: ZhuowangCampaignStore.backupKey
            ),
            0
        )
        XCTAssertEqual(suite.recorder.writeCount, 0)
        XCTAssertNil(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.backupKey
            )
        )
    }


    func testLegacyHandWrittenPayloadLoadsWithoutMigration() throws {
        let suite = try makeRecordedSuite(label: "CampaignLegacy")
        let raw = ZhuowangHandWrittenPayload.legacyCampaigns

        // Precondition: the fixture must differ from the production
        // encoding, otherwise a re-encode could not be detected.
        XCTAssertNotEqual(
            try JSONEncoder().encode(
                try JSONDecoder().decode(
                    [ZhuowangCampaign].self,
                    from: raw
                )
            ),
            raw
        )

        suite.defaults.set(
            raw,
            forKey: ZhuowangCampaignStore.storageKey
        )

        let store = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )

        XCTAssertEqual(store.persistenceState, .healthy)
        XCTAssertEqual(store.campaigns.count, 2)
        // Sorted by updatedAt descending: "Legacy Two" (3000) first.
        XCTAssertEqual(
            store.campaigns.map(\.name),
            ["Legacy Two", "Legacy One"]
        )
        XCTAssertEqual(
            store.campaigns.last?.provinceID,
            UUID(uuidString: "10000000-0000-0000-0000-000000000001")
        )
        XCTAssertNil(store.campaigns.last?.moduleID)
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            raw
        )
        XCTAssertEqual(suite.recorder.writeCount, 0)
    }


    func testCorruptPrimaryWithoutBackupLocksAndPreservesBytes() throws {
        let suite = try makeRecordedSuite(label: "CampaignCorrupt")
        let corrupt = Data("not-json".utf8)
        suite.defaults.set(
            corrupt,
            forKey: ZhuowangCampaignStore.storageKey
        )

        let store = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )

        XCTAssertEqual(
            store.persistenceState,
            .lockedCorruptPrimary(hasValidBackup: false)
        )
        XCTAssertTrue(store.campaigns.isEmpty)
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            corrupt
        )
        XCTAssertEqual(suite.recorder.writeCount, 0)
    }


    func testCorruptPrimaryAndCorruptBackupLockWithoutValidBackup() throws {
        let suite = try makeRecordedSuite(label: "CampaignBothCorrupt")
        let corruptPrimary = Data("{broken primary".utf8)
        let corruptBackup = Data("[broken backup".utf8)
        suite.defaults.set(
            corruptPrimary,
            forKey: ZhuowangCampaignStore.storageKey
        )
        suite.defaults.set(
            corruptBackup,
            forKey: ZhuowangCampaignStore.backupKey
        )

        let store = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )

        XCTAssertEqual(
            store.persistenceState,
            .lockedCorruptPrimary(hasValidBackup: false)
        )
        XCTAssertTrue(store.campaigns.isEmpty)
        XCTAssertEqual(
            store.addCampaign(
                name: "Rejected",
                scopeType: .other,
                startDate: Date(),
                endDate: Date()
            ),
            .rejected(.lockedCorruptPrimary(hasValidBackup: false))
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            corruptPrimary
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.backupKey
            ),
            corruptBackup
        )
        XCTAssertEqual(suite.recorder.writeCount, 0)
    }


    func testCorruptPrimaryRecognizesValidBackupWithoutRestoringIt() throws {
        let suite = try makeSuite(label: "CampaignBackup")
        let corrupt = Data("not-json".utf8)
        let backup = try JSONEncoder().encode([
            makeCampaign(name: "Last Good")
        ])
        suite.defaults.set(
            corrupt,
            forKey: ZhuowangCampaignStore.storageKey
        )
        suite.defaults.set(
            backup,
            forKey: ZhuowangCampaignStore.backupKey
        )

        let store = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )

        XCTAssertEqual(
            store.persistenceState,
            .lockedCorruptPrimary(hasValidBackup: true)
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            corrupt
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.backupKey
            ),
            backup
        )
        XCTAssertTrue(store.campaigns.isEmpty)
    }


    func testLockedCreateUpdateAndDeletePreserveMemoryPrimaryAndBackup() throws {
        let suite = try makeSuite(label: "CampaignLocked")
        let corrupt = Data("not-json".utf8)
        let backup = try JSONEncoder().encode([
            makeCampaign(name: "Last Good")
        ])
        suite.defaults.set(
            corrupt,
            forKey: ZhuowangCampaignStore.storageKey
        )
        suite.defaults.set(
            backup,
            forKey: ZhuowangCampaignStore.backupKey
        )
        let store = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )
        let sample = makeCampaign(name: "Rejected")

        let createResult = store.addCampaign(
            name: sample.name,
            scopeType: sample.scopeType,
            startDate: sample.startDate,
            endDate: sample.endDate
        )
        let updateResult = store.updateCampaign(sample)
        let deleteResult = store.deleteCampaign(id: sample.id)

        let expected: ZhuowangStoreMutationResult =
            .rejected(
                .lockedCorruptPrimary(
                    hasValidBackup: true
                )
            )
        XCTAssertEqual(createResult, expected)
        XCTAssertEqual(updateResult, expected)
        XCTAssertEqual(deleteResult, expected)
        XCTAssertTrue(store.campaigns.isEmpty)
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            corrupt
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.backupKey
            ),
            backup
        )
    }


    func testSuccessfulMutationBacksUpPreviousValidPrimary() throws {
        let suite = try makeSuite(label: "CampaignMutation")
        let original = try JSONEncoder().encode([
            makeCampaign(name: "Original")
        ])
        suite.defaults.set(
            original,
            forKey: ZhuowangCampaignStore.storageKey
        )
        let store = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )

        let result = store.addCampaign(
            name: "New",
            scopeType: .other,
            startDate: Date(),
            endDate: Date()
        )

        XCTAssertEqual(result, .succeeded)
        XCTAssertEqual(store.campaigns.count, 2)
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.backupKey
            ),
            original
        )
        let persisted = try JSONDecoder().decode(
            [ZhuowangCampaign].self,
            from: try XCTUnwrap(
                suite.defaults.data(
                    forKey: ZhuowangCampaignStore.storageKey
                )
            )
        )
        XCTAssertEqual(persisted, store.campaigns)
    }


    func testSuccessfulUpdatePersistsAndSurvivesRestart() throws {
        let suite = try makeSuite(label: "CampaignUpdate")
        let original = makeCampaign(name: "Before")
        let originalData = try JSONEncoder().encode([original])
        suite.defaults.set(
            originalData,
            forKey: ZhuowangCampaignStore.storageKey
        )
        let store = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )

        var edited = original
        edited.name = "After"
        edited.status = .active
        edited.notes = "edited"

        let result = store.updateCampaign(edited)

        XCTAssertEqual(result, .succeeded)
        XCTAssertEqual(store.persistenceState, .healthy)

        // In-memory value updated (updatedAt is stamped by the Store).
        let inMemory = try XCTUnwrap(
            store.campaign(id: original.id)
        )
        XCTAssertEqual(inMemory.name, "After")
        XCTAssertEqual(inMemory.status, .active)
        XCTAssertEqual(inMemory.notes, "edited")
        XCTAssertGreaterThan(inMemory.updatedAt, original.updatedAt)

        // Primary persisted; backup holds the pre-update bytes.
        let primaryData = try XCTUnwrap(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.storageKey
            )
        )
        XCTAssertNotEqual(primaryData, originalData)
        XCTAssertEqual(
            try JSONDecoder().decode(
                [ZhuowangCampaign].self,
                from: primaryData
            ),
            [inMemory]
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.backupKey
            ),
            originalData
        )

        // Restart: a fresh instance reads exactly the same value.
        let restarted = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )
        XCTAssertEqual(restarted.persistenceState, .healthy)
        XCTAssertEqual(restarted.campaigns, [inMemory])
    }


    func testSecondStoreRejectsStaleWriteWithoutChangingAnything() throws {
        let suite = try makeSuite(label: "CampaignConflict")
        let first = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )
        let second = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )
        let secondMemory = second.campaigns

        XCTAssertEqual(
            first.addCampaign(
                name: "First",
                scopeType: .other,
                startDate: Date(),
                endDate: Date()
            ),
            .succeeded
        )
        let primaryAfterFirst = suite.defaults.data(
            forKey: ZhuowangCampaignStore.storageKey
        )
        let backupAfterFirst = suite.defaults.data(
            forKey: ZhuowangCampaignStore.backupKey
        )

        let secondResult = second.addCampaign(
            name: "Second",
            scopeType: .other,
            startDate: Date(),
            endDate: Date()
        )

        XCTAssertEqual(
            secondResult,
            .rejected(.staleConflict)
        )
        XCTAssertEqual(
            second.persistenceState,
            .staleConflict
        )
        XCTAssertEqual(second.campaigns, secondMemory)
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            primaryAfterFirst
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.backupKey
            ),
            backupAfterFirst
        )
    }


    func testBackupWriteFailureLeavesPrimaryAndMemoryUntouched() throws {
        let originalCampaign = makeCampaign(name: "Original")
        let original = try JSONEncoder().encode([
            originalCampaign
        ])
        let dataSource = ZhuowangInMemoryPersistenceDataSource(
            storage: [
                ZhuowangCampaignStore.storageKey:
                    original
            ]
        )
        let store = ZhuowangCampaignStore(
            persistenceConfiguration:
                isolatedConfiguration(
                    dataSource: dataSource
                )
        )
        dataSource.resetWriteLog()
        dataSource.corruptWritesForKeys = [
            ZhuowangCampaignStore.backupKey
        ]

        let result = store.addCampaign(
            name: "Rejected",
            scopeType: .other,
            startDate: Date(),
            endDate: Date()
        )

        // Explicit error, Store locked.
        XCTAssertEqual(
            result,
            .rejected(.writeVerificationFailed)
        )
        XCTAssertEqual(
            store.persistenceState,
            .writeVerificationFailed
        )
        // Public memory unchanged.
        XCTAssertEqual(store.campaigns, [originalCampaign])
        // Primary bytes unchanged and never written.
        XCTAssertEqual(
            dataSource.storage[ZhuowangCampaignStore.storageKey],
            original
        )
        XCTAssertEqual(
            dataSource.writeCount(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            0
        )
        // Exactly one (failed) backup write was attempted, carrying the
        // old valid primary bytes; the candidate never reached any key.
        XCTAssertEqual(
            dataSource.writes(
                forKey: ZhuowangCampaignStore.backupKey
            ),
            [original]
        )
        XCTAssertEqual(dataSource.writeCount, 1)
    }


    func testWriteVerificationFailureDoesNotPublishCandidate() throws {
        let originalCampaign = makeCampaign(name: "Original")
        let original = try JSONEncoder().encode([
            originalCampaign
        ])
        let dataSource = ZhuowangInMemoryPersistenceDataSource(
            storage: [
                ZhuowangCampaignStore.storageKey:
                    original
            ]
        )
        let store = ZhuowangCampaignStore(
            persistenceConfiguration:
                isolatedConfiguration(
                    dataSource: dataSource
                )
        )
        dataSource.resetWriteLog()
        dataSource.corruptWritesForKeys = [
            ZhuowangCampaignStore.storageKey
        ]

        let result = store.addCampaign(
            name: "Rejected",
            scopeType: .other,
            startDate: Date(),
            endDate: Date()
        )

        // Current Store: locked, public memory keeps the old value.
        XCTAssertEqual(
            result,
            .rejected(.writeVerificationFailed)
        )
        XCTAssertEqual(
            store.persistenceState,
            .writeVerificationFailed
        )
        XCTAssertEqual(
            store.campaigns,
            [originalCampaign]
        )
        XCTAssertEqual(
            store.addCampaign(
                name: "Still Locked",
                scopeType: .other,
                startDate: Date(),
                endDate: Date()
            ),
            .rejected(.writeVerificationFailed)
        )

        // Backup holds the old valid primary; the primary write was
        // attempted once with the candidate and did not persist.
        XCTAssertEqual(
            dataSource.storage[
                ZhuowangCampaignStore.backupKey
            ],
            original
        )
        XCTAssertEqual(
            dataSource.writeCount(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            1
        )
        XCTAssertEqual(
            dataSource.storage[ZhuowangCampaignStore.storageKey],
            Data("corrupt-write".utf8)
        )

        // A fresh instance on the same data must not silently "heal": the
        // primary is unreadable, so it locks and reports the valid backup.
        dataSource.corruptWritesForKeys = []
        let writesBeforeReload = dataSource.writeCount
        let reloaded = ZhuowangCampaignStore(
            persistenceConfiguration:
                isolatedConfiguration(
                    dataSource: dataSource
                )
        )
        XCTAssertEqual(
            reloaded.persistenceState,
            .lockedCorruptPrimary(hasValidBackup: true)
        )
        XCTAssertTrue(reloaded.campaigns.isEmpty)
        XCTAssertEqual(dataSource.writeCount, writesBeforeReload)
        XCTAssertEqual(
            dataSource.storage[
                ZhuowangCampaignStore.backupKey
            ],
            original
        )
    }


    func testInvalidAndMissingMutationsDoNotWriteBackup() throws {
        let suite = try makeRecordedSuite(label: "CampaignRejected")
        let store = ZhuowangCampaignStore(
            persistenceConfiguration: suite.configuration
        )
        let primary = suite.defaults.data(
            forKey: ZhuowangCampaignStore.storageKey
        )
        suite.recorder.resetWriteLog()

        XCTAssertEqual(
            store.addCampaign(
                name: "   ",
                scopeType: .other,
                startDate: Date(),
                endDate: Date()
            ),
            .rejected(.invalidInput)
        )
        XCTAssertEqual(
            store.deleteCampaign(id: UUID()),
            .rejected(.itemNotFound)
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.storageKey
            ),
            primary
        )
        XCTAssertNil(
            suite.defaults.data(
                forKey: ZhuowangCampaignStore.backupKey
            )
        )
        XCTAssertEqual(suite.recorder.writeCount, 0)
    }


    private func makeCampaign(
        name: String
    ) -> ZhuowangCampaign {
        ZhuowangCampaign(
            id: UUID(),
            name: name,
            scopeType: .other,
            startDate: Date(timeIntervalSince1970: 100),
            endDate: Date(timeIntervalSince1970: 200),
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
    }
}
