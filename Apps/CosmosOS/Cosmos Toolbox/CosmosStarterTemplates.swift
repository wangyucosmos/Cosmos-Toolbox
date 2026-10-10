import Foundation

/// UI-only examples: these values enter a new unsaved editor, never a Store.
nonisolated enum CosmosProjectStarter: String, CaseIterable, Identifiable {
    case cosmos, portfolio, learningTool
    var id: String { rawValue }
    var icon: String { switch self { case .cosmos: "desktopcomputer"; case .portfolio: "briefcase"; case .learningTool: "hammer" } }
    var title: String { switch self { case .cosmos: "Cosmos OS 开发"; case .portfolio: "AI 产品运营作品集"; case .learningTool: "学习型小工具" } }
    var draft: PersonalProject {
        switch self {
        case .cosmos: PersonalProject(name: title, goal: "让日常工作在一套原生 macOS 工具中连续推进。", nextStep: "选一个日常使用最频繁的页面，记录问题并确定下一次改进范围。")
        case .portfolio: PersonalProject(name: title, goal: "整理能展示 AI 产品与运营能力的作品和验证过程。", nextStep: "选一份可公开作品，写清问题、方案与实际结果。")
        case .learningTool: PersonalProject(name: title, goal: "用一个小工具解决真实问题，同时掌握一项新技术。", nextStep: "描述输入、输出与最小可用功能，先做第一条完整流程。")
        }
    }
}
nonisolated enum CosmosPromptStarter: String, CaseIterable, Identifiable {
    case campaign, faq, development
    var id: String { rawValue }
    var title: String { switch self { case .campaign: "卓望活动策划"; case .faq: "客服 FAQ 生成"; case .development: "Claude Code / Codex 开发任务" } }
    var draft: PromptTemplate {
        let body: String
        switch self {
        case .campaign: body = "请为{{活动名称}}整理活动策划。目标人群：{{目标人群}}。活动目标：{{活动目标}}。请输出玩法、页面结构和待确认事项；缺失信息请明确指出，不编造。"
        case .faq: body = "请根据以下已确认规则，为{{活动名称}}编写客服 FAQ：\n{{活动规则}}\n覆盖参与资格、操作路径、奖品与异常处理；规则未说明的内容列为待确认，不自行补充。"
        case .development: body = "在{{仓库路径}}完成{{本次目标}}。先读取项目指令与相关代码。修改范围：{{允许修改范围}}。验证要求：{{验证要求}}。保护现有数据和未提交成果；不扩展范围，未授权时不提交、推送或部署。"
        }
        return PromptTemplate(name: title, body: body, category: "任务模板")
    }
}
