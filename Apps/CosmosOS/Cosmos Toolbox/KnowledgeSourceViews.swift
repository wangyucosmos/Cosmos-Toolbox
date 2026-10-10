import SwiftUI
import AppKit

/// 「我的知识库」页面根视图。自包含：由接线层放进知识库分段即可。
/// 只读：不写入、不移动、不删除来源文件夹中的任何内容。
struct KnowledgeSourcesRootView: View {
    enum ListKind: String { case documents = "文档", attachments = "附件" }

    @StateObject private var store: KnowledgeSourceStore
    @StateObject private var searchModel = KnowledgeSourceSearchModel()
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    private let suggestedFolder: URL?
    private let initialSourceID: UUID?

    @State private var sourceID: UUID?
    @State private var folder = ""
    @State private var selection: String?
    @State private var query = ""
    @State private var listKind: ListKind = .documents
    @State private var showSource = false
    @State private var scrollRequest: KnowledgeReaderScrollRequest?
    @State private var history: [String] = []
    @State private var showManage = false
    @State private var showExclusions = false
    @State private var treeCollapsed = false
    @State private var confirmPull = false
    @State private var pendingOpen: KnowledgeSourceOpenRequest?
    @State private var toast: String?
    @FocusState private var searchFocused: Bool

    init(location: KnowledgeSourcesLocation, suggestedFolder: URL? = KnowledgeSourcesRootView.defaultSuggestion()) {
        _store = StateObject(wrappedValue: KnowledgeSourceStore(location: location))
        self.suggestedFolder = suggestedFolder; initialSourceID = nil
    }
    /// 测试 / 预览宿主使用。
    init(store: KnowledgeSourceStore, suggestedFolder: URL? = nil, initialSourceID: UUID? = nil) {
        _store = StateObject(wrappedValue: store)
        self.suggestedFolder = suggestedFolder; self.initialSourceID = initialSourceID
    }

