import SwiftUI

struct PromptVaultView: View {
    @StateObject private var store: PromptVaultStore
    @StateObject private var model = PromptVaultViewModel()
    @State private var pendingRestore: PromptVersionEntry?
    init(location: PromptVaultLocation) {
        _store = StateObject(wrappedValue: PromptVaultStore(root: location.root, startupError: location.error))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("提示词库").font(.largeTitle)
                Spacer()
                Button("新建模板", systemImage: "plus") { PromptTemplateWindowManager.shared.open(store: store, template: nil) }
                    .disabled(!store.canSave).accessibilityIdentifier("prompt-new")
                Button("刷新", systemImage: "arrow.clockwise") { Task { await store.reload() } }.disabled(store.saving)
            }
            Text("个人模板 · 填写变量不会修改原始模板，也不会保存变量值。")
                .foregroundStyle(.secondary).font(.callout)
            if let error = store.error {
                Text(error.localizedDescription).foregroundStyle(.orange).textSelection(.enabled)
            }
            if store.loading { ProgressView("正在读取提示词库…") }
            HStack {
                TextField("搜索名称或正文", text: $model.query).accessibilityIdentifier("prompt-search")
                Toggle("仅收藏", isOn: $model.favoritesOnly)
                Toggle("查看归档", isOn: $model.showArchived)
            }
            ViewThatFits(in: .horizontal) {
                HSplitView {
                    categories.frame(minWidth: 120, idealWidth: 140, maxWidth: 180)
                    content.frame(minWidth: 660)
                }.frame(minWidth: 820)
                VStack(alignment: .leading) {
                    Picker("分类", selection: $model.category) {
                        Text("全部分类").tag("")
                        ForEach(categoryNames, id: \.self) { Text($0).tag($0) }
                    }.frame(maxWidth: 240)
                    content
                }
            }
        }
        .padding(24)
        .task { await store.reload() }
        .onChange(of: store.templates) { _, templates in model.reconcile(templates) }
        .onDisappear { model.clearSession() }
    }
    private var categoryNames: [String] {
        Array(Set(store.templates.map { $0.category ?? "未分类" })).sorted()
    }
    private var categories: some View {
        List(selection: $model.category) {
            Text("全部分类").tag("")
            ForEach(categoryNames, id: \.self) { Text($0).tag($0) }
        }
    }
    private var content: some View {
        HSplitView {
            VStack {
                if model.filtered(store.templates).isEmpty {
                    ContentUnavailableView(store.templates.isEmpty ? "创建第一份提示词模板" : "没有匹配的模板",
                        systemImage: "text.book.closed", description: Text("模板由你创建；可调整搜索、分类、收藏或归档筛选。"))
                } else {
                    List(selection: $model.selectedID) {
                        ForEach(model.filtered(store.templates)) { template in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(template.name).fontWeight(.medium)
                                    if template.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                                }
                                Text(template.category ?? "未分类").font(.caption).foregroundStyle(.secondary)
                            }.tag(template.id).accessibilityIdentifier("prompt-template-" + template.id.uuidString)
                        }
                    }
                }
            }.frame(minWidth: 180, idealWidth: 230, maxWidth: 300)
            if let template = store.templates.first(where: { $0.id == model.selectedID }) {
                detail(template).frame(minWidth: 360, maxWidth: .infinity)
            } else {
                ContentUnavailableView("选择一个模板开始使用", systemImage: "text.cursor",
                    description: Text("填写变量 → 完整预览 → 复制。"))
                    .frame(minWidth: 360, maxWidth: .infinity)
            }
        }
    }
    private func detail(_ template: PromptTemplate) -> some View {
        let renderer = PromptTemplateRenderer(template.body)
        let result = model.rendered(template)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(template.name).font(.title2)
                Text("\(template.category ?? "未分类") · 已保存 r\(template.revision)\(template.contentVersion.map { " · 内容 v\($0)" } ?? "")\(template.isArchived ? " · 已归档" : "")")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("编辑", systemImage: "square.and.pencil") {
                        PromptTemplateWindowManager.shared.open(store: store, template: template)
                    }.accessibilityIdentifier("prompt-edit")
                    Button(template.isFavorite ? "取消收藏" : "收藏", systemImage: "star") { Task { await store.setFavorite(template) } }
                    Button(template.isArchived ? "恢复归档" : "归档", systemImage: "archivebox") { Task { await store.setArchived(template) } }
                }.disabled(!store.canSave)
                if renderer.variables.isEmpty { Text("此模板没有需要填写的变量。").foregroundStyle(.secondary) }
                ForEach(renderer.variables) { variable in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(variable.name).font(.headline)
                        TextField("填写 \(variable.name)", text: Binding(
                            get: { model.values[template.id]?[variable.id] ?? "" },
                            set: { model.setValue($0, variable: variable, templateID: template.id) }), axis: .vertical)
                            .textFieldStyle(.roundedBorder).lineLimit(2...6)
                            .accessibilityIdentifier("prompt-variable-" + variable.id)
                    }
                }
                if !result.missing.isEmpty {
                    Text("待填写：" + result.missing.joined(separator: "、")).foregroundStyle(.orange)
                }
                ForEach(Array(result.warnings.enumerated()), id: \.offset) { _, warning in
                    Text(warning).font(.caption).foregroundStyle(.orange)
                }
                Text("完整提示词预览").font(.headline)
                Text(result.text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(.background).accessibilityIdentifier("prompt-preview")
                HStack {
                    Button("复制完整结果", systemImage: "doc.on.doc") { model.copyResult(template) }
                        .disabled(!result.canCopy).accessibilityIdentifier("prompt-copy-result")
                    Button("复制原始模板") { model.copyOriginal(template) }
                }
                Text(model.copyMessage).font(.caption).foregroundStyle(.secondary)
                Divider()
                history(template)
            }.padding(12)
        }
    }
    private static let timeText: Date.FormatStyle = .dateTime.year().month().day().hour().minute().second()
    private func timeLabel(_ entry: PromptVersionEntry, _ template: PromptTemplate) -> String {
        switch entry.kind {
        case .legacyCurrent: return "无独立记录时间 · 模板更新于 " + template.updatedAt.formatted(Self.timeText)
        case .upgradeBaseline: return (entry.recordedAt ?? template.updatedAt).formatted(Self.timeText) + "（沿用升级前的模板更新时间，非实际编辑时间）"
        default: return (entry.recordedAt ?? template.updatedAt).formatted(Self.timeText)
        }
    }
    private func history(_ template: PromptTemplate) -> some View {
        let entries = template.versionEntries, viewed = model.viewedEntry(of: template)
        return VStack(alignment: .leading, spacing: 8) {
            Text("版本历史").font(.headline)
            if template.versions.isEmpty {
                Text("此模板保存于版本历史功能之前：当前内容显示为「升级前当前内容」。首次修改内容并保存时，会连同旧内容一起保留；收藏与归档不产生内容版本。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                Button { model.viewEntry(entry, of: template) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.label).fontWeight(entry.isCurrent ? .semibold : .regular)
                            Text(entry.name).lineLimit(1)
                            Spacer()
                            if entry.id == viewed.id { Image(systemName: "eye") }
                        }
                        Text(timeLabel(entry, template)).font(.caption).foregroundStyle(.secondary)
                    }.contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(6)
                .background(entry.id == viewed.id ? Color.accentColor.opacity(0.12) : Color.clear)
                .accessibilityIdentifier("prompt-version-" + entry.id.uuidString)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("正在查看：\(viewed.label) · \(viewed.name) · \(viewed.category ?? "未分类")").font(.subheadline)
                Text(viewed.body).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.background)
                    .accessibilityIdentifier("prompt-version-body")
                HStack {
                    Button("复制此版本正文（\(viewed.label)）", systemImage: "doc.on.doc") { model.copyVersion(viewed) }
                        .accessibilityIdentifier("prompt-version-copy")
                    if !viewed.isCurrent {
                        Button("恢复此版本…", systemImage: "clock.arrow.circlepath") { pendingRestore = viewed }
                            .disabled(!store.canSave).accessibilityIdentifier("prompt-version-restore")
                    }
                }
            }
            Text(model.historyMessage).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }
        .alert("将 \(pendingRestore?.label ?? "") 恢复为新的当前版本？", isPresented: Binding(
            get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })) {
            Button("取消", role: .cancel) { pendingRestore = nil }
            Button("恢复") {
                guard let entry = pendingRestore else { return }
                pendingRestore = nil
                Task {
                    let dirty = PromptTemplateWindowManager.shared.hasUnsavedDraft(store: store, templateID: template.id)
                    if await model.restore(entry, of: template, in: store, hasUnsavedDraft: dirty),
                       let saved = store.templates.first(where: { $0.id == template.id }) {
                        PromptTemplateWindowManager.shared.syncCleanSession(store: store, saved: saved)
                    }
                }
            }
        } message: { Text("所选版本的名称、正文、分类会保存为一个新的当前内容版本；全部历史保留，收藏与归档状态不变。") }
    }
}
