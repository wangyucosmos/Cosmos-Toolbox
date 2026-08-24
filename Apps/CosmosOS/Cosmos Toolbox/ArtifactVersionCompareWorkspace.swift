import SwiftUI
import AppKit


// MARK: - Compare Selection

struct ArtifactVersionComparisonItem:
    Identifiable,
    Equatable {

    let artifactID: UUID
    let version: Int
    let isCurrent: Bool
    let document: ArtifactReviewDocument

    var id: UUID { artifactID }
}


struct ArtifactVersionCompareState: Equatable {

    var leftArtifactID: UUID
    var rightArtifactID: UUID
    var leftDisplayMode: ArtifactReviewDisplayMode = .preview
    var rightDisplayMode: ArtifactReviewDisplayMode = .preview
    var sharedMobileViewport: ArtifactReviewMobileViewport = .width390

    init?(
        items: [ArtifactVersionComparisonItem],
        selectedArtifactID: UUID
    ) {
        let orderedItems = items.sorted {
            $0.version > $1.version
        }

        guard orderedItems.count >= 2,
              let leftItem = orderedItems.first(where: \.isCurrent)
                ?? orderedItems.first,
              let rightItem = orderedItems.first(where: {
                  $0.artifactID == selectedArtifactID
                    && $0.artifactID != leftItem.artifactID
              })
                ?? orderedItems.first(where: {
                    $0.artifactID != leftItem.artifactID
                })
        else {
            return nil
        }

        leftArtifactID = leftItem.artifactID
        rightArtifactID = rightItem.artifactID
    }

    mutating func selectLeft(
        _ artifactID: UUID,
        availableArtifactIDs: Set<UUID>
    ) {
        guard availableArtifactIDs.contains(artifactID),
              artifactID != leftArtifactID
        else {
            return
        }

        if artifactID == rightArtifactID {
            rightArtifactID = leftArtifactID
        }

        leftArtifactID = artifactID
    }

    mutating func selectRight(
        _ artifactID: UUID,
        availableArtifactIDs: Set<UUID>
    ) {
        guard availableArtifactIDs.contains(artifactID),
              artifactID != rightArtifactID
        else {
            return
        }

        if artifactID == leftArtifactID {
            leftArtifactID = rightArtifactID
        }

        rightArtifactID = artifactID
    }
}


struct ArtifactVersionCompareWindowIdentity: Hashable {

    let campaignID: UUID
    let versionGroupKey: String

    var rawValue: String {
        "artifact-version-compare::\(campaignID.uuidString)::\(versionGroupKey)"
    }
}


// MARK: - Compare Workspace

struct ArtifactVersionCompareWorkspace: View {

    let artifactName: String
    let items: [ArtifactVersionComparisonItem]
    let rendererRegistry: ArtifactPreviewRendererRegistry
    let windowContext: ArtifactReviewWindowContext

    @State
    private var compareState: ArtifactVersionCompareState

    init(
        artifactName: String,
        items: [ArtifactVersionComparisonItem],
        rendererRegistry: ArtifactPreviewRendererRegistry = .init(),
        windowContext: ArtifactReviewWindowContext,
        initialState: ArtifactVersionCompareState
    ) {
        self.artifactName = artifactName
        self.items = items.sorted {
            $0.version > $1.version
        }
        self.rendererRegistry = rendererRegistry
        self.windowContext = windowContext
        _compareState = State(initialValue: initialState)
    }

