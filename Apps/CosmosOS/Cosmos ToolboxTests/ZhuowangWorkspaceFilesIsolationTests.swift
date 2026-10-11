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
}
