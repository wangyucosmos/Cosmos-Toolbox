import SwiftUI

struct AIWorkspaceTaskPreparationView: View {
    @ObservedObject var model: AIWorkspaceTaskPreparation
    var history: AIWorkspaceHandoffStore? = nil
    @State private var stage: Int
    @State private var copied = false
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    init(model: AIWorkspaceTaskPreparation, history: AIWorkspaceHandoffStore? = nil, initialStage: Int = 1) {
        self.model = model; self.history = history; _stage = State(initialValue: initialStage)
    }
    var body: some View {
        let preview = model.preview
        let guide = CosmosAITaskGuide(selectionComplete: model.campaign != nil && model.workflow != nil && model.step != nil,
            goalEntered: !model.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, previewReady: preview != nil)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ForEach(1...3, id: \.self) { number in
                    Button { stage = number } label: {
                        HStack(spacing: 8) {
                            Image(systemName: guide.status(number) == .complete ? "checkmark.circle.fill" : "\(number).circle.fill").cosmosSymbolReplacement()
                                .foregroundStyle(guide.status(number) == .waiting ? Color.secondary : Color.accentColor)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(["选择活动与步骤", "填写本次目标", "预览并交接"][number - 1]).font(CosmosDesign.font(.body))
                                Text(guide.status(number) == .waiting ? "待完成前一步" : guide.status(number) == .complete ? "已准备" : "继续填写")
                                    .font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }.padding(12).background(stage == number ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).disabled(!guide.permits(number)).accessibilityLabel("第\(number)步")
                }
            }
            CosmosContentPanel {
                if stage == 1 || !guide.permits(stage) { selectionStep(guide) }
                else if stage == 2 { goalStep(guide) }
                else { previewStep(preview) }
            }
            Text("草稿只在本次页面内存中；切换活动或步骤会清空本次输入。复制不自动记录，也不表示执行或完成。")
                .font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
        }
            .onChange(of: model.campaignID) { _, _ in stage = 1; copied = false }
            .onChange(of: model.stepID) { _, _ in copied = false }
            .onChange(of: model.copyFeedback) { _, feedback in copied = feedback == "已复制当前任务提示词" }
            .task(id: copied) {
                guard copied else { return }
                do { try await Task.sleep(for: .seconds(CosmosDesign.successDuration)); copied = false } catch { }
            }
    }
    private func selectionStep(_ guide: CosmosAITaskGuide) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("① 选择活动和 Workflow 步骤").font(CosmosDesign.font(.section))
            Text("为什么：把已保存的上下文带给工具，避免从头解释。例：河南活动 → 完整策划案。").font(CosmosDesign.font(.body)).foregroundStyle(.secondary)
            Picker("活动", selection: Binding(get: { model.campaignID }, set: { model.selectCampaign($0) })) {
                Text("请选择活动").tag(Optional<UUID>.none)
                ForEach(model.context.campaigns) { Text("\($0.name) · \(ZhuowangWorkspaceUI.dates($0))").tag(Optional($0.id)) }
            }.accessibilityIdentifier("ai-task-campaign")
            Picker("Workflow 步骤", selection: Binding(get: { model.stepID }, set: { model.selectStep($0) })) {
                Text("请选择步骤").tag(Optional<UUID>.none)
                ForEach(model.steps) { Text("\($0.title) · \($0.status.title)\($0.isEnabled ? "" : " · 已停用")").tag(Optional($0.id)) }
            }.disabled(model.steps.isEmpty).accessibilityIdentifier("ai-task-step")
            if !guide.selectionComplete { Text(model.validation ?? "请选择活动与步骤。").font(CosmosDesign.font(.body)).foregroundStyle(.secondary).accessibilityIdentifier("ai-task-empty") }
            if let step = model.step { Text("\(model.workflow?.name ?? "") / \(step.title) · \(step.status.title)").font(CosmosDesign.font(.body)); if !step.notes.isEmpty { Text(step.notes).foregroundStyle(.secondary).textSelection(.enabled) } }
            Button("下一步：填写目标", systemImage: "arrow.right") { stage = 2 }.buttonStyle(.bordered).disabled(!guide.selectionComplete)
        }
    }
    private func goalStep(_ guide: CosmosAITaskGuide) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("② 写本次目标与补充要求").font(CosmosDesign.font(.section))
            Text("为什么：明确本次交付范围，让结果可以核对。").font(.callout).foregroundStyle(.secondary)
            Picker("交接工具", selection: $model.tool) { ForEach(AIWorkspaceHandoffTool.allCases) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented).frame(maxWidth: 300)
            TextField("例如：为河南活动生成完整策划案初稿（必填）", text: $model.goal, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(2...5).accessibilityIdentifier("ai-task-goal")
            Text("补充要求（选填，例如：保留既定奖品、列出待确认事项）").font(CosmosDesign.font(.body))
            TextEditor(text: $model.requirements).font(CosmosDesign.font(.body)).frame(height: 90)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor))).accessibilityIdentifier("ai-task-requirements")
            DisclosureGroup("参考资料（可选，明确选择后才读取）") { AIWorkspaceTaskReferencesView(selection: model.referenceSelection) }
            if let reason = model.validation { Text(reason).font(CosmosDesign.font(.body)).foregroundStyle(.secondary) }
            HStack { Button("上一步") { stage = 1 }; Spacer(); Button("下一步：预览提示词", systemImage: "arrow.right") { stage = 3 }.buttonStyle(.bordered).disabled(!guide.permits(3)) }
        }
    }
    private func previewStep(_ preview: String?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("③ 预览完整提示词").font(CosmosDesign.font(.section))
                Spacer()
                Button("复制给 \(model.tool.rawValue)", systemImage: "doc.on.doc") { model.copyPreview() }
                    .buttonStyle(.bordered).disabled(preview == nil || model.copying).accessibilityIdentifier("ai-task-copy")
            }
            if copied { Label("已复制：粘贴到 Claude Code / Codex 执行；完成后回到这里点“记录交接”。", systemImage: "checkmark.circle.fill").foregroundStyle(.green).accessibilityIdentifier("ai-task-copy-feedback") }
            else if let feedback = model.copyFeedback, feedback != "已复制当前任务提示词" { Text(feedback).foregroundStyle(.orange).accessibilityIdentifier("ai-task-copy-feedback") }
            Text("为什么：先检查完整上下文，再交给工具；记录交接可以追踪产出和下一步。").font(.callout).foregroundStyle(.secondary)
            if let preview { Text(preview).font(.body.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(14)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10)).accessibilityIdentifier("ai-task-preview") }
            else { Text(model.validation ?? "请先完成前两步。").foregroundStyle(.secondary) }
            if let history { AIWorkspaceHandoffRecordingView(preparation: model, history: history) }
            Button("返回修改目标") { stage = 2 }
        }
    }
}
