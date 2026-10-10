import AppKit
import Combine
import SwiftUI

/// 导出流程的状态机：准备（冻结）→ 预览 → 选择保存位置 → 核对 / 生成 / 校验 / 发布 → Finder 显示。
/// 同一时刻只允许一个准备或导出，重复点击被忽略；取消只在发布前的步骤边界生效。
@MainActor
final class ContentExportController: ObservableObject {
    enum Phase: Equatable { case idle, preparing, ready, exporting, succeeded, failed }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var plan: ContentExportPlan?
    @Published private(set) var message = ""
    @Published private(set) var revealMessage = ""
    @Published private(set) var result: ContentExportResult?
    @Published private(set) var cancelRequested = false

    let service: ContentExportService
    var chooseDestination: (ContentExportPlan) -> URL? = ContentExportController.presentSavePanel
    var reveal: (URL) -> Bool = { url in
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return true
    }
    private var cancellation: ContentExportCancellation?

    init(service: ContentExportService) { self.service = service }
    convenience init(libraries: ContentExportLibraries) { self.init(service: ContentExportService(libraries: libraries)) }

    var isBusy: Bool { phase == .preparing || phase == .exporting }

    func reset() {
        guard !isBusy else { return }
        phase = .idle; plan = nil; message = ""; revealMessage = ""; result = nil; cancelRequested = false
    }

    func prepare(batch request: ContentExportBatchRequest) async {
        guard !isBusy else { return }
        phase = .preparing; plan = nil; result = nil; revealMessage = ""; message = "正在读取已保存的内容并冻结导出范围…"
        do {
            plan = try await service.prepare(batch: request)
            phase = .ready; message = "已冻结导出范围；请核对预览。"
        } catch {
            phase = .failed; message = error.localizedDescription
        }
    }

    func prepare(single request: ContentExportSingleRequest) async {
        guard !isBusy else { return }
        phase = .preparing; plan = nil; result = nil; revealMessage = ""; message = "正在读取已保存的内容…"
        do {
            plan = try await service.prepare(single: request)
            phase = .ready; message = ""
        } catch {
            phase = .failed; message = error.localizedDescription
        }
    }

    /// 单条：准备并直接进入保存面板；面板信息说明导出的是已保存正文原文。
    func runSingle(_ request: ContentExportSingleRequest) async {
        guard !isBusy else { return }
        await prepare(single: request)
        guard phase == .ready else { return }
        await exportPrepared()
    }

    func exportPrepared() async {
        guard !isBusy, phase == .ready, let plan else { return }
        phase = .exporting; cancelRequested = false; message = "请选择保存位置…"
        guard let destination = chooseDestination(plan) else {
            phase = .ready; message = "未选择保存位置，没有导出任何文件。"; return
        }
        let token = ContentExportCancellation()
        cancellation = token
        message = "正在核对源内容、生成并校验导出文件…"
        defer { cancellation = nil; cancelRequested = false }
        do {
            let outcome = try await service.export(plan: plan, to: destination, cancellation: token)
            result = outcome; phase = .succeeded
            message = "导出成功：\(outcome.url.path)（\(outcome.byteCount) 字节，SHA-256 \(outcome.sha256.prefix(12))…）"
        } catch let error as ContentExportError {
            message = error.localizedDescription
            switch error {
            case .sourceChanged, .recordMissing, .versionMissing, .sourceUnavailable:
                self.plan = nil; phase = .failed            // 必须重新准备，不静默换版
            default:
                phase = .ready                              // 范围仍冻结；可换位置重试
            }
        } catch {
            message = error.localizedDescription; phase = .ready
        }
    }

    /// 取消只影响发布前的步骤；进入发布后无法中断。
    func cancel() {
        guard phase == .exporting, let cancellation else { return }
        cancellation.cancel(); cancelRequested = true
    }

    func revealResult() {
        guard let url = result?.url else { return }
        revealMessage = reveal(url) ? "" : "无法在 Finder 中显示，但导出已完成，文件位于：\(url.path)"
    }

    static func presentSavePanel(_ plan: ContentExportPlan) -> URL? {
        let panel = NSSavePanel()
        let single = plan.kind == .singleMarkdown
        panel.title = single ? "导出 Markdown 正文" : "导出内容包"
        panel.prompt = "导出"
        panel.message = single
            ? "导出的是已保存正文的原文字节（不含标题、引用或元数据）。已存在的同名文件不会被覆盖。"
            : "导出为内容 ZIP，不是核心数据备份。已存在的同名文件不会被覆盖。"
        panel.nameFieldStringValue = plan.suggestedFileName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return single
            ? ContentExportFileName.ensureExtension(url, allowed: ["md", "markdown"], default: "md")
            : ContentExportFileName.ensureExtension(url, allowed: ["zip"], default: "zip")
    }
}

extension PersonalNotesStore {
    /// 单条笔记导出只读取本笔记库。
    var exportLibraries: ContentExportLibraries {
        ContentExportLibraries(notes: location.root.map { PersonalNotesFileStorage(root: $0) }, prompts: nil,
            notesUnavailable: location.error?.localizedDescription ?? "存储位置不可用")
    }
}

