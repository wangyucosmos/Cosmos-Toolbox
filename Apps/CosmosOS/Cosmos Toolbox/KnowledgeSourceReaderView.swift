import SwiftUI
import AppKit
import QuickLook

// MARK: - File actions (read-only: open / reveal / copy)

nonisolated enum KnowledgeSourceActions {
    /// 用默认应用打开的扩展名白名单；脚本、应用包、安装包等可执行类型只能在 Finder 中显示。
    static let defaultOpenExtensions: Set<String> = [
        "md", "markdown", "txt", "pdf", "png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "tif", "bmp",
        "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "csv", "rtf", "html", "htm", "svg",
    ]

    static func canOpenWithDefaultApp(_ relativePath: String) -> Bool {
        defaultOpenExtensions.contains((relativePath as NSString).pathExtension.lowercased())
    }

    /// 来源根 + 相对路径 → 文件 URL；拒绝路径穿越、符号链接与非普通文件。
    static func fileURL(root: String, relative: String) -> URL? {
        guard !relative.isEmpty, !relative.contains("\0"), !relative.split(separator: "/").contains(".."), !relative.hasPrefix("/") else { return nil }
        let path = root + "/" + relative
        guard KnowledgeSourceScanner.kind(path) == S_IFREG else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// `obsidian://open?path=<绝对路径>`；路径中的所有保留字符都被百分号编码。
    static func obsidianURL(path: String) -> URL? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/-_.~"))
        guard path.hasPrefix("/"), let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "obsidian://open?path=" + encoded)
    }
}

@MainActor
enum KnowledgeSourceSystem {
    static var obsidianInstalled: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: "md.obsidian") != nil }
    static func openInObsidian(_ url: URL) -> Bool { KnowledgeSourceActions.obsidianURL(path: url.path).map { NSWorkspace.shared.open($0) } ?? false }
    static func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    static func open(_ url: URL) -> Bool { NSWorkspace.shared.open(url) }
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
    }
}

struct KnowledgeReaderScrollRequest: Equatable {
    var line: Int?
    var heading: String?
    var serial = UUID()
}

// MARK: - Document reader

struct KnowledgeDocumentReaderView: View {
    let document: KnowledgeDocument
    let source: KnowledgeSource
    let index: KnowledgeIndex
    @Binding var showSource: Bool
    var scrollRequest: KnowledgeReaderScrollRequest?
    var canGoBack = false
    var onBack: () -> Void = {}
    var onOpenDocument: (String, String?) -> Void
    var onOpenAttachment: (String) -> Void
    var onMessage: (String) -> Void

    @State private var blocks: [KnowledgeMarkdownBlock]?
    @State private var scrollTarget: (id: Int, serial: UUID)?
    @State private var highlighted: Int?
    @State private var obsidianAvailable = KnowledgeSourceSystem.obsidianInstalled

