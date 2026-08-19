import Foundation
import Combine

private enum ZhuowangConnectionPersistenceLoadState: Equatable {
    case missing
    case loaded
    case recoveredFromBackup
    case locked
}


final class ZhuowangAIConnectionStore: ObservableObject {

    // MARK: - Data

    @Published
    private(set) var connections: [ZhuowangAIConnection] = []

    @Published
    private(set) var toolIntegrations: [ZhuowangExternalToolIntegration] = []

    @Published
    private(set) var agentToolRoutes: [ZhuowangAgentToolRoute] = []


    // MARK: - Storage

    private let storageKey =
        "cosmos.zhuowang.ai.connections.v1"

    private let toolIntegrationsStorageKey =
        "cosmos.zhuowang.ai.toolIntegrations.v1"

    private let agentToolRoutesStorageKey =
        "cosmos.zhuowang.ai.agentToolRoutes.v1"

    private let backupStorageKey =
        "cosmos.zhuowang.ai.connections.v1.backup"

    private let toolIntegrationsBackupStorageKey =
        "cosmos.zhuowang.ai.toolIntegrations.v1.backup"

    private let agentToolRoutesBackupStorageKey =
        "cosmos.zhuowang.ai.agentToolRoutes.v1.backup"

    private var connectionLoadState:
        ZhuowangConnectionPersistenceLoadState = .missing

    private var toolIntegrationLoadState:
        ZhuowangConnectionPersistenceLoadState = .missing

    private var agentToolRouteLoadState:
        ZhuowangConnectionPersistenceLoadState = .missing

    private var connectionPersistenceLocked = false
    private var toolIntegrationPersistenceLocked = false
    private var agentToolRoutePersistenceLocked = false

    private var skipNextConnectionBackup = false
    private var skipNextToolIntegrationBackup = false
    private var skipNextAgentToolRouteBackup = false


    // MARK: - Init

    init() {

        load()
        loadToolIntegrations()
        loadAgentToolRoutes()

        if connectionLoadState == .missing {

            connections =
                Self.defaultConnections

            save()
        }

        if toolIntegrationLoadState == .missing {

            toolIntegrations =
                Self.defaultToolIntegrations

            saveToolIntegrations()
        }

        if agentToolRouteLoadState == .missing {

            agentToolRoutes =
                Self.defaultAgentToolRoutes

            saveAgentToolRoutes()
        }
    }


    // MARK: - Access

    func connection(
        id: UUID
    ) -> ZhuowangAIConnection? {

        connections.first {
            $0.id == id
        }
    }


    func connections(
        forProviderID providerID: UUID
    ) -> [ZhuowangAIConnection] {

        connections
            .filter {
                $0.providerID == providerID
                && $0.isEnabled
            }
            .sorted {
                $0.createdAt < $1.createdAt
            }
    }


    func availableConnections(
        forProviderID providerID: UUID
    ) -> [ZhuowangAIConnection] {

        connections(
            forProviderID: providerID
        )
        .filter {

            $0.status == .available
            || $0.status == .needsLogin
            || $0.status == .needsSetup
        }
    }


    // MARK: - Recommended Connection

    func recommendedConnection(
        forProviderID providerID: UUID
    ) -> ZhuowangAIConnection? {

        let providerConnections =
            connections(
                forProviderID: providerID
            )

        if let directAvailable =
            providerConnections.first(
                where: {
                    $0.status == .available
                    && $0.supportsDirectExecution
                    && $0.allowsAutomaticSelection
                }
            ) {

            return directAvailable
        }

        if let available =
            providerConnections.first(
                where: {
                    $0.status == .available
                    && $0.allowsAutomaticSelection
                }
            ) {

            return available
        }

        return providerConnections.first
    }


    // MARK: - External Tools

    func toolIntegration(
        id: UUID
    ) -> ZhuowangExternalToolIntegration? {

        toolIntegrations.first {
            $0.id == id
        }
    }


    func toolIntegration(
        kind: ZhuowangExternalToolKind
    ) -> ZhuowangExternalToolIntegration? {

        toolIntegrations.first {
            $0.kind == kind
            && $0.isEnabled
        }
    }


