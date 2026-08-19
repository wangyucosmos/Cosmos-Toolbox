import Foundation

// MARK: - AI Provider Kind

enum ZhuowangAIProviderKind: String, Codable, CaseIterable, Identifiable {

    case openAI
    case codex
    case deepSeekHarness
    case claude
    case figma
    case custom

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .codex:
            return "Codex"
        case .deepSeekHarness:
            return "DeepSeek Harness"
        case .claude:
            return "Claude"
        case .figma:
            return "Figma"
        case .custom:
            return "自定义"
        }
    }

    var systemImage: String {
        switch self {
        case .openAI:
            return "sparkles"
        case .codex:
            return "terminal"
        case .deepSeekHarness:
            return "brain"
        case .claude:
            return "message"
        case .figma:
            return "square.on.square"
        case .custom:
            return "puzzlepiece.extension"
        }
    }
}


// MARK: - AI Provider

struct ZhuowangAIProvider:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID

    var name: String
    var kind: ZhuowangAIProviderKind

    /// Example:
    /// GPT-5.6, Claude Sonnet, DeepSeek model name, etc.
    var modelName: String

    /// Whether this provider is currently available for use.
    var isEnabled: Bool

    /// Whether Cosmos OS should show this provider
    /// as an option in workflow steps.
    var isVisible: Bool

    /// Reserved for future adapter configuration.
    /// Example:
    /// local endpoint, connector name, MCP server identifier.
    var configurationIdentifier: String?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        kind: ZhuowangAIProviderKind,
        modelName: String = "",
        isEnabled: Bool = true,
        isVisible: Bool = true,
        configurationIdentifier: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.modelName = modelName
        self.isEnabled = isEnabled
        self.isVisible = isVisible
        self.configurationIdentifier = configurationIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }


    // MARK: Backward-Compatible Codable

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case modelName
        case isEnabled
        case isVisible
        case configurationIdentifier
        case createdAt
        case updatedAt
    }


    init(from decoder: Decoder) throws {

        let container =
            try decoder.container(
                keyedBy: CodingKeys.self
            )

        id =
            try container.decode(
                UUID.self,
                forKey: .id
            )

        name =
            try container.decodeIfPresent(
                String.self,
                forKey: .name
            )
            ?? "未命名 AI Provider"

        kind =
            try container.decodeIfPresent(
                ZhuowangAIProviderKind.self,
                forKey: .kind
            )
            ?? .custom

        modelName =
            try container.decodeIfPresent(
                String.self,
                forKey: .modelName
            )
            ?? ""

        isEnabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .isEnabled
            )
            ?? true

        isVisible =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .isVisible
            )
            ?? true

        configurationIdentifier =
            try container.decodeIfPresent(
                String.self,
                forKey: .configurationIdentifier
            )

        createdAt =
            try container.decodeIfPresent(
                Date.self,
                forKey: .createdAt
            )
            ?? Date()

        updatedAt =
            try container.decodeIfPresent(
                Date.self,
                forKey: .updatedAt
            )
            ?? createdAt
    }
}


// MARK: - Workflow Capability

/// Describes the ability required by a workflow step.
/// This is intentionally separated from concrete tools.
///
/// Example:
/// Prototype Design capability can be fulfilled by:
/// - Figma
/// - Pixso
/// - HTML prototype
/// - Other future design tools
enum ZhuowangWorkflowCapability:
    String,
    Codable,
    CaseIterable,
    Identifiable {

    case informationProcessing
    case planning
    case documentGeneration
    case prototypeDesign
    case imageCreation
    case dataProcessing
    case codeGeneration
    case publishing
    case custom

    var id: String {
        rawValue
    }

    var title: String {

        switch self {
        case .informationProcessing:
            return "信息整理"

        case .planning:
            return "策划规划"

        case .documentGeneration:
            return "文档生成"

        case .prototypeDesign:
            return "原型设计"

        case .imageCreation:
            return "视觉生成"

        case .dataProcessing:
            return "数据处理"

        case .codeGeneration:
            return "代码生成"

        case .publishing:
            return "发布"

        case .custom:
            return "自定义"
        }
    }
}


// MARK: - Workflow Step Kind

enum ZhuowangWorkflowStepKind: String, Codable {

    case brief
    case idea
    case plan
    case pageStructure
    case prototype
    case customerService
    case prompt
    case flowchart
    case asset
    case review
    case custom
}


// MARK: - Workflow Step Status

enum ZhuowangWorkflowStepStatus: String, Codable, CaseIterable, Identifiable {