    private var fileURL: URL? { KnowledgeSourceActions.fileURL(root: source.path, relative: document.relativePath) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color(nsColor: .textBackgroundColor))
        .task(id: document.relativePath + "\u{0}" + String(document.byteSize) + String(document.modifiedAt.timeIntervalSince1970) + String(index.scannedAt.timeIntervalSince1970)) {
            blocks = nil
            guard document.contentState == .loaded else { blocks = []; return }
            let body = document.body
            let parsed = await Task.detached(priority: .userInitiated) { KnowledgeMarkdown.parse(body) }.value
            blocks = parsed
            applyScroll()
        }
        .onChange(of: scrollRequest) { _, _ in applyScroll() }
    }

    private func applyScroll() {
        guard let blocks, let request = scrollRequest else { return }
        var target: Int?
        if let heading = request.heading { target = KnowledgeMarkdown.headingBlockID(heading, in: blocks) }
        if target == nil, let line = request.line { target = KnowledgeMarkdown.blockID(containingLine: line, in: blocks) }
        guard let target else { return }
        scrollTarget = (target, request.serial)
        highlighted = target
        Task { try? await Task.sleep(for: .seconds(2.5)); if highlighted == target { highlighted = nil } }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if canGoBack { Button("返回", systemImage: "chevron.left", action: onBack).labelStyle(.iconOnly).buttonStyle(.borderless).help("返回上一篇") }
                Text(document.title).font(KnowledgeReaderFont.body(22).weight(.semibold)).lineLimit(2).textSelection(.enabled)
                Spacer(minLength: 8)
            }
            Text(document.relativePath).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
            properties
            actions
        }.padding(.horizontal, 24).padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var properties: some View {
        let fm = document.frontmatter
        if fm.type != nil || fm.created != nil || !fm.tags.isEmpty {
            FlowChips {
                if let type = fm.type { KnowledgePropertyChip(label: "类型", value: type, symbol: "tag") }
                if let created = fm.created { KnowledgePropertyChip(label: "创建", value: created, symbol: "calendar") }
                ForEach(fm.tags, id: \.self) { KnowledgeTagCapsule(text: $0) }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Picker("显示", selection: $showSource) {
                Label("阅读", systemImage: "doc.richtext").tag(false)
                Label("查看源文", systemImage: "chevron.left.forwardslash.chevron.right").tag(true)
            }.pickerStyle(.segmented).labelsHidden().frame(width: 190)
                .disabled(document.contentState != .loaded).accessibilityIdentifier("knowledge-source-toggle")
            Spacer(minLength: 8)
            Group {
                Button("在 Obsidian 中打开", systemImage: "arrow.up.forward.app") {
                    if let url = fileURL, !KnowledgeSourceSystem.openInObsidian(url) { onMessage("无法打开 Obsidian。") }
                }.disabled(!obsidianAvailable || fileURL == nil)
                    .help(obsidianAvailable ? "在 Obsidian 中打开" : "未检测到 Obsidian，已停用此操作")
                Button("在 Finder 中显示", systemImage: "folder") { if let url = fileURL { KnowledgeSourceSystem.reveal(url) } }
                    .disabled(fileURL == nil).help("在 Finder 中显示")
                Button("用默认应用打开", systemImage: "arrow.up.right.square") {
                    if let url = fileURL, !KnowledgeSourceSystem.open(url) { onMessage("系统未能打开该文件。") }
                }.disabled(fileURL == nil || !KnowledgeSourceActions.canOpenWithDefaultApp(document.relativePath)).help("用默认应用打开")
                Button("复制正文", systemImage: "doc.on.doc") {
                    KnowledgeSourceSystem.copy(document.body); onMessage("已复制正文")
                }.disabled(document.contentState != .loaded).help("复制正文（不含 frontmatter）")
            }.labelStyle(.iconOnly).buttonStyle(.borderless).controlSize(.regular)
        }
    }

    // MARK: Body

    @ViewBuilder private var content: some View {
        if document.contentState != .loaded {
            CosmosEmptyState(icon: "doc.text.magnifyingglass", title: "未读取内容", detail: document.contentState.note ?? "该文件仅列出名称。")
        } else if showSource {
            ScrollView {
                Text(document.rawText.isEmpty ? " " : document.rawText).font(KnowledgeReaderFont.mono())
                    .textSelection(.enabled)
                    .padding(24).frame(maxWidth: .infinity, alignment: .topLeading)
            }.accessibilityIdentifier("knowledge-source-text")
        } else if let blocks {
            if blocks.isEmpty {
                CosmosEmptyState(icon: "doc", title: "正文为空", detail: "这个文件没有正文内容。")
            } else {
                KnowledgeMarkdownView(blocks: blocks,
                    context: KnowledgeRenderContext(document: document.relativePath, resolver: index.resolver, rootPath: source.path, highlightedBlock: highlighted),
                    scrollTarget: scrollTarget, onLink: handle)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handle(_ url: URL) {
        switch KnowledgeMarkdownInline.action(for: url) {
        case .document(let path, let heading): onOpenDocument(path, heading)
        case .attachment(let path): onOpenAttachment(path)
        case .missing(let name): onMessage("未找到「\(name)」：来源内没有同名文件。")
        case .web(let web): if !NSWorkspace.shared.open(web) { onMessage("无法在浏览器中打开链接。") }
        case .relative(let raw):
            let resolved = index.resolver.resolveRelative(raw, from: document.relativePath)
            switch resolved.target {
            case .document(let path): onOpenDocument(path, resolved.heading)
            case .attachment(let path): onOpenAttachment(path)
            case .unresolved: onMessage("未找到链接目标：" + raw)
            }
        case .ignored: break
        }
    }
}

// MARK: - Attachment

struct KnowledgeAttachmentView: View {
    let attachment: KnowledgeAttachment
    let source: KnowledgeSource
    var onMessage: (String) -> Void
    @State private var quickLook: URL?
    @State private var obsidianAvailable = KnowledgeSourceSystem.obsidianInstalled

    private var fileURL: URL? { KnowledgeSourceActions.fileURL(root: source.path, relative: attachment.relativePath) }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: Self.symbol(attachment.fileExtension)).font(.system(size: 44)).foregroundStyle(.secondary)
            Text(attachment.fileName).font(CosmosDesign.font(.section)).multilineTextAlignment(.center).textSelection(.enabled)
            VStack(spacing: 4) {
                Text(attachment.relativePath).lineLimit(2).truncationMode(.middle)
                Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteSize), countStyle: .file) + " · 修改于 " +
                     attachment.modifiedAt.formatted(date: .abbreviated, time: .shortened))
            }.font(.caption).foregroundStyle(.secondary)
            Text("附件只显示名称、大小与修改时间；内容不会被读取或索引。").font(.caption).foregroundStyle(.tertiary)
            HStack(spacing: 10) {
                Button("快速预览", systemImage: "eye") { quickLook = fileURL }.disabled(fileURL == nil)
                Button("在 Finder 中显示", systemImage: "folder") { if let url = fileURL { KnowledgeSourceSystem.reveal(url) } }.disabled(fileURL == nil)
                Button("用默认应用打开", systemImage: "arrow.up.right.square") {
                    if let url = fileURL, !KnowledgeSourceSystem.open(url) { onMessage("系统未能打开该文件。") }
                }.disabled(fileURL == nil || !KnowledgeSourceActions.canOpenWithDefaultApp(attachment.relativePath))
                    .help(KnowledgeSourceActions.canOpenWithDefaultApp(attachment.relativePath) ? "用默认应用打开" : "该类型不会被直接打开，请在 Finder 中显示")
                Button("在 Obsidian 中打开", systemImage: "arrow.up.forward.app") {
                    if let url = fileURL, !KnowledgeSourceSystem.openInObsidian(url) { onMessage("无法打开 Obsidian。") }
                }.disabled(!obsidianAvailable || fileURL == nil)
            }.buttonStyle(.glass)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
            .background(Color(nsColor: .textBackgroundColor))
            .quickLookPreview($quickLook)
    }

    static func symbol(_ ext: String) -> String {
        switch ext {
        case "pdf": return "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp", "svg": return "photo"
        case "doc", "docx", "pages", "rtf": return "doc.text"
        case "xls", "xlsx", "numbers", "csv": return "tablecells"
        case "ppt", "pptx", "key": return "rectangle.on.rectangle"
        case "html", "htm": return "globe"
        case "mp3", "m4a", "wav": return "waveform"
        case "mp4", "mov": return "film"
        case "zip", "gz", "tar": return "doc.zipper"
        default: return "doc"
        }
    }
}

// MARK: - Small shared chips

struct KnowledgeTagCapsule: View {
    let text: String
    var body: some View {
        Text("#" + text).font(.caption).lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.12), in: Capsule()).foregroundStyle(Color.accentColor)
            .accessibilityLabel("标签 " + text)
    }
}

struct KnowledgePropertyChip: View {
    let label: String
    let value: String
    let symbol: String
    var body: some View {
        Label { Text(label + " " + value).lineLimit(1) } icon: { Image(systemName: symbol) }
            .font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.primary.opacity(0.07), in: Capsule()).foregroundStyle(.secondary)
    }
}

/// 简单的自动换行容器（胶囊行）。
struct FlowChips<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { FlowLayout(spacing: 6) { content } }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing; rowHeight = max(rowHeight, size.height); maxX = max(maxX, x - spacing)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
    }
}
