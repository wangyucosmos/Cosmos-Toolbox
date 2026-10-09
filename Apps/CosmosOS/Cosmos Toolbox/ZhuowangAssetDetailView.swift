import SwiftUI
import AppKit

struct ZhuowangAssetDetailView: View {
    @ObservedObject var model: ZhuowangAssetCatalogViewModel
    let groupID: String
    @State var selectedID: UUID
    @State private var bodyResult: ZhuowangAssetBody?
    @State private var message = ""
    let actions: ZhuowangAssetActions

    init(model: ZhuowangAssetCatalogViewModel, groupID: String, selectedID: UUID,
         actions: ZhuowangAssetActions = .init()) {
        self.model = model; self.groupID = groupID; _selectedID = State(initialValue: selectedID); self.actions = actions
    }

    private var versions: [ZhuowangAssetEntry] {
        model.entries.filter { $0.groupID == groupID }.sorted {
            if $0.artifact.version != $1.artifact.version { return $0.artifact.version > $1.artifact.version }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
    private var entry: ZhuowangAssetEntry? { versions.first { $0.id == selectedID } }
    private var requestIdentity: String { selectedID.uuidString + "::" + String(model.revision) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry?.artifact.name ?? "选中版本已不可用").font(.title)
            Picker("具体版本", selection: $selectedID) {
                if entry == nil { Text("原版本已消失，请显式选择").tag(selectedID) }
                ForEach(versions) { version in
                    Text("V\(version.artifact.version) · \(version.adoptionLabel)").tag(version.id)
                }
            }
            if let entry {
                Text("来源活动：\(entry.campaignName) · \(entry.scopeName)")
                Text("Workflow Step：\(entry.stepName)")
                Text("版本：V\(entry.artifact.version) · \(entry.adoptionLabel) · \(entry.artifact.type.title)")
                if let bodyResult {
                    Text("正文来源：\(bodyResult.source)")
                    Text("文件状态：\(bodyResult.fileStatus)")
                    Text(bodyResult.comparison).foregroundStyle(.secondary)
                    if let limitation = bodyResult.limitation { Text(limitation).foregroundStyle(.orange) }
                    if let text = bodyResult.text {
                        ScrollView([.horizontal, .vertical]) {
                            Text(text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        }.background(.background).accessibilityIdentifier("asset-body")
                    } else {
                        ContentUnavailableView("此版本没有可展示的文本正文", systemImage: "doc",
                            description: Text("可使用受支持的文件预览；不提取 Word / PDF 正文。"))
                    }
                    HStack {
                        Button("安全预览", systemImage: "macwindow") { perform(.preview) }
                            .disabled(bodyResult.text == nil && bodyResult.admittedPath == nil)
                        Button("Finder 定位", systemImage: "folder") { perform(.reveal) }
                            .disabled(bodyResult.admittedPath == nil)
                        Button("复制完整正文", systemImage: "doc.on.doc") { perform(.copy) }
                            .disabled(!bodyResult.canCopy)
                    }
                } else { ProgressView("正在重新核对版本和正文…") }
            } else {
                Text(model.error ?? "刷新后原版本已消失；不会自动切换到其他版本或沿用旧正文。")
                Spacer()
            }
            Text(message).font(.caption).foregroundStyle(.secondary)
            Text("刷新会重新核对数据并关闭本中心打开的旧预览。未核对不会标记为一致；不改变采用版本。")
                .font(.caption).foregroundStyle(.secondary)
            Button("刷新并重新核对") { bodyResult = nil; message = "数据已刷新，请核对当前版本。"; model.refresh() }
        }
        .padding(24).frame(minWidth: 780, minHeight: 580)
        .task(id: requestIdentity) {
            bodyResult = nil; message = ""
            bodyResult = await model.resolveDetail(id: selectedID)
        }
    }

    private enum Action { case copy, reveal, preview }
    private func perform(_ action: Action) {
        let id = selectedID
        Task {
            guard let refreshed = await model.resolveDetail(id: id), id == selectedID,
                  let current = model.entries.first(where: { $0.id == id }) else {
                bodyResult = nil; message = "版本或数据已变化，请刷新后重试。"; return
            }
            bodyResult = refreshed
            switch action {
            case .copy:
                if let text = refreshed.text { actions.copy(text); message = "已复制完整原始正文；来源信息未混入正文。" }
            case .reveal:
                if let path = refreshed.admittedPath { actions.reveal(URL(fileURLWithPath: path)) }
            case .preview:
                model.registerPreview(id: id)
                actions.preview(ZhuowangAssetCatalogViewModel.document(entry: current, body: refreshed))
            }
        }
    }
}

final class ZhuowangAssetDetailWindowManager: NSObject, NSWindowDelegate {
    static let shared = ZhuowangAssetDetailWindowManager()
    private var controllers: [String: NSWindowController] = [:]

    func open(model: ZhuowangAssetCatalogViewModel, entry: ZhuowangAssetEntry) {
        let key = "asset-detail::" + entry.groupID
        let view = ZhuowangAssetDetailView(model: model, groupID: entry.groupID, selectedID: entry.id)
        if let window = controllers[key]?.window {
            window.contentViewController = NSHostingController(rootView: view)
            window.makeKeyAndOrderFront(nil); return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = entry.campaignName + " · " + entry.artifact.name
        window.minSize = NSSize(width: 800, height: 620)
        window.identifier = NSUserInterfaceItemIdentifier(key)
        window.contentViewController = NSHostingController(rootView: view)
        window.delegate = self; window.collectionBehavior.insert(.fullScreenPrimary)
        let controller = NSWindowController(window: window); controllers[key] = controller
        window.center(); controller.showWindow(nil)
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let key = window.identifier?.rawValue else { return }
        controllers.removeValue(forKey: key)
    }
}
