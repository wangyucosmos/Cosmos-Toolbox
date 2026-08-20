import XCTest
@testable import Cosmos_Toolbox

final class ZhuowangStep05Tests: XCTestCase {

    func testHTMLToolUsesStableIDAndSupportsPrototypeDesign() {
        let first = ZhuowangHTMLPrototypeAdapter()
        let second = ZhuowangHTMLPrototypeAdapter()

        XCTAssertEqual(first.toolID, second.toolID)
        XCTAssertEqual(
            first.toolID,
            ZhuowangBuiltInIntegrationIDs.htmlPrototypeTool
        )
        XCTAssertTrue(first.supports(capability: .prototypeDesign))
    }


    func testExecutionSnapshotRoundTripPreservesEntireRoute() throws {
        let snapshot = ZhuowangWorkflowExecutionSnapshot(
            workflowID: UUID(),
            workflowStepID: UUID(),
            providerID: UUID(),
            connectionID: UUID(),
            toolIntegrationID: UUID(),
            routeID: UUID(),
            capability: .prototypeDesign,
            adapterIdentifier: "deepseek-harness-html-prototype"
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(
            ZhuowangWorkflowExecutionSnapshot.self,
            from: data
        )

        XCTAssertEqual(decoded, snapshot)
    }


    func testRegistryFindsHTMLAdapter() {
        let registry = ZhuowangToolAdapterRegistry()

        let adapter = registry.find(
            toolID: ZhuowangBuiltInIntegrationIDs.htmlPrototypeTool
        )

        XCTAssertNotNil(adapter)
        XCTAssertTrue(
            adapter?.supports(capability: .prototypeDesign) == true
        )
    }


    func testHTMLAdapterUsesRealResultAndRejectsPlaceholder() async throws {
        let adapter = ZhuowangHTMLPrototypeAdapter()
        let taskPackage = ZhuowangAITaskPackage(
            campaignID: UUID(),
            workflowStepID: UUID(),
            title: "产品原型设计",
            instruction: "生成产品原型"
        )
        let html = """
        <!doctype html>
        <html><head><meta charset="utf-8"><title>V1</title></head>
        <body><main>真实原型</main></body></html>
        """

        let draft = try await adapter.execute(
            taskPackage: taskPackage,
            rawAIResult: html
        )

        XCTAssertEqual(draft.type, .html)
        XCTAssertTrue(draft.content.contains("真实原型"))
        XCTAssertTrue(
            draft.content.contains("Content-Security-Policy")
        )

        let placeholder = """
        <html><head><title>V1</title></head>
        <body>HTML Prototype Placeholder</body></html>
        """

        do {
            _ = try await adapter.execute(
                taskPackage: taskPackage,
                rawAIResult: placeholder
            )
            XCTFail("Placeholder 不应被视为成功产物")
        } catch let error as ZhuowangHTMLPrototypeAdapterError {
            guard case .placeholderContent = error else {
                XCTFail("应返回 placeholderContent，实际为 \(error)")
                return
            }
        }
    }


    func testV2AppendsAndSwitchingCurrentPreservesV1() {
        let campaignID = UUID()
        let logicalKey = "workflow.prototypeDesign.primary"
        let v1 = ZhuowangArtifact(
            campaignID: campaignID,
            name: "产品原型设计",
            type: .html,
            logicalKey: logicalKey,
            version: 1,
            isApprovedVersion: true
        )

        XCTAssertEqual(
            ZhuowangWorkflowTransitionLogic.nextArtifactVersion(
                artifacts: [v1],
                logicalKey: logicalKey
            ),
            2
        )

        let v2 = ZhuowangArtifact(
            campaignID: campaignID,
            name: "重新命名也属于同一原型",
            type: .html,
            logicalKey: logicalKey,
            version: 2,
            isApprovedVersion: true
        )

        let selectedV1 =
            ZhuowangWorkflowTransitionLogic.selectingCurrentVersion(
                artifacts: [v1, v2],
                artifactID: v1.id
            )

        XCTAssertEqual(selectedV1.count, 2)
        XCTAssertTrue(
            selectedV1.first(where: { $0.id == v1.id })?
                .isApprovedVersion == true
        )
        XCTAssertTrue(
            selectedV1.first(where: { $0.id == v2.id })?
                .isApprovedVersion == false
        )
    }


    func testHTMLDisasterRecoveryScansHistoricalPrototypeFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let manager = ZhuowangWorkspaceFileManager(rootURL: root)
        let campaignURL = manager.campaignDirectoryURL(
            provinceName: "浙江",
            campaignName: "测试活动"
        )
        let historicalFolder = campaignURL.appendingPathComponent(
            "05_Figma原型",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: historicalFolder,
            withIntermediateDirectories: true
        )

        let htmlURL = historicalFolder.appendingPathComponent(
            "产品原型设计_V1.html"
        )
        try "<html><head></head><body>V1</body></html>".write(
            to: htmlURL,
            atomically: true,
            encoding: .utf8
        )

        let discovered = manager.discoverLocalArtifacts(
            provinceName: "浙江",
            campaignName: "测试活动"
        )

        XCTAssertEqual(discovered.count, 1)
        XCTAssertEqual(discovered.first?.type, .html)
        XCTAssertEqual(discovered.first?.version, 1)
    }


    func testStep05OnlyUnlocksStep06AfterApprovalTransition() {
        let campaignID = UUID()
        let workflow = ZhuowangCampaignWorkflow.standard(
            campaignID: campaignID
        )
        guard
            let step05 = workflow.steps.first(
                where: { $0.kind == .prototype }
            ),
            let step06 = workflow.steps.first(
                where: { $0.kind == .customerService }
            )
        else {
            XCTFail("标准 Workflow 缺少 Step 05 / Step 06")
            return
        }

        XCTAssertNotEqual(step05.status, .approved)
        XCTAssertEqual(step06.status, .notStarted)

        let approved =
            ZhuowangWorkflowTransitionLogic
                .approvingStepAndUnlockingNext(
                    workflow: workflow,
                    stepID: step05.id
                )

        XCTAssertEqual(
            approved.steps.first(where: { $0.id == step05.id })?.status,
            .approved
        )
        XCTAssertEqual(
            approved.steps.first(where: { $0.id == step06.id })?.status,
            .ready
        )
    }
}
