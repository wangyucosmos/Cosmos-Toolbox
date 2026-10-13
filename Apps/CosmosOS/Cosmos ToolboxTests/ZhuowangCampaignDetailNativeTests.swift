import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class ZhuowangCampaignDetailNativeTests: XCTestCase {
    private final class CloseDelegate: NSObject, NSWindowDelegate {
        var allowsClose = false
        var closeRequests = 0

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            closeRequests += 1
            return allowsClose
        }
    }

    func testDetailCloseUsesPerformCloseAndPreservesDelegateVeto() {
        let delegate = CloseDelegate()
        let window = CosmosWindowFactory.makeWindow(
            CosmosWindowConfiguration(title: "合成窗口", contentSize: NSSize(width: 980, height: 760),
                minSize: NSSize(width: 760, height: 620), identifier: UUID().uuidString, delegate: delegate),
            rootView: Text("合成内容")
        )
        defer { window.contentViewController = nil; window.close() }
        let context = ZhuowangDetailWindowContext()
        context.window = window
        context.close()
        XCTAssertEqual(delegate.closeRequests, 1)
        XCTAssertTrue(window.delegate === delegate)
        delegate.allowsClose = true
        context.close()
        XCTAssertEqual(delegate.closeRequests, 2)
    }

    func testDetailContextDoesNotRetainWindow() {
        let context = ZhuowangDetailWindowContext()
        autoreleasepool {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            context.window = window
        }
        XCTAssertNil(context.window)
        context.close()
    }
}
