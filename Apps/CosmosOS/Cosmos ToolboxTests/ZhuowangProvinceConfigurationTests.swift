import XCTest
import Foundation
@testable import Cosmos_Toolbox

/// Province configuration: add / rename / reorder / stop / restore, stable
/// folder names, backward-compatible decoding and history preservation.
/// Everything runs over in-memory data sources; no UserDefaults domain and
/// no file system is touched (paths are URL assertions on an injected root).
@MainActor
final class ZhuowangProvinceConfigurationTests: XCTestCase {

    // MARK: Helpers

    let henanID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    let anhuiID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    let zhejiangID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!

    /// Hand-written payload in the format saved before `isEnabled` /
    /// `directoryName` existed (no such keys, non-canonical key order).
    func legacyWorkspace(_ provinces: [(UUID, String)]) -> Data {
        let list = provinces.map {
            "{\"name\":\"\($0.1)\",\"id\":\"\($0.0.uuidString)\",\"englishName\":\"\($0.1)-en\"}"
        }.joined(separator: ",")
        let json = """
        {"provinces":[\(list)],
         "modules":[{"id":"welfare","name":"福利中心","englishName":"Welfare","icon":"gift","usesProvinces":true},
                    {"id":"national","name":"全国促活","englishName":"National","icon":"globe","usesProvinces":false}],
         "categories":[{"id":"overview","name":"总览","englishName":"Overview","icon":"square.grid.2x2"}]}
        """
        return Data(json.utf8)
    }

    func makeSource(_ workspace: Data? = nil, extra: [String: Data] = [:]) -> ZhuowangInMemoryPersistenceDataSource {
        var storage = extra
        if let workspace { storage[ZhuowangWorkspaceStore.storageKey] = workspace }
        return ZhuowangInMemoryPersistenceDataSource(storage: storage)
    }

    func makeStore(_ source: ZhuowangInMemoryPersistenceDataSource) -> ZhuowangWorkspaceStore {
        ZhuowangWorkspaceStore(persistenceConfiguration: isolatedConfiguration(dataSource: source))
    }

    func persisted(_ source: ZhuowangInMemoryPersistenceDataSource) throws -> ZhuowangWorkspaceSnapshot {
        try JSONDecoder().decode(ZhuowangWorkspaceSnapshot.self,
            from: try XCTUnwrap(source.storage[ZhuowangWorkspaceStore.storageKey]))
    }

    func legacyStore(_ names: [String] = ["河南", "安徽", "浙江"])
        -> (ZhuowangInMemoryPersistenceDataSource, ZhuowangWorkspaceStore) {
        let ids = [henanID, anhuiID, zhejiangID]
        let source = makeSource(legacyWorkspace(Array(zip(ids, names))))
        return (source, makeStore(source))
    }

    func path(_ province: ZhuowangProvince, campaign: String = "秋季活动") -> URL {
        ZhuowangWorkspaceFileManager(rootURL: URL(fileURLWithPath: "/private/tmp/CosmosProvinceConfig-PathRoot", isDirectory: true))
            .campaignDirectoryURL(provinceName: province.pathName, campaignName: campaign)
    }

    // MARK: Fresh install and upgrade

    func testFreshInstallHasNoFixedProvincesAndIsNeverReseeded() throws {
        let source = makeSource()
        let first = makeStore(source)
        XCTAssertEqual(first.persistenceState, .healthy)
        XCTAssertTrue(first.provinces.isEmpty)
        XCTAssertFalse(first.modules.isEmpty); XCTAssertFalse(first.categories.isEmpty)
        XCTAssertTrue(try persisted(source).provinces.isEmpty)
        XCTAssertEqual(first.addProvince(name: "湖北", englishName: "Hubei"), .succeeded)
        let second = makeStore(source)
        XCTAssertEqual(second.provinces.map(\.name), ["湖北"])
        XCTAssertEqual(second.provinces.map(\.id), first.provinces.map(\.id))
        // A user who stopped everything / has an unusual list is not reseeded either.
        _ = second.setProvinceEnabled(id: second.provinces[0].id, isEnabled: false)
        XCTAssertEqual(makeStore(source).provinces.map(\.isEnabled), [false])
    }

