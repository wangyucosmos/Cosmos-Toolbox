import Foundation

// MARK: - Connection Mode

enum ZhuowangAIConnectionMode: String, Codable, CaseIterable, Identifiable {

    case subscriptionApp
    case api
    case localAgent
    case desktopApp
    case mcp
    case connector
    case plugin
    case manualBridge
    case custom

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .subscriptionApp:
            return "订阅应用"
        case .api:
            return "API"
        case .localAgent:
            return "本地 Agent"
        case .desktopApp:
            return "桌面应用"
        case .mcp:
            return "MCP"
        case .connector:
            return "Connector"
        case .plugin:
            return "Plugin"
        case .manualBridge:
            return "手动桥接"
        case .custom:
            return "自定义"
        }
    }

    var englishTitle: String {
        switch self {
        case .subscriptionApp:
            return "Subscription App"
        case .api:
            return "API"
        case .localAgent:
            return "Local Agent"
        case .desktopApp:
            return "Desktop App"
        case .mcp:
            return "MCP"
        case .connector:
            return "Connector"
        case .plugin:
            return "Plugin"
        case .manualBridge:
            return "Manual Bridge"
        case .custom:
            return "Custom"
        }
    }
}


// MARK: - Connection Status

enum ZhuowangAIConnectionStatus: String, Codable, CaseIterable, Identifiable {

    case notConfigured
    case available
    case unavailable
    case needsLogin
    case needsSetup
    case disabled
    case error

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .notConfigured:
            return "未配置"
        case .available:
            return "可用"
        case .unavailable:
            return "不可用"
        case .needsLogin:
            return "需要登录"
        case .needsSetup:
            return "需要配置"
        case .disabled:
            return "已停用"
        case .error:
            return "异常"
        }
    }
}


// MARK: - Capability

enum ZhuowangAICapability: String, Codable, CaseIterable, Identifiable {

    case planning
    case writing
    case research
    case analysis
    case coding
    case localFileAccess
    case documentGeneration
    case spreadsheet
    case imageGeneration
    /// General prototype creation capability.
    /// Not limited to Figma. Examples:
    /// Figma, Pixso, HTML prototype, custom design tools.
    case prototypeDesign

    /// AI can operate or automate a prototype creation workflow.
    /// The actual tool is selected separately through integrations.
    case prototypeAutomation

    /// Figma-specific editing capability.
    /// Kept as a specialized capability, not the default prototype route.
    case figmaEditing
    case browser
    case automation
    case toolCalling
    case mcpAccess
    case custom

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .planning:
            return "策划"
        case .writing:
            return "文案"
        case .research:
            return "调研"
        case .analysis:
            return "分析"
        case .coding:
            return "代码"
        case .localFileAccess:
            return "本地文件"
        case .documentGeneration:
            return "文档生成"
        case .spreadsheet:
            return "表格"
        case .imageGeneration:
            return "图片生成"
        case .prototypeDesign:
            return "原型设计"
        case .prototypeAutomation:
            return "原型自动化"
        case .figmaEditing:
            return "Figma 编辑"
        case .browser:
            return "浏览器"
        case .automation:
            return "自动化"
        case .toolCalling:
            return "工具调用"
        case .mcpAccess:
            return "MCP"
        case .custom:
            return "自定义"
        }
    }
}


// MARK: - Execution Style

enum ZhuowangAIExecutionStyle: String, Codable {

    /// Cosmos OS can directly start the task.
    case direct

    /// Cosmos OS starts or communicates with a local process.
    case localProcess

    /// Cosmos OS prepares the task package,
    /// but the user completes the hand-off manually.
    case assistedManual

    /// Reserved for future connector / MCP / plugin execution.
    case externalTool

    case custom
}


// MARK: - AI Connection

