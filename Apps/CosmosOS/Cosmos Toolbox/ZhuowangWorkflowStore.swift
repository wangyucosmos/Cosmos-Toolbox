import Foundation
import Combine

private enum ZhuowangProviderPersistenceLoadState: Equatable {
    case missing
    case loaded
    case recoveredFromBackup
    case locked
}


struct ZhuowangWorkflowRecoverySummary {

    let importedArtifacts: Int
    let restoredSteps: Int
    let ambiguousArtifactNames: [String]

    static let empty =
        ZhuowangWorkflowRecoverySummary(
            importedArtifacts: 0,
            restoredSteps: 0,
            ambiguousArtifactNames: []
        )

    var didRecoverAnything: Bool {
        importedArtifacts > 0
        || restoredSteps > 0
    }
}


final class ZhuowangWorkflowStore: ObservableObject {

    // MARK: - Published Data

    @Published
    private(set) var workflows: [ZhuowangCampaignWorkflow] = []

    @Published
    private(set) var providers: [ZhuowangAIProvider] = []


    // MARK: - Storage Keys

    private let workflowStorageKey =
        "cosmos.zhuowang.workflows.v1"

    private let providerStorageKey =
        "cosmos.zhuowang.ai.providers.v1"

    private let providerBackupStorageKey =
        "cosmos.zhuowang.ai.providers.v1.backup"

    /// Last known workflow payload before a successful overwrite.
    /// Used as a lightweight safety net for future model migrations.
    private let workflowBackupStorageKey =
        "cosmos.zhuowang.workflows.v1.backup"

    /// If persisted workflow data exists but cannot be decoded,
    /// block writes so a fresh empty workflow cannot overwrite it.
    private var workflowPersistenceLocked = false

    /// When recovering from backup, preserve that backup on the next save.
    private var skipNextWorkflowBackup = false

    /// Provider configuration has the same safety boundary as Workflow data.
    /// A decode failure must not be converted into a fresh default registry.
    private var providerPersistenceLocked = false
    private var skipNextProviderBackup = false
    private var providerLoadState:
        ZhuowangProviderPersistenceLoadState = .missing


    // MARK: - Init

    init() {
        loadProviders()
        loadWorkflows()

        if providerLoadState == .missing {
            providers = Self.defaultProviders
            saveProviders()

        } else if providerLoadState != .locked {
            normalizeBuiltInProviderIDs()
            removeLegacyToolProvidersFromAIRegistry()
        }
    }


    // MARK: - Workflow Access

    func workflow(
        forCampaignID campaignID: UUID
    ) -> ZhuowangCampaignWorkflow? {

        workflows.first {
            $0.campaignID == campaignID
        }
    }


    // MARK: - Get Or Create Workflow

    @discardableResult
    func getOrCreateWorkflow(
        forCampaignID campaignID: UUID
    ) -> ZhuowangCampaignWorkflow {

        if let existingWorkflow =
            workflow(
                forCampaignID: campaignID
            ) {

            return existingWorkflow
        }

        let newWorkflow =
            ZhuowangCampaignWorkflow.standard(
                campaignID: campaignID
            )

        workflows.append(
            newWorkflow
        )

        saveWorkflows()

        return newWorkflow
    }


    // MARK: - Replace Workflow

    func updateWorkflow(
        _ workflow: ZhuowangCampaignWorkflow
    ) {

        guard
            let index =
                workflows.firstIndex(
                    where: {
                        $0.id == workflow.id
                    }
                )
        else {
            return
        }

        var updatedWorkflow = workflow
        updatedWorkflow.updatedAt = Date()

        workflows[index] =
            updatedWorkflow

        saveWorkflows()
    }


    // MARK: - Delete Workflow

    func deleteWorkflow(
        forCampaignID campaignID: UUID
    ) {

        workflows.removeAll {
            $0.campaignID == campaignID
        }

        saveWorkflows()
    }


    // MARK: - Workflow Step

    func step(
        workflowID: UUID,
        stepID: UUID
    ) -> ZhuowangWorkflowStep? {

        guard
            let workflow =
                workflows.first(
                    where: {
                        $0.id == workflowID
                    }
                )
        else {
            return nil
        }

        return workflow.steps.first {
            $0.id == stepID
        }
    }


    // MARK: - Add Workflow Step

    func addStep(
        workflowID: UUID,
        title: String,
        englishTitle: String = "",
        kind: ZhuowangWorkflowStepKind = .custom,
        requiresApproval: Bool = true
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                )
        else {
            return
        }

        let cleanTitle =
            title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanTitle.isEmpty else {
            return
        }

        let cleanEnglishTitle =
            englishTitle.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let nextSortOrder =
            (
                workflows[workflowIndex]
                    .steps
                    .map(\.sortOrder)
                    .max()
                ?? 0
            ) + 10

        let newStep =
            ZhuowangWorkflowStep(
                title: cleanTitle,
                englishTitle: cleanEnglishTitle,
                kind: kind,
                sortOrder: nextSortOrder,
                status: .notStarted,
                requiresApproval: requiresApproval
            )

        workflows[workflowIndex]
            .steps
            .append(
                newStep
            )

        workflows[workflowIndex]
            .updatedAt = Date()

        sortSteps(
            workflowIndex: workflowIndex
        )