    func testExistingLibraryUpgradesUnchangedWithoutAnyWrite() throws {
        let raw = legacyWorkspace([(zhejiangID, "浙江"), (henanID, "河南"), (anhuiID, "安徽")])
        let source = makeSource(raw)
        let store = makeStore(source)
        XCTAssertEqual(store.persistenceState, .healthy)
        XCTAssertEqual(store.provinces.map(\.id), [zhejiangID, henanID, anhuiID], "order kept")
        XCTAssertEqual(store.provinces.map(\.name), ["浙江", "河南", "安徽"])
        XCTAssertTrue(store.provinces.allSatisfy(\.isEnabled))
        XCTAssertTrue(store.provinces.allSatisfy { $0.directoryName == nil })
        XCTAssertEqual(store.provinces.map(\.pathName), ["浙江", "河南", "安徽"])
        XCTAssertEqual(source.writeCount, 0, "loading old data triggers no migration write")
        XCTAssertEqual(source.storage[ZhuowangWorkspaceStore.storageKey], raw)
        // Only one default-like province saved: nothing is added back.
        let partial = makeStore(makeSource(legacyWorkspace([(henanID, "河南")])))
        XCTAssertEqual(partial.provinces.map(\.name), ["河南"])
    }

    func testProvinceDecodingIsBackwardCompatibleAndEncodesOptionalFolderOnlyWhenSet() throws {
        let old = Data("{\"id\":\"\(henanID.uuidString)\",\"name\":\"河南\",\"englishName\":\"Henan\"}".utf8)
        let decoded = try JSONDecoder().decode(ZhuowangProvince.self, from: old)
        XCTAssertTrue(decoded.isEnabled); XCTAssertNil(decoded.directoryName); XCTAssertEqual(decoded.pathName, "河南")
        let encoded = String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
        XCTAssertFalse(encoded.contains("directoryName"))
        let stopped = ZhuowangProvince(id: henanID, name: "中原", englishName: "x", isEnabled: false, directoryName: "河南")
        let again = try JSONDecoder().decode(ZhuowangProvince.self, from: try JSONEncoder().encode(stopped))
        XCTAssertEqual(again, stopped); XCTAssertEqual(again.pathName, "河南")
        XCTAssertThrowsError(try JSONDecoder().decode(ZhuowangProvince.self, from: Data("{\"id\":\"x\"}".utf8)))
    }

    // MARK: Adding and validation

    func testAddAppendsAtEndPinsFolderAndKeepsExistingOrder() throws {
        let (source, store) = legacyStore()
        XCTAssertEqual(store.addProvince(name: "  湖北  ", englishName: ""), .succeeded)
        XCTAssertEqual(store.provinces.map(\.name), ["河南", "安徽", "浙江", "湖北"])
        let added = try XCTUnwrap(store.provinces.last)
        XCTAssertEqual(added.directoryName, "湖北"); XCTAssertEqual(added.englishName, "湖北"); XCTAssertTrue(added.isEnabled)
        XCTAssertEqual(try persisted(source).provinces, store.provinces)
        XCTAssertEqual(store.addProvince(name: "   ", englishName: ""), .rejected(.invalidInput))
    }