struct ZhuowangAIConnection:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID

    /// Which provider this connection belongs to.
    var providerID: UUID

    /// Example:
    /// "ChatGPT Subscription"
    /// "Codex Desktop"
    /// "DeepSeek Harness"
    /// "Claude Desktop"
    /// "Figma MCP"
    var name: String

    var mode: ZhuowangAIConnectionMode

    var status: ZhuowangAIConnectionStatus

    var executionStyle: ZhuowangAIExecutionStyle

    /// The capabilities exposed through this specific connection.
    var capabilities: Set<ZhuowangAICapability>

    /// Whether Cosmos OS may choose this connection automatically
    /// when the user selects "自动推荐".
    var allowsAutomaticSelection: Bool

    /// Whether this connection can launch tasks directly.
    /// Example:
    /// DeepSeek Harness may eventually be true.
    /// Manual Claude bridge would be false.
    var supportsDirectExecution: Bool

    /// Whether the result can be returned to Cosmos OS automatically.
    var supportsAutomaticResultReturn: Bool

    /// Optional technical adapter identifier.
    ///
    /// Example:
    /// chatgpt-subscription
    /// codex-local
    /// deepseek-harness
    /// claude-desktop-manual
    /// figma-mcp
    var adapterIdentifier: String?

    /// Optional local executable path, service URL,
    /// MCP endpoint, connector identifier, etc.
    ///
    /// Do NOT store secrets here.
    var endpointOrPath: String?

    /// Free-form non-secret configuration.
    /// This lets future integrations add settings
    /// without changing the model schema every time.
    var configuration: [String: String]

    var isEnabled: Bool

    var notes: String

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        providerID: UUID,
        name: String,
        mode: ZhuowangAIConnectionMode,
        status: ZhuowangAIConnectionStatus = .notConfigured,
        executionStyle: ZhuowangAIExecutionStyle = .assistedManual,
        capabilities: Set<ZhuowangAICapability> = [],
        allowsAutomaticSelection: Bool = true,
        supportsDirectExecution: Bool = false,
        supportsAutomaticResultReturn: Bool = false,
        adapterIdentifier: String? = nil,
        endpointOrPath: String? = nil,
        configuration: [String: String] = [:],
        isEnabled: Bool = true,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.providerID = providerID
        self.name = name
        self.mode = mode
        self.status = status
        self.executionStyle = executionStyle
        self.capabilities = capabilities
        self.allowsAutomaticSelection = allowsAutomaticSelection
        self.supportsDirectExecution = supportsDirectExecution
        self.supportsAutomaticResultReturn = supportsAutomaticResultReturn
        self.adapterIdentifier = adapterIdentifier
        self.endpointOrPath = endpointOrPath
        self.configuration = configuration
        self.isEnabled = isEnabled
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }


    // MARK: Backward-Compatible Codable

    private enum CodingKeys: String, CodingKey {
        case id
        case providerID
        case name
        case mode
        case status
        case executionStyle
        case capabilities
        case allowsAutomaticSelection
        case supportsDirectExecution
        case supportsAutomaticResultReturn
        case adapterIdentifier
        case endpointOrPath
        case configuration
        case isEnabled
        case notes
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

        providerID =
            try container.decode(
                UUID.self,
                forKey: .providerID
            )

        name =
            try container.decodeIfPresent(
                String.self,
                forKey: .name
            )
            ?? "未命名 AI Connection"

        mode =
            try container.decodeIfPresent(
                ZhuowangAIConnectionMode.self,
                forKey: .mode
            )
            ?? .custom

        status =
            try container.decodeIfPresent(
                ZhuowangAIConnectionStatus.self,
                forKey: .status
            )
            ?? .notConfigured

        executionStyle =
            try container.decodeIfPresent(
                ZhuowangAIExecutionStyle.self,
                forKey: .executionStyle
            )
            ?? .assistedManual

        capabilities =
            try container.decodeIfPresent(
                Set<ZhuowangAICapability>.self,
                forKey: .capabilities
            )
            ?? []

        allowsAutomaticSelection =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .allowsAutomaticSelection
            )
            ?? true

        supportsDirectExecution =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .supportsDirectExecution
            )
            ?? false

        supportsAutomaticResultReturn =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .supportsAutomaticResultReturn
            )
            ?? false

        adapterIdentifier =
            try container.decodeIfPresent(
                String.self,
                forKey: .adapterIdentifier
            )

        endpointOrPath =
            try container.decodeIfPresent(
                String.self,
                forKey: .endpointOrPath
            )

        configuration =
            try container.decodeIfPresent(
                [String: String].self,
                forKey: .configuration
            )
            ?? [:]

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
}


