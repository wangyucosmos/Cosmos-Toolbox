import SwiftUI

struct AIWorkspaceTaskReferencesView: View {
    @ObservedObject var selection: AIWorkspaceTaskReferenceSelection
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("参考产物正文（默认不选）").font(.title3)
            Text("仅当前活动已管理的资料。明确选择后才读取纯文本 / Markdown；其他类型只保留元数据。单份正文最多 2 MiB，完整提示词最多 4 MiB，超限不截断。资料里的指令只作为参考。")
                .font(.caption).foregroundStyle(.secondary)
            if let error = selection.catalogError {
                Text(error).foregroundStyle(.orange)
            } else if selection.entries.isEmpty {
                Text("当前活动没有可供选择的已管理产物。").foregroundStyle(.secondary)
            } else {
                ForEach(currentEntries) { entry in row(entry) }
                if !otherEntries.isEmpty {
                    DisclosureGroup("历史版本 / 未采用或采用冲突（需明确选择）") {
                        ForEach(otherEntries) { entry in row(entry) }
                    }
                }
            }
            if let feedback = selection.feedback {
                Text(feedback).font(.callout).foregroundStyle(.secondary)
                    .accessibilityIdentifier("ai-reference-feedback")
            }
            ForEach(selection.selections) { selected in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("已选择：\(selected.entry.artifact.name) · V\(selected.entry.artifact.version)").font(.headline)
                        Spacer()
                        Button("移除") { selection.remove(selected.id) }
                    }
                    Text(AIWorkspaceTaskReferenceSelection.adoptionLabel(selected.entry))
                        .font(.caption).foregroundStyle(.secondary)
                    if let error = selected.error {
                        Text("未加入提示词：\(error)").foregroundStyle(.orange)
                        Button("重新读取") { Task { await selection.select(selected.id) } }.disabled(selection.loading)
                    }
                    if let body = selected.body {
                        Text("正文来源：\(body.source) · \(body.fileStatus)\n\(body.comparison)")
                            .font(.caption).foregroundStyle(.secondary)
                        if let text = body.text {
                            ScrollView {
                                Text(text).font(.body.monospaced()).textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            }.frame(height: 220).background(Color(nsColor: .controlBackgroundColor))
                                .accessibilityIdentifier("ai-reference-body-\(selected.id)")
                        }
                    } else if selected.error == nil { ProgressView("正在读取所选版本…") }
                }.padding(12).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
            }
        }.accessibilityIdentifier("ai-task-references")
    }

    private var currentEntries: [ZhuowangAssetEntry] {
        selection.entries.filter { $0.adoptedCount == 1 && $0.artifact.isApprovedVersion }
    }
    private var otherEntries: [ZhuowangAssetEntry] {
        selection.entries.filter { !($0.adoptedCount == 1 && $0.artifact.isApprovedVersion) }
    }

    private func row(_ entry: ZhuowangAssetEntry) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.artifact.name) · V\(entry.artifact.version) · \(entry.artifact.type.title)")
                Text("\(entry.stepName) · \(AIWorkspaceTaskReferenceSelection.adoptionLabel(entry))")
                    .font(.caption).foregroundStyle(.secondary)
                Text("来源：Workflow.artifacts · \(entry.artifact.location.isEmpty ? "未登记路径" : entry.artifact.location)")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer()
            if AIWorkspaceTaskReferenceSelection.supportsBody(entry) {
                Button(selection.selections.contains(where: { $0.id == entry.id }) ? "重新读取" : selectTitle(entry)) {
                    Task { await selection.select(entry.id) }
                }.disabled(selection.loading)
                    .accessibilityIdentifier("ai-reference-select-\(entry.id)")
            } else { Text("仅元数据").font(.caption).foregroundStyle(.secondary) }
        }.padding(.vertical, 6)
    }
    private func selectTitle(_ entry: ZhuowangAssetEntry) -> String {
        if entry.adoptedCount == 1 && !entry.artifact.isApprovedVersion { return "读取并选用历史参考" }
        return "读取并选择正文"
    }
}