/// 详情 / 版本历史里的单条 .md 导出入口。
struct ContentExportSingleButton: View {
    let title: String
    let request: ContentExportSingleRequest
    let hasUnsavedDraft: Bool
    let identifier: String
    @StateObject private var controller: ContentExportController

    init(title: String, request: ContentExportSingleRequest, libraries: ContentExportLibraries,
         hasUnsavedDraft: Bool, identifier: String) {
        self.title = title; self.request = request; self.hasUnsavedDraft = hasUnsavedDraft; self.identifier = identifier
        _controller = StateObject(wrappedValue: ContentExportController(libraries: libraries))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(title, systemImage: "square.and.arrow.up") { Task { await controller.runSingle(request) } }
                    .disabled(controller.isBusy).accessibilityIdentifier(identifier)
                if controller.isBusy {
                    ProgressView().controlSize(.small)
                    if controller.phase == .exporting { Button("取消") { controller.cancel() } }
                }
                if controller.phase == .succeeded {
                    Button("在 Finder 中显示") { controller.revealResult() }.accessibilityIdentifier(identifier + "-reveal")
                }
            }
            Text("单个 .md 只含已保存正文的原文（不含标题、引用等元数据）；批量导出的 ZIP 才含 manifest 与笔记引用登记。导出不会修改源内容。")
                .font(.caption).foregroundStyle(.secondary)
            if hasUnsavedDraft {
                Text("当前有未保存的草稿：导出的是已保存版本，草稿不包含，也不会被保存或放弃。")
                    .font(.caption).foregroundStyle(.orange)
            }
            if controller.cancelRequested {
                Text("已请求取消：将在当前步骤结束后生效；若已进入发布步骤则无法中断。").font(.caption).foregroundStyle(.secondary)
            }
            if !controller.message.isEmpty {
                Text(controller.message).font(.caption).foregroundStyle(controller.phase == .succeeded ? Color.secondary : Color.orange)
                    .textSelection(.enabled).accessibilityIdentifier(identifier + "-message")
            }
            if !controller.revealMessage.isEmpty {
                Text(controller.revealMessage).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
    }
}

/// 批量导出：选择 → 范围 → 预览 → 保存位置。读取走只读来源，不依赖列表内存状态。
struct ContentExportBatchSheet: View {
    enum SourceFilter: String, CaseIterable, Identifiable {
        case all = "全部来源", notes = "个人笔记", prompts = "提示词"
        var id: String { rawValue }
    }
    enum Step { case choose, preview }

    let libraries: ContentExportLibraries
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller: ContentExportController
    @State private var step: Step = .choose
    @State private var sourceFilter: SourceFilter
    @State private var archived = false
    @State private var search = ""
    @State private var scope: ContentExportScope = .currentOnly
    @State private var selected = Set<ContentExportSelection>()
    @State private var rows: [ContentExportListingRow] = []
    @State private var sourceErrors: [ContentExportSource: String] = [:]
    @State private var loading = true

    init(libraries: ContentExportLibraries, initialSource: ContentExportSource? = nil) {
        self.libraries = libraries
        _controller = StateObject(wrappedValue: ContentExportController(libraries: libraries))
        _sourceFilter = State(initialValue: initialSource == .personalNote ? .notes : initialSource == .promptTemplate ? .prompts : .all)
    }

