import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

/// 只用随机 UserDefaults suite 注入；不写正式域，不显示窗口。
@MainActor
final class CosmosWindowFrameMemoryTests: XCTestCase {

    private var suites: [String] = []
    private var windows: [NSWindow] = []
    private let screens = [NSRect(x: 0, y: 0, width: 1920, height: 1080)]

    override func tearDown() {
        windows.forEach { $0.close() }
        windows.removeAll()
        for suite in suites { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        suites.removeAll()
        super.tearDown()
    }

    private func defaults() throws -> UserDefaults {
        let suite = "CosmosWindowFrameMemory." + UUID().uuidString
        suites.append(suite)
        return try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    private func window(minSize: NSSize = NSSize(width: 400, height: 300)) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.minSize = minSize
        windows.append(window)
        return window
    }

    private func uniqueKey() -> String { "test-" + UUID().uuidString }

    func testStorageKeyFormat() {
        XCTAssertEqual(CosmosWindowFrameMemory.storageKey("noteEditor"), "cosmos.ui.window.noteEditor.frame")
    }

    func testFirstOpenCentersWhenNothingStored() throws {
        let store = try defaults()
        let reference = window()
        reference.center()
        let subject = window()
        CosmosWindowFrameMemory.attach(subject, key: uniqueKey(), defaults: store, visibleFrames: screens)
        XCTAssertEqual(subject.frame, reference.frame)
        XCTAssertNil(store.string(forKey: CosmosWindowFrameMemory.storageKey("never-written")))
    }

    func testRestoresStoredFrame() throws {
        let store = try defaults()
        let key = uniqueKey()
        store.set("120 140 800 600 0 0 1920 1080", forKey: CosmosWindowFrameMemory.storageKey(key))
        let subject = window()
        CosmosWindowFrameMemory.attach(subject, key: key, defaults: store, visibleFrames: screens)
        XCTAssertEqual(subject.frame, NSRect(x: 120, y: 140, width: 800, height: 600))
    }

    func testInvalidStoredFrameFallsBackToCenter() throws {
        let store = try defaults()
        let reference = window()
        reference.center()
        for bad in ["50000 50000 800 600 0 0 1920 1080", "not a frame", "10 10 0 0", "nan 1 2 3", ""] {
            let key = uniqueKey()
            store.set(bad, forKey: CosmosWindowFrameMemory.storageKey(key))
            let subject = window()
            CosmosWindowFrameMemory.attach(subject, key: key, defaults: store, visibleFrames: screens)
            XCTAssertEqual(subject.frame, reference.frame, "descriptor: \(bad)")
        }
    }

    func testDisconnectedDisplayFrameFallsBack() throws {
        let store = try defaults()
        let key = uniqueKey()
        // 记录在 x=2200 的外接显示器上，该显示器已不在。
        store.set("2300 100 800 600 1920 0 1920 1080", forKey: CosmosWindowFrameMemory.storageKey(key))
        let reference = window()
        reference.center()
        let subject = window()
        CosmosWindowFrameMemory.attach(subject, key: key, defaults: store, visibleFrames: screens)
        XCTAssertEqual(subject.frame, reference.frame)
    }

    func testStoredFrameIsNeverSmallerThanMinSize() throws {
        let store = try defaults()
        let key = uniqueKey()
        store.set("100 200 300 200 0 0 1920 1080", forKey: CosmosWindowFrameMemory.storageKey(key))
        let subject = window(minSize: NSSize(width: 700, height: 560))
        CosmosWindowFrameMemory.attach(subject, key: key, defaults: store, visibleFrames: screens)
        XCTAssertGreaterThanOrEqual(subject.frame.width, 700)
        XCTAssertGreaterThanOrEqual(subject.frame.height, 560)
        XCTAssertEqual(subject.frame.minX, 100)
        XCTAssertEqual(subject.frame.maxY, 400, "放大时左上角保持不动")
    }

    func testUsableFrameRejectsTooLittleOverlap() {
        let sliver = CosmosWindowFrameMemory.usableFrame(
            descriptor: "1900 100 800 600", minSize: .zero, visibleFrames: screens)
        XCTAssertNil(sliver)
        let fine = CosmosWindowFrameMemory.usableFrame(
            descriptor: "1000 100 800 600", minSize: .zero, visibleFrames: screens)
        XCTAssertEqual(fine, NSRect(x: 1000, y: 100, width: 800, height: 600))
    }

    func testSecondWindowOfSameTypeIsCascaded() throws {
        let store = try defaults()
        let key = uniqueKey()
        store.set("120 140 800 600", forKey: CosmosWindowFrameMemory.storageKey(key))
        let first = window()
        CosmosWindowFrameMemory.attach(first, key: key, defaults: store, visibleFrames: screens)
        let second = window()
        CosmosWindowFrameMemory.attach(second, key: key, defaults: store, visibleFrames: screens)
        XCTAssertNotEqual(second.frame.origin, first.frame.origin, "同类第二个窗口不得完全重叠")
        XCTAssertEqual(CosmosWindowFrameMemory.trackedWindowCount(key: key), 2)
    }

    func testDifferentTypesDoNotCascade() throws {
        let store = try defaults()
        let keyA = uniqueKey(), keyB = uniqueKey()
        let first = window()
        CosmosWindowFrameMemory.attach(first, key: keyA, defaults: store, visibleFrames: screens)
        let second = window()
        CosmosWindowFrameMemory.attach(second, key: keyB, defaults: store, visibleFrames: screens)
        XCTAssertEqual(second.frame, first.frame)
    }

    func testFullScreenAndMiniaturizedAreNotEligibleForSave() {
        XCTAssertTrue(CosmosWindowFrameMemory.isEligibleForSave(styleMask: [.titled, .resizable], isMiniaturized: false))
        XCTAssertFalse(CosmosWindowFrameMemory.isEligibleForSave(styleMask: [.titled, .fullScreen], isMiniaturized: false))
        XCTAssertFalse(CosmosWindowFrameMemory.isEligibleForSave(styleMask: [.titled], isMiniaturized: true))
    }

    /// 不真的进入全屏（会触发系统动画）：只让 styleMask 报告 .fullScreen。
    private final class FullScreenReportingWindow: NSWindow {
        var reportsFullScreen = true
        override var styleMask: NSWindow.StyleMask {
            get { reportsFullScreen ? super.styleMask.union(.fullScreen) : super.styleMask }
            set { super.styleMask = newValue }
        }
    }

    func testSaveIsSkippedWhileFullScreen() throws {
        let store = try defaults()
        let key = uniqueKey()
        let subject = FullScreenReportingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        subject.isReleasedWhenClosed = false
        windows.append(subject)
        XCTAssertTrue(subject.styleMask.contains(.fullScreen))
        XCTAssertFalse(CosmosWindowFrameMemory.save(subject, key: key, defaults: store))
        XCTAssertNil(store.string(forKey: CosmosWindowFrameMemory.storageKey(key)))
        subject.reportsFullScreen = false
        XCTAssertTrue(CosmosWindowFrameMemory.save(subject, key: key, defaults: store))
        XCTAssertNotNil(store.string(forKey: CosmosWindowFrameMemory.storageKey(key)))
    }

    func testClosingSavesFrameAndRemovesTracking() throws {
        let store = try defaults()
        let key = uniqueKey()
        let subject = window()
        CosmosWindowFrameMemory.attach(subject, key: key, defaults: store, visibleFrames: screens)
        subject.setFrame(NSRect(x: 300, y: 220, width: 777, height: 555), display: false)
        XCTAssertEqual(CosmosWindowFrameMemory.trackedWindowCount(key: key), 1)
        subject.close()
        let saved = try XCTUnwrap(store.string(forKey: CosmosWindowFrameMemory.storageKey(key)))
        XCTAssertEqual(
            CosmosWindowFrameMemory.usableFrame(descriptor: saved, minSize: .zero, visibleFrames: screens),
            NSRect(x: 300, y: 220, width: 777, height: 555))
        XCTAssertEqual(CosmosWindowFrameMemory.trackedWindowCount(key: key), 0)

        // 下一次同类型窗口恢复到该位置。
        let next = window()
        CosmosWindowFrameMemory.attach(next, key: key, defaults: store, visibleFrames: screens)
        XCTAssertEqual(next.frame, NSRect(x: 300, y: 220, width: 777, height: 555))
    }

    func testResizeEndSavesImmediately() throws {
        let store = try defaults()
        let key = uniqueKey()
        let subject = window()
        CosmosWindowFrameMemory.attach(subject, key: key, defaults: store, visibleFrames: screens)
        subject.setFrame(NSRect(x: 50, y: 60, width: 700, height: 500), display: false)
        NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: subject)
        XCTAssertNotNil(store.string(forKey: CosmosWindowFrameMemory.storageKey(key)))
    }

