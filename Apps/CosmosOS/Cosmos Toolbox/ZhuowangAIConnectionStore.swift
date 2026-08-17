import Foundation
import Combine

final class ZhuowangAIConnectionStore: ObservableObject {

    // MARK: - Data

    @Published
    private(set) var connections: [ZhuowangAIConnection] = []


    // MARK: - Storage

    private let storageKey =
        "cosmos.zhuowang.ai.connections.v1"


    // MARK: - Init

    init() {

        load()

        if connections.isEmpty {

            connections =
                Self.defaultConnections

            save()
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

        guard
            let data =
                try? JSONEncoder()
                .encode(connections)
        else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: storageKey
        )
    }


    private func load() {

        guard
            let data =
                UserDefaults.standard
                .data(
                    forKey: storageKey
                ),
            let savedConnections =
                try? JSONDecoder()
                .decode(
                    [ZhuowangAIConnection].self,
                    from: data
                )
        else {
            connections = []
            return
        }

        connections =
            savedConnections
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
}
