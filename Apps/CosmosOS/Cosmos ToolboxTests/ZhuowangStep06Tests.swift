import XCTest
@testable import Cosmos_Toolbox


@MainActor
final class ZhuowangStep06Tests:
    ZhuowangStorePersistenceTestCase {

    func testTaskPackageUsesOnlyCurrentAdoptedUpstreamArtifacts()
        throws {
        let campaign = makeCampaign()
        var workflow = makeReadyWorkflow(
            campaignID: campaign.id
        )
        let prototypeStep = try XCTUnwrap(
            workflow.steps.first {
                $0.kind == .prototype
            }
        )
        let customerServiceStep = try XCTUnwrap(
            workflow.steps.first {
                $0.kind == .customerService
            }
        )

        workflow.artifacts.append(contentsOf: [
            makePrototypeArtifact(
                campaignID: campaign.id,
                stepID: prototypeStep.id,
                version: 1,
                content: "PROTOTYPE_V1",
                isCurrent: false
            ),
            makePrototypeArtifact(
                campaignID: campaign.id,
                stepID: prototypeStep.id,
                version: 3,
                content: "PROTOTYPE_V3_ADOPTED",
                isCurrent: true
            ),
            makePrototypeArtifact(
                campaignID: campaign.id,
                stepID: prototypeStep.id,
                version: 4,
                content: "PROTOTYPE_V4",
                isCurrent: false
            )
        ])

        let package = ZhuowangTaskPackageBuilder.build(
            campaign: campaign,
            province: nil,
            module: nil,
            workflow: workflow,
            step: customerServiceStep,
            provider: makeDeepSeekProvider()
        )

        XCTAssertEqual(
            package.workflowStepKind,
            .customerService
        )
        XCTAssertTrue(
            package.instruction.contains(
                "PROTOTYPE_V3_ADOPTED"
            )
        )
        XCTAssertFalse(
            package.instruction.contains("PROTOTYPE_V1")
        )
        XCTAssertFalse(
            package.instruction.contains("PROTOTYPE_V4")
        )
        XCTAssertTrue(
            package.contextReferences.contains {
                $0.contains("V3")
            }
        )
        XCTAssertFalse(
            package.contextReferences.contains {
                $0.contains("V1") || $0.contains("V4")
            }
        )
    }


    func testDeepSeekResultCreatesReviewableMarkdownDraft()
        throws {
        let stepID = UUID()
        let package = ZhuowangAITaskPackage(
            campaignID: UUID(),
            workflowStepID: stepID,
            workflowStepKind: .customerService,
            title: "客服文档",
            instruction: "生成 FAQ"
        )
        let source =
            "# FAQ\n\n<script>alert('raw')</script>\n"
        let draft = ZhuowangCustomerServiceArtifact
            .makeDraft(
                taskPackage: package,
                outputText: source
            )

        XCTAssertEqual(
            draft?.logicalKey,
            ZhuowangCustomerServiceArtifact.logicalKey
        )
        XCTAssertEqual(draft?.type, .markdown)
        XCTAssertEqual(draft?.content, source)

        let document = try XCTUnwrap(
            draft.map {
                ArtifactReviewDocument(
                    id: package.id,
                    draft: $0,
                    snapshot: nil,
                    providerName: "DeepSeek Harness"
                )
            }
        )

        XCTAssertEqual(
            ArtifactPreviewRendererRegistry()
                .rendererIdentifier(
                    for: document.previewInput
                ),
            .text
        )
        XCTAssertEqual(document.content, source)
    }


    func testProviderChoiceBeforeAdoptionDoesNotPersistWorkflow()
        throws {
        let fixture = try makeStoreFixture()
        let step = try customerServiceStep(in: fixture.workflow)
        let before = fixture.dataSource.data(
            forKey: ZhuowangWorkflowStore.workflowStorageKey
        )
        var session = ZhuowangStep06ProviderSession()
        let provider = makeDeepSeekProvider()

        session.select(provider.id, for: step.id)
        XCTAssertEqual(session.providerID(for: step), provider.id)
        session.select(nil, for: step.id)
        XCTAssertNil(session.providerID(for: step))
        XCTAssertEqual(
            fixture.dataSource.data(
                forKey: ZhuowangWorkflowStore.workflowStorageKey
            ),
            before
        )
        XCTAssertEqual(
            fixture.dataSource.writeCount(
                forKey: ZhuowangWorkflowStore.workflowStorageKey
            ),
            0
        )
        XCTAssertEqual(
            try customerServiceStep(in: XCTUnwrap(
                fixture.store.workflow(forCampaignID: fixture.campaign.id)
            )).updatedAt,
            step.updatedAt
        )
    }


    func testAdoptionPersistsCompleteProvenanceAndSurvivesRestart()
        throws {
        let fixture = try makeStoreFixture()
        let provider = makeDeepSeekProvider()
        let step = try customerServiceStep(
            in: fixture.workflow
        )

        let result = fixture.store
            .adoptCustomerServiceResult(
                workflowID: fixture.workflow.id,
                campaignID: fixture.campaign.id,
                campaignName: fixture.campaign.name,
                provinceName: nil,
                stepID: step.id,
                provider: provider,
                connectionID:
                    ZhuowangBuiltInIntegrationIDs
                        .deepSeekConnection,
                adapterIdentifier: "deepseek-harness",
                inputText: "INPUT",
                outputText: "# 客服 FAQ\n正式口径"
            )

        guard case .succeeded(
            let artifactID,
            let version,
            let reusedExisting
        ) = result else {
            return XCTFail("Expected successful adoption: \(result)")
        }

        XCTAssertEqual(version, 1)
        XCTAssertFalse(reusedExisting)

        let stored = try XCTUnwrap(
            fixture.store.workflow(
                forCampaignID: fixture.campaign.id
            )
        )
        let storedStep = try customerServiceStep(in: stored)
        let artifact = try XCTUnwrap(
            stored.artifacts.first {
                $0.id == artifactID
            }
        )
        let run = try XCTUnwrap(
            stored.aiRuns.first {
                $0.id == artifact.runID
            }
        )
        let approval = try XCTUnwrap(
            stored.approvals.first {
                $0.runID == run.id
            }
        )

        XCTAssertEqual(storedStep.status, .approved)
        XCTAssertEqual(storedStep.selectedProviderID, provider.id)
        XCTAssertEqual(run.status, .succeeded)
        XCTAssertEqual(run.providerID, provider.id)
        XCTAssertEqual(
            run.connectionID,
            ZhuowangBuiltInIntegrationIDs
                .deepSeekConnection
        )
        XCTAssertEqual(
            run.adapterIdentifier,
            "deepseek-harness"
        )
        XCTAssertEqual(approval.decision, .approved)
        XCTAssertEqual(
            artifact.logicalKey,
            ZhuowangCustomerServiceArtifact.logicalKey
        )
        XCTAssertEqual(artifact.providerID, provider.id)
        XCTAssertTrue(artifact.isApprovedVersion)
        XCTAssertEqual(
            URL(fileURLWithPath: artifact.location).lastPathComponent,
            "客服文档_V1.md"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: artifact.location
            )
        )

        let restarted = ZhuowangWorkflowStore(
            persistenceConfiguration: fixture.configuration,
            workspaceFileManager: fixture.fileManager
        )
        let restartedWorkflow = try XCTUnwrap(
            restarted.workflow(
                forCampaignID: fixture.campaign.id
            )
        )

        XCTAssertEqual(
            try customerServiceStep(
                in: restartedWorkflow
            ).status,
            .approved
        )
        XCTAssertEqual(
            restartedWorkflow.artifacts.first {
                $0.id == artifactID
            }?.isApprovedVersion,
            true
        )
    }


    func testNewVersionPreservesHistoryAndDuplicateAdoptionIsIdempotent()
        throws {
        let fixture = try makeStoreFixture()
        let provider = makeDeepSeekProvider()
        let step = try customerServiceStep(
            in: fixture.workflow
        )

        let first = adopt(
            output: "V1",
            fixture: fixture,
            stepID: step.id,
            provider: provider
        )
        XCTAssertTrue(first.succeeded)

        let duplicate = adopt(
            output: "V1",
            fixture: fixture,
            stepID: step.id,
            provider: provider
        )

        guard case .succeeded(
            _, _, let reusedExisting
        ) = duplicate else {
            return XCTFail("Expected idempotent success")
        }
        XCTAssertTrue(reusedExisting)

        let second = adopt(
            output: "V2",
            fixture: fixture,
            stepID: step.id,
            provider: provider
        )
        XCTAssertTrue(second.succeeded)

        let workflow = try XCTUnwrap(
            fixture.store.workflow(
                forCampaignID: fixture.campaign.id
            )
        )
        let artifacts = workflow.artifacts.filter {
            $0.versionGroupKey
                == ZhuowangCustomerServiceArtifact.logicalKey
        }

        XCTAssertEqual(artifacts.count, 2)
        XCTAssertEqual(workflow.aiRuns.count, 2)
        XCTAssertEqual(workflow.approvals.count, 2)
        XCTAssertEqual(
            artifacts.filter(\.isApprovedVersion).count,
            1
        )
        XCTAssertEqual(
            artifacts.first(
                where: { $0.isApprovedVersion }
            )?.version,
            2
        )
        XCTAssertEqual(
            Set(artifacts.map(\.version)),
            Set([1, 2])
        )
        XCTAssertTrue(
            artifacts.allSatisfy {
                FileManager.default.fileExists(
                    atPath: $0.location
                )
            }
        )
    }


    func testFileWriteFailureLeavesMemoryAndPersistenceUnchanged()
        throws {
        let fixture = try makeStoreFixture(
            blockedWorkspaceRoot: true
        )
        let provider = makeDeepSeekProvider()
        let step = try customerServiceStep(
            in: fixture.workflow
        )
        let originalData = fixture.dataSource.storage[
            ZhuowangWorkflowStore.workflowStorageKey
        ]
        let originalWorkflow = fixture.store.workflows

        let result = adopt(
            output: "WRITE FAILURE",
            fixture: fixture,
            stepID: step.id,
            provider: provider
        )

        guard case .rejected(.fileWriteFailed(_)) = result else {
            return XCTFail("Expected file write failure: \(result)")
        }
        XCTAssertEqual(fixture.store.workflows, originalWorkflow)
        XCTAssertEqual(
            fixture.dataSource.storage[
                ZhuowangWorkflowStore.workflowStorageKey
            ],
            originalData
        )
    }


    func testBackupVerificationFailureKeepsMemoryAndPrimaryUnchanged()
        throws {
        let fixture = try makeStoreFixture()
        let provider = makeDeepSeekProvider()
        let step = try customerServiceStep(
            in: fixture.workflow
        )
        let originalData = fixture.dataSource.storage[
            ZhuowangWorkflowStore.workflowStorageKey
        ]
        let originalWorkflow = fixture.store.workflows

        fixture.dataSource.corruptWritesForKeys = [
            ZhuowangWorkflowStore.workflowBackupStorageKey
        ]

        let result = adopt(
            output: "ORPHAN",
            fixture: fixture,
            stepID: step.id,
            provider: provider
        )

        XCTAssertEqual(
            result,
            .rejected(.writeVerificationFailed)
        )
        XCTAssertEqual(fixture.store.workflows, originalWorkflow)
        XCTAssertEqual(
            fixture.dataSource.storage[
                ZhuowangWorkflowStore.workflowStorageKey
            ],
            originalData
        )

        let files = try customerServiceFiles(
            fixture: fixture
        )
        XCTAssertEqual(files.count, 1)
    }


    func testPrimaryReadBackFailureKeepsMemoryUnpublishedAndRetainsFile()
        throws {
        let fixture = try makeStoreFixture()
        let provider = makeDeepSeekProvider()
        let step = try customerServiceStep(
            in: fixture.workflow
        )
        let originalWorkflow = fixture.store.workflows

        fixture.dataSource.corruptWritesForKeys = [
            ZhuowangWorkflowStore.workflowStorageKey
        ]

        let result = adopt(
            output: "PRIMARY READ BACK FAILURE",
            fixture: fixture,
            stepID: step.id,
            provider: provider
        )

        XCTAssertEqual(
            result,
            .rejected(.writeVerificationFailed)
        )
        XCTAssertEqual(fixture.store.workflows, originalWorkflow)
        XCTAssertEqual(
            fixture.store.workflowPersistenceState,
            .writeVerificationFailed
        )
        XCTAssertEqual(
            fixture.dataSource.storage[
                ZhuowangWorkflowStore.workflowStorageKey
            ],
            Data("corrupt-write".utf8)
        )
        XCTAssertEqual(
            try customerServiceFiles(
                fixture: fixture
            ).count,
            1
        )
    }


    func testStaleBaselineRejectsBeforeWritingFile()
        throws {
        let fixture = try makeStoreFixture()
        let secondStore = ZhuowangWorkflowStore(
            persistenceConfiguration: fixture.configuration,
            workspaceFileManager: fixture.fileManager
        )
        let provider = makeDeepSeekProvider()
        let step = try customerServiceStep(
            in: fixture.workflow
        )

        XCTAssertTrue(
            adopt(
                output: "FIRST",
                fixture: fixture,
                stepID: step.id,
                provider: provider
            ).succeeded
        )

        let staleResult = secondStore
            .adoptCustomerServiceResult(
                workflowID: fixture.workflow.id,
                campaignID: fixture.campaign.id,
                campaignName: fixture.campaign.name,
                provinceName: nil,
                stepID: step.id,
                provider: provider,
                connectionID:
                    ZhuowangBuiltInIntegrationIDs
                        .deepSeekConnection,
                adapterIdentifier: "deepseek-harness",
                inputText: "INPUT",
                outputText: "STALE"
            )

        XCTAssertEqual(
            staleResult,
            .rejected(.staleConflict)
        )
        XCTAssertEqual(
            try customerServiceFiles(
                fixture: fixture
            ).count,
            1
        )
        XCTAssertEqual(
            try customerServiceStep(
                in: secondStore.workflows[0]
            ).status,
            .ready
        )
    }


    func testCorruptPrimaryWithBackupRejectsWithoutWritingFile()
        throws {
        let campaign = makeCampaign()
        let workflow = makeReadyWorkflow(
            campaignID: campaign.id
        )
        let validData = try JSONEncoder().encode([workflow])
        let dataSource = ZhuowangInMemoryPersistenceDataSource(
            storage: [
                ZhuowangWorkflowStore.workflowStorageKey:
                    Data("corrupt".utf8),
                ZhuowangWorkflowStore.workflowBackupStorageKey:
                    validData
            ]
        )
        let configuration = isolatedConfiguration(
            dataSource: dataSource
        )
        let root = temporaryRoot()
        let fileManager = ZhuowangWorkspaceFileManager(
            rootURL: root
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let store = ZhuowangWorkflowStore(
            persistenceConfiguration: configuration,
            workspaceFileManager: fileManager
        )
        let step = try customerServiceStep(in: workflow)

        let result = store.adoptCustomerServiceResult(
            workflowID: workflow.id,
            campaignID: campaign.id,
            campaignName: campaign.name,
            provinceName: nil,
            stepID: step.id,
            provider: makeDeepSeekProvider(),
            connectionID:
                ZhuowangBuiltInIntegrationIDs.deepSeekConnection,
            adapterIdentifier: "deepseek-harness",
            inputText: "INPUT",
            outputText: "LOCKED"
        )

        XCTAssertEqual(
            result,
            .rejected(
                .lockedCorruptPrimary(
                    hasValidBackup: true
                )
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: root.path)
        )
    }


    func testRecoveryImportsCustomerServiceFileWithoutApprovalOrAdoption()
        throws {
        let fixture = try makeStoreFixture()
        let step = try customerServiceStep(
            in: fixture.workflow
        )

        _ = try fixture.fileManager.writeMarkdownArtifact(
            provinceName: nil,
            campaignName: fixture.campaign.name,
            stepKind: .customerService,
            artifactName:
                ZhuowangCustomerServiceArtifact.name,
            version: 1,
            content: "RECOVERED"
        )

        let summary = fixture.store
            .recoverWorkflowFromLocalFiles(
                campaign: fixture.campaign,
                provinceName: nil
            )
        let workflow = try XCTUnwrap(
            fixture.store.workflow(
                forCampaignID: fixture.campaign.id
            )
        )
        let recovered = workflow.artifacts.filter {
            $0.stepID == step.id
        }

        XCTAssertEqual(summary.importedArtifacts, 1)
        XCTAssertEqual(
            try customerServiceStep(in: workflow).status,
            .ready
        )
        XCTAssertEqual(recovered.count, 1)
        XCTAssertEqual(
            recovered.first?.logicalKey,
            ZhuowangCustomerServiceArtifact.logicalKey
        )
        XCTAssertEqual(
            recovered.first?.isApprovedVersion,
            false
        )
        XCTAssertTrue(workflow.approvals.isEmpty)
    }


    func testRecoveryIgnoresNonFormalCustomerServiceFileNames()
        throws {
        let fixture = try makeStoreFixture()
        let directory = fixture.fileManager
            .customerServiceDirectoryURL(
                provinceName: nil,
                campaignName: fixture.campaign.name
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        for name in [
            "客服文档 _ AI 采用结果_V1.md",
            "其他客服文件_V2.md",
            "客服文档_V3.txt"
        ] {
            try "UNADOPTED".write(
                to: directory.appendingPathComponent(name),
                atomically: true,
                encoding: .utf8
            )
        }

        let before = fixture.dataSource.data(
            forKey: ZhuowangWorkflowStore.workflowStorageKey
        )
        let summary = fixture.store.recoverWorkflowFromLocalFiles(
            campaign: fixture.campaign,
            provinceName: nil
        )
        XCTAssertEqual(summary.importedArtifacts, 0)
        XCTAssertEqual(
            fixture.dataSource.data(
                forKey: ZhuowangWorkflowStore.workflowStorageKey
            ),
            before
        )
        XCTAssertEqual(
            fixture.dataSource.writeCount(
                forKey: ZhuowangWorkflowStore.workflowStorageKey
            ),
            0
        )
        XCTAssertFalse(
            ZhuowangWorkspaceFileManager
                .isFormalCustomerServiceFileName(
                    "客服文档 _ AI 采用结果_V1.md"
                )
        )
        XCTAssertTrue(
            ZhuowangWorkspaceFileManager
                .isFormalCustomerServiceFileName("客服文档_V1.md")
        )
    }


    // MARK: - Helpers

    private struct StoreFixture {
        let campaign: ZhuowangCampaign
        let workflow: ZhuowangCampaignWorkflow
        let dataSource: ZhuowangInMemoryPersistenceDataSource
        let configuration: ZhuowangStorePersistenceConfiguration
        let fileManager: ZhuowangWorkspaceFileManager
        let store: ZhuowangWorkflowStore
    }

    private func makeStoreFixture(
        blockedWorkspaceRoot: Bool = false
    ) throws -> StoreFixture {
        let campaign = makeCampaign()
        let workflow = makeReadyWorkflow(
            campaignID: campaign.id
        )
        let workflowData = try JSONEncoder().encode([workflow])
        let dataSource = ZhuowangInMemoryPersistenceDataSource(
            storage: [
                ZhuowangWorkflowStore.workflowStorageKey:
                    workflowData
            ]
        )
        let configuration = isolatedConfiguration(
            dataSource: dataSource
        )
        let root = temporaryRoot()

        if blockedWorkspaceRoot {
            try Data("blocking-file".utf8).write(to: root)
        }

        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }

        let fileManager = ZhuowangWorkspaceFileManager(
            rootURL: root
        )
        let store = ZhuowangWorkflowStore(
            persistenceConfiguration: configuration,
            workspaceFileManager: fileManager
        )

        dataSource.resetWriteLog()

        return StoreFixture(
            campaign: campaign,
            workflow: workflow,
            dataSource: dataSource,
            configuration: configuration,
            fileManager: fileManager,
            store: store
        )
    }

    private func adopt(
        output: String,
        fixture: StoreFixture,
        stepID: UUID,
        provider: ZhuowangAIProvider
    ) -> ZhuowangCustomerServiceAdoptionResult {
        fixture.store.adoptCustomerServiceResult(
            workflowID: fixture.workflow.id,
            campaignID: fixture.campaign.id,
            campaignName: fixture.campaign.name,
            provinceName: nil,
            stepID: stepID,
            provider: provider,
            connectionID:
                ZhuowangBuiltInIntegrationIDs
                    .deepSeekConnection,
            adapterIdentifier: "deepseek-harness",
            inputText: "INPUT",
            outputText: output
        )
    }

    private func customerServiceFiles(
        fixture: StoreFixture
    ) throws -> [URL] {
        let directory = fixture.fileManager
            .customerServiceDirectoryURL(
                provinceName: nil,
                campaignName: fixture.campaign.name
            )

        return try FileManager.default
            .contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "md" }
    }

    private func customerServiceStep(
        in workflow: ZhuowangCampaignWorkflow
    ) throws -> ZhuowangWorkflowStep {
        try XCTUnwrap(
            workflow.steps.first {
                $0.kind == .customerService
            }
        )
    }

    private func makeReadyWorkflow(
        campaignID: UUID
    ) -> ZhuowangCampaignWorkflow {
        var workflow = ZhuowangCampaignWorkflow.standard(
            campaignID: campaignID
        )

        for index in workflow.steps.indices {
            workflow.steps[index].status =
                workflow.steps[index].kind == .customerService
                ? .ready
                : .approved
        }

        return workflow
    }

    private func makeCampaign() -> ZhuowangCampaign {
        ZhuowangCampaign(
            name: "Step 06 Test Campaign",
            scopeType: .other,
            startDate: Date(timeIntervalSince1970: 100),
            endDate: Date(timeIntervalSince1970: 200)
        )
    }

    private func makeDeepSeekProvider()
        -> ZhuowangAIProvider {
        ZhuowangAIProvider(
            id: UUID(
                uuidString:
                    "20000000-0000-0000-0000-000000000003"
            )!,
            name: "DeepSeek Harness",
            kind: .deepSeekHarness,
            modelName: "deepseek-chat"
        )
    }

    private func makePrototypeArtifact(
        campaignID: UUID,
        stepID: UUID,
        version: Int,
        content: String,
        isCurrent: Bool
    ) -> ZhuowangArtifact {
        ZhuowangArtifact(
            campaignID: campaignID,
            stepID: stepID,
            name: "产品原型设计",
            type: .html,
            logicalKey: "workflow.prototypeDesign.primary",
            content: content,
            version: version,
            isApprovedVersion: isCurrent
        )
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "Cosmos-Step06-\(UUID().uuidString)",
                isDirectory: true
            )
    }
}
