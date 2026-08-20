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

        let htmlContent = try validatedHTML(
            rawAIResult
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

        if html.hasPrefix("```html") {
            html.removeFirst("```html".count)
        } else if html.hasPrefix("```") {
            html.removeFirst(3)
        }

        if html.hasSuffix("```") {
            html.removeLast(3)
        }

        html = html.trimmingCharacters(
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

        guard !normalized.contains("placeholder") else {
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
            return "HTML Prototype 仍包含 Placeholder，不能作为真实产物。"
        }
    }
}