    private var visibleRows: [ContentExportListingRow] {
        let source: ContentExportSource? = sourceFilter == .notes ? .personalNote : sourceFilter == .prompts ? .promptTemplate : nil
        return ContentExportListingFilter.apply(rows, source: source, archived: archived, search: search)
    }
    private var draftNotice: Bool {
        PersonalNoteWindowManager.shared.hasUnsavedWork || PromptTemplateWindowManager.shared.hasUnsavedWork
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("导出个人内容").font(.title2)
                Spacer()
                Button("关闭") { dismiss() }.disabled(controller.isBusy).accessibilityIdentifier("export-close")
            }
            Text("把已保存的个人笔记和提示词导出为 ZIP（Markdown 原文 + manifest）。不调用 AI，不修改源内容；这不是核心数据备份，不能用于恢复。")
                .font(.callout).foregroundStyle(.secondary)
            switch step {
            case .choose: chooseStep
            case .preview: previewStep
            }
        }
        .padding(24).frame(minWidth: 820, minHeight: 620)
        .task { await load() }
    }

    // MARK: Choose

    private var chooseStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("来源", selection: $sourceFilter) { ForEach(SourceFilter.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 300)
                Picker("范围", selection: $archived) { Text("当前记录").tag(false); Text("已归档").tag(true) }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 200)
                TextField("按名称或分类过滤", text: $search).frame(maxWidth: 240).accessibilityIdentifier("export-search")
            }
            ForEach(ContentExportSource.allCases, id: \.self) { source in
                if let error = sourceErrors[source] {
                    Text("\(source.label)读取失败（不会当作空列表）：\(error)").font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                }
            }
            if loading { ProgressView("读取已保存的内容…") }
            else if visibleRows.isEmpty {
                ContentUnavailableView("没有符合当前筛选的记录", systemImage: "tray",
                    description: Text("可调整来源、当前 / 已归档或过滤条件；默认不会选中任何记录。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(visibleRows) { row in
                        Toggle(isOn: Binding(get: { selected.contains(row.id) },
                                             set: { if $0 { selected.insert(row.id) } else { selected.remove(row.id) } })) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(row.name).fontWeight(.medium)
                                    Text(row.source.label).font(.caption).padding(.horizontal, 6)
                                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                                    if row.isArchived { Text("已归档").font(.caption).foregroundStyle(.orange) }
                                }
                                Text("\(row.category ?? "未分类") · \(row.versionLabel)" + (row.referenceCount > 0 ? " · 引用 \(row.referenceCount) 条" : ""))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.accessibilityIdentifier("export-row-" + row.recordID.uuidString)
                    }
                }.frame(minHeight: 240)
            }
            HStack {
                Button("全选当前筛选结果（\(visibleRows.count) 条）") { selected.formUnion(visibleRows.map(\.id)) }
                    .disabled(visibleRows.isEmpty).accessibilityIdentifier("export-select-all")
                Button("清除选择") { selected.removeAll() }.disabled(selected.isEmpty)
                let hidden = selected.subtracting(visibleRows.map(\.id)).count
                Text("已选 \(selected.count) 条" + (hidden > 0 ? "（其中 \(hidden) 条不在当前筛选显示范围内，仍会导出）" : ""))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Picker("导出内容", selection: $scope) {
                Text("仅当前内容").tag(ContentExportScope.currentOnly)
                Text("当前内容 + 全部历史版本").tag(ContentExportScope.includeHistory)
            }.pickerStyle(.segmented).frame(maxWidth: 420).accessibilityIdentifier("export-scope")
            if controller.phase == .failed {
                Text(controller.message).font(.callout).foregroundStyle(.orange).textSelection(.enabled)
            }
            HStack {
                Spacer()
                Button("预览导出范围…") {
                    Task {
                        await controller.prepare(batch: ContentExportBatchRequest(selections: Array(selected), scope: scope))
                        if controller.phase == .ready { step = .preview }
                    }
                }
                .disabled(selected.isEmpty || controller.isBusy || loading).accessibilityIdentifier("export-prepare")
                if controller.phase == .preparing { ProgressView().controlSize(.small) }
            }
        }
    }

    // MARK: Preview

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let preview = controller.plan?.preview {
                Text("将导出 \(preview.rows.count) 条记录 · \(preview.fileCount) 个 Markdown 文件 · 正文共 \(preview.totalBytes) 字节")
                    .font(.headline)
                List(preview.rows) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(row.name).fontWeight(.medium)
                            Text(row.source).font(.caption)
                            if row.archived { Text("已归档").font(.caption).foregroundStyle(.orange) }
                        }
                        Text("\(row.category) · \(row.versionSummary) · \(row.fileCount) 个文件 · \(row.bytes) 字节"
                             + (row.referenceCount > 0 ? " · 引用登记 \(row.referenceCount) 条随包导出" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(minHeight: 180)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(preview.notices, id: \.self) { Text("• " + $0).font(.caption).foregroundStyle(.secondary) }
                    if draftNotice {
                        Text("• 有窗口存在未保存的草稿：导出的是已保存版本，草稿不包含，也不会被保存或放弃。")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            } else {
                Text("导出范围已失效，请返回重新准备。").foregroundStyle(.orange)
            }
            if controller.cancelRequested {
                Text("已请求取消：将在当前步骤结束后生效；若已进入发布步骤则无法中断。").font(.caption).foregroundStyle(.secondary)
            }
            if !controller.message.isEmpty {
                Text(controller.message).font(.callout).foregroundStyle(controller.phase == .succeeded ? Color.secondary : Color.orange)
                    .textSelection(.enabled).accessibilityIdentifier("export-message")
            }
            if !controller.revealMessage.isEmpty { Text(controller.revealMessage).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button("返回修改选择") { controller.reset(); step = .choose }.disabled(controller.isBusy)
                Spacer()
                if controller.phase == .exporting { Button("取消") { controller.cancel() }.accessibilityIdentifier("export-cancel") }
                if controller.isBusy { ProgressView().controlSize(.small) }
                if controller.phase == .succeeded {
                    Button("在 Finder 中显示") { controller.revealResult() }.accessibilityIdentifier("export-reveal")
                } else {
                    Button("选择保存位置并导出…", systemImage: "square.and.arrow.up") { Task { await controller.exportPrepared() } }
                        .disabled(controller.isBusy || controller.plan == nil).accessibilityIdentifier("export-run")
                }
            }
            if controller.phase == .failed && controller.plan == nil {
                Text("源内容已变化或不可读取，需要返回重新准备导出范围。").font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private func load() async {
        loading = true
        let service = controller.service
        var collected: [ContentExportListingRow] = []
        var errors: [ContentExportSource: String] = [:]
        for source in ContentExportSource.allCases {
            do { collected += try await service.listing(source) }
            catch { errors[source] = error.localizedDescription }
        }
        rows = collected; sourceErrors = errors; loading = false
    }
}
