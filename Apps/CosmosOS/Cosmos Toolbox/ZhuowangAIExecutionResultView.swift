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

    let resultText: String
    let errorText: String

    let state: ZhuowangAIExecutionViewState

    let onAdopt: () -> Void
    let onRequestRevision: (String) -> Void
    let onRegenerate: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var copied = false

    @State
    private var showRevisionSheet = false


    var body: some View {

        VStack(spacing: 0) {

            header

            Divider()

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: CosmosDesign.spacingXL
                ) {

                    executionSummary

                    switch state {

                    case .running:
                        runningContent

                    case .succeeded:
                        successContent

                    case .failed:
                        failureContent
                    }
                }
                .padding(
                    .horizontal,
                    CosmosDesign.pagePadding
                )
                .padding(
                    .vertical,
                    CosmosDesign.spacingXL
                )
                .frame(
                    maxWidth: 860,
                    alignment: .leading
                )
            }

            Divider()

            footer
        }
        .frame(
            minWidth: 820,
            minHeight: 720
        )
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
    }


    // MARK: - Header

    private var header: some View {

        HStack(
            spacing:
                CosmosDesign.spacingM
        ) {

            ZStack {

                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
                .fill(
                    headerColor.opacity(0.10)
                )
                .frame(
                    width: 40,
                    height: 40
                )

                Image(
                    systemName:
                        headerIcon
                )
                .font(
                    .system(
                        size: 17,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    headerColor
                )
            }

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(headerTitle)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
            }

            Spacer()

            if state == .running {

                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }

            Button("关闭") {

                dismiss()
            }
            .disabled(
                state == .running
            )
        }
        .padding(
            .horizontal,
            CosmosDesign.spacingL
        )
        .padding(
            .vertical,
            CosmosDesign.spacingM
        )
    }


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
                        .font(.title2)
                        .fontWeight(.semibold)

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

                summaryItem(
                    title: "AI Provider",
                    value:
                        provider?.name
                        ?? "未选择"
                )

                summaryItem(
                    title: "Connection",
                    value:
                        connectionDisplayName
                )

                summaryItem(
                    title: "Execution",
                    value:
                        executionStyleText
                )
            }
        }
        .padding(
            CosmosDesign.cardPadding
        )
        .background(.thinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusLarge,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusLarge,
                style: .continuous
            )
            .stroke(
                Color.primary
                    .opacity(0.06),
                lineWidth: 1
            )
        }
    }


    // MARK: - Summary Item

    private func summaryItem(
        title: String,
        value: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 4
        ) {

            Text(title)
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

            Text(value)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(2)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
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
            minHeight: 360
        )
        .background(
            Color.primary
                .opacity(0.012)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusLarge,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusLarge,
                style: .continuous
            )
            .stroke(
                Color.primary
                    .opacity(0.05),
                lineWidth: 1
            )
        }
    }


    // MARK: - Success

    private var successContent: some View {

        VStack(
            alignment: .leading,
            spacing:
                CosmosDesign.spacingXL
        ) {

            HStack {

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text("AI 生成结果")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Generated Result")
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                }

                Spacer()

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
            }


            resultCard


            reviewNotice
        }
    }


    // MARK: - Result Card

    private var resultCard: some View {

        VStack(
            alignment: .leading,
            spacing:
                CosmosDesign.spacingM
        ) {

            HStack(
                spacing: 8
            ) {

                Image(
                    systemName:
                        "sparkles"
                )
                .foregroundStyle(.tint)

                Text(
                    provider?.name
                    ?? "AI Result"
                )
                .font(.headline)

                Spacer()

                Text("Draft")
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )
                    .padding(
                        .horizontal,
                        8
                    )
                    .padding(
                        .vertical,
                        4
                    )
                    .background(
                        Color.primary
                            .opacity(0.04)
                    )
                    .clipShape(
                        Capsule()
                    )
            }

            Divider()

            Text(
                cleanedResultText
            )
            .font(
                .system(
                    size: 14
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
                Color.primary
                    .opacity(0.018)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign.cornerRadiusSmall,
                    style: .continuous
                )
            )
        }
        .padding(
            CosmosDesign.spacingL
        )
        .background(.thinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusLarge,
                style: .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    CosmosDesign.cornerRadiusLarge,
                style: .continuous
            )
            .stroke(
                Color.primary
                    .opacity(0.06),
                lineWidth: 1
            )
        }
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
                    .fontWeight(.medium)

                Text(
                    "AI 已完成当前步骤，但不会自动进入下一步。你可以采用结果、提出修改意见，或者重新生成。"
                )
                .font(.caption)
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
                .opacity(0.055)
        )
        .clipShape(
            RoundedRectangle(
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
                CosmosDesign.spacingXL
        ) {

            VStack(
                spacing:
                    CosmosDesign.spacingM
            ) {

                ZStack {

                    Circle()
                        .fill(
                            Color.red
                                .opacity(0.08)
                        )
                        .frame(
                            width: 70,
                            height: 70
                        )

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
                }

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


            VStack(
                alignment: .leading,
                spacing:
                    CosmosDesign.spacingM
            ) {

                HStack {

                    Text("错误信息")
                        .font(.headline)

                    Spacer()

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
                }

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
                        .opacity(0.035)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            CosmosDesign.cornerRadiusSmall,
                        style: .continuous
                    )
                )
            }
            .padding(
                CosmosDesign.spacingL
            )
            .background(
                Color.primary
                    .opacity(0.012)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign.cornerRadiusLarge,
                    style: .continuous
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        CosmosDesign.cornerRadiusLarge,
                    style: .continuous
                )
                .stroke(
                    Color.red
                        .opacity(0.15),
                    lineWidth: 1
                )
            }
        }
    }


    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {

        switch state {

        case .running:

            HStack {

                Label(
                    "执行过程中请保持 Cosmos OS 运行",
                    systemImage:
                        "info.circle"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                Spacer()

                ProgressView()
                    .controlSize(.small)

                Text("执行中…")
                    .font(.callout)
                    .foregroundStyle(
                        .secondary
                    )
            }
            .padding(
                .horizontal,
                CosmosDesign.spacingL
            )
            .padding(
                .vertical,
                CosmosDesign.spacingM
            )


        case .succeeded:

            HStack(
                spacing:
                    CosmosDesign.spacingM
            ) {

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

                Spacer()

                Button {

                    showRevisionSheet =
                        true

                } label: {

                    Label(
                        "要求修改",
                        systemImage:
                            "text.bubble"
                    )
                }
                .buttonStyle(.bordered)

                Button {

                    onRegenerate()

                } label: {

                    Label(
                        "重新生成",
                        systemImage:
                            "arrow.clockwise"
                    )
                }
                .buttonStyle(.bordered)

                Button {

                    onAdopt()

                    dismiss()

                } label: {

                    Label(
                        "采用结果",
                        systemImage:
                            "checkmark.circle"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .keyboardShortcut(
                    .defaultAction
                )
            }
            .padding(
                .horizontal,
                CosmosDesign.spacingL
            )
            .padding(
                .vertical,
                CosmosDesign.spacingM
            )


        case .failed:

            HStack {

                Button("关闭") {

                    dismiss()
                }

                Spacer()

                Button {

                    onRegenerate()

                } label: {

                    Label(
                        "重新执行",
                        systemImage:
                            "arrow.clockwise"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
            }
            .padding(
                .horizontal,
                CosmosDesign.spacingL
            )
            .padding(
                .vertical,
                CosmosDesign.spacingM
            )
        }
    }


    // MARK: - Status Badge

    private var executionStateBadge:
        some View {

        HStack(spacing: 6) {

            Circle()
                .fill(headerColor)
                .frame(
                    width: 6,
                    height: 6
                )

            Text(stateTitle)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(
            .horizontal,
            9
        )
        .padding(
            .vertical,
            5
        )
        .background(
            headerColor
                .opacity(0.08)
        )
        .clipShape(Capsule())
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

        VStack(spacing: 0) {

            HStack {

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text("要求修改")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(
                        "Revision Request"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()

                Button("取消") {

                    dismiss()
                }
            }
            .padding(20)


            Divider()


            VStack(
                alignment: .leading,
                spacing:
                    CosmosDesign.spacingM
            ) {

                Text("告诉 AI 需要修改什么")
                    .font(.headline)

                Text(
                    "例如：玩法太复杂，保留签到和抽奖，减少排行榜内容，并重新优化 Slogan。"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                TextEditor(
                    text: $feedback
                )
                .frame(
                    minHeight: 180
                )
                .padding(10)
                .background(
                    Color.primary
                        .opacity(0.025)
                )
                .clipShape(
                    RoundedRectangle(
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
            }
            .padding(20)


            Divider()


            HStack {

                Spacer()

                Button("取消") {

                    dismiss()
                }

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
                    .borderedProminent
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
            .padding(20)
        }
        .frame(
            minWidth: 560,
            minHeight: 420
        )
    }
}