    case notStarted
    case ready
    case running
    case waitingForApproval
    case approved
    case needsRevision
    case completed
    case failed
    case skipped

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .notStarted:
            return "未开始"
        case .ready:
            return "可开始"
        case .running:
            return "生成中"
        case .waitingForApproval:
            return "等待确认"
        case .approved:
            return "已确认"
        case .needsRevision:
            return "需修改"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        case .skipped:
            return "已跳过"
        }
    }
}


// MARK: - Workflow Step

struct ZhuowangWorkflowStep:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID

    var title: String
    var englishTitle: String

    var kind: ZhuowangWorkflowStepKind

    /// Controls display order.
    var sortOrder: Int

    var status: ZhuowangWorkflowStepStatus

    /// User-selected provider for this step.
    /// Nil means provider has not been selected yet.
    var selectedProviderID: UUID?

    /// Capabilities required by this workflow step.
    /// This avoids binding Cosmos OS to one specific product.
    var requiredCapabilities: [ZhuowangWorkflowCapability]

    /// External tools required by this workflow step.
    /// Examples: Figma, Pixso, GitHub, Browser.
    var requiredTools: [ZhuowangExternalToolKind]

    /// User-selected tools for this specific execution path.
    /// Kept separate from requiredTools because one capability
    /// may have multiple available tools.
    var selectedToolIDs: [UUID]

    /// If true, Cosmos OS may recommend a provider.
    /// The user still keeps final control.
    var allowsAutomaticProviderRecommendation: Bool

    /// Whether this step requires explicit user approval
    /// before the next step can continue.
    var requiresApproval: Bool

    /// Whether this step is currently enabled.
    /// This allows a workflow to add/remove steps
    /// without deleting historical data.
    var isEnabled: Bool

    var notes: String

    var createdAt: Date
    var updatedAt: Date


    init(
        id: UUID = UUID(),
        title: String,
        englishTitle: String = "",
        kind: ZhuowangWorkflowStepKind = .custom,
        sortOrder: Int,
        status: ZhuowangWorkflowStepStatus = .notStarted,
        selectedProviderID: UUID? = nil,
        requiredCapabilities: [ZhuowangWorkflowCapability] = [],
        requiredTools: [ZhuowangExternalToolKind] = [],
        selectedToolIDs: [UUID] = [],
        allowsAutomaticProviderRecommendation: Bool = true,
        requiresApproval: Bool = true,
        isEnabled: Bool = true,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.englishTitle = englishTitle
        self.kind = kind
        self.sortOrder = sortOrder
        self.status = status
        self.selectedProviderID = selectedProviderID
        self.requiredCapabilities = requiredCapabilities
        self.requiredTools = requiredTools
        self.selectedToolIDs = selectedToolIDs
        self.allowsAutomaticProviderRecommendation =
            allowsAutomaticProviderRecommendation
        self.requiresApproval = requiresApproval
        self.isEnabled = isEnabled
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }


    // MARK: Backward-Compatible Codable

    /// Workflow Step is persisted across Cosmos OS versions.
    /// Newly-added fields must never make an older saved workflow undecodable.
    private enum CodingKeys:
        String,
        CodingKey {

        case id
        case title
        case englishTitle
        case kind
        case sortOrder
        case status
        case selectedProviderID
        case requiredCapabilities
        case requiredTools
        case selectedToolIDs
        case allowsAutomaticProviderRecommendation
        case requiresApproval
        case isEnabled
        case notes
        case createdAt
        case updatedAt
    }


    init(
        from decoder: Decoder
    ) throws {

        let container =
            try decoder.container(
                keyedBy: CodingKeys.self
            )

        id =
            try container.decodeIfPresent(
                UUID.self,
                forKey: .id
            )
            ?? UUID()

        title =
            try container.decodeIfPresent(
                String.self,
                forKey: .title
            )
            ?? "未命名步骤"

        englishTitle =
            try container.decodeIfPresent(
                String.self,
                forKey: .englishTitle
            )
            ?? ""

        kind =
            try container.decodeIfPresent(
                ZhuowangWorkflowStepKind.self,
                forKey: .kind
            )
            ?? .custom

        sortOrder =
            try container.decodeIfPresent(
                Int.self,
                forKey: .sortOrder
            )
            ?? 0

        status =
            try container.decodeIfPresent(
                ZhuowangWorkflowStepStatus.self,
                forKey: .status
            )
            ?? .notStarted

        selectedProviderID =
            try container.decodeIfPresent(
                UUID.self,
                forKey: .selectedProviderID
            )

        requiredCapabilities =
            try container.decodeIfPresent(
                [ZhuowangWorkflowCapability].self,
                forKey: .requiredCapabilities
            )
            ?? []

        requiredTools =
            try container.decodeIfPresent(
                [ZhuowangExternalToolKind].self,
                forKey: .requiredTools
            )
            ?? []

        selectedToolIDs =
            try container.decodeIfPresent(
                [UUID].self,
                forKey: .selectedToolIDs
            )
            ?? []

        allowsAutomaticProviderRecommendation =
            try container.decodeIfPresent(
                Bool.self,
                forKey:
                    .allowsAutomaticProviderRecommendation
            )
            ?? true

        requiresApproval =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .requiresApproval
            )
            ?? true

        isEnabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .isEnabled
            )
            ?? true

        notes =
            try container.decodeIfPresent(
                String.self,
                forKey: .notes
            )
            ?? ""

        createdAt =
            try container.decodeIfPresent(
                Date.self,
                forKey: .createdAt
            )
            ?? Date()

        updatedAt =
            try container.decodeIfPresent(
                Date.self,
                forKey: .updatedAt
            )
            ?? createdAt
    }


    func encode(
        to encoder: Encoder
    ) throws {

        var container =
            encoder.container(
                keyedBy: CodingKeys.self
            )

        try container.encode(
            id,
            forKey: .id
        )

        try container.encode(
            title,
            forKey: .title
        )

        try container.encode(
            englishTitle,
            forKey: .englishTitle
        )

        try container.encode(
            kind,
            forKey: .kind
        )

        try container.encode(
            sortOrder,
            forKey: .sortOrder
        )

        try container.encode(
            status,
            forKey: .status
        )

        try container.encodeIfPresent(
            selectedProviderID,
            forKey: .selectedProviderID
        )

        try container.encode(
            requiredCapabilities,
            forKey: .requiredCapabilities
        )

        try container.encode(
            requiredTools,
            forKey: .requiredTools
        )

        try container.encode(
            selectedToolIDs,
            forKey: .selectedToolIDs
        )

        try container.encode(
            allowsAutomaticProviderRecommendation,
            forKey:
                .allowsAutomaticProviderRecommendation
        )

        try container.encode(
            requiresApproval,
            forKey: .requiresApproval
        )

        try container.encode(
            isEnabled,
            forKey: .isEnabled
        )

        try container.encode(
            notes,
            forKey: .notes
        )

        try container.encode(
            createdAt,
            forKey: .createdAt
        )

        try container.encode(
            updatedAt,
            forKey: .updatedAt
        )
    }
}