    var body: some View {
        VStack(spacing: 0) {
            compareHeader
            Divider()
            compareToolbar
            Divider()

            HStack(spacing: 0) {
                comparePane(
                    sideTitle: "左侧版本",
                    item: leftItem,
                    artifactSelection: leftSelection,
                    displayMode: $compareState.leftDisplayMode
                )

                Divider()

                comparePane(
                    sideTitle: "右侧版本",
                    item: rightItem,
                    artifactSelection: rightSelection,
                    displayMode: $compareState.rightDisplayMode
                )
            }
        }
        .frame(minWidth: 1180, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var compareHeader: some View {
        HStack(spacing: CosmosDesign.spacingL) {
            VStack(alignment: .leading, spacing: 4) {
                Text(artifactName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Artifact Version Compare")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("基础并排比较 · 不包含 Diff")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, CosmosDesign.spacingL)
        .padding(.vertical, CosmosDesign.spacingM)
    }

    private var compareToolbar: some View {
        HStack(spacing: CosmosDesign.spacingM) {
            if showsSharedViewport {
                Picker(
                    "Mobile Viewport",
                    selection: $compareState.sharedMobileViewport
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
                windowContext.close()
            } label: {
                Label("关闭", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, CosmosDesign.spacingL)
        .padding(.vertical, CosmosDesign.spacingS)
    }

    private func comparePane(
        sideTitle: String,
        item: ArtifactVersionComparisonItem?,
        artifactSelection: Binding<UUID>,
        displayMode: Binding<ArtifactReviewDisplayMode>
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: CosmosDesign.spacingM) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(sideTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Picker(
                        sideTitle,
                        selection: artifactSelection
                    ) {
                        ForEach(items) { option in
                            Text(versionPickerTitle(for: option))
                                .tag(option.artifactID)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                if item?.isCurrent == true {
                    Label(
                        "当前采用",
                        systemImage: "checkmark.seal.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.green)
                }

                Spacer(minLength: CosmosDesign.spacingS)

                Picker(
                    "Artifact 查看方式",
                    selection: displayMode
                ) {
                    ForEach(ArtifactReviewDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal, CosmosDesign.spacingM)
            .padding(.vertical, CosmosDesign.spacingS)

            Divider()

            if let item {
                ArtifactReviewPane(
                    document: item.document,
                    rendererRegistry: rendererRegistry,
                    displayMode: displayMode.wrappedValue,
                    mobileViewport: compareState.sharedMobileViewport
                )
            } else {
                Text("所选版本不可用")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var leftSelection: Binding<UUID> {
        Binding(
            get: { compareState.leftArtifactID },
            set: { artifactID in
                compareState.selectLeft(
                    artifactID,
                    availableArtifactIDs: availableArtifactIDs
                )
            }
        )
    }

    private var rightSelection: Binding<UUID> {
        Binding(
            get: { compareState.rightArtifactID },
            set: { artifactID in
                compareState.selectRight(
                    artifactID,
                    availableArtifactIDs: availableArtifactIDs
                )
            }
        )
    }

    private var leftItem: ArtifactVersionComparisonItem? {
        item(for: compareState.leftArtifactID)
    }

    private var rightItem: ArtifactVersionComparisonItem? {
        item(for: compareState.rightArtifactID)
    }

    private var availableArtifactIDs: Set<UUID> {
        Set(items.map(\.artifactID))
    }

    private var showsSharedViewport: Bool {
        usesMobilePreview(
            item: leftItem,
            displayMode: compareState.leftDisplayMode
        )
        || usesMobilePreview(
            item: rightItem,
            displayMode: compareState.rightDisplayMode
        )
    }

    private func usesMobilePreview(
        item: ArtifactVersionComparisonItem?,
        displayMode: ArtifactReviewDisplayMode
    ) -> Bool {
        guard displayMode == .preview,
              let item
        else {
            return false
        }

        return rendererRegistry
            .renderer(for: item.document.type)
            .presentationStyle == .mobileDevice
    }

    private func item(
        for artifactID: UUID
    ) -> ArtifactVersionComparisonItem? {
        items.first {
            $0.artifactID == artifactID
        }
    }

    private func versionPickerTitle(
        for item: ArtifactVersionComparisonItem
    ) -> String {
        item.isCurrent
            ? "V\(item.version) · 当前采用"
            : "V\(item.version)"
    }
}


// MARK: - Compare Window

final class ArtifactVersionCompareWindowManager:
    NSObject,
    NSWindowDelegate {

    static let shared = ArtifactVersionCompareWindowManager()

    private var controllers:
        [ArtifactVersionCompareWindowIdentity: NSWindowController] = [:]

    private override init() {
        super.init()
    }

    func open(
        campaignID: UUID,
        versionGroupKey: String,
        artifactName: String,
        items: [ArtifactVersionComparisonItem],
        selectedArtifactID: UUID
    ) {
        let identity = ArtifactVersionCompareWindowIdentity(
            campaignID: campaignID,
            versionGroupKey: versionGroupKey
        )

        if let existing = controllers[identity],
           let window = existing.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let initialState = ArtifactVersionCompareState(
            items: items,
            selectedArtifactID: selectedArtifactID
        ) else {
            return
        }

        let windowContext = ArtifactReviewWindowContext()
        let rootView = ArtifactVersionCompareWorkspace(
            artifactName: artifactName,
            items: items,
            windowContext: windowContext,
            initialState: initialState
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 1480,
                height: 900
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

        window.title = "\(artifactName) · Version Compare"
        window.minSize = NSSize(width: 1180, height: 720)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.contentViewController = hostingController
        window.delegate = self
        window.identifier = NSUserInterfaceItemIdentifier(identity.rawValue)
        windowContext.window = window

        let controller = NSWindowController(window: window)
        controllers[identity] = controller

        window.center()
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(
        _ notification: Notification
    ) {
        guard let window = notification.object as? NSWindow,
              let identity = controllers.first(where: {
                  $0.value.window === window
              })?.key
        else {
            return
        }

        controllers.removeValue(forKey: identity)
    }
}
