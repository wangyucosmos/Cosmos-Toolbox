import XCTest
@testable import Cosmos_Toolbox

final class ZhuowangStep05Tests: XCTestCase {

    func testDeepSeekRuntimeDiscoveryReadsVersionAndHeadlessCapability() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let executableURL = root.appendingPathComponent("dsh")
        let executable = """
        #!/bin/sh
        if [ "$1" = "--version" ]; then
          echo "test-runtime-version"
          exit 0
        fi
        if [ "$1" = "--help" ]; then
          echo 'dsh --profile headless "task"'
          exit 0
        fi
        exit 1
        """
        try executable.write(
            to: executableURL,
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )

        let compatibility = DeepSeekHarnessRuntimeCompatibility(
            environment: [
                "HOME": root.path,
                "COSMOS_DSH_EXECUTABLE": executableURL.path,
                "PATH": ""
            ]
        )

        let runtime = compatibility.discover()

        XCTAssertEqual(runtime.executableURL?.path, executableURL.path)
        XCTAssertEqual(runtime.version, "test-runtime-version")
        XCTAssertTrue(runtime.supportsHeadless)
        XCTAssertTrue(runtime.isDiscoveredRuntime)
    }


    func testDeepSeekRuntimeDiscoversDSHHomeFromLaunchAgent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        let launchAgents = root
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        try FileManager.default.createDirectory(
            at: launchAgents,
            withIntermediateDirectories: true
        )
        let expectedHome = root.appendingPathComponent("harness-home").path
        let plist: [String: Any] = [
            "EnvironmentVariables": ["DSH_HOME": expectedHome]
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(
            to: launchAgents.appendingPathComponent(
                "ai.deepseek.harness.server.plist"
            )
        )

        let compatibility = DeepSeekHarnessRuntimeCompatibility(
            environment: ["HOME": root.path, "PATH": ""]
        )

        XCTAssertEqual(compatibility.discoverDSHHome(), expectedHome)
    }

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
        let profile = ZhuowangPrototypeExecutionProfile(
            fidelity: .low,
            style: .grayscaleWireframe
        )
        let snapshot = ZhuowangWorkflowExecutionSnapshot(
            workflowID: UUID(),
            workflowStepID: UUID(),
            providerID: UUID(),
            connectionID: UUID(),
            toolIntegrationID: UUID(),
            routeID: UUID(),
            capability: .prototypeDesign,
            adapterIdentifier: "deepseek-harness-html-prototype",
            prototypeExecutionProfile: profile
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(
            ZhuowangWorkflowExecutionSnapshot.self,
            from: data
        )

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.prototypeExecutionProfile, profile)
    }


    func testLegacyWorkflowWithoutPrototypeProfileDecodes() throws {
        let workflow = ZhuowangCampaignWorkflow.standard(
            campaignID: UUID()
        )
        let encoded = try JSONEncoder().encode(workflow)
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any]
        )
        var steps = try XCTUnwrap(payload["steps"] as? [[String: Any]])
        for index in steps.indices {
            steps[index].removeValue(forKey: "prototypeExecutionProfile")
        }
        payload["steps"] = steps
        let legacyData = try JSONSerialization.data(withJSONObject: payload)

        let decoded = try JSONDecoder().decode(
            ZhuowangCampaignWorkflow.self,
            from: legacyData
        )
        let prototypeStep = try XCTUnwrap(
            decoded.steps.first(
                where: { $0.requiredCapabilities.contains(.prototypeDesign) }
            )
        )

        XCTAssertEqual(
            prototypeStep.prototypeExecutionProfile,
            .default
        )
    }


    func testPrototypeProfileDefaultsToHighFidelityMarketingPage() {
        let step = ZhuowangWorkflowStep(
            title: "产品原型设计",
            sortOrder: 50,
            requiredCapabilities: [.prototypeDesign]
        )

        XCTAssertEqual(step.prototypeExecutionProfile.fidelity, .high)
        XCTAssertEqual(
            step.prototypeExecutionProfile.style,
            .highFidelityMarketingPage
        )
    }


    func testUnsupportedPrototypeProfileUsesRecommendedStyle() {
        XCTAssertEqual(
            ZhuowangPrototypeExecutionProfile(
                fidelity: .low,
                style: .highFidelityMarketingPage
            ).normalized,
            ZhuowangPrototypeExecutionProfile(
                fidelity: .low,
                style: .grayscaleWireframe
            )
        )
        XCTAssertEqual(
            ZhuowangPrototypeExecutionProfile(
                fidelity: .high,
                style: .grayscaleWireframe
            ).normalized,
            .default
        )
    }


    func testLowFidelityWireframeProducesCorrectPrompt() throws {
        let specification = try XCTUnwrap(
            ZhuowangTaskExecutionSpecificationResolver.resolve(
                snapshot: prototypeSnapshot(
                    profile: ZhuowangPrototypeExecutionProfile(
                        fidelity: .low,
                        style: .grayscaleWireframe
                    )
                )
            )
        )

        XCTAssertTrue(
            specification.instruction.contains("Prototype Fidelity：Low-fi")
        )
        XCTAssertTrue(
            specification.instruction.contains("Prototype Style：黑白灰线框")
        )
        XCTAssertTrue(
            specification.instruction.contains("Low-fi 不等于空白页面")
        )
        XCTAssertTrue(
            specification.instruction.contains("使用线框与灰阶突出页面结构")
        )
        XCTAssertTrue(
            specification.instruction.contains("按钮、弹窗、交互状态与基础点击逻辑")
        )
    }


    func testHighFidelityMarketingPageProducesCorrectPrompt() throws {
        let specification = try XCTUnwrap(
            ZhuowangTaskExecutionSpecificationResolver.resolve(
                snapshot: prototypeSnapshot(
                    profile: .default
                )
            )
        )

        XCTAssertTrue(
            specification.instruction.contains("Prototype Fidelity：High-fi")
        )
        XCTAssertTrue(
            specification.instruction.contains("Prototype Style：高保真活动页")
        )
        XCTAssertTrue(
            specification.instruction.contains("接近真实上线活动页")
        )
        XCTAssertTrue(
            specification.instruction.contains("首屏、权益、任务、奖励、弹窗和异常状态")
        )
    }


    func testArtifactProvenanceRoundTripPreservesPrototypeProfile() throws {
        let profile = ZhuowangPrototypeExecutionProfile(
            fidelity: .mid,
            style: .brandMinimal
        )
        let artifact = ZhuowangArtifact(
            campaignID: UUID(),
            name: "产品原型设计",
            type: .html,
            logicalKey: "workflow.prototypeDesign.primary",
            capability: .prototypeDesign,
            prototypeExecutionProfile: profile
        )

        let data = try JSONEncoder().encode(artifact)
        let decoded = try JSONDecoder().decode(
            ZhuowangArtifact.self,
            from: data
        )

        XCTAssertEqual(decoded.prototypeExecutionProfile, profile)
    }


    func testPrototypeProfileDoesNotChangeArtifactLogicalKey() {
        let logicalKey = "workflow.prototypeDesign.primary"
        let low = ZhuowangArtifact(
            campaignID: UUID(),
            name: "产品原型设计",
            type: .html,
            logicalKey: logicalKey,
            prototypeExecutionProfile: ZhuowangPrototypeExecutionProfile(
                fidelity: .low,
                style: .grayscaleWireframe
            )
        )
        let high = ZhuowangArtifact(
            campaignID: UUID(),
            name: "产品原型设计",
            type: .html,
            logicalKey: logicalKey,
            prototypeExecutionProfile: .default
        )

        XCTAssertEqual(low.versionGroupKey, logicalKey)
        XCTAssertEqual(high.versionGroupKey, logicalKey)
    }


    func testHTMLRouteDeterminesExecutableTaskSpecification() {
        let campaign = ZhuowangCampaign(
            name: "测试活动",
            scopeType: .other,
            startDate: Date(),
            endDate: Date()
        )
        let workflow = ZhuowangCampaignWorkflow.standard(
            campaignID: campaign.id
        )
        guard let step = workflow.steps.first(
            where: { $0.kind == .prototype }
        ) else {
            XCTFail("标准 Workflow 缺少 Step 05")
            return
        }
        let snapshot = ZhuowangWorkflowExecutionSnapshot(
            workflowID: workflow.id,
            workflowStepID: step.id,
            providerID: UUID(),
            connectionID: ZhuowangBuiltInIntegrationIDs.deepSeekConnection,
            toolIntegrationID: ZhuowangBuiltInIntegrationIDs.htmlPrototypeTool,
            routeID: ZhuowangBuiltInIntegrationIDs.deepSeekHTMLRoute,
            capability: .prototypeDesign,
            adapterIdentifier: "deepseek-harness-html-prototype"
        )

        let taskPackage = ZhuowangTaskPackageBuilder.build(
            campaign: campaign,
            province: nil,
            module: nil,
            workflow: workflow,
            step: step,
            provider: nil,
            executionSnapshot: snapshot
        )

        XCTAssertTrue(
            taskPackage.instruction.contains(
                "完整、可直接打开并运行的单文件 HTML Prototype"
            )
        )
        XCTAssertTrue(
            taskPackage.instruction.contains(
                "不要使用 Markdown 代码围栏"
            )
        )
        XCTAssertTrue(
            taskPackage.instruction.contains(
                "【内部策划标记转换规则】"
            )
        )
        XCTAssertTrue(
            taskPackage.instruction.contains(
                "均属于内部策划状态，不是最终用户页面文案"
            )
        )
        XCTAssertTrue(
            taskPackage.instruction.contains(
                "非必要字段尚未确定时，应隐藏或省略该字段"
            )
        )
        XCTAssertTrue(
            taskPackage.instruction.contains(
                "必要字段或业务参数尚未确定时，仍须生成完整 UI 结构"
            )
        )
        XCTAssertTrue(
            taskPackage.instruction.contains(
                "【最终输出自检】"
            )
        )
        XCTAssertTrue(
            taskPackage.instruction.contains(
                "不得包含“待补充”“未填写”“TBD”“TODO”“Placeholder”等内部标记"
            )
        )
        XCTAssertFalse(
            taskPackage.instruction.contains("明确标注待确认")
        )
        XCTAssertFalse(
            taskPackage.instruction.contains("等待用户确认")
        )
        XCTAssertFalse(
            taskPackage.instruction.contains("准备原型设计执行所需要的说明")
        )
        XCTAssertEqual(
            taskPackage.expectedOutputs,
            [
                "完整、可直接打开并运行的单文件 HTML Prototype（包含完整 html / head / body、必要页面结构、视觉层级与基础交互）"
            ]
        )

        XCTAssertFalse(taskPackage.destinationHint.isEmpty)

        let executionText = DeepSeekHarnessAdapter.buildExecutionText(
            from: taskPackage
        )

        XCTAssertFalse(
            executionText.contains(taskPackage.destinationHint)
        )
        XCTAssertFalse(
            executionText.contains("【建议保存位置】")
        )
        XCTAssertTrue(
            executionText.contains(
                "stdout 必须且只能包含完整 HTML 源码"
            )
        )
        XCTAssertTrue(
            executionText.contains(
                "不要创建、修改、复制或管理任何正式 Artifact 文件"
            )
        )
    }


    func testPrototypeBusinessGoalRemainsToolAgnostic() {
        let campaign = ZhuowangCampaign(
            name: "测试活动",
            scopeType: .other,
            startDate: Date(),
            endDate: Date()
        )
        let workflow = ZhuowangCampaignWorkflow.standard(
            campaignID: campaign.id
        )
        guard let step = workflow.steps.first(
            where: { $0.kind == .prototype }
        ) else {
            XCTFail("标准 Workflow 缺少 Step 05")
            return
        }

        let taskPackage = ZhuowangTaskPackageBuilder.build(
            campaign: campaign,
            province: nil,
            module: nil,
            workflow: workflow,
            step: step,
            provider: nil
        )

        XCTAssertTrue(
            taskPackage.instruction.contains(
                "使用本轮所选 Tool 生成真实的产品原型交付物"
            )
        )
        XCTAssertFalse(
            taskPackage.instruction.contains("单文件 HTML Prototype")
        )
        XCTAssertEqual(
            taskPackage.expectedOutputs,
            ["本轮所选 Tool 生成的真实产品原型交付物"]
        )
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


    func testHTMLAdapterAllowsStandardInputPlaceholder() async throws {
        let adapter = ZhuowangHTMLPrototypeAdapter()
        let taskPackage = ZhuowangAITaskPackage(
            campaignID: UUID(),
            workflowStepID: UUID(),
            title: "产品原型设计",
            instruction: "生成产品原型"
        )
        let html = """
        <html><head><title>输入提示</title></head><body>
        <input type="tel" placeholder="请输入手机号">
        </body></html>
        """

        let draft = try await adapter.execute(
            taskPackage: taskPackage,
            rawAIResult: html
        )

        XCTAssertTrue(
            draft.content.contains(
                "placeholder=\"请输入手机号\""
            )
        )
    }


    func testHTMLAdapterAllowsStandardTextareaPlaceholder() async throws {
        let adapter = ZhuowangHTMLPrototypeAdapter()
        let taskPackage = ZhuowangAITaskPackage(
            campaignID: UUID(),
            workflowStepID: UUID(),
            title: "产品原型设计",
            instruction: "生成产品原型"
        )
        let html = """
        <html><head><title>输入提示</title></head><body>
        <textarea placeholder="请输入反馈内容"></textarea>
        </body></html>
        """

        let draft = try await adapter.execute(
            taskPackage: taskPackage,
            rawAIResult: html
        )

        XCTAssertTrue(
            draft.content.contains(
                "placeholder=\"请输入反馈内容\""
            )
        )
    }


    func testHTMLAdapterRejectsSemanticPlaceholderContent() async {
        let adapter = ZhuowangHTMLPrototypeAdapter()
        let taskPackage = ZhuowangAITaskPackage(
            campaignID: UUID(),
            workflowStepID: UUID(),
            title: "产品原型设计",
            instruction: "生成产品原型"
        )
        let rejectedBodies = [
            "<div class=\"placeholder\">页面待补充</div>",
            "<!-- Placeholder --><main>真实页面</main>",
            "<input placeholder=\"TODO\">",
            "<textarea placeholder=\"后续补充\"></textarea>",
            "<input placeholder=\"待实现\">",
            "<section>空白模块</section>"
        ]

        for body in rejectedBodies {
            let html = """
            <html><head><title>无效原型</title></head>
            <body>\(body)</body></html>
            """

            do {
                _ = try await adapter.execute(
                    taskPackage: taskPackage,
                    rawAIResult: html
                )
                XCTFail("未实现内容不应通过校验：\(body)")
            } catch let error as ZhuowangHTMLPrototypeAdapterError {
                guard case .placeholderContent = error else {
                    XCTFail("应返回 placeholderContent，实际为 \(error)")
                    continue
                }
            } catch {
                XCTFail("应返回 HTML Placeholder 错误，实际为 \(error)")
            }
        }
    }


    func testHTMLNormalizerAcceptsCompleteHTML() throws {
        let html = """
        \u{FEFF}  <!doctype html>
        <html><head><title>正常结果</title></head>
        <body>内容</body></html>
        """

        let normalized = try ZhuowangHTMLPrototypeNormalizer()
            .normalize(html)

        XCTAssertTrue(normalized.hasPrefix("<!doctype html>"))
        XCTAssertTrue(normalized.contains("正常结果"))
        XCTAssertFalse(normalized.contains("\u{FEFF}"))
    }


    func testHTMLNormalizerExtractsFencedHTML() throws {
        let raw = """
        ```html
        <!doctype html>
        <html><head><title>围栏</title></head>
        <body>内容</body></html>
        ```
        """

        let normalized = try ZhuowangHTMLPrototypeNormalizer()
            .normalize(raw)

        XCTAssertTrue(normalized.hasPrefix("<!doctype html>"))
        XCTAssertFalse(normalized.contains("```"))
    }


    func testHTMLNormalizerExtractsDocumentSurroundedByExplanation() throws {
        let raw = """
        以下是最终结果：
        <html><head><title>唯一文档</title></head>
        <body>内容</body></html>
        以上内容可直接打开。
        """

        let normalized = try ZhuowangHTMLPrototypeNormalizer()
            .normalize(raw)

        XCTAssertTrue(normalized.hasPrefix("<html>"))
        XCTAssertTrue(normalized.hasSuffix("</html>"))
        XCTAssertFalse(normalized.contains("以下是最终结果"))
    }


    func testHTMLNormalizerRejectsMarkdownDeliveryNote() {
        XCTAssertThrowsError(
            try ZhuowangHTMLPrototypeNormalizer().normalize(
                "## 交付物\n已完成产品原型并保存。"
            )
        )
    }


    func testHTMLNormalizerRejectsFilePath() {
        XCTAssertThrowsError(
            try ZhuowangHTMLPrototypeNormalizer().normalize(
                "/Workspace/05_产品原型/产品原型设计_V2.html"
            )
        )
    }


    func testHTMLNormalizerRejectsFragment() {
        XCTAssertThrowsError(
            try ZhuowangHTMLPrototypeNormalizer().normalize(
                "<main><h1>只有 fragment</h1></main>"
            )
        )
    }


    func testNextArtifactVersionUsesMetadataAndWorkspaceVersions() {
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
                logicalKey: logicalKey,
                workspaceVersions: [2]
            ),
            3
        )

        XCTAssertTrue(v1.isApprovedVersion)

        XCTAssertEqual(
            ZhuowangWorkflowTransitionLogic.nextArtifactVersion(
                artifacts: [v1],
                logicalKey: logicalKey
            ),
            2
        )
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


    func testRecoveryDoesNotImportUnmanagedVersionIntoManagedGroup() {
        let stepID = UUID()
        let logicalKey = "workflow.prototypeDesign.primary"
        let v1 = ZhuowangArtifact(
            campaignID: UUID(),
            stepID: stepID,
            name: "产品原型设计",
            type: .html,
            logicalKey: logicalKey,
            version: 1,
            isApprovedVersion: true
        )

        XCTAssertFalse(
            ZhuowangWorkflowTransitionLogic
                .shouldRecoverMissingArtifact(
                    existingArtifactsAtRecoveryStart: [v1],
                    stepID: stepID,
                    versionGroupKey: logicalKey,
                    artifactName: "产品原型设计"
                )
        )

        XCTAssertTrue(
            ZhuowangWorkflowTransitionLogic
                .shouldRecoverMissingArtifact(
                    existingArtifactsAtRecoveryStart: [],
                    stepID: stepID,
                    versionGroupKey: logicalKey,
                    artifactName: "产品原型设计"
                )
        )
        XCTAssertTrue(v1.isApprovedVersion)
    }


    func testWorkspaceVersionDiscoveryAndWriteNeverOverwriteExistingFile()
        throws {

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let manager = ZhuowangWorkspaceFileManager(rootURL: root)
        let originalContent =
            "<html><head></head><body>外部 V2</body></html>"

        let existingURL = try manager.writeHTMLArtifact(
            provinceName: "浙江",
            campaignName: "测试活动",
            stepKind: .prototype,
            artifactName: "产品原型设计",
            version: 2,
            content: originalContent
        )

        XCTAssertEqual(
            manager.existingArtifactVersions(
                provinceName: "浙江",
                campaignName: "测试活动",
                stepKind: .prototype,
                artifactName: "产品原型设计",
                fileExtension: "html"
            ),
            [2]
        )

        XCTAssertThrowsError(
            try manager.writeHTMLArtifact(
                provinceName: "浙江",
                campaignName: "测试活动",
                stepKind: .prototype,
                artifactName: "产品原型设计",
                version: 2,
                content: "<html><head></head><body>新内容</body></html>"
            )
        )

        XCTAssertEqual(
            try String(contentsOf: existingURL, encoding: .utf8),
            originalContent
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


    private func prototypeSnapshot(
        profile: ZhuowangPrototypeExecutionProfile
    ) -> ZhuowangWorkflowExecutionSnapshot {
        ZhuowangWorkflowExecutionSnapshot(
            workflowID: UUID(),
            workflowStepID: UUID(),
            providerID: UUID(),
            connectionID: ZhuowangBuiltInIntegrationIDs.deepSeekConnection,
            toolIntegrationID: ZhuowangBuiltInIntegrationIDs.htmlPrototypeTool,
            routeID: ZhuowangBuiltInIntegrationIDs.deepSeekHTMLRoute,
            capability: .prototypeDesign,
            adapterIdentifier: "deepseek-harness-html-prototype",
            prototypeExecutionProfile: profile
        )
    }
}