        saveWorkflows()
    }


    // MARK: - Update Workflow Step

    func updateStep(
        workflowID: UUID,
        step: ZhuowangWorkflowStep
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                ),
            let stepIndex =
                workflows[workflowIndex]
                    .steps
                    .firstIndex(
                        where: {
                            $0.id == step.id
                        }
                    )
        else {
            return
        }

        var updatedStep = step
        updatedStep.updatedAt = Date()

        workflows[workflowIndex]
            .steps[stepIndex] =
            updatedStep

        workflows[workflowIndex]
            .updatedAt = Date()

        sortSteps(
            workflowIndex: workflowIndex
        )

        saveWorkflows()
    }


    // MARK: - Update Step Status

    func updateStepStatus(
        workflowID: UUID,
        stepID: UUID,
        status: ZhuowangWorkflowStepStatus
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                ),
            let stepIndex =
                workflows[workflowIndex]
                    .steps
                    .firstIndex(
                        where: {
                            $0.id == stepID
                        }
                    )
        else {
            return
        }

        workflows[workflowIndex]
            .steps[stepIndex]
            .status = status

        workflows[workflowIndex]
            .steps[stepIndex]
            .updatedAt = Date()

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - Select Provider For Step

    func selectProvider(
        workflowID: UUID,
        stepID: UUID,
        providerID: UUID?
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                ),
            let stepIndex =
                workflows[workflowIndex]
                    .steps
                    .firstIndex(
                        where: {
                            $0.id == stepID
                        }
                    )
        else {
            return
        }

        workflows[workflowIndex]
            .steps[stepIndex]
            .selectedProviderID =
            providerID

        workflows[workflowIndex]
            .steps[stepIndex]
            .updatedAt = Date()

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - Select Tools For Step

    /// 保存当前 Workflow Step 选择的工具。
    /// Tool 与 Agent 分离：
    /// Step 可以拥有多个可选工具，但本次执行路径保存用户实际选择的工具。

    func selectTools(
        workflowID: UUID,
        stepID: UUID,
        toolIDs: [UUID]
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                ),
            let stepIndex =
                workflows[workflowIndex]
                    .steps
                    .firstIndex(
                        where: {
                            $0.id == stepID
                        }
                    )
        else {
            return
        }

        workflows[workflowIndex]
            .steps[stepIndex]
            .selectedToolIDs = toolIDs

        workflows[workflowIndex]
            .steps[stepIndex]
            .updatedAt = Date()

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - Enable / Disable Step

    func setStepEnabled(
        workflowID: UUID,
        stepID: UUID,
        isEnabled: Bool
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                ),
            let stepIndex =
                workflows[workflowIndex]
                    .steps
                    .firstIndex(
                        where: {
                            $0.id == stepID
                        }
                    )
        else {
            return
        }

        workflows[workflowIndex]
            .steps[stepIndex]
            .isEnabled = isEnabled

        workflows[workflowIndex]
            .steps[stepIndex]
            .updatedAt = Date()

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - Delete Step

    func deleteStep(
        workflowID: UUID,
        stepID: UUID
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                )
        else {
            return
        }

        workflows[workflowIndex]
            .steps
            .removeAll {
                $0.id == stepID
            }

        workflows[workflowIndex]
            .aiRuns
            .removeAll {
                $0.stepID == stepID
            }

        workflows[workflowIndex]
            .approvals
            .removeAll {
                $0.stepID == stepID
            }

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - AI Providers

    func provider(
        id: UUID
    ) -> ZhuowangAIProvider? {

        providers.first {
            $0.id == id
        }
    }


    func visibleProviders() -> [ZhuowangAIProvider] {

        providers.filter {
            $0.isVisible
            && $0.kind != .figma
        }
    }


    func enabledProviders() -> [ZhuowangAIProvider] {

        providers.filter {
            $0.isEnabled
            && $0.isVisible
            && $0.kind != .figma
        }
    }


    // MARK: - Add Provider

    func addProvider(
        name: String,
        kind: ZhuowangAIProviderKind,
        modelName: String = "",
        configurationIdentifier: String? = nil
    ) {

        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty else {
            return
        }

        // Figma is a Tool, not an AI Provider.
        // Keep the legacy enum case only so old saved data remains decodable.
        guard kind != .figma else {
            return
        }

        let cleanModelName =
            modelName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let newProvider =
            ZhuowangAIProvider(
                name: cleanName,
                kind: kind,
                modelName: cleanModelName,
                isEnabled: true,
                isVisible: true,
                configurationIdentifier:
                    configurationIdentifier
            )

        providers.append(
            newProvider
        )

        saveProviders()
    }


    // MARK: - Update Provider

    func updateProvider(
        _ provider: ZhuowangAIProvider
    ) {

        guard
            let index =
                providers.firstIndex(
                    where: {
                        $0.id == provider.id
                    }
                )
        else {
            return
        }

        var updatedProvider =
            provider

        updatedProvider.updatedAt =
            Date()

        providers[index] =
            updatedProvider

        saveProviders()
    }


    // MARK: - Delete Provider

    func deleteProvider(
        id: UUID
    ) {

        providers.removeAll {
            $0.id == id
        }

        for workflowIndex
            in workflows.indices {

            for stepIndex
                in workflows[workflowIndex]
                    .steps.indices {

                if workflows[workflowIndex]
                    .steps[stepIndex]
                    .selectedProviderID
                    == id {

                    workflows[workflowIndex]
                        .steps[stepIndex]
                        .selectedProviderID =
                        nil
                }
            }
        }

        saveProviders()
        saveWorkflows()
    }


    // MARK: - AI Runs

    @discardableResult
    func createAIRun(
        workflowID: UUID,
        stepID: UUID,
        providerID: UUID,
        inputText: String
    ) -> ZhuowangAIRun? {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                ),
            let provider =
                provider(
                    id: providerID
                )
        else {
            return nil
        }

        let existingVersions =
            workflows[workflowIndex]
                .aiRuns
                .filter {
                    $0.stepID == stepID
                }
                .map(\.version)

        let nextVersion =
            (
                existingVersions.max()
                ?? 0
            ) + 1

        let run =
            ZhuowangAIRun(
                stepID: stepID,
                providerID: providerID,
                modelName:
                    provider.modelName,
                status: .queued,
                inputText: inputText,
                version: nextVersion
            )

        workflows[workflowIndex]
            .aiRuns
            .append(
                run
            )

        workflows[workflowIndex]
            .updatedAt = Date()

        updateStepStatus(
            workflowID: workflowID,
            stepID: stepID,
            status: .running
        )

        saveWorkflows()

        return run
    }


    // MARK: - Update AI Run

    func updateAIRun(
        workflowID: UUID,
        run: ZhuowangAIRun
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                ),
            let runIndex =
                workflows[workflowIndex]
                    .aiRuns
                    .firstIndex(
                        where: {
                            $0.id == run.id
                        }
                    )
        else {
            return
        }

        workflows[workflowIndex]
            .aiRuns[runIndex] =
            run

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - Complete AI Run

    func completeAIRun(
        workflowID: UUID,
        runID: UUID,
        outputText: String
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                ),
            let runIndex =
                workflows[workflowIndex]
                    .aiRuns
                    .firstIndex(
                        where: {
                            $0.id == runID
                        }
                    )
        else {
            return
        }

        workflows[workflowIndex]
            .aiRuns[runIndex]
            .status = .succeeded

        workflows[workflowIndex]
            .aiRuns[runIndex]
            .outputText = outputText

        workflows[workflowIndex]
            .aiRuns[runIndex]
            .completedAt = Date()

        let stepID =
            workflows[workflowIndex]
                .aiRuns[runIndex]
                .stepID

        let requiresApproval =
            workflows[workflowIndex]
                .steps
                .first(
                    where: {
                        $0.id == stepID
                    }
                )?
                .requiresApproval
            ?? true

        updateStepStatus(
            workflowID: workflowID,
            stepID: stepID,
            status:
                requiresApproval
                ? .waitingForApproval
                : .completed
        )

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - Fail AI Run

    func failAIRun(
        workflowID: UUID,
        runID: UUID,
        errorMessage: String
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                ),
            let runIndex =
                workflows[workflowIndex]
                    .aiRuns
                    .firstIndex(
                        where: {
                            $0.id == runID
                        }
                    )
        else {
            return
        }

        workflows[workflowIndex]
            .aiRuns[runIndex]
            .status = .failed

        workflows[workflowIndex]
            .aiRuns[runIndex]
            .errorMessage =
            errorMessage

        workflows[workflowIndex]
            .aiRuns[runIndex]
            .completedAt = Date()

        let stepID =
            workflows[workflowIndex]
                .aiRuns[runIndex]
                .stepID

        updateStepStatus(
            workflowID: workflowID,
            stepID: stepID,
            status: .failed
        )

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - Runs For Step

    func runs(
        workflowID: UUID,
        stepID: UUID
    ) -> [ZhuowangAIRun] {

        guard
            let workflow =
                workflows.first(
                    where: {
                        $0.id == workflowID
                    }
                )
        else {
            return []
        }

        return workflow.aiRuns
            .filter {
                $0.stepID == stepID
            }
            .sorted {
                $0.version > $1.version
            }
    }


    // MARK: - Approval

    func createApproval(
        workflowID: UUID,
        stepID: UUID,
        runID: UUID? = nil
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                )
        else {
            return
        }

        let approval =
            ZhuowangApproval(
                stepID: stepID,
                runID: runID
            )

        workflows[workflowIndex]
            .approvals
            .append(
                approval
            )

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - Approve Step

    func approveStep(
        workflowID: UUID,
        stepID: UUID,
        runID: UUID? = nil,
        feedback: String = ""
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                )
        else {
            return
        }

        let approval =
            ZhuowangApproval(
                stepID: stepID,
                runID: runID,
                decision: .approved,
                feedback: feedback,
                createdAt: Date(),
                decidedAt: Date()
            )

        workflows[workflowIndex]
            .approvals
            .append(
                approval
            )

        updateStepStatus(
            workflowID: workflowID,
            stepID: stepID,
            status: .approved
        )

        unlockNextStep(
            workflowIndex: workflowIndex,
            afterStepID: stepID
        )

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - Request Revision

    func requestRevision(
        workflowID: UUID,
        stepID: UUID,
        runID: UUID? = nil,
        feedback: String
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                )
        else {
            return
        }

        let approval =
            ZhuowangApproval(
                stepID: stepID,
                runID: runID,
                decision: .revisionRequested,
                feedback: feedback,
                createdAt: Date(),
                decidedAt: Date()
            )

        workflows[workflowIndex]
            .approvals
            .append(
                approval
            )

        updateStepStatus(
            workflowID: workflowID,
            stepID: stepID,
            status: .needsRevision
        )

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - Adopt AI Result

    /// Atomically adopts one AI result into the workflow.
    ///
    /// This creates a succeeded AI run, records the approval,
    /// stores the result as an approved Markdown artifact,
    /// marks the current step approved, remembers the provider,
    /// and unlocks the next workflow step.
    @discardableResult
    func adoptAIResult(
        workflowID: UUID,
        campaignID: UUID,
        campaignName: String,
        provinceName: String?,
        stepID: UUID,
        providerID: UUID,
        inputText: String,
        outputText: String,
        artifactName: String
    ) -> Bool {

        let cleanOutput =
            outputText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanOutput.isEmpty else {
            return false
        }

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                ),
            let stepIndex =
                workflows[workflowIndex]
                    .steps
                    .firstIndex(
                        where: {
                            $0.id == stepID
                        }
                    ),
            let provider =
                provider(
                    id: providerID
                )
        else {
            return false
        }

        let stepKind =
            workflows[workflowIndex]
                .steps[stepIndex]
                .kind

        // Avoid creating duplicate records when the button is clicked twice.
        if let existingRun =
            workflows[workflowIndex]
                .aiRuns
                .last(
                    where: {
                        $0.stepID == stepID
                        && $0.providerID == providerID
                        && $0.status == .succeeded
                        && $0.outputText == cleanOutput
                    }
                ),
           workflows[workflowIndex]
                .approvals
                .contains(
                    where: {
                        $0.runID == existingRun.id
                        && $0.decision == .approved
                    }
                ) {

            if let artifactIndex =
                workflows[workflowIndex]
                    .artifacts
                    .firstIndex(
                        where: {
                            $0.runID == existingRun.id
                        }
                    ) {

                let existingArtifact =
                    workflows[workflowIndex]
                        .artifacts[artifactIndex]

                if existingArtifact.location
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty,
                   let existingContent =
                    existingArtifact.content,
                   !existingContent
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty {

                    do {

                        let fileURL =
                            try ZhuowangWorkspaceFileManager
                                .shared
                                .writeMarkdownArtifact(
                                    provinceName:
                                        provinceName,
                                    campaignName:
                                        campaignName,
                                    stepKind:
                                        stepKind,
                                    artifactName:
                                        existingArtifact.name,
                                    version:
                                        existingArtifact.version,
                                    content:
                                        existingContent
                                )

                        workflows[workflowIndex]
                            .artifacts[artifactIndex]
                            .location =
                            fileURL.path

                        workflows[workflowIndex]
                            .artifacts[artifactIndex]
                            .updatedAt =
                            Date()

                    } catch {

                        return false
                    }
                }
            }

            workflows[workflowIndex]
                .steps[stepIndex]
                .selectedProviderID =
                providerID

            workflows[workflowIndex]
                .steps[stepIndex]
                .status =
                .approved

            unlockNextStep(
                workflowIndex: workflowIndex,
                afterStepID: stepID
            )

            workflows[workflowIndex]
                .updatedAt = Date()

            saveWorkflows()

            return true
        }

        let runVersion =
            (
                workflows[workflowIndex]
                    .aiRuns
                    .filter {
                        $0.stepID == stepID
                    }
                    .map(\.version)
                    .max()
                ?? 0
            ) + 1

        let run =
            ZhuowangAIRun(
                stepID: stepID,
                providerID: providerID,
                modelName: provider.modelName,
                status: .succeeded,
                inputText: inputText,
                outputText: cleanOutput,
                version: runVersion,
                startedAt: Date(),
                completedAt: Date()
            )

        workflows[workflowIndex]
            .aiRuns
            .append(
                run
            )

        let approval =
            ZhuowangApproval(
                stepID: stepID,
                runID: run.id,
                decision: .approved,
                feedback: "",
                createdAt: Date(),
                decidedAt: Date()
            )

        workflows[workflowIndex]
            .approvals
            .append(
                approval
            )

        let cleanArtifactName =
            artifactName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let finalArtifactName =
            cleanArtifactName.isEmpty
            ? "AI 结果"
            : cleanArtifactName

        let artifactVersion =
            (
                workflows[workflowIndex]
                    .artifacts
                    .filter {
                        $0.name == finalArtifactName
                    }
                    .map(\.version)
                    .max()
                ?? 0
            ) + 1

        for artifactIndex
            in workflows[workflowIndex]
                .artifacts.indices {

            if workflows[workflowIndex]
                .artifacts[artifactIndex]
                .name == finalArtifactName {

                workflows[workflowIndex]
                    .artifacts[artifactIndex]
                    .isApprovedVersion =
                    false
            }
        }

        let fileURL: URL

        do {

            fileURL =
                try ZhuowangWorkspaceFileManager
                    .shared
                    .writeMarkdownArtifact(
                        provinceName:
                            provinceName,
                        campaignName:
                            campaignName,
                        stepKind:
                            stepKind,
                        artifactName:
                            finalArtifactName,
                        version:
                            artifactVersion,
                        content:
                            cleanOutput
                    )

        } catch {

            return false
        }

        let artifact =
            ZhuowangArtifact(
                campaignID: campaignID,
                stepID: stepID,
                runID: run.id,
                name: finalArtifactName,
                type: .markdown,
                location: fileURL.path,
                content: cleanOutput,
                version: artifactVersion,
                isApprovedVersion: true
            )

        workflows[workflowIndex]
            .artifacts
            .append(
                artifact
            )

        workflows[workflowIndex]
            .steps[stepIndex]
            .selectedProviderID =
            providerID

        workflows[workflowIndex]
            .steps[stepIndex]
            .status =
            .approved

        workflows[workflowIndex]
            .steps[stepIndex]
            .updatedAt = Date()

        unlockNextStep(
            workflowIndex: workflowIndex,
            afterStepID: stepID
        )

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()

        return true
    }


    // MARK: - Adopt Tool Artifact Result

    /// Adopts a validated Tool Artifact only after its versioned file has been
    /// written successfully. Existing Workflow data is not mutated before that
    /// durable file boundary succeeds.
    @discardableResult
    func adoptExecutionResult(
        workflowID: UUID,
        campaignID: UUID,
        campaignName: String,
        provinceName: String?,
        stepID: UUID,
        provider: ZhuowangAIProvider,
        inputText: String,
        executionResult: ZhuowangWorkflowExecutionResult
    ) -> Bool {

        let draft = executionResult.artifactDraft
        let snapshot = executionResult.snapshot
        let cleanContent = draft.content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            !cleanContent.isEmpty,
            snapshot.workflowID == workflowID,
            snapshot.workflowStepID == stepID,
            snapshot.providerID == provider.id
        else {
            return false
        }

        guard
            let workflowIndex = workflows.firstIndex(
                where: { $0.id == workflowID }
            ),
            let stepIndex = workflows[workflowIndex]
                .steps.firstIndex(
                    where: { $0.id == stepID }
                )
        else {
            return false
        }

        let originalWorkflow = workflows[workflowIndex]
        let stepKind = originalWorkflow.steps[stepIndex].kind

        let nextRunVersion =
            (originalWorkflow.aiRuns
                .filter { $0.stepID == stepID }
                .map(\.version)
                .max() ?? 0) + 1

        let nextArtifactVersion =
            ZhuowangWorkflowTransitionLogic
                .nextArtifactVersion(
                    artifacts: originalWorkflow.artifacts,
                    logicalKey: draft.logicalKey
                )

        let fileURL: URL

        do {
            switch draft.type {
            case .html:
                fileURL = try ZhuowangWorkspaceFileManager
                    .shared
                    .writeHTMLArtifact(
                        provinceName: provinceName,
                        campaignName: campaignName,
                        stepKind: stepKind,
                        artifactName: draft.name,
                        version: nextArtifactVersion,
                        content: cleanContent
                    )

            case .markdown:
                fileURL = try ZhuowangWorkspaceFileManager
                    .shared
                    .writeMarkdownArtifact(
                        provinceName: provinceName,
                        campaignName: campaignName,
                        stepKind: stepKind,
                        artifactName: draft.name,
                        version: nextArtifactVersion,
                        content: cleanContent
                    )

            default:
                return false
            }
        } catch {
            print(
                "[Cosmos OS] Artifact adoption stopped before Workflow mutation: \(error.localizedDescription)"
            )
            return false
        }

        let run = ZhuowangAIRun(
            stepID: stepID,
            providerID: provider.id,
            connectionID: snapshot.connectionID,
            toolIntegrationID: snapshot.toolIntegrationID,
            routeID: snapshot.routeID,
            capability: snapshot.capability,
            adapterIdentifier: snapshot.adapterIdentifier,
            modelName: provider.modelName,
            status: .succeeded,
            inputText: inputText,
            outputText: executionResult.rawAIResult,
            version: nextRunVersion,
            startedAt: snapshot.createdAt,
            completedAt: Date()
        )

        let approval = ZhuowangApproval(
            stepID: stepID,
            runID: run.id,
            decision: .approved,
            feedback: "",
            createdAt: Date(),
            decidedAt: Date()
        )

        let artifact = ZhuowangArtifact(
            campaignID: campaignID,
            stepID: stepID,
            runID: run.id,
            name: draft.name,
            type: draft.type,
            logicalKey: draft.logicalKey,
            providerID: provider.id,
            connectionID: snapshot.connectionID,
            toolIntegrationID: snapshot.toolIntegrationID,
            routeID: snapshot.routeID,
            capability: snapshot.capability,
            adapterIdentifier: snapshot.adapterIdentifier,
            location: fileURL.path,
            content: cleanContent,
            version: nextArtifactVersion,
            isApprovedVersion: true
        )

        var updatedWorkflow = originalWorkflow

        updatedWorkflow.aiRuns.append(run)
        updatedWorkflow.approvals.append(approval)
        updatedWorkflow.artifacts.append(artifact)
        updatedWorkflow.artifacts =
            ZhuowangWorkflowTransitionLogic
                .selectingCurrentVersion(
                    artifacts: updatedWorkflow.artifacts,
                    artifactID: artifact.id
                )
        updatedWorkflow.steps[stepIndex].selectedProviderID = provider.id
        updatedWorkflow.steps[stepIndex].selectedToolIDs = [
            snapshot.toolIntegrationID
        ]
        updatedWorkflow =
            ZhuowangWorkflowTransitionLogic
                .approvingStepAndUnlockingNext(
                    workflow: updatedWorkflow,
                    stepID: stepID
                )

        workflows[workflowIndex] = updatedWorkflow

        saveWorkflows()
        return true
    }


    // MARK: - Recover Workflow From Local Files

    /// Rebuilds missing Workflow / Artifact metadata from files that already
    /// exist inside the campaign workspace.
    ///
    /// Recovery is idempotent:
    /// - existing Artifact records are not duplicated
    /// - existing approved-version choices are preserved
    /// - local files are read only
    /// - only missing metadata is reconstructed
    ///
    /// If metadata was completely lost and several versions exist for the same
    /// artifact, the highest version is used as a conservative fallback and the
    /// ambiguity is reported to the UI so the user can switch versions manually.
    @discardableResult
    func recoverWorkflowFromLocalFiles(
        campaign: ZhuowangCampaign,
        provinceName: String?
    ) -> ZhuowangWorkflowRecoverySummary {

        let discovered =
            ZhuowangWorkspaceFileManager
                .shared
                .discoverLocalArtifacts(
                    provinceName:
                        provinceName,
                    campaignName:
                        campaign.name
                )

        guard !discovered.isEmpty else {
            return .empty
        }

        let workflow =
            getOrCreateWorkflow(
                forCampaignID:
                    campaign.id
            )

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflow.id
                    }
                )
        else {
            return .empty
        }

        var importedArtifacts = 0
        var recoveredStepIDs = Set<UUID>()
        var changed = false

        for item in discovered {

            guard
                let stepIndex =
                    workflows[workflowIndex]
                        .steps
                        .firstIndex(
                            where: {
                                $0.kind
                                    == item.stepKind
                            }
                        )
            else {
                continue
            }

            let stepID =
                workflows[workflowIndex]
                    .steps[stepIndex]
                    .id

            recoveredStepIDs.insert(
                stepID
            )

            let alreadyExists =
                workflows[workflowIndex]
                    .artifacts
                    .contains {
                        artifact in

                        artifact.stepID == stepID
                        && artifact.version
                            == item.version
                        && (
                            artifact.location
                                == item.fileURL.path
                            || artifact.name
                                == item.artifactName
                        )
                    }

            if !alreadyExists {

                let artifact =
                    ZhuowangArtifact(
                        campaignID:
                            campaign.id,
                        stepID:
                            stepID,
                        runID:
                            nil,
                        name:
                            item.artifactName,
                        type:
                            item.type,
                        logicalKey:
                            item.stepKind == .prototype
                            && item.type == .html
                            && item.artifactName == "产品原型设计"
                            ? "workflow.prototypeDesign.primary"
                            : nil,
                        location:
                            item.fileURL.path,
                        content:
                            item.content,
                        version:
                            item.version,
                        isApprovedVersion:
                            false,
                        createdAt:
                            item.modifiedAt,
                        updatedAt:
                            item.modifiedAt
                    )

                workflows[workflowIndex]
                    .artifacts
                    .append(
                        artifact
                    )

                importedArtifacts += 1
                changed = true
            }
        }

        // Restore step progress from real files.
        var restoredSteps = 0

        for stepIndex
            in workflows[workflowIndex]
                .steps.indices {

            let stepID =
                workflows[workflowIndex]
                    .steps[stepIndex]
                    .id

            guard
                recoveredStepIDs.contains(
                    stepID
                )
            else {
                continue
            }

            if workflows[workflowIndex]
                .steps[stepIndex]
                .status
                != .approved {

                workflows[workflowIndex]
                    .steps[stepIndex]
                    .status =
                    .approved

                workflows[workflowIndex]
                    .steps[stepIndex]
                    .updatedAt =
                    Date()

                restoredSteps += 1
                changed = true
            }
        }

        // Preserve any existing approved selection. When the metadata is gone,
        // choose the highest local version and report multi-version ambiguity.
        var ambiguousArtifactNames: [String] = []

        let groupedArtifacts =
            Dictionary(
                grouping:
                    workflows[workflowIndex]
                        .artifacts
            ) {
                artifact in

                "\(artifact.stepID?.uuidString ?? "none")|\(artifact.versionGroupKey)"
            }

        for (_, artifacts)
            in groupedArtifacts {

            guard !artifacts.isEmpty else {
                continue
            }

            if artifacts.contains(
                where: {
                    $0.isApprovedVersion
                }
            ) {
                continue
            }

            let sorted =
                artifacts.sorted {

                    if $0.version
                        != $1.version {

                        return $0.version
                            > $1.version
                    }

                    return $0.updatedAt
                        > $1.updatedAt
                }

            guard
                let fallback =
                    sorted.first
            else {
                continue
            }

            if sorted.count > 1 {

                ambiguousArtifactNames
                    .append(
                        fallback.name
                    )
            }

            for artifactIndex
                in workflows[workflowIndex]
                    .artifacts.indices {

                let current =
                    workflows[workflowIndex]
                        .artifacts[artifactIndex]

                if current.stepID
                    == fallback.stepID,
                   current.name
                    == fallback.name,
                   current.versionGroupKey
                    == fallback.versionGroupKey {

                    workflows[workflowIndex]
                        .artifacts[artifactIndex]
                        .isApprovedVersion =
                        current.id
                        == fallback.id

                    changed = true
                }
            }
        }

        // Rebuild the "next actionable step" after recovered progress.
        let enabledSortedIndices =
            workflows[workflowIndex]
                .steps.indices
                .filter {
                    workflows[workflowIndex]
                        .steps[$0]
                        .isEnabled
                }
                .sorted {
                    workflows[workflowIndex]
                        .steps[$0]
                        .sortOrder
                    <
                    workflows[workflowIndex]
                        .steps[$1]
                        .sortOrder
                }

        var foundNextStep = false

        for stepIndex
            in enabledSortedIndices {

            let status =
                workflows[workflowIndex]
                    .steps[stepIndex]
                    .status

            if status == .approved
                || status == .completed {

                continue
            }

            if !foundNextStep {

                if status
                    == .notStarted
                    || status
                    == .failed
                    || status
                    == .skipped {

                    workflows[workflowIndex]
                        .steps[stepIndex]
                        .status =
                        .ready

                    workflows[workflowIndex]
                        .steps[stepIndex]
                        .updatedAt =
                        Date()

                    changed = true
                }

                foundNextStep = true
            }
        }

        if changed {

            workflows[workflowIndex]
                .updatedAt =
                Date()

            saveWorkflows()
        }

        return ZhuowangWorkflowRecoverySummary(
            importedArtifacts:
                importedArtifacts,
            restoredSteps:
                restoredSteps,
            ambiguousArtifactNames:
                Array(
                    Set(
                        ambiguousArtifactNames
                    )
                )
                .sorted()
        )
    }


    // MARK: - Legacy Artifact Migration

    @discardableResult
    func migrateLegacyArtifactsToLocalFiles(
        campaign: ZhuowangCampaign,
        provinceName: String?
    ) -> Int {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.campaignID
                            == campaign.id
                    }
                )
        else {
            return 0
        }

        var migratedCount = 0

        for artifactIndex
            in workflows[workflowIndex]
                .artifacts.indices {

            let artifact =
                workflows[workflowIndex]
                    .artifacts[artifactIndex]

            let currentLocation =
                artifact.location
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            if !currentLocation.isEmpty,
               FileManager.default
                .fileExists(
                    atPath:
                        currentLocation
                ) {

                continue
            }

            guard
                let stepID =
                    artifact.stepID,
                let step =
                    workflows[workflowIndex]
                        .steps.first(
                            where: {
                                $0.id == stepID
                            }
                        ),
                let content =
                    artifact.content?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ),
                !content.isEmpty
            else {
                continue
            }

            do {

                let fileURL: URL

                if artifact.type == .html {
                    fileURL = try ZhuowangWorkspaceFileManager
                        .shared
                        .writeHTMLArtifact(
                            provinceName:
                                provinceName,
                            campaignName:
                                campaign.name,
                            stepKind:
                                step.kind,
                            artifactName:
                                artifact.name,
                            version:
                                artifact.version,
                            content:
                                content
                        )
                } else {
                    fileURL = try ZhuowangWorkspaceFileManager
                        .shared
                        .writeMarkdownArtifact(
                            provinceName:
                                provinceName,
                            campaignName:
                                campaign.name,
                            stepKind:
                                step.kind,
                            artifactName:
                                artifact.name,
                            version:
                                artifact.version,
                            content:
                                content
                        )
                }

                workflows[workflowIndex]
                    .artifacts[artifactIndex]
                    .location =
                    fileURL.path

                workflows[workflowIndex]
                    .artifacts[artifactIndex]
                    .updatedAt =
                    Date()

                migratedCount += 1

            } catch {

                continue
            }
        }

        if migratedCount > 0 {

            workflows[workflowIndex]
                .updatedAt =
                Date()

            saveWorkflows()
        }

        return migratedCount
    }


    // MARK: - Artifacts

    func addArtifact(
        workflowID: UUID,
        campaignID: UUID,
        stepID: UUID? = nil,
        runID: UUID? = nil,
        name: String,
        type: ZhuowangArtifactType,
        location: String = "",
        content: String? = nil,
        isApprovedVersion: Bool = false
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                )
        else {
            return
        }

        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty else {
            return
        }

        let existingVersions =
            workflows[workflowIndex]
                .artifacts
                .filter {
                    $0.versionGroupKey == cleanName
                }
                .map(\.version)

        let nextVersion =
            (
                existingVersions.max()
                ?? 0
            ) + 1

        if isApprovedVersion {

            for artifactIndex
                in workflows[workflowIndex]
                    .artifacts.indices {

                if workflows[workflowIndex]
                    .artifacts[artifactIndex]
                    .versionGroupKey == cleanName {

                    workflows[workflowIndex]
                        .artifacts[artifactIndex]
                        .isApprovedVersion =
                        false
                }
            }
        }

        let artifact =
            ZhuowangArtifact(
                campaignID: campaignID,
                stepID: stepID,
                runID: runID,
                name: cleanName,
                type: type,
                location: location,
                content: content,
                version: nextVersion,
                isApprovedVersion:
                    isApprovedVersion
            )

        workflows[workflowIndex]
            .artifacts
            .append(
                artifact
            )

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - Approve Artifact Version

    func approveArtifact(
        workflowID: UUID,
        artifactID: UUID
    ) {

        guard
            let workflowIndex =
                workflows.firstIndex(
                    where: {
                        $0.id == workflowID
                    }
                ),
            workflows[workflowIndex]
                .artifacts
                .contains(
                    where: {
                        $0.id == artifactID
                    }
                )
        else {
            return
        }

        workflows[workflowIndex].artifacts =
            ZhuowangWorkflowTransitionLogic
                .selectingCurrentVersion(
                    artifacts:
                        workflows[workflowIndex].artifacts,
                    artifactID: artifactID
                )

        workflows[workflowIndex]
            .updatedAt = Date()

        saveWorkflows()
    }


    // MARK: - Artifacts For Campaign

    func artifacts(
        forCampaignID campaignID: UUID
    ) -> [ZhuowangArtifact] {

        workflows
            .filter {
                $0.campaignID == campaignID
            }
            .flatMap {
                $0.artifacts
            }
            .sorted {
                $0.updatedAt > $1.updatedAt
            }
    }


    // MARK: - Persistence

    private func saveWorkflows() {

        // Never destroy an existing persisted workflow after a decode failure.
        guard !workflowPersistenceLocked else {

            print(
                "[Cosmos OS] Workflow persistence is locked because existing data could not be decoded. Save skipped to protect user data."
            )

            return
        }

        guard
            let data =
                try? JSONEncoder()
                .encode(workflows)
        else {
            return
        }

        let defaults =
            UserDefaults.standard

        if skipNextWorkflowBackup {

            skipNextWorkflowBackup = false

        } else if let currentData =
            defaults.data(
                forKey:
                    workflowStorageKey
            ) {

            if canDecodeWorkflows(
                currentData
            ) {
                defaults.set(
                    currentData,
                    forKey:
                        workflowBackupStorageKey
                )
            } else {
                print(
                    "[Cosmos OS] Existing Workflow payload is unreadable. Previous backup was preserved."
                )
            }
        }

        defaults.set(
            data,
            forKey:
                workflowStorageKey
        )
    }


    private func loadWorkflows() {

        let defaults =
            UserDefaults.standard

        guard
            let data =
                defaults.data(
                    forKey:
                        workflowStorageKey
                )
        else {

            workflows = []
            workflowPersistenceLocked = false

            return
        }

        do {

            workflows =
                try JSONDecoder()
                .decode(
                    [ZhuowangCampaignWorkflow].self,
                    from: data
                )

            workflowPersistenceLocked = false

        } catch {

            // Try the previous payload before giving up.
            if let backupData =
                defaults.data(
                    forKey:
                        workflowBackupStorageKey
                ),
               let backupWorkflows =
                try? JSONDecoder()
                .decode(
                    [ZhuowangCampaignWorkflow].self,
                    from: backupData
                ) {

                workflows =
                    backupWorkflows

                workflowPersistenceLocked = false
                skipNextWorkflowBackup = true

                print(
                    "[Cosmos OS] Current workflow payload could not be decoded. Recovered from backup: \(error.localizedDescription)"
                )

                return
            }

            // Existing bytes are present but unreadable.
            // Keep them untouched instead of replacing them with a new empty workflow.
            workflows = []
            workflowPersistenceLocked = true

            print(
                "[Cosmos OS] Workflow decode failed. Existing persisted data has been protected from overwrite: \(error.localizedDescription)"
            )
        }
    }


    private func saveProviders() {

        guard !providerPersistenceLocked else {
            print(
                "[Cosmos OS] AI Provider persistence is locked because existing data could not be decoded. Save skipped to protect user data."
            )
            return
        }

        guard
            let data =
                try? JSONEncoder()
                .encode(providers)
        else {
            return
        }

        let defaults = UserDefaults.standard

        if skipNextProviderBackup {
            skipNextProviderBackup = false

        } else if let currentData =
            defaults.data(
                forKey:
                    providerStorageKey
            ) {

            if canDecodeProviders(
                currentData
            ) {
                defaults.set(
                    currentData,
                    forKey:
                        providerBackupStorageKey
                )
            } else {
                print(
                    "[Cosmos OS] Existing AI Provider payload is unreadable. Previous backup was preserved."
                )
            }
        }

        defaults.set(
            data,
            forKey:
                providerStorageKey
        )
    }


    private func loadProviders() {

        let defaults = UserDefaults.standard

        guard let data =
            defaults.data(
                forKey:
                    providerStorageKey
            )
        else {
            providers = []
            providerPersistenceLocked = false
            providerLoadState = .missing
            return
        }

        do {
            providers =
                try JSONDecoder()
                .decode(
                    [ZhuowangAIProvider].self,
                    from: data
                )

            providerPersistenceLocked = false
            providerLoadState = .loaded

        } catch {

            if let backupData =
                defaults.data(
                    forKey:
                        providerBackupStorageKey
                ),
               let backupProviders =
                try? JSONDecoder()
                .decode(
                    [ZhuowangAIProvider].self,
                    from: backupData
                ) {

                providers = backupProviders
                providerPersistenceLocked = false
                providerLoadState = .recoveredFromBackup
                skipNextProviderBackup = true

                print(
                    "[Cosmos OS] AI Provider payload could not be decoded. Recovered from backup: \(error.localizedDescription)"
                )
                return
            }

            providers = []
            providerPersistenceLocked = true
            providerLoadState = .locked

            print(
                "[Cosmos OS] AI Provider decode failed. Existing payload and previous backup were protected from overwrite: \(error.localizedDescription)"
            )
        }
    }


    // MARK: - Backup Validation

    private func canDecodeWorkflows(
        _ data: Data
    ) -> Bool {

        (try? JSONDecoder().decode(
            [ZhuowangCampaignWorkflow].self,
            from: data
        )) != nil
    }


    private func canDecodeProviders(
        _ data: Data
    ) -> Bool {

        (try? JSONDecoder().decode(
            [ZhuowangAIProvider].self,
            from: data
        )) != nil
    }


    // MARK: - Sorting

    private func sortSteps(
        workflowIndex: Int
    ) {

        workflows[workflowIndex]
            .steps
            .sort {

                if $0.sortOrder
                    != $1.sortOrder {

                    return $0.sortOrder
                        < $1.sortOrder
                }

                return $0.createdAt
                    < $1.createdAt
            }
    }


    // MARK: - Unlock Next Step

    private func unlockNextStep(
        workflowIndex: Int,
        afterStepID stepID: UUID
    ) {

        let sortedSteps =
            workflows[workflowIndex]
                .steps
                .filter {
                    $0.isEnabled
                }
                .sorted {
                    $0.sortOrder
                        < $1.sortOrder
                }

        guard
            let currentIndex =
                sortedSteps.firstIndex(
                    where: {
                        $0.id == stepID
                    }
                )
        else {
            return
        }

        let nextIndex =
            sortedSteps.index(
                after: currentIndex
            )

        guard
            nextIndex
                < sortedSteps.endIndex
        else {
            return
        }

        let nextStepID =
            sortedSteps[nextIndex]
                .id

        guard
            let storedIndex =
                workflows[workflowIndex]
                    .steps
                    .firstIndex(
                        where: {
                            $0.id
                                == nextStepID
                        }
                    )
        else {
            return
        }

        if workflows[workflowIndex]
            .steps[storedIndex]
            .status
            == .notStarted {

            workflows[workflowIndex]
                .steps[storedIndex]
                .status =
                .ready

            workflows[workflowIndex]
                .steps[storedIndex]
                .updatedAt =
                Date()
        }
    }


    // MARK: - Normalize Built-in Provider IDs

    /// Older Cosmos OS builds could save built-in providers with random UUIDs.
    /// Connections use stable provider UUIDs, so a stale provider ID can make
    /// a previously selected AI appear to have no Connection.
    ///
    /// This migration keeps user-facing provider settings while moving the
    /// built-in providers and all workflow references to the canonical IDs.
    private func normalizeBuiltInProviderIDs() {

        var didChange = false

        for canonical
            in Self.defaultProviders {

            guard
                let identifier =
                    canonical.configurationIdentifier,
                let existingIndex =
                    providers.firstIndex(
                        where: {
                            $0.configurationIdentifier
                                == identifier
                        }
                    )
            else {

                if let identifier =
                    canonical.configurationIdentifier,
                   !providers.contains(
                        where: {
                            $0.configurationIdentifier
                                == identifier
                        }
                   ) {

                    providers.append(
                        canonical
                    )

                    didChange = true
                }

                continue
            }

            let existing =
                providers[existingIndex]

            guard
                existing.id
                    != canonical.id
            else {
                continue
            }

            let oldID =
                existing.id

            providers[existingIndex] =
                ZhuowangAIProvider(
                    id: canonical.id,
                    name: existing.name,
                    kind: canonical.kind,
                    modelName:
                        existing.modelName,
                    isEnabled:
                        existing.isEnabled,
                    isVisible:
                        existing.isVisible,
                    configurationIdentifier:
                        identifier,
                    createdAt:
                        existing.createdAt,
                    updatedAt:
                        Date()
                )

            for workflowIndex
                in workflows.indices {

                for stepIndex
                    in workflows[workflowIndex]
                        .steps.indices {

                    if workflows[workflowIndex]
                        .steps[stepIndex]
                        .selectedProviderID
                        == oldID {

                        workflows[workflowIndex]
                            .steps[stepIndex]
                            .selectedProviderID =
                            canonical.id
                    }
                }

                for runIndex
                    in workflows[workflowIndex]
                        .aiRuns.indices {

                    if workflows[workflowIndex]
                        .aiRuns[runIndex]
                        .providerID
                        == oldID {

                        workflows[workflowIndex]
                            .aiRuns[runIndex]
                            .providerID =
                            canonical.id
                    }
                }
            }

            didChange = true
        }

        if didChange {
            saveProviders()
            saveWorkflows()
        }
    }


    // MARK: - Legacy Tool Provider Cleanup

    /// Figma used to exist inside the AI Provider registry.
    /// It is now an external Tool. Keep `.figma` in the enum only for
    /// backward decoding, but remove persisted Figma provider records
    /// and clear any step-level AI selections that point to them.
    private func removeLegacyToolProvidersFromAIRegistry() {

        let legacyFigmaIDs =
            Set(
                providers
                    .filter {
                        $0.kind == .figma
                        || $0.configurationIdentifier
                            == "figma"
                    }
                    .map(\.id)
            )

        guard !legacyFigmaIDs.isEmpty else {
            return
        }

        providers.removeAll {
            legacyFigmaIDs.contains(
                $0.id
            )
        }

        for workflowIndex
            in workflows.indices {

            for stepIndex
                in workflows[workflowIndex]
                    .steps.indices {

                if let selectedProviderID =
                    workflows[workflowIndex]
                    .steps[stepIndex]
                    .selectedProviderID,
                   legacyFigmaIDs.contains(
                    selectedProviderID
                   ) {

                    workflows[workflowIndex]
                        .steps[stepIndex]
                        .selectedProviderID =
                        nil
                }
            }
        }

        saveProviders()
        saveWorkflows()
    }


    // MARK: - Default Providers

    private static let defaultProviders: [
        ZhuowangAIProvider
    ] = [

        ZhuowangAIProvider(
            id: UUID(
                uuidString:
                    "20000000-0000-0000-0000-000000000001"
            )!,
            name: "OpenAI",
            kind: .openAI,
            modelName: "",
            isEnabled: true,
            isVisible: true,
            configurationIdentifier:
                "openai"
        ),

        ZhuowangAIProvider(
            id: UUID(
                uuidString:
                    "20000000-0000-0000-0000-000000000002"
            )!,
            name: "Codex",
            kind: .codex,
            modelName: "",
            isEnabled: true,
            isVisible: true,
            configurationIdentifier:
                "codex"
        ),

        ZhuowangAIProvider(
            id: UUID(
                uuidString:
                    "20000000-0000-0000-0000-000000000003"
            )!,
            name: "DeepSeek Harness",
            kind: .deepSeekHarness,
            modelName: "",
            isEnabled: true,
            isVisible: true,
            configurationIdentifier:
                "deepseek-harness"
        ),

        ZhuowangAIProvider(
            id: UUID(
                uuidString:
                    "20000000-0000-0000-0000-000000000004"
            )!,
            name: "Claude",
            kind: .claude,
            modelName: "",
            isEnabled: false,
            isVisible: true,
            configurationIdentifier:
                "claude"
        )
    ]
}
