import Foundation
import Combine

final class ZhuowangWorkspaceStore: ObservableObject {

    @Published
    private(set) var modules: [ZhuowangModule] = []

    @Published
    private(set) var provinces: [ZhuowangProvince] = []

    @Published
    private(set) var categories: [ZhuowangCategory] = []

    @Published
    private(set) var persistenceState:
        ZhuowangStorePersistenceState = .healthy

    static let storageKey =
        "cosmos.zhuowang.workspace.v1"

    static let backupKey =
        "cosmos.zhuowang.workspace.v1.backup"

    let persistenceConfiguration:
        ZhuowangStorePersistenceConfiguration

    private let persistence:
        ZhuowangProtectedPersistence<ZhuowangWorkspaceSnapshot>

    private var baselineData: Data?


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


    // MARK: - Add Province

    @discardableResult
    func addProvince(
        name: String,
        englishName: String
    ) -> ZhuowangStoreMutationResult {
        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard persistenceState.allowsMutations else {
            return lockedMutationResult
        }

        guard !cleanName.isEmpty else {
            return .rejected(.invalidInput)
        }

        let cleanEnglish =
            englishName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let province =
            ZhuowangProvince(
                id: UUID(),
                name: cleanName,
                englishName:
                    cleanEnglish.isEmpty
                    ? cleanName
                    : cleanEnglish
            )

        return transact { snapshot in
            var provinces = snapshot.provinces
            provinces.append(province)
            snapshot = ZhuowangWorkspaceSnapshot(
                modules: snapshot.modules,
                provinces: provinces,
                categories: snapshot.categories
            )
            return true
        }
    }


    // MARK: - Add Category

    @discardableResult
    func addCategory(
        name: String,
        englishName: String
    ) -> ZhuowangStoreMutationResult {
        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard persistenceState.allowsMutations else {
            return lockedMutationResult
        }

        guard !cleanName.isEmpty else {
            return .rejected(.invalidInput)
        }

        let cleanEnglish =
            englishName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let category =
            ZhuowangCategory(
                id:
                    "custom-\(UUID().uuidString)",
                name: cleanName,
                englishName:
                    cleanEnglish.isEmpty
                    ? cleanName
                    : cleanEnglish,
                icon: "folder"
            )

        return transact { snapshot in
            var categories = snapshot.categories
            categories.append(category)
            snapshot = ZhuowangWorkspaceSnapshot(
                modules: snapshot.modules,
                provinces: snapshot.provinces,
                categories: categories
            )
            return true
        }
    }


    // MARK: - Add Module

    @discardableResult
    func addModule(
        name: String,
        englishName: String,
        usesProvinces: Bool
    ) -> ZhuowangStoreMutationResult {
        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard persistenceState.allowsMutations else {
            return lockedMutationResult
        }

        guard !cleanName.isEmpty else {
            return .rejected(.invalidInput)
        }

        let cleanEnglish =
            englishName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let module =
            ZhuowangModule(
                id:
                    "custom-\(UUID().uuidString)",
                name: cleanName,
                englishName:
                    cleanEnglish.isEmpty
                    ? cleanName
                    : cleanEnglish,
                icon:
                    "square.grid.2x2",
                usesProvinces:
                    usesProvinces
            )

        return transact { snapshot in
            var modules = snapshot.modules
            modules.append(module)
            snapshot = ZhuowangWorkspaceSnapshot(
                modules: modules,
                provinces: snapshot.provinces,
                categories: snapshot.categories
            )
            return true
        }
    }


    // MARK: - Update Module

    @discardableResult
    func updateModule(
        _ module: ZhuowangModule
    ) -> ZhuowangStoreMutationResult {
        guard persistenceState.allowsMutations else {
            return lockedMutationResult
        }

        let cleanName =
            module.name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty else {
            return .rejected(.invalidInput)
        }

        let cleanEnglish =
            module.englishName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        var updatedModule = module
        updatedModule.name = cleanName
        updatedModule.englishName =
            cleanEnglish.isEmpty
            ? cleanName
            : cleanEnglish

        return transact(
            rejectedMutationFailure: .itemNotFound
        ) { snapshot in
            guard
                let index =
                    snapshot.modules.firstIndex(
                        where: {
                            $0.id == module.id
                        }
                    )
            else {
                return false
            }

            var modules = snapshot.modules
            modules[index] = updatedModule
            snapshot = ZhuowangWorkspaceSnapshot(
                modules: modules,
                provinces: snapshot.provinces,
                categories: snapshot.categories
            )
            return true
        }
    }


    // MARK: - Delete Module

    @discardableResult
    func deleteModule(
        id: String
    ) -> ZhuowangStoreMutationResult {
        guard persistenceState.allowsMutations else {
            return lockedMutationResult
        }

        return transact(
            rejectedMutationFailure: .itemNotFound
        ) { snapshot in
            guard
                let index =
                    snapshot.modules.firstIndex(
                        where: { $0.id == id }
                    )
            else {
                return false
            }

            var modules = snapshot.modules
            modules.remove(at: index)
            snapshot = ZhuowangWorkspaceSnapshot(
                modules: modules,
                provinces: snapshot.provinces,
                categories: snapshot.categories
            )
            return true
        }
    }


    @discardableResult
    func deleteModule(
        _ module: ZhuowangModule
    ) -> ZhuowangStoreMutationResult {
        deleteModule(id: module.id)
    }


    // MARK: - Persistence

