import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class CoreBackupTests: XCTestCase {
    private var roots: [URL] = []
    private final class Bytes { var values: [String: Data] = [:]; var reads = [String]() }
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots = []; super.tearDown()
    }
    private func root() throws -> URL {
        let url = URL(fileURLWithPath: "/private/tmp/CosmosCoreBackup-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        roots.append(url); return url
    }
    private func source(_ bytes: Bytes, _ root: URL) -> CoreBackupSource {
        CoreBackupSource(readPreference: { key in bytes.reads.append(key); return bytes.values[key] },
            fileRoots: [root.appendingPathComponent("prompts"), root.appendingPathComponent("learning"), root.appendingPathComponent("handoffs"), root.appendingPathComponent("projects")])
    }
    private func write(_ data: Data, root: URL, path: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
    private func fixture(_ bytes: Bytes, _ root: URL) throws {
        let encoder = JSONEncoder()
        let campaign = ZhuowangCampaign(name: "备份活动", scopeType: .national, startDate: Date(), endDate: Date())
        let step = ZhuowangWorkflowStep(title: "步骤", sortOrder: 10)
        let workflow = ZhuowangCampaignWorkflow(campaignID: campaign.id, steps: [step], artifacts: [
            ZhuowangArtifact(campaignID: campaign.id, stepID: step.id, name: "原文", type: .markdown,
                location: "/not/read/source.md", content: "  原文 e\u{301}\r\n尾部  \n", isApprovedVersion: true)])
        let provider = ZhuowangAIProvider(name: "Provider", kind: .custom, configurationIdentifier: "excluded-provider-secret")
        let connection = ZhuowangAIConnection(providerID: provider.id, name: "Connection", mode: .api,
            adapterIdentifier: "excluded-adapter-secret", endpointOrPath: "https://user:excluded-endpoint-secret@example.test", configuration: ["token": "excluded-token-secret", "safe": "also-excluded"], notes: "excluded-notes-secret")
        let tool = ZhuowangExternalToolIntegration(kind: .custom, name: "Tool", configuration: ["apiKey": "excluded-tool-secret"])
        let route = ZhuowangAgentToolRoute(connectionID: connection.id, toolIntegrationID: tool.id, configuration: ["authorization": "excluded-route-secret"])
        let values = [try encoder.encode([campaign]), try encoder.encode(ZhuowangWorkspaceSnapshot(modules: [], provinces: [], categories: [])),
            try encoder.encode([workflow]), try encoder.encode([provider]), try encoder.encode([connection]), try encoder.encode([tool]), try encoder.encode([route])]
        for (index,key) in CoreBackupSource.keys.enumerated() { bytes.values[key] = values[index] }
        var connectionJSON = try JSONSerialization.jsonObject(with: bytes.values[CoreBackupSource.keys[4]]!) as! [[String: Any]]
        connectionJSON[0]["futureSecret"] = "excluded-unknown-secret"
        bytes.values[CoreBackupSource.keys[4]] = try JSONSerialization.data(withJSONObject: connectionJSON)
        try write(ProjectsCoding.encoder().encode(ProjectsDocument()), root: root, path: "projects/projects.json")
        try write(encoder.encode(PromptVaultDocument(templates: [.init(name: "Prompt", body: "  提示词 e\u{301}\r\n  ")])), root: root, path: "prompts/templates.json")
        try write(Data("{\"schemaVersion\":1,\"topics\":[],\"entries\":[]}".utf8), root: root, path: "learning/learning.json")
        let record = AIWorkspaceHandoffRecord(id: UUID(), recordedAt: Date(), campaignID: campaign.id, campaignName: campaign.name,
            workflowID: workflow.id, workflowName: workflow.name, stepID: step.id, stepName: step.title, toolIdentifier: "Codex", toolName: "Codex",
            goal: "目标", requirements: "  要求\r\n", prompt: "  全文 e\u{301}\r\n尾部  \n")
        try write(encoder.encode(AIWorkspaceHandoffDocument(records: [record])), root: root, path: "handoffs/handoffs.json")
    }
    private func entries(_ url: URL) throws -> [String: Data] { try CoreBackupArchive.decode(Data(contentsOf: url)) }
    private func rewritten(_ url: URL, _ update: (inout [String: Data]) throws -> Void) throws {
        var items = try entries(url); try update(&items); try CoreBackupArchive.encode(items).write(to: url)
    }
    private func manifest(_ items: inout [String: Data], _ update: (inout CoreBackupManifest) -> Void) throws {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var value = try decoder.decode(CoreBackupManifest.self, from: items["manifest.json"]!)
        update(&value)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        items["manifest.json"] = try encoder.encode(value)
    }
    private func noTemporary(_ root: URL) throws {
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".cosmos-core-backup-") })
    }

    func testAllTenSourcesOriginalPayloadsAndSensitiveConfigurationExcluded() throws {
        let root = try root(), bytes = Bytes(); try fixture(bytes, root)
        let before = bytes.values
        let filePaths = ["prompts/templates.json", "learning/learning.json", "handoffs/handoffs.json"]
        let files = try filePaths.map { try Data(contentsOf: root.appendingPathComponent($0)) }
        let target = root.appendingPathComponent("backup.zip")
        let result = try CoreBackupService(source: source(bytes,root)).export(to: target)
        XCTAssertEqual(result.manifest.sources.count, 11)
        XCTAssertTrue(result.manifest.sources.allSatisfy { $0.status == "present" })
        let items = try entries(target)
        for index in 0..<3 { XCTAssertEqual(items["data/\(CoreBackupSource.ids[index]).json"], before[CoreBackupSource.keys[index]]) }
        for index in 0..<3 { XCTAssertEqual(items["data/\(CoreBackupSource.ids[7+index]).json"], files[index]) }
        for id in ["providers","connections","tools","routes"] {
            let text = String(data: items["data/\(id).json"]!,encoding:.utf8)!
            XCTAssertFalse(text.contains("excluded-")); XCTAssertNotNil(result.manifest.sources.first { $0.id == id }?.transformation)
        }
        XCTAssertFalse(String(data: items["manifest.json"]!,encoding:.utf8)!.contains(root.path))
        XCTAssertEqual(bytes.values,before)
        for (index,path) in filePaths.enumerated() { XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(path)),files[index]) }
        XCTAssertEqual(try CoreBackupService.verify(target).manifest.sources.map(\.sha256),result.manifest.sources.map(\.sha256))
        XCTAssertTrue(Set(bytes.reads).isSubset(of:Set(CoreBackupSource.keys)))
        try noTemporary(root)
    }

    func testMissingVersusEstablishedEmptyAndNoDefaultsCreated() throws {
        let root = try root(), bytes = Bytes(); bytes.values[CoreBackupSource.keys[0]] = Data("[]".utf8)
        let result = try CoreBackupService(source: source(bytes,root)).export(to: root.appendingPathComponent("backup.zip"))
        XCTAssertEqual(result.manifest.sources[0].status,"present")
        XCTAssertEqual(result.manifest.sources.filter { $0.status == "missing" }.count,10)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path),["backup.zip"])
    }

    func testCorruptUnreadableAndMissingPrimaryWithBackupRefusePublication() throws {
        let root = try root(), bytes = Bytes(), target = root.appendingPathComponent("backup.zip")
        bytes.values[CoreBackupSource.keys[0]] = Data("broken".utf8)
        XCTAssertThrowsError(try CoreBackupService(source: source(bytes,root)).export(to:target))
        bytes.values = [CoreBackupSource.keys[0]+".backup":Data("[]".utf8)]
        XCTAssertThrowsError(try CoreBackupService(source: source(bytes,root)).export(to:target))
        bytes.values = [:]
        try write(Data("{}".utf8), root:root,path:"learning/learning.backup.json")
        XCTAssertThrowsError(try CoreBackupService(source: source(bytes,root)).export(to:target))
        let denied = CoreBackupSource(readPreference: { _ in throw CoreBackupError.invalid("不可读取") },fileRoots:[root,root,root,root])
        XCTAssertThrowsError(try CoreBackupService(source:denied).export(to:target))
        XCTAssertFalse(FileManager.default.fileExists(atPath:target.path)); try noTemporary(root)
    }

    func testWrongUserDefaultsTypeRejectedWithoutWriting() throws {
        let suite = "com.wangyucosmos.CosmosCoreBackup.Test."+UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName:suite)); defer { defaults.removePersistentDomain(forName:suite) }
        defaults.set("wrong-type",forKey:CoreBackupSource.keys[0])
        let before = defaults.persistentDomain(forName:suite)! as NSDictionary
        let source = ZhuowangUserDefaultsDataSource(defaults:defaults,domainIdentifier:suite)
        XCTAssertThrowsError(try source.coreBackupData(forKey:CoreBackupSource.keys[0]))
        XCTAssertNil(try source.coreBackupData(forKey:CoreBackupSource.keys[1]))
        XCTAssertEqual(defaults.persistentDomain(forName:suite)! as NSDictionary,before)
    }

    func testSourceChangesAbortAndCleanTemporary() throws {
        let root = try root(), bytes = Bytes(); try fixture(bytes,root)
        let target = root.appendingPathComponent("backup.zip")
        var service = CoreBackupService(source:source(bytes,root))
        service.checkpoint = { bytes.values[CoreBackupSource.keys[0]] = Data("[]".utf8) }
        XCTAssertThrowsError(try service.export(to:target)); XCTAssertFalse(FileManager.default.fileExists(atPath:target.path)); try noTemporary(root)
        service.checkpoint = { try Data("{\"schemaVersion\":1,\"topics\":[],\"entries\":[]}".utf8).write(to:root.appendingPathComponent("learning/learning.json"),options:.atomic) }
        XCTAssertThrowsError(try service.export(to:target)); try noTemporary(root)
    }

    func testExistingTargetAndRacingCreationNeverOverwritten() throws {
        let root = try root(), bytes = Bytes(), target = root.appendingPathComponent("existing.zip"), old = Data("existing".utf8)
        try old.write(to:target)
        XCTAssertThrowsError(try CoreBackupService(source:source(bytes,root)).export(to:target))
        XCTAssertEqual(try Data(contentsOf:target),old)
        let race = root.appendingPathComponent("race.zip")
        var service = CoreBackupService(source:source(bytes,root)); service.checkpoint = { try old.write(to:race) }
        XCTAssertThrowsError(try service.export(to:race)); XCTAssertEqual(try Data(contentsOf:race),old); try noTemporary(root)
    }

    func testTamperMissingExtraAndHashMismatchRejected() throws {
        let root = try root(), bytes = Bytes(); bytes.values[CoreBackupSource.keys[0]] = Data("[]".utf8)
        let target = root.appendingPathComponent("backup.zip"), service = CoreBackupService(source:source(bytes,root))
        _ = try service.export(to:target); let valid = try Data(contentsOf:target)
        try rewritten(target) { $0["data/campaigns.json"] = Data("[ ]".utf8) }
        XCTAssertThrowsError(try CoreBackupService.verify(target))
        try valid.write(to:target); try rewritten(target) { $0.removeValue(forKey:"data/campaigns.json") }
        XCTAssertThrowsError(try CoreBackupService.verify(target))
        try valid.write(to:target); try rewritten(target) { $0["data/workspace.json"] = Data("{}".utf8) }
        XCTAssertThrowsError(try CoreBackupService.verify(target))
        try valid.write(to:target)
        var damaged = valid; damaged[40] ^= 1; try damaged.write(to:target)
        XCTAssertThrowsError(try CoreBackupService.verify(target))
    }

    func testInvalidStructureWithRecomputedHashAndDuplicateManifestRejected() throws {
        let root = try root(),bytes = Bytes(); bytes.values[CoreBackupSource.keys[0]] = Data("[]".utf8)
        let target = root.appendingPathComponent("backup.zip"); _ = try CoreBackupService(source:source(bytes,root)).export(to:target)
        let valid = try Data(contentsOf:target)
        try rewritten(target) { items in
            let body = Data("{}".utf8);items["data/campaigns.json"] = body
            try manifest(&items) { m in m.sources[0] = .init(id:"campaigns",status:"present",path:"data/campaigns.json",bytes:body.count,sha256:CoreBackupService.digest(body),transformation:nil) }
        }
        XCTAssertThrowsError(try CoreBackupService.verify(target))
        try valid.write(to:target)
        try rewritten(target) { items in try manifest(&items) { $0.sources[1] = $0.sources[0] } }
        XCTAssertThrowsError(try CoreBackupService.verify(target))
    }

    func testUnsafeZipNamesDuplicateEntriesSymlinksAndCompressedContentRejected() throws {
        let root = try root(),bytes = Bytes();try fixture(bytes,root)
        let target = root.appendingPathComponent("backup.zip");_ = try CoreBackupService(source:source(bytes,root)).export(to:target)
        let valid = try Data(contentsOf:target)
        func replacing(_ data:Data,_ old:String,_ new:String) -> Data {
            var result = data;var index = 0;let a = Data(old.utf8),b = Data(new.utf8)
            while index <= result.count-a.count {
                if result.subdata(in:index..<(index+a.count)) == a { result.replaceSubrange(index..<(index+a.count),with:b);index += b.count }
                else { index += 1 }
            };return result
        }
        // Equal-length local + central names are changed together, so header agreement alone cannot accept them.
        let duplicate = replacing(valid,"data/providers.json","data/workflows.json")
        XCTAssertThrowsError(try CoreBackupArchive.decode(duplicate))
        let traversal = replacing(valid,"data/providers.json","../x/providers.json")
        XCTAssertThrowsError(try CoreBackupArchive.decode(traversal))
        var compressed = valid; compressed[8] = 8; XCTAssertThrowsError(try CoreBackupArchive.decode(compressed))
        var linked = valid
        let signature = Data([0x50,0x4b,0x01,0x02]);let central = try XCTUnwrap(linked.range(of:signature)).lowerBound
        linked[central+41] = 0xA1; XCTAssertThrowsError(try CoreBackupArchive.decode(linked))
        var count = valid;count[count.count-12] = 255;count[count.count-11] = 255
        XCTAssertThrowsError(try CoreBackupArchive.decode(count))
    }

    func testCapacityLimitsAndSymlinkSourcePackageOrParentRejected() throws {
        let root = try root(),bytes = Bytes(),target = root.appendingPathComponent("backup.zip")
        bytes.values[CoreBackupSource.keys[0]] = Data(repeating:32,count:CoreBackupService.sourceLimit+1)
        XCTAssertThrowsError(try CoreBackupService(source:source(bytes,root)).export(to:target));bytes.values = [:]
        try FileManager.default.createDirectory(at:root.appendingPathComponent("prompts"),withIntermediateDirectories:true)
        try FileManager.default.createSymbolicLink(at:root.appendingPathComponent("prompts/templates.json"),withDestinationURL:root.appendingPathComponent("absent"))
        XCTAssertThrowsError(try CoreBackupService(source:source(bytes,root)).export(to:target))
        let package = root.appendingPathComponent("large.zip");FileManager.default.createFile(atPath:package.path,contents:nil)
        let handle = try FileHandle(forWritingTo:package);try handle.truncate(atOffset:UInt64(CoreBackupService.packageLimit+1));try handle.close()
        XCTAssertThrowsError(try CoreBackupService.verify(package))
        let link = root.appendingPathComponent("link.zip");try FileManager.default.createSymbolicLink(at:link,withDestinationURL:package)
        XCTAssertThrowsError(try CoreBackupService.verify(link))
        let parent = root.appendingPathComponent("linked-parent");try FileManager.default.createSymbolicLink(at:parent,withDestinationURL:root)
        XCTAssertThrowsError(try CoreBackupService(source:source(bytes,root)).export(to:parent.appendingPathComponent("target.zip")));try noTemporary(root)
    }

    func testUnknownVersionAndSensitiveFieldAddedToPackageRejected() throws {
        let root = try root(),bytes = Bytes();try fixture(bytes,root)
        let target = root.appendingPathComponent("backup.zip");_ = try CoreBackupService(source:source(bytes,root)).export(to:target)
        let valid = try Data(contentsOf:target)
        try rewritten(target) { items in try manifest(&items) { $0.version = 3 } };XCTAssertThrowsError(try CoreBackupService.verify(target))
        try valid.write(to:target)
        try rewritten(target) { items in
            var values = try JSONSerialization.jsonObject(with:items["data/connections.json"]!) as! [[String:Any]]
            values[0]["token"] = "synthetic-secret";let body = try JSONSerialization.data(withJSONObject:values);items["data/connections.json"] = body
            try manifest(&items) { m in let index = m.sources.firstIndex { $0.id == "connections" }!;m.sources[index] = .init(id:"connections",status:"present",path:"data/connections.json",bytes:body.count,sha256:CoreBackupService.digest(body),transformation:m.sources[index].transformation) }
        };XCTAssertThrowsError(try CoreBackupService.verify(target))
    }

    func testIsolatedMissingRootsFailsClosedAndSettingsRenders() throws {
        let root = try root(),bytes = Bytes()
        let denied = CoreBackupSource(readPreference:{ _ in XCTFail("must not read");return nil },fileRoots:[])
        XCTAssertThrowsError(try CoreBackupService(source:denied).export(to:root.appendingPathComponent("backup.zip")))
        let view = NSHostingView(rootView:CoreBackupSettingsView(source:source(bytes,root)))
        view.frame = NSRect(x:0,y:0,width:1100,height:850);view.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(view.fittingSize.height,0)
    }
}
