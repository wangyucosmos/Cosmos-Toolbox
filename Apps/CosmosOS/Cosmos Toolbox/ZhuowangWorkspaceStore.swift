import Foundation
import Combine

final class ZhuowangWorkspaceStore: ObservableObject {

    @Published
    var modules: [ZhuowangModule]

    @Published
    var provinces: [ZhuowangProvince]

    @Published
    var categories: [ZhuowangCategory]

    private let storageKey =
        "cosmos.zhuowang.workspace.v1"

    init() {
        self.modules = Self.defaultModules
        self.provinces = Self.defaultProvinces
        self.categories = Self.defaultCategories

        load()

        // 第一次启动时也立即保存默认工作区，
        // 确保省份 UUID 后续启动保持一致。
        save()
    }


    // MARK: - Add Province

    func addProvince(
        name: String,
        englishName: String
    ) {
        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty else {
            return
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

        provinces.append(province)

        save()
    }


    // MARK: - Add Category

    func addCategory(
        name: String,
        englishName: String
    ) {
        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty else {
            return
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

        categories.append(category)

        save()
    }


    // MARK: - Add Module

    func addModule(
        name: String,
        englishName: String,
        usesProvinces: Bool
    ) {
        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanName.isEmpty else {
            return
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

        modules.append(module)

        save()
    }


    // MARK: - Persistence

    private func save() {
        let snapshot =
            ZhuowangWorkspaceSnapshot(
                modules: modules,
                provinces: provinces,
                categories: categories
            )

        guard
            let data =
                try? JSONEncoder()
                .encode(snapshot)
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
            let snapshot =
                try? JSONDecoder()
                .decode(
                    ZhuowangWorkspaceSnapshot.self,
                    from: data
                )
        else {
            return
        }

        modules =
            snapshot.modules

        provinces =
            snapshot.provinces

        categories =
            snapshot.categories
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
