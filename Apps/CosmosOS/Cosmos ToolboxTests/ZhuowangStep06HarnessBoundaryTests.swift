import Foundation
import XCTest
@testable import Cosmos_Toolbox


@MainActor
final class ZhuowangStep06HarnessBoundaryTests:
    ZhuowangStorePersistenceTestCase {

    func testInitialGenerationAndRegenerationCannotWriteProtectedRoots()
        async throws {
        let fixture = try makeFixture(scriptBody: """
        if /usr/bin/touch "\(workspaceProbePath)"; then printf 'WORKSPACE_ALLOWED\\n'; else printf 'WORKSPACE_BLOCKED\\n'; fi
        if /usr/bin/touch "\(knowledgeProbePath)"; then printf 'KNOWLEDGE_ALLOWED\\n'; else printf 'KNOWLEDGE_BLOCKED\\n'; fi
        if /usr/bin/git --version; then printf 'GIT_ALLOWED\\n'; else printf 'GIT_BLOCKED\\n'; fi
        printf '# 客服 FAQ\\n正文\\n'
        """)
        let suite = try makeSuite(label: "Step06Harness")
        let campaign = ZhuowangCampaign(
            name: "Boundary Fixture",
            scopeType: .other,
            startDate: Date(timeIntervalSince1970: 100),
            endDate: Date(timeIntervalSince1970: 200)
        )
        let workflowBytes = try JSONEncoder().encode([
            ZhuowangCampaignWorkflow.standard(campaignID: campaign.id)
        ])
        suite.defaults.set(
            workflowBytes,
            forKey: ZhuowangWorkflowStore.workflowStorageKey
        )
        let store = ZhuowangWorkflowStore(
            persistenceConfiguration: suite.configuration,
            workspaceFileManager: ZhuowangWorkspaceFileManager(
                rootURL: fixture.workspaceProbe.deletingLastPathComponent()
            )
        )
        let before = suite.defaults.data(
            forKey: ZhuowangWorkflowStore.workflowStorageKey
        )

        var package = makePackage()
        let first = try await fixture.adapter.execute(taskPackage: package)
        XCTAssertTrue(first.output.contains("WORKSPACE_BLOCKED"))
        XCTAssertTrue(first.output.contains("KNOWLEDGE_BLOCKED"))
        XCTAssertTrue(first.output.contains("GIT_BLOCKED"))
        XCTAssertFalse(first.output.contains("_ALLOWED"))
        XCTAssertTrue(first.output.contains("# 客服 FAQ\n正文"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.workspaceProbe.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.knowledgeProbe.path))

        package.instruction = "根据修改意见重新生成 FAQ"
        let second = try await fixture.adapter.execute(taskPackage: package)
        XCTAssertEqual(second.output, first.output)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.workspaceProbe.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.knowledgeProbe.path))
        XCTAssertEqual(
            suite.defaults.data(forKey: ZhuowangWorkflowStore.workflowStorageKey),
            before
        )
        XCTAssertEqual(store.workflow(forCampaignID: campaign.id)?.artifacts.count, 0)
        XCTAssertEqual(store.workflow(forCampaignID: campaign.id)?.aiRuns.count, 0)
        XCTAssertEqual(store.workflow(forCampaignID: campaign.id)?.approvals.count, 0)
    }

    func testSandboxAllowsEachRequiredWritableTarget() async throws {
        let fixture = try makeFixture(scriptBody: """
        set -eu
        /usr/bin/touch "$HOME/home-probe"
        /usr/bin/touch "$TMPDIR/tmp-probe"
        /usr/bin/touch ./cwd-probe
        /usr/bin/touch "$PWD/pwd-probe"
        /usr/bin/touch "$npm_config_cache/npm-probe"
        /usr/bin/touch "$DSH_HOME/dsh-probe"
        printf 'null-probe' > /dev/null
        printf 'ALL_WRITES_REACHED\\n# 客服 FAQ\\n正文\\n'
        """)

        let result = try await fixture.adapter.execute(taskPackage: makePackage())
        XCTAssertTrue(result.output.contains("ALL_WRITES_REACHED"))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: fixture.harnessHome.appendingPathComponent("dsh-probe").path
        ))
    }

    func testStep01To04RevisionPreservesRawRequest() async throws {
        let fixture = try makeFixture(scriptBody: """
        printf '%s' "$3"
        """)
        let revisionTask = "原始修订请求：只输出这一段，不增加上下文。"
        for kind in [ZhuowangWorkflowStepKind.brief, .idea, .plan, .pageStructure] {
            var package = makePackage()
            package.workflowStepKind = kind
            package.destinationHint = "SHOULD_NOT_BE_APPENDED"
            let result = try await fixture.adapter.executeRevision(
                taskPackage: package,
                revisionTask: revisionTask
            )
            XCTAssertEqual(result.output, revisionTask, "Unexpected revision route: \(kind)")
        }
    }

    func testStep06RevisionStillUsesSandboxedTaskPackage() async throws {
        let fixture = try makeFixture(scriptBody: """
        if /usr/bin/touch "\(workspaceProbePath)"; then printf 'WORKSPACE_ALLOWED\\n'; else printf 'WORKSPACE_BLOCKED\\n'; fi
        printf '%s' "$3"
        """)
        let result = try await fixture.adapter.executeRevision(
            taskPackage: makePackage(),
            revisionTask: "Step06 修订正文"
        )
        XCTAssertTrue(result.output.contains("WORKSPACE_BLOCKED"))
        XCTAssertTrue(result.output.contains("Step06 修订正文"))
        XCTAssertTrue(result.output.contains("stdout 只包含完整 Markdown 正文"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.workspaceProbe.path))
    }

    func testUnexpectedProtectedFileChangeRejectsDraft()
        async throws {
        let fixture = try makeFixture(scriptBody: """
        /bin/sleep 1
        printf '# 客服 FAQ\\n'
        """)
        let path = fixture.workspaceProbe
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            try? Data("external change".utf8).write(to: path)
        }

        do {
            _ = try await fixture.adapter.execute(taskPackage: makePackage())
            XCTFail("Changed formal root must not yield a reviewable result")
        } catch let error as ZhuowangStep06HarnessBoundaryError {
            guard case .formalFilesChanged = error else {
                return XCTFail("Unexpected boundary failure: \(error)")
            }
        }
    }

    func testStep06PromptHidesDestinationAndPreviousAbsolutePath()
        throws {
        let campaign = ZhuowangCampaign(
            name: "Prompt Fixture",
            scopeType: .other,
            startDate: Date(timeIntervalSince1970: 100),
            endDate: Date(timeIntervalSince1970: 200)
        )
        var workflow = ZhuowangCampaignWorkflow.standard(campaignID: campaign.id)
        let prototypeIndex = try XCTUnwrap(workflow.steps.firstIndex {
            $0.kind == .prototype
        })
        let customerStep = try XCTUnwrap(workflow.steps.first {
            $0.kind == .customerService
        })
        workflow.steps[prototypeIndex].status = .approved
        workflow.artifacts.append(ZhuowangArtifact(
            campaignID: campaign.id,
            stepID: workflow.steps[prototypeIndex].id,
            name: "产品原型设计",
            type: .html,
            logicalKey: "workflow.prototypeDesign.primary",
            location: "/Users/example/Documents/Cosmos OS/secret-prototype.html",
            content: "APPROVED V3 CONTENT",
            version: 3,
            isApprovedVersion: true
        ))
        let package = ZhuowangTaskPackageBuilder.build(
            campaign: campaign,
            province: nil,
            module: nil,
            workflow: workflow,
            step: customerStep,
            provider: nil
        )
        let executionText = DeepSeekHarnessAdapter.buildExecutionText(from: package)
        XCTAssertTrue(executionText.contains("APPROVED V3 CONTENT"))
        XCTAssertFalse(executionText.contains("secret-prototype.html"))
        XCTAssertFalse(executionText.contains(package.destinationHint))
        XCTAssertFalse(executionText.contains("【建议保存位置】"))
        XCTAssertTrue(executionText.contains("stdout 只包含完整 Markdown 正文"))
    }

    private struct Fixture {
        let adapter: DeepSeekHarnessAdapter
        let harnessHome: URL
        let workspaceProbe: URL
        let knowledgeProbe: URL
    }

    private var workspaceProbePath: String { "PLACEHOLDER_WORKSPACE" }
    private var knowledgeProbePath: String { "PLACEHOLDER_KNOWLEDGE" }

    private func makeFixture(scriptBody: String) throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Cosmos-Step06-Boundary-Test-\(UUID())", isDirectory: true)
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        let knowledge = root.appendingPathComponent("knowledge", isDirectory: true)
        let harnessHome = root.appendingPathComponent("harness-home", isDirectory: true)
        let script = root.appendingPathComponent("fake-dsh.sh")
        for directory in [root, workspace, knowledge, harnessHome] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let workspaceProbe = workspace.appendingPathComponent("probe.md")
        let knowledgeProbe = knowledge.appendingPathComponent("probe.md")
        let body = scriptBody
            .replacingOccurrences(of: workspaceProbePath, with: workspaceProbe.path)
            .replacingOccurrences(of: knowledgeProbePath, with: knowledgeProbe.path)
        try ("#!/bin/sh\n" + body + "\n").write(
            to: script,
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: script.path
        )
        let runtime = DeepSeekHarnessRuntime(
            executableURL: script,
            version: "fixture",
            dshHomePath: harnessHome.path,
            supportsHeadless: true,
            source: "fixture"
        )
        return Fixture(
            adapter: DeepSeekHarnessAdapter(
                runtime: runtime,
                step06Boundary: ZhuowangStep06HarnessBoundary(
                    protectedRoots: [workspace, knowledge]
                )
            ),
            harnessHome: harnessHome,
            workspaceProbe: workspaceProbe,
            knowledgeProbe: knowledgeProbe
        )
    }

    private func makePackage() -> ZhuowangAITaskPackage {
        ZhuowangAITaskPackage(
            campaignID: UUID(),
            workflowStepID: UUID(),
            workflowStepKind: .customerService,
            title: "Step 06 客服文档",
            instruction: "生成 FAQ Markdown",
            destinationHint: "formal/06_客服文档"
        )
    }
}
