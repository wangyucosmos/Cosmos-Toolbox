import Foundation

// MARK: - 页内搜索（只搜已读入的文本；被排除的文件不在索引中）

nonisolated struct KnowledgeSearchHit: Identifiable, Equatable, Sendable {
    enum Field: String, Sendable { case title = "标题", path = "路径", tag = "标签", body = "正文" }
    var id: String { path }
    let path: String
    let title: String
    let isAttachment: Bool
    let fields: [Field]
    /// 命中片段（正文命中优先，否则标题 / 路径 / 标签）。
    let snippet: String
    /// 第一处正文命中所在的正文行（0 起）。
    let line: Int?
    let modifiedAt: Date
}

nonisolated enum KnowledgeSourceSearch {
    static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    static func search(_ rawQuery: String, in index: KnowledgeIndex, limit: Int = 200) throws -> [KnowledgeSearchHit] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        var scored: [(score: Int, hit: KnowledgeSearchHit)] = []
        for document in index.documents {
            try Task.checkCancellation()
            var fields: [KnowledgeSearchHit.Field] = [], score = 0
            var snippet = "", line: Int?
            if document.title.range(of: query, options: options) != nil { fields.append(.title); score += 8 }
            if document.relativePath.range(of: query, options: options) != nil { fields.append(.path); score += 4 }
            if let tag = document.tags.first(where: { $0.range(of: query, options: options) != nil }) {
                fields.append(.tag); score += 4; if snippet.isEmpty { snippet = "#" + tag }
            }
            if document.contentState == .loaded {
                let body = document.body
                if let range = body.range(of: query, options: options) {
                    fields.append(.body); score += 1
                    line = body[..<range.lowerBound].reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
                    snippet = Self.snippet(body, around: range)
                }
            }
            guard !fields.isEmpty else { continue }
            if snippet.isEmpty { snippet = fields.contains(.title) ? document.title : document.relativePath }
            scored.append((score, KnowledgeSearchHit(path: document.relativePath, title: document.title, isAttachment: false,
                fields: fields, snippet: snippet, line: line, modifiedAt: document.modifiedAt)))
        }
        for attachment in index.attachments where attachment.relativePath.range(of: query, options: options) != nil {
            scored.append((3, KnowledgeSearchHit(path: attachment.relativePath, title: attachment.fileName, isAttachment: true,
                fields: [.path], snippet: attachment.relativePath, line: nil, modifiedAt: attachment.modifiedAt)))
        }
        scored.sort { $0.score == $1.score ? ($0.hit.modifiedAt == $1.hit.modifiedAt ? $0.hit.path < $1.hit.path : $0.hit.modifiedAt > $1.hit.modifiedAt) : $0.score > $1.score }
        return scored.prefix(limit).map(\.hit)
    }

    /// 命中位置前后各取一小段，限制在同一行内并去掉多余空白。
    static func snippet(_ text: String, around range: Range<String.Index>) -> String {
        var lineStart = range.lowerBound
        while lineStart > text.startIndex, text[text.index(before: lineStart)] != "\n" { lineStart = text.index(before: lineStart) }
        var lineEnd = range.upperBound
        while lineEnd < text.endIndex, text[lineEnd] != "\n" { lineEnd = text.index(after: lineEnd) }
        let start = text.index(range.lowerBound, offsetBy: -36, limitedBy: lineStart) ?? lineStart
        let end = text.index(range.upperBound, offsetBy: 80, limitedBy: lineEnd) ?? lineEnd
        let core = text[start..<end].trimmingCharacters(in: .whitespaces)
        return (start > lineStart ? "…" : "") + core + (end < lineEnd ? "…" : "")
    }
}

// MARK: - 文件夹树

nonisolated struct KnowledgeFolderNode: Identifiable, Equatable, Sendable {
    var id: String { path }
    let path: String
    let name: String
    var children: [KnowledgeFolderNode]
    /// 该文件夹（含子文件夹）内的文档与附件数量。
    var itemCount: Int
}

nonisolated enum KnowledgeFolderTree {
    static func build(_ index: KnowledgeIndex) -> [KnowledgeFolderNode] {
        var counts: [String: Int] = [:]
        func bump(_ folder: String) {
            var current = folder
            while !current.isEmpty { counts[current, default: 0] += 1; current = (current as NSString).deletingLastPathComponent }
        }
        for document in index.documents { bump(document.folder) }
        for attachment in index.attachments { bump(attachment.folder) }
        // 只显示含有可见文档或附件的文件夹：空文件夹（或只含被排除文件的文件夹）不出现在树里。
        let all = Set(counts.keys)
        func children(of parent: String) -> [KnowledgeFolderNode] {
            all.filter { ($0 as NSString).deletingLastPathComponent == parent && $0 != parent }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                .map { KnowledgeFolderNode(path: $0, name: ($0 as NSString).lastPathComponent, children: children(of: $0), itemCount: counts[$0] ?? 0) }
        }
        return children(of: "")
    }

    static func contains(folder: String, path: String) -> Bool {
        folder.isEmpty || path == folder || path.hasPrefix(folder + "/")
    }
}
