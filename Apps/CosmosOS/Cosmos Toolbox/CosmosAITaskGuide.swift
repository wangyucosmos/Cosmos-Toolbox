import Foundation

/// Presentation only. Preview readiness comes from the existing validation, including reference limits.
nonisolated struct CosmosAITaskGuide: Equatable {
    enum Status: Equatable { case waiting, current, complete }
    let selectionComplete: Bool
    let goalEntered: Bool
    let previewReady: Bool
    func permits(_ stage: Int) -> Bool {
        switch stage { case 1: true; case 2: selectionComplete; case 3: selectionComplete && goalEntered && previewReady; default: false }
    }
    func status(_ stage: Int) -> Status {
        switch stage {
        case 1: selectionComplete ? .complete : .current
        case 2: !selectionComplete ? .waiting : goalEntered && previewReady ? .complete : .current
        case 3: permits(3) ? .current : .waiting
        default: .waiting
        }
    }
}
