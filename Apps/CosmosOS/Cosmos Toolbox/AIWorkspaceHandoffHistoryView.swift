import AppKit
import SwiftUI

struct AIWorkspaceHandoffRecordingView: View {
    @ObservedObject var preparation: AIWorkspaceTaskPreparation
    @ObservedObject var history: AIWorkspaceHandoffStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preparation.recordingNotice).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(history.saving ? "正在记录…" : "记录本次交接", systemImage: "tray.and.arrow.down") {
                    Task { await history.recordCurrent(preparation) }
                }
                .disabled(preparation.preview == nil || history.saving || history.loading || !history.loaded
                    || history.alreadyRecorded(preparation.preview))
                .accessibilityIdentifier("ai-handoff-record")
                if history.alreadyRecorded(preparation.preview) {
                    Button("准备再次交接相同任务") { history.prepareAnotherHandoff() }
                        .disabled(history.saving).accessibilityIdentifier("ai-handoff-rearm")
                }
                if !history.loaded && !history.loading {
                    Button("重新加载记录") { Task { await history.reload() } }
                }
            }
            if let error = history.loadError { Text(error).font(.callout).foregroundStyle(.orange) }
            if let message = history.saveFeedback {
                Text(message).font(.callout).accessibilityIdentifier("ai-handoff-save-feedback")
            }
        }
    }
}

struct AIWorkspaceHandoffHistoryView: View {
    @ObservedObject var history: AIWorkspaceHandoffStore
    let preparation: AIWorkspaceTaskPreparation
    @State private var campaignID: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("交接记录").font(CosmosDesign.font(.section))
                Spacer()
                Button("刷新记录", systemImage: "arrow.clockwise") { Task { await history.reload() } }
                    .disabled(history.loading || history.saving)
            }
            Text("保存交接时的提示词快照，继续追踪每次任务。").font(CosmosDesign.font(.body)).foregroundStyle(.secondary)
            CosmosInfoButton(text: "手动保存不代表 AI 已执行或完成；名称与文本保持保存时的内容，不使用当前资料替换历史。")
            Picker("活动", selection: $campaignID) {
                Text("全部活动").tag(Optional<UUID>.none)
                ForEach(history.campaignFilters, id: \.id) { filter in
                    Text(filter.name).tag(Optional(filter.id))
                }
            }.accessibilityIdentifier("ai-handoff-filter")
            if history.loading {
                ProgressView("正在读取交接记录…")
            } else if let error = history.loadError {
                ContentUnavailableView("交接记录读取失败", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if history.loaded && filtered.isEmpty {
                CosmosEmptyState(icon: "tray", title: "暂无交接记录", detail: "复制提示词并记录交接后会出现在这里；复制不会自动保存。")
            } else {
                ForEach(filtered) { record in
                    Button {
                        AIWorkspaceHandoffDetailWindowManager.shared.open(record: record,
                            association: { preparation.associationStatus(for: record) })
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(record.campaignName).font(.headline)
                                Text(record.stepName).foregroundStyle(.secondary)
                                Spacer()
                                Text(record.toolName)
                                Text(record.recordedAt, format: .dateTime.year().month().day().hour().minute().second())
                                    .foregroundStyle(.secondary)
                            }
                            Text(record.goal).lineLimit(2).foregroundStyle(.primary)
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }.buttonStyle(CosmosInteractiveCardStyle())
                }
            }
            if let root = history.location.root {
                Text("本机存储：\(root.appendingPathComponent("handoffs.json").path)")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }.accessibilityIdentifier("ai-handoff-history")
    }
    private var filtered: [AIWorkspaceHandoffRecord] {
        history.records.filter { campaignID == nil || $0.campaignID == campaignID }
    }
}

struct AIWorkspaceHandoffDetailView: View {
    let record: AIWorkspaceHandoffRecord
    let association: () -> String
    @State private var associationMessage = "正在核对当前关联…"
    @StateObject private var copyModel = AIWorkspaceHandoffCopyModel()
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("交接快照").font(.title)
            Text("\(record.campaignName) / \(record.workflowName) / \(record.stepName)").font(.headline)
            HStack {
                Text(record.toolName)
                Text(record.recordedAt, format: .dateTime.year().month().day().hour().minute().second())
                Spacer()
                Button("复制历史快照", systemImage: "doc.on.doc") { copyModel.copySnapshot(record) }
                    .accessibilityIdentifier("ai-handoff-copy-history")
            }
            Text("记录 ID：\(record.id)\n活动 ID：\(record.campaignID) · 流程 ID：\(record.workflowID) · 步骤 ID：\(record.stepID)")
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            Text(associationMessage).font(.callout).foregroundStyle(.secondary)
            Text("本次目标：\(record.goal)\n补充要求：\(record.requirements.isEmpty ? "未填写" : record.requirements)")
                .textSelection(.enabled)
            if let feedback = copyModel.feedback { Text(feedback).font(.callout) }
            ScrollView {
                Text(record.prompt).font(.body.monospaced()).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }.background(Color(nsColor: .controlBackgroundColor))
                .accessibilityIdentifier("ai-handoff-snapshot")
            HStack {
                Text("手动记录不证明已发送、执行或完成；历史快照不会重新生成。").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("核对当前关联") { associationMessage = association() }
            }
        }.padding(24).frame(minWidth: 760, minHeight: 560)
            .task { associationMessage = association() }
    }
}

final class AIWorkspaceHandoffDetailWindowManager: NSObject, NSWindowDelegate {
    static let shared = AIWorkspaceHandoffDetailWindowManager()
    private var controllers: [UUID: NSWindowController] = [:]
    func open(record: AIWorkspaceHandoffRecord, association: @escaping () -> String) {
        if let window = controllers[record.id]?.window { window.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "交接快照 · " + record.campaignName + " · " + record.stepName
        window.minSize = NSSize(width: 800, height: 600)
        window.identifier = NSUserInterfaceItemIdentifier(record.id.uuidString)
        window.contentViewController = NSHostingController(rootView: AIWorkspaceHandoffDetailView(record: record, association: association))
        window.delegate = self
        let controller = NSWindowController(window: window)
        controllers[record.id] = controller
        window.center(); controller.showWindow(nil)
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let raw = window.identifier?.rawValue,
              let id = UUID(uuidString: raw) else { return }
        controllers.removeValue(forKey: id)
    }
}
