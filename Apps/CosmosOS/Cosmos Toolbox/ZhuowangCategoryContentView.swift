import SwiftUI

/// Category names remain editable; only the established IDs define meaning.
enum ZhuowangCategoryRoute: Equatable {
    case assets(step: ZhuowangWorkflowStepKind?, type: ZhuowangArtifactType?)
    case promptVault
    case unsupported

    init(categoryID: String) {
        switch categoryID {
        case "faq": self = .assets(step: .customerService, type: nil)
        case "prototype": self = .assets(step: .prototype, type: nil)
        case "flow": self = .assets(step: nil, type: .flowchart)
        case "asset": self = .assets(step: nil, type: .image)
        case "prompt": self = .promptVault
        default: self = .unsupported
        }
    }

    var explanation: String {
        switch self {
        case .assets(step: .customerService, type: _):
            return "仅检索当前范围已关联客服文档步骤（customerService / Step06）的产物，不创建文档或执行 AI。"
        case .assets(step: .prototype, type: _):
            return "仅检索当前范围已关联原型步骤（prototype / Step05、prototypeDesign）的产物，包含不同工具生成的原型，不绑定 Figma。"
        case .assets(step: _, type: .flowchart):
            return "仅检索当前范围元数据类型为「流程图」的已管理产物，不按名称或文件扩展名推断。"
        case .assets(step: _, type: .image):
            return "本期素材仅检索当前范围元数据类型为「图片」的已管理产物；其他素材尚未归类，不扫描目录或把全部产物当作素材。"
        case .promptVault:
            return "提示词由全局 Prompt Vault 管理，不属于当前省份或模块的专属资产。"
        default:
            return "现有已管理产物没有该分类的可靠归属依据，本期不支持检索或创建。分类配置及已有数据保留，未扫描目录或迁移数据。"
        }
    }

    func filter(provinceID: UUID?, moduleID: String?) -> ZhuowangAssetFilter? {
        guard case let .assets(step, type) = self,
              provinceID != nil || moduleID != nil else { return nil }
        var filter = ZhuowangAssetFilter()
        filter.provinceID = provinceID
        filter.moduleID = provinceID == nil ? moduleID : nil
        filter.stepKind = step
        filter.type = type
        return filter
    }
}

struct ZhuowangCategoryContentView: View {
    let category: ZhuowangCategory?
    let categoryID: String
    let scopeName: String
    let provinceID: UUID?
    let moduleID: String?
    @ObservedObject var model: ZhuowangAssetCatalogViewModel
    let openPromptVault: () -> Void

    var body: some View {
        let route = ZhuowangCategoryRoute(categoryID: categoryID)
        VStack(alignment: .leading, spacing: CosmosDesign.spacingM) {
            CosmosSectionTitle(title: category?.name ?? "内容", subtitle: category?.englishName ?? "Content")
            Text(route.explanation).font(.callout).foregroundStyle(.secondary)
            switch route {
            case .assets:
                if let filter = route.filter(provinceID: provinceID, moduleID: moduleID) {
                    Text(scopeName + " · 当前范围").font(.headline)
                    ZhuowangAssetCenterView(model: model, fixedScope: filter)
                        .id(categoryID + "::" + (provinceID?.uuidString ?? moduleID ?? ""))
                } else {
                    ContentUnavailableView("当前范围不可用", systemImage: "exclamationmark.triangle",
                        description: Text("请重新选择现有省份或业务模块；未显示其他范围的资产。"))
                }
            case .promptVault:
                Button("打开全局提示词库", systemImage: "text.quote", action: openPromptVault)
                    .accessibilityIdentifier("category-prompt-vault")
            case .unsupported:
                ContentUnavailableView("该分类暂未接入", systemImage: "rectangle.dashed",
                    description: Text("这不是空资产结果。当前没有可用的分类检索或创建入口。"))
                    .accessibilityIdentifier("category-unsupported")
            }
        }
    }
}
