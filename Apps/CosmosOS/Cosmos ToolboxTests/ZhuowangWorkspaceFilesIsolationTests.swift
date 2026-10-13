import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class ZhuowangWorkspaceFilesIsolationTests: XCTestCase {
    private func configuration(root: URL?) -> ZhuowangStorePersistenceConfiguration {
        .init(dataSource: ZhuowangInMemoryPersistenceDataSource(storage: [:]),
              isIsolated: true, workspaceFilesRootURL: root)
    }

    func testBootstrapAcceptsOnlyTemporaryUUIDRoot() throws {
        let suite = CosmosDebugStorePersistenceBootstrap.suitePrefix + UUID().uuidString
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let root = "/private/tmp/CosmosWorkspaceFiles-" + UUID().uuidString
        let args = ["test", CosmosDebugStorePersistenceBootstrap.suiteArgument, suite,
                    CosmosDebugStorePersistenceBootstrap.workspaceFilesArgument, root]
        let bundle = CosmosDebugStorePersistenceBootstrap.isolatedBundleIdentifierPrefix + "C0"
        guard case .ready(let config) = CosmosDebugStorePersistenceBootstrap.resolve(arguments: args, bundleIdentifier: bundle) else {
            return XCTFail("Expected isolated configuration")
        }
        XCTAssertEqual(config.workspaceFileManager.cosmosRootURL.path, root)
        XCTAssertTrue(root.hasPrefix("/private/tmp/"))
        XCTAssertFalse(root.hasPrefix(NSHomeDirectory() + "/Documents/"))
        for path in [NSHomeDirectory() + "/Documents/Cosmos OS", root + "/../escape", root + "/nested", "/tmp/CosmosWorkspaceFiles-" + UUID().uuidString] {
            XCTAssertNil(CosmosDebugStorePersistenceBootstrap.workspaceFilesRoot(arguments: [args[3], path]))
        }
        guard case .blocked = CosmosDebugStorePersistenceBootstrap.resolve(arguments: ["test", args[3], root], bundleIdentifier: bundle) else {
            return XCTFail("Root without suite must be blocked")
        }
    }

    func testMissingAndInvalidRootFailClosed() throws {
        let manager = configuration(root: nil).workspaceFileManager
        XCTAssertNotNil(manager.accessFailure)
        XCTAssertThrowsError(try manager.createCampaignWorkspace(provinceName: "合成", campaignName: "拒绝写入"))
        XCTAssertThrowsError(try manager.writeMarkdownArtifact(provinceName: nil, campaignName: "拒绝", stepKind: .brief,
            artifactName: "需求", version: 1, content: "正文"))
        XCTAssertThrowsError(try manager.writeHTMLArtifact(provinceName: nil, campaignName: "拒绝", stepKind: .prototype,
            artifactName: "原型", version: 1, content: "<html>合成</html>"))
        XCTAssertTrue(manager.existingArtifactVersions(provinceName: nil, campaignName: "拒绝", stepKind: .brief,
            artifactName: "需求", fileExtension: "md").isEmpty)
        XCTAssertTrue(manager.discoverLocalArtifacts(provinceName: "合成", campaignName: "拒绝读取").isEmpty)
        XCTAssertFalse(manager.fileExists(atPath: NSHomeDirectory() + "/Documents/Cosmos OS"))
        let store = ZhuowangWorkflowStore(persistenceConfiguration: configuration(root: nil))
        let campaign = ZhuowangCampaign(name: "合成", scopeType: .other, startDate: Date(), endDate: Date())
        XCTAssertEqual(store.migrateLegacyArtifactsToLocalFiles(campaign: campaign, provinceName: nil), 0)
        XCTAssertFalse(store.recoverWorkflowFromLocalFiles(campaign: campaign, provinceName: nil).didRecoverAnything)
        XCTAssertNil(CosmosDebugStorePersistenceBootstrap.workspaceFilesRoot(arguments: []))
        XCTAssertNil(CosmosDebugStorePersistenceBootstrap.workspaceFilesRoot(arguments: [CosmosDebugStorePersistenceBootstrap.workspaceFilesArgument, "invalid"]))
    }

    func testNonIsolatedConfigurationKeepsSharedManager() {
        XCTAssertTrue(ZhuowangStorePersistenceConfiguration.production.workspaceFileManager === ZhuowangWorkspaceFileManager.shared)
    }

    func testRecoveryAndMigrationUseOnlyInjectedRoot() throws {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosWorkspaceFiles-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = configuration(root: root)
        let store = ZhuowangWorkflowStore(persistenceConfiguration: config)
        let campaign = ZhuowangCampaign(name: "C0 合成", scopeType: .other, startDate: Date(), endDate: Date())
        let file = try store.workspaceFileManager.writeMarkdownArtifact(provinceName: "合成省", campaignName: campaign.name,
            stepKind: .brief, artifactName: "需求整理", version: 1, content: "隔离恢复正文")
        XCTAssertEqual(store.recoverWorkflowFromLocalFiles(campaign: campaign, provinceName: "合成省").importedArtifacts, 1)
        var workflow = try XCTUnwrap(store.workflow(forCampaignID: campaign.id))
        let step = try XCTUnwrap(workflow.steps.first { $0.kind == .idea })
        workflow.artifacts.append(.init(campaignID: campaign.id, stepID: step.id, name: "策划思路", type: .markdown,
            content: "隔离迁移正文", version: 1, isApprovedVersion: false))
        store.updateWorkflow(workflow)
        XCTAssertEqual(store.migrateLegacyArtifactsToLocalFiles(campaign: campaign, provinceName: "合成省"), 1)
        XCTAssertEqual(CosmosDebugStorePersistenceBootstrap.workspaceFilesRoot(arguments:
            [CosmosDebugStorePersistenceBootstrap.workspaceFilesArgument, root.path])?.path, root.path)
        let artifacts = try XCTUnwrap(store.workflow(forCampaignID: campaign.id)).artifacts
        XCTAssertEqual(artifacts.count, 2)
        XCTAssertTrue(artifacts.allSatisfy { $0.location.hasPrefix(root.path + "/") })
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "隔离恢复正文")
        let entries = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
        for case let url as URL in entries { XCTAssertTrue(url.path.hasPrefix(root.path + "/")) }
    }

    func testRecoveryRepeatedCallsPreserveWorkflowAndPayload() throws {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosWorkspaceFiles-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = configuration(root: root)
        let store = ZhuowangWorkflowStore(persistenceConfiguration: config)
        let campaign = ZhuowangCampaign(name: "恢复幂等夹具", scopeType: .other, startDate: Date(), endDate: Date())
        _ = try store.workspaceFileManager.writeMarkdownArtifact(provinceName: nil, campaignName: campaign.name,
            stepKind: .brief, artifactName: "需求整理", version: 1, content: "合成正文")
        XCTAssertTrue(store.recoverWorkflowFromLocalFiles(campaign: campaign, provinceName: nil).didRecoverAnything)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(store.workflows)
        let payload = config.dataSource.data(forKey: ZhuowangWorkflowStore.workflowStorageKey)
        for _ in 0..<2 {
            XCTAssertFalse(store.recoverWorkflowFromLocalFiles(campaign: campaign, provinceName: nil).didRecoverAnything)
            XCTAssertEqual(try encoder.encode(store.workflows), before)
            XCTAssertEqual(config.dataSource.data(forKey: ZhuowangWorkflowStore.workflowStorageKey), payload)
            XCTAssertEqual(store.workflow(forCampaignID: campaign.id)?.artifacts.count, 1)
        }
    }

    func testLegacyMigrationRepeatedCallsPreserveWorkflowAndFile() throws {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosWorkspaceFiles-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = configuration(root: root)
        let store = ZhuowangWorkflowStore(persistenceConfiguration: config)
        let campaign = ZhuowangCampaign(name: "迁移幂等夹具", scopeType: .other, startDate: Date(), endDate: Date())
        var workflow = store.getOrCreateWorkflow(forCampaignID: campaign.id)
        let step = try XCTUnwrap(workflow.steps.first { $0.kind == .brief })
        workflow.artifacts.append(.init(campaignID: campaign.id, stepID: step.id, name: "需求整理", type: .markdown,
            content: "合成迁移正文", version: 1, isApprovedVersion: false))
        store.updateWorkflow(workflow)
        XCTAssertEqual(store.migrateLegacyArtifactsToLocalFiles(campaign: campaign, provinceName: nil), 1)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(store.workflows)
        let payload = config.dataSource.data(forKey: ZhuowangWorkflowStore.workflowStorageKey)
        let artifact = try XCTUnwrap(store.workflow(forCampaignID: campaign.id)?.artifacts.first)
        let fileURL = URL(fileURLWithPath: artifact.location)
        let fileData = try Data(contentsOf: fileURL)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        for _ in 0..<2 {
            XCTAssertEqual(store.migrateLegacyArtifactsToLocalFiles(campaign: campaign, provinceName: nil), 0)
            XCTAssertEqual(try encoder.encode(store.workflows), before)
            XCTAssertEqual(config.dataSource.data(forKey: ZhuowangWorkflowStore.workflowStorageKey), payload)
            XCTAssertEqual(store.workflow(forCampaignID: campaign.id)?.artifacts.count, 1)
            XCTAssertEqual(try Data(contentsOf: fileURL), fileData)
            XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date,
                attributes[.modificationDate] as? Date)
        }
    }

    func testRepeatedAppearRecoveryThenMigrationPreservesFirstPass() throws {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosWorkspaceFiles-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = configuration(root: root)
        let store = ZhuowangWorkflowStore(persistenceConfiguration: config)
        let campaign = ZhuowangCampaign(name: "重复出现夹具", scopeType: .other, startDate: Date(), endDate: Date())
        var workflow = store.getOrCreateWorkflow(forCampaignID: campaign.id)
        let step = try XCTUnwrap(workflow.steps.first { $0.kind == .brief })
        workflow.artifacts.append(.init(campaignID: campaign.id, stepID: step.id, name: "需求整理", type: .markdown,
            content: "合成旧版正文", version: 1, isApprovedVersion: false))
        store.updateWorkflow(workflow)
        XCTAssertFalse(store.recoverWorkflowFromLocalFiles(campaign: campaign, provinceName: nil).didRecoverAnything)
        XCTAssertEqual(store.migrateLegacyArtifactsToLocalFiles(campaign: campaign, provinceName: nil), 1)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(store.workflows)
        let payload = config.dataSource.data(forKey: ZhuowangWorkflowStore.workflowStorageKey)
        let writes = (config.dataSource as? ZhuowangInMemoryPersistenceDataSource)?.writeCount
        let second = store.recoverWorkflowFromLocalFiles(campaign: campaign, provinceName: nil)
        XCTAssertFalse(second.didRecoverAnything, "重复 appear 不应在迁移生成文件后再次恢复步骤")
        XCTAssertEqual(store.migrateLegacyArtifactsToLocalFiles(campaign: campaign, provinceName: nil), 0)
        XCTAssertEqual(try encoder.encode(store.workflows), before)
        XCTAssertEqual(config.dataSource.data(forKey: ZhuowangWorkflowStore.workflowStorageKey), payload)
        XCTAssertEqual(store.workflow(forCampaignID: campaign.id)?.artifacts.count, 1)
        XCTAssertEqual(store.workflow(forCampaignID: campaign.id)?.steps.first { $0.id == step.id }?.status, step.status)
        XCTAssertEqual(store.workflow(forCampaignID: campaign.id)?.artifacts.first?.isApprovedVersion, false)
        XCTAssertEqual((config.dataSource as? ZhuowangInMemoryPersistenceDataSource)?.writeCount, writes)
    }

    private func recoveryFixture() -> (URL, ZhuowangWorkflowStore, ZhuowangCampaign) {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosWorkspaceFiles-" + UUID().uuidString, isDirectory: true)
        return (root, ZhuowangWorkflowStore(persistenceConfiguration: configuration(root: root)),
                ZhuowangCampaign(name: "合成恢复", scopeType: .other, startDate: Date(), endDate: Date()))
    }

    func testMissingMetadataRecoversHighestVersionAndAmbiguity() throws {
        let (root, store, campaign) = recoveryFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        for version in [1, 3] {
            _ = try store.workspaceFileManager.writeMarkdownArtifact(provinceName: nil, campaignName: campaign.name,
                stepKind: .brief, artifactName: "需求整理", version: version, content: "合成版本\(version)")
        }
        let summary = store.recoverWorkflowFromLocalFiles(campaign: campaign, provinceName: nil)
        let workflow = try XCTUnwrap(store.workflow(forCampaignID: campaign.id))
        XCTAssertEqual(summary.importedArtifacts, 2)
        XCTAssertEqual(summary.restoredSteps, 1)
        XCTAssertEqual(summary.ambiguousArtifactNames, ["需求整理"])
        XCTAssertEqual(workflow.steps.first { $0.kind == .brief }?.status, .approved)
        XCTAssertEqual(workflow.artifacts.filter(\.isApprovedVersion).map(\.version), [3])
        let stable = store.workflows
        let source = try XCTUnwrap(store.persistenceConfiguration.dataSource as? ZhuowangInMemoryPersistenceDataSource)
        let writes = source.writeCount
        XCTAssertFalse(store.recoverWorkflowFromLocalFiles(campaign: campaign, provinceName: nil).didRecoverAnything)
        XCTAssertEqual(store.workflows, stable)
        XCTAssertEqual(source.writeCount, writes)
    }

    func testPartialMetadataPreservesRegisteredDraftAndRecoversMissingGroup() throws {
        for registeredStatus in [ZhuowangWorkflowStepStatus.needsRevision, .failed, .skipped, .notStarted] {
            let (root, store, campaign) = recoveryFixture()
            defer { try? FileManager.default.removeItem(at: root) }
            let file = try store.workspaceFileManager.writeMarkdownArtifact(provinceName: nil, campaignName: campaign.name,
                stepKind: .brief, artifactName: "需求整理", version: 1, content: "登记草稿")
            var workflow = store.getOrCreateWorkflow(forCampaignID: campaign.id)
            let briefIndex = try XCTUnwrap(workflow.steps.firstIndex { $0.kind == .brief })
            workflow.steps[briefIndex].status = registeredStatus
            let registered = ZhuowangArtifact(campaignID: campaign.id, stepID: workflow.steps[briefIndex].id,
                name: "需求整理", type: .markdown, location: file.path, content: "登记草稿", version: 1, isApprovedVersion: false)
            workflow.artifacts.append(registered)
            store.updateWorkflow(workflow)
            _ = try store.workspaceFileManager.writeMarkdownArtifact(provinceName: nil, campaignName: campaign.name,
                stepKind: .idea, artifactName: "策划思路", version: 1, content: "缺失元数据正文")
            let summary = store.recoverWorkflowFromLocalFiles(campaign: campaign, provinceName: nil)
            let after = try XCTUnwrap(store.workflow(forCampaignID: campaign.id))
            XCTAssertEqual(summary.importedArtifacts, 1)
            XCTAssertEqual(summary.restoredSteps, 1)
            XCTAssertTrue(summary.ambiguousArtifactNames.isEmpty)
            XCTAssertEqual(after.artifacts.first { $0.id == registered.id }, registered)
            XCTAssertEqual(after.steps[briefIndex], workflow.steps[briefIndex])
            XCTAssertEqual(after.steps.first { $0.kind == .idea }?.status, .approved)
            XCTAssertEqual(after.artifacts.first { $0.name == "策划思路" }?.isApprovedVersion, true)
        }
    }

    func testCustomerServiceRecoveryDoesNotApproveOrAdopt() throws {
        let (root, store, campaign) = recoveryFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try store.workspaceFileManager.writeMarkdownArtifact(provinceName: nil, campaignName: campaign.name,
            stepKind: .customerService, artifactName: "客服文档", version: 1, content: "合成客服正文")
        let summary = store.recoverWorkflowFromLocalFiles(campaign: campaign, provinceName: nil)
        let workflow = try XCTUnwrap(store.workflow(forCampaignID: campaign.id))
        XCTAssertEqual(summary.importedArtifacts, 1)
        XCTAssertEqual(summary.restoredSteps, 0)
        XCTAssertNotEqual(workflow.steps.first { $0.kind == .customerService }?.status, .approved)
        XCTAssertEqual(workflow.artifacts.first?.isApprovedVersion, false)
        XCTAssertTrue(summary.ambiguousArtifactNames.isEmpty)
    }

    func testAdoptedPlanV1PrototypeV3CustomerServiceV1SurviveRepeatedRecoveryAndMigration() throws {
        let (root, store, campaign) = recoveryFixture()
        defer { try? FileManager.default.removeItem(at: root) }
        var workflow = store.getOrCreateWorkflow(forCampaignID: campaign.id)
        for (kind, name, versions, adopted) in [
            (ZhuowangWorkflowStepKind.plan, "完整策划案", [1, 2], 1),
            (.prototype, "产品原型设计", [1, 3, 4], 3),
            (.customerService, "客服文档", [1], 1)
        ] {
            let step = try XCTUnwrap(workflow.steps.first { $0.kind == kind })
            for version in versions {
                workflow.artifacts.append(.init(campaignID: campaign.id, stepID: step.id, name: name,
                    type: kind == .prototype ? .html : .markdown,
                    logicalKey: kind == .prototype ? "workflow.prototypeDesign.primary" :
                        kind == .customerService ? ZhuowangCustomerServiceArtifact.logicalKey : nil,
                    content: kind == .prototype ? "<html>合成</html>" : "合成正文",
                    version: version, isApprovedVersion: version == adopted))
            }
        }
        store.updateWorkflow(workflow)
        let expected = workflow.artifacts.filter(\.isApprovedVersion).map(\.id)
        for _ in 0..<2 {
            XCTAssertFalse(store.recoverWorkflowFromLocalFiles(campaign: campaign, provinceName: nil).didRecoverAnything)
            _ = store.migrateLegacyArtifactsToLocalFiles(campaign: campaign, provinceName: nil)
            XCTAssertEqual(store.workflow(forCampaignID: campaign.id)?.artifacts.filter(\.isApprovedVersion).map(\.id), expected)
        }
        _ = try store.workspaceFileManager.writeMarkdownArtifact(provinceName: nil, campaignName: campaign.name,
            stepKind: .customerService, artifactName: "客服文档", version: 2, content: "新找回客服")
        XCTAssertEqual(store.recoverWorkflowFromLocalFiles(campaign: campaign, provinceName: nil).importedArtifacts, 1)
        XCTAssertEqual(store.workflow(forCampaignID: campaign.id)?.artifacts.filter(\.isApprovedVersion).map(\.id), expected)
    }
}