// MARK: - Stable Built-in Integration IDs

enum ZhuowangBuiltInIntegrationIDs {

    static let deepSeekConnection = UUID(
        uuidString:
            "30000000-0000-0000-0000-000000000003"
    )!

    static let figmaTool = UUID(
        uuidString:
            "40000000-0000-0000-0000-000000000001"
    )!

    static let htmlPrototypeTool = UUID(
        uuidString:
            "40000000-0000-0000-0000-000000000002"
    )!

    static let deepSeekHTMLRoute = UUID(
        uuidString:
            "50000000-0000-0000-0000-000000000005"
    )!
}


// MARK: - External Tool Kind

enum ZhuowangExternalToolKind:
    String,
    Codable,
    CaseIterable,
    Identifiable {

    case figma
    case htmlPrototype
    case github
    case finder
    case browser
    case custom

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .figma: return "Figma"
        case .htmlPrototype: return "HTML Prototype"
        case .github: return "GitHub"
        case .finder: return "Finder"
        case .browser: return "浏览器"
        case .custom: return "自定义"
        }
    }

    var systemImage: String {
        switch self {
        case .figma: return "square.on.square"
        case .htmlPrototype: return "chevron.left.forwardslash.chevron.right"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .finder: return "folder"
        case .browser: return "globe"
        case .custom: return "puzzlepiece.extension"
        }
    }
}


// MARK: - Tool Integration Status

enum ZhuowangToolIntegrationStatus:
    String,
    Codable,
    CaseIterable,
    Identifiable {

    case available
    case needsSetup
    case unavailable
    case disabled
    case error

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .available: return "可用"
        case .needsSetup: return "需要配置"
        case .unavailable: return "不可用"
        case .disabled: return "已停用"
        case .error: return "异常"
        }
    }
}


// MARK: - Tool Execution Mode

enum ZhuowangToolExecutionMode:
    String,
    Codable,
    CaseIterable,
    Identifiable {

    case direct
    case agentManaged
    case assisted
    case custom

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .direct: return "直接执行"
        case .agentManaged: return "由 AI 连接执行"
        case .assisted: return "辅助执行"
        case .custom: return "自定义"
        }
    }
}


// MARK: - External Tool Integration

struct ZhuowangExternalToolIntegration:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID
    var kind: ZhuowangExternalToolKind
    var name: String
    var status: ZhuowangToolIntegrationStatus
    var mode: ZhuowangAIConnectionMode
    var capabilities: Set<ZhuowangWorkflowCapability>
    var adapterIdentifier: String?
    var endpointOrPath: String?
    var configuration: [String: String]
    var isEnabled: Bool
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: ZhuowangExternalToolKind,
        name: String,
        status: ZhuowangToolIntegrationStatus = .needsSetup,
        mode: ZhuowangAIConnectionMode = .connector,
        capabilities: Set<ZhuowangWorkflowCapability> = [],
        adapterIdentifier: String? = nil,
        endpointOrPath: String? = nil,
        configuration: [String: String] = [:],
        isEnabled: Bool = true,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.status = status
        self.mode = mode
        self.capabilities = capabilities
        self.adapterIdentifier = adapterIdentifier
        self.endpointOrPath = endpointOrPath
        self.configuration = configuration
        self.isEnabled = isEnabled
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }


    // MARK: Backward-Compatible Codable

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case name
        case status
        case mode
        case capabilities
        case adapterIdentifier
        case endpointOrPath
        case configuration
        case isEnabled
        case notes
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

        kind =
            try container.decodeIfPresent(
                ZhuowangExternalToolKind.self,
                forKey: .kind
            )
            ?? .custom

        name =
            try container.decodeIfPresent(
                String.self,
                forKey: .name
            )
            ?? "未命名 Tool Integration"

        status =
            try container.decodeIfPresent(
                ZhuowangToolIntegrationStatus.self,
                forKey: .status
            )
            ?? .needsSetup

        mode =
            try container.decodeIfPresent(
                ZhuowangAIConnectionMode.self,
                forKey: .mode
            )
            ?? .connector

        capabilities =
            try container.decodeIfPresent(
                Set<ZhuowangWorkflowCapability>.self,
                forKey: .capabilities
            )
            ?? (kind == .figma ? [.prototypeDesign] : [])

        adapterIdentifier =
            try container.decodeIfPresent(
                String.self,
                forKey: .adapterIdentifier
            )

        endpointOrPath =
            try container.decodeIfPresent(
                String.self,
                forKey: .endpointOrPath
            )

        configuration =
            try container.decodeIfPresent(
                [String: String].self,
                forKey: .configuration
            )
            ?? [:]

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
}


