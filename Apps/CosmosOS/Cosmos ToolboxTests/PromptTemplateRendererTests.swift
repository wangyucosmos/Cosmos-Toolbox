import XCTest
@testable import Cosmos_Toolbox

final class PromptTemplateRendererTests: XCTestCase {
    func values(_ renderer: PromptTemplateRenderer, _ pairs: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: renderer.variables.compactMap { variable in
            pairs[variable.name].map { (variable.id, $0) }
        })
    }
    func testOrderedRepeatedVariablesAndWhitespace() {
        let renderer = PromptTemplateRenderer("  \r\n{{ 省份\t}}/{{主题}}/{{省份}}\t\n")
        XCTAssertEqual(renderer.variables.map(\.name), ["省份", "主题"])
        let output = renderer.render(values: values(renderer, ["省份": "浙江", "主题": "  签到\n活动  "]))
        XCTAssertEqual(Data(output.text.utf8), Data("  \r\n浙江/  签到\n活动  /浙江\t\n".utf8))
        XCTAssertTrue(output.canCopy)
    }
    func testMissingAndCaseSensitive() {
        let renderer = PromptTemplateRenderer("{{Name}} {{name}} {{Name}}")
        let result = renderer.render(values: values(renderer, ["Name": " \n\t ", "name": "x"]))
        XCTAssertEqual(result.missing, ["Name"])
        XCTAssertEqual(result.text, "{{Name}} x {{Name}}")
        XCTAssertFalse(result.canCopy)
    }
    func testEscapesParityAndNonRecursiveValues() {
        let renderer = PromptTemplateRenderer(#"\{{x}}|\\{{x}}|\\\{{x}}|\\\\{{x}}|C:\abc"#)
        let result = renderer.render(values: values(renderer, ["x": "{{second}}\\\n"]))
        XCTAssertEqual(result.text, "{{x}}|\\{{second}}\\\n|\\{{x}}|\\\\{{second}}\\\n|C:\\abc")
        XCTAssertTrue(result.canCopy)
        XCTAssertEqual(renderer.variables.map(\.name), ["x"])
    }
    func testInvalidNestedAndUnclosedAreLiteral() {
        for text in ["{{}}", "{{a b}}", "{{a\nb}}", "{{1a}}", "{{a.b}}", "{{a{{inner}}}}", "{{{x}}}", "{{x}}}", "{{unclosed {{inner}}"] {
            let renderer = PromptTemplateRenderer(text)
            XCTAssertTrue(renderer.variables.isEmpty, text)
            XCTAssertEqual(Data(renderer.render(values: [:]).text.utf8), Data(text.utf8))
            XCTAssertFalse(renderer.warnings.isEmpty, text)
        }
    }
    func testUnicodeIdentityAndNameRules() {
        let renderer = PromptTemplateRenderer("{{省份}} {{_name-2}} {{é}} {{e\u{301}}}")
        XCTAssertEqual(renderer.variables.count, 4)
        XCTAssertEqual(Set(renderer.variables.map(\.id)).count, 4)
        let result = renderer.render(values: Dictionary(uniqueKeysWithValues: renderer.variables.enumerated().map { ($1.id, String($0)) }))
        XCTAssertEqual(result.text, "0 1 2 3")
    }
    func testNoVariablesAndStrayBracesPreserveBytes() {
        let text = "\t😀 e\u{301} \r\n{single} }} \\ {{ bad value }}\n "
        let renderer = PromptTemplateRenderer(text)
        XCTAssertEqual(Data(renderer.render(values: [:]).text.utf8), Data(text.utf8))
        XCTAssertTrue(renderer.render(values: [:]).canCopy)
    }
    func testLeadingCombiningMarkIsInvalidAndPreserved() {
        for text in ["{{\u{301}a}}", "{{ \u{301}a}}", "{{\u{301}}}", "x{{\u{301}}}y"] {
            let renderer = PromptTemplateRenderer(text)
            XCTAssertTrue(renderer.variables.isEmpty, text)
            XCTAssertFalse(renderer.warnings.isEmpty, text)
            let result = renderer.render(values: [:])
            XCTAssertEqual(Data(result.text.utf8), Data(text.utf8), "no Unicode normalization")
            XCTAssertTrue(result.missing.isEmpty)
            XCTAssertTrue(result.canCopy)
        }
    }
    func testLetterFollowedByMarksAndMixedNamesStayValid() {
        let renderer = PromptTemplateRenderer("{{e\u{301}}} {{a\u{301}\u{302}b}} {{_\u{301}}} {{中文_1-x}} {{x}} {{x}} \\{{x}}")
        XCTAssertEqual(renderer.variables.map { Array($0.name.unicodeScalars.map(\.value)) },
                       [[0x65, 0x301], [0x61, 0x301, 0x302, 0x62], [0x5f, 0x301], [0x4e2d, 0x6587, 0x5f, 0x31, 0x2d, 0x78], [0x78]])
        XCTAssertTrue(renderer.warnings.isEmpty)
    }
}