    func enabledToolIntegrations()
        -> [ZhuowangExternalToolIntegration] {

        toolIntegrations
            .filter {
                $0.isEnabled
            }
            .sorted {
                $0.createdAt < $1.createdAt
            }
    }


    func updateToolIntegration(
        _ integration:
            ZhuowangExternalToolIntegration
    ) {

        guard
            let index =
                toolIntegrations.firstIndex(
                    where: {
                        $0.id == integration.id
                    }
                )
        else {
            return
        }

        var updated =
            integration

        updated.updatedAt =
            Date()

        toolIntegrations[index] =
            updated

        saveToolIntegrations()
    }


    // MARK: - Capability + Tool Matching

    /// 根据 Workflow 所需能力寻找可用工具。
    /// Workflow 不直接绑定具体产品，而是通过能力匹配工具。
    func availableTools(
        for capability: ZhuowangWorkflowCapability
    ) -> [ZhuowangExternalToolIntegration] {

        enabledToolIntegrations()
            .filter { tool in

                switch capability {

                case .prototypeDesign:
                    return tool.kind == .figma

                default:
                    return false
                }
            }
    }


    /// 判断某个 Agent 是否可以使用某个工具。
    func canAgentUseTool(
        connectionID: UUID,
        toolIntegrationID: UUID
    ) -> Bool {

        guard
            let route =
                route(
                    connectionID: connectionID,
                    toolIntegrationID: toolIntegrationID
                )
        else {
            return false
        }

        return route.status != .disabled
    }


    // MARK: - Agent + Tool Routes

    func routes(
        forConnectionID connectionID: UUID
    ) -> [ZhuowangAgentToolRoute] {

        agentToolRoutes
            .filter {
                $0.connectionID == connectionID
            }
            .sorted {
                $0.createdAt < $1.createdAt
            }
    }


    func routes(
        forToolIntegrationID toolIntegrationID: UUID
    ) -> [ZhuowangAgentToolRoute] {

        agentToolRoutes
            .filter {
                $0.toolIntegrationID
                    == toolIntegrationID
            }
            .sorted {
                $0.createdAt < $1.createdAt
            }
    }


    func route(
        connectionID: UUID,
        toolIntegrationID: UUID
    ) -> ZhuowangAgentToolRoute? {

        agentToolRoutes.first {
            $0.connectionID == connectionID
            && $0.toolIntegrationID
                == toolIntegrationID
        }
    }


    func route(
        providerID: UUID,
        toolKind: ZhuowangExternalToolKind
    ) -> ZhuowangAgentToolRoute? {

        guard
            let tool =
                toolIntegration(
                    kind: toolKind
                )
        else {
            return nil
        }

        let providerConnectionIDs =
            Set(
                connections(
                    forProviderID:
                        providerID
                )
                .map(\.id)
            )

        return agentToolRoutes.first {
            providerConnectionIDs
                .contains(
                    $0.connectionID
                )
            && $0.toolIntegrationID
                == tool.id
        }
    }


    func updateAgentToolRoute(
        _ route:
            ZhuowangAgentToolRoute
    ) {

        guard
            let index =
                agentToolRoutes.firstIndex(
                    where: {
                        $0.id == route.id
                    }
                )
        else {
            return
        }

        var updated =
            route

        updated.updatedAt =
            Date()

        agentToolRoutes[index] =
            updated

        saveAgentToolRoutes()
    }


    // MARK: - Add Connection

    func addConnection(
        providerID: UUID,
        name: String,
        mode: ZhuowangAIConnectionMode,
        executionStyle: ZhuowangAIExecutionStyle,
        capabilities: Set<ZhuowangAICapability> = [],
        adapterIdentifier: String? = nil,
        endpointOrPath: String? = nil,
        notes: String = ""
    ) {

        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty else {
            return
        }

        let connection =
            ZhuowangAIConnection(
                providerID: providerID,
                name: cleanName,
                mode: mode,
                status: .needsSetup,
                executionStyle: executionStyle,
                capabilities: capabilities,
                allowsAutomaticSelection: true,
                supportsDirectExecution: false,
                supportsAutomaticResultReturn: false,
                adapterIdentifier:
                    adapterIdentifier,
                endpointOrPath:
                    endpointOrPath,
                configuration: [:],
                isEnabled: true,
                notes: notes
            )

        connections.append(
            connection
        )

        save()
    }