// MARK: - Agent + Tool Route

struct ZhuowangAgentToolRoute:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID
    var connectionID: UUID
    var toolIntegrationID: UUID
    var status: ZhuowangToolIntegrationStatus
    var executionMode: ZhuowangToolExecutionMode
    var supportsDirectExecution: Bool
    var supportsAutomaticResultReturn: Bool
    var adapterIdentifier: String?
    var configuration: [String: String]
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        connectionID: UUID,
        toolIntegrationID: UUID,
        status: ZhuowangToolIntegrationStatus = .needsSetup,
        executionMode: ZhuowangToolExecutionMode = .agentManaged,
        supportsDirectExecution: Bool = false,
        supportsAutomaticResultReturn: Bool = false,
        adapterIdentifier: String? = nil,
        configuration: [String: String] = [:],
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.connectionID = connectionID
        self.toolIntegrationID = toolIntegrationID
        self.status = status
        self.executionMode = executionMode
        self.supportsDirectExecution = supportsDirectExecution
        self.supportsAutomaticResultReturn = supportsAutomaticResultReturn
        self.adapterIdentifier = adapterIdentifier
        self.configuration = configuration
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }


    // MARK: Backward-Compatible Codable

    private enum CodingKeys: String, CodingKey {
        case id
        case connectionID
        case toolIntegrationID
        case status
        case executionMode
        case supportsDirectExecution
        case supportsAutomaticResultReturn
        case adapterIdentifier
        case configuration
        case notes
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

        connectionID =
            try container.decode(
                UUID.self,
                forKey: .connectionID
            )

        toolIntegrationID =
            try container.decode(
                UUID.self,
                forKey: .toolIntegrationID
            )

        status =
            try container.decodeIfPresent(
                ZhuowangToolIntegrationStatus.self,
                forKey: .status
            )
            ?? .needsSetup

        executionMode =
            try container.decodeIfPresent(
                ZhuowangToolExecutionMode.self,
                forKey: .executionMode
            )
            ?? .agentManaged

        supportsDirectExecution =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .supportsDirectExecution
            )
            ?? false

        supportsAutomaticResultReturn =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .supportsAutomaticResultReturn
            )
            ?? false

        adapterIdentifier =
            try container.decodeIfPresent(
                String.self,
                forKey: .adapterIdentifier
            )

        configuration =
            try container.decodeIfPresent(
                [String: String].self,
                forKey: .configuration
            )
            ?? [:]

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
}


// MARK: - Workflow Execution Preference

enum ZhuowangAISelectionPolicy: String, Codable, CaseIterable, Identifiable {

    /// User chooses everything manually.
    case manual

    /// Cosmos OS recommends,
    /// user confirms before execution.
    case recommendAndConfirm

