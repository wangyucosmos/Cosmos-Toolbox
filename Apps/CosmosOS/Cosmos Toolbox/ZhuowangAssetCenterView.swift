import SwiftUI

struct ZhuowangAssetCenterView: View {
    @StateObject private var model: ZhuowangAssetCatalogViewModel

    init(configuration: ZhuowangStorePersistenceConfiguration, isolatedRoot: URL? = nil) {
#if DEBUG
        let requiresRoot = configuration.isIsolated
#else
        let requiresRoot = false
#endif
        _model = StateObject(wrappedValue: ZhuowangAssetCatalogViewModel(
            dataSource: configuration.dataSource, allowedRoot: isolatedRoot, requiresIsolatedRoot: requiresRoot))
    }

    init(model: ZhuowangAssetCatalogViewModel) { _model = StateObject(wrappedValue: model) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("知识与资产中心").font(.largeTitle)
                    Text("来源：Cosmos OS 已管理的卓望资产 · 只读检索与复用").foregroundStyle(.secondary)
                }
                Spacer()
                Button("刷新", systemImage: "arrow.clockwise") { model.refresh() }
            }
            TextField("搜索产物名称、活动名或 Markdown / 纯文本正文", text: $model.filter.query)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("asset-search")
            HStack {
                Picker("版本", selection: $model.filter.allVersions) {
                    Text("当前采用").tag(false)
                    Text("全部版本").tag(true)
                }.frame(width: 200)
                Picker("省份", selection: $model.filter.provinceID) {
                    Text("全部省份 / 全国及其他").tag(Optional<UUID>.none)
                    ForEach(model.provinces) { Text($0.isEnabled ? $0.name : $0.name + "（已停用）").tag(Optional($0.id)) }
                }
                Picker("活动", selection: $model.filter.campaignID) {
                    Text("全部活动").tag(Optional<UUID>.none)
                    ForEach(model.campaigns) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("类型", selection: $model.filter.type) {
                    Text("全部类型").tag(Optional<ZhuowangArtifactType>.none)
                    ForEach(ZhuowangArtifactType.allCases) { Text($0.title).tag(Optional($0)) }
                }
            }
            HStack {
                Button("未采用组 \(model.unadoptedGroupCount) · 查看全部版本") { model.filter.allVersions = true }
                    .buttonStyle(.link)
                Text("采用冲突 \(model.conflictGroupCount) 组").foregroundStyle(model.conflictGroupCount > 0 ? .orange : .secondary)
                Spacer()
                Text("\(model.matches.count) 个版本").foregroundStyle(.secondary)
            }
            ForEach(model.notices, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
            if let error = model.error {
                ContentUnavailableView("资产数据读取异常", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if model.loading {
                ProgressView("正在核对正文并检索…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.matches.isEmpty {
                ContentUnavailableView("没有匹配的资产", systemImage: "magnifyingglass",
                    description: Text("可调整筛选或查看全部版本。文件未被扫描、导入或恢复。"))
            } else {
                List(model.matches) { match in
                    Button {
                        ZhuowangAssetDetailWindowManager.shared.open(model: model, entry: match.entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(match.entry.artifact.name).font(.headline)
                                Text("V\(match.entry.artifact.version)")
                                Text(match.entry.adoptionLabel).foregroundStyle(match.entry.adoptedCount > 1 ? .orange : .secondary)
                                Spacer()
                                Text(match.entry.artifact.type.title).foregroundStyle(.secondary)
                            }
                            Text("\(match.entry.scopeName) · \(match.entry.campaignName) · \(match.entry.stepName)")
                                .font(.caption).foregroundStyle(.secondary)
                            if let snippet = match.snippet { Text(snippet).font(.callout).lineLimit(3) }
                        }.padding(.vertical, 6).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }.accessibilityIdentifier("asset-results")
            }
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 560)
        .onAppear { model.refresh() }
    }
}