    func testDisplayNameDuplicatesAreRejectedConservativelyIncludingStoppedProvinces() throws {
        let (_, store) = legacyStore(["Hubei", "安徽", "浙江"])
        for duplicate in ["Hubei", "hubei", "  HUBEI ", "ＨＵＢＥＩ"] {
            XCTAssertEqual(ZhuowangProvinceRules.validateNew(name: duplicate, existing: store.provinces, modules: store.modules),
                           .duplicateDisplayName, duplicate)
            XCTAssertEqual(store.addProvince(name: duplicate, englishName: ""), .rejected(.invalidInput))
        }
        // Canonically equivalent Unicode forms are the same name.
        let nfc = makeStore(makeSource(legacyWorkspace([(henanID, "caf\u{E9}")])))
        XCTAssertEqual(ZhuowangProvinceRules.validateNew(name: "cafe\u{301}", existing: nfc.provinces, modules: nfc.modules),
                       .duplicateDisplayName)
        _ = store.setProvinceEnabled(id: store.provinces[0].id, isEnabled: false)
        XCTAssertEqual(store.addProvince(name: "Hubei", englishName: ""), .rejected(.invalidInput), "stopped provinces count")
        XCTAssertEqual(store.provinces.count, 3)
    }

    func testFolderNamesAreComparedAgainstEffectiveFoldersNotJustDisplayNames() throws {
        // Two different display names that sanitize to the same folder.
        let a = makeStore(makeSource(legacyWorkspace([(henanID, "A/B")])))
        XCTAssertEqual(ZhuowangProvinceRules.validateNew(name: "A:B", existing: a.provinces, modules: a.modules),
                       .directoryConflict)
        XCTAssertEqual(a.addProvince(name: "a|b", englishName: ""), .rejected(.invalidInput))
        // A renamed province keeps occupying its old (pinned) folder.
        let (_, store) = legacyStore()
        XCTAssertEqual(store.renameProvince(id: henanID, name: "中原", englishName: ""), .succeeded)
        XCTAssertEqual(ZhuowangProvinceRules.validateNew(name: "河南", existing: store.provinces, modules: store.modules),
                       .directoryConflict)
        XCTAssertEqual(store.addProvince(name: "河南", englishName: ""), .rejected(.invalidInput))
        XCTAssertEqual(store.provinces.count, 3)
    }

    func testNationalAndOtherNamesAreReserved() throws {
        let (_, store) = legacyStore()
        for name in ["全国", "全国及其他", "全国促活", " 全国 "] {
            XCTAssertEqual(ZhuowangProvinceRules.validateNew(name: name, existing: store.provinces, modules: store.modules),
                           .reservedName, name)
            XCTAssertEqual(store.addProvince(name: name, englishName: ""), .rejected(.invalidInput))
            XCTAssertEqual(ZhuowangProvinceRules.validateRename(id: henanID, name: name, existing: store.provinces, modules: store.modules),
                           .reservedName, name)
        }
        XCTAssertEqual(ZhuowangProvinceRules.nationalPathName, "全国及其他")
        // National campaigns are not province-scoped and never become a province.
        XCTAssertFalse(store.provinces.contains { ZhuowangProvinceRules.pathKey($0.pathName) == ZhuowangProvinceRules.pathKey("全国及其他") })
    }

    // MARK: Rename and stable folders

    func testRenamePinsTheLegacyFolderOnceAndNeverChangesItAgain() throws {
        let (source, store) = legacyStore()
        let original = try XCTUnwrap(store.provinces.first { $0.id == henanID })
        let before = path(original)
        XCTAssertEqual(store.renameProvince(id: henanID, name: "豫", englishName: "Yu"), .succeeded)
        var current = try XCTUnwrap(store.provinces.first { $0.id == henanID })
        XCTAssertEqual(current.id, henanID); XCTAssertEqual(current.name, "豫"); XCTAssertEqual(current.englishName, "Yu")
        XCTAssertEqual(current.directoryName, "河南", "old folder pinned in the same transaction")
        XCTAssertEqual(path(current), before, "folder path unchanged after the first rename")
        XCTAssertNotEqual(ZhuowangWorkspaceFileManager(rootURL: URL(fileURLWithPath: "/private/tmp/x"))
            .campaignDirectoryURL(provinceName: current.name, campaignName: "秋季活动"),
            ZhuowangWorkspaceFileManager(rootURL: URL(fileURLWithPath: "/private/tmp/x"))
            .campaignDirectoryURL(provinceName: original.name, campaignName: "秋季活动"), "name-based paths would have moved")
        for name in ["中原", "豫", "河南省", "河南"] {
            XCTAssertEqual(store.renameProvince(id: henanID, name: name, englishName: ""), .succeeded, name)
            current = try XCTUnwrap(store.provinces.first { $0.id == henanID })
            XCTAssertEqual(current.directoryName, "河南"); XCTAssertEqual(path(current), before, name)
        }
        XCTAssertEqual(try persisted(source).provinces.first { $0.id == henanID }?.directoryName, "河南")
        XCTAssertEqual(makeStore(source).provinces.first { $0.id == henanID }?.pathName, "河南", "survives restart")
    }