    // MARK: - Update Connection

    func updateConnection(
        _ connection: ZhuowangAIConnection
    ) {

        guard
            let index =
                connections.firstIndex(
                    where: {
                        $0.id == connection.id
                    }
                )
        else {
            return
        }

        var updatedConnection =
            connection

        updatedConnection.updatedAt =
            Date()

        connections[index] =
            updatedConnection

        save()
    }


    // MARK: - Delete Connection

    func deleteConnection(
        id: UUID
    ) {

        connections.removeAll {
            $0.id == id
        }

        save()
    }


    // MARK: - Enable / Disable

    func setConnectionEnabled(
        id: UUID,
        isEnabled: Bool
    ) {

        guard
            let index =
                connections.firstIndex(
                    where: {
                        $0.id == id
                    }
                )
        else {
            return
        }

        connections[index]
            .isEnabled =
            isEnabled

        connections[index]
            .updatedAt =
            Date()

        save()
    }


    // MARK: - Update Status

    func setConnectionStatus(
        id: UUID,
        status: ZhuowangAIConnectionStatus
    ) {

        guard
            let index =
                connections.firstIndex(
                    where: {
                        $0.id == id
                    }
                )
        else {
            return
        }

        connections[index]
            .status =
            status

        connections[index]
            .updatedAt =
            Date()

        save()
    }


    // MARK: - Persistence

    private func save() {

        guard !connectionPersistenceLocked else {
            print(
                "[Cosmos OS] AI Connection persistence is locked because existing data could not be decoded. Save skipped to protect user data."
            )
            return
        }

        guard
            let data =
                try? JSONEncoder()
                .encode(connections)
        else {
            return
        }

        let defaults = UserDefaults.standard

        if skipNextConnectionBackup {
            skipNextConnectionBackup = false

        } else if let currentData =
            defaults.data(
                forKey: storageKey
            ) {

            if canDecodeConnections(
                currentData
            ) {
                defaults.set(
                    currentData,
                    forKey: backupStorageKey
                )
            } else {
                print(
                    "[Cosmos OS] Existing AI Connection payload is unreadable. Previous backup was preserved."
                )
            }
        }

        defaults.set(
            data,
            forKey: storageKey
        )
    }


    private func load() {

        let defaults = UserDefaults.standard

        guard let data =
            defaults.data(
                forKey: storageKey
            )
        else {
            connections = []
            connectionPersistenceLocked = false
            connectionLoadState = .missing
            return
        }

        do {
            connections =
                try JSONDecoder()
                .decode(
                    [ZhuowangAIConnection].self,
                    from: data
                )

            connectionPersistenceLocked = false
            connectionLoadState = .loaded

        } catch {

            if let backupData =
                defaults.data(
                    forKey: backupStorageKey
                ),
               let backupConnections =
                try? JSONDecoder()
                .decode(
                    [ZhuowangAIConnection].self,
                    from: backupData
                ) {

                connections = backupConnections
                connectionPersistenceLocked = false
                connectionLoadState = .recoveredFromBackup
                skipNextConnectionBackup = true

                print(
                    "[Cosmos OS] AI Connection payload could not be decoded. Recovered from backup: \(error.localizedDescription)"
                )
                return
            }

            connections = []
            connectionPersistenceLocked = true
            connectionLoadState = .locked

            print(
                "[Cosmos OS] AI Connection decode failed. Existing payload and previous backup were protected from overwrite: \(error.localizedDescription)"
            )
        }
    }


    // MARK: - Tool Persistence

    private func saveToolIntegrations() {

        guard !toolIntegrationPersistenceLocked else {
            print(
                "[Cosmos OS] Tool Integration persistence is locked because existing data could not be decoded. Save skipped to protect user data."
            )
            return
        }

        guard
            let data =
                try? JSONEncoder()
                    .encode(
                        toolIntegrations
                    )
        else {
            return
        }

        let defaults = UserDefaults.standard

        if skipNextToolIntegrationBackup {
            skipNextToolIntegrationBackup = false

        } else if let currentData =
            defaults.data(
                forKey: toolIntegrationsStorageKey
            ) {

            if canDecodeToolIntegrations(
                currentData
            ) {
                defaults.set(
                    currentData,
                    forKey:
                        toolIntegrationsBackupStorageKey
                )
            } else {
                print(
                    "[Cosmos OS] Existing Tool Integration payload is unreadable. Previous backup was preserved."
                )
            }
        }

        defaults.set(
            data,
            forKey:
                toolIntegrationsStorageKey
        )
    }


