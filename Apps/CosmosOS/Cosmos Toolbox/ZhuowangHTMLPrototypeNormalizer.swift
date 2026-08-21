import Foundation

// MARK: - HTML Prototype Normalizer

/// Extracts one complete HTML document without repairing or synthesizing it.
/// Structural validity remains the responsibility of the HTML Tool Adapter.
struct ZhuowangHTMLPrototypeNormalizer {

    func normalize(
        _ rawValue: String
    ) throws -> String {

        let boundaryCharacters =
            CharacterSet.whitespacesAndNewlines.union(
                CharacterSet(charactersIn: "\u{FEFF}")
            )

        let cleaned = rawValue.trimmingCharacters(
            in: boundaryCharacters
        )

        guard !cleaned.isEmpty else {
            throw ZhuowangHTMLPrototypeNormalizerError
                .missingCompleteDocument
        }

        let pattern =
            "(?:<!doctype\\s+html[^>]*>\\s*)?<html\\b[^>]*>.*?</html\\s*>"
        let regularExpression = try NSRegularExpression(
            pattern: pattern,
            options: [
                .caseInsensitive,
                .dotMatchesLineSeparators
            ]
        )
        let searchRange = NSRange(
            cleaned.startIndex..<cleaned.endIndex,
            in: cleaned
        )
        let matches = regularExpression.matches(
            in: cleaned,
            options: [],
            range: searchRange
        )

        guard matches.count == 1 else {
            if matches.isEmpty {
                throw ZhuowangHTMLPrototypeNormalizerError
                    .missingCompleteDocument
            }

            throw ZhuowangHTMLPrototypeNormalizerError
                .ambiguousDocuments
        }

        guard let documentRange = Range(
            matches[0].range,
            in: cleaned
        ) else {
            throw ZhuowangHTMLPrototypeNormalizerError
                .missingCompleteDocument
        }

        return String(cleaned[documentRange])
            .trimmingCharacters(in: boundaryCharacters)
    }
}


enum ZhuowangHTMLPrototypeNormalizerError: LocalizedError {

    case missingCompleteDocument
    case ambiguousDocuments

    var errorDescription: String? {
        switch self {
        case .missingCompleteDocument:
            return "AI 返回结果中没有唯一、完整的 HTML document。"
        case .ambiguousDocuments:
            return "AI 返回结果中包含多个 HTML document，无法安全确定产物。"
        }
    }
}
