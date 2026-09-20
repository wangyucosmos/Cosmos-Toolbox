import Foundation
import Combine

final class ZhuowangCampaignStore: ObservableObject {

    @Published
    private(set) var campaigns: [ZhuowangCampaign] = []

    @Published
    private(set) var persistenceState:
        ZhuowangStorePersistenceState = .healthy

    static let storageKey =
        "cosmos.zhuowang.campaigns.v1"

    static let backupKey =
        "cosmos.zhuowang.campaigns.v1.backup"

    let persistenceConfiguration:
        ZhuowangStorePersistenceConfiguration

    private let persistence:
        ZhuowangProtectedPersistence<[ZhuowangCampaign]>

    private var baselineData: Data?


    // MARK: - Init

    init(
        persistenceConfiguration:
            ZhuowangStorePersistenceConfiguration = .production
    ) {
        self.persistenceConfiguration =
            persistenceConfiguration

        self.persistence =
            ZhuowangProtectedPersistence(
                dataSource:
                    persistenceConfiguration.dataSource,
                primaryKey: Self.storageKey,
                backupKey: Self.backupKey
            )

        load()
    }


    // MARK: - Create

    @discardableResult
    func addCampaign(
        name: String,
        englishName: String = "",
        scopeType: ZhuowangCampaignScopeType,
        provinceID: UUID? = nil,
        moduleID: String? = nil,
        startDate: Date,
        endDate: Date,
        status: ZhuowangCampaignStatus = .planning,
        notes: String = ""
    ) -> ZhuowangStoreMutationResult {
        guard
            persistenceState.allowsMutations,
            baselineData != nil
        else {
            return .rejected(
                failureForCurrentState
            )
        }

        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty else {
            return .rejected(.invalidInput)
        }

        let campaign =
            ZhuowangCampaign(
                name: cleanName,
                englishName:
                    englishName.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                scopeType: scopeType,
                provinceID: provinceID,
                moduleID: moduleID,
                startDate: startDate,
                endDate: endDate,
                status: status,
                notes:
                    notes.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
            )

        return transact { campaigns in
            campaigns.append(campaign)
            Self.sortCampaigns(&campaigns)
            return true
        }
    }


    // MARK: - Update

    @discardableResult
    func updateCampaign(
        _ campaign: ZhuowangCampaign
    ) -> ZhuowangStoreMutationResult {
        guard
            persistenceState.allowsMutations,
            baselineData != nil
        else {
            return .rejected(
                failureForCurrentState
            )
        }

        guard
            !campaign.name
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
        else {
            return .rejected(.invalidInput)
        }

        return transact(
            rejectedMutationFailure: .itemNotFound
        ) { campaigns in
            guard
                let index =
                    campaigns.firstIndex(
                        where: {
                            $0.id == campaign.id
                        }
                    )
            else {
                return false
            }

            var updatedCampaign = campaign
            updatedCampaign.updatedAt = Date()
            campaigns[index] = updatedCampaign
            Self.sortCampaigns(&campaigns)
            return true
        }
    }


    // MARK: - Delete

    @discardableResult
    func deleteCampaign(
        id: UUID
    ) -> ZhuowangStoreMutationResult {
        guard
            persistenceState.allowsMutations,
            baselineData != nil
        else {
            return .rejected(
                failureForCurrentState
            )
        }

        return transact(
            rejectedMutationFailure: .itemNotFound
        ) { campaigns in
            guard
                let index =
                    campaigns.firstIndex(
                        where: { $0.id == id }
                    )
            else {
                return false
            }

            campaigns.remove(at: index)
            return true
        }
    }


    @discardableResult
    func deleteCampaign(
        _ campaign: ZhuowangCampaign
    ) -> ZhuowangStoreMutationResult {
        deleteCampaign(id: campaign.id)
    }


    // MARK: - Find Campaign

    func campaign(
        id: UUID
    ) -> ZhuowangCampaign? {
        campaigns.first { $0.id == id }
    }


    // MARK: - Filtering

    func campaigns(
        forProvinceID provinceID: UUID
    ) -> [ZhuowangCampaign] {
        campaigns.filter {
            $0.scopeType == .province
            && $0.provinceID == provinceID
        }
    }


