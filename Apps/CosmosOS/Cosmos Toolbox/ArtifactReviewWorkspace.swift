import SwiftUI
import AppKit


// MARK: - Artifact Review Workspace

struct ArtifactReviewWorkspace: View {

    let document: ArtifactReviewDocument
    let rendererRegistry: ArtifactPreviewRendererRegistry

    let windowContext: ArtifactReviewWindowContext

    @State
    private var reviewState: ArtifactReviewWorkspaceState

    init(
        document: ArtifactReviewDocument,
        rendererRegistry: ArtifactPreviewRendererRegistry = .init(),
        windowContext: ArtifactReviewWindowContext,
        initialState: ArtifactReviewWorkspaceState = .init()
    ) {
        self.document = document
        self.rendererRegistry = rendererRegistry
        self.windowContext = windowContext
        _reviewState = State(initialValue: initialState)
    }

    var body: some View {
        VStack(spacing: 0) {
            if reviewState.presentationMode == .workspace {
                metadataHeader
                Divider()
            }

            workspaceToolbar
            Divider()

            reviewContent
        }
        .frame(minWidth: 900, minHeight: 680)
        .background(Color(nsColor: .windowBackgroundColor))
    }


    // MARK: - Artifact Metadata

    private var metadataHeader: some View {
        HStack(alignment: .center, spacing: CosmosDesign.spacingL) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Artifact Review Workspace")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: CosmosDesign.spacingL)

            metadataItem(
                title: "版本",
                value: document.versionLabel
            )
            metadataItem(
                title: "类型",
                value: document.typeDisplayName
            )
            metadataItem(
                title: "Prototype Fidelity",
                value: document.fidelityDisplayName
            )
            metadataItem(
                title: "Prototype Style",
                value: document.styleDisplayName
            )
            metadataItem(
                title: "来源",
                value: document.sourceName
            )
            metadataItem(
                title: "执行时间",
                value: document.executedAt.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
            )
        }
        .padding(.horizontal, CosmosDesign.spacingL)
        .padding(.vertical, CosmosDesign.spacingM)
    }

    private func metadataItem(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }


    // MARK: - Toolbar

    private var workspaceToolbar: some View {
        HStack(spacing: CosmosDesign.spacingM) {
            Picker(
                "Artifact 查看方式",
                selection: $reviewState.displayMode
            ) {
                ForEach(ArtifactReviewDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            if reviewState.displayMode == .preview,
               selectedRenderer.presentationStyle == .mobileDevice {
                Picker(
                    "Mobile Viewport",
                    selection: $reviewState.mobileViewport
                ) {
                    ForEach(ArtifactReviewMobileViewport.allCases) { viewport in
                        Text(viewport.title).tag(viewport)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            Spacer()

            Button {
                reviewState.toggleFullPreview()
            } label: {
                Label(
                    reviewState.presentationMode == .fullPreview
                        ? "退出完整预览"
                        : "完整预览",
                    systemImage:
                        reviewState.presentationMode == .fullPreview
                        ? "arrow.down.right.and.arrow.up.left"
                        : "arrow.up.left.and.arrow.down.right"
                )
            }
            .buttonStyle(.bordered)

            Button {
                windowContext.close()
            } label: {
                Label("关闭", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, CosmosDesign.spacingL)
        .padding(.vertical, CosmosDesign.spacingS)
    }


    // MARK: - Review Content

    @ViewBuilder
    private var reviewContent: some View {
        switch reviewState.displayMode {
        case .preview:
            previewContent
        case .source:
            sourceContent
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch selectedRenderer.presentationStyle {
        case .mobileDevice:
            mobilePreviewContent
        case .adaptiveCanvas:
            selectedRenderer.makePreview(
                document: document,
                viewport: reviewState.mobileViewport
            )
        }
    }

    private var mobilePreviewContent: some View {
        GeometryReader { proxy in
            let screenHeight = max(520, proxy.size.height - 64)

            ScrollView([.horizontal, .vertical]) {
                ArtifactMobileDeviceFrame(
                    screenWidth: reviewState.mobileViewport.width,
                    screenHeight: screenHeight
                ) {
                    selectedRenderer.makePreview(
                        document: document,
                        viewport: reviewState.mobileViewport
                    )
                }
                .padding(CosmosDesign.spacingXL)
                .frame(
                    minWidth: proxy.size.width,
                    minHeight: proxy.size.height
                )
            }
            .background(Color.primary.opacity(0.035))
        }
    }

    private var sourceContent: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(
                document.content.isEmpty
                    ? "此 Artifact 没有可显示的源码内容。"
                    : document.content
            )
            .font(.system(size: 13, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CosmosDesign.spacingL)
        }
        .background(Color.primary.opacity(0.018))
    }

    private var selectedRenderer: any ArtifactPreviewRenderer {
        rendererRegistry.renderer(for: document.type)
    }
}


// MARK: - Mobile Device Frame

private struct ArtifactMobileDeviceFrame<Content: View>: View {

    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let content: Content

    init(
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Color.white.opacity(0.24))
                .frame(width: 72, height: 5)

            content
                .frame(width: screenWidth, height: screenHeight)
                .background(Color.white)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 28,
                        style: .continuous
                    )
                )
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.black.opacity(0.92))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 42,
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.20), radius: 24, y: 12)
    }
}


// MARK: - Native Window

final class ArtifactReviewWindowContext {

    weak var window: NSWindow?

    func close() {
        window?.performClose(nil)
    }
}


final class ArtifactReviewWindowManager:
    NSObject,
    NSWindowDelegate {

    static let shared = ArtifactReviewWindowManager()

    private var controllers: [String: NSWindowController] = [:]

    private override init() {
        super.init()
    }

    func open(
        document: ArtifactReviewDocument
    ) {
        let windowKey = "artifact-review::\(document.id.uuidString)"

        if let existing = controllers[windowKey],
           let window = existing.window {
            let windowContext = ArtifactReviewWindowContext()
            windowContext.window = window
            window.contentViewController = NSHostingController(
                rootView: ArtifactReviewWorkspace(
                    document: document,
                    windowContext: windowContext
                )
            )
            window.title = "\(document.name) · Artifact Review"
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let windowContext = ArtifactReviewWindowContext()
        let rootView = ArtifactReviewWorkspace(
            document: document,
            windowContext: windowContext
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 1240,
                height: 880
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "\(document.name) · Artifact Review"
        window.minSize = NSSize(width: 900, height: 680)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.contentViewController = hostingController
        window.delegate = self
        window.identifier = NSUserInterfaceItemIdentifier(windowKey)
        windowContext.window = window

        let controller = NSWindowController(window: window)
        controllers[windowKey] = controller

        window.center()
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(
        _ notification: Notification
    ) {
        guard
            let window = notification.object as? NSWindow,
            let windowKey = window.identifier?.rawValue
        else {
            return
        }

        controllers.removeValue(forKey: windowKey)
    }
}