    private func load() {
        switch persistence.loadOrInitialize(
            defaultValue: Self.defaultSnapshot
        ) {
        case .loaded(
            let snapshot,
            let baselineData
        ):
            publish(snapshot)
            self.baselineData = baselineData
            persistenceState = .healthy

        case .lockedCorruptPrimary(
            let hasValidBackup
        ):
            clearPublishedState()
            baselineData = nil
            persistenceState =
                .lockedCorruptPrimary(
                    hasValidBackup:
                        hasValidBackup
                )

        case .writeVerificationFailed:
            clearPublishedState()
            baselineData = nil
            persistenceState =
                .writeVerificationFailed
        }
    }


    private func transact(
        rejectedMutationFailure:
            ZhuowangStoreMutationFailure = .invalidInput,
        mutation:
            (inout ZhuowangWorkspaceSnapshot) -> Bool
    ) -> ZhuowangStoreMutationResult {
        guard
            persistenceState.allowsMutations,
            let baselineData
        else {
            return lockedMutationResult
        }

        switch persistence.transact(
            baselineData: baselineData,
            mutate: mutation
        ) {
        case .committed(
            let snapshot,
            let newBaselineData
        ):
            publish(snapshot)
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


    private func publish(
        _ snapshot: ZhuowangWorkspaceSnapshot
    ) {
        modules = snapshot.modules
        provinces = snapshot.provinces
        categories = snapshot.categories
    }


    private func clearPublishedState() {
        modules = []
        provinces = []
        categories = []
    }


    private var lockedMutationResult:
        ZhuowangStoreMutationResult {
        switch persistenceState {
        case .healthy:
            return .rejected(
                .writeVerificationFailed
            )

        case .lockedCorruptPrimary(
            let hasValidBackup
        ):
            return .rejected(
                .lockedCorruptPrimary(
                    hasValidBackup:
                        hasValidBackup
                )
            )

        case .staleConflict:
            return .rejected(.staleConflict)

        case .writeVerificationFailed:
            return .rejected(
                .writeVerificationFailed
            )
        }
    }


    private static var defaultSnapshot:
        ZhuowangWorkspaceSnapshot {
        ZhuowangWorkspaceSnapshot(
            modules: defaultModules,
            provinces: defaultProvinces,
            categories: defaultCategories
        )
    }


    // MARK: - Default Modules

    private static let defaultModules: [
        ZhuowangModule
    ] = [

        ZhuowangModule(
            id: "welfare",
            name: "福利中心",
            englishName: "Welfare Center",
            icon: "gift",
            usesProvinces: true
        ),

        ZhuowangModule(
            id: "national",
            name: "全国促活",
            englishName: "National Campaign",
            icon: "globe.asia.australia",
            usesProvinces: false
        ),

        ZhuowangModule(
            id: "quiz",
            name: "竞猜专题",
            englishName: "Quiz Campaign",
            icon: "sportscourt",
            usesProvinces: false
        ),

        ZhuowangModule(
            id: "shared",
            name: "公共资料",
            englishName: "Shared Resources",
            icon: "books.vertical",
            usesProvinces: false
        ),

        ZhuowangModule(
            id: "templates",
            name: "工作模板",
            englishName: "Templates",
            icon: "square.stack.3d.up",
            usesProvinces: false
        )
    ]


    // MARK: - Default Provinces

    private static let defaultProvinces: [
        ZhuowangProvince
    ] = [

        ZhuowangProvince(
            id: UUID(
                uuidString: "10000000-0000-0000-0000-000000000001"
            )!,
            name: "河南",
            englishName: "Henan"
        ),

        ZhuowangProvince(
            id: UUID(
                uuidString: "10000000-0000-0000-0000-000000000002"
            )!,
            name: "安徽",
            englishName: "Anhui"
        ),

        ZhuowangProvince(
            id: UUID(
                uuidString: "10000000-0000-0000-0000-000000000003"
            )!,
            name: "浙江",
            englishName: "Zhejiang"
        ),

        ZhuowangProvince(
            id: UUID(
                uuidString: "10000000-0000-0000-0000-000000000004"
            )!,
            name: "海南",
            englishName: "Hainan"
        ),

        ZhuowangProvince(
            id: UUID(
                uuidString: "10000000-0000-0000-0000-000000000005"
            )!,
            name: "广东",
            englishName: "Guangdong"
        ),

        ZhuowangProvince(
            id: UUID(
                uuidString: "10000000-0000-0000-0000-000000000006"
            )!,
            name: "贵州",
            englishName: "Guizhou"
        )
    ]


    // MARK: - Default Categories

    private static let defaultCategories: [
        ZhuowangCategory
    ] = [

        ZhuowangCategory(
            id: "overview",
            name: "总览",
            englishName: "Overview",
            icon: "square.grid.2x2"
        ),

        ZhuowangCategory(
            id: "campaign",
            name: "活动",
            englishName: "Campaign",
            icon: "megaphone"
        ),

        ZhuowangCategory(
            id: "popup",
            name: "弹窗",
            englishName: "Popup",
            icon:
                "rectangle.portrait"
        ),

        ZhuowangCategory(
            id: "banner",
            name: "Banner",
            englishName: "Banner",
            icon:
                "rectangle.on.rectangle"
        ),

        ZhuowangCategory(
            id: "faq",
            name: "客服文档",
            englishName: "FAQ",
            icon: "headphones"
        ),

        ZhuowangCategory(
            id: "prompt",
            name: "提示词",
            englishName: "Prompt",
            icon: "text.quote"
        ),

        ZhuowangCategory(
            id: "flow",
            name: "流程图",
            englishName: "Flow",
            icon:
                "point.3.connected.trianglepath.dotted"
        ),

        ZhuowangCategory(
            id: "prototype",
            name: "原型",
            englishName: "Prototype",
            icon: "macwindow"
        ),

        ZhuowangCategory(
            id: "asset",
            name: "素材",
            englishName: "Assets",
            icon: "photo.on.rectangle"
        )
    ]
}
