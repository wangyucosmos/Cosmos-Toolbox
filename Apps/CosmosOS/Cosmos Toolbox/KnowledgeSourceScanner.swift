import Foundation
import Darwin

// MARK: - Index model (memory only; never written to disk)

nonisolated enum KnowledgeExclusionReason: String, Sendable, CaseIterable {
    case hidden, builtinDirectory, gitignore, nestedRepository, sensitiveName, sensitiveFrontmatter, symlink, special
    var title: String {
        switch self {
        case .hidden: return "隐藏文件或目录"
        case .builtinDirectory: return "默认排除的目录"
        case .gitignore: return "被 .gitignore 规则排除"
        case .nestedRepository: return "嵌套的独立 Git 仓库（可作为单独来源添加）"
        case .sensitiveName: return "疑似敏感文件名"
        case .sensitiveFrontmatter: return "标记为 type: secret"
        case .symlink: return "符号链接（不跟随）"
        case .special: return "非普通文件"
        }
    }
}

nonisolated struct KnowledgeExclusion: Equatable, Sendable, Identifiable {
    var id: String { relativePath }
    let relativePath: String
    let reason: KnowledgeExclusionReason
    /// 触发的规则文本（仅 .gitignore 规则），绝不包含文件内容。
    var detail: String? = nil
}

nonisolated enum KnowledgeContentState: Equatable, Sendable {
    case loaded, tooLarge, budgetExceeded, notText, unreadable(String), metadataOnly
    var note: String? {
        switch self {
        case .loaded, .metadataOnly: return nil
        case .tooLarge: return "文件超过 2 MiB，仅列出，未读取内容"
        case .budgetExceeded: return "来源文本总量已达 64 MiB 上限，仅列出，未读取内容"
        case .notText: return "不是有效的 UTF-8 文本，未读取内容"
        case .unreadable(let reason): return "无法读取：" + reason
        }
    }
}

nonisolated struct KnowledgeDocument: Identifiable, Equatable, Sendable {
    var id: String { relativePath }
    let relativePath: String
    let title: String
    let frontmatter: KnowledgeFrontmatter
    let byteSize: Int
    let modifiedAt: Date
    let contentState: KnowledgeContentState
    /// 完整原文（含 frontmatter）。仅 `.loaded` 时非空；索引只在内存。
    let rawText: String
    /// 正文在 `rawText` 的 UTF-8 起始偏移。
    let bodyOffset: Int
    var fileName: String { (relativePath as NSString).lastPathComponent }
    var folder: String { (relativePath as NSString).deletingLastPathComponent }
    var tags: [String] { frontmatter.tags }
    var body: String { bodyOffset == 0 ? rawText : String(Substring(rawText.utf8.dropFirst(bodyOffset))) }
}

nonisolated struct KnowledgeAttachment: Identifiable, Equatable, Sendable {
    var id: String { relativePath }
    let relativePath: String
    let byteSize: Int
    let modifiedAt: Date
    var fileName: String { (relativePath as NSString).lastPathComponent }
    var folder: String { (relativePath as NSString).deletingLastPathComponent }
    var fileExtension: String { (relativePath as NSString).pathExtension.lowercased() }
}

nonisolated struct KnowledgeIndex: Equatable, Sendable {
    let sourceID: UUID
    let rootPath: String
    let scannedAt: Date
    var documents: [KnowledgeDocument] = []
    var attachments: [KnowledgeAttachment] = []
    /// 包含的目录（相对路径，排序）。
    var directories: [String] = []
    var exclusions: [KnowledgeExclusion] = []
    /// 不能可靠解析而被跳过的 .gitignore 行（只记录规则文本）。
    var unsupportedIgnoreLines: [String] = []
    var truncated = false
    var loadedTextBytes = 0

    func document(at path: String) -> KnowledgeDocument? { documents.first { $0.relativePath == path } }
    func attachment(at path: String) -> KnowledgeAttachment? { attachments.first { $0.relativePath == path } }
    var exclusionSummary: [(KnowledgeExclusionReason, Int)] {
        KnowledgeExclusionReason.allCases.compactMap { reason in
            let count = exclusions.filter { $0.reason == reason }.count
            return count == 0 ? nil : (reason, count)
        }
    }
    var resolver: KnowledgeLinkResolver { KnowledgeLinkResolver(documents: documents.map(\.relativePath), attachments: attachments.map(\.relativePath)) }
}

