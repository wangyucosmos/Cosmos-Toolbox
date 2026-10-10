import Foundation
import SwiftUI

// MARK: - Block model (pure)

nonisolated struct KnowledgeMarkdownBlock: Identifiable, Equatable, Sendable {
    enum Alignment: Equatable, Sendable { case leading, center, trailing }
    struct ListItem: Equatable, Sendable {
        /// nil = 普通项；false/true = 任务列表未完成/已完成。
        var task: Bool?
        var blocks: [KnowledgeMarkdownBlock]
    }
    indirect enum Kind: Equatable, Sendable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case list(ordered: Bool, start: Int, items: [ListItem])
        case quote([KnowledgeMarkdownBlock])
        case callout(type: String, title: String, body: [KnowledgeMarkdownBlock])
        case code(language: String?, text: String)
        case table(header: [String], alignments: [Alignment], rows: [[String]])
        case rule
        case image(alt: String, target: String)
    }
    let id: Int
    /// 在正文（不含 frontmatter）中的起始行（0 起）。
    let line: Int
    let kind: Kind
}

nonisolated enum KnowledgeMarkdown {
    static func parse(_ body: String) -> [KnowledgeMarkdownBlock] {
        var counter = 0
        let lines = body.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return parseBlocks(lines, baseLine: 0, counter: &counter)
    }

    /// 包含指定正文行的顶层块 ID（该行之前最近的块）。
    static func blockID(containingLine line: Int, in blocks: [KnowledgeMarkdownBlock]) -> Int? {
        blocks.last { $0.line <= line }?.id ?? blocks.first?.id
    }

    /// 与标题文本匹配的块 ID（忽略大小写、Unicode 规范化与行内标记符）。
    static func headingBlockID(_ heading: String, in blocks: [KnowledgeMarkdownBlock]) -> Int? {
        let target = normalizedHeading(heading)
        func search(_ blocks: [KnowledgeMarkdownBlock]) -> Int? {
            for block in blocks {
                if case .heading(_, let text) = block.kind, normalizedHeading(text) == target { return block.id }
            }
            return nil
        }
        return search(blocks)
    }
    static func normalizedHeading(_ text: String) -> String {
        KnowledgeLinkResolver.norm(text.filter { !"*_`~".contains($0) }.trimmingCharacters(in: .whitespaces))
    }

    // MARK: Block parsing

    private static func indent(of line: String) -> Int {
        var width = 0
        for ch in line { if ch == " " { width += 1 } else if ch == "\t" { width += 4 } else { break } }
        return width
    }
    private static func stripIndent(_ line: String, _ count: Int) -> String {
        var removed = 0, index = line.startIndex
        while index < line.endIndex, removed < count {
            let ch = line[index]
            if ch == " " { removed += 1 } else if ch == "\t" { removed += 4 } else { break }
            index = line.index(after: index)
        }
        return String(line[index...])
    }
    private static func isBlank(_ line: String) -> Bool { line.allSatisfy { $0 == " " || $0 == "\t" } }

    private static func fence(_ line: String) -> (char: Character, length: Int, info: String)? {
        guard indent(of: line) < 4 else { return nil }
        let trimmed = line.drop(while: { $0 == " " })
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        let run = trimmed.prefix(while: { $0 == first })
        guard run.count >= 3 else { return nil }
        let info = trimmed.dropFirst(run.count).trimmingCharacters(in: .whitespaces)
        if first == "`", info.contains("`") { return nil }
        return (first, run.count, info)
    }
    private static func heading(_ line: String) -> (Int, String)? {
        guard indent(of: line) < 4 else { return nil }
        let trimmed = line.drop(while: { $0 == " " })
        let hashes = trimmed.prefix(while: { $0 == "#" })
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = trimmed.dropFirst(hashes.count)
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        if text.allSatisfy({ $0 == "#" }) { text = "" }
        else if let range = text.range(of: "\\s+#+$", options: .regularExpression) { text.removeSubrange(range) }
        return (hashes.count, text.trimmingCharacters(in: .whitespaces))
    }
    private static func isRule(_ line: String) -> Bool {
        guard indent(of: line) < 4 else { return false }
        let compact = line.filter { $0 != " " && $0 != "\t" }
        guard compact.count >= 3, let first = compact.first, first == "-" || first == "*" || first == "_" else { return false }
        return compact.allSatisfy { $0 == first }
    }
    private static func quoteContent(_ line: String) -> String? {
        guard indent(of: line) < 4 else { return nil }
        let trimmed = line.drop(while: { $0 == " " })
        guard trimmed.first == ">" else { return nil }
        var rest = trimmed.dropFirst()
        if rest.first == " " { rest = rest.dropFirst() }
        return String(rest)
    }
    private static func listMarker(_ line: String) -> (indent: Int, ordered: Bool, number: Int, contentOffset: Int, text: String)? {
        let width = indent(of: line)
        guard width < 8 else { return nil }
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        guard let first = trimmed.first else { return nil }
        if first == "-" || first == "*" || first == "+" {
            let rest = trimmed.dropFirst()
            guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
            if isRule(line) { return nil }
            return (width, false, 0, width + 2, String(rest.drop(while: { $0 == " " || $0 == "\t" })))
        }
        let digits = trimmed.prefix(while: { $0.isNumber && $0.isASCII })
        guard (1...9).contains(digits.count), let number = Int(digits) else { return nil }
        let after = trimmed.dropFirst(digits.count)
        guard let sep = after.first, sep == "." || sep == ")" else { return nil }
        let rest = after.dropFirst()
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        return (width, true, number, width + digits.count + 2, String(rest.drop(while: { $0 == " " })))
    }
    private static func tableCells(_ line: String) -> [String]? {
        guard line.contains("|") else { return nil }
        var cells: [String] = [], current = "", inCode = false, escaped = false
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("|") { text.removeFirst() }
        for ch in text {
            if escaped { current.append(ch); escaped = false; continue }
            if ch == "\\" { escaped = true; current.append(ch); continue }
            if ch == "`" { inCode.toggle() }
            if ch == "|", !inCode { cells.append(current); current = "" } else { current.append(ch) }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty || !text.hasSuffix("|") { cells.append(current) }
        return cells.map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\\|", with: "|") }
    }
    private static func tableAlignments(_ line: String) -> [KnowledgeMarkdownBlock.Alignment]? {
        guard let cells = tableCells(line), !cells.isEmpty else { return nil }
        var result: [KnowledgeMarkdownBlock.Alignment] = []
        for cell in cells {
            let c = cell.trimmingCharacters(in: .whitespaces)
            guard c.contains("-"), c.allSatisfy({ $0 == "-" || $0 == ":" }) else { return nil }
            let left = c.hasPrefix(":"), right = c.hasSuffix(":")
            result.append(left && right ? .center : right ? .trailing : .leading)
        }
        return result
    }
    private static func standaloneImage(_ line: String) -> (alt: String, target: String)? {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("![["), t.hasSuffix("]]"), t.count > 5 {
            let inner = String(t.dropFirst(3).dropLast(2))
            guard !inner.contains("[["), !inner.contains("]]") else { return nil }
            let target = inner.split(separator: "|", maxSplits: 1).first.map(String.init) ?? inner
            return (target, target)
        }
        guard t.hasPrefix("!["), t.hasSuffix(")"), let close = t.range(of: "](") else { return nil }
        let alt = String(t[t.index(t.startIndex, offsetBy: 2)..<close.lowerBound])
        var target = String(t[close.upperBound...].dropLast())
        guard !alt.contains("]"), !target.contains(")") || target.hasPrefix("<") else { return nil }
        if target.hasPrefix("<"), target.hasSuffix(">") { target = String(target.dropFirst().dropLast()) }
        else if let space = target.firstIndex(of: " ") { target = String(target[..<space]) }
        return (alt, target.removingPercentEncoding ?? target)
    }
    private static func calloutHeader(_ line: String) -> (type: String, title: String)? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("[!"), let close = t.firstIndex(of: "]") else { return nil }
        let type = String(t[t.index(t.startIndex, offsetBy: 2)..<close]).lowercased()
        guard !type.isEmpty, type.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return nil }
        var rest = t[t.index(after: close)...]
        if rest.first == "+" || rest.first == "-" { rest = rest.dropFirst() }
        return (type, rest.trimmingCharacters(in: .whitespaces))
    }

    private static func startsBlock(_ line: String) -> Bool {
        fence(line) != nil || heading(line) != nil || isRule(line) || quoteContent(line) != nil || listMarker(line) != nil
    }

    private static func parseBlocks(_ lines: [String], baseLine: Int, counter: inout Int) -> [KnowledgeMarkdownBlock] {
        var blocks: [KnowledgeMarkdownBlock] = []
        var i = 0
        func make(_ line: Int, _ kind: KnowledgeMarkdownBlock.Kind) -> KnowledgeMarkdownBlock {
            defer { counter += 1 }
            return KnowledgeMarkdownBlock(id: counter, line: baseLine + line, kind: kind)
        }
        while i < lines.count {
            let line = lines[i]
            if isBlank(line) { i += 1; continue }
            let start = i
            if let f = fence(line) {
                var code: [String] = []
                i += 1
                while i < lines.count {
                    if let close = fence(lines[i]), close.char == f.char, close.length >= f.length, close.info.isEmpty { i += 1; break }
                    code.append(stripIndent(lines[i], indent(of: line))); i += 1
                }
                blocks.append(make(start, .code(language: f.info.isEmpty ? nil : String(f.info.split(separator: " ").first ?? ""), text: code.joined(separator: "\n"))))
                continue
            }
            if let (level, text) = heading(line) { blocks.append(make(start, .heading(level: level, text: text))); i += 1; continue }
            if isRule(line) { blocks.append(make(start, .rule)); i += 1; continue }
            if quoteContent(line) != nil {
                var inner: [String] = []
                while i < lines.count, let content = quoteContent(lines[i]) { inner.append(content); i += 1 }
                if let header = calloutHeader(inner[0]) {
                    let title = header.title.isEmpty ? header.type.prefix(1).uppercased() + header.type.dropFirst() : header.title
                    let nested = parseBlocks(Array(inner.dropFirst()), baseLine: baseLine + start + 1, counter: &counter)
                    blocks.append(make(start, .callout(type: header.type, title: title, body: nested)))
                } else {
                    let nested = parseBlocks(inner, baseLine: baseLine + start, counter: &counter)
                    blocks.append(make(start, .quote(nested)))
                }
                continue
            }
            if let marker = listMarker(line) {
                var items: [KnowledgeMarkdownBlock.ListItem] = []
                let ordered = marker.ordered, first = marker.number
                var cursor = i
                while cursor < lines.count, let m = listMarker(lines[cursor]), m.ordered == ordered, m.indent < marker.indent + 2 {
                    var itemLines = [m.text]
                    let itemStart = cursor
                    cursor += 1
                    var pendingBlank = 0
                    while cursor < lines.count {
                        let next = lines[cursor]
                        if isBlank(next) { pendingBlank += 1; itemLines.append(""); cursor += 1; continue }
                        if indent(of: next) >= m.indent + 2 {
                            pendingBlank = 0; itemLines.append(stripIndent(next, m.indent + 2)); cursor += 1; continue
                        }
                        if pendingBlank == 0, listMarker(next) == nil, !startsBlock(next), fence(next) == nil {
                            itemLines.append(next.trimmingCharacters(in: .whitespaces)); cursor += 1; continue   // 懒续行
                        }
                        break
                    }
                    while itemLines.last.map(isBlank) == true { itemLines.removeLast() }
                    var task: Bool?
                    var firstText = itemLines[0]
                    if firstText.hasPrefix("[ ] ") || firstText == "[ ]" { task = false; firstText = String(firstText.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
                    else if firstText.hasPrefix("[x] ") || firstText.hasPrefix("[X] ") || firstText == "[x]" || firstText == "[X]" {
                        task = true; firstText = String(firstText.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    }
                    itemLines[0] = firstText
                    items.append(.init(task: task, blocks: parseBlocks(itemLines, baseLine: baseLine + itemStart, counter: &counter)))
                    // 空行之后若不是同级标记行，则列表结束（保留空行位置供外层继续）
                    var probe = cursor
                    while probe < lines.count, isBlank(lines[probe]) { probe += 1 }
                    if probe < lines.count, let n = listMarker(lines[probe]), n.ordered == ordered, n.indent < marker.indent + 2 { cursor = probe }
                    else { break }
                }
                i = cursor
                blocks.append(make(start, .list(ordered: ordered, start: first, items: items)))
                continue
            }
            if i + 1 < lines.count, let header = tableCells(line), let alignments = tableAlignments(lines[i + 1]), header.count == alignments.count {
                var rows: [[String]] = []
                i += 2
                while i < lines.count, !isBlank(lines[i]), let cells = tableCells(lines[i]) {
                    var row = cells
                    if row.count < header.count { row += Array(repeating: "", count: header.count - row.count) }
                    rows.append(Array(row.prefix(header.count))); i += 1
                }
                blocks.append(make(start, .table(header: header, alignments: alignments, rows: rows)))
                continue
            }
            if let image = standaloneImage(line) { blocks.append(make(start, .image(alt: image.alt, target: image.target))); i += 1; continue }
            // 段落（含 setext 标题）
            var para = [line.trimmingCharacters(in: .whitespaces)]
            i += 1
            var setext: Int?
            while i < lines.count {
                let next = lines[i]
                if isBlank(next) { break }
                let t = next.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty, t.allSatisfy({ $0 == "=" }) { setext = 1; i += 1; break }
                if t.count >= 2, t.allSatisfy({ $0 == "-" }) { setext = 2; i += 1; break }
                if startsBlock(next) { break }
                if i + 1 < lines.count, tableCells(next) != nil, tableAlignments(lines[i + 1]) != nil { break }
                para.append(t); i += 1
            }
            if let level = setext { blocks.append(make(start, .heading(level: level, text: para.joined(separator: " ")))) }
            else { blocks.append(make(start, .paragraph(para.joined(separator: "\n")))) }
        }
        return blocks
    }
}

// MARK: - Callouts

nonisolated enum KnowledgeCalloutStyle {
    enum Tone: Sendable { case blue, cyan, green, orange, red, purple, gray }
    static func style(for type: String) -> (symbol: String, tone: Tone) {
        switch type.lowercased() {
        case "note": return ("pencil", .blue)
        case "abstract", "summary", "tldr": return ("doc.text", .cyan)
        case "info": return ("info.circle", .blue)
        case "todo": return ("checkmark.circle", .blue)
        case "tip", "hint", "important": return ("lightbulb", .cyan)
        case "success", "check", "done": return ("checkmark.seal", .green)
        case "question", "help", "faq": return ("questionmark.circle", .orange)
        case "warning", "caution", "attention": return ("exclamationmark.triangle", .orange)
        case "failure", "fail", "missing": return ("xmark.circle", .red)
        case "danger", "error": return ("bolt.trianglebadge.exclamationmark", .red)
        case "bug": return ("ladybug", .red)
        case "example": return ("list.bullet.rectangle", .purple)
        case "quote", "cite": return ("quote.opening", .gray)
        default: return ("pencil", .blue)
        }
    }
}

// MARK: - Inline conversion

nonisolated enum KnowledgeMarkdownInline {
    static let wikiScheme = "cosmoswiki", missingScheme = "cosmoswiki-missing", attachmentScheme = "cosmoswiki-attachment"

    /// 把 `[[...]]` 转成带自定义 scheme 的 Markdown 链接；行内代码内不转换。返回可交给 `AttributedString(markdown:)` 的文本。
    static func preprocess(_ text: String, document: String, resolver: KnowledgeLinkResolver) -> String {
        var output = "", index = text.startIndex
        while index < text.endIndex {
            let ch = text[index]
            if ch == "`" {
                let run = text[index...].prefix(while: { $0 == "`" })
                let fence = String(run)
                let afterRun = text.index(index, offsetBy: run.count)
                if let close = text.range(of: fence, range: afterRun..<text.endIndex) {
                    output += text[index..<close.upperBound]; index = close.upperBound; continue
                }
                output += fence; index = afterRun; continue
            }
            if ch == "\\", text.index(after: index) < text.endIndex {
                output += text[index...text.index(after: index)]; index = text.index(index, offsetBy: 2); continue
            }
            if ch == "!" || ch == "[" {
                let embed = ch == "!"
                let open = embed ? text.index(after: index) : index
                if open < text.endIndex, text[open...].hasPrefix("[["), let close = text.range(of: "]]", range: text.index(open, offsetBy: 2)..<text.endIndex) {
                    let inner = String(text[text.index(open, offsetBy: 2)..<close.lowerBound])
                    if !inner.isEmpty, !inner.contains("\n"), !inner.contains("[[") {
                        output += wikiLink(inner, embed: embed, document: document, resolver: resolver)
                        index = close.upperBound; continue
                    }
                }
                if embed, text[index...].hasPrefix("!["), let altEnd = text.range(of: "](", range: index..<text.endIndex),
                   let close = text.range(of: ")", range: altEnd.upperBound..<text.endIndex) {
                    // 行内图片（段落中间）：不加载，显示替代文本。
                    let alt = String(text[text.index(index, offsetBy: 2)..<altEnd.lowerBound])
                    output += "🖼 " + escape(alt.isEmpty ? "图片" : alt)
                    index = close.upperBound; continue
                }
            }
            output.append(ch); index = text.index(after: index)
        }
        return output
    }

    private static func wikiLink(_ inner: String, embed: Bool, document: String, resolver: KnowledgeLinkResolver) -> String {
        let parts = inner.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let targetText = parts[0], alias = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : nil
        let resolved = resolver.resolveWiki(targetText, from: document)
        var label = alias.flatMap { $0.isEmpty ? nil : $0 } ?? targetText.trimmingCharacters(in: .whitespaces)
        if alias == nil, let heading = resolved.heading, let hash = label.firstIndex(of: "#") {
            let name = String(label[..<hash]).trimmingCharacters(in: .whitespaces)
            label = name.isEmpty ? heading : name + " › " + heading
        }
        if embed { label = "🖼 " + label }
        var components = URLComponents()
        components.host = "link"
        switch resolved.target {
        case .document(let path):
            components.scheme = wikiScheme
            components.percentEncodedQuery = "p=" + enc(path) + (resolved.heading.map { "&h=" + enc($0) } ?? "")
        case .attachment(let path):
            components.scheme = attachmentScheme; components.percentEncodedQuery = "p=" + enc(path)
        case .unresolved:
            components.scheme = missingScheme; components.percentEncodedQuery = "n=" + enc(targetText)
        }
        guard let url = components.url?.absoluteString else { return escape(label) }
        return "[\(escape(label))](\(url))"
    }

    private static func enc(_ value: String) -> String { value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "" }
    private static func escape(_ text: String) -> String {
        var out = ""
        for ch in text { if "\\[]*_`~<>".contains(ch) { out.append("\\") }; out.append(ch) }
        return out
    }

    static func attributed(_ text: String, document: String, resolver: KnowledgeLinkResolver) -> AttributedString {
        let converted = preprocess(text, document: document, resolver: resolver)
        let options = AttributedString.MarkdownParsingOptions(allowsExtendedAttributes: false,
            interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
        var result = (try? AttributedString(markdown: converted, options: options)) ?? AttributedString(text)
        for run in result.runs {
            if let intent = run.inlinePresentationIntent, intent.contains(.code) {
                result[run.range].backgroundColor = Color.primary.opacity(0.08)
            }
            if let url = run.link, url.scheme == missingScheme {
                result[run.range].foregroundColor = Color.secondary
                result[run.range].underlineStyle = .single
            }
        }
        return result
    }

    /// 解析自定义 scheme 链接。
    enum LinkAction: Equatable {
        case document(path: String, heading: String?), attachment(path: String), missing(name: String), web(URL), relative(String), ignored
    }
    static func action(for url: URL) -> LinkAction {
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { query.first { $0.name == name }?.value }
        switch url.scheme?.lowercased() {
        case wikiScheme: return value("p").map { .document(path: $0, heading: value("h")) } ?? .ignored
        case attachmentScheme: return value("p").map { .attachment(path: $0) } ?? .ignored
        case missingScheme: return .missing(name: value("n") ?? "")
        case "http", "https": return .web(url)
        case nil, "": return .relative(url.absoluteString.removingPercentEncoding ?? url.absoluteString)
        default: return .ignored
        }
    }
}