    /// `~/Documents/我的知识库` 存在时作为“建议”显示；绝不自动添加。
    static func defaultSuggestion() -> URL? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/我的知识库", isDirectory: true)
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue ? url : nil
    }

    private var reduced: Bool { preferences.reducesMotion(system: systemMotion) }
    private var enabledSources: [KnowledgeSource] { store.sources.filter(\.isEnabled) }
    private var currentSource: KnowledgeSource? { enabledSources.first { $0.id == sourceID } }
    private var index: KnowledgeIndex? { sourceID.flatMap { store.indexes[$0] } }

    var body: some View {
        VStack(spacing: 0) {
            CosmosPageHeader("我的知识库", subtitle: "只读浏览本地知识库文件夹，并同步 GitHub 更新。",
                info: "选择你的知识库文件夹（如 Obsidian 库）后，Cosmos 会在后台读取其中的 Markdown 与文本，附件只显示名称。\n\n只读：不会修改、移动或删除文件夹里的任何内容（包括 .obsidian 配置）。隐藏文件、.gitignore 排除项、嵌套仓库，以及疑似密钥的文件（type: secret 或文件名含密钥 / secret / token / password / .env）都不会被读取，也不会出现在列表、搜索或统一检索中。索引只保存在内存里。") {
                CosmosGlassToolbarGroup {
                    Button("添加文件夹", systemImage: "folder.badge.plus") { pickFolder() }
                        .disabled(!store.canSave).accessibilityIdentifier("knowledge-add-folder")
                    Button("重新扫描", systemImage: "arrow.clockwise") { store.rescanAll() }
                        .disabled(enabledSources.isEmpty).help("重新扫描已启用的来源")
                }
            }.padding(.horizontal, CosmosDesign.pagePadding).padding(.top, CosmosDesign.spacingXL).padding(.bottom, CosmosDesign.spacingM)
            if let error = store.error {
                HStack {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).textSelection(.enabled)
                    Spacer()
                    if !error.locksSaving { Button("知道了") { store.dismissError() }.buttonStyle(.borderless) }
                }.font(CosmosDesign.font(.body)).padding(.horizontal, CosmosDesign.pagePadding).padding(.bottom, 8)
                    .accessibilityIdentifier("knowledge-error")
            }
            Group {
                if !store.loaded && store.error != nil { Spacer() }
                else if !store.loaded { ProgressView("读取来源登记…").frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if store.sources.isEmpty { onboarding }
                else { browser }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { toastView }
        .background { Button("") { searchFocused = true }.keyboardShortcut("f", modifiers: .command).opacity(0).accessibilityHidden(true) }
        .task {
            await store.reload()
            if sourceID == nil { sourceID = initialSourceID ?? enabledSources.first?.id }
            store.scanEnabledSourcesIfNeeded()
            if let request = KnowledgeSourceOpenCenter.shared.consume() { apply(request) }
        }
        .onChange(of: KnowledgeSourceOpenCenter.shared.pending) { _, request in
            if request != nil, let request = KnowledgeSourceOpenCenter.shared.consume() { apply(request) }
        }
        .onChange(of: store.scanStates) { _, _ in resolvePendingOpen() }
        .onChange(of: store.sources) { _, sources in
            if sourceID == nil || !sources.contains(where: { $0.id == sourceID && $0.isEnabled }) { switchSource(sources.first(where: \.isEnabled)?.id) }
        }
        .onChange(of: query) { _, value in searchModel.search(value, in: index) }
        .onChange(of: selection) { _, _ in showSource = false }
        .onDisappear { searchModel.cancel() }
        .sheet(isPresented: $showManage) { KnowledgeSourceManageView(store: store, onPick: pickFolder) }
        .alert("拉取更新", isPresented: $confirmPull) {
            Button("拉取（仅快进）") { if let id = sourceID { store.pullRemote(id) } }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将在「\(currentSource?.displayName ?? "")」中执行 git pull --ff-only：只做快进更新，不会提交、推送，也不会覆盖本地修改。需要凭据时依赖你电脑上已有的 git 配置。")
        }
    }

    // MARK: Onboarding

    private var onboarding: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "books.vertical").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("连接你的知识库").font(CosmosDesign.font(.title))
            Text("选择一个本地文件夹（例如 Obsidian 库）。Cosmos 只读取并显示其中的 Markdown 与附件，不会修改文件夹里的任何内容；密钥、隐藏文件和 .gitignore 排除项不会被读取。")
                .font(CosmosDesign.font(.body)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 520)
            HStack(spacing: 12) {
                Button("添加文件夹…", systemImage: "folder.badge.plus") { pickFolder() }
                    .buttonStyle(.glassProminent).disabled(!store.canSave).accessibilityIdentifier("knowledge-onboarding-add")
                if let suggestedFolder {
                    Button("添加『我的知识库』", systemImage: "lightbulb") { Task { await add(suggestedFolder) } }
                        .buttonStyle(.glass).disabled(!store.canSave).accessibilityIdentifier("knowledge-onboarding-suggestion")
                        .help("检测到 \(suggestedFolder.path)；点击才会添加")
                }
            }.controlSize(.large)
            if suggestedFolder != nil {
                Text("检测到 ~/Documents/我的知识库，仅作为建议，点击才会添加。").font(.caption).foregroundStyle(.tertiary)
            }
            Spacer(); Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(CosmosDesign.pagePadding)
    }

    // MARK: Browser

    @ViewBuilder private var browser: some View {
        VStack(spacing: 0) {
            sourceBar
            if let source = currentSource, KnowledgeSourceGitService.isRepository(source.rootURL) {
                KnowledgeGitPanelView(status: store.gitStatuses[source.id], activity: store.gitActivity[source.id] ?? .idle,
                    result: store.gitResults[source.id], onRefresh: { store.refreshGit(source.id) },
                    onFetch: { store.fetchRemote(source.id) }, onPull: { confirmPull = true }, onCancel: { store.cancelGit(source.id) })
                    .padding(.horizontal, CosmosDesign.pagePadding).padding(.bottom, 10)
            }
            Divider()
            if enabledSources.isEmpty {
                CosmosEmptyState(icon: "pause.circle", title: "所有来源都已停用", detail: "在“管理来源”中启用一个来源后才会扫描。", actionTitle: "管理来源") { showManage = true }
            } else if let source = currentSource {
                switch store.scanStates[source.id] ?? .idle {
                case .failed(let reason) where index == nil:
                    CosmosEmptyState(icon: "exclamationmark.triangle", title: "无法扫描「\(source.displayName)」", detail: reason, actionTitle: "重新扫描") { store.scan(source) }
                default:
                    if let index { panes(source: source, index: index) }
                    else { ProgressView("正在扫描…").frame(maxWidth: .infinity, maxHeight: .infinity) }
                }
            } else { Spacer() }
        }
    }

    private var sourceBar: some View {
        HStack(spacing: 12) {
            Picker("来源", selection: Binding(get: { sourceID }, set: { switchSource($0) })) {
                ForEach(enabledSources) { Text($0.displayName).tag(Optional($0.id)) }
            }.labelsHidden().frame(maxWidth: 220).accessibilityIdentifier("knowledge-source-picker")
            if let source = currentSource, store.scanStates[source.id] == .scanning { ProgressView().controlSize(.small) }
            if let index {
                Text("\(index.documents.count) 篇文档 · \(index.attachments.count) 个附件").font(.caption).foregroundStyle(.secondary)
                Button { showExclusions.toggle() } label: {
                    Label("已排除 \(index.exclusions.count) 项", systemImage: "eye.slash")
                }.buttonStyle(.borderless).font(.caption).accessibilityIdentifier("knowledge-exclusions")
                    .popover(isPresented: $showExclusions) { KnowledgeExclusionPopover(index: index) }
                if index.truncated { Label("条目过多，列表已截断", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange) }
            }
            Spacer()
            Button("管理来源", systemImage: "slider.horizontal.3") { showManage = true }.buttonStyle(.borderless).font(.caption)
        }.padding(.horizontal, CosmosDesign.pagePadding).padding(.vertical, 8)
    }

    private func panes(source: KnowledgeSource, index: KnowledgeIndex) -> some View {
        GeometryReader { geo in
            let showTree = geo.size.width >= 1020 && !treeCollapsed
            HStack(spacing: 0) {
                if showTree {
                    KnowledgeFolderTreeView(index: index, selection: $folder).frame(width: 210)
                    Divider()
                }
                listColumn(source: source, index: index, showTree: geo.size.width >= 1020)
                    .frame(width: geo.size.width >= 1020 ? 330 : 290)
                Divider()
                reader(source: source, index: index).frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: List column

    private func listColumn(source: KnowledgeSource, index: KnowledgeIndex, showTree: Bool) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    if showTree {
                        Button("文件夹", systemImage: "sidebar.leading") { withAnimation(reduced ? nil : CosmosDesign.motion) { treeCollapsed.toggle() } }
                            .labelStyle(.iconOnly).buttonStyle(.borderless).help(treeCollapsed ? "展开文件夹树" : "收起文件夹树")
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("搜索标题、路径、标签与正文", text: $query).textFieldStyle(.plain).focused($searchFocused)
                            .accessibilityIdentifier("knowledge-search")
                        if !query.isEmpty { Button("清空", systemImage: "xmark.circle.fill") { query = "" }.labelStyle(.iconOnly).buttonStyle(.borderless).foregroundStyle(.secondary) }
                    }.padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(searchFocused ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.1)) }
                }
                HStack {
                    Picker("类型", selection: $listKind) {
                        Text("文档 \(index.documents.count)").tag(ListKind.documents)
                        Text("附件 \(index.attachments.count)").tag(ListKind.attachments)
                    }.pickerStyle(.segmented).labelsHidden()
                    if !showTree { folderMenu(index: index) }
                }
            }.padding(10)
            Divider()
            fileList(source: source, index: index)
        }
    }

    private func folderMenu(index: KnowledgeIndex) -> some View {
        Menu {
            Button("全部文件夹") { folder = "" }
            Divider()
            ForEach(index.directories, id: \.self) { path in Button(path) { folder = path } }
        } label: { Image(systemName: "folder") }
            .menuStyle(.borderlessButton).fixedSize().help(folder.isEmpty ? "全部文件夹" : folder)
    }

    @ViewBuilder private func fileList(source: KnowledgeSource, index: KnowledgeIndex) -> some View {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            if searchModel.searching && searchModel.hits.isEmpty {
                ProgressView("搜索中…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchModel.hits.isEmpty {
                CosmosEmptyState(icon: "magnifyingglass", title: "没有匹配", detail: "只搜索已读入的标题、路径、标签与正文；被排除的文件不会出现。")
                Spacer()
            } else {
                Text("\(searchModel.hits.count) 个匹配").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.top, 8)
                List(selection: Binding(get: { selection }, set: { chooseHit($0) })) {
                    ForEach(searchModel.hits) { hit in KnowledgeHitRow(hit: hit, keyword: keyword).tag(hit.path) }
                }.listStyle(.plain)
            }
        } else if listKind == .documents {
            let documents = index.documents.filter { KnowledgeFolderTree.contains(folder: folder, path: $0.relativePath) }
                .sorted { $0.modifiedAt == $1.modifiedAt ? $0.relativePath < $1.relativePath : $0.modifiedAt > $1.modifiedAt }
            if documents.isEmpty {
                CosmosEmptyState(icon: "doc", title: "这里没有文档", detail: folder.isEmpty ? "来源中没有可显示的 Markdown 或文本文件。" : "该文件夹下没有文档。")
                Spacer()
            } else {
                List(selection: Binding(get: { selection }, set: { select($0) })) {
                    ForEach(documents) { KnowledgeDocumentRow(document: $0).tag($0.relativePath) }
                }.listStyle(.plain).accessibilityIdentifier("knowledge-file-list")
            }
        } else {
            let attachments = index.attachments.filter { KnowledgeFolderTree.contains(folder: folder, path: $0.relativePath) }
                .sorted { $0.modifiedAt == $1.modifiedAt ? $0.relativePath < $1.relativePath : $0.modifiedAt > $1.modifiedAt }
            if attachments.isEmpty {
                CosmosEmptyState(icon: "paperclip", title: "这里没有附件"); Spacer()
            } else {
                List(selection: Binding(get: { selection }, set: { select($0) })) {
                    ForEach(attachments) { KnowledgeAttachmentRow(attachment: $0).tag($0.relativePath) }
                }.listStyle(.plain)
            }
        }
    }

    // MARK: Reader column

    @ViewBuilder private func reader(source: KnowledgeSource, index: KnowledgeIndex) -> some View {
        if let path = selection, let document = index.document(at: path) {
            KnowledgeDocumentReaderView(document: document, source: source, index: index, showSource: $showSource,
                scrollRequest: scrollRequest, canGoBack: !history.isEmpty, onBack: goBack,
                onOpenDocument: { openLink($0, heading: $1) }, onOpenAttachment: { openAttachmentLink($0) }, onMessage: show)
                .id(source.id.uuidString + "/" + path)
        } else if let path = selection, let attachment = index.attachment(at: path) {
            KnowledgeAttachmentView(attachment: attachment, source: source, onMessage: show).id(source.id.uuidString + "/" + path)
        } else {
            CosmosEmptyState(icon: "text.book.closed", title: "选择一个文件开始阅读",
                detail: "左侧选择文档，或用搜索框查找。支持 [[双链]]、提示框、表格与本地图片。")
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(nsColor: .textBackgroundColor))
        }
    }

    // MARK: Actions

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "添加"; panel.message = "选择要只读接入的知识库文件夹"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in await add(url) }
        }
    }
    private func add(_ url: URL) async {
        if await store.add(folder: url), sourceID == nil || currentSource == nil {
            sourceID = store.sources.first(where: { $0.path == KnowledgeSourceScanner.canonicalDirectory(url) })?.id ?? store.sources.last?.id
        }
    }
    private func switchSource(_ id: UUID?) {
        guard id != sourceID else { return }
        sourceID = id; folder = ""; selection = nil; query = ""; history = []; scrollRequest = nil
        searchModel.search("", in: nil)
    }
    private func select(_ path: String?) {
        guard path != selection else { return }
        selection = path; scrollRequest = nil; history = []
    }
    private func chooseHit(_ path: String?) {
        guard let path else { selection = nil; return }
        let hit = searchModel.hits.first { $0.path == path }
        selection = path; history = []
        scrollRequest = hit?.line.map { KnowledgeReaderScrollRequest(line: $0, heading: nil) }
    }
    private func openLink(_ path: String, heading: String?) {
        if let current = selection, current != path { history.append(current) }
        selection = path; query = ""
        scrollRequest = heading != nil ? KnowledgeReaderScrollRequest(line: nil, heading: heading) : nil
        if let index, index.document(at: path) != nil { listKind = .documents }
    }
    private func openAttachmentLink(_ path: String) {
        if let current = selection, current != path { history.append(current) }
        selection = path; listKind = .attachments; scrollRequest = nil
    }
    private func goBack() { if let previous = history.popLast() { selection = previous; scrollRequest = nil } }

    private func apply(_ request: KnowledgeSourceOpenRequest) {
        guard store.sources.contains(where: { $0.id == request.document.sourceID && $0.isEnabled }) else {
            show("该文档所在的来源已停用或已移除。"); return
        }
        if sourceID != request.document.sourceID { switchSource(request.document.sourceID) }
        query = ""; folder = ""; listKind = .documents; showSource = false
        pendingOpen = request
        if store.indexes[request.document.sourceID] == nil, store.scanStates[request.document.sourceID] != .scanning,
           let source = store.sources.first(where: { $0.id == request.document.sourceID }) { store.scan(source) }
        resolvePendingOpen()
    }
    private func resolvePendingOpen() {
        guard let request = pendingOpen, let index = store.indexes[request.document.sourceID] else { return }
        pendingOpen = nil
        guard index.document(at: request.document.relativePath) != nil else { show("该文件已不存在，或已被排除规则排除。"); return }
        history = []; selection = request.document.relativePath
        scrollRequest = request.heading.map { KnowledgeReaderScrollRequest(line: nil, heading: $0) }
    }

    private func show(_ message: String) {
        toast = message
        Task { try? await Task.sleep(for: .seconds(3)); if toast == message { toast = nil } }
    }
    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast).font(CosmosDesign.font(.body)).padding(.horizontal, 14).padding(.vertical, 8)
                .glassEffect(.regular, in: Capsule()).padding(.bottom, 18)
                .transition(reduced ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                .accessibilityIdentifier("knowledge-toast")
        }
    }
}