// MARK: - Frontmatter

nonisolated struct KnowledgeFrontmatter: Equatable, Sendable {
    var title: String?
    var typeValues: [String] = []
    var created: String?
    var tags: [String] = []
    /// 其它顶层字段（键 → 展示文本），保持出现顺序。
    var extra: [KnowledgeFrontmatterField] = []
    var present = false

    var type: String? { typeValues.isEmpty ? nil : typeValues.joined(separator: "、") }
    /// `type: secret` 是硬排除规则的一部分。
    var isSecret: Bool { typeValues.contains { $0.trimmingCharacters(in: .whitespaces).lowercased() == "secret" } }

    static let none = KnowledgeFrontmatter()

    /// 返回 frontmatter 与正文的 UTF-8 起始偏移（无 frontmatter 时为 0；偏移不含 BOM 处理，调用方传入已去 BOM 的文本）。
    static func parse(_ text: String) -> (frontmatter: KnowledgeFrontmatter, bodyOffset: Int) {
        let utf8 = Array(text.utf8)
        var lines: [(text: String, endOffset: Int)] = []
        var start = 0, index = 0
        func pushLine(_ end: Int, _ next: Int) {
            lines.append((String(decoding: utf8[start..<end], as: UTF8.self), next)); start = next
        }
        // 只扫描到第一个结束标记所需的行，避免对大文件全量拆行。
        var closing: Int?
        while index < utf8.count {
            if utf8[index] == 0x0A {
                var end = index
                if end > start, utf8[end - 1] == 0x0D { end -= 1 }
                pushLine(end, index + 1)
                if lines.count == 1 {
                    guard lines[0].text.trimmingCharacters(in: .whitespaces) == "---" else { return (.none, 0) }
                } else {
                    let trimmed = lines.last!.text.trimmingCharacters(in: .whitespaces)
                    if trimmed == "---" || trimmed == "..." { closing = lines.count - 1; break }
                }
            }
            index += 1
        }
        if closing == nil, start < utf8.count, lines.count >= 1 {
            // 最后一行无换行符
            let tail = String(decoding: utf8[start..<utf8.count], as: UTF8.self).trimmingCharacters(in: .whitespaces)
            if lines.count >= 1, tail == "---" || tail == "..." {
                pushLine(utf8.count, utf8.count); closing = lines.count - 1
            }
        }
        guard let closing, closing >= 1, lines[0].text.trimmingCharacters(in: .whitespaces) == "---" else { return (.none, 0) }
        var result = KnowledgeFrontmatter(); result.present = true
        let body = lines[1..<closing].map(\.text)
        var i = 0
        while i < body.count {
            let line = body[i]; i += 1
            guard let first = line.first, first != " ", first != "\t", first != "-", first != "#",
                  let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            var items: [String]?
            if value.isEmpty {
                var list: [String] = []
                while i < body.count {
                    let next = body[i]; let trimmed = next.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("- ") || trimmed == "-" {
                        list.append(unquote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))); i += 1
                    } else if trimmed.isEmpty { i += 1 } else { break }
                }
                if !list.isEmpty { items = list.filter { !$0.isEmpty } }
            } else if value.hasPrefix("["), value.hasSuffix("]") {
                items = splitFlow(String(value.dropFirst().dropLast()))
            }
            let lowerKey = key.lowercased()
            if items == nil, value.hasPrefix("|") || value.hasPrefix(">") {
                // 块标量：吞掉缩进行，字段不展示。
                while i < body.count, body[i].first == " " || body[i].first == "\t" || body[i].isEmpty { i += 1 }
                value = ""
            }
            value = unquote(value)
            switch lowerKey {
            case "title": result.title = items?.joined(separator: " ") ?? (value.isEmpty ? nil : value)
            case "type": result.typeValues = items ?? (value.isEmpty ? [] : value.split(separator: ",").map { unquote($0.trimmingCharacters(in: .whitespaces)) })
            case "created", "date": if result.created == nil { result.created = items?.first ?? (value.isEmpty ? nil : value) }
            case "tags", "tag":
                let raw = items ?? (value.isEmpty ? [] : value.split(separator: ",").map { unquote($0.trimmingCharacters(in: .whitespaces)) })
                result.tags += raw.map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }.filter { !$0.isEmpty }
            default:
                let shown = items?.joined(separator: "、") ?? value
                if !shown.isEmpty { result.extra.append(KnowledgeFrontmatterField(key: key, value: shown)) }
            }
        }
        result.tags = Array(NSOrderedSet(array: result.tags)) as? [String] ?? result.tags
        return (result, lines[closing].endOffset)
    }
    private static func unquote(_ value: String) -> String {
        var v = value.trimmingCharacters(in: .whitespaces)
        if v.count >= 2, let f = v.first, let l = v.last, (f == "\"" && l == "\"") || (f == "'" && l == "'") { v = String(v.dropFirst().dropLast()) }
        return v
    }
    private static func splitFlow(_ inner: String) -> [String] {
        var parts: [String] = [], current = "", quote: Character?
        for ch in inner {
            if let q = quote { current.append(ch); if ch == q { quote = nil } }
            else if ch == "\"" || ch == "'" { quote = ch; current.append(ch) }
            else if ch == "," { parts.append(current); current = "" }
            else { current.append(ch) }
        }
        parts.append(current)
        return parts.map { unquote($0) }.filter { !$0.isEmpty }
    }
}
nonisolated struct KnowledgeFrontmatterField: Equatable, Sendable { let key: String; let value: String }

