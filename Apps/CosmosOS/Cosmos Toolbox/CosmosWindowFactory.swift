import AppKit
import SwiftUI

// 原生窗口工厂（第二批 2.1 前置）
//
// 职责边界：只负责“造窗口 + 统一外观 + SwiftUI toolbar/title 桥接”。
// 不负责：窗口身份/复用键、关闭保护、未保存提醒、终止协调 —— 这些仍由各
// WindowManager（及其 NSWindowDelegate / CosmosTerminationParticipant）自行处理，
// 工厂只把 delegate 透传给窗口。
//
// 被托管视图约定（第二批迁移时遵守）：
// - 窗口级操作一律用标准 `.toolbar { ToolbarItem … }` 声明，不再在内容区自绘工具条；
// - 窗口标题用 `.navigationTitle(_:)` / `.navigationSubtitle(_:)`（见 `cosmosWindowTitle`），
//   因为 sceneBridgingOptions 含 `.title`，SwiftUI 标题会驱动 NSWindow.title；
// - 主操作按钮用 `.cosmosWindowPrimaryAction()`（`.glassProminent`），其余保持系统默认玻璃样式；
// - 内容延伸到工具栏玻璃之下（`.fullSizeContentView`），顶部固定内容请依赖 SwiftUI 安全区，
//   不要手写顶部 padding 去避让标题栏。

// MARK: - Configuration

struct CosmosWindowConfiguration {

    /// 初始标题。被托管视图声明 `.navigationTitle` 后，由 SwiftUI 接管。
    var title: String

    /// 首次显示的内容区尺寸（对应现有代码里的 NSWindow(contentRect:)）。
    var contentSize: NSSize

    /// 窗口最小尺寸，语义同现有代码里的 `window.minSize`（按窗口 frame 计，含标题栏）。
    var minSize: NSSize

    /// 默认含 `.fullSizeContentView`，让内容延伸到工具栏玻璃下。
    var styleMask: NSWindow.StyleMask = [
        .titled,
        .closable,
        .miniaturizable,
        .resizable,
        .fullSizeContentView
    ]

    /// `.unified`（默认）或 `.unifiedCompact`。
    var toolbarStyle: NSWindow.ToolbarStyle = .unified

    var titleVisibility: NSWindow.TitleVisibility = .visible

    /// 业务窗口都用 `.disallowed`：每个对象一个独立窗口，不自动并成标签页。
    var tabbingMode: NSWindow.TabbingMode = .disallowed

    /// 对应现有 `window.collectionBehavior.insert(.fullScreenPrimary)`。
    var allowsFullScreen = false

    /// 原样写入 `window.identifier`（现有 WindowManager 用它做 windowWillClose 反查键）。
    var identifier: String?

    /// 调用方传入的 frame autosave 名，原样使用，不加前缀、不改写。
    /// 全新窗口才使用新名，且一律 `cosmos.ui.` 前缀（见 `CosmosWindowConfiguration.newAutosaveName`）。
    /// 注意：AppKit 不允许两个存活窗口共用同一个 autosave 名，
    /// 同类型可同时打开多个的窗口（每条笔记一个窗口等）不要传 autosave 名。
    var frameAutosaveName: String?

    /// 无已保存 frame 时是否居中（现有代码都是 `window.center()`）。
    var centersWhenNoSavedFrame = true

    /// 透传给 `window.delegate`（弱引用，持有者仍是 WindowManager）。
    weak var delegate: NSWindowDelegate?

    init(
        title: String,
        contentSize: NSSize,
        minSize: NSSize,
        identifier: String? = nil,
        frameAutosaveName: String? = nil,
        allowsFullScreen: Bool = false,
        delegate: NSWindowDelegate? = nil
    ) {
        self.title = title
        self.contentSize = contentSize
        self.minSize = minSize
        self.identifier = identifier
        self.frameAutosaveName = frameAutosaveName
        self.allowsFullScreen = allowsFullScreen
        self.delegate = delegate
    }

    /// 全新窗口的 autosave 名：统一 `cosmos.ui.window.` 前缀。
    static func newAutosaveName(_ suffix: String) -> String {
        "cosmos.ui.window." + suffix
    }
}

// MARK: - Factory

enum CosmosWindowFactory {

    /// 统一创建被托管视图的控制器，并打开 toolbar / title 桥接。
    /// 窗口复用路径里需要替换内容时（如 Artifact Review 重新载入文档），也应经此创建，
    /// 避免新内容丢失桥接。
    static func makeHostingController<Content: View>(
        rootView: Content
    ) -> NSHostingController<Content> {
        let controller = NSHostingController(rootView: rootView)
        controller.sceneBridgingOptions = [.toolbars, .title]
        return controller
    }

    /// 造窗口：不显示（不 orderFront、不 showWindow）；显示仍由调用方的
    /// `NSWindowController.showWindow` / `makeKeyAndOrderFront` 负责。
    static func makeWindow<Content: View>(
        _ configuration: CosmosWindowConfiguration,
        rootView: Content
    ) -> NSWindow {
        makeWindow(
            configuration,
            hostingController: makeHostingController(rootView: rootView)
        )
    }

    static func makeWindow<Content: View>(
        _ configuration: CosmosWindowConfiguration,
        hostingController: NSHostingController<Content>
    ) -> NSWindow {

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: configuration.contentSize),
            styleMask: configuration.styleMask,
            backing: .buffered,
            defer: false
        )

        // 与 contentViewController 的先后：先设内容再设 toolbarStyle，
        // 保证 SwiftUI 桥接来的 NSToolbar 以该样式呈现。
        window.contentViewController = hostingController

        window.title = configuration.title
        window.titleVisibility = configuration.titleVisibility
        window.toolbarStyle = configuration.toolbarStyle
        window.tabbingMode = configuration.tabbingMode
        window.minSize = configuration.minSize
        window.isReleasedWhenClosed = false

        if configuration.allowsFullScreen {
            window.collectionBehavior.insert(.fullScreenPrimary)
        }

        if let identifier = configuration.identifier {
            window.identifier = NSUserInterfaceItemIdentifier(identifier)
        }

        window.delegate = configuration.delegate

        applyFrame(configuration, to: window)

        return window
    }

    /// 内容尺寸由 contentViewController 的 fittingSize 可能改写，
    /// 所以在挂好内容之后统一重设内容尺寸，再处理 autosave / 居中。
    private static func applyFrame(
        _ configuration: CosmosWindowConfiguration,
        to window: NSWindow
    ) {
        window.setContentSize(configuration.contentSize)

        if let name = configuration.frameAutosaveName {
            // 已有保存的 frame 则沿用；没有才居中。autosave 名原样使用。
            let restored = window.setFrameUsingName(name)
            window.setFrameAutosaveName(name)
            if !restored, configuration.centersWhenNoSavedFrame {
                window.center()
            }
        } else if configuration.centersWhenNoSavedFrame {
            window.center()
        }
    }
}

// MARK: - Thin View helpers

extension View {

    /// 窗口标题与副标题；经 sceneBridgingOptions 的 `.title` 同步到 NSWindow。
    func cosmosWindowTitle(_ title: String, subtitle: String = "") -> some View {
        navigationTitle(title).navigationSubtitle(subtitle)
    }

    /// 窗口工具栏里的主操作（保存、设为当前版本等），其余按钮保持系统默认样式。
    func cosmosWindowPrimaryAction() -> some View {
        buttonStyle(.glassProminent)
    }
}