// MARK: - Rows

struct KnowledgeDocumentRow: View {
    let document: KnowledgeDocument
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(document.title).font(.system(size: 13.5 * CosmosUIPreferences.shared.textSize.scale, weight: .medium)).lineLimit(1)
                Spacer(minLength: 4)
                Text(document.modifiedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
            Text(document.folder.isEmpty ? document.fileName : document.folder + "/").font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            if let note = document.contentState.note, document.contentState != .loaded {
                Label(note, systemImage: "exclamationmark.circle").font(.caption2).foregroundStyle(.orange).lineLimit(1)
            }
            if !document.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(document.tags.prefix(3), id: \.self) { KnowledgeTagCapsule(text: $0) }
                    if document.tags.count > 3 { Text("+\(document.tags.count - 3)").font(.caption2).foregroundStyle(.secondary) }
                }
            }
        }.padding(.vertical, 4).accessibilityElement(children: .combine)
    }
}

struct KnowledgeAttachmentRow: View {
    let attachment: KnowledgeAttachment
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: KnowledgeAttachmentView.symbol(attachment.fileExtension)).foregroundStyle(.secondary).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(attachment.fileName).font(.system(size: 13 * CosmosUIPreferences.shared.textSize.scale, weight: .medium)).lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteSize), countStyle: .file) + " · " +
                     attachment.modifiedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 3)
    }
}

