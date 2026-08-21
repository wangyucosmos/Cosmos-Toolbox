import Foundation

/// Tool- and route-specific output contract layered on top of a Workflow
/// Step's tool-agnostic business goal.
struct ZhuowangTaskExecutionSpecification: Equatable {

    let instruction: String
    let expectedOutputs: [String]
}


enum ZhuowangTaskExecutionSpecificationResolver {

    static func resolve(
        snapshot: ZhuowangWorkflowExecutionSnapshot?
    ) -> ZhuowangTaskExecutionSpecification? {

        guard let snapshot else {
            return nil
        }

        guard
            snapshot.capability == .prototypeDesign,
            snapshot.toolIntegrationID
                == ZhuowangBuiltInIntegrationIDs.htmlPrototypeTool,
            snapshot.routeID
                == ZhuowangBuiltInIntegrationIDs.deepSeekHTMLRoute,
            snapshot.adapterIdentifier
                == "deepseek-harness-html-prototype"
        else {
            return nil
        }

        let profile =
            snapshot.prototypeExecutionProfile?
                .normalized
            ?? .default

        return htmlPrototype(
            profile: profile
        )
    }


    private static func htmlPrototype(
        profile: ZhuowangPrototypeExecutionProfile
    ) -> ZhuowangTaskExecutionSpecification {
        ZhuowangTaskExecutionSpecification(
            instruction: """
            【当前 Tool / Route 执行规范】
            本次必须立即生成完整、可直接打开并运行的单文件 HTML Prototype。
            HTML 页面内容必须依据当前采用的上游 Artifacts，包含完整的 html、head、body 结构、UTF-8 meta、内联 CSS，以及必要的页面结构、视觉层级和基础交互。
            本 Route 使用自动结果回传：stdout 必须且只能返回完整 HTML 源码，不要使用 Markdown 代码围栏。
            不得创建、修改、复制或管理正式 Artifact 文件；Cosmos OS 将在校验、预览和人工采用后负责正式落盘。
            不得输出文件路径、交付说明、执行说明或组件清单来代替 HTML。
            禁止使用 Placeholder、TODO、伪代码、“后续补充”或空白组件代替真实页面。
            HTML input/textarea 的标准 placeholder 属性可用于真实输入提示，但不得用于掩盖未实现功能。

            【Prototype Execution Profile】
            Prototype Fidelity：\(profile.fidelity.title)
            Prototype Style：\(profile.style.title)
            \(fidelityInstruction(for: profile.fidelity))
            \(styleInstruction(for: profile.style))

            【内部策划标记转换规则】
            上游 Artifact 中的“未填写”“待补充”“待确认”“TBD”“占位”“示例”“业务备注”以及内部讨论语言，均属于内部策划状态，不是最终用户页面文案。
            不得将这些内部策划标记原样复制到 HTML 用户可见内容，不得据此生成空白模块，也不得生成 TODO 或 Placeholder 页面。
            非必要字段尚未确定时，应隐藏或省略该字段，不得显示“字段名：待补充”“字段名：未填写”等内容。
            必要字段或业务参数尚未确定时，仍须生成完整 UI 结构、状态和基础交互，并使用中性、面向用户的原型表达，不得虚构已经确认的业务事实。
            上游标注为“框架”或“占位”的模块，表示本轮必须完成对应组件，而不是在页面中保留占位内容。
            通用执行原则中的“明确指出缺失信息”不表示可以把内部缺失状态直接渲染成最终页面文案。

            【最终输出自检】
            生成 HTML 前检查最终源码：不得包含“待补充”“未填写”“TBD”“TODO”“Placeholder”等内部标记，不得存在空白模块、未实现组件或以说明文字代替真实 UI 的情况。
            不要要求用户再次确认后才开始制作。
            """,
            expectedOutputs: [
                "完整、可直接打开并运行的单文件 HTML Prototype（包含完整 html / head / body、必要页面结构、视觉层级与基础交互）"
            ]
        )
    }


    private static func fidelityInstruction(
        for fidelity: ZhuowangPrototypeFidelity
    ) -> String {
        switch fidelity {
        case .low:
            return """
            Low-fi 执行要求：使用黑白灰表达并以结构为先，减少品牌装饰，突出布局、信息层级、模块关系和交互入口。
            必须保留完整页面结构、按钮、弹窗、交互状态与基础点击逻辑；Low-fi 不等于空白页面、空壳页面或未完成页面。
            """
        case .mid:
            return """
            Mid-fi 执行要求：在清晰完整的页面结构与交互流程基础上，提供适度视觉层级、组件状态和品牌表达，兼顾结构验证与视觉方向验证。
            """
        case .high:
            return """
            High-fi 执行要求：生成接近真实上线活动页的完整原型，具备完整视觉层级、真实移动端表现和完整交互反馈，不得以线框或结构草图代替成品级页面。
            """
        }
    }


    private static func styleInstruction(
        for style: ZhuowangPrototypeStyle
    ) -> String {
        switch style {
        case .grayscaleWireframe:
            return """
            黑白灰线框风格：使用线框与灰阶突出页面结构，禁止大量品牌色和复杂视觉装饰。
            """
        case .annotatedBoard:
            return """
            批注说明板风格：以清晰的页面模块和流程为主体，可使用克制的批注解释关键交互、状态变化与设计意图，但批注不得代替真实 UI。
            """
        case .brandMinimal:
            return """
            品牌简约风格：使用克制的品牌元素、清晰排版和简洁组件建立完整视觉层级，避免过度装饰，同时保留完整交互与状态。
            """
        case .highFidelityMarketingPage:
            return """
            高保真活动页风格：按照活动主题生成完整营销视觉，必须包含首屏、权益、任务、奖励、弹窗和异常状态，并呈现可直接体验的活动流程。
            """
        }
    }
}
