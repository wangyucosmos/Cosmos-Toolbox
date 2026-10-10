import SwiftUI
import AppKit

struct CampaignReferencesView: View {
    @ObservedObject var store: ZhuowangCampaignStore
    let campaignID: UUID
    @StateObject private var draft = CampaignReferenceDraft()
    @State private var registering = false
    @State private var openMessage: String?

    private var records: [CampaignExternalReference] {
        store.campaign(id: campaignID)?.referenceRecords ?? []
    }

    var body: some View {
        GroupBox("资料与外部成果") {
            VStack(alignment: .leading, spacing: 12) {
                Text("登记活动资料和外部成果的位置，只追加历史。登记不代表 Artifact、采用、已落盘或可交付，也不影响 ZIP 资格。月度清单的七项成品仍在「月度清单」中登记与确认。")
                    .font(.callout).foregroundStyle(.secondary)
                Text("备份仅包含引用记录，不包含原文件或网页。文件移动后记录仍保留，不自动修复。")
                    .font(.caption).foregroundStyle(.secondary)
                if records.isEmpty { Text("尚未登记资料或外部成果").foregroundStyle(.secondary) }
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(record.name).font(.headline)
                            if !record.versionLabel.isEmpty { Text(record.versionLabel).foregroundStyle(.secondary) }
                            Spacer()
                            if record.kind != .correction {
                                Button(record.kind == .file ? "打开原文件" : "打开链接") { open(record) }
                            }
                            Button("追加更正说明") { begin(correcting: record.id) }
                                .disabled(!store.persistenceState.allowsMutations)
                        }
                        Text(record.recordedAt, format: .dateTime.year().month().day().hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                        if let id = record.correctsReferenceID {
                            Text("更正对象：\(records.first(where: { $0.id == id })?.name ?? id.uuidString) · \(id.uuidString)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if !record.location.isEmpty { Text(record.location).textSelection(.enabled) }
                        if !record.notes.isEmpty { Text(record.notes).textSelection(.enabled) }
                        if record.kind == .file, let reason = unavailableReason(record) {
                            Text(reason).font(.caption).foregroundStyle(.orange)
                        }
                    }
                    Divider()
                }
                Button("追加文件或链接引用") { begin() }
                    .disabled(!store.persistenceState.allowsMutations)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }
        .sheet(isPresented: $registering) { registration }
        .alert("未打开引用", isPresented: Binding(get: { openMessage != nil }, set: { if !$0 { openMessage = nil } })) {
            Button("好") { openMessage = nil }
        } message: { Text(openMessage ?? "") }
    }

    private var registration: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.kind == .correction ? "追加更正说明" : "登记资料与外部成果").font(.title2)
            if draft.kind != .correction {
                Picker("引用类型", selection: $draft.kind) {
                    Text("本地文件").tag(CampaignExternalReference.Kind.file)
                    Text("http/https 链接").tag(CampaignExternalReference.Kind.link)
                }.onChange(of: draft.kind) { draft.location = "" }
            }
            TextField("名称", text: $draft.name)
            TextField("版本标签（可选）", text: $draft.versionLabel)
            if draft.kind == .file {
                Button("选择原文件…") { chooseFile() }
                Text(draft.location.isEmpty ? "尚未选择文件" : draft.location).textSelection(.enabled)
            } else if draft.kind == .link {
                TextField("http:// 或 https:// 链接", text: $draft.location)
            }
            Text("原文备注\(draft.kind == .correction ? "（更正内容必填）" : "（可选）")")
            TextEditor(text: $draft.notes).frame(height: 130).border(Color.secondary.opacity(0.3))
            if let message = draft.message { Text(message).foregroundStyle(.orange) }
            HStack {
                Button("取消") { registering = false }
                Spacer()
                Button("保存登记") {
                    if draft.save(store: store, campaignID: campaignID) { registering = false }
                }.disabled(!store.persistenceState.allowsMutations)
            }
        }.padding(24).frame(width: 530)
    }

    private func begin(correcting: UUID? = nil) {
        draft.begin(records: records, correcting: correcting)
        registering = true
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false; panel.resolvesAliases = false
        if panel.runModal() == .OK, let url = panel.url {
            draft.location = url.path
            if draft.name.isEmpty { draft.name = url.lastPathComponent }
        }
    }

    private func unavailableReason(_ record: CampaignExternalReference) -> String? {
        do { _ = try record.openURL(); return nil } catch { return error.localizedDescription }
    }

    private func open(_ record: CampaignExternalReference) {
        do {
            let url = try record.openURL()
            if !NSWorkspace.shared.open(url) { openMessage = "系统未能打开此引用；记录仍保留。" }
        } catch { openMessage = error.localizedDescription }
    }
}
