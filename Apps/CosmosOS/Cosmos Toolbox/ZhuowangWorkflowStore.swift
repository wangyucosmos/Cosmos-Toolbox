import Foundation
import Combine

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


    // MARK: - Init

    init() {
        loadProviders()
        loadWorkflows()

        if providers.isEmpty {
            providers = Self.defaultProviders
            saveProviders()
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
        }
    }


    func enabledProviders() -> [ZhuowangAIProvider] {

        providers.filter {
            $0.isEnabled
            && $0.isVisible
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


    // MARK: - Artifacts

    func addArtifact(
        workflowID: UUID,
        campaignID: UUID,
        stepID: UUID? = nil,
        runID: UUID? = nil,
        name: String,
        type: ZhuowangArtifactType,
        location: String = "",
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
                    $0.name == cleanName
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
                    .name == cleanName {

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
            let targetArtifact =
                workflows[workflowIndex]
                    .artifacts
                    .first(
                        where: {
                            $0.id == artifactID
                        }
                    )
        else {
            return
        }

        for artifactIndex
            in workflows[workflowIndex]
                .artifacts.indices {

            if workflows[workflowIndex]
                .artifacts[artifactIndex]
                .name
                == targetArtifact.name {

                workflows[workflowIndex]
                    .artifacts[artifactIndex]
                    .isApprovedVersion =
                    (
                        workflows[workflowIndex]
                            .artifacts[artifactIndex]
                            .id
                        == artifactID
                    )
            }
        }

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

        guard
            let data =
                try? JSONEncoder()
                .encode(workflows)
        else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey:
                workflowStorageKey
        )
    }


    private func loadWorkflows() {

        guard
            let data =
                UserDefaults.standard
                .data(
                    forKey:
                        workflowStorageKey
                ),
            let savedWorkflows =
                try? JSONDecoder()
                .decode(
                    [ZhuowangCampaignWorkflow].self,
                    from: data
                )
        else {
            workflows = []
            return
        }

        workflows =
            savedWorkflows
    }


    private func saveProviders() {

        guard
            let data =
                try? JSONEncoder()
                .encode(providers)
        else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey:
                providerStorageKey
        )
    }


    private func loadProviders() {

        guard
            let data =
                UserDefaults.standard
                .data(
                    forKey:
                        providerStorageKey
                ),
            let savedProviders =
                try? JSONDecoder()
                .decode(
                    [ZhuowangAIProvider].self,
                    from: data
                )
        else {
            providers = []
            return
        }

        providers =
            savedProviders
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
        ),

        ZhuowangAIProvider(
            id: UUID(
                uuidString:
                    "20000000-0000-0000-0000-000000000005"
            )!,
            name: "Figma",
            kind: .figma,
            modelName: "",
            isEnabled: true,
            isVisible: true,
            configurationIdentifier:
                "figma"
        )
    ]
}