// MARK: - AI Run Status

enum ZhuowangAIRunStatus: String, Codable {

    case queued
    case running
    case succeeded
    case failed
    case cancelled
}


// MARK: - AI Run

struct ZhuowangAIRun:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID

    /// The workflow step that started this run.
    var stepID: UUID

    /// Provider used for this specific run.
    var providerID: UUID

    /// Model actually used.
    /// Stored here so old runs remain traceable
    /// even if provider settings later change.
    var modelName: String

    var status: ZhuowangAIRunStatus

    /// Prompt / instruction sent to the provider.
    var inputText: String

    /// Raw or normalized result returned by the provider.
    var outputText: String

    /// Optional technical error.
    var errorMessage: String?

    /// Allows multiple attempts under the same workflow step.
    var version: Int

    var startedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        stepID: UUID,
        providerID: UUID,
        modelName: String = "",
        status: ZhuowangAIRunStatus = .queued,
        inputText: String,
        outputText: String = "",
        errorMessage: String? = nil,
        version: Int = 1,
        startedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.stepID = stepID
        self.providerID = providerID
        self.modelName = modelName
        self.status = status
        self.inputText = inputText
        self.outputText = outputText
        self.errorMessage = errorMessage
        self.version = version
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}


// MARK: - Approval Decision

enum ZhuowangApprovalDecision: String, Codable {

    case pending
    case approved
    case revisionRequested
    case rejected
}


// MARK: - Approval

struct ZhuowangApproval:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID

    var stepID: UUID

    /// Optional AI run being reviewed.
    var runID: UUID?

    var decision: ZhuowangApprovalDecision

    /// User feedback such as:
    /// "玩法太复杂，简化后重新生成"
    var feedback: String

    var createdAt: Date
    var decidedAt: Date?

    init(
        id: UUID = UUID(),
        stepID: UUID,
        runID: UUID? = nil,
        decision: ZhuowangApprovalDecision = .pending,
        feedback: String = "",
        createdAt: Date = Date(),
        decidedAt: Date? = nil
    ) {
        self.id = id
        self.stepID = stepID
        self.runID = runID
        self.decision = decision
        self.feedback = feedback
        self.createdAt = createdAt
        self.decidedAt = decidedAt
    }
}


