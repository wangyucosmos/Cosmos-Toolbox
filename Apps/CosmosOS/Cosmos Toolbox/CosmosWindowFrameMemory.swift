import AppKit

/// 窗口位置与大小记忆：按“窗口类型”记一份（不按对象），存 `cosmos.ui.window.<key>.frame`，
/// 值是 NSWindow frame descriptor 字符串（`NSWindow.frameDescriptor`）。
///
/// - attach：有可用的已存 frame → 应用（不小于 `window.minSize`）；同类型已有打开中的窗口 →
///   在它的基础上 `cascadeTopLeft` 错开；无记录或记录失效（显示器拔掉等）→ `center()`。
/// - 保存：移动 / 调整大小结束（防抖）、即将关闭。全屏、最小化时不保存。
/// - 不碰 `identifier`、`delegate`、窗口复用；观察者随窗口关闭移除，不持有窗口。
enum CosmosWindowFrameMemory {

    static func storageKey(_ key: String) -> String {
        "cosmos.ui.window.\(key).frame"
    }

    static func attach(
        _ window: NSWindow,
        key: String,
        defaults: UserDefaults = .standard
    ) {
        attach(
            window,
            key: key,
            defaults: defaults,
            visibleFrames: NSScreen.screens.map(\.visibleFrame)
        )
    }

    // MARK: - Restore

    /// `visibleFrames` 可注入，便于测试“显示器拔掉”。
    static func attach(
        _ window: NSWindow,
        key: String,
        defaults: UserDefaults,
        visibleFrames: [NSRect]
    ) {
        registry.removeAll { $0.window == nil }

        let sibling = registry.last { $0.key == key && $0.window != nil }?.window

        if let stored = defaults.string(forKey: storageKey(key)),
           let frame = usableFrame(
            descriptor: stored,
            minSize: window.minSize,
            visibleFrames: visibleFrames
           ) {
            window.setFrame(frame, display: false)
        } else {
            window.center()
        }

        if let sibling {
            let topLeft = NSPoint(x: sibling.frame.minX, y: sibling.frame.maxY)
            let next = window.cascadeTopLeft(from: topLeft)
            window.cascadeTopLeft(from: next)
        }

        registry.append(Tracker(window: window, key: key, defaults: defaults))
    }

    /// 解析 descriptor 的前四个数（x y w h），校验与可见屏幕有足够交集，并保证不小于 minSize。
    /// 无效（解析失败、尺寸非法、与所有屏幕交集太小）返回 nil。
    static func usableFrame(
        descriptor: String,
        minSize: NSSize,
        visibleFrames: [NSRect]
    ) -> NSRect? {
        let numbers = descriptor
            .split(whereSeparator: \.isWhitespace)
            .prefix(4)
            .compactMap { Double($0) }
        guard numbers.count == 4,
              numbers.allSatisfy(\.isFinite),
              numbers[2] > 0, numbers[3] > 0
        else { return nil }

        var frame = NSRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])

        let enoughOverlap = visibleFrames.contains { screen in
            let overlap = screen.intersection(frame)
            guard !overlap.isNull else { return false }
            return overlap.width >= min(120, frame.width)
                && overlap.height >= min(80, frame.height)
                && overlap.width * overlap.height >= 0.25 * frame.width * frame.height
        }
        guard enoughOverlap else { return nil }

        // 不小于 minSize：放大时保持左上角不动。
        let width = max(frame.width, minSize.width)
        let height = max(frame.height, minSize.height)
        frame.origin.y -= height - frame.height
        frame.size = NSSize(width: width, height: height)
        return frame
    }

    // MARK: - Save

    /// 全屏 / 最小化时不保存（此时 frame 不是用户摆放的位置）。
    static func isEligibleForSave(styleMask: NSWindow.StyleMask, isMiniaturized: Bool) -> Bool {
        !styleMask.contains(.fullScreen) && !isMiniaturized
    }

    /// 返回是否真正写入。
    @discardableResult
    static func save(_ window: NSWindow, key: String, defaults: UserDefaults) -> Bool {
        guard isEligibleForSave(styleMask: window.styleMask, isMiniaturized: window.isMiniaturized)
        else { return false }
        defaults.set(window.frameDescriptor, forKey: storageKey(key))
        return true
    }

    // MARK: - Tracking

    private static var registry: [Tracker] = []

    /// 当前仍被追踪的窗口数（测试用）。
    static func trackedWindowCount(key: String) -> Int {
        registry.filter { $0.key == key && $0.window != nil }.count
    }

    private final class Tracker {
        weak var window: NSWindow?
        let key: String
        let defaults: UserDefaults
        private var tokens: [NSObjectProtocol] = []
        private var pendingSave: Task<Void, Never>?

        init(window: NSWindow, key: String, defaults: UserDefaults) {
            self.window = window
            self.key = key
            self.defaults = defaults

            let center = NotificationCenter.default
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
                tokens.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.scheduleSave() }
                })
            }
            tokens.append(center.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.saveNow() }
            })
            tokens.append(center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.closing() }
            })
        }

        deinit {
            tokens.forEach(NotificationCenter.default.removeObserver)
            pendingSave?.cancel()
        }

        private func scheduleSave() {
            pendingSave?.cancel()
            pendingSave = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                self?.saveNow()
            }
        }

        private func saveNow() {
            pendingSave?.cancel()
            guard let window else { return }
            CosmosWindowFrameMemory.save(window, key: key, defaults: defaults)
        }

        private func closing() {
            saveNow()
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens.removeAll()
            let id = ObjectIdentifier(self)
            CosmosWindowFrameMemory.registry.removeAll { ObjectIdentifier($0) == id }
        }
    }
}
