import Foundation


// MARK: - HTML Prototype Adapter
//
// Cosmos OS 默认原型输出方式之一。
// 不绑定 Figma。
// 可用于生成 HTML Prototype、Web Preview 等形式。


struct ZhuowangHTMLPrototypeAdapter: ZhuowangToolAdapter {

    let toolID: UUID = UUID()

    let name: String = "HTML Prototype Generator"


    let capabilities: [ZhuowangWorkflowCapability] = [
        .prototypeDesign
    ]


    func execute(
        taskPackage: ZhuowangAITaskPackage
    ) async throws -> ZhuowangArtifact {


        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>Cosmos Prototype</title>
        </head>

        <body>

        <h1>
        \(taskPackage.title)
        </h1>

        <p>
        HTML Prototype Placeholder
        </p>

        </body>
        </html>
        """


        return ZhuowangArtifact(
            campaignID: taskPackage.campaignID,
            stepID: taskPackage.workflowStepID,
            name: "\(taskPackage.title).html",
            type: .html,
            location: "",
            content: htmlContent,
            version: 1,
            isApprovedVersion: false
        )
    }
}
