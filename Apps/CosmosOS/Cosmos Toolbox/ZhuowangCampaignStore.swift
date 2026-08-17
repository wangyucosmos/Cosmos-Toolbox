import Foundation
import Combine

final class ZhuowangCampaignStore: ObservableObject {

    @Published
    private(set) var campaigns: [ZhuowangCampaign] = []

    private let storageKey =
        "cosmos.zhuowang.campaigns.v1"


    // MARK: - Init

    init() {
        load()
    }


    // MARK: - Create

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
    ) {

        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty else {
            return
        }

        let cleanEnglishName =
            englishName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanNotes =
            notes.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let campaign =
            ZhuowangCampaign(
                name: cleanName,
                englishName: cleanEnglishName,
                scopeType: scopeType,
                provinceID: provinceID,
                moduleID: moduleID,
                startDate: startDate,
                endDate: endDate,
                status: status,
                notes: cleanNotes
            )

        campaigns.append(campaign)

        sortCampaigns()

        save()
    }


    // MARK: - Update

    func updateCampaign(
        _ campaign: ZhuowangCampaign
    ) {

        guard
            let index =
                campaigns.firstIndex(
                    where: {
                        $0.id == campaign.id
                    }
                )
        else {
            return
        }

        var updatedCampaign = campaign
        updatedCampaign.updatedAt = Date()

        campaigns[index] =
            updatedCampaign

        sortCampaigns()

        save()
    }


    // MARK: - Delete

    func deleteCampaign(
        id: UUID
    ) {

        campaigns.removeAll {
            $0.id == id
        }

        save()
    }


    func deleteCampaign(
        _ campaign: ZhuowangCampaign
    ) {

        deleteCampaign(
            id: campaign.id
        )
    }


    // MARK: - Find Campaign

    func campaign(
        id: UUID
    ) -> ZhuowangCampaign? {

        campaigns.first {
            $0.id == id
        }
    }


    // MARK: - Province Filtering

    func campaigns(
        forProvinceID provinceID: UUID
    ) -> [ZhuowangCampaign] {

        campaigns.filter {

            $0.scopeType == .province
            && $0.provinceID == provinceID
        }
    }


    // MARK: - Module Filtering

    func campaigns(
        forModuleID moduleID: String
    ) -> [ZhuowangCampaign] {

        campaigns.filter {
            $0.moduleID == moduleID
        }
    }


    // MARK: - Status Filtering

    func campaigns(
        withStatus status:
            ZhuowangCampaignStatus
    ) -> [ZhuowangCampaign] {

        campaigns.filter {
            $0.status == status
        }
    }


    // MARK: - Province + Status

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


    // MARK: - Module + Status

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

    private func save() {

        guard
            let data =
                try? JSONEncoder()
                .encode(campaigns)
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
            let savedCampaigns =
                try? JSONDecoder()
                .decode(
                    [ZhuowangCampaign].self,
                    from: data
                )
        else {
            campaigns = []
            return
        }

        campaigns =
            savedCampaigns

        sortCampaigns()
    }


    // MARK: - Sorting

    private func sortCampaigns() {

        campaigns.sort {

            if $0.updatedAt
                != $1.updatedAt {

                return $0.updatedAt
                    > $1.updatedAt
            }

            return $0.createdAt
                > $1.createdAt
        }
    }
}
