import Foundation

// MARK: - AI Execution Adapter

protocol ZhuowangAIExecutionAdapter {

    var connectionID: UUID { get }

    func execute(
        taskPackage: ZhuowangAITaskPackage
    ) async throws -> String
}


struct ZhuowangDeepSeekExecutionAdapter:
    ZhuowangAIExecutionAdapter {

    let connectionID =
        ZhuowangBuiltInIntegrationIDs.deepSeekConnection

    func execute(
        taskPackage: ZhuowangAITaskPackage
    ) async throws -> String {

        let result = try await DeepSeekHarnessAdapter
            .shared
            .execute(taskPackage: taskPackage)

        return result.output
    }
}


struct ZhuowangAIExecutionAdapterRegistry {

    private let adapters: [any ZhuowangAIExecutionAdapter]

    init(
        adapters: [any ZhuowangAIExecutionAdapter] = [
            ZhuowangDeepSeekExecutionAdapter()
        ]
    ) {
        self.adapters = adapters
    }

    func find(
        connectionID: UUID
    ) -> (any ZhuowangAIExecutionAdapter)? {

        adapters.first {
            $0.connectionID == connectionID
        }
    }
}


// MARK: - Coordinator Result

struct ZhuowangWorkflowExecutionResult {

    let snapshot: ZhuowangWorkflowExecutionSnapshot
    let rawAIResult: String
    let artifactDraft: ZhuowangArtifactDraft
}


// MARK: - Workflow Execution Coordinator

struct ZhuowangWorkflowExecutionCoordinator {

    private let aiRegistry: ZhuowangAIExecutionAdapterRegistry
    private let toolRegistry: ZhuowangToolAdapterRegistry

    init(
        aiRegistry: ZhuowangAIExecutionAdapterRegistry = .init(),
        toolRegistry: ZhuowangToolAdapterRegistry = .init()
    ) {
        self.aiRegistry = aiRegistry
        self.toolRegistry = toolRegistry
    }

    func execute(
        taskPackage: ZhuowangAITaskPackage
    ) async throws -> ZhuowangWorkflowExecutionResult {

        guard let snapshot = taskPackage.executionSnapshot else {
            throw ZhuowangWorkflowExecutionCoordinatorError
                .missingExecutionSnapshot
        }

        guard let aiAdapter = aiRegistry.find(
            connectionID: snapshot.connectionID
        ) else {
            throw ZhuowangWorkflowExecutionCoordinatorError
                .missingAIAdapter
        }

        guard let toolAdapter = toolRegistry.find(
            toolID: snapshot.toolIntegrationID
        ) else {
            throw ZhuowangWorkflowExecutionCoordinatorError
                .missingToolAdapter
        }

        guard toolAdapter.supports(
            capability: snapshot.capability
        ) else {
            throw ZhuowangWorkflowExecutionCoordinatorError
                .unsupportedCapability
        }

        let rawAIResult = try await aiAdapter.execute(
            taskPackage: taskPackage
        )

        let artifactDraft = try await toolAdapter.execute(
            taskPackage: taskPackage,
            rawAIResult: rawAIResult
        )

        return ZhuowangWorkflowExecutionResult(
            snapshot: snapshot,
            rawAIResult: rawAIResult,
            artifactDraft: artifactDraft
        )
    }
}


enum ZhuowangWorkflowExecutionCoordinatorError:
    LocalizedError {

    case missingExecutionSnapshot
    case missingAIAdapter
    case missingToolAdapter
    case unsupportedCapability

    var errorDescription: String? {
        switch self {
        case .missingExecutionSnapshot:
            return "任务缺少不可变执行快照，已阻止执行。"
        case .missingAIAdapter:
            return "当前 AI Connection 尚未注册自动执行 Adapter。"
        case .missingToolAdapter:
            return "当前 Tool 尚未注册执行 Adapter。"
        case .unsupportedCapability:
            return "当前 Tool 不支持该 Workflow capability。"
        }
    }
}