    func campaigns(
        forModuleID moduleID: String
    ) -> [ZhuowangCampaign] {
        campaigns.filter {
            $0.moduleID == moduleID
        }
    }


    func campaigns(
        withStatus status:
            ZhuowangCampaignStatus
    ) -> [ZhuowangCampaign] {
        campaigns.filter {
            $0.status == status
        }
    }


    func campaigns(
        forProvinceID provinceID: UUID,
        status: ZhuowangCampaignStatus
    ) -> [ZhuowangCampaign] {
        campaigns.filter {
            $0.scopeType == .province
            && $0.provinceID == provinceID
            && $0.status == status
        }
    }


    func campaigns(
        forModuleID moduleID: String,
        status: ZhuowangCampaignStatus
    ) -> [ZhuowangCampaign] {
        campaigns.filter {
            $0.moduleID == moduleID
            && $0.status == status
        }
    }


    // MARK: - Counts

    var totalCount: Int {
        campaigns.count
    }


    var activeCount: Int {
        campaigns.filter {
            $0.status == .active
        }
        .count
    }


    var planningCount: Int {
        campaigns.filter {
            $0.status == .planning
        }
        .count
    }


    var pendingLaunchCount: Int {
        campaigns.filter {
            $0.status == .pendingLaunch
        }
        .count
    }


    // MARK: - Persistence

    private func load() {
        switch persistence.loadOrInitialize(
            defaultValue: []
        ) {
        case .loaded(
            var value,
            let baselineData
        ):
            Self.sortCampaigns(&value)
            campaigns = value
            self.baselineData = baselineData
            persistenceState = .healthy

        case .lockedCorruptPrimary(
            let hasValidBackup
        ):
            campaigns = []
            baselineData = nil
            persistenceState =
                .lockedCorruptPrimary(
                    hasValidBackup:
                        hasValidBackup
                )

        case .writeVerificationFailed:
            campaigns = []
            baselineData = nil
            persistenceState =
                .writeVerificationFailed
        }
    }


    private func transact(
        rejectedMutationFailure:
            ZhuowangStoreMutationFailure = .invalidInput,
        mutation:
            (inout [ZhuowangCampaign]) -> Bool
    ) -> ZhuowangStoreMutationResult {
        guard
            persistenceState.allowsMutations,
            let baselineData
        else {
            return .rejected(
                failureForCurrentState
            )
        }

        switch persistence.transact(
            baselineData: baselineData,
            mutate: mutation
        ) {
        case .committed(
            let value,
            let newBaselineData
        ):
            campaigns = value
            self.baselineData = newBaselineData
            persistenceState = .healthy
            return .succeeded

        case .rejectedMutation:
            return .rejected(
                rejectedMutationFailure
            )

        case .lockedCorruptPrimary(
            let hasValidBackup
        ):
            persistenceState =
                .lockedCorruptPrimary(
                    hasValidBackup:
                        hasValidBackup
                )
            return .rejected(
                .lockedCorruptPrimary(
                    hasValidBackup:
                        hasValidBackup
                )
            )

        case .staleConflict:
            persistenceState = .staleConflict
            return .rejected(.staleConflict)

        case .writeVerificationFailed:
            persistenceState =
                .writeVerificationFailed
            return .rejected(
                .writeVerificationFailed
            )
        }
    }


    private var failureForCurrentState:
        ZhuowangStoreMutationFailure {
        switch persistenceState {
        case .healthy:
            return .writeVerificationFailed

        case .lockedCorruptPrimary(
            let hasValidBackup
        ):
            return .lockedCorruptPrimary(
                hasValidBackup:
                    hasValidBackup
            )

        case .staleConflict:
            return .staleConflict

        case .writeVerificationFailed:
            return .writeVerificationFailed
        }
    }


    private static func sortCampaigns(
        _ campaigns: inout [ZhuowangCampaign]
    ) {
        campaigns.sort {
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt > $1.updatedAt
            }

            return $0.createdAt > $1.createdAt
        }
    }
}