// MARK: - .gitignore subset

nonisolated struct KnowledgeIgnoreRule: Equatable, Sendable {
    let raw: String
    let components: [String]
    let anchored: Bool
    let directoryOnly: Bool
}

/// 支持：目录名、带 `/` 的路径前缀、`*` 与 `?` 通配（不跨 `/`）、`#` 注释、前导 `/`、尾部 `/`。
/// 不支持（跳过并记录）：`!` 取反、`**`、`[...]`、反斜杠转义。
nonisolated struct KnowledgeIgnoreRules: Equatable, Sendable {
    var rules: [KnowledgeIgnoreRule] = []
    var unsupported: [String] = []

    static func parse(_ text: String) -> Self {
        var result = Self()
        for rawLine in text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }) {
            var line = String(rawLine)
            while line.hasSuffix(" ") || line.hasSuffix("\t") { line.removeLast() }
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("!") || line.contains("**") || line.contains("[") || line.contains("\\") || line.contains("\0") {
                result.unsupported.append(line); continue
            }
            var body = line, anchored = false, directoryOnly = false
            if body.hasPrefix("/") { anchored = true; body.removeFirst() }
            if body.hasSuffix("/") { directoryOnly = true; body.removeLast() }
            let comps = body.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            guard !comps.isEmpty, !comps.contains(""), !comps.contains("."), !comps.contains("..") else {
                result.unsupported.append(line); continue
            }
            if comps.count > 1 { anchored = true }
            result.rules.append(KnowledgeIgnoreRule(raw: line, components: comps, anchored: anchored, directoryOnly: directoryOnly))
        }
        return result
    }

    func matchedRule(path components: [String], isDirectory: Bool) -> KnowledgeIgnoreRule? {
        guard !components.isEmpty else { return nil }
        for rule in rules {
            if rule.anchored {
                guard rule.components.count <= components.count else { continue }
                var ok = true
                for (pattern, name) in zip(rule.components, components) where !Self.glob(pattern, name) { ok = false; break }
                guard ok else { continue }
                if rule.components.count == components.count, rule.directoryOnly, !isDirectory { continue }
                return rule
            } else {
                for (offset, name) in components.enumerated() where Self.glob(rule.components[0], name) {
                    if offset == components.count - 1, rule.directoryOnly, !isDirectory { continue }
                    return rule
                }
            }
        }
        return nil
    }

    /// 单个路径分量的通配匹配（`*` 任意长度，`?` 单个字符）；大小写与 Unicode 规范化不敏感（偏向多排除）。
    static func glob(_ pattern: String, _ text: String) -> Bool {
        let p = Array(pattern.precomposedStringWithCanonicalMapping.lowercased())
        let t = Array(text.precomposedStringWithCanonicalMapping.lowercased())
        var pi = 0, ti = 0, star = -1, mark = 0
        while ti < t.count {
            if pi < p.count, p[pi] == "?" || p[pi] == t[ti] { pi += 1; ti += 1 }
            else if pi < p.count, p[pi] == "*" { star = pi; mark = ti; pi += 1 }
            else if star >= 0 { pi = star + 1; mark += 1; ti = mark }
            else { return false }
        }
        while pi < p.count, p[pi] == "*" { pi += 1 }
        return pi == p.count
    }
}

