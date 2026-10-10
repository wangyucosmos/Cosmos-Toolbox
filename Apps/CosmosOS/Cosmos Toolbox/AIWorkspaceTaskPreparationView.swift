import SwiftUI

struct AIWorkspaceTaskPreparationView: View {
    @ObservedObject var model: AIWorkspaceTaskPreparation
    var history: AIWorkspaceHandoffStore? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("准备任务").font(.title2)
                Spacer()
                Button("刷新活动上下文", systemImage: "arrow.clockwise") { model.refresh() }
            }
            Text("选择已有活动与步骤，填写本次目标，再复制给 Claude 或 Codex。无需本机 CLI 可运行；草稿仅保留在当前页面内存中。切换活动或步骤会清空本次输入。")
                .font(.callout).foregroundStyle(.secondary)
            Picker("活动", selection: Binding(get: { model.campaignID }, set: { model.selectCampaign($0) })) {
                Text("请选择活动").tag(Optional<UUID>.none)
                ForEach(model.context.campaigns) { campaign in
                    Text("\(campaign.name) · \(campaign.dateRangeText)").tag(Optional(campaign.id))
                }
            }.accessibilityIdentifier("ai-task-campaign")
            Picker("Workflow 步骤", selection: Binding(get: { model.stepID }, set: { model.selectStep($0) })) {
                Text("请选择步骤").tag(Optional<UUID>.none)
                ForEach(model.steps) { step in
                    Text("\(step.title) · \(step.status.title)\(step.isEnabled ? "" : " · 已停用")").tag(Optional(step.id))
                }
            }.disabled(model.steps.isEmpty).accessibilityIdentifier("ai-task-step")
            if let step = model.step {
                Text("\(model.workflow?.name ?? "") / \(step.title) · \(step.status.title)").font(.headline)
                if !step.notes.isEmpty { Text("步骤说明：\(step.notes)").foregroundStyle(.secondary).textSelection(.enabled) }
            }
            Picker("交接工具", selection: $model.tool) {
                ForEach(AIWorkspaceHandoffTool.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).frame(maxWidth: 300)
            Text("本次目标（必填）").font(.headline)
            TextField("说明本次希望完成什么", text: $model.goal, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(2...5)
                .accessibilityIdentifier("ai-task-goal")
            Text("补充要求（选填）").font(.headline)
            TextEditor(text: $model.requirements)
                .font(.body).frame(height: 100)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))
                .accessibilityIdentifier("ai-task-requirements")
            HStack {
                Text("任务提示词预览").font(.title3)
                Spacer()
                Button("复制当前提示词", systemImage: "doc.on.doc") { model.copyPreview() }
                    .disabled(model.preview == nil)
                    .accessibilityIdentifier("ai-task-copy")
            }
            if let history {
                AIWorkspaceHandoffRecordingView(preparation: model, history: history)
            }
            if let feedback = model.copyFeedback {
                Text(feedback).font(.callout).accessibilityIdentifier("ai-task-copy-feedback")
            }
            if let preview = model.preview {
                Text(preview).font(.body.monospaced()).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("ai-task-preview")
            } else {
                Text(model.validation ?? "请选择活动与步骤。")
                    .foregroundStyle(.secondary).accessibilityIdentifier("ai-task-empty")
            }
        }
    }
}
