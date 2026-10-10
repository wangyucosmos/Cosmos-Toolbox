import SwiftUI
import AppKit

/// 渲染所需的上下文：当前文档路径、链接解析器与来源根（只用于经索引核验的本地图片）。
struct KnowledgeRenderContext {
    let document: String
    let resolver: KnowledgeLinkResolver
    let rootPath: String
    var highlightedBlock: Int? = nil

    func text(_ raw: String) -> AttributedString {
        KnowledgeMarkdownInline.attributed(raw, document: document, resolver: resolver)
    }
}

enum KnowledgeReaderFont {
    static func body(_ size: CGFloat = 14) -> Font { .system(size: size * CosmosUIPreferences.shared.textSize.scale) }
    static func mono(_ size: CGFloat = 12.5) -> Font { .system(size: size * CosmosUIPreferences.shared.textSize.scale, design: .monospaced) }
}

extension KnowledgeCalloutStyle.Tone {
    var color: Color {
        switch self {
        case .blue: return .blue
        case .cyan: return .teal
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .purple: return .purple
        case .gray: return .gray
        }
    }
}

struct KnowledgeMarkdownView: View {
    let blocks: [KnowledgeMarkdownBlock]
    let context: KnowledgeRenderContext
    /// 变化时滚动到 `id`；`serial` 保证重复请求也能触发。
    var scrollTarget: (id: Int, serial: UUID)? = nil
    var onLink: (URL) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(blocks) { block in
                        KnowledgeBlockView(block: block, context: context, depth: 0)
                            .id(block.id)
                            .background(context.highlightedBlock == block.id ? Color.yellow.opacity(0.18) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 28).padding(.vertical, 22)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .textSelection(.enabled)
            }
            .onChange(of: scrollTarget?.serial) { _, _ in
                if let target = scrollTarget { withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(target.id, anchor: .top) } }
            }
            .onAppear { if let target = scrollTarget { proxy.scrollTo(target.id, anchor: .top) } }
        }
        .environment(\.openURL, OpenURLAction { url in onLink(url); return .handled })
    }
}

struct KnowledgeBlockView: View {
    let block: KnowledgeMarkdownBlock
    let context: KnowledgeRenderContext
    let depth: Int

    var body: some View {
        switch block.kind {
        case .heading(let level, let text):
            let sizes: [CGFloat] = [0, 26, 22, 18, 16, 14, 14]
            Text(context.text(text)).font(KnowledgeReaderFont.body(sizes[min(level, 6)]).weight(.semibold))
                .padding(.top, level <= 2 ? 8 : 2).accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(context.text(text)).font(KnowledgeReaderFont.body()).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        case .list(let ordered, let start, let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        marker(ordered: ordered, number: start + offset, task: item.task)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(item.blocks) { KnowledgeBlockView(block: $0, context: context, depth: depth + 1) }
                        }
                    }
                }
            }
        case .quote(let nested):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.45)).frame(width: 3)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(nested) { KnowledgeBlockView(block: $0, context: context, depth: depth + 1) }
                }.foregroundStyle(.secondary)
            }
        case .callout(let type, let title, let nested):
            let style = KnowledgeCalloutStyle.style(for: type), color = style.tone.color
            VStack(alignment: .leading, spacing: 8) {
                Label { Text(context.text(title)).fontWeight(.semibold) } icon: { Image(systemName: style.symbol) }
                    .font(KnowledgeReaderFont.body()).foregroundStyle(color)
                ForEach(nested) { KnowledgeBlockView(block: $0, context: context, depth: depth + 1) }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusSmall))
            .overlay(alignment: .leading) { UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10).fill(color.opacity(0.7)).frame(width: 3) }
            .accessibilityElement(children: .contain).accessibilityLabel("提示框：" + title)
        case .code(let language, let text):
            VStack(alignment: .leading, spacing: 0) {
                if let language, !language.isEmpty {
                    Text(language).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.top, 8)
                }
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(text.isEmpty ? " " : text).font(KnowledgeReaderFont.mono()).fixedSize(horizontal: true, vertical: true)
                        .padding(12).textSelection(.enabled)
                }
            }
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusSmall))
        case .table(let header, let alignments, let rows):
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        ForEach(Array(header.enumerated()), id: \.offset) { offset, cell in
                            tableCell(cell, alignment: alignments[offset], header: true)
                        }
                    }
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Divider().gridCellUnsizedAxes(.horizontal)
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { offset, cell in
                                tableCell(cell, alignment: alignments[offset], header: false)
                            }
                        }
                    }
                }
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.12)) }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        case .rule:
            Divider().padding(.vertical, 4)
        case .image(let alt, let target):
            KnowledgeLocalImageView(alt: alt, target: target, context: context)
        }
    }

    private func tableCell(_ text: String, alignment: KnowledgeMarkdownBlock.Alignment, header: Bool) -> some View {
        Text(context.text(text)).font(KnowledgeReaderFont.body(13).weight(header ? .semibold : .regular))
            .multilineTextAlignment(alignment == .trailing ? .trailing : alignment == .center ? .center : .leading)
            .frame(minWidth: 70, maxWidth: 360, alignment: alignment == .trailing ? .trailing : alignment == .center ? .center : .leading)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(header ? Color.primary.opacity(0.06) : Color.clear)
    }

    @ViewBuilder private func marker(ordered: Bool, number: Int, task: Bool?) -> some View {
        if let task {
            Image(systemName: task ? "checkmark.square.fill" : "square").foregroundStyle(task ? Color.accentColor : Color.secondary)
                .accessibilityLabel(task ? "已完成" : "未完成")
        } else if ordered {
            Text("\(number).").font(KnowledgeReaderFont.body()).foregroundStyle(.secondary).monospacedDigit().frame(minWidth: 22, alignment: .trailing)
        } else {
            Text(depth == 0 ? "•" : "◦").font(KnowledgeReaderFont.body()).foregroundStyle(.secondary).frame(width: 14)
        }
    }
}