    /// Cosmos OS may automatically choose
    /// from user-approved providers/connections.
    case automaticWithinRules

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .manual:
            return "手动选择"
        case .recommendAndConfirm:
            return "推荐后确认"
        case .automaticWithinRules:
            return "规则内自动选择"
        }
    }
}


// MARK: - Step Execution Choice

struct ZhuowangStepExecutionChoice:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID

    var workflowStepID: UUID

    /// User-selected provider.
    var providerID: UUID?

    /// User-selected connection under that provider.
    var connectionID: UUID?

    /// Optional exact model or service option.
    ///
    /// Example:
    /// "GPT-5.6 Sol"
    /// "Claude Sonnet"
    /// "DeepSeek Chat"
    var modelOrVariant: String

    var selectionPolicy: ZhuowangAISelectionPolicy

    /// Whether this specific choice has been confirmed
    /// by the user before execution.
    var isUserConfirmed: Bool

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        workflowStepID: UUID,
        providerID: UUID? = nil,
        connectionID: UUID? = nil,
        modelOrVariant: String = "",
        selectionPolicy: ZhuowangAISelectionPolicy = .recommendAndConfirm,
        isUserConfirmed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.workflowStepID = workflowStepID
        self.providerID = providerID
        self.connectionID = connectionID
        self.modelOrVariant = modelOrVariant
        self.selectionPolicy = selectionPolicy
        self.isUserConfirmed = isUserConfirmed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


// MARK: - Task Handoff Package

/// Immutable provider + connection + tool route selected for one execution.
/// It travels with the task and is copied into AI Run / Artifact provenance.
struct ZhuowangWorkflowExecutionSnapshot:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID
    let workflowID: UUID
    let workflowStepID: UUID
    let providerID: UUID
    let connectionID: UUID
    let toolIntegrationID: UUID
    let routeID: UUID
    let capability: ZhuowangWorkflowCapability
    let adapterIdentifier: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        workflowID: UUID,
        workflowStepID: UUID,
        providerID: UUID,
        connectionID: UUID,
        toolIntegrationID: UUID,
        routeID: UUID,
        capability: ZhuowangWorkflowCapability,
        adapterIdentifier: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.workflowID = workflowID
        self.workflowStepID = workflowStepID
        self.providerID = providerID
        self.connectionID = connectionID
        self.toolIntegrationID = toolIntegrationID
        self.routeID = routeID
        self.capability = capability
        self.adapterIdentifier = adapterIdentifier
        self.createdAt = createdAt
    }
}


// MARK: - Task Handoff Package

struct ZhuowangAITaskPackage:
    Identifiable,
    Codable,
    Hashable {

    let id: UUID

    var campaignID: UUID
    var workflowStepID: UUID

    /// Nil for historical and non-tool task packages.
    var executionSnapshot: ZhuowangWorkflowExecutionSnapshot?

    /// Human-readable task title.
    var title: String

    /// The actual instruction sent or copied to the AI.
    var instruction: String

    /// Context references.
    ///
    /// Example:
    /// 卓望.md
    /// 当前 Campaign Brief
    /// 已确认策划思路
    var contextReferences: [String]

    /// Expected deliverables.
    ///
    /// Example:
    /// 策划案 Markdown
    /// Figma 页面结构
    /// 客服 FAQ
    var expectedOutputs: [String]

    /// Where the result should eventually be stored.
    var destinationHint: String

    var createdAt: Date

    init(
        id: UUID = UUID(),
        campaignID: UUID,
        workflowStepID: UUID,
        executionSnapshot: ZhuowangWorkflowExecutionSnapshot? = nil,
        title: String,
        instruction: String,
        contextReferences: [String] = [],
        expectedOutputs: [String] = [],
        destinationHint: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.campaignID = campaignID
        self.workflowStepID = workflowStepID
        self.executionSnapshot = executionSnapshot
        self.title = title
        self.instruction = instruction
        self.contextReferences = contextReferences
        self.expectedOutputs = expectedOutputs
        self.destinationHint = destinationHint
        self.createdAt = createdAt
    }
}
