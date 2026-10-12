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
        var normalizedState = initialState
        normalizedState.normalize(
            for: rendererRegistry
                .renderer(for: document.previewInput)
                .capabilities
        )
        _reviewState = State(initialValue: normalizedState)
    }

    var body: some View {
        VStack(spacing: 0) {
            if reviewState.presentationMode == .workspace {
                metadataHeader
                    .background(Color(nsColor: .windowBackgroundColor))
                Divider()
            }


            ArtifactReviewPane(
                document: document,
                rendererRegistry: rendererRegistry,
                displayMode: reviewState.displayMode,
                mobileViewport: reviewState.mobileViewport
            )
        }
        .frame(minWidth: 900, minHeight: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(document.name)
        .navigationSubtitle("Artifact Review")
        .toolbar { workspaceToolbar }
        .modifier(CosmosMotionPolicy())
        .campaignUIAnimation(value: reviewState.presentationMode)
    }


    // MARK: - Artifact Metadata

    private var metadataHeader: some View {
        VStack(alignment: .leading, spacing: CosmosDesign.spacingM) {
            CampaignUIStatusPill(text: document.versionLabel,
                tone: document.versionLabel == "Draft" ? .neutral : .accent)

            HStack(alignment: .top, spacing: CosmosDesign.spacingXL) {
                metadataItem(
                    title: "类型",
                    value: document.typeDisplayName
                )
                metadataItem(
                    title: "来源",
                    value: document.sourceName
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
                    title: "执行时间",
                    value: CosmosDate.timestamp(document.executedAt)
                )
                Spacer(minLength: 0)
            }
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

    @ToolbarContentBuilder
    private var workspaceToolbar: some ToolbarContent {
        if selectedRenderer.capabilities.supportsSource {
            ToolbarItem(placement: .principal) {
                Picker("Artifact 查看方式", selection: $reviewState.displayMode) {
                    ForEach(ArtifactReviewDisplayMode.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).frame(width: 200)
            }
        }
        if reviewState.displayMode == .preview, selectedRenderer.capabilities.supportsMobileViewport {
            ToolbarItem {
                Picker("Mobile Viewport", selection: $reviewState.mobileViewport) {
                    ForEach(ArtifactReviewMobileViewport.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).frame(width: 170)
            }
        }
        if selectedRenderer.capabilities.supportsFullPreview {
            ToolbarItem(placement: .primaryAction) {
                Button { reviewState.toggleFullPreview() } label: {
                    Label(reviewState.presentationMode == .fullPreview ? "退出完整预览" : "完整预览",
                        systemImage: reviewState.presentationMode == .fullPreview
                            ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .cosmosSymbolReplacement()
                }
            }
        }
    }

    private var selectedRenderer: any ArtifactPreviewRenderer {
        rendererRegistry.renderer(for: document.previewInput)
    }
}


// MARK: - Shared Review Pane

struct ArtifactReviewPane: View {

    let document: ArtifactReviewDocument
    let rendererRegistry: ArtifactPreviewRendererRegistry
    let displayMode: ArtifactReviewDisplayMode
    let mobileViewport: ArtifactReviewMobileViewport

    var body: some View {
        Group {
            switch effectiveDisplayMode {
            case .preview:
                previewContent
            case .source:
                sourceContent
            }
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
                input: document.previewInput,
                context: previewContext
            )
            .id(document.id)
        }
    }

    private var mobilePreviewContent: some View {
        GeometryReader { proxy in
            let screenHeight = max(520, proxy.size.height - 64)

            ScrollView([.horizontal, .vertical]) {
                ArtifactMobileDeviceFrame(
                    screenWidth: mobileViewport.width,
                    screenHeight: screenHeight
                ) {
                    selectedRenderer.makePreview(
                        document: document,
                        input: document.previewInput,
                        context: previewContext
                    )
                    .id(document.id)
                }
                .padding(CosmosDesign.spacingXL)
                .frame(
                    minWidth: proxy.size.width,
                    minHeight: proxy.size.height
                )
            }.scrollEdgeEffectStyle(.soft, for: .top)
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
        }.scrollEdgeEffectStyle(.soft, for: .top)
        .background(Color.primary.opacity(0.018))
    }

    private var selectedRenderer: any ArtifactPreviewRenderer {
        rendererRegistry.renderer(for: document.previewInput)
    }

    private var effectiveDisplayMode: ArtifactReviewDisplayMode {
        displayMode == .source
            && !selectedRenderer.capabilities.supportsSource
            ? .preview
            : displayMode
    }

    private var previewContext: ArtifactPreviewContext {
        ArtifactPreviewContext(
            mobileViewport:
                selectedRenderer.capabilities.supportsMobileViewport
                ? mobileViewport
                : nil
        )
    }
}


// MARK: - Mobile Device Frame

struct ArtifactMobileDeviceFrame<Content: View>: View {

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
            window.contentViewController = CosmosWindowFactory.makeHostingController(
                rootView: ArtifactReviewWorkspace(
                    document: document,
                    windowContext: windowContext
                )
            )
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let windowContext = ArtifactReviewWindowContext()
        let rootView = ArtifactReviewWorkspace(
            document: document,
            windowContext: windowContext
        )
        let window = CosmosWindowFactory.makeWindow(
            CosmosWindowConfiguration(title: document.name,
                contentSize: NSSize(width: 1240, height: 880), minSize: NSSize(width: 900, height: 680),
                identifier: windowKey, frameMemoryKey: "artifactReview", allowsFullScreen: true, delegate: self),
            rootView: rootView)
        windowContext.window = window

        let controller = NSWindowController(window: window)
        controllers[windowKey] = controller

        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Asset-center refresh invalidates only previews explicitly opened by it.
    func close(documentID: UUID) {
        controllers["artifact-review::\(documentID.uuidString)"]?.window?.performClose(nil)
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
