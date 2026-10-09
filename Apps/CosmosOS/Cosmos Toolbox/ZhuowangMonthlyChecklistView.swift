import SwiftUI

/// "月度清单" tab of a monthly Campaign's detail window. It only reads the
/// Workflow (never creates one, never recovers, never adopts) and only writes
/// the Campaign's monthly plan through `updateMonthlyPlan`.
struct ZhuowangMonthlyChecklistView: View {

    @ObservedObject var store: ZhuowangCampaignStore
    @ObservedObject var workflowStore: ZhuowangWorkflowStore
    let campaignID: UUID

    @State private var message = ""
    @State private var monthDraft = ""
    @State private var monthDraftSource = ""

    private var campaign: ZhuowangCampaign? {
        store.campaign(id: campaignID)
    }

    var body: some View {
        if let campaign, let plan = campaign.monthly {
            let workflow = workflowStore.workflow(forCampaignID: campaign.id)
            VStack(alignment: .leading, spacing: CosmosDesign.spacingXL) {
                header(campaign, plan)
                if !message.isEmpty {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
                periodAndReference(campaign, plan)
                inputsSection(plan)
                outputsSection(campaign, plan, workflow)
                Text("登记只记录位置：不会打开链接，不会读取、复制或检查文件，也不会把它变成工作产物或可交付文件。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onAppear { syncMonthDraft(plan) }
            .onChange(of: plan.activityMonth) { _, _ in syncMonthDraft(plan) }
        } else {
            ContentUnavailableView("没有月度清单", systemImage: "list.bullet.clipboard",
                description: Text("该活动不是月度会员促活类型。"))
        }
    }

    // MARK: Header

    private func header(_ campaign: ZhuowangCampaign, _ plan: ZhuowangMonthlyPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("月度会员促活 · \(plan.activityMonth)").font(.title2)
            Text("月度成品已确认 \(ZhuowangMonthlyRules.confirmedOutputCount(plan))/\(ZhuowangMonthlyDefinition.outputs.count)")
                .font(.headline)
            Text("业务输入已齐备 \(ZhuowangMonthlyRules.settledInputCount(plan))/\(ZhuowangMonthlyDefinition.inputs.count)")
            Text("这两项只是你手动登记的清单状态；它们与 Workflow 进度、步骤采用情况和现有 ZIP 交付状态互不替代，也不会修改它们。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(ZhuowangMonthlyDefinition.suggestedDatesNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Month and reference

    private func periodAndReference(_ campaign: ZhuowangCampaign, _ plan: ZhuowangMonthlyPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("月份与上期参考").font(.headline)
            HStack {
                TextField("YYYY-MM", text: $monthDraft).frame(maxWidth: 120)
                    .accessibilityIdentifier("monthly-month")
                Button("保存月份") {
                    apply(.setActivityMonth(monthDraft.trimmingCharacters(in: .whitespacesAndNewlines)), plan)
                }
                .disabled(monthDraft == plan.activityMonth || !store.persistenceState.allowsMutations)
                Text("月份标签与实际起止时间相互独立。").font(.caption).foregroundStyle(.secondary)
            }
            let duplicates = ZhuowangMonthlyRules.campaignsWithMonth(plan.activityMonth, excluding: campaign.id, in: store.campaigns)
            if !duplicates.isEmpty {
                Text("已有 \(duplicates.count) 个同月月度活动（仅提示，不禁止）。").font(.caption).foregroundStyle(.orange)
            }
            referencePicker(campaign, plan)
        }
    }

    private func referencePicker(_ campaign: ZhuowangCampaign, _ plan: ZhuowangMonthlyPlan) -> some View {
        let state = ZhuowangMonthlyRules.referenceState(of: plan, in: store.campaigns)
        let eligible = eligibleReferences(campaign, plan)
        return VStack(alignment: .leading, spacing: 4) {
            Picker("上期参考", selection: Binding(
                get: { plan.referenceCampaignID },
                set: { apply(.setReference($0), plan) }
            )) {
                Text("不选").tag(UUID?.none)
                if case .missing = state, let id = plan.referenceCampaignID {
                    Text("（已不存在的活动）").tag(UUID?.some(id))
                }
                if case .notMonthly = state, let id = plan.referenceCampaignID {
                    Text("（非月度活动）").tag(UUID?.some(id))
                }
                ForEach(eligible) { reference in
                    Text("\(reference.monthly?.activityMonth ?? "") · \(reference.name)").tag(UUID?.some(reference.id))
                }
            }
            .disabled(!store.persistenceState.allowsMutations)
            switch state {
            case .none:
                Text("未选择上期参考。默认候选是本月份之前最近一期月度活动，需要时请手动选择。")
                    .font(.caption).foregroundStyle(.secondary)
            case .resolved:
                Text("只保存上期活动的身份；它的内容不会被复制。下方“上期”显示的是它的实时登记，上期修改后这里随之变化，也不会计入本期完成。")
                    .font(.caption).foregroundStyle(.secondary)
            case .missing:
                Text("上期参考活动已不存在。不会自动换成其他活动，请重新选择或选择“不选”。")
                    .font(.caption).foregroundStyle(.orange)
            case .notMonthly:
                Text("上期参考活动不是月度会员促活类型。不会自动换成其他活动，请重新选择。")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private func eligibleReferences(_ campaign: ZhuowangCampaign, _ plan: ZhuowangMonthlyPlan) -> [ZhuowangCampaign] {
        guard let own = ZhuowangActivityMonth(string: plan.activityMonth) else { return [] }
        return store.campaigns.filter { other in
            guard other.id != campaign.id, let theirs = other.monthly.flatMap({ ZhuowangActivityMonth(string: $0.activityMonth) })
            else { return false }
            return theirs < own
        }.sorted {
            let a = $0.monthly.flatMap { ZhuowangActivityMonth(string: $0.activityMonth) }
            let b = $1.monthly.flatMap { ZhuowangActivityMonth(string: $0.activityMonth) }
            if let a, let b, a != b { return a > b }
            return $0.createdAt > $1.createdAt
        }
    }

    // MARK: Inputs

    private func inputsSection(_ plan: ZhuowangMonthlyPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("向业务方要的输入").font(.headline)
            Text("流程文档的参考：从 T−14 起开始要，最晚 T−8 前到。联系人只记录是否已拿到，不在这里保存联系方式。")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(ZhuowangMonthlyDefinition.inputs) { definition in
                ZhuowangMonthlyInputRow(definition: definition, plan: plan,
                    canMutate: store.persistenceState.allowsMutations,
                    perform: { apply($0, plan) })
            }
        }
    }

    // MARK: Outputs

    private func outputsSection(_ campaign: ZhuowangCampaign, _ plan: ZhuowangMonthlyPlan,
                                _ workflow: ZhuowangCampaignWorkflow?) -> some View {
        let reference: ZhuowangCampaign? = {
            if case .resolved(let id) = ZhuowangMonthlyRules.referenceState(of: plan, in: store.campaigns) {
                return store.campaign(id: id)
            }
            return nil
        }()
        return VStack(alignment: .leading, spacing: 12) {
            Text("7 项产出").font(.headline)
            ForEach(ZhuowangMonthlyDefinition.outputs) { definition in
                ZhuowangMonthlyOutputRow(
                    definition: definition,
                    record: plan.output(definition.key),
                    hint: ZhuowangMonthlyRules.stepHint(for: definition, workflow: workflow),
                    suggestedDay: ZhuowangMonthlyRules.suggestedDay(start: campaign.startDate, offsetDays: definition.suggestedOffsetDays),
                    referenceRecord: reference?.monthly?.output(definition.key),
                    canMutate: store.persistenceState.allowsMutations,
                    perform: { apply($0, plan) })
            }
        }
    }

    // MARK: Actions

    /// Returns whether the change was saved; on refusal the message is shown and
    /// the caller keeps its input.
    @discardableResult
    private func apply(_ mutation: ZhuowangMonthlyMutation, _ plan: ZhuowangMonthlyPlan) -> Bool {
        let result = store.updateMonthlyPlan(campaignID: campaignID, expectedRevision: plan.revision, mutation)
        message = result.message ?? ""
        return result.succeeded
    }

    private func syncMonthDraft(_ plan: ZhuowangMonthlyPlan) {
        if monthDraftSource != plan.activityMonth {
            monthDraftSource = plan.activityMonth
            monthDraft = plan.activityMonth
        }
    }
}

// MARK: - Input row

private struct ZhuowangMonthlyInputRow: View {
    let definition: ZhuowangMonthlyInputDefinition
    let plan: ZhuowangMonthlyPlan
    let canMutate: Bool
    let perform: (ZhuowangMonthlyMutation) -> Void
    @State private var note = ""
    @State private var noteSource: String?

    private var storedNote: String {
        definition.kind == .prizePoolRelation ? plan.prizePoolNote : (plan.input(definition.key)?.note ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(definition.title).fontWeight(.medium)
                Spacer()
                switch definition.kind {
                case .receipt:
                    Picker("状态", selection: Binding(
                        get: { plan.input(definition.key)?.status ?? .requested },
                        set: { perform(.setInput(key: definition.key, status: $0, note: storedNote)) }
                    )) {
                        ForEach(ZhuowangMonthlyInputStatus.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().frame(width: 110).disabled(!canMutate)
                case .prizePoolRelation:
                    Picker("关系", selection: Binding(
                        get: { plan.prizePoolRelation },
                        set: { perform(.setPrizePool(relation: $0, note: storedNote)) }
                    )) {
                        ForEach(ZhuowangPrizePoolRelation.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().frame(width: 110).disabled(!canMutate)
                }
            }
            if definition.kind == .prizePoolRelation {
                Text("每个月都要重新确认，新建月度活动时总是“待确认”；两页的抽奖机会口径仍是两套。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                TextField("备注（按原文保存）", text: $note)
                Button("保存备注") { saveNote() }
                    .disabled(note == storedNote || !canMutate)
            }
        }
        .padding(10)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { syncNote() }
        .onChange(of: storedNote) { _, _ in syncNote() }
    }

    private func syncNote() {
        if noteSource != storedNote { noteSource = storedNote; note = storedNote }
    }

    private func saveNote() {
        switch definition.kind {
        case .receipt:
            perform(.setInput(key: definition.key, status: plan.input(definition.key)?.status ?? .requested, note: note))
        case .prizePoolRelation:
            perform(.setPrizePool(relation: plan.prizePoolRelation, note: note))
        }
    }
}

// MARK: - Output row

private struct ZhuowangMonthlyOutputRow: View {
    let definition: ZhuowangMonthlyOutputDefinition
    let record: ZhuowangMonthlyOutputRecord?
    let hint: ZhuowangMonthlyRules.StepHint
    let suggestedDay: Date?
    let referenceRecord: ZhuowangMonthlyOutputRecord?
    let canMutate: Bool
    let perform: (ZhuowangMonthlyMutation) -> Void

    @State private var showRegisterForm = false
    @State private var location = ""
    @State private var versionLabel = ""
    @State private var note = ""
    @State private var showHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(definition.title).fontWeight(.medium)
                Text(definition.formText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(record?.isConfirmed == true ? "已确认定稿" : "未确认")
                    .font(.caption)
                    .foregroundStyle(record?.isConfirmed == true ? .green : .secondary)
            }
            if let suggestedDay {
                Text("流程参考日：\(Self.dayText(suggestedDay))（T\(definition.suggestedOffsetDays > 0 ? "+" : "")\(definition.suggestedOffsetDays)，初版约定，非截止日期）")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(hintText).font(.caption).foregroundStyle(.secondary)
            currentView
            referenceView
            HStack {
                Button("登记新位置") { showRegisterForm.toggle() }.disabled(!canMutate)
                if let record, record.current != nil {
                    if record.isConfirmed {
                        Button("取消确认") { perform(.clearConfirmation(outputKey: definition.key)) }.disabled(!canMutate)
                    } else if let current = record.current {
                        Button("确认定稿") {
                            perform(.confirmRegistration(outputKey: definition.key, registrationID: current.id))
                        }.disabled(!canMutate)
                    }
                }
                if let record, record.registrations.count > 1 {
                    Button(showHistory ? "收起历史" : "历史登记（\(record.registrations.count)）") { showHistory.toggle() }
                        .buttonStyle(.link)
                }
            }
            if showRegisterForm { registerForm }
            if showHistory, let record { historyView(record) }
        }
        .padding(10)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var hintText: String {
        guard hint.workflowExists else {
            return "来源提示：该活动的 Workflow 尚未创建（打开清单不会创建它）。这只是来源提示，不代表该项完成。"
        }
        guard let title = hint.stepTitle else {
            return "来源提示：Workflow 中没有对应步骤。这只是来源提示，不代表该项完成。"
        }
        if hint.adoptedArtifactCount > 0 {
            return "来源提示：「\(title)」步骤已有 \(hint.adoptedArtifactCount) 个采用产物。这只是来源提示，不代表该项已完成（例如 Markdown 文档不等于外部 Word 定稿）。"
        }
        return "来源提示：「\(title)」步骤暂无采用产物。这只是来源提示。"
    }

    @ViewBuilder private var currentView: some View {
        if let current = record?.current {
            VStack(alignment: .leading, spacing: 2) {
                Text("当前登记" + (current.versionLabel.isEmpty ? "" : " · \(current.versionLabel)")).font(.caption).fontWeight(.medium)
                Text(current.location).textSelection(.enabled).font(.callout)
                if !current.note.isEmpty { Text(current.note).textSelection(.enabled).font(.caption) }
                Text("已登记，未核验文件／链接可用性").font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Text("尚无登记位置").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var referenceView: some View {
        if let current = referenceRecord?.current {
            VStack(alignment: .leading, spacing: 2) {
                Text(referenceRecord?.isConfirmed == true ? "上期当前定稿（实时参考）" : "上期当前登记（未确认定稿，实时参考）")
                    .font(.caption).foregroundStyle(.secondary)
                Text(current.location).textSelection(.enabled).font(.caption)
            }
        }
    }

    private var registerForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("位置：绝对路径（/…）或 http/https 链接", text: $location)
                .accessibilityIdentifier("monthly-register-location")
            TextField("版本标签（可选，例如 V1.1）", text: $versionLabel)
            TextField("备注（按原文保存）", text: $note)
            HStack {
                Button("登记") {
                    perform(.addRegistration(outputKey: definition.key, id: UUID(), location: location,
                        versionLabel: versionLabel, note: note, at: Date()))
                    // Inputs are kept unless the parent reports success by the record changing.
                }
                .disabled(location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canMutate)
                Button("关闭") { showRegisterForm = false }
            }
            Text("新登记不会自动定稿；它会成为当前登记，并清除该项原有的定稿确认。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: record?.registrations.count ?? 0) { _, _ in
            location = ""; versionLabel = ""; note = ""; showRegisterForm = false
        }
    }

    private func historyView(_ record: ZhuowangMonthlyOutputRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(record.registrations.reversed()) { registration in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text((registration.versionLabel.isEmpty ? "未标版本" : registration.versionLabel)
                             + (registration.id == record.currentRegistrationID ? " · 当前" : ""))
                            .font(.caption).fontWeight(.medium)
                        Text(registration.location).textSelection(.enabled).font(.caption)
                        if !registration.note.isEmpty { Text(registration.note).textSelection(.enabled).font(.caption2) }
                    }
                    Spacer()
                    if registration.id != record.currentRegistrationID {
                        Button("设为当前") {
                            perform(.setCurrentRegistration(outputKey: definition.key, registrationID: registration.id))
                        }.disabled(!canMutate)
                    }
                }
            }
            Text("历史登记只追加，不会被覆盖；更换当前登记会清除该项定稿确认。")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private static func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = ZhuowangMonthlyRules.shanghai
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}
