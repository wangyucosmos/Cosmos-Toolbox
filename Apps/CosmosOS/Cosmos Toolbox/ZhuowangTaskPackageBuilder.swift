import Foundation

struct ZhuowangTaskPackageBuilder {

    // MARK: - Build

    static func build(
        campaign: ZhuowangCampaign,
        province: ZhuowangProvince?,
        module: ZhuowangModule?,
        workflow: ZhuowangCampaignWorkflow,
        step: ZhuowangWorkflowStep,
        provider: ZhuowangAIProvider?
    ) -> ZhuowangAITaskPackage {

        ZhuowangAITaskPackage(
            campaignID: campaign.id,
            workflowStepID: step.id,
            title: taskTitle(
                campaign: campaign,
                step: step
            ),
            instruction: taskInstruction(
                campaign: campaign,
                province: province,
                module: module,
                workflow: workflow,
                step: step,
                provider: provider
            ),
            contextReferences: contextReferences(
                campaign: campaign,
                step: step
            ),
            expectedOutputs: expectedOutputs(
                for: step
            ),
            destinationHint: destinationHint(
                campaign: campaign,
                step: step
            )
        )
    }


    // MARK: - Task Title

    private static func taskTitle(
        campaign: ZhuowangCampaign,
        step: ZhuowangWorkflowStep
    ) -> String {

        "\(campaign.name) · \(step.title)"
    }


    // MARK: - Main Instruction

    private static func taskInstruction(
        campaign: ZhuowangCampaign,
        province: ZhuowangProvince?,
        module: ZhuowangModule?,
        workflow: ZhuowangCampaignWorkflow,
        step: ZhuowangWorkflowStep,
        provider: ZhuowangAIProvider?
    ) -> String {

        let scopeText =
            workspaceScopeText(
                province: province,
                module: module
            )

        let providerText =
            provider?.name
            ?? "未指定 AI"

        let campaignNotes =
            campaign.notes
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let notesText =
            campaignNotes.isEmpty
            ? "暂无额外备注"
            : campaignNotes

        let previousContext =
            previousApprovedStepsText(
                workflow: workflow,
                currentStep: step
            )

        return """
        你正在处理 Cosmos OS 中的卓望工作项目。

        【当前活动】
        活动名称：\(campaign.name)
        英文名称：\(campaign.englishName.isEmpty ? "未填写" : campaign.englishName)
        所属范围：\(scopeText)
        活动时间：\(campaign.dateRangeText)
        当前状态：\(campaign.status.title)
        活动备注：\(notesText)

        【当前工作流步骤】
        步骤名称：\(step.title)
        English：\(step.englishTitle.isEmpty ? "未填写" : step.englishTitle)
        当前状态：\(step.status.title)
        执行 AI：\(providerText)

        【前置已确认内容】
        \(previousContext)

        【本次任务】
        \(instructionText(for: step))

        【执行原则】
        1. 优先遵循卓望项目既有规范与当前活动上下文。
        2. 不擅自改变已经确认的业务口径。
        3. 如果信息不足，明确指出缺失信息，不要自行虚构关键业务条件。
        4. 输出内容应便于后续继续进入 Cosmos OS Workflow。
        5. 当前阶段只完成本步骤目标，不提前替用户执行下一工作流步骤。
        """
    }


    // MARK: - Step Instruction