struct KnowledgeHitRow: View {
    let hit: KnowledgeSearchHit
    let keyword: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: hit.isAttachment ? "paperclip" : "doc.text").font(.caption).foregroundStyle(.secondary)
                Text(Self.highlight(hit.title, keyword)).font(.system(size: 13.5, weight: .medium)).lineLimit(1)
                Spacer(minLength: 4)
                ForEach(hit.fields, id: \.rawValue) { Text($0.rawValue).font(.caption2).padding(.horizontal, 5).padding(.vertical, 1).background(Color.primary.opacity(0.07), in: Capsule()).foregroundStyle(.secondary) }
            }
            Text(Self.highlight(hit.snippet, keyword)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Text(hit.path).font(.caption2).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
        }.padding(.vertical, 4)
    }
    static func highlight(_ text: String, _ keyword: String) -> AttributedString {
        var result = AttributedString(text)
        guard !keyword.isEmpty else { return result }
        var remaining = text.startIndex..<text.endIndex
        while let range = text.range(of: keyword, options: KnowledgeSourceSearch.options, range: remaining) {
            if let lower = AttributedString.Index(range.lowerBound, within: result), let upper = AttributedString.Index(range.upperBound, within: result) {
                result[lower..<upper].foregroundColor = .accentColor
                result[lower..<upper].backgroundColor = Color.accentColor.opacity(0.15)
            }
            remaining = range.upperBound..<text.endIndex
        }
        return result
    }
}