    private func loadToolIntegrations() {

        let defaults = UserDefaults.standard

        guard let data =
            defaults.data(
                forKey:
                    toolIntegrationsStorageKey
            )
        else {

            toolIntegrations = []
            toolIntegrationPersistenceLocked = false
            toolIntegrationLoadState = .missing
            return
        }

        do {
            toolIntegrations =
                try JSONDecoder()
                .decode(
                    [ZhuowangExternalToolIntegration].self,
                    from: data
                )

            toolIntegrationPersistenceLocked = false
            toolIntegrationLoadState = .loaded

        } catch {

            if let backupData =
                defaults.data(
                    forKey:
                        toolIntegrationsBackupStorageKey
                ),
               let backupIntegrations =
                try? JSONDecoder()
                .decode(
                    [ZhuowangExternalToolIntegration].self,
                    from: backupData
                ) {

                toolIntegrations = backupIntegrations
                toolIntegrationPersistenceLocked = false
                toolIntegrationLoadState = .recoveredFromBackup
                skipNextToolIntegrationBackup = true

                print(
                    "[Cosmos OS] Tool Integration payload could not be decoded. Recovered from backup: \(error.localizedDescription)"
                )
                return
            }

            toolIntegrations = []
            toolIntegrationPersistenceLocked = true
            toolIntegrationLoadState = .locked

            print(
                "[Cosmos OS] Tool Integration decode failed. Existing payload and previous backup were protected from overwrite: \(error.localizedDescription)"
            )
        }
    }


    private func saveAgentToolRoutes() {

        guard !agentToolRoutePersistenceLocked else {
            print(
                "[Cosmos OS] Agent/Tool Route persistence is locked because existing data could not be decoded. Save skipped to protect user data."
            )
            return
        }

        guard
            let data =
                try? JSONEncoder()
                    .encode(
                        agentToolRoutes
                    )
        else {
            return
        }

        let defaults = UserDefaults.standard

        if skipNextAgentToolRouteBackup {
            skipNextAgentToolRouteBackup = false

        } else if let currentData =
            defaults.data(
                forKey: agentToolRoutesStorageKey
            ) {

            if canDecodeAgentToolRoutes(
                currentData
            ) {
                defaults.set(
                    currentData,
                    forKey:
                        agentToolRoutesBackupStorageKey
                )
            } else {
                print(
                    "[Cosmos OS] Existing Agent/Tool Route payload is unreadable. Previous backup was preserved."
                )
            }
        }

        defaults.set(
            data,
            forKey:
                agentToolRoutesStorageKey
        )
    }


    private func loadAgentToolRoutes() {

        let defaults = UserDefaults.standard

        guard let data =
            defaults.data(
                forKey:
                    agentToolRoutesStorageKey
            )
        else {

            agentToolRoutes = []
            agentToolRoutePersistenceLocked = false
            agentToolRouteLoadState = .missing
            return
        }

        do {
            agentToolRoutes =
                try JSONDecoder()
                .decode(
                    [ZhuowangAgentToolRoute].self,
                    from: data
                )

            agentToolRoutePersistenceLocked = false
            agentToolRouteLoadState = .loaded

        } catch {

            if let backupData =
                defaults.data(
                    forKey:
                        agentToolRoutesBackupStorageKey
                ),
               let backupRoutes =
                try? JSONDecoder()
                .decode(
                    [ZhuowangAgentToolRoute].self,
                    from: backupData
                ) {

                agentToolRoutes = backupRoutes
                agentToolRoutePersistenceLocked = false
                agentToolRouteLoadState = .recoveredFromBackup
                skipNextAgentToolRouteBackup = true

                print(
                    "[Cosmos OS] Agent/Tool Route payload could not be decoded. Recovered from backup: \(error.localizedDescription)"
                )
                return
            }

            agentToolRoutes = []
            agentToolRoutePersistenceLocked = true
            agentToolRouteLoadState = .locked

            print(
                "[Cosmos OS] Agent/Tool Route decode failed. Existing payload and previous backup were protected from overwrite: \(error.localizedDescription)"
            )
        }
    }


