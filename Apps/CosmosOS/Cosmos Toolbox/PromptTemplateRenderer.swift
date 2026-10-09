import Foundation

nonisolated struct PromptVariable: Identifiable, Equatable, Sendable {
    let name: String
    // UTF-8 identity deliberately distinguishes canonically equivalent spellings.
    var id: String { Data(name.utf8).base64EncodedString() }
}

nonisolated struct PromptRenderResult: Equatable, Sendable {
    let text: String
    let missing: [String]
    let warnings: [String]
    var canCopy: Bool { missing.isEmpty }
}

nonisolated struct PromptTemplateRenderer: Sendable {
    enum Token: Sendable { case text(String), variable(PromptVariable, original: String) }
    let tokens: [Token]
    let variables: [PromptVariable]
    let warnings: [String]

    init(_ source: String) {
        let bytes = Array(source.utf8)
        var tokens: [Token] = [], variables: [PromptVariable] = [], warnings: [String] = []
        var cursor = 0, rawStart = 0
        func string(_ a: Int, _ b: Int) -> String { String(decoding: bytes[a..<b], as: UTF8.self) }
        func appendRaw(_ end: Int) {
            if rawStart < end { tokens.append(.text(string(rawStart, end))) }
        }
        while cursor < bytes.count {
            guard bytes[cursor] == 123 || bytes[cursor] == 125 else { cursor += 1; continue }
            if bytes[cursor] == 125 {
                let start = cursor
                while cursor < bytes.count, bytes[cursor] == 125 { cursor += 1 }
                if cursor - start >= 2 { warnings.append("位置 (start + 1)：多余结束花括号按原文保留。") }
                continue
            }
            guard cursor + 1 < bytes.count, bytes[cursor + 1] == 123 else { cursor += 1; continue }
            let start = cursor
            var end = cursor + 2, depth = 1, nested = false, closed = false
            while end < bytes.count {
                if end + 1 < bytes.count, bytes[end] == 123, bytes[end + 1] == 123 {
                    depth += 1; nested = true; end += 2
                } else if end + 1 < bytes.count, bytes[end] == 125, bytes[end + 1] == 125 {
                    depth -= 1; end += 2
                    if depth == 0 { closed = true; break }
                } else { end += 1 }
            }
            if !closed { end = bytes.count }
            while end < bytes.count, bytes[end] == 125 { end += 1; nested = true }
            let innerEnd = closed ? end - 2 : end
            let name = string(start + 2, max(start + 2, innerEnd))
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
            let valid = closed && !nested && Self.validName(name)
            guard valid else {
                warnings.append("位置 (start + 1)：无效或不完整占位符按原文保留。")
                cursor = end; continue
            }
            var slashStart = start
            while slashStart > rawStart, bytes[slashStart - 1] == 92 { slashStart -= 1 }
            appendRaw(slashStart)
            let slashCount = start - slashStart
            if slashCount / 2 > 0 { tokens.append(.text(String(repeating: "\\", count: slashCount / 2))) }
            let original = string(start, end)
            if slashCount % 2 == 1 { tokens.append(.text(original)) }
            else {
                let variable = PromptVariable(name: name)
                tokens.append(.variable(variable, original: original))
                if !variables.contains(where: { $0.id == variable.id }) { variables.append(variable) }
            }
            cursor = end; rawStart = end
        }
        appendRaw(bytes.count)
        self.tokens = tokens; self.variables = variables; self.warnings = warnings
    }

    // Syntax: first scalar is a Unicode letter (L*) or "_"; the rest may be a letter, a
    // combining mark (M*), a decimal digit (Nd), "_" or "-". Judged per scalar via general
    // category, so a bare combining mark can never start a name while "e" + U+0301 can.
    private static func validName(_ name: String) -> Bool {
        let scalars = Array(name.unicodeScalars)
        guard let first = scalars.first, first == "_" || isLetter(first) else { return false }
        return scalars.dropFirst().allSatisfy {
            $0 == "_" || $0 == "-" || isLetter($0) || isMark($0) || $0.properties.generalCategory == .decimalNumber
        }
    }
    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter: return true
        default: return false
        }
    }
    private static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: return true
        default: return false
        }
    }

    func render(values: [String: String]) -> PromptRenderResult {
        var text = "", missing: [String] = []
        for token in tokens {
            switch token {
            case .text(let original): text += original
            case .variable(let variable, let original):
                let value = values[variable.id] ?? ""
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    text += original
                    if !missing.contains(where: { Data($0.utf8) == Data(variable.name.utf8) }) { missing.append(variable.name) }
                } else { text += value }
            }
        }
        return PromptRenderResult(text: text, missing: missing, warnings: warnings)
    }
}