// MARK: - Folder tree

extension KnowledgeFolderNode { var optionalChildren: [KnowledgeFolderNode]? { children.isEmpty ? nil : children } }

struct KnowledgeFolderTreeView: View {
    let index: KnowledgeIndex
    @Binding var selection: String
    var body: some View {
        let nodes = KnowledgeFolderTree.build(index)
        List(selection: Binding(get: { Optional(selection) }, set: { selection = $0 ?? "" })) {
            Label { HStack { Text("全部"); Spacer(); Text("\(index.documents.count + index.attachments.count)").font(.caption).foregroundStyle(.secondary) } }
                icon: { Image(systemName: "tray.full") }.tag("")
            OutlineGroup(nodes, children: \.optionalChildren) { node in
                Label { HStack { Text(node.name).lineLimit(1); Spacer(); Text("\(node.itemCount)").font(.caption).foregroundStyle(.secondary) } }
                    icon: { Image(systemName: "folder") }.tag(node.path)
            }
        }.listStyle(.sidebar).accessibilityIdentifier("knowledge-folder-tree")
    }
}

// MARK: - Exclusions

struct KnowledgeExclusionPopover: View {
    let index: KnowledgeIndex
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("已排除 \(index.exclusions.count) 项").font(CosmosDesign.font(.section))
                Text("被排除的文件不会被读取，也不会出现在列表、搜索、统一检索或任何缓存中。这里只显示路径与原因。")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if index.exclusions.isEmpty { Text("没有被排除的项目。").font(.caption) }
                ForEach(index.exclusionSummary, id: \.0) { reason, count in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(index.exclusions.filter { $0.reason == reason }.prefix(200)) { item in
                                HStack(spacing: 6) {
                                    Text(item.relativePath).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                                    if let rule = item.detail { Text("规则 " + rule).font(.caption2).foregroundStyle(.tertiary).lineLimit(1) }
                                }
                            }
                            if count > 200 { Text("…另有 \(count - 200) 项").font(.caption2).foregroundStyle(.secondary) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    } label: { Text("\(reason.title) · \(count)").font(CosmosDesign.font(.body)) }
                }
                if !index.unsupportedIgnoreLines.isEmpty {
                    Divider()
                    Text("以下 .gitignore 行无法可靠解析，已跳过：").font(.caption).foregroundStyle(.secondary)
                    ForEach(index.unsupportedIgnoreLines, id: \.self) { Text($0).font(.caption.monospaced()) }
                }
            }.padding(16).textSelection(.enabled)
        }.frame(width: 440, height: 360)
    }
}