    // MARK: - Backup Validation

    private func canDecodeConnections(
        _ data: Data
    ) -> Bool {

        (try? JSONDecoder().decode(
            [ZhuowangAIConnection].self,
            from: data
        )) != nil
    }


    private func canDecodeToolIntegrations(
        _ data: Data
    ) -> Bool {

        (try? JSONDecoder().decode(
            [ZhuowangExternalToolIntegration].self,
            from: data
        )) != nil
    }


    private func canDecodeAgentToolRoutes(
        _ data: Data
    ) -> Bool {

        (try? JSONDecoder().decode(
            [ZhuowangAgentToolRoute].self,
            from: data
        )) != nil
    }


    // MARK: - Default Provider IDs

    private static let openAIProviderID =
        UUID(
            uuidString:
                "20000000-0000-0000-0000-000000000001"
        )!

    private static let codexProviderID =
        UUID(
            uuidString:
                "20000000-0000-0000-0000-000000000002"
        )!

    private static let deepSeekProviderID =
        UUID(
            uuidString:
                "20000000-0000-0000-0000-000000000003"
        )!

    private static let claudeProviderID =
        UUID(
            uuidString:
                "20000000-0000-0000-0000-000000000004"
        )!

    private static let figmaProviderID =
        UUID(
            uuidString:
                "20000000-0000-0000-0000-000000000005"
        )!


    // MARK: - Default Connection / Tool IDs

    private static let chatGPTConnectionID =
        UUID(
            uuidString:
                "30000000-0000-0000-0000-000000000001"
        )!

    private static let codexConnectionID =
        UUID(
            uuidString:
                "30000000-0000-0000-0000-000000000002"
        )!

    private static let deepSeekConnectionID =
        UUID(
            uuidString:
                "30000000-0000-0000-0000-000000000003"
        )!

    private static let claudeWorkConnectionID =
        UUID(
            uuidString:
                "30000000-0000-0000-0000-000000000004"
        )!

    private static let figmaToolIntegrationID =
        UUID(
            uuidString:
                "40000000-0000-0000-0000-000000000001"
        )!


    // MARK: - Default Connections