// MARK: - Wiki links

nonisolated struct KnowledgeLinkResolver: Sendable {
    enum Target: Equatable, Sendable { case document(String), attachment(String), unresolved }
    private let documents: [String]
    private let attachments: [String]
    private let documentSet: Set<String>
    private let attachmentSet: Set<String>
    private let stems: [String: [String]]
    private let fileNames: [String: [String]]

    init(documents: [String], attachments: [String]) {
        self.documents = documents; self.attachments = attachments
        documentSet = Set(documents.map(Self.norm)); attachmentSet = Set(attachments.map(Self.norm))
        var stems: [String: [String]] = [:], names: [String: [String]] = [:]
        for path in documents {
            let name = (path as NSString).lastPathComponent
            stems[Self.norm((name as NSString).deletingPathExtension), default: []].append(path)
            names[Self.norm(name), default: []].append(path)
        }
        for path in attachments { names[Self.norm((path as NSString).lastPathComponent), default: []].append(path) }
        self.stems = stems; self.fileNames = names
    }
    static func norm(_ value: String) -> String { value.precomposedStringWithCanonicalMapping.lowercased() }

    /// 解析 `[[名称]]` / `[[名称#标题]]` 的目标部分（不含别名）。
    func resolveWiki(_ target: String, from current: String) -> (target: Target, heading: String?) {
        var name = target.trimmingCharacters(in: .whitespacesAndNewlines), heading: String?
        if let hash = name.firstIndex(of: "#") {
            let h = name[name.index(after: hash)...].trimmingCharacters(in: .whitespaces)
            heading = h.isEmpty ? nil : h
            name = String(name[..<hash]).trimmingCharacters(in: .whitespaces)
        }
        if name.isEmpty { return (heading != nil ? .document(current) : .unresolved, heading) }
        let key = Self.norm(name)
        var candidates: [String] = []
        if key.contains("/") {
            let withoutExt = key.hasSuffix(".md") ? String(key.dropLast(3)) : key
            candidates = documents.filter {
                let n = Self.norm($0); let noExt = n.hasSuffix(".md") ? String(n.dropLast(3)) : n
                return noExt == withoutExt || noExt.hasSuffix("/" + withoutExt) || n == key || n.hasSuffix("/" + key)
            }
            if candidates.isEmpty {
                let att = attachments.filter { Self.norm($0) == key || Self.norm($0).hasSuffix("/" + key) }
                if let best = best(att, current) { return (.attachment(best), heading) }
            }
        } else {
            let stemKey = (key.hasSuffix(".md") ? String(key.dropLast(3)) : key)
            candidates = stems[stemKey] ?? []
            if candidates.isEmpty { candidates = (fileNames[key] ?? []).filter { documentSet.contains(Self.norm($0)) } }
            if candidates.isEmpty, let match = fileNames[key], let best = best(match.filter { attachmentSet.contains(Self.norm($0)) }, current) {
                return (.attachment(best), heading)
            }
        }
        if let chosen = best(candidates, current) { return (.document(chosen), heading) }
        return (.unresolved, heading)
    }

    /// 解析标准 Markdown 链接中的相对路径（已百分号解码）。
    func resolveRelative(_ path: String, from current: String) -> (target: Target, heading: String?) {
        var raw = path, heading: String?
        if let hash = raw.firstIndex(of: "#") { heading = String(raw[raw.index(after: hash)...]); raw = String(raw[..<hash]) }
        if raw.isEmpty { return (heading != nil ? .document(current) : .unresolved, heading) }
        let base = (current as NSString).deletingLastPathComponent
        var parts = raw.hasPrefix("/") ? [] : base.split(separator: "/").map(String.init)
        for comp in raw.split(separator: "/").map(String.init) {
            if comp == "." { continue }
            if comp == ".." { guard !parts.isEmpty else { return (.unresolved, heading) }; parts.removeLast() }
            else { parts.append(comp) }
        }
        let joined = parts.joined(separator: "/"), key = Self.norm(joined)
        if documentSet.contains(key), let hit = documents.first(where: { Self.norm($0) == key }) { return (.document(hit), heading) }
        if attachmentSet.contains(key), let hit = attachments.first(where: { Self.norm($0) == key }) { return (.attachment(hit), heading) }
        return (.unresolved, heading)
    }

    /// 嵌入图片 `![[name.png]]` / 相对路径图片：只在附件索引中查找。
    func resolveAttachment(_ name: String, from current: String) -> String? {
        let relative = resolveRelative(name, from: current).target
        if case .attachment(let path) = relative { return path }
        if case .attachment(let path) = resolveWiki(name, from: current).target { return path }
        return nil
    }

    private func best(_ paths: [String], _ current: String) -> String? {
        let dir = (current as NSString).deletingLastPathComponent
        return paths.sorted {
            let a = ($0 as NSString).deletingLastPathComponent == dir, b = ($1 as NSString).deletingLastPathComponent == dir
            if a != b { return a }
            let ca = $0.split(separator: "/").count, cb = $1.split(separator: "/").count
            return ca == cb ? $0 < $1 : ca < cb
        }.first
    }
}