// MARK: - Source management

struct KnowledgeSourceManageView: View {
    @ObservedObject var store: KnowledgeSourceStore
    var onPick: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var removing: KnowledgeSource?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("管理来源").font(CosmosDesign.font(.title))
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            Text("来源是你选择的本地文件夹。移除只会删除这里的登记，绝不会触碰文件夹里的内容。卓望子仓库等嵌套仓库可以作为独立来源添加。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let error = store.error, !error.locksSaving {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
            List {
                ForEach(store.sources) { source in
                    KnowledgeSourceManageRow(source: source, store: store, onRemove: { removing = source })
                }
            }.listStyle(.inset).frame(minHeight: 180)
            HStack {
                Button("添加文件夹…", systemImage: "folder.badge.plus") { onPick() }.disabled(!store.canSave)
                Spacer()
                Text("\(store.sources.count) / \(KnowledgeSourceLimits.maxSources)").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(22).frame(width: 600, height: 440)
            .confirmationDialog("移除来源？", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), presenting: removing) { source in
                Button("仅移除登记", role: .destructive) { Task { await store.remove(source.id) } }
                Button("取消", role: .cancel) {}
            } message: { source in Text("「\(source.displayName)」的文件夹及其内容不会被修改或删除。") }
    }
}

struct KnowledgeSourceManageRow: View {
    let source: KnowledgeSource
    @ObservedObject var store: KnowledgeSourceStore
    var onRemove: () -> Void
    @State private var name: String