    private static func instructionText(
        for step: ZhuowangWorkflowStep
    ) -> String {

        switch step.kind {

        case .brief:
            return """
            整理当前活动需求，形成清晰、可供后续 AI 和人工继续工作的活动 Brief。

            重点梳理：
            - 活动背景
            - 活动目标
            - 目标用户
            - 活动时间
            - 奖励或权益信息
            - 已知业务限制
            - 当前待确认事项
            - 后续策划需要重点解决的问题

            不要直接生成完整活动策划案。
            """


        case .idea:
            return """
            基于当前活动 Brief 和既有项目规范，生成活动策划思路。

            建议至少包含：
            - 2～3 个可选策划方向
            - 活动主题
            - 主 Slogan / 副 Slogan
            - 核心玩法
            - 用户参与路径
            - 奖励机制建议
            - 页面核心模块
            - 每个方向的优缺点与适用场景

            本阶段目标是帮助用户选择方向，不要直接进入最终 Figma 原型制作。
            """


        case .plan:
            return """
            基于已经确认的策划思路，生成完整活动策划方案。

            建议包含：
            - 项目背景
            - 活动目标
            - 活动主题
            - Slogan
            - 用户对象
            - 活动时间
            - 活动机制
            - 详细玩法
            - 用户路径
            - 奖励机制
            - 页面模块说明
            - 规则与异常情况
            - 运营配置建议
            - 风险及注意事项

            如果前置策划思路尚未确认，应明确提示，不要直接假设已确认。
            """


        case .pageStructure:
            return """
            基于已经确认的活动方案，梳理页面结构与用户交互。

            输出应重点包含：
            - 页面从上到下的模块顺序
            - 每个模块的作用
            - 用户进入后的主要操作路径
            - 按钮与跳转关系
            - 弹窗与异常状态
            - 登录、领取、分享、回流等关键节点
            - 需要设计重点表现的区域

            本阶段先输出页面结构和交互逻辑，不直接执行 Figma 制作。
            """


        case .prototype:
            return """
            基于已经确认的页面结构，准备 Figma 原型制作所需要的设计执行说明。

            输出应包括：
            - 页面尺寸与基础布局建议
            - 页面模块层级
            - 组件清单
            - 交互状态
            - 页面跳转关系
            - 需要复用的设计组件
            - 需要人工确认的视觉重点
            - Figma 执行前检查项

            必须等待用户确认设计思路后，才能进入真正的 Figma 执行阶段。
            """


        case .customerService:
            return """
            根据最终确认的活动方案和规则，生成客服 FAQ 文档内容。

            重点覆盖：
            - 活动是什么
            - 谁可以参加
            - 活动时间
            - 如何参与
            - 奖励如何获得
            - 奖励不到账怎么办
            - 页面异常怎么办
            - 登录 / 手机号 / 权益相关问题
            - 常见边界情况
            - 客服标准回答口径

            不得自行增加活动方案中不存在的规则。
            """


        case .prompt:
            return """
            根据当前活动沉淀可复用 Prompt。

            Prompt 应明确：
            - 使用场景
            - 输入内容
            - 输出要求
            - 约束条件
            - 可复用变量
            - 示例调用方式
            """


        case .flowchart:
            return """
            根据当前活动业务规则整理流程图结构。

            输出应适合后续生成清晰的纵向业务流程图，
            包括主流程、判断节点、异常分支、回流路径和最终状态。
            """


        case .asset:
            return """
            根据当前活动方案整理需要生成或准备的运营素材。

            输出素材清单、用途、尺寸、文案要求、视觉方向和依赖关系。
            """


        case .review:
            return """
            对当前活动阶段已有内容进行审核。

            重点检查：
            - 前后逻辑是否一致
            - 业务口径是否冲突
            - 是否存在缺失步骤
            - 用户路径是否闭环
            - 文案是否存在歧义
            - 是否有明显执行风险
            - 是否满足当前工作流阶段要求
            """


        case .custom:
            let customNotes =
                step.notes
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            return customNotes.isEmpty
            ? "完成当前自定义工作步骤，并保持输出结构清晰、可继续进入后续 Workflow。"
            : customNotes
        }
    }


    // MARK: - Context References

    private static func contextReferences(
        campaign: ZhuowangCampaign,
        step: ZhuowangWorkflowStep
    ) -> [String] {

        var references: [String] = [
            "卓望.md",
            "Campaign：\(campaign.name)",
            "Workflow Step：\(step.title)"
        ]

        switch step.kind {

        case .brief:
            references.append(
                "当前 Campaign 基本信息"
            )

        case .idea:
            references.append(
                "已确认 Campaign Brief"
            )

        case .plan:
            references.append(
                "已确认策划思路"
            )

        case .pageStructure:
            references.append(
                "已确认完整策划方案"
            )

        case .prototype:
            references.append(
                "已确认页面结构"
            )

        case .customerService:
            references.append(
                "最终确认活动方案与规则"
            )

        default:
            break
        }

        return references
    }


    // MARK: - Expected Outputs

    private static func expectedOutputs(
        for step: ZhuowangWorkflowStep
    ) -> [String] {

        switch step.kind {

        case .brief:
            return [
                "活动 Brief",
                "待确认事项清单"
            ]

        case .idea:
            return [
                "2～3 套策划方向",
                "主题与 Slogan",
                "核心玩法建议",
                "方向对比"
            ]

        case .plan:
            return [
                "完整活动策划案"
            ]

        case .pageStructure:
            return [
                "页面模块结构",
                "用户路径",
                "交互逻辑"
            ]

        case .prototype:
            return [
                "Figma 原型执行说明",
                "组件与页面结构清单"
            ]

        case .customerService:
            return [
                "客服 FAQ",
                "标准客服回答口径"
            ]

        case .prompt:
            return [
                "可复用 Prompt"
            ]

        case .flowchart:
            return [
                "业务流程结构"
            ]

        case .asset:
            return [
                "素材需求清单"
            ]

        case .review:
            return [
                "审核结果",
                "问题清单",
                "修改建议"
            ]

        case .custom:
            return [
                "自定义工作结果"
            ]
        }
    }


    // MARK: - Destination

    private static func destinationHint(
        campaign: ZhuowangCampaign,
        step: ZhuowangWorkflowStep
    ) -> String {

        "\(campaign.name)/\(step.title)"
    }


    // MARK: - Workspace Scope

    private static func workspaceScopeText(
        province: ZhuowangProvince?,
        module: ZhuowangModule?
    ) -> String {

        if let province {
            return "\(province.name)福利中心"
        }

        if let module {
            return module.name
        }

        return "卓望工作区"
    }


    // MARK: - Previous Approved Steps

    private static func previousApprovedStepsText(
        workflow: ZhuowangCampaignWorkflow,
        currentStep: ZhuowangWorkflowStep
    ) -> String {

        let previousSteps =
            workflow.steps
                .filter {
                    $0.isEnabled
                    && $0.sortOrder
                        < currentStep.sortOrder
                    && (
                        $0.status == .approved
                        || $0.status == .completed
                    )
                }
                .sorted {
                    $0.sortOrder
                        < $1.sortOrder
                }

        guard !previousSteps.isEmpty else {
            return "暂无已经确认的前置步骤。"
        }

        return previousSteps
            .map {
                "✓ \($0.title)"
            }
            .joined(
                separator: "\n"
            )
    }
}
