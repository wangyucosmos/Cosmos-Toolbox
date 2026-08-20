import Foundation

/// Pure Workflow and Artifact transition rules used by the Store and unit tests.
enum ZhuowangWorkflowTransitionLogic {

    static func nextArtifactVersion(
        artifacts: [ZhuowangArtifact],
        logicalKey: String
    ) -> Int {

        (artifacts
            .filter {
                $0.versionGroupKey == logicalKey
            }
            .map(\.version)
            .max() ?? 0) + 1
    }


    static func selectingCurrentVersion(
        artifacts: [ZhuowangArtifact],
        artifactID: UUID
    ) -> [ZhuowangArtifact] {

        guard let target = artifacts.first(
            where: { $0.id == artifactID }
        ) else {
            return artifacts
        }

        return artifacts.map { artifact in
            var updated = artifact

            if updated.versionGroupKey
                == target.versionGroupKey {
                updated.isApprovedVersion =
                    updated.id == artifactID
            }

            return updated
        }
    }


    static func approvingStepAndUnlockingNext(
        workflow: ZhuowangCampaignWorkflow,
        stepID: UUID
    ) -> ZhuowangCampaignWorkflow {

        var updated = workflow

        let sortedStepIDs = updated.steps
            .filter(\.isEnabled)
            .sorted {
                $0.sortOrder < $1.sortOrder
            }
            .map(\.id)

        guard
            let currentOrderIndex = sortedStepIDs.firstIndex(
                of: stepID
            ),
            let storedIndex = updated.steps.firstIndex(
                where: { $0.id == stepID }
            )
        else {
            return workflow
        }

        updated.steps[storedIndex].status = .approved
        updated.steps[storedIndex].updatedAt = Date()

        let nextOrderIndex = sortedStepIDs.index(
            after: currentOrderIndex
        )

        if nextOrderIndex < sortedStepIDs.endIndex,
           let nextStoredIndex = updated.steps.firstIndex(
                where: {
                    $0.id == sortedStepIDs[nextOrderIndex]
                }
           ),
           updated.steps[nextStoredIndex].status == .notStarted {

            updated.steps[nextStoredIndex].status = .ready
            updated.steps[nextStoredIndex].updatedAt = Date()
        }

        updated.updatedAt = Date()
        return updated
    }
}