// MARK: - Artifact Type

enum ZhuowangArtifactType: String, Codable, CaseIterable, Identifiable {

    case markdown
    case word
    case pdf
    case excel
    case image
    case figma
    case html
    case flowchart
    case prompt
    case url
    case other

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .markdown:
            return "Markdown"
        case .word:
            return "Word"
        case .pdf:
            return "PDF"
        case .excel:
            return "Excel"
        case .image:
            return "图片"
        case .figma:
            return "Figma"
        case .html:
            return "HTML"
        case .flowchart:
            return "流程图"
        case .prompt:
            return "Prompt"
        case .url:
            return "链接"
        case .other:
            return "其他"
        }
    }
}


// MARK: - Artifact

struct ZhuowangArtifact:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID

    var campaignID: UUID

    /// Optional workflow step that produced this artifact.
    var stepID: UUID?

    /// Optional AI run that produced this artifact.
    var runID: UUID?

    var name: String
    var type: ZhuowangArtifactType

    /// Local path, future cloud path, Figma URL,
    /// GitHub URL, etc.
    var location: String

    /// Text content stored directly inside Cosmos OS.
    /// Optional for backward compatibility with older saved artifacts.
    var content: String?

    var version: Int

    /// Whether this artifact has been confirmed
    /// as the currently adopted version.
    var isApprovedVersion: Bool

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        campaignID: UUID,
        stepID: UUID? = nil,
        runID: UUID? = nil,
        name: String,
        type: ZhuowangArtifactType,
        location: String = "",
        content: String? = nil,
        version: Int = 1,
        isApprovedVersion: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.campaignID = campaignID
        self.stepID = stepID
        self.runID = runID
        self.name = name
        self.type = type
        self.location = location
        self.content = content
        self.version = version
        self.isApprovedVersion = isApprovedVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


// MARK: - Campaign Workflow

struct ZhuowangCampaignWorkflow:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID

    var campaignID: UUID

    var name: String

    var steps: [ZhuowangWorkflowStep]

    var aiRuns: [ZhuowangAIRun]

    var approvals: [ZhuowangApproval]

    var artifacts: [ZhuowangArtifact]

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        campaignID: UUID,
        name: String = "标准活动工作流",
        steps: [ZhuowangWorkflowStep] = [],
        aiRuns: [ZhuowangAIRun] = [],
        approvals: [ZhuowangApproval] = [],
        artifacts: [ZhuowangArtifact] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.campaignID = campaignID
        self.name = name
        self.steps = steps
        self.aiRuns = aiRuns
        self.approvals = approvals
        self.artifacts = artifacts
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


// MARK: - Default Workflow Template

extension ZhuowangCampaignWorkflow {

    static func standard(
        campaignID: UUID
    ) -> ZhuowangCampaignWorkflow {

        ZhuowangCampaignWorkflow(
            campaignID: campaignID,
            name: "卓望标准活动工作流",
            steps: [

                ZhuowangWorkflowStep(
                    title: "需求整理",
                    englishTitle: "Brief",
                    kind: .brief,
                    sortOrder: 10,
                    status: .ready,
                    requiresApproval: true
                ),

                ZhuowangWorkflowStep(
                    title: "策划思路",
                    englishTitle: "Campaign Idea",
                    kind: .idea,
                    sortOrder: 20,
                    requiresApproval: true
                ),

                ZhuowangWorkflowStep(
                    title: "完整策划案",
                    englishTitle: "Campaign Plan",
                    kind: .plan,
                    sortOrder: 30,
                    requiresApproval: true
                ),

                ZhuowangWorkflowStep(
                    title: "页面结构",
                    englishTitle: "Page Structure",
                    kind: .pageStructure,
                    sortOrder: 40,
                    requiresApproval: true
                ),

                ZhuowangWorkflowStep(
                    title: "产品原型设计",
                    englishTitle: "Product Prototype",
                    kind: .prototype,
                    sortOrder: 50,
                    requiredCapabilities: [
                        .prototypeDesign
                    ],
                    requiresApproval: true
                ),

                ZhuowangWorkflowStep(
                    title: "客服文档",
                    englishTitle: "Customer Service FAQ",
                    kind: .customerService,
                    sortOrder: 60,
                    requiresApproval: true
                )
            ]
        )
    }
}