// MARK: - Scanner

nonisolated enum KnowledgeScanMode: Sendable {
    /// 读入文本全文（受单文件与总量上限限制）。
    case full
    /// 只读文件头用于标题 / 标签 / 敏感判定；不保留正文（统一检索使用）。
    case metadata
}

nonisolated struct KnowledgeScanLimits: Sendable {
    var fileBytes = KnowledgeSourceLimits.fileBytes
    var totalTextBytes = KnowledgeSourceLimits.totalTextBytes
    static let standard = KnowledgeScanLimits()
}

nonisolated enum KnowledgeSourceScanner {
    static let textExtensions: Set<String> = ["md", "markdown", "txt"]
    static let builtinDirectories: Set<String> = [".git", ".obsidian", ".trash", "node_modules", ".venv", "__pycache__"]
    static let sensitiveKeywords = ["密钥", "真实密钥", "secret", "token", "password", ".env"]

    static func isSensitiveName(_ name: String) -> Bool {
        let lowered = name.precomposedStringWithCanonicalMapping.lowercased()
        return sensitiveKeywords.contains { lowered.contains($0) }
    }

    /// 返回排除原因；nil = 保留。`components` 为相对来源根的完整路径分量，最后一项是被检查的条目。
    static func exclusionReason(name: String, isDirectory: Bool, components: [String], rules: KnowledgeIgnoreRules)
        -> (KnowledgeExclusionReason, String?)? {
        if builtinDirectories.contains(name) { return (.builtinDirectory, nil) }
        if name.hasPrefix(".") { return (.hidden, nil) }
        if isSensitiveName(name) { return (.sensitiveName, nil) }
        if let rule = rules.matchedRule(path: components, isDirectory: isDirectory) { return (.gitignore, rule.raw) }
        return nil
    }

    static func readIgnoreRules(root: String) -> KnowledgeIgnoreRules {
        guard let data = readRegularFile(root + "/.gitignore", limit: 256 * 1024), let text = String(data: data, encoding: .utf8) else { return KnowledgeIgnoreRules() }
        return KnowledgeIgnoreRules.parse(text)
    }

    static func scan(source: KnowledgeSource, mode: KnowledgeScanMode = .full, limits: KnowledgeScanLimits = .standard,
                     now: Date = Date()) throws -> KnowledgeIndex {
        try scan(root: source.path, sourceID: source.id, mode: mode, limits: limits, now: now)
    }

    static func scan(root: String, sourceID: UUID, mode: KnowledgeScanMode = .full, limits: KnowledgeScanLimits = .standard,
                     now: Date = Date()) throws -> KnowledgeIndex {
        guard KnowledgeSource.validPath(root), let rootKind = kind(root), rootKind == S_IFDIR else {
            throw KnowledgeSourceError.storage("来源文件夹不存在、不是文件夹，或是符号链接。")
        }
        var index = KnowledgeIndex(sourceID: sourceID, rootPath: root, scannedAt: now)
        let rules = readIgnoreRules(root: root)
        index.unsupportedIgnoreLines = rules.unsupported
        var directories: [String] = []
        var entriesSeen = 0
        var stack: [[String]] = [[]]
        while let current = stack.popLast() {
            try Task.checkCancellation()
            let relativeDir = current.joined(separator: "/")
            let absoluteDir = relativeDir.isEmpty ? root : root + "/" + relativeDir
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: absoluteDir) else {
                if !current.isEmpty { index.exclusions.append(.init(relativePath: relativeDir, reason: .special, detail: "目录不可读取")) }
                continue
            }
            for name in names.sorted() {
                try Task.checkCancellation()
                let components = current + [name]
                let relative = components.joined(separator: "/"), absolute = root + "/" + relative
                var info = stat()
                guard lstat(absolute, &info) == 0 else { continue }
                let type = info.st_mode & S_IFMT
                if type == S_IFLNK { index.exclusions.append(.init(relativePath: relative, reason: .symlink)); continue }
                let isDir = type == S_IFDIR
                guard isDir || type == S_IFREG else { index.exclusions.append(.init(relativePath: relative, reason: .special)); continue }
                if let (reason, detail) = exclusionReason(name: name, isDirectory: isDir, components: components, rules: rules) {
                    index.exclusions.append(.init(relativePath: relative, reason: reason, detail: detail)); continue
                }
                entriesSeen += 1
                if entriesSeen > KnowledgeSourceLimits.maxEntries { index.truncated = true; break }
                if isDir {
                    if hasGitEntry(absolute) { index.exclusions.append(.init(relativePath: relative, reason: .nestedRepository)); continue }
                    directories.append(relative); stack.append(components)
                    continue
                }
                let ext = (name as NSString).pathExtension.lowercased()
                let size = Int(info.st_size), modified = Date(timeIntervalSince1970: TimeInterval(info.st_mtimespec.tv_sec))
                if textExtensions.contains(ext) {
                    try addText(relative: relative, absolute: absolute, size: size, modified: modified, mode: mode, limits: limits, into: &index)
                } else {
                    index.attachments.append(KnowledgeAttachment(relativePath: relative, byteSize: size, modifiedAt: modified))
                }
            }
            if index.truncated { break }
        }
        index.directories = directories.sorted()
        index.documents.sort { $0.relativePath < $1.relativePath }
        index.attachments.sort { $0.relativePath < $1.relativePath }
        index.exclusions.sort { $0.relativePath < $1.relativePath }
        return index
    }

    // MARK: Text files

    private static func addText(relative: String, absolute: String, size: Int, modified: Date, mode: KnowledgeScanMode,
                                limits: KnowledgeScanLimits, into index: inout KnowledgeIndex) throws {
        let fallbackTitle = ((relative as NSString).lastPathComponent as NSString).deletingPathExtension
        func listOnly(_ state: KnowledgeContentState, head: Data?) {
            // 为敏感判定读取文件头（不保留）；type: secret 即使超限也被排除。
            if let head, classifySecret(head) {
                index.exclusions.append(.init(relativePath: relative, reason: .sensitiveFrontmatter)); return
            }
            index.documents.append(KnowledgeDocument(relativePath: relative, title: fallbackTitle, frontmatter: .none, byteSize: size,
                modifiedAt: modified, contentState: state, rawText: "", bodyOffset: 0))
        }
        let headLimit = KnowledgeSourceLimits.classificationHeadBytes
        let oversize = size > limits.fileBytes
        let overBudget = mode == .full && index.loadedTextBytes + size > limits.totalTextBytes
        if oversize || overBudget {
            listOnly(oversize ? .tooLarge : .budgetExceeded, head: readRegularFile(absolute, limit: headLimit, allowPartial: true))
            return
        }
        guard let data = readRegularFile(absolute, limit: mode == .full ? limits.fileBytes : headLimit,
                                         allowPartial: mode == .metadata) else {
            index.documents.append(KnowledgeDocument(relativePath: relative, title: fallbackTitle, frontmatter: .none, byteSize: size,
                modifiedAt: modified, contentState: .unreadable("读取失败"), rawText: "", bodyOffset: 0)); return
        }
        guard let decoded = decodeText(data, partial: mode == .metadata) else {
            // 非 UTF-8 / 含 NUL：仍用宽松解码判定 type: secret，之后丢弃。
            let lossy = String(decoding: data, as: UTF8.self)
            if classifySecret(lossy) { index.exclusions.append(.init(relativePath: relative, reason: .sensitiveFrontmatter)); return }
            index.documents.append(KnowledgeDocument(relativePath: relative, title: fallbackTitle, frontmatter: .none, byteSize: size,
                modifiedAt: modified, contentState: .notText, rawText: "", bodyOffset: 0)); return
        }
        let parsed = KnowledgeFrontmatter.parse(decoded)
        if parsed.frontmatter.isSecret { index.exclusions.append(.init(relativePath: relative, reason: .sensitiveFrontmatter)); return }
        let title = parsed.frontmatter.title.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? fallbackTitle
        switch mode {
        case .full:
            index.loadedTextBytes += data.count
            index.documents.append(KnowledgeDocument(relativePath: relative, title: title, frontmatter: parsed.frontmatter, byteSize: size,
                modifiedAt: modified, contentState: .loaded, rawText: decoded, bodyOffset: parsed.bodyOffset))
        case .metadata:
            index.documents.append(KnowledgeDocument(relativePath: relative, title: title, frontmatter: parsed.frontmatter, byteSize: size,
                modifiedAt: modified, contentState: .metadataOnly, rawText: "", bodyOffset: 0))
        }
    }

    private static func decodeText(_ data: Data, partial: Bool) -> String? {
        var bytes = data
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes = bytes.dropFirst(3) }
        guard !bytes.contains(0) else { return nil }
        if let text = String(data: bytes, encoding: .utf8) { return text }
        if partial {
            // 头部截断可能切在多字节字符中间：回退到最后一个完整字符。
            for cut in 1...3 where bytes.count > cut { if let text = String(data: bytes.dropLast(cut), encoding: .utf8) { return text } }
        }
        return nil
    }

    /// 只回答“是不是 type: secret”，不返回任何内容。
    private static func classifySecret(_ data: Data) -> Bool {
        guard let text = decodeText(data, partial: true) else { return classifySecret(String(decoding: data, as: UTF8.self)) }
        return classifySecret(text)
    }
    private static func classifySecret(_ text: String) -> Bool {
        var t = text
        if t.hasPrefix("\u{FEFF}") { t.removeFirst() }
        return KnowledgeFrontmatter.parse(t).frontmatter.isSecret
    }

    // MARK: File primitives (never follow symlinks, never write)

    static func kind(_ path: String) -> mode_t? {
        var info = stat()
        return lstat(path, &info) == 0 ? info.st_mode & S_IFMT : nil
    }
    static func hasGitEntry(_ directory: String) -> Bool { kind(directory + "/.git") != nil }

    static func readRegularFile(_ path: String, limit: Int, allowPartial: Bool = false) -> Data? {
        guard kind(path) == S_IFREG else { return nil }
        let fd = open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { return nil }
        if !allowPartial, info.st_size > limit { return nil }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        guard let data = try? handle.read(upToCount: limit + (allowPartial ? 0 : 1)) else { return nil }
        if !allowPartial, data.count > limit { return nil }
        return data
    }

    /// 规范化路径（解析符号链接、取磁盘真实大小写）。路径必须是目录。
    static func canonicalDirectory(_ url: URL) -> String? {
        let fd = open(url.path, O_RDONLY | O_DIRECTORY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard fcntl(fd, F_GETPATH, &buffer) == 0 else { return nil }
        let path = String(cString: buffer)
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}

// MARK: - Overlap between sources

nonisolated enum KnowledgeSourceOverlap {
    private static func components(_ path: String) -> [String] { path.split(separator: "/").map { KnowledgeLinkResolver.norm(String($0)) } }

    /// nil = 允许添加。
    static func rejection(candidate: String, existing: [KnowledgeSource]) -> KnowledgeSourceError? {
        let c = components(candidate)
        for source in existing {
            let e = components(source.path)
            if c == e { return .duplicateSource("该文件夹已作为来源「\(source.displayName)」添加。") }
            if c.count > e.count, Array(c.prefix(e.count)) == e {
                // 候选位于已有来源内部：仅当已有来源自身的排除规则已排除它时才允许（作为独立来源）。
                let relative = relativeComponents(candidate, under: source.path)
                if !isExcluded(relative, underRoot: source.path) {
                    return .overlap("该文件夹已包含在来源「\(source.displayName)」中，且未被其排除；重复添加会产生重叠。")
                }
            } else if e.count > c.count, Array(e.prefix(c.count)) == c {
                let relative = relativeComponents(source.path, under: candidate)
                if !isExcluded(relative, underRoot: candidate) {
                    return .overlap("该文件夹会包含已有来源「\(source.displayName)」，且不会将其排除；请先移除该来源。")
                }
            }
        }
        return nil
    }

    private static func relativeComponents(_ child: String, under parent: String) -> [String] {
        let all = child.split(separator: "/").map(String.init), skip = parent.split(separator: "/").count
        return Array(all.dropFirst(skip))
    }

    /// 以 `root` 为来源时，`relative`（目录）是否会被默认规则 / .gitignore / 嵌套仓库规则排除。
    static func isExcluded(_ relative: [String], underRoot root: String) -> Bool {
        let rules = KnowledgeSourceScanner.readIgnoreRules(root: root)
        var path = root
        for depth in 0..<relative.count {
            let name = relative[depth]
            path += "/" + name
            let prefix = Array(relative.prefix(depth + 1))
            if KnowledgeSourceScanner.kind(path) == S_IFLNK { return true }
            if KnowledgeSourceScanner.exclusionReason(name: name, isDirectory: true, components: prefix, rules: rules) != nil { return true }
            if KnowledgeSourceScanner.hasGitEntry(path) { return true }
        }
        return false
    }
}
