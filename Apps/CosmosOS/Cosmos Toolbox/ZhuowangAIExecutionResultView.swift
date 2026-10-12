import SwiftUI
import AppKit

// MARK: - Execution State

enum ZhuowangAIExecutionViewState: Equatable {

    case running
    case succeeded
    case failed
}


// MARK: - AI Execution Result View

struct ZhuowangAIExecutionResultView: View {

    let taskPackage: ZhuowangAITaskPackage

    let provider: ZhuowangAIProvider?
    let connection: ZhuowangAIConnection?
    let artifactDraft: ZhuowangArtifactDraft?

    let resultText: String
    let errorText: String

    let state: ZhuowangAIExecutionViewState

    let onAdopt: () ->
        ZhuowangArtifactAdoptionPresentationResult
    let onRequestRevision: (String) -> Void
    let onRegenerate: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var copied = false

    @State
    private var showRevisionSheet = false

    @State
    private var adoptionErrorMessage: String?


    var body: some View {
        NavigationStack {


            VStack(spacing: 0) {

                ScrollView {

                    VStack(
                        alignment: .leading,
                        spacing: CosmosDesign.spacingL
                    ) {

                        executionSummary

                        ZStack(alignment: .top) {

                            switch state {

                            case .running:
                                runningContent
                                    .transition(.opacity)

                            case .succeeded:
                                successContent
                                    .transition(.opacity)

                            case .failed:
                                failureContent
                                    .transition(.opacity)
                            }
                        }
                        .campaignUIAnimation(
                            .smooth(duration: CosmosDesign.animationNormal),
                            value: state
                        )
                    }
                    .padding(
                        .horizontal,
                        CosmosDesign.spacingXL + 4
                    )
                    .padding(
                        .vertical,
                        CosmosDesign.spacingXL
                    )
                    .frame(
                        maxWidth: 880
                    )
                    .frame(maxWidth: .infinity)
                }.scrollEdgeEffectStyle(.soft, for: .top)
            }
            .frame(
                minWidth: 820,
                minHeight: 720
            )
            .background(Color(nsColor: .windowBackgroundColor))
            .modifier(CosmosMotionPolicy())
            .sheet(
                isPresented:
                    $showRevisionSheet
            ) {

                ZhuowangAIRevisionRequestView {

                    feedback in

                    onRequestRevision(
                        feedback
                    )

                    showRevisionSheet =
                        false
                }
            }

    .navigationTitle(headerTitle)
    .navigationSubtitle(headerSubtitle)
    .toolbar {
    ToolbarItem(placement: .cancellationAction) {
        Button("关闭") { dismiss() }.disabled(state == .running)
    }
    ToolbarItemGroup(placement: .primaryAction) {
        if state == .succeeded {
            Button(copied ? "已复制" : "复制结果", systemImage: copied ? "checkmark" : "doc.on.doc") { copyResult() }
            Button("要求修改", systemImage: "text.bubble") { showRevisionSheet = true }
            Button("重新生成", systemImage: "arrow.clockwise") { onRegenerate() }
        }
    }
    ToolbarItem(placement: .confirmationAction) {
        if state == .succeeded {
            Button("采用结果", systemImage: "checkmark.circle") {
                let result = onAdopt()
                if result.succeeded {
                    adoptionErrorMessage = nil
                    dismiss()
                } else {
                    adoptionErrorMessage = result.errorMessage ?? "采用失败。Workflow 状态未改变，请检查后重试。"
                }
            }.buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
        } else if state == .failed {
            Button("重新执行", systemImage: "arrow.clockwise") { onRegenerate() }.buttonStyle(.glassProminent)
        }
    }
    ToolbarItem(placement: .status) {
        if state == .running {
            Label("执行过程中请保持 Cosmos OS 运行", systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
            ProgressView().controlSize(.small)
        }
    }
    }
        }
    }


    // MARK: - Header


    // MARK: - Summary

    private var executionSummary: some View {

        VStack(
            alignment: .leading,
            spacing:
                CosmosDesign.spacingM
        ) {

            HStack(
                alignment: .top,
                spacing:
                    CosmosDesign.spacingL
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(taskPackage.title)
                        .font(.system(size: 20, weight: .semibold))

                    Text(
                        "Cosmos OS · AI Execution"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                executionStateBadge
            }

            Divider()

            HStack(
                spacing:
                    CosmosDesign.spacingXL
            ) {

                CampaignUIKeyValue(
                    title: "AI Provider",
                    value:
                        provider?.name
                        ?? "未选择"
                )

                CampaignUIKeyValue(
                    title: "Connection",
                    value:
                        connectionDisplayName
                )

                CampaignUIKeyValue(
                    title: "Execution",
                    value:
                        executionStyleText
                )
            }
        }
        .campaignUICardSurface()
    }


    // MARK: - Running

    private var runningContent: some View {

        VStack(
            spacing:
                CosmosDesign.spacingL
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color.accentColor
                            .opacity(0.08)
                    )
                    .frame(
                        width: 82,
                        height: 82
                    )

                ProgressView()
                    .controlSize(.large)
            }

            VStack(spacing: 7) {

                Text("AI 正在执行任务")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(
                    runningDescription
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
                .frame(
                    maxWidth: 500
                )
            }

            VStack(
                alignment: .leading,
                spacing: 10
            ) {

                Label(
                    "正在发送任务包",
                    systemImage:
                        "checkmark.circle.fill"
                )

                Label(
                    "等待 AI 返回最终结果",
                    systemImage:
                        "hourglass"
                )

                Label(
                    "返回后将进入人工审核",
                    systemImage:
                        "person.crop.circle.badge.checkmark"
                )
            }
            .font(.callout)
            .foregroundStyle(
                .secondary
            )
            .padding(.top, 4)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 320
        )
        .campaignUICardSurface()
    }


    // MARK: - Success

    private var successContent: some View {

        VStack(
            alignment: .leading,
            spacing:
                CosmosDesign.spacingL
        ) {

            // 1. 等待你的确认：先说清楚下一步由用户决定。
            reviewNotice

            // 2. 生成结果。
            resultCard

            if let adoptionErrorMessage {
                CampaignUINotice(
                    text: adoptionErrorMessage,
                    icon: "exclamationmark.triangle",
                    tone: .danger
                )
            }
        }
    }


    // MARK: - Result Card

    private var resultCard: some View {

        CampaignUICard(
            title: provider?.name ?? "AI Result",
            icon: "sparkles",
            info: "这是 AI 生成的草稿，还没有被采用。采用后才会保存为工作产物并解锁下一步。",
            trailing: {

                CampaignUIStatusPill(
                    text: "Draft",
                    tone: .neutral
                )

                Button {

                    copyResult()

                } label: {

                    Label(
                        copied
                        ? "已复制"
                        : "复制结果",
                        systemImage:
                            copied
                            ? "checkmark"
                            : "doc.on.doc"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        ) {

            if let artifactDraft {
                artifactDraftSummary(
                    artifactDraft
                )
            } else {
                sourceCodeView
            }
        }
    }


    private func artifactDraftSummary(
        _ draft: ZhuowangArtifactDraft
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {
            HStack(spacing: CosmosDesign.spacingL) {
                Label(
                    draft.name,
                    systemImage: CampaignUIFormat.artifactIcon(draft.type)
                )
                .font(.headline)

                Spacer()

                Text(draft.type.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(
                draft.type == .html
                ? "在独立 Artifact Review Workspace 中查看真实渲染、切换 Mobile Viewport，并核对源码。"
                : "在独立 Artifact Review Workspace 中阅读完整内容并核对原文。"
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack {
                Text("内容长度：\(draft.content.utf8.count) bytes")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    openArtifactReviewWorkspace()
                } label: {
                    Label(
                        "打开完整预览",
                        systemImage: "macwindow"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(CosmosDesign.spacingM)
        .background(
            Color.primary.opacity(0.018),
            in: RoundedRectangle(
                cornerRadius: CosmosDesign.cornerRadiusSmall,
                style: .continuous
            )
        )
    }


    private var sourceCodeView: some View {

        ScrollView([.horizontal, .vertical]) {
            Text(cleanedResultText)
                .font(
                    .system(
                        size: 13,
                        design: artifactDraft?.type == .html
                            ? .monospaced
                            : .default
                    )
                )
                .textSelection(.enabled)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(CosmosDesign.spacingM)
        }.scrollEdgeEffectStyle(.soft, for: .top)
        .frame(minHeight: artifactDraft?.type == .html ? 420 : 180)
        .background(
            Color.primary.opacity(0.018),
            in: RoundedRectangle(
                cornerRadius: CosmosDesign.cornerRadiusSmall,
                style: .continuous
            )
        )
    }


    // MARK: - Review Notice

    private var reviewNotice: some View {

        HStack(
            alignment: .top,
            spacing:
                CosmosDesign.spacingM
        ) {

            Image(
                systemName:
                    "person.crop.circle.badge.checkmark"
            )
            .font(
                .system(
                    size: 18,
                    weight: .medium
                )
            )
            .foregroundStyle(.tint)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text("等待你的确认")
                    .fontWeight(.semibold)

                Text(
                    "AI 已完成当前步骤，但不会自动进入下一步。你可以采用结果、提出修改意见，或者重新生成。"
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()
        }
        .padding(
            CosmosDesign.spacingM
        )
        .background(
            Color.accentColor
                .opacity(0.07),
            in: RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusMedium,
                style: .continuous
            )
        )
    }


    // MARK: - Failure

    private var failureContent: some View {

        VStack(
            alignment: .leading,
            spacing:
                CosmosDesign.spacingL
        ) {

            VStack(
                spacing:
                    CosmosDesign.spacingM
            ) {

                Image(
                    systemName:
                        "exclamationmark.triangle"
                )
                .font(
                    .system(
                        size: 26,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.red
                )
                .frame(width: 70, height: 70)
                .background(
                    Color.red.opacity(0.08),
                    in: Circle()
                )

                Text("AI 执行失败")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(
                    "任务没有成功完成。你可以查看错误信息后重新尝试。"
                )
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
            }
            .frame(
                maxWidth: .infinity
            )


            CampaignUICard(
                title: "错误信息",
                icon: "exclamationmark.octagon",
                trailing: {
                    Button {

                        copyError()

                    } label: {

                        Label(
                            "复制错误",
                            systemImage:
                                "doc.on.doc"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            ) {

                Text(
                    cleanedErrorText
                )
                .font(
                    .system(
                        size: 13,
                        design: .monospaced
                    )
                )
                .textSelection(.enabled)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(
                    CosmosDesign.spacingM
                )
                .background(
                    Color.red
                        .opacity(0.045),
                    in: RoundedRectangle(
                        cornerRadius:
                            CosmosDesign.cornerRadiusSmall,
                        style: .continuous
                    )
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign.cornerRadiusLarge,
                    style: .continuous
                )
                .stroke(
                    Color.red
                        .opacity(0.18),
                    lineWidth: 1
                )
            }
        }
    }


    // MARK: - Footer

    @ViewBuilder


    // MARK: - Status Badge

    private var executionStateBadge:
        some View {

        CampaignUIStatusPill(
            text: stateTitle,
            tone: headerTone
        )
    }

    private var headerTone: CampaignUITone {

        switch state {

        case .running:
            return .info

        case .succeeded:
            return .success

        case .failed:
            return .danger
        }
    }


    // MARK: - Helpers

    private var stateTitle: String {

        switch state {

        case .running:
            return "执行中"

        case .succeeded:
            return "已完成"

        case .failed:
            return "失败"
        }
    }


    private var headerTitle: String {

        switch state {

        case .running:
            return "AI 正在执行"

        case .succeeded:
            return "AI 执行结果"

        case .failed:
            return "AI 执行失败"
        }
    }


    private var headerSubtitle: String {

        switch state {

        case .running:
            return "AI Execution in Progress"

        case .succeeded:
            return "AI Execution Result"

        case .failed:
            return "AI Execution Failed"
        }
    }


    private var headerIcon: String {

        switch state {

        case .running:
            return "sparkles"

        case .succeeded:
            return "checkmark.circle"

        case .failed:
            return "exclamationmark.triangle"
        }
    }


    private var headerColor: Color {

        switch state {

        case .running:
            return .blue

        case .succeeded:
            return .green

        case .failed:
            return .red
        }
    }


    private var runningDescription:
        String {

        if let provider {

            return "\(provider.name) 正在处理当前任务。完成后，结果会自动返回 Cosmos OS。"
        }

        return "AI 正在处理当前任务。完成后，结果会自动返回 Cosmos OS。"
    }


    private var connectionDisplayName:
        String {

        guard let connection else {
            return "未指定"
        }

        return "\(connection.name) · \(connection.mode.title)"
    }


    private var executionStyleText:
        String {

        guard let connection else {
            return "未指定"
        }

        switch connection.executionStyle {

        case .direct:
            return "直接执行"

        case .localProcess:
            return "本地进程"

        case .assistedManual:
            return "辅助执行"

        case .externalTool:
            return "外部工具"

        case .custom:
            return "自定义"
        }
    }


    private var cleanedResultText:
        String {

        let cleaned =
            resultText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return cleaned.isEmpty
        ? "AI 没有返回可显示的内容。"
        : cleaned
    }


    private var cleanedErrorText:
        String {

        let cleaned =
            errorText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return cleaned.isEmpty
        ? "没有可用的错误详情。"
        : cleaned
    }


    private func openArtifactReviewWorkspace() {
        guard let artifactReviewDocument else {
            return
        }

        ArtifactReviewWindowManager.shared.open(
            document: artifactReviewDocument
        )
    }


    private var artifactReviewDocument:
        ArtifactReviewDocument? {
        guard let artifactDraft else {
            return nil
        }

        return ArtifactReviewDocument(
            id: taskPackage.executionSnapshot?.id
                ?? taskPackage.id,
            draft: artifactDraft,
            snapshot: taskPackage.executionSnapshot,
            providerName: frozenProviderName
        )
    }


    private var frozenProviderName: String? {
        guard let snapshot = taskPackage.executionSnapshot else {
            return provider?.name
        }

        guard provider?.id == snapshot.providerID else {
            return nil
        }

        return provider?.name
    }


    // MARK: - Clipboard

    private func copyResult() {

        NSPasteboard.general
            .clearContents()

        NSPasteboard.general
            .setString(
                cleanedResultText,
                forType: .string
            )

        copied = true

        DispatchQueue.main
            .asyncAfter(
                deadline:
                    .now() + 1.5
            ) {

                copied = false
            }
    }


    private func copyError() {

        NSPasteboard.general
            .clearContents()

        NSPasteboard.general
            .setString(
                cleanedErrorText,
                forType: .string
            )
    }
}


// MARK: - Revision Request View

struct ZhuowangAIRevisionRequestView:
    View {

    let onSubmit: (String) -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var feedback = ""


    var body: some View {
        NavigationStack {


            VStack(spacing: 0) {

                VStack(
                    alignment: .leading,
                    spacing:
                        CosmosDesign.spacingM
                ) {

                    Text("告诉 AI 需要修改什么")
                        .font(.headline)

                    TextEditor(
                        text: $feedback
                    )
                    .frame(
                        minHeight: 180
                    )
                    .padding(10)
                    .background(
                        Color.primary
                            .opacity(0.025),
                        in: RoundedRectangle(
                            cornerRadius:
                                CosmosDesign.cornerRadiusSmall,
                            style: .continuous
                        )
                    )
                    .overlay {

                        RoundedRectangle(
                            cornerRadius:
                                CosmosDesign.cornerRadiusSmall,
                            style: .continuous
                        )
                        .stroke(
                            Color.primary
                                .opacity(0.07),
                            lineWidth: 1
                        )
                    }

                    Text("例如：玩法太复杂，保留签到和抽奖，减少排行榜内容，并重新优化 Slogan。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)


            }
            .frame(
                minWidth: 560,
                minHeight: 420
            )
            .background(Color(nsColor: .windowBackgroundColor))

    .navigationTitle("要求修改")
    .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
                    Button("提交修改意见") {

                        let cleanFeedback =
                            feedback
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )

                        guard
                            !cleanFeedback.isEmpty
                        else {
                            return
                        }

                        onSubmit(
                            cleanFeedback
                        )

                        dismiss()
                    }
                    .buttonStyle(
                        .glassProminent
                    )
                    .keyboardShortcut(
                        .defaultAction
                    )
                    .disabled(
                        feedback
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
                    )

        }
    }
        }
    }
}
