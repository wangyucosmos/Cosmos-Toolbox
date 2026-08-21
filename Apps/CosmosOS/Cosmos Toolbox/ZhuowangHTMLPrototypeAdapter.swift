import Foundation


// MARK: - HTML Prototype Adapter
//
// Cosmos OS 默认原型输出方式之一。
// 不绑定 Figma。
// 可用于生成 HTML Prototype、Web Preview 等形式。


struct ZhuowangHTMLPrototypeAdapter: ZhuowangToolAdapter {

    let toolID: UUID =
        ZhuowangBuiltInIntegrationIDs.htmlPrototypeTool

    let name: String = "HTML Prototype Generator"


    let capabilities: [ZhuowangWorkflowCapability] = [
        .prototypeDesign
    ]


    func execute(
        taskPackage: ZhuowangAITaskPackage,
        rawAIResult: String
    ) async throws -> ZhuowangArtifactDraft {

        let normalizedHTML = try ZhuowangHTMLPrototypeNormalizer()
            .normalize(rawAIResult)

        let htmlContent = try validatedHTML(
            normalizedHTML
        )

        return ZhuowangArtifactDraft(
            logicalKey:
                "workflow.prototypeDesign.primary",
            name:
                "产品原型设计",
            type:
                .html,
            content:
                htmlContent,
            preferredFileExtension:
                "html"
        )
    }


    private func validatedHTML(
        _ value: String
    ) throws -> String {

        var html = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !html.isEmpty else {
            throw ZhuowangHTMLPrototypeAdapterError.emptyHTML
        }

        guard html.data(using: .utf8) != nil else {
            throw ZhuowangHTMLPrototypeAdapterError.invalidUTF8
        }

        let normalized = html.lowercased()

        guard
            normalized.contains("<html"),
            normalized.contains("</html>"),
            normalized.contains("<head"),
            normalized.contains("</head>"),
            normalized.contains("<body"),
            normalized.contains("</body>")
        else {
            throw ZhuowangHTMLPrototypeAdapterError.invalidStructure
        }

        guard hasNoUnimplementedContent(in: html) else {
            throw ZhuowangHTMLPrototypeAdapterError.placeholderContent
        }

        let contentSecurityPolicy =
            "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data: blob:; font-src data:;\">"

        guard let headRange = html.range(
            of: "<head[^>]*>",
            options: [
                .regularExpression,
                .caseInsensitive
            ]
        ) else {
            throw ZhuowangHTMLPrototypeAdapterError.invalidStructure
        }

        html.insert(
            contentsOf: "\n\(contentSecurityPolicy)",
            at: headRange.upperBound
        )

        return html
    }


    private func hasNoUnimplementedContent(
        in html: String
    ) -> Bool {

        let allowedAttributePattern =
            "<(?:input|textarea)\\b[^>]*>"

        guard let tagExpression = try? NSRegularExpression(
            pattern: allowedAttributePattern,
            options: [
                .caseInsensitive,
                .dotMatchesLineSeparators
            ]
        ) else {
            return false
        }

        var inspectionText = html
        let fullRange = NSRange(
            inspectionText.startIndex..<inspectionText.endIndex,
            in: inspectionText
        )
        let allowedTags = tagExpression.matches(
            in: inspectionText,
            options: [],
            range: fullRange
        )

        for match in allowedTags.reversed() {
            guard let range = Range(
                match.range,
                in: inspectionText
            ) else {
                return false
            }

            let tag = String(inspectionText[range])
            let normalizedTag = tag.replacingOccurrences(
                of: "\\bplaceholder\\s*=",
                with: "data-cosmos-input-hint=",
                options: [
                    .regularExpression,
                    .caseInsensitive
                ]
            )

            inspectionText.replaceSubrange(
                range,
                with: normalizedTag
            )
        }

        let normalizedInspection =
            inspectionText.lowercased()

        let prohibitedMarkers = [
            "placeholder",
            "todo",
            "后续补充",
            "待补充",
            "待实现",
            "空白模块"
        ]

        return !prohibitedMarkers.contains {
            normalizedInspection.contains($0)
        }
    }
}


enum ZhuowangHTMLPrototypeAdapterError: LocalizedError {

    case emptyHTML
    case invalidUTF8
    case invalidStructure
    case placeholderContent

    var errorDescription: String? {
        switch self {
        case .emptyHTML:
            return "HTML Prototype 内容为空。"
        case .invalidUTF8:
            return "HTML Prototype 不是有效 UTF-8 内容。"
        case .invalidStructure:
            return "HTML Prototype 缺少完整的 html、head 或 body 结构。"
        case .placeholderContent:
            return "HTML Prototype 仍包含 Placeholder、TODO 或未实现内容，不能作为真实产物。"
        }
    }
}
