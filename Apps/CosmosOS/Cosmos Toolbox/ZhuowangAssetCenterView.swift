import SwiftUI

struct ZhuowangAssetCenterView: View {
    var fixedScope: ZhuowangAssetFilter? = nil
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

    init(model: ZhuowangAssetCatalogViewModel, fixedScope: ZhuowangAssetFilter? = nil) {
        _model = StateObject(wrappedValue: model)
        self.fixedScope = fixedScope
    }

    private var scopeReady: Bool {
        guard let scope = fixedScope else { return true }
        return model.filter.provinceID == scope.provinceID
            && model.filter.moduleID == scope.moduleID
            && model.filter.stepKind == scope.stepKind
            && (scope.type == nil || model.filter.type == scope.type)
    }

    private var scopedEntries: [ZhuowangAssetEntry] {
        var filter = model.filter
        filter.allVersions = true
        return model.entries.filter(filter.includes)
    }

    var body: some View {
        Group {
            if scopeReady { catalogContent }
            else { ProgressView("正在切换检索范围…") }
        }
        .onAppear { applyScope() }
        .onChange(of: fixedScope) { _, _ in applyScope() }
    }

    private func applyScope() {
        if let fixedScope { model.filter = fixedScope }
        model.refresh()
    }

    private func assetIcon(_ type: ZhuowangArtifactType) -> String {
        switch type {
        case .image: return "photo"
        case .html: return "safari"
        case .pdf: return "doc.richtext"
        case .flowchart: return "point.3.connected.trianglepath.dotted"
        default: return "doc.text"
        }
    }

    private var filterBinding: Binding<ZhuowangAssetFilter> {
        Binding(get: { model.filter }, set: { model.filter = ZhuowangAssetFilterControls.constrained($0, to: fixedScope) })
    }

    private var filterControls: some View {
        HStack(spacing: 10) {
            Menu {
                Picker("版本", selection: filterBinding.allVersions) {
                    Text("当前采用").tag(false)
                    Text("全部版本").tag(true)
                }.pickerStyle(.menu)
                if fixedScope == nil {
                    Picker("省份", selection: filterBinding.provinceID) {
                        Text("全部省份 / 全国及其他").tag(Optional<UUID>.none)
                        ForEach(model.provinces) { Text($0.isEnabled ? $0.name : $0.name + "（已停用）").tag(Optional($0.id)) }
                    }.pickerStyle(.menu)
                }
                if fixedScope?.campaignID == nil {
                    Picker("活动", selection: filterBinding.campaignID) {
                        Text("全部活动").tag(Optional<UUID>.none)
                        ForEach(model.campaigns.filter { campaign in
                            fixedScope.map { scope in
                                (scope.provinceID == nil || campaign.provinceID == scope.provinceID)
                                && (scope.moduleID == nil || (campaign.provinceID == nil && campaign.moduleID == scope.moduleID))
                            } ?? true
                        }) { Text($0.name).tag(Optional($0.id)) }
                    }.pickerStyle(.menu)
                }
                Picker("类型", selection: filterBinding.type) {
                    Text("全部类型").tag(Optional<ZhuowangArtifactType>.none)
                    ForEach(ZhuowangArtifactType.allCases) { Text($0.title).tag(Optional($0)) }
                }.pickerStyle(.menu).disabled(fixedScope?.type != nil)
            } label: {
                Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
            }
            .accessibilityIdentifier("asset-filter-menu")
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    if model.filter.allVersions { Label("全部版本", systemImage: "square.stack") }
                    if let id = model.filter.provinceID {
                        Label(model.provinces.first { $0.id == id }?.name ?? "指定省份", systemImage: "mappin")
                    }
                    if let id = model.filter.campaignID {
                        Label(model.campaigns.first { $0.id == id }?.name ?? "指定活动", systemImage: "megaphone")
                    }
                    if let type = model.filter.type { Label(type.title, systemImage: assetIcon(type)) }
                    if model.filter.moduleID != nil { Label("固定模块", systemImage: "building.2") }
                    if model.filter.stepKind != nil { Label("固定步骤", systemImage: "list.number") }
                    if !model.filter.query.isEmpty { Label("搜索条件", systemImage: "magnifyingglass") }
                }.font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }.scrollIndicators(.hidden)
            Button("清除筛选") { model.filter = ZhuowangAssetFilterControls.reset(fixedScope: fixedScope) }
                .buttonStyle(.borderless)
                .disabled(model.filter == ZhuowangAssetFilterControls.reset(fixedScope: fixedScope))
                .accessibilityIdentifier("asset-filter-clear")
        }
    }

    private var catalogContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            CosmosPageHeader("知识与资产", subtitle: "已管理的工作产物 · 只读检索与复用",
                info: "仅检索现有元数据和受支持文本正文；不扫描、恢复、导入或修改采用版本。单份正文读取上限仍为 2 MiB。") {
                Button { model.refresh() } label: { Label("刷新", systemImage: "arrow.clockwise") }.buttonStyle(.bordered)
            }
            TextField("搜索产物名称、活动名或 Markdown / 纯文本正文", text: $model.filter.query)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("asset-search")
            filterControls
            if model.error == nil && !model.loading {
                HStack {
                    let unadopted = Set(scopedEntries.filter { $0.adoptedCount == 0 }.map(\.groupID)).count
                    let conflicts = Set(scopedEntries.filter { $0.adoptedCount > 1 }.map(\.groupID)).count
                    Button("未采用组 \(unadopted) · 查看全部版本") { model.filter.allVersions = true }
                        .buttonStyle(.link)
                    Text("采用冲突 \(conflicts) 组").foregroundStyle(conflicts > 0 ? .orange : .secondary)
                    Spacer()
                    Text("\(model.matches.count) 个版本").foregroundStyle(.secondary)
                }
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
                                Image(systemName: assetIcon(match.entry.artifact.type)).foregroundStyle(Color.accentColor).frame(width: 24)
                                Text(match.entry.artifact.name).font(.headline)
                                Text("V\(match.entry.artifact.version)")
                                Text(match.entry.adoptionLabel).foregroundStyle(match.entry.adoptedCount > 1 ? .orange : .secondary)
                                Spacer()
                                Text(match.entry.artifact.type.title).foregroundStyle(.secondary)
                            }
                            Text("\(match.entry.scopeName) · \(match.entry.campaignName) · \(match.entry.stepName)")
                                .font(.caption).foregroundStyle(.secondary)
                            if let snippet = match.snippet { Text(snippet).font(.callout).lineLimit(3) }
                        }.padding(12).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }.frame(minHeight: 240).listStyle(.plain).scrollContentBackground(.hidden).accessibilityIdentifier("asset-results")
            }
        }
        .padding(24)
        .frame(minWidth: 440, minHeight: 420)
    }
}

/// UI bindings preserve the caller's fixed dimensions without changing catalog filtering.
enum ZhuowangAssetFilterControls {
    static func constrained(_ candidate: ZhuowangAssetFilter, to scope: ZhuowangAssetFilter?) -> ZhuowangAssetFilter {
        guard let scope else { return candidate }
        var value = candidate
        value.provinceID = scope.provinceID
        value.moduleID = scope.moduleID
        value.stepKind = scope.stepKind
        if let type = scope.type { value.type = type }
        if let campaignID = scope.campaignID { value.campaignID = campaignID }
        return value
    }

    static func reset(fixedScope: ZhuowangAssetFilter?) -> ZhuowangAssetFilter {
        fixedScope ?? ZhuowangAssetFilter()
    }
}
