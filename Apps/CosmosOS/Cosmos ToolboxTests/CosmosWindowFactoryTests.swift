import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

/// 工厂只造窗口，不显示：测试不 orderFront、不 showWindow、
/// 不传 frameAutosaveName 给 makeWindow（避免写 UserDefaults），也不访问 ~/Documents。
@MainActor
final class CosmosWindowFactoryTests: XCTestCase {

    private final class Delegate: NSObject, NSWindowDelegate {}

    private func configuration(
        identifier: String? = nil,
        allowsFullScreen: Bool = false,
        delegate: NSWindowDelegate? = nil
    ) -> CosmosWindowConfiguration {
        CosmosWindowConfiguration(
            title: "测试窗口",
            contentSize: NSSize(width: 900, height: 700),
            minSize: NSSize(width: 700, height: 560),
            identifier: identifier,
            allowsFullScreen: allowsFullScreen,
            delegate: delegate
        )
    }

    func testHostingControllerBridgesToolbarAndTitle() throws {
        let window = CosmosWindowFactory.makeWindow(configuration(), rootView: Text("内容"))
        let host = try XCTUnwrap(window.contentViewController as? NSHostingController<Text>)
        XCTAssertEqual(host.sceneBridgingOptions, [.toolbars, .title])
        XCTAssertTrue(host.sceneBridgingOptions.contains(.toolbars))
        XCTAssertTrue(host.sceneBridgingOptions.contains(.title))
    }

    func testStandaloneHostingControllerAlsoBridges() {
        let host = CosmosWindowFactory.makeHostingController(rootView: Text("复用路径"))
        XCTAssertEqual(host.sceneBridgingOptions, [.toolbars, .title])
    }

    func testWindowAppearanceDefaults() {
        let window = CosmosWindowFactory.makeWindow(configuration(), rootView: Text("内容"))
        XCTAssertEqual(window.toolbarStyle, .unified)
        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertEqual(window.tabbingMode, .disallowed)
        XCTAssertFalse(window.isReleasedWhenClosed)
        XCTAssertEqual(window.minSize, NSSize(width: 700, height: 560))
        XCTAssertEqual(window.title, "测试窗口")
        for flag: NSWindow.StyleMask in [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView] {
            XCTAssertTrue(window.styleMask.contains(flag))
        }
        XCTAssertFalse(window.collectionBehavior.contains(.fullScreenPrimary))
        XCTAssertFalse(window.isVisible, "工厂不得显示窗口")
    }

    func testCompactToolbarStyleAndCustomStyleMaskAreHonoured() {
        var config = configuration()
        config.toolbarStyle = .unifiedCompact
        config.styleMask = [.titled, .closable, .fullSizeContentView]
        config.titleVisibility = .hidden
        let window = CosmosWindowFactory.makeWindow(config, rootView: Text("内容"))
        XCTAssertEqual(window.toolbarStyle, .unifiedCompact)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(window.styleMask.contains(.resizable))
    }

    func testContentSizeIdentifierFullScreenAndDelegatePassThrough() {
        let delegate = Delegate()
        let window = CosmosWindowFactory.makeWindow(
            configuration(identifier: "key::123", allowsFullScreen: true, delegate: delegate),
            rootView: Text("内容")
        )
        XCTAssertEqual(window.identifier?.rawValue, "key::123")
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenPrimary))
        XCTAssertTrue(window.delegate === delegate)
        XCTAssertEqual(window.contentLayoutRect.size.width, 900, accuracy: 1)
    }

    func testWindowWithoutIdentifierKeepsNoneAndNoDelegate() {
        let window = CosmosWindowFactory.makeWindow(configuration(), rootView: Text("内容"))
        XCTAssertNil(window.delegate)
        XCTAssertNotEqual(window.identifier?.rawValue, "key::123")
    }

    func testAutosaveNameIsPassedThroughVerbatimInConfiguration() {
        let existing = "任意既有 autosave 名 / legacy.name"
        var config = configuration()
        config.frameAutosaveName = existing
        XCTAssertEqual(config.frameAutosaveName, existing)

        let initWithName = CosmosWindowConfiguration(
            title: "t",
            contentSize: NSSize(width: 1, height: 1),
            minSize: NSSize(width: 1, height: 1),
            frameAutosaveName: existing
        )
        XCTAssertEqual(initWithName.frameAutosaveName, existing)
        XCTAssertNil(configuration().frameAutosaveName)
    }

    func testNewAutosaveNamesUseCosmosUIPrefix() {
        XCTAssertEqual(
            CosmosWindowConfiguration.newAutosaveName("artifactReview"),
            "cosmos.ui.window.artifactReview"
        )
        XCTAssertTrue(CosmosWindowConfiguration.newAutosaveName("x").hasPrefix("cosmos.ui."))
    }
}
