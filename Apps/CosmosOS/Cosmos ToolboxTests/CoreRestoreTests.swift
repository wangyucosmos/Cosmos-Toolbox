import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

nonisolated private final class RestoreMemory:CoreRestorePreferences,@unchecked Sendable {
    private let lock = NSLock()
    private var values:[String:Data] = [:]
    var failKey:String?
    var uncertainKey:String?
    var unreadable = false
    var inserts = 0
    func restoreRead(_ key:String) throws -> Data? {
        lock.lock();defer { lock.unlock() };if unreadable { throw CoreRestoreError.invalid("不可读取") };return values[key]
    }
    func restoreInsert(_ data:Data,key:String) throws {
        lock.lock();defer { lock.unlock() }
        guard values[key] == nil else { throw CoreRestoreError.invalid("存在，不覆盖") }
        if failKey == key { throw CoreRestoreError.invalid("注入写失败") }
        values[key] = data;inserts += 1
        if uncertainKey == key { throw CoreRestoreError.invalid("注入不确定写结果") }
    }
    func restoreRemoveOwned(_ data:Data,key:String) throws -> Bool {
        lock.lock();defer { lock.unlock() };if values[key] == nil { return true }
        guard values[key] == data else { return false };values.removeValue(forKey:key);return true
    }
    func force(_ key:String,_ data:Data) { lock.lock();values[key] = data;lock.unlock() }
    func all() -> [String:Data] { lock.lock();defer { lock.unlock() };return values }
}

