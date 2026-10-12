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
        CampaignUICard(
            title: "资料与外部成果",
            icon: "paperclip",
            info: "登记活动资料和外部成果的位置，只追加历史。登记不代表 Artifact、采用、已落盘或可交付，也不影响 ZIP 资格。月度清单的七项成品仍在「月度清单」中登记与确认。\n\n备份仅包含引用记录，不包含原文件或网页。文件移动后记录仍保留，不自动修复。",
            trailing: {
                Button { begin() } label: { Label("追加引用", systemImage: "plus") }
                    .buttonStyle(.bordered)
                    .help("追加文件或链接引用")
                    .disabled(!store.persistenceState.allowsMutations)
            }
        ) {
            Text("登记位置，只追加历史；登记不是采用，也不影响交付资格。")
                .font(CosmosDesign.font(.body)).foregroundStyle(.secondary)
            if records.isEmpty {
                Text("尚未登记资料或外部成果").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            VStack(spacing: 8) {
                ForEach(records) { record in recordRow(record) }
            }
        }
        .sheet(isPresented: $registering) { registration }
        .alert("未打开引用", isPresented: Binding(get: { openMessage != nil }, set: { if !$0 { openMessage = nil } })) {
            Button("好") { openMessage = nil }
        } message: { Text(openMessage ?? "") }
    }

    private func recordRow(_ record: CampaignExternalReference) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon(for: record.kind)).foregroundStyle(.secondary).frame(width: 20)
                Text(record.name).font(.headline).lineLimit(1)
                if !record.versionLabel.isEmpty {
                    Text(record.versionLabel).font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                Spacer()
                if record.kind != .correction {
                    Button(record.kind == .file ? "打开原文件" : "打开链接") { open(record) }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                Button("追加更正说明") { begin(correcting: record.id) }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(!store.persistenceState.allowsMutations)
            }
            Text(CosmosDate.timestamp(record.recordedAt))
                .font(.caption).foregroundStyle(.secondary)
            if let id = record.correctsReferenceID {
                Text("更正对象：\(records.first(where: { $0.id == id })?.name ?? id.uuidString) · \(id.uuidString)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !record.location.isEmpty { Text(record.location).font(.callout).textSelection(.enabled) }
            if !record.notes.isEmpty { Text(record.notes).font(.callout).textSelection(.enabled) }
            if record.kind == .file, let reason = unavailableReason(record) {
                Label(reason, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusMedium, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusMedium, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1) }
    }

    private func icon(for kind: CampaignExternalReference.Kind) -> String {
        switch kind {
        case .file: return "doc"
        case .link: return "link"
        case .correction: return "pencil.line"
        }
    }

    private var registration: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.kind == .correction ? "追加更正说明" : "登记资料与外部成果").font(.title2)
            if draft.kind != .correction {
                Picker("引用类型", selection: $draft.kind) {
                    Text("本地文件").tag(CampaignExternalReference.Kind.file)
                    Text("http/https 链接").tag(CampaignExternalReference.Kind.link)
                }.pickerStyle(.segmented).onChange(of: draft.kind) { draft.location = "" }
            }
            TextField("名称", text: $draft.name)
            TextField("版本标签（可选）", text: $draft.versionLabel)
            if draft.kind == .file {
                Button("选择原文件…") { chooseFile() }.buttonStyle(.bordered)
                Text(draft.location.isEmpty ? "尚未选择文件" : draft.location).textSelection(.enabled)
                    .font(.callout).foregroundStyle(.secondary)
            } else if draft.kind == .link {
                TextField("http:// 或 https:// 链接", text: $draft.location)
            }
            Text("原文备注\(draft.kind == .correction ? "（更正内容必填）" : "（可选）")")
            TextEditor(text: $draft.notes).frame(height: 130)
                .padding(6)
                .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusSmall, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusSmall, style: .continuous).stroke(Color.primary.opacity(0.07), lineWidth: 1) }
            if let message = draft.message { Text(message).foregroundStyle(.orange) }
            HStack {
                Button("取消") { registering = false }.buttonStyle(.bordered)
                Spacer()
                Button("保存登记") {
                    if draft.save(store: store, campaignID: campaignID) { registering = false }
                }.buttonStyle(.borderedProminent).disabled(!store.persistenceState.allowsMutations)
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