    private static let defaultConnections: [
        ZhuowangAIConnection
    ] = [

        // ChatGPT Subscription

        ZhuowangAIConnection(
            id: UUID(
                uuidString:
                    "30000000-0000-0000-0000-000000000001"
            )!,
            providerID:
                openAIProviderID,
            name:
                "ChatGPT Subscription",
            mode:
                .subscriptionApp,
            status:
                .available,
            executionStyle:
                .assistedManual,
            capabilities: [
                .planning,
                .writing,
                .research,
                .analysis,
                .documentGeneration,
                .imageGeneration,
                .toolCalling
            ],
            allowsAutomaticSelection:
                true,
            supportsDirectExecution:
                false,
            supportsAutomaticResultReturn:
                false,
            adapterIdentifier:
                "chatgpt-subscription",
            endpointOrPath:
                nil,
            configuration: [
                "preferredEntry":
                    "web-or-desktop"
            ],
            isEnabled:
                true,
            notes:
                "使用 ChatGPT 订阅账号。Cosmos OS 负责准备任务包，再通过网页或桌面端完成执行。"
        ),


        // Codex Subscription

        ZhuowangAIConnection(
            id: UUID(
                uuidString:
                    "30000000-0000-0000-0000-000000000002"
            )!,
            providerID:
                codexProviderID,
            name:
                "Codex · ChatGPT Subscription",
            mode:
                .localAgent,
            status:
                .available,
            executionStyle:
                .localProcess,
            capabilities: [
                .coding,
                .localFileAccess,
                .documentGeneration,
                .spreadsheet,
                .automation,
                .toolCalling,
                .mcpAccess
            ],
            allowsAutomaticSelection:
                true,
            supportsDirectExecution:
                false,
            supportsAutomaticResultReturn:
                false,
            adapterIdentifier:
                "codex-local-subscription",
            endpointOrPath:
                nil,
            configuration: [
                "authMode":
                    "chatgpt-subscription"
            ],
            isEnabled:
                true,
            notes:
                "通过 ChatGPT 订阅使用 Codex。本地任务、代码、文件和自动化优先使用该连接。"
        ),


        // DeepSeek Harness

        ZhuowangAIConnection(
            id: UUID(
                uuidString:
                    "30000000-0000-0000-0000-000000000003"
            )!,
            providerID:
                deepSeekProviderID,
            name:
                "DeepSeek Harness",
            mode:
                .localAgent,
            status:
                .available,
            executionStyle:
                .localProcess,
            capabilities: [
                .planning,
                .writing,
                .analysis,
                .coding,
                .localFileAccess,
                .documentGeneration,
                .spreadsheet,
                .automation,
                .toolCalling
            ],
            allowsAutomaticSelection:
                true,
            supportsDirectExecution:
                true,
            supportsAutomaticResultReturn:
                false,
            adapterIdentifier:
                "deepseek-harness",
            endpointOrPath:
                nil,
            configuration: [
                "modelAccess":
                    "api",
                "runtime":
                    "local-harness"
            ],
            isEnabled:
                true,
            notes:
                "DeepSeek API 由本地 DeepSeek Harness 使用。后续作为 Cosmos OS 第一条真正自动执行链路。"
        ),


        // Claude Work

        ZhuowangAIConnection(
            id: UUID(
                uuidString:
                    "30000000-0000-0000-0000-000000000004"
            )!,
            providerID:
                claudeProviderID,
            name:
                "Claude Work",
            mode:
                .desktopApp,
            status:
                .needsLogin,
            executionStyle:
                .assistedManual,
            capabilities: [
                .planning,
                .writing,
                .research,
                .analysis,
                .documentGeneration,
                .toolCalling,
                .mcpAccess
            ],
            allowsAutomaticSelection:
                true,
            supportsDirectExecution:
                false,
            supportsAutomaticResultReturn:
                false,
            adapterIdentifier:
                "claude-work-desktop",
            endpointOrPath:
                nil,
            configuration: [
                "authMode":
                    "claude-subscription",
                "surface":
                    "work"
            ],
            isEnabled:
                true,
            notes:
                "Claude Desktop 内的 Work 工作模式。使用 Claude 订阅，不使用 Anthropic API。"
        ),


        // Claude Code

        ZhuowangAIConnection(
            id: UUID(
                uuidString:
                    "30000000-0000-0000-0000-000000000005"
            )!,
            providerID:
                claudeProviderID,
            name:
                "Claude Code",
            mode:
                .localAgent,
            status:
                .needsLogin,
            executionStyle:
                .localProcess,
            capabilities: [
                .coding,
                .localFileAccess,
                .documentGeneration,
                .automation,
                .toolCalling,
                .mcpAccess
            ],
            allowsAutomaticSelection:
                true,
            supportsDirectExecution:
                false,
            supportsAutomaticResultReturn:
                false,
            adapterIdentifier:
                "claude-code-desktop",
            endpointOrPath:
                nil,
            configuration: [
                "authMode":
                    "claude-subscription",
                "surface":
                    "code"
            ],
            isEnabled:
                true,
            notes:
                "Claude Desktop 内集成的 Claude Code。使用 Claude 订阅，不使用 Anthropic API。"
        ),


        // Figma

        ZhuowangAIConnection(
            id: UUID(
                uuidString:
                    "30000000-0000-0000-0000-000000000006"
            )!,
            providerID:
                figmaProviderID,
            name:
                "Figma Integration",
            mode:
                .connector,
            status:
                .needsSetup,
            executionStyle:
                .externalTool,
            capabilities: [
                .prototypeDesign,
                .figmaEditing,
                .automation,
                .toolCalling
            ],
            allowsAutomaticSelection:
                true,
            supportsDirectExecution:
                false,
            supportsAutomaticResultReturn:
                false,
            adapterIdentifier:
                "figma-integration",
            endpointOrPath:
                nil,
            configuration: [:],
            isEnabled:
                true,
            notes:
                "后续根据实际能力接入 Figma Connector、MCP 或 Plugin。"
        )
    ]