    func testEnglishOnlyAndNewProvinceRenamesKeepFolders() throws {
        let (_, store) = legacyStore()
        XCTAssertEqual(store.renameProvince(id: anhuiID, name: "安徽", englishName: "Anhui Province"), .succeeded)
        XCTAssertNil(store.provinces.first { $0.id == anhuiID }?.directoryName, "no rename → nothing to pin yet")
        _ = store.addProvince(name: "湖北", englishName: "Hubei")
        let hubei = try XCTUnwrap(store.provinces.last)
        let before = path(hubei)
        XCTAssertEqual(store.renameProvince(id: hubei.id, name: "楚", englishName: ""), .succeeded)
        let renamed = try XCTUnwrap(store.provinces.last)
        XCTAssertEqual(renamed.directoryName, "湖北"); XCTAssertEqual(path(renamed), before); XCTAssertEqual(renamed.id, hubei.id)
        XCTAssertEqual(store.renameProvince(id: UUID(), name: "x", englishName: ""), .rejected(.itemNotFound))
        XCTAssertEqual(store.renameProvince(id: henanID, name: "  ", englishName: ""), .rejected(.invalidInput))
    }

    func testRenameChecksOnlyOtherProvincesDisplayNamesAndExcludesItself() throws {
        let (_, store) = legacyStore()
        XCTAssertEqual(store.renameProvince(id: henanID, name: "安徽", englishName: ""), .rejected(.invalidInput))
        XCTAssertEqual(store.renameProvince(id: henanID, name: "安徽 ", englishName: ""), .rejected(.invalidInput))
        XCTAssertEqual(store.renameProvince(id: henanID, name: "河南", englishName: "Henan Province"), .succeeded, "itself excluded")
        XCTAssertEqual(store.renameProvince(id: henanID, name: "河南".lowercased(), englishName: ""), .succeeded)
        // A stopped province still blocks a duplicate display name.
        _ = store.setProvinceEnabled(id: anhuiID, isEnabled: false)
        XCTAssertEqual(store.renameProvince(id: henanID, name: "安徽", englishName: ""), .rejected(.invalidInput))
        // Renaming does not need a free folder name: a name equal to another province's folder is fine.
        XCTAssertEqual(store.renameProvince(id: henanID, name: "浙江省", englishName: ""), .succeeded)
        XCTAssertEqual(store.provinces.first { $0.id == henanID }?.pathName, "河南")
    }

    func testExistingDuplicatesAreKeptReportedAndNeverLockOrMerge() throws {
        let source = makeSource(legacyWorkspace([(henanID, "重名"), (anhuiID, "重名"), (zhejiangID, "浙江")]))
        let store = makeStore(source)
        XCTAssertEqual(store.persistenceState, .healthy)
        XCTAssertEqual(store.provinces.count, 3)
        let notes = ZhuowangProvinceRules.existingConflicts(in: store.provinces)
        XCTAssertEqual(notes.count, 2, "same display name and shared folder are both reported")
        XCTAssertTrue(notes.contains { $0.contains("重名") })
        XCTAssertEqual(source.writeCount, 0)
        // Unchanged name with an English edit still works; a unique rename resolves the duplicate.
        XCTAssertEqual(store.renameProvince(id: henanID, name: "重名", englishName: "Dup"), .succeeded)
        XCTAssertEqual(store.renameProvince(id: anhuiID, name: "安徽", englishName: ""), .succeeded)
        XCTAssertEqual(store.provinces.count, 3)
        XCTAssertEqual(ZhuowangProvinceRules.existingConflicts(in: store.provinces).count, 1, "shared folder remains reported, not merged")
        XCTAssertEqual(store.provinces.first { $0.id == anhuiID }?.pathName, "重名")
        XCTAssertEqual(store.renameProvince(id: zhejiangID, name: "安徽", englishName: ""), .rejected(.invalidInput))
    }

