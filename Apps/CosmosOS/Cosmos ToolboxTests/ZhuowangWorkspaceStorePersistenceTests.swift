import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class ZhuowangWorkspaceStorePersistenceTests:
    ZhuowangStorePersistenceTestCase {

    func testMissingPrimaryInitializesDefaultsOnlyOnce() throws {
        let suite = try makeRecordedSuite(label: "WorkspaceInit")

        let first = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )
        let firstData = try XCTUnwrap(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.storageKey
            )
        )

        // First load: primary missing → exactly one primary write,
        // carrying the default snapshot, and no backup write.
        XCTAssertEqual(first.persistenceState, .healthy)
        XCTAssertEqual(first.provinces.count, 6)
        XCTAssertEqual(
            suite.recorder.writeCount(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            1
        )
        XCTAssertEqual(
            suite.recorder.writeCount(
                forKey: ZhuowangWorkspaceStore.backupKey
            ),
            0
        )
        XCTAssertEqual(
            suite.recorder.writes(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            [firstData]
        )

        let writesBeforeSecond = suite.recorder.writeCount

        let second = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )

        // Second load: zero additional writes of any kind.
        XCTAssertEqual(second.persistenceState, .healthy)
        XCTAssertEqual(
            suite.recorder.writeCount - writesBeforeSecond,
            0
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            firstData
        )
        XCTAssertNil(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.backupKey
            )
        )
    }


    func testValidPayloadLoadsWithoutReencodingOrBackup() throws {
        let suite = try makeRecordedSuite(label: "WorkspaceLoad")
        let raw = ZhuowangHandWrittenPayload.singleWorkspace

        // Sanity: the fixture must differ from the production encoding.
        let decoded = try JSONDecoder().decode(
            ZhuowangWorkspaceSnapshot.self,
            from: raw
        )
        XCTAssertNotEqual(
            try JSONEncoder().encode(decoded),
            raw
        )

        suite.defaults.set(
            raw,
            forKey: ZhuowangWorkspaceStore.storageKey
        )

        let store = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )

        XCTAssertEqual(store.persistenceState, .healthy)
        XCTAssertEqual(store.provinces.map(\.id), [
            ZhuowangHandWrittenPayload.provinceID
        ])
        XCTAssertEqual(store.provinces.first?.name, "Province")
        XCTAssertEqual(store.modules.map(\.id), ["module"])
        XCTAssertEqual(store.modules.first?.usesProvinces, true)
        XCTAssertEqual(store.categories.map(\.id), ["category"])

        // Byte-for-byte unchanged and no write at all.
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            raw
        )
        XCTAssertEqual(
            suite.recorder.writeCount(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            0
        )
        XCTAssertEqual(
            suite.recorder.writeCount(
                forKey: ZhuowangWorkspaceStore.backupKey
            ),
            0
        )
        XCTAssertEqual(suite.recorder.writeCount, 0)
        XCTAssertNil(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.backupKey
            )
        )
    }


    func testExistingPayloadNeedsNoMigration() throws {
        let suite = try makeRecordedSuite(label: "WorkspaceLegacy")
        let raw = ZhuowangHandWrittenPayload.legacyWorkspace

        // Precondition: the fixture must differ from the production
        // encoding, otherwise a re-encode could not be detected.
        XCTAssertNotEqual(
            try JSONEncoder().encode(
                try JSONDecoder().decode(
                    ZhuowangWorkspaceSnapshot.self,
                    from: raw
                )
            ),
            raw
        )

        suite.defaults.set(
            raw,
            forKey: ZhuowangWorkspaceStore.storageKey
        )

        let store = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )

        XCTAssertEqual(store.persistenceState, .healthy)
        XCTAssertEqual(
            store.provinces.map(\.name),
            ["河南", "安徽"]
        )
        XCTAssertEqual(
            store.provinces.map(\.id),
            [
                UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
            ]
        )
        XCTAssertEqual(store.modules.map(\.id), ["welfare"])
        XCTAssertEqual(
            store.categories.map(\.id),
            ["overview", "campaign"]
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            raw
        )
        XCTAssertEqual(suite.recorder.writeCount, 0)
    }


    func testRestartPreservesProvinceUUIDs() throws {
        // Uses a *custom* province so the assertion cannot be satisfied by
        // the fixed default UUIDs alone.
        let suite = try makeSuite(label: "WorkspaceRestart")
        let first = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )
        XCTAssertEqual(
            first.addProvince(name: "临时省", englishName: "Temp"),
            .succeeded
        )
        let firstIDs = first.provinces.map(\.id)
        XCTAssertEqual(firstIDs.count, 7)

        let second = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )

        XCTAssertEqual(
            second.provinces.map(\.id),
            firstIDs
        )
        XCTAssertEqual(second.provinces.last?.name, "临时省")
    }


    func testModuleCreateUpdateDeletePersistsAcrossRestarts() throws {
        let suite = try makeSuite(label: "WorkspaceModuleCRUD")
        let first = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )

        XCTAssertEqual(
            first.addModule(
                name: "Temporary Workspace",
                englishName: "Temporary Workspace",
                usesProvinces: false
            ),
            .succeeded
        )
        let created = try XCTUnwrap(
            first.modules.first {
                $0.name == "Temporary Workspace"
            }
        )

        let afterCreate = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )
        var updated = try XCTUnwrap(
            afterCreate.modules.first {
                $0.id == created.id
            }
        )
        updated.name = "Temporary Workspace Edited"

        XCTAssertEqual(
            afterCreate.updateModule(updated),
            .succeeded
        )

        let afterUpdate = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )
        XCTAssertEqual(
            afterUpdate.modules.first {
                $0.id == created.id
            }?.name,
            "Temporary Workspace Edited"
        )
        XCTAssertEqual(
            afterUpdate.deleteModule(id: created.id),
            .succeeded
        )

        let afterDelete = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )
        XCTAssertFalse(
            afterDelete.modules.contains {
                $0.id == created.id
            }
        )
    }


    func testCorruptPrimaryWithoutBackupLocksAndPreservesBytes() throws {
        let suite = try makeRecordedSuite(label: "WorkspaceCorrupt")
        let corrupt = Data("not-json".utf8)
        suite.defaults.set(
            corrupt,
            forKey: ZhuowangWorkspaceStore.storageKey
        )

        let store = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )

        XCTAssertEqual(
            store.persistenceState,
            .lockedCorruptPrimary(hasValidBackup: false)
        )
        XCTAssertTrue(store.modules.isEmpty)
        XCTAssertTrue(store.provinces.isEmpty)
        XCTAssertTrue(store.categories.isEmpty)
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            corrupt
        )
        XCTAssertEqual(suite.recorder.writeCount, 0)
    }


    func testCorruptPrimaryAndCorruptBackupLockWithoutValidBackup() throws {
        let suite = try makeRecordedSuite(label: "WorkspaceBothCorrupt")
        let corruptPrimary = Data("{broken primary".utf8)
        let corruptBackup = Data("{broken backup".utf8)
        suite.defaults.set(
            corruptPrimary,
            forKey: ZhuowangWorkspaceStore.storageKey
        )
        suite.defaults.set(
            corruptBackup,
            forKey: ZhuowangWorkspaceStore.backupKey
        )

        let store = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )

        XCTAssertEqual(
            store.persistenceState,
            .lockedCorruptPrimary(hasValidBackup: false)
        )
        XCTAssertTrue(store.provinces.isEmpty)
        XCTAssertEqual(
            store.addProvince(name: "Rejected", englishName: "Rejected"),
            .rejected(.lockedCorruptPrimary(hasValidBackup: false))
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            corruptPrimary
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.backupKey
            ),
            corruptBackup
        )
        XCTAssertEqual(suite.recorder.writeCount, 0)
    }


    func testCorruptPrimaryKeepsValidBackupAndRejectsAllMutations() throws {
        let suite = try makeSuite(label: "WorkspaceBackup")
        let corrupt = Data("not-json".utf8)
        let backup = try JSONEncoder().encode(
            makeSnapshot(provinceName: "Last Good")
        )
        suite.defaults.set(
            corrupt,
            forKey: ZhuowangWorkspaceStore.storageKey
        )
        suite.defaults.set(
            backup,
            forKey: ZhuowangWorkspaceStore.backupKey
        )

        let store = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )
        let rejectedModule = ZhuowangModule(
            id: "rejected",
            name: "Rejected",
            englishName: "Rejected",
            icon: "folder",
            usesProvinces: false
        )

        let expected: ZhuowangStoreMutationResult =
            .rejected(
                .lockedCorruptPrimary(
                    hasValidBackup: true
                )
            )
        XCTAssertEqual(
            store.addProvince(
                name: "Rejected",
                englishName: "Rejected"
            ),
            expected
        )
        XCTAssertEqual(
            store.addCategory(
                name: "Rejected",
                englishName: "Rejected"
            ),
            expected
        )
        XCTAssertEqual(
            store.addModule(
                name: "Rejected",
                englishName: "Rejected",
                usesProvinces: false
            ),
            expected
        )
        XCTAssertEqual(
            store.updateModule(rejectedModule),
            expected
        )
        XCTAssertEqual(
            store.deleteModule(rejectedModule),
            expected
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            corrupt
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.backupKey
            ),
            backup
        )
        XCTAssertTrue(store.provinces.isEmpty)
    }


    func testSuccessfulMutationBacksUpPreviousValidPrimary() throws {
        let suite = try makeSuite(label: "WorkspaceMutation")
        let original = try JSONEncoder().encode(
            makeSnapshot(provinceName: "Original")
        )
        suite.defaults.set(
            original,
            forKey: ZhuowangWorkspaceStore.storageKey
        )
        let store = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )

        let result = store.addProvince(
            name: "New",
            englishName: "New"
        )

        XCTAssertEqual(result, .succeeded)
        XCTAssertEqual(store.provinces.count, 2)
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.backupKey
            ),
            original
        )
        let persisted = try JSONDecoder().decode(
            ZhuowangWorkspaceSnapshot.self,
            from: try XCTUnwrap(
                suite.defaults.data(
                    forKey: ZhuowangWorkspaceStore.storageKey
                )
            )
        )
        XCTAssertEqual(persisted.provinces, store.provinces)
    }


    func testSecondStoreRejectsStaleWriteWithoutChangingAnything() throws {
        let suite = try makeSuite(label: "WorkspaceConflict")
        let first = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )
        let second = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )
        let secondProvinces = second.provinces

        XCTAssertEqual(
            first.addProvince(
                name: "First",
                englishName: "First"
            ),
            .succeeded
        )
        let primaryAfterFirst = suite.defaults.data(
            forKey: ZhuowangWorkspaceStore.storageKey
        )
        let backupAfterFirst = suite.defaults.data(
            forKey: ZhuowangWorkspaceStore.backupKey
        )

        let result = second.addProvince(
            name: "Second",
            englishName: "Second"
        )

        XCTAssertEqual(
            result,
            .rejected(.staleConflict)
        )
        XCTAssertEqual(
            second.persistenceState,
            .staleConflict
        )
        XCTAssertEqual(
            second.provinces,
            secondProvinces
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            primaryAfterFirst
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.backupKey
            ),
            backupAfterFirst
        )
    }


    func testBackupWriteFailureLeavesPrimaryAndMemoryUntouched() throws {
        let originalSnapshot =
            makeSnapshot(provinceName: "Original")
        let original = try JSONEncoder().encode(
            originalSnapshot
        )
        let dataSource = ZhuowangInMemoryPersistenceDataSource(
            storage: [
                ZhuowangWorkspaceStore.storageKey:
                    original
            ]
        )
        let store = ZhuowangWorkspaceStore(
            persistenceConfiguration:
                isolatedConfiguration(
                    dataSource: dataSource
                )
        )
        dataSource.resetWriteLog()
        dataSource.corruptWritesForKeys = [
            ZhuowangWorkspaceStore.backupKey
        ]

        let result = store.addProvince(
            name: "Rejected",
            englishName: "Rejected"
        )

        XCTAssertEqual(
            result,
            .rejected(.writeVerificationFailed)
        )
        XCTAssertEqual(
            store.persistenceState,
            .writeVerificationFailed
        )
        XCTAssertEqual(
            store.provinces,
            originalSnapshot.provinces
        )
        XCTAssertEqual(
            dataSource.storage[ZhuowangWorkspaceStore.storageKey],
            original
        )
        XCTAssertEqual(
            dataSource.writeCount(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            0
        )
        XCTAssertEqual(
            dataSource.writes(
                forKey: ZhuowangWorkspaceStore.backupKey
            ),
            [original]
        )
        XCTAssertEqual(dataSource.writeCount, 1)
    }


    func testWriteVerificationFailureDoesNotPublishCandidate() throws {
        let originalSnapshot =
            makeSnapshot(provinceName: "Original")
        let original = try JSONEncoder().encode(
            originalSnapshot
        )
        let dataSource = ZhuowangInMemoryPersistenceDataSource(
            storage: [
                ZhuowangWorkspaceStore.storageKey:
                    original
            ]
        )
        let store = ZhuowangWorkspaceStore(
            persistenceConfiguration:
                isolatedConfiguration(
                    dataSource: dataSource
                )
        )
        dataSource.resetWriteLog()
        dataSource.corruptWritesForKeys = [
            ZhuowangWorkspaceStore.storageKey
        ]

        let result = store.addProvince(
            name: "Rejected",
            englishName: "Rejected"
        )

        XCTAssertEqual(
            result,
            .rejected(.writeVerificationFailed)
        )
        XCTAssertEqual(
            store.persistenceState,
            .writeVerificationFailed
        )
        XCTAssertEqual(
            store.provinces,
            originalSnapshot.provinces
        )
        XCTAssertEqual(
            store.addProvince(name: "Still Locked", englishName: ""),
            .rejected(.writeVerificationFailed)
        )
        XCTAssertEqual(
            dataSource.storage[
                ZhuowangWorkspaceStore.backupKey
            ],
            original
        )
        XCTAssertEqual(
            dataSource.writeCount(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            1
        )

        // Fresh instance on the same data: locked, backup detected,
        // nothing rewritten.
        dataSource.corruptWritesForKeys = []
        let writesBeforeReload = dataSource.writeCount
        let reloaded = ZhuowangWorkspaceStore(
            persistenceConfiguration:
                isolatedConfiguration(
                    dataSource: dataSource
                )
        )
        XCTAssertEqual(
            reloaded.persistenceState,
            .lockedCorruptPrimary(hasValidBackup: true)
        )
        XCTAssertTrue(reloaded.provinces.isEmpty)
        XCTAssertEqual(dataSource.writeCount, writesBeforeReload)
    }


    func testInvalidAndMissingModuleMutationsDoNotWriteBackup() throws {
        let suite = try makeRecordedSuite(label: "WorkspaceModuleRejected")
        let store = ZhuowangWorkspaceStore(
            persistenceConfiguration: suite.configuration
        )
        let primary = suite.defaults.data(
            forKey: ZhuowangWorkspaceStore.storageKey
        )
        suite.recorder.resetWriteLog()
        let missing = ZhuowangModule(
            id: "missing",
            name: "Missing",
            englishName: "Missing",
            icon: "folder",
            usesProvinces: false
        )
        var invalid = missing
        invalid.name = "   "

        XCTAssertEqual(
            store.updateModule(invalid),
            .rejected(.invalidInput)
        )
        XCTAssertEqual(
            store.updateModule(missing),
            .rejected(.itemNotFound)
        )
        XCTAssertEqual(
            store.deleteModule(id: missing.id),
            .rejected(.itemNotFound)
        )
        XCTAssertEqual(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.storageKey
            ),
            primary
        )
        XCTAssertNil(
            suite.defaults.data(
                forKey: ZhuowangWorkspaceStore.backupKey
            )
        )
        XCTAssertEqual(suite.recorder.writeCount, 0)
    }


    private func makeSnapshot(
        provinceName: String
    ) -> ZhuowangWorkspaceSnapshot {
        ZhuowangWorkspaceSnapshot(
            modules: [
                ZhuowangModule(
                    id: "module",
                    name: "Module",
                    englishName: "Module",
                    icon: "folder",
                    usesProvinces: true
                )
            ],
            provinces: [
                ZhuowangProvince(
                    id: UUID(),
                    name: provinceName,
                    englishName: provinceName
                )
            ],
            categories: [
                ZhuowangCategory(
                    id: "category",
                    name: "Category",
                    englishName: "Category",
                    icon: "folder"
                )
            ]
        )
    }
}