    func testFactoryUsesFrameMemoryInsteadOfCenteringWhenKeyGiven() throws {
        let store = try defaults()
        let key = uniqueKey()
        store.set("90 110 820 640", forKey: CosmosWindowFrameMemory.storageKey(key))
        var config = CosmosWindowConfiguration(
            title: "t", contentSize: NSSize(width: 900, height: 700), minSize: NSSize(width: 500, height: 400),
            frameMemoryKey: key)
        config.frameMemoryDefaults = store
        let subject = CosmosWindowFactory.makeWindow(config, rootView: Text("x"))
        windows.append(subject)
        XCTAssertEqual(subject.frame.origin, NSPoint(x: 90, y: 110))
        XCTAssertEqual(subject.frame.size, NSSize(width: 820, height: 640))
    }

    func testFactoryWithoutKeyKeepsCentering() throws {
        let config = CosmosWindowConfiguration(
            title: "t", contentSize: NSSize(width: 900, height: 700), minSize: NSSize(width: 500, height: 400))
        XCTAssertNil(config.frameMemoryKey)
        let subject = CosmosWindowFactory.makeWindow(config, rootView: Text("x"))
        windows.append(subject)
        let reference = window()
        reference.setFrame(subject.frame, display: false)
        reference.center()
        XCTAssertEqual(subject.frame.origin, reference.frame.origin)
    }
}