    init(source: KnowledgeSource, store: KnowledgeSourceStore, onRemove: @escaping () -> Void) {
        self.source = source; self.store = store; self.onRemove = onRemove; _name = State(initialValue: source.displayName)
    }
    var body: some View {
        HStack(spacing: 12) {
            Toggle("启用", isOn: Binding(get: { source.isEnabled }, set: { value in Task { await store.setEnabled(source.id, value) } }))
                .labelsHidden().toggleStyle(.switch).controlSize(.small).disabled(!store.canSave).help(source.isEnabled ? "停用后不再扫描" : "启用并扫描")
            VStack(alignment: .leading, spacing: 3) {
                TextField("显示名", text: $name).textFieldStyle(.plain).font(CosmosDesign.font(.section))
                    .onSubmit { Task { await store.rename(source.id, to: name); name = store.sources.first { $0.id == source.id }?.displayName ?? name } }
                Text(source.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
            }
            Spacer()
            Button("移除", systemImage: "minus.circle", action: onRemove).labelStyle(.iconOnly).buttonStyle(.borderless)
                .disabled(!store.canSave).help("仅移除登记，不触碰文件夹内容")
        }.padding(.vertical, 4)
    }
}

// MARK: - Git panel (pure view over values)

struct KnowledgeGitPanelView: View {
    let status: KnowledgeGitStatus?
    let activity: KnowledgeSourceStore.GitActivity
    let result: KnowledgeGitOperationResult?
    var onRefresh: () -> Void = {}
    var onFetch: () -> Void = {}
    var onPull: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let status {
                if let failure = status.failure {
                    Label("无法读取 Git 状态：" + failure, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                } else { summary(status) }
                controls(status)
            } else {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("正在读取 Git 状态…").font(.caption).foregroundStyle(.secondary) }
            }
            if let result {
                Label { Text(result.message).textSelection(.enabled).lineLimit(6) } icon: { Image(systemName: Self.symbol(result.outcome)) }
                    .font(.caption).foregroundStyle(Self.color(result.outcome)).accessibilityIdentifier("knowledge-git-result")
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusMedium))
        .overlay { RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusMedium).stroke(Color.primary.opacity(0.06)) }
        .accessibilityIdentifier("knowledge-git-panel")
    }

    private func summary(_ s: KnowledgeGitStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(s.detached ? "游离 HEAD" : (s.branch ?? "未知分支"), systemImage: "arrow.triangle.branch").font(.system(size: 13, weight: .semibold))
                if let upstream = s.upstream { Text("跟踪 " + upstream).font(.caption).foregroundStyle(.secondary) }
                else if !s.detached { Text("未跟踪远端").font(.caption).foregroundStyle(.orange) }
                Spacer(minLength: 0)
                if let commit = s.lastCommit {
                    HStack(spacing: 6) {
                        Text(commit.shortHash).font(.caption.monospaced()).foregroundStyle(.secondary)
                        Text(commit.subject).font(.caption).lineLimit(1).truncationMode(.tail)
                        Text(commit.date.formatted(.relative(presentation: .named))).font(.caption).foregroundStyle(.tertiary)
                    }.textSelection(.enabled)
                }
            }
            FlowChips {
                if s.totalChanged == 0 && s.stagedTracked == 0 && s.unmerged == 0 { statChip("工作区干净", "checkmark.circle", .green) }
                if s.changedTracked > 0 { statChip("已修改 \(s.changedTracked)", "pencil.circle", .orange) }
                if s.stagedTracked > 0 { statChip("已暂存 \(s.stagedTracked)", "tray.and.arrow.down", .orange) }
                if s.untracked > 0 { statChip("未跟踪 \(s.untracked)", "questionmark.circle", .secondary) }
                if s.unmerged > 0 { statChip("冲突 \(s.unmerged)", "exclamationmark.octagon", .red) }
                if s.upstream != nil {
                    statChip("领先 \(s.ahead)", "arrow.up", s.ahead > 0 ? .blue : .secondary)
                    statChip("落后 \(s.behind)", "arrow.down", s.behind > 0 ? .blue : .secondary)
                }
                statChip(s.lastFetch.map { "上次拉取 " + $0.formatted(.relative(presentation: .named)) } ?? "尚未从远端拉取", "clock", .secondary)
            }
        }
    }

    private func controls(_ s: KnowledgeGitStatus) -> some View {
        let decision = KnowledgeGitPullPolicy.evaluate(s)
        let busy = activity != .idle
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button { onFetch() } label: { Label("检查远端更新", systemImage: "arrow.triangle.2.circlepath") }
                    .disabled(busy || s.failure != nil || s.upstream == nil && s.branch == nil).accessibilityIdentifier("knowledge-git-fetch")
                Button { onPull() } label: { Label("拉取更新…", systemImage: "arrow.down.circle") }
                    .disabled(busy || !decision.allowed).accessibilityIdentifier("knowledge-git-pull")
                    .help(decision.reason ?? "快进拉取（git pull --ff-only）")
                Button { onRefresh() } label: { Label("刷新状态", systemImage: "arrow.clockwise") }.labelStyle(.iconOnly).disabled(busy)
                if busy {
                    ProgressView().controlSize(.small)
                    Text(activity == .fetching ? "正在检查远端…" : activity == .pulling ? "正在拉取…" : "正在读取状态…").font(.caption).foregroundStyle(.secondary)
                    Button("取消", action: onCancel).buttonStyle(.borderless)
                }
                Spacer(minLength: 0)
            }.buttonStyle(.glass).controlSize(.small)
            if !decision.allowed, s.failure == nil, let reason = decision.reason {
                Label(reason, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("knowledge-git-pull-reason")
            }
            ForEach(decision.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange) }
        }
    }

    private func statChip(_ text: String, _ symbol: String, _ color: Color) -> some View {
        Label(text, systemImage: symbol).font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule()).foregroundStyle(color == .secondary ? Color.secondary : color)
    }
    static func symbol(_ outcome: KnowledgeGitOperationResult.Outcome) -> String {
        switch outcome {
        case .success: return "checkmark.circle"
        case .failed: return "xmark.octagon"
        case .timedOut: return "clock.badge.exclamationmark"
        case .cancelled: return "slash.circle"
        case .blocked: return "hand.raised"
        }
    }
    static func color(_ outcome: KnowledgeGitOperationResult.Outcome) -> Color {
        switch outcome {
        case .success: return .green
        case .failed, .timedOut: return .red
        case .cancelled, .blocked: return .orange
        }
    }
}