    // MARK: Stop, restore, reorder

    func testStopAndRestoreNeverDeleteAndKeepPositionAcrossRestart() throws {
        let (source, store) = legacyStore()
        let before = store.provinces
        XCTAssertEqual(store.setProvinceEnabled(id: anhuiID, isEnabled: false), .succeeded)
        XCTAssertEqual(store.provinces.map(\.id), before.map(\.id))
        XCTAssertEqual(store.provinces.map(\.isEnabled), [true, false, true])
        XCTAssertEqual(store.provinces[1].name, "安徽"); XCTAssertEqual(store.provinces[1].pathName, "安徽")
        let writes = source.writeCount
        XCTAssertEqual(store.setProvinceEnabled(id: anhuiID, isEnabled: false), .succeeded)
        XCTAssertEqual(source.writeCount, writes, "no-op writes nothing")
        XCTAssertEqual(makeStore(source).provinces.map(\.isEnabled), [true, false, true])
        XCTAssertEqual(store.setProvinceEnabled(id: anhuiID, isEnabled: true), .succeeded)
        XCTAssertEqual(makeStore(source).provinces.map(\.id), before.map(\.id), "restored to its old position")
        XCTAssertTrue(makeStore(source).provinces.allSatisfy(\.isEnabled))
        XCTAssertEqual(store.setProvinceEnabled(id: UUID(), isEnabled: false), .rejected(.itemNotFound))
    }

    func testReorderSwapsNeighborsAndPersists() throws {
        let (source, store) = legacyStore()
        XCTAssertEqual(store.moveProvince(id: zhejiangID, offset: -1), .succeeded)
        XCTAssertEqual(store.provinces.map(\.id), [henanID, zhejiangID, anhuiID])
        XCTAssertEqual(store.moveProvince(id: henanID, offset: 1), .succeeded)
        XCTAssertEqual(store.provinces.map(\.id), [zhejiangID, henanID, anhuiID])
        let writes = source.writeCount
        XCTAssertEqual(store.moveProvince(id: zhejiangID, offset: -1), .rejected(.invalidInput), "already first")
        XCTAssertEqual(store.moveProvince(id: anhuiID, offset: 1), .rejected(.invalidInput), "already last")
        XCTAssertEqual(store.moveProvince(id: henanID, offset: 0), .rejected(.invalidInput))
        XCTAssertEqual(store.moveProvince(id: UUID(), offset: 1), .rejected(.itemNotFound))
        XCTAssertEqual(source.writeCount, writes)
        XCTAssertEqual(makeStore(source).provinces.map(\.id), [zhejiangID, henanID, anhuiID])
        // A stopped province keeps taking part in ordering.
        _ = store.setProvinceEnabled(id: henanID, isEnabled: false)
        XCTAssertEqual(store.moveProvince(id: henanID, offset: 1), .succeeded)
        XCTAssertEqual(makeStore(source).provinces.map(\.id), [zhejiangID, anhuiID, henanID])
    }

