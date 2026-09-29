import Foundation


struct ZhuowangStep06ProviderSession {
    private enum Choice {
        case provider(UUID)
        case cleared
    }

    private var choices: [UUID: Choice] = [:]

    mutating func select(_ providerID: UUID?, for stepID: UUID) {
        choices[stepID] = providerID.map(Choice.provider) ?? .cleared
    }

    func providerID(for step: ZhuowangWorkflowStep) -> UUID? {
        guard let choice = choices[step.id] else {
            return step.selectedProviderID
        }
        switch choice {
        case .provider(let id): return id
        case .cleared: return nil
        }
    }
}


// MARK: - Customer Service Artifact

enum ZhuowangCustomerServiceArtifact {

    static let logicalKey =
        "workflow.customerService.primary"

    static let name = "客服文档"

    static func makeDraft(
        taskPackage: ZhuowangAITaskPackage,
        outputText: String
    ) -> ZhuowangArtifactDraft? {
        guard
            taskPackage.workflowStepKind == .customerService,
            !outputText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        else {
            return nil
        }

        return ZhuowangArtifactDraft(
            logicalKey: logicalKey,
            name: name,
            type: .markdown,
            content: outputText,
            preferredFileExtension: "md"
        )
    }
}


// MARK: - Adoption Result

enum ZhuowangCustomerServiceAdoptionFailure:
    Equatable {

    case invalidInput
    case workflowNotFound
    case stepNotFound
    case wrongStepKind
    case stepNotReady
    case unsupportedProvider
    case persistenceUnavailable
    case fileWriteFailed(String)
    case lockedCorruptPrimary(hasValidBackup: Bool)
    case staleConflict
    case writeVerificationFailed

    var userMessage: String {
        switch self {
        case .invalidInput:
            return "客服文档内容为空，未保存任何修改。"
        case .workflowNotFound:
            return "当前 Workflow 已不存在，未保存任何修改。"
        case .stepNotFound:
            return "客服文档步骤已不存在，未保存任何修改。"
        case .wrongStepKind:
            return "当前操作不属于客服文档步骤，未保存任何修改。"
        case .stepNotReady:
            return "客服文档步骤尚未就绪，未保存任何修改。"
        case .unsupportedProvider:
            return "Phase 1 仅支持采用 DeepSeek Harness 生成的客服文档。"
        case .persistenceUnavailable:
            return "Workflow 持久化尚未就绪，未保存任何修改。"
        case .fileWriteFailed(let message):
            return "客服文档文件写入失败，Workflow 状态未改变。\n\(message)"
        case .lockedCorruptPrimary(let hasValidBackup):
            return ZhuowangStorePersistenceState
                .lockedCorruptPrimary(
                    hasValidBackup: hasValidBackup
                )
                .userMessage
                ?? "Workflow 数据已锁定，未保存任何修改。"
        case .staleConflict:
            return ZhuowangStorePersistenceState
                .staleConflict
                .userMessage
                ?? "检测到数据冲突，未保存任何修改。"
        case .writeVerificationFailed:
            return ZhuowangStorePersistenceState
                .writeVerificationFailed
                .userMessage
                ?? "Workflow 保存校验失败，未发布本次修改。"
        }
    }
}


enum ZhuowangCustomerServiceAdoptionResult:
    Equatable {

    case succeeded(
        artifactID: UUID,
        version: Int,
        reusedExisting: Bool
    )

    case rejected(
        ZhuowangCustomerServiceAdoptionFailure
    )

    var succeeded: Bool {
        if case .succeeded = self {
            return true
        }

        return false
    }

    var userMessage: String? {
        guard case .rejected(let failure) = self else {
            return nil
        }

        return failure.userMessage
    }
}


// MARK: - UI Adoption Boundary

struct ZhuowangArtifactAdoptionPresentationResult {

    let succeeded: Bool
    let errorMessage: String?

    static let success =
        ZhuowangArtifactAdoptionPresentationResult(
            succeeded: true,
            errorMessage: nil
        )

    static func failure(
        _ message: String
    ) -> ZhuowangArtifactAdoptionPresentationResult {
        ZhuowangArtifactAdoptionPresentationResult(
            succeeded: false,
            errorMessage: message
        )
    }

    init(
        customerServiceResult:
            ZhuowangCustomerServiceAdoptionResult
    ) {
        succeeded = customerServiceResult.succeeded
        errorMessage = customerServiceResult.userMessage
    }

    private init(
        succeeded: Bool,
        errorMessage: String?
    ) {
        self.succeeded = succeeded
        self.errorMessage = errorMessage
    }
}