    // MARK: - Default Tool Integrations

    private static let defaultToolIntegrations: [
        ZhuowangExternalToolIntegration
    ] = [

        ZhuowangExternalToolIntegration(
            id:
                figmaToolIntegrationID,
            kind:
                .figma,
            name:
                "Figma",
            status:
                .needsSetup,
            mode:
                .connector,
            adapterIdentifier:
                "figma",
            endpointOrPath:
                nil,
            configuration: [
                "artifactType":
                    "figma",
                "resultType":
                    "figma-url"
            ],
            isEnabled:
                true,
            notes:
                "Figma 是外部设计工具，不再作为固定 AI 执行器。由 ChatGPT、Codex、Claude、DeepSeek Harness 等 Agent 通过各自可用的 Connector / MCP / Plugin 路径调用。"
        )
    ]


    // MARK: - Default Agent + Tool Routes

    private static let defaultAgentToolRoutes: [
        ZhuowangAgentToolRoute
    ] = [

        ZhuowangAgentToolRoute(
            id:
                UUID(
                    uuidString:
                        "50000000-0000-0000-0000-000000000001"
                )!,
            connectionID:
                chatGPTConnectionID,
            toolIntegrationID:
                figmaToolIntegrationID,
            status:
                .needsSetup,
            executionMode:
                .agentManaged,
            supportsDirectExecution:
                false,
            supportsAutomaticResultReturn:
                false,
            adapterIdentifier:
                "chatgpt-figma",
            configuration: [
                "preferredPath":
                    "figma-connector"
            ],
            notes:
                "目标：ChatGPT 作为执行 Agent，通过其可用的 Figma 连接能力创建或修改真实可编辑 Figma 原型。具体自动编排方式在接入阶段验证。"
        ),

        ZhuowangAgentToolRoute(
            id:
                UUID(
                    uuidString:
                        "50000000-0000-0000-0000-000000000002"
                )!,
            connectionID:
                codexConnectionID,
            toolIntegrationID:
                figmaToolIntegrationID,
            status:
                .needsSetup,
            executionMode:
                .agentManaged,
            supportsDirectExecution:
                false,
            supportsAutomaticResultReturn:
                false,
            adapterIdentifier:
                "codex-figma",
            configuration: [
                "preferredPath":
                    "figma-mcp-or-plugin"
            ],
            notes:
                "目标：Codex 作为执行 Agent，通过 Figma MCP / Plugin 创建或修改真实可编辑原型。"
        ),

        ZhuowangAgentToolRoute(
            id:
                UUID(
                    uuidString:
                        "50000000-0000-0000-0000-000000000003"
                )!,
            connectionID:
                claudeWorkConnectionID,
            toolIntegrationID:
                figmaToolIntegrationID,
            status:
                .needsSetup,
            executionMode:
                .agentManaged,
            supportsDirectExecution:
                false,
            supportsAutomaticResultReturn:
                false,
            adapterIdentifier:
                "claude-work-figma",
            configuration: [
                "preferredPath":
                    "figma-connector"
            ],
            notes:
                "目标：Claude Desktop / Work 作为执行 Agent，通过其 Figma Connector 创建或修改真实可编辑原型。"
        ),

        ZhuowangAgentToolRoute(
            id:
                UUID(
                    uuidString:
                        "50000000-0000-0000-0000-000000000004"
                )!,
            connectionID:
                deepSeekConnectionID,
            toolIntegrationID:
                figmaToolIntegrationID,
            status:
                .needsSetup,
            executionMode:
                .agentManaged,
            supportsDirectExecution:
                false,
            supportsAutomaticResultReturn:
                false,
            adapterIdentifier:
                "deepseek-harness-figma",
            configuration: [
                "preferredPath":
                    "mcp-or-plugin-to-be-verified"
            ],
            notes:
                "目标：DeepSeek Harness 作为执行 Agent 调用 Figma。当前先注册正式 Route，实际 MCP / Plugin 路径仍需后续验证，不在模型层写死。"
        )
    ]

}