    func testUnrelatedWorkspaceFieldsAndOtherStoresAreNeverRewritten() throws {
        let other = ["cosmos.zhuowang.campaigns.v1": Data("campaign-bytes".utf8),
                     ZhuowangWorkflowStore.workflowStorageKey: Data("workflow-bytes".utf8)]
        let source = makeSource(legacyWorkspace([(henanID, "河南"), (anhuiID, "安徽")]), extra: other)
        let store = makeStore(source)
        let modules = store.modules, categories = store.categories
        _ = store.addProvince(name: "湖北", englishName: "")
        _ = store.renameProvince(id: henanID, name: "豫", englishName: "")
        _ = store.setProvinceEnabled(id: anhuiID, isEnabled: false)
        _ = store.moveProvince(id: henanID, offset: 1)
        let snapshot = try persisted(source)
        XCTAssertEqual(snapshot.modules, modules); XCTAssertEqual(snapshot.categories, categories)
        for (key, value) in other { XCTAssertEqual(source.storage[key], value, key); XCTAssertEqual(source.writeCount(forKey: key), 0) }
        XCTAssertEqual(store.modules, modules); XCTAssertEqual(store.categories, categories)
    }

    func testStaleAndLockedStatesRefuseProvinceChangesWithoutWriting() throws {
        let (source, one) = legacyStore()
        let two = makeStore(source)
        XCTAssertEqual(one.renameProvince(id: henanID, name: "豫", englishName: ""), .succeeded)
        XCTAssertEqual(two.setProvinceEnabled(id: anhuiID, isEnabled: false), .rejected(.staleConflict))
        XCTAssertEqual(try persisted(source).provinces.map(\.isEnabled), [true, true, true])
        let corrupt = makeSource(Data("not json".utf8))
        let locked = makeStore(corrupt)
        XCTAssertFalse(locked.persistenceState.allowsMutations)
        XCTAssertFalse(locked.addProvince(name: "湖北", englishName: "").succeeded)
        XCTAssertFalse(locked.setProvinceEnabled(id: henanID, isEnabled: false).succeeded)
        XCTAssertEqual(corrupt.storage[ZhuowangWorkspaceStore.storageKey], Data("not json".utf8))
    }

    // MARK: Campaign creation gate

    func testCampaignCreationFollowsTheLiveProvinceConfiguration() throws {
        let (_, store) = legacyStore()
        let henan = try XCTUnwrap(store.provinces.first { $0.id == henanID })
        XCTAssertTrue(ZhuowangProvinceRules.canCreateCampaign(provinceID: henanID, in: store.provinces))
        let live: (UUID) -> Bool = { ZhuowangProvinceRules.canCreateCampaign(provinceID: $0, in: store.provinces) }
        // A form was opened while the province was enabled (it holds the old struct) …
        XCTAssertNil(ZhuowangProvinceRules.creationRefusalMessage(province: henan, isEnabled: live))
        _ = store.setProvinceEnabled(id: henanID, isEnabled: false)
        // … and saving re-reads the live configuration, so it is refused.
        let message = try XCTUnwrap(ZhuowangProvinceRules.creationRefusalMessage(province: henan, isEnabled: live))
        XCTAssertTrue(message.contains("河南")); XCTAssertTrue(message.contains("保留"))
        XCTAssertFalse(ZhuowangProvinceRules.canCreateCampaign(provinceID: henanID, in: store.provinces))
        XCTAssertFalse(ZhuowangProvinceRules.canCreateCampaign(provinceID: UUID(), in: store.provinces))
        XCTAssertNil(ZhuowangProvinceRules.creationRefusalMessage(province: nil, isEnabled: live), "national / other scope is not gated")
        _ = store.setProvinceEnabled(id: henanID, isEnabled: true)
        XCTAssertNil(ZhuowangProvinceRules.creationRefusalMessage(province: henan, isEnabled: live))
    }

    // MARK: History stays reachable