// MARK: - Local images (index-verified, never network)

nonisolated enum KnowledgeImageLoader {
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "tif", "bmp"]
    enum Resolution: Equatable { case file(path: String), network, missing }

    /// 只通过索引中的附件解析：被排除（敏感 / 隐藏 / 忽略 / 符号链接）的文件永远不会被解析到。
    static func resolve(_ target: String, document: String, resolver: KnowledgeLinkResolver) -> Resolution {
        let lowered = target.lowercased()
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") || lowered.hasPrefix("//") || lowered.hasPrefix("data:") { return .network }
        guard let path = resolver.resolveAttachment(target, from: document),
              imageExtensions.contains((path as NSString).pathExtension.lowercased()) else { return .missing }
        return .file(path: path)
    }
    static func load(rootPath: String, relativePath: String) -> NSImage? {
        guard let data = KnowledgeSourceScanner.readRegularFile(rootPath + "/" + relativePath, limit: KnowledgeSourceLimits.imageBytes) else { return nil }
        return NSImage(data: data)
    }
}

struct KnowledgeLocalImageView: View {
    let alt: String
    let target: String
    let context: KnowledgeRenderContext
    @State private var image: NSImage?
    @State private var failed = false
    var body: some View {
        let resolution = KnowledgeImageLoader.resolve(target, document: context.document, resolver: context.resolver)
        Group {
            switch resolution {
            case .network:
                placeholder("网络图片未加载", detail: target)
            case .missing:
                placeholder("找不到图片", detail: target)
            case .file(let path):
                if let image {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: 640, alignment: .leading)
                        .clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityLabel(alt.isEmpty ? "图片" : alt)
                } else if failed {
                    placeholder("无法读取图片", detail: path)
                } else {
                    ProgressView().controlSize(.small).frame(height: 60)
                        .task(id: path) {
                            let root = context.rootPath
                            let loaded = await Task.detached { KnowledgeImageLoader.load(rootPath: root, relativePath: path) }.value
                            if let loaded { image = loaded } else { failed = true }
                        }
                }
            }
        }
    }
    private func placeholder(_ title: String, detail: String) -> some View {
        Label { Text(title + "：" + detail).lineLimit(2) } icon: { Image(systemName: "photo") }
            .font(.caption).foregroundStyle(.secondary).padding(10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}