@MainActor final class CoreRestoreTests:XCTestCase {
    private var roots:[URL] = []
    override func tearDown() {
        CoreRestoreRuntime.restoredInstallation = false
        for root in roots { try? FileManager.default.removeItem(at:root) };roots = [];super.tearDown()
    }
    private func root() throws -> URL {
        let root = URL(fileURLWithPath:"/private/tmp/CosmosCoreRestoreTest-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);roots.append(root);return root
    }
    private func target(_ root:URL,_ memory:RestoreMemory) -> CoreRestoreTarget {
        .init(preferences:memory,roots:["prompts","learning","handoffs","projects"].map { root.appendingPathComponent($0) },transactionRoot:root.appendingPathComponent("transaction"))
    }
    private func backup(_ root:URL) throws -> (URL,[String:Data]) {
        let encoder = JSONEncoder(), campaign = ZhuowangCampaign(name:"恢复活动",scopeType:.national,startDate:Date(),endDate:Date())
        let step = ZhuowangWorkflowStep(title:"步骤",sortOrder:10), provider = ZhuowangAIProvider(name:"历史 Provider",kind:.custom,isEnabled:true)
        let connection = ZhuowangAIConnection(providerID:provider.id,name:"历史 Connection",mode:.api,status:.available,supportsDirectExecution:true,supportsAutomaticResultReturn:true,isEnabled:true)
        let tool = ZhuowangExternalToolIntegration(kind:.custom,name:"历史 Tool",status:.available)
        let route = ZhuowangAgentToolRoute(connectionID:connection.id,toolIntegrationID:tool.id,status:.available,supportsDirectExecution:true,supportsAutomaticResultReturn:true)
        let run = ZhuowangAIRun(stepID:step.id,providerID:provider.id,connectionID:connection.id,inputText:"  输入 e\u{301}\r\n",outputText:"  输出  \n")
        let workflow = ZhuowangCampaignWorkflow(campaignID:campaign.id,steps:[step],aiRuns:[run],approvals:[.init(stepID:step.id,runID:run.id,decision:.approved,feedback:"  审批原文\r\n")],artifacts:[
            .init(campaignID:campaign.id,stepID:step.id,runID:run.id,name:"同一方案",type:.markdown,logicalKey:"plan",location:"/nonexistent/historical/V1.md",content:"  正文 e\u{301}\r\n尾部  \n",version:1,isApprovedVersion:true),
            .init(campaignID:campaign.id,stepID:step.id,name:"同一方案",type:.markdown,logicalKey:"plan",content:"历史V3",version:3)])
        var data:[String:Data] = ["campaigns":try encoder.encode([campaign]),"workspace":try encoder.encode(ZhuowangWorkspaceSnapshot(modules:[],provinces:[],categories:[])),
            "workflows":try encoder.encode([workflow]),"providers":try encoder.encode([provider]),"connections":try encoder.encode([connection]),"tools":try encoder.encode([tool]),"routes":try encoder.encode([route]),
            "prompts":try encoder.encode(PromptVaultDocument(templates:[.init(name:"原 Prompt",body:"  原文 e\u{301}\r\n尾部  \n")]))]
        let topic = LearningTopic(name:"主题",goal:"  目标\r\n"),day = try XCTUnwrap(LearningDay(string:"2026-10-10"))
        let learningEncoder = JSONEncoder();learningEncoder.dateEncodingStrategy = .iso8601
        data["learning"] = try learningEncoder.encode(LearningDocument(topics:[topic],entries:[.init(topicID:topic.id,studyDay:day,body:"  笔记 e\u{301}\r\n尾部  \n")]))
        data["handoffs"] = try encoder.encode(AIWorkspaceHandoffDocument(records:[.init(id:UUID(),recordedAt:Date(),campaignID:UUID(),campaignName:"已删除活动",workflowID:UUID(),workflowName:"历史流程",stepID:UUID(),stepName:"已删除步骤",toolIdentifier:"Codex",toolName:"Codex",goal:"目标",requirements:"  要求\r\n",prompt:"  完整原文 e\u{301}\r\n尾部  \n")]))
        data["projects"] = try ProjectsCoding.encoder().encode(ProjectsDocument())
        let sourceRoots = ["sourcePrompt","sourceLearning","sourceHandoff","sourceProjects"].map { root.appendingPathComponent($0) }
        for (index,id) in ["prompts","learning","handoffs","projects"].enumerated() {
            try FileManager.default.createDirectory(at:sourceRoots[index],withIntermediateDirectories:true)
            try data[id]!.write(to:sourceRoots[index].appendingPathComponent(CoreRestoreTarget.fileNames[index]+".json"))
        }
        let source = CoreBackupSource(readPreference:{ key in
            guard let index = CoreBackupSource.keys.firstIndex(of:key) else { return nil };return data[CoreBackupSource.ids[index]]
        },fileRoots:sourceRoots)
        let url = root.appendingPathComponent("backup.zip");_ = try CoreBackupService(source:source).export(to:url)
        return (url,data)
    }

    func testBackupRestoreReloadPreservesRawTextIDsRunsApprovalsAdoptionAndNoEntities() throws {
        let root = try root(),memory = RestoreMemory(),target = target(root,memory)
        let (url,source) = try backup(root),plan = try CoreRestoreService.prepare(url),service = CoreRestoreService(target:target)
        try service.restore(plan);XCTAssertEqual(try service.startup(),"readyToLoad")
        for id in ["campaigns","workspace","workflows","prompts","learning","handoffs"] { XCTAssertEqual(try target.read(id:id)?.0,source[id]) }
        let workflows = try JSONDecoder().decode([ZhuowangCampaignWorkflow].self,from:try XCTUnwrap(target.read(id:"workflows")?.0))
        XCTAssertEqual(workflows[0].artifacts.map(\.version),[1,3]);XCTAssertEqual(workflows[0].artifacts.map(\.isApprovedVersion),[true,false])
        XCTAssertEqual(workflows[0].approvals[0].runID,workflows[0].aiRuns[0].id)
        XCTAssertFalse(FileManager.default.fileExists(atPath:workflows[0].artifacts[0].location))
        XCTAssertTrue(plan.warnings.first!.contains("元数据"))
        // Fresh service instances represent a restart; activation is required before Store construction.
        let reloaded = CoreRestoreService(target:target);try reloaded.activateCompleted();XCTAssertEqual(try reloaded.startup(),"restored")
        XCTAssertTrue(try reloaded.journal()!.0.restoredInstallation)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:target.transactionRoot.path).sorted(),[".restore.lock","state.json"])
        for folder in target.roots { XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:folder.path).count,1) }
        XCTAssertEqual(try CoreRestoreService.prepare(url).packageHash,plan.packageHash)
    }

    func testConfigsDisabledNeedsSetupAndNoInventedSecrets() throws {
        let root = try root(),memory = RestoreMemory();let (url,_) = try backup(root),plan = try CoreRestoreService.prepare(url)
        try CoreRestoreService(target:target(root,memory)).restore(plan)
        let decoder = JSONDecoder()
        let connections = try decoder.decode([ZhuowangAIConnection].self,from:memory.restoreRead(CoreBackupSource.keys[4])!)
        XCTAssertEqual(connections[0].status,.needsSetup);XCTAssertFalse(connections[0].isEnabled);XCTAssertFalse(connections[0].allowsAutomaticSelection)
        XCTAssertFalse(connections[0].supportsDirectExecution);XCTAssertFalse(connections[0].supportsAutomaticResultReturn)
        XCTAssertNil(connections[0].endpointOrPath);XCTAssertTrue(connections[0].configuration.isEmpty)
        let tools = try decoder.decode([ZhuowangExternalToolIntegration].self,from:memory.restoreRead(CoreBackupSource.keys[5])!)
        XCTAssertEqual(tools[0].status,.needsSetup);XCTAssertFalse(tools[0].isEnabled)
        let routes = try decoder.decode([ZhuowangAgentToolRoute].self,from:memory.restoreRead(CoreBackupSource.keys[6])!)
        XCTAssertEqual(routes[0].status,.needsSetup);XCTAssertFalse(routes[0].supportsDirectExecution)
        let providers = try decoder.decode([ZhuowangAIProvider].self,from:memory.restoreRead(CoreBackupSource.keys[3])!)
        XCTAssertFalse(providers[0].isEnabled);XCTAssertNil(providers[0].configurationIdentifier)
    }

    func testPreviewCancelAndUnconfirmedActionPerformZeroWrites() async throws {
        let root = try root(),memory = RestoreMemory(),target = target(root,memory);let (url,_) = try backup(root)
        let model = CoreRestoreViewModel(target:target)
        await model.choose(url);XCTAssertNotNil(model.plan);XCTAssertEqual(memory.inserts,0)
        await model.confirm(confirmed:false);XCTAssertEqual(memory.inserts,0)
        model.cancel();XCTAssertNil(model.plan);XCTAssertFalse(FileManager.default.fileExists(atPath:target.transactionRoot.path))
        XCTAssertTrue(target.roots.allSatisfy { !FileManager.default.fileExists(atPath:$0.path) })
    }

    func testExistingEmptyCorruptUnreadableAndBackupTargetsRejected() throws {
        let root = try root(),memory = RestoreMemory(),target = target(root,memory);let (url,_) = try backup(root),plan = try CoreRestoreService.prepare(url)
        for value in [Data("[]".utf8),Data("broken".utf8)] {
            memory.force(CoreBackupSource.keys[0],value)
            XCTAssertThrowsError(try CoreRestoreService(target:target).restore(plan));XCTAssertEqual(memory.inserts,0)
        }
        let backupMemory = RestoreMemory();backupMemory.force(CoreBackupSource.keys[0]+".backup",Data("[]".utf8))
        XCTAssertThrowsError(try CoreRestoreService(target:self.target(root,backupMemory)).restore(plan))
        let unavailable = RestoreMemory();unavailable.unreadable = true
        XCTAssertThrowsError(try CoreRestoreService(target:self.target(root,unavailable)).restore(plan))
        for name in ["templates.json","templates.backup.json",".prompt.lock"] {
            let folder = root.appendingPathComponent("fileTarget-"+name);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            try Data("{}".utf8).write(to:folder.appendingPathComponent(name))
            let fileTarget = CoreRestoreTarget(preferences:RestoreMemory(),roots:[folder,target.roots[1],target.roots[2],target.roots[3]],transactionRoot:target.transactionRoot)
            XCTAssertThrowsError(try CoreRestoreService(target:fileTarget).restore(plan))
        }
    }

    func testCorruptBackupAndBrokenStructuralAssociationRefusedBeforeTransaction() async throws {
        let root = try root(),memory = RestoreMemory(),target = target(root,memory);let (url,_) = try backup(root)
        let original = try Data(contentsOf:url);try Data("bad".utf8).write(to:url)
        let model = CoreRestoreViewModel(target:target);await model.choose(url);XCTAssertNil(model.plan);XCTAssertEqual(memory.inserts,0)
        try original.write(to:url)
        var entries = try CoreBackupArchive.decode(original)
        var workflows = try JSONDecoder().decode([ZhuowangCampaignWorkflow].self,from:entries["data/workflows.json"]!)
        workflows[0].campaignID = UUID();let data = try JSONEncoder().encode(workflows);entries["data/workflows.json"] = data
        let decoder = JSONDecoder();decoder.dateDecodingStrategy = .iso8601
        var manifest = try decoder.decode(CoreBackupManifest.self,from:entries["manifest.json"]!)
        let index = manifest.sources.firstIndex { $0.id == "workflows" }!
        manifest.sources[index] = .init(id:"workflows",status:"present",path:"data/workflows.json",bytes:data.count,sha256:CoreBackupService.digest(data),transformation:nil)
        let encoder = JSONEncoder();encoder.dateEncodingStrategy = .iso8601;entries["manifest.json"] = try encoder.encode(manifest)
        try CoreBackupArchive.encode(entries).write(to:url)
        _ = try CoreBackupService.verify(url)
        XCTAssertThrowsError(try CoreRestoreService.prepare(url));XCTAssertFalse(FileManager.default.fileExists(atPath:target.transactionRoot.path))
    }

    func testBackupChangeAfterPreviewRejectedBeforeTargetWrites() throws {
        let root = try root(),memory = RestoreMemory(),target = target(root,memory);let (url,_) = try backup(root),plan = try CoreRestoreService.prepare(url)
        try Data(contentsOf:url).write(to:url,options:.atomic)
        XCTAssertThrowsError(try CoreRestoreService(target:target).restore(plan));XCTAssertEqual(memory.inserts,0)
        XCTAssertFalse(FileManager.default.fileExists(atPath:target.transactionRoot.path))
    }

    func testWriteFailureRollsBackConfirmedPrefixAndDoesNotLookSuccessful() throws {
        let root = try root(),memory = RestoreMemory(),target = target(root,memory);let (url,_) = try backup(root),plan = try CoreRestoreService.prepare(url)
        memory.failKey = CoreBackupSource.keys[3]
        XCTAssertThrowsError(try CoreRestoreService(target:target).restore(plan));XCTAssertTrue(memory.all().isEmpty)
        XCTAssertEqual(try CoreRestoreService(target:target).startup(),"empty")
        XCTAssertTrue(target.roots.allSatisfy { !FileManager.default.fileExists(atPath:$0.path) })
    }

    func testTargetChangesPreservedAndStartupBlocked() throws {
        let root = try root(),memory = RestoreMemory(),target = target(root,memory);let (url,_) = try backup(root),plan = try CoreRestoreService.prepare(url)
        let foreign = Data("foreign".utf8);var service = CoreRestoreService(target:target)
        service.checkpoint = { point in if point == .beforeWrite("workspace") { memory.force(CoreBackupSource.keys[0],foreign) } }
        XCTAssertThrowsError(try service.restore(plan));XCTAssertEqual(try memory.restoreRead(CoreBackupSource.keys[0]),foreign)
        XCTAssertEqual(try service.startup(),"interrupted")
        XCTAssertFalse(try service.rollbackInterrupted());XCTAssertEqual(try memory.restoreRead(CoreBackupSource.keys[0]),foreign)
    }

    func testInterruptionPersistsAndExplicitRollbackSurvivesNewService() throws {
        let root = try root(),memory = RestoreMemory(),target = target(root,memory);let (url,_) = try backup(root),plan = try CoreRestoreService.prepare(url)
        var service = CoreRestoreService(target:target);service.checkpoint = { point in if point == .afterWrite("learning") { throw CoreRestoreError.simulatedInterruption } }
        XCTAssertThrowsError(try service.restore(plan));XCTAssertEqual(try service.startup(),"interrupted")
        let restarted = CoreRestoreService(target:target);XCTAssertTrue(try restarted.rollbackInterrupted());XCTAssertEqual(try restarted.startup(),"empty")
        XCTAssertTrue(memory.all().isEmpty)
        for root in target.roots { if FileManager.default.fileExists(atPath:root.path) { XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:root.path).isEmpty) } }
    }

    func testUncertainPreferenceWriteNeverDeletedOrLoadedAsSuccess() throws {
        let root = try root(),memory = RestoreMemory(),target = target(root,memory);let (url,_) = try backup(root),plan = try CoreRestoreService.prepare(url)
        memory.uncertainKey = CoreBackupSource.keys[1]
        XCTAssertThrowsError(try CoreRestoreService(target:target).restore(plan))
        XCTAssertNotNil(try memory.restoreRead(CoreBackupSource.keys[1]));XCTAssertEqual(try CoreRestoreService(target:target).startup(),"interrupted")
        XCTAssertFalse(try CoreRestoreService(target:target).rollbackInterrupted())
    }

    func testChangedFileAndSymlinkDoNotGetDeletedDuringRollback() throws {
        let root = try root(),memory = RestoreMemory(),target = target(root,memory);let (url,_) = try backup(root),plan = try CoreRestoreService.prepare(url)
        var service = CoreRestoreService(target:target)
        let prompt = target.fileURL(id:"prompts")!,foreign = Data("changed file".utf8)
        service.checkpoint = { point in if point == .afterWrite("prompts") { try foreign.write(to:prompt,options:.atomic);throw CoreRestoreError.invalid("stop") } }
        XCTAssertThrowsError(try service.restore(plan));XCTAssertEqual(try Data(contentsOf:prompt),foreign);XCTAssertEqual(try service.startup(),"interrupted")
        XCTAssertFalse(try service.rollbackInterrupted())
        let other = try self.root(),otherTarget = self.target(other,RestoreMemory())
        try FileManager.default.createSymbolicLink(at:otherTarget.roots[0],withDestinationURL:root)
        XCTAssertThrowsError(try otherTarget.requireEmpty())
    }

    func testCompleteMarkerTamperBlocksReloadAndEnvironmentChoicePreventsLaterRestore() throws {
        let root = try root(),memory = RestoreMemory(),target = target(root,memory);let (url,_) = try backup(root),plan = try CoreRestoreService.prepare(url)
        let service = CoreRestoreService(target:target);try service.restore(plan)
        memory.force(CoreBackupSource.keys[0],Data("changed".utf8));XCTAssertThrowsError(try service.activateCompleted())
        XCTAssertNotEqual(try service.startup(),"existing")
        let new = try self.root(),newTarget = self.target(new,RestoreMemory()),newService = CoreRestoreService(target:newTarget)
        try newService.beginNewEnvironment();XCTAssertEqual(try newService.startup(),"existing")
        XCTAssertThrowsError(try newService.restore(plan))
        try Data("corrupt marker".utf8).write(to:newTarget.stateURL);XCTAssertThrowsError(try newService.startup())
    }

    func testFreshPreferencesWrapperPersistsRestoreAndWorkflowDoesNotRenormalizeIDs() throws {
        let root = try root(),suite = "com.wangyucosmos.CosmosRestore.Test."+UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName:suite));defer { defaults.removePersistentDomain(forName:suite) }
        let source = ZhuowangUserDefaultsDataSource(defaults:defaults,domainIdentifier:suite)
        let target = CoreRestoreTarget(preferences:source,roots:["p","l","h","j"].map { root.appendingPathComponent($0) },transactionRoot:root.appendingPathComponent("transaction"))
        let (url,_) = try backup(root),plan = try CoreRestoreService.prepare(url),service = CoreRestoreService(target:target)
        try service.restore(plan)
        let fresh = ZhuowangUserDefaultsDataSource(defaults:try XCTUnwrap(UserDefaults(suiteName:suite)),domainIdentifier:suite)
        for index in 0..<7 { XCTAssertEqual(try fresh.restoreRead(CoreBackupSource.keys[index]),plan.payloads[CoreBackupSource.ids[index]]) }
        try service.activateCompleted();CoreRestoreRuntime.restoredInstallation = true
        let before = defaults.persistentDomain(forName:suite)! as NSDictionary
        let store = ZhuowangWorkflowStore(persistenceConfiguration:.init(dataSource:fresh,isIsolated:true),workspaceFileManager:.init(rootURL:root.appendingPathComponent("workspace")))
        XCTAssertEqual(store.providers.count,1);XCTAssertFalse(store.providers[0].isEnabled)
        XCTAssertEqual(defaults.persistentDomain(forName:suite)! as NSDictionary,before)
    }

    func testMissingSourcesRemainAbsentAndSafePreviewRenders() throws {
        let root = try root(),memory = RestoreMemory(),target = target(root,memory)
        let source = CoreBackupSource(readPreference:{ key in key == CoreBackupSource.keys[0] ? Data("[]".utf8) : nil },fileRoots:[root.appendingPathComponent("a"),root.appendingPathComponent("b"),root.appendingPathComponent("c"),root.appendingPathComponent("d")])
        let url = root.appendingPathComponent("minimal.zip");_ = try CoreBackupService(source:source).export(to:url)
        let plan = try CoreRestoreService.prepare(url);XCTAssertEqual(plan.payloads.count,1)
        try CoreRestoreService(target:target).restore(plan);XCTAssertEqual(memory.all().count,1)
        XCTAssertTrue(target.roots.allSatisfy { !FileManager.default.fileExists(atPath:$0.path) })
        let view = NSHostingView(rootView:CoreRestoreView(target:target));view.frame = NSRect(x:0,y:0,width:1100,height:850);view.layoutSubtreeIfNeeded();XCTAssertGreaterThan(view.fittingSize.height,0)
    }
}