    func testStoppedProvinceKeepsHistoricalCampaignsEditableAndVisible() throws {
        let fixture = WorkbenchFixture()
        let stores = fixture.makeStores()
        let henan = try XCTUnwrap(stores.workspace.provinces.first { $0.name == "河南" })
        let campaignsBefore = stores.dataSource.storage[ZhuowangCampaignStore.storageKey]
        let workflowsBefore = stores.dataSource.storage[ZhuowangWorkflowStore.workflowStorageKey]
        stores.dataSource.resetWriteLog()
        XCTAssertEqual(stores.workspace.setProvinceEnabled(id: henan.id, isEnabled: false), .succeeded)
        XCTAssertEqual(stores.dataSource.writeCount(forKey: ZhuowangCampaignStore.storageKey), 0)
        XCTAssertEqual(stores.dataSource.storage[ZhuowangCampaignStore.storageKey], campaignsBefore)
        XCTAssertEqual(stores.dataSource.storage[ZhuowangWorkflowStore.workflowStorageKey], workflowsBefore)

        // Progress workbench: the stopped province's Campaigns are still listed with their province.
        let progress = ZhuowangCampaignProgressBuilder.build(
            campaigns: stores.campaigns.campaigns, workflows: stores.workflows.workflows,
            provinces: stores.workspace.provinces, modules: stores.workspace.modules,
            now: fixture.now, calendar: fixture.calendar, deliverableCounter: fixture.counter)
        let rows = progress.filter { $0.campaign.provinceID == henan.id }
        XCTAssertEqual(Set(rows.map(\.campaign.name)), ["秋季签到", "夏日回顾"])
        XCTAssertTrue(rows.allSatisfy { $0.scopeName == "河南" })
        XCTAssertTrue(rows.contains { $0.hasWorkflow })

        // Existing Campaigns remain editable: no province check in their save path.
        var edited = try XCTUnwrap(stores.campaigns.campaigns.first { $0.name == "秋季签到" })
        edited.status = .active; edited.notes = "停用后仍可编辑"
        XCTAssertEqual(stores.campaigns.updateCampaign(edited), .succeeded)
        XCTAssertEqual(stores.campaigns.campaigns.first { $0.id == edited.id }?.notes, "停用后仍可编辑")

        // Asset center: artifacts of the stopped province are still found, labelled with the province.
        let catalog = try ZhuowangAssetCatalogReader(dataSource: stores.dataSource).read()
        let assets = catalog.entries.filter { $0.provinceID == henan.id }
        XCTAssertFalse(assets.isEmpty)
        XCTAssertTrue(assets.allSatisfy { $0.scopeName == "河南" })
        XCTAssertEqual(catalog.provinces.first { $0.id == henan.id }?.isEnabled, false)
    }

    func testRenamedProvinceKeepsHistoricalOwnershipByIdentity() throws {
        let fixture = WorkbenchFixture()
        let stores = fixture.makeStores()
        let henan = try XCTUnwrap(stores.workspace.provinces.first { $0.name == "河南" })
        XCTAssertEqual(stores.workspace.renameProvince(id: henan.id, name: "中原", englishName: ""), .succeeded)
        let renamed = try XCTUnwrap(stores.workspace.provinces.first { $0.id == henan.id })
        XCTAssertEqual(renamed.directoryName, "河南"); XCTAssertEqual(renamed.pathName, "河南")
        let progress = ZhuowangCampaignProgressBuilder.build(
            campaigns: stores.campaigns.campaigns, workflows: stores.workflows.workflows,
            provinces: stores.workspace.provinces, modules: stores.workspace.modules,
            now: fixture.now, calendar: fixture.calendar, deliverableCounter: fixture.counter)
        let rows = progress.filter { $0.campaign.provinceID == henan.id }
        XCTAssertEqual(rows.count, 2); XCTAssertTrue(rows.allSatisfy { $0.scopeName == "中原" })
        XCTAssertEqual(stores.campaigns.campaigns.filter { $0.provinceID == henan.id }.count, 2)
        XCTAssertEqual(path(renamed, campaign: "秋季签到").pathComponents.suffix(2), ["河南", "秋季签到"])
    }
}
