import SwiftUI

/// In-memory task handoff and read-only local tool detection.
struct AIWorkspaceView: View {

    @StateObject private var model: AIWorkspaceViewModel
    private let autoDetect: Bool
    @StateObject private var preparation: AIWorkspaceTaskPreparation

    init(cache: AIWorkspaceResultCache, configuration: ZhuowangStorePersistenceConfiguration, autoDetect: Bool = false) {
        let reader = AIWorkspaceTaskContextReader(source: configuration.dataSource)
        _preparation = StateObject(wrappedValue: AIWorkspaceTaskPreparation(read: { try reader.read() }))
        _model = StateObject(wrappedValue: AIWorkspaceViewModel(cache: cache))
        self.autoDetect = autoDetect
    }

    /// Injectable model, for offscreen rendering and tests.
    init(model: AIWorkspaceViewModel, autoDetect: Bool = false) {
        _preparation = StateObject(wrappedValue: AIWorkspaceTaskPreparation(read: { AIWorkspaceTaskContext() }))
        _model = StateObject(wrappedValue: model)
        self.autoDetect = autoDetect
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CosmosDesign.spacingXL) {
                header
                AIWorkspaceTaskPreparationView(model: preparation)
                Divider()
                Text("本机工具与运行环境").font(.title2)
                notice
                VStack(spacing: CosmosDesign.spacingM) {
                    ForEach(AIWorkspaceToolID.allCases) { tool in
                        AIWorkspaceToolRow(
                            tool: tool,
                            result: model.snapshot?.results.first { $0.tool == tool },
                            isDetecting: model.isDetecting
                        )
                    }
                }
            }
            .padding(.horizontal, CosmosDesign.pagePadding)
            .padding(.vertical, CosmosDesign.spacingXXL)
            .frame(maxWidth: CosmosDesign.contentMaxWidth, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            preparation.refresh()
            if autoDetect, model.snapshot == nil { model.refresh() }
        }
        .onDisappear { model.cancel() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: CosmosDesign.spacingS) {
                Text("AI 工作台")
                    .font(.system(size: 32, weight: .semibold))
                Text("任务准备与提示词交接")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    model.refresh()
                } label: {
                    if model.isDetecting {
                        Label {
                            Text("正在检测…")
                        } icon: {
                            ProgressView().controlSize(.small)
                        }
                    } else {
                        Label(model.snapshot == nil ? "开始检测" : "重新检测", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(model.isDetecting)
                .accessibilityIdentifier("ai-workspace-detect")

                Text(timeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("ai-workspace-time")
            }
        }
    }

    private var timeText: String {
        guard let completed = model.snapshot?.completedAt else { return "尚未检测" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm:ss"
        return "最近检测：" + formatter.string(from: completed)
    }

    private var notice: some View {
        Label {
            Text("检测只说明这台 Mac 上有没有这个工具，并且 --version 能运行。它不代表已经登录、有额度、网络通畅或模型可用。Cosmos OS 不会安装、更新、登录，也不会读取密钥或调用 AI 服务。")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}


struct AIWorkspaceToolRow: View {

    let tool: AIWorkspaceToolID
    let result: AIWorkspaceToolResult?
    let isDetecting: Bool

    var body: some View {
        HStack(alignment: .top, spacing: CosmosDesign.spacingL) {
            Image(systemName: tool.symbol)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: CosmosDesign.spacingS) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tool.title).font(.headline)
                    if let version = result?.version {
                        Text(version)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    statusBadge
                }
                details
            }
        }
        .padding(CosmosDesign.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusMedium)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CosmosDesign.cornerRadiusMedium)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ai-workspace-row-\(tool.rawValue)")
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch result?.status {
        case .ready?:
            Label("可运行", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .warning?:
            Label("无法运行", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .missing?:
            Label("未找到", systemImage: "minus.circle.fill").foregroundStyle(.secondary)
        case nil:
            Label(isDetecting ? "检测中" : "未检测", systemImage: "circle.dashed").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var details: some View {
        if let result {
            if let line = result.versionLine, line != result.version {
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let path = result.path {
                VStack(alignment: .leading, spacing: 2) {
                    Text(path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    if let resolved = result.resolvedPath {
                        Text("实际位置：\(resolved)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    HStack(spacing: CosmosDesign.spacingS) {
                        if let source = result.source {
                            Text("来源：\(source.title)")
                        }
                        if result.isSystemShim {
                            Text("· 系统自带入口")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            if let failure = result.failure {
                VStack(alignment: .leading, spacing: 2) {
                    Text(failure.message)
                        .foregroundStyle(result.status == .warning ? Color.orange : Color.primary)
                    Text(failure.hint)
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(isDetecting ? "正在检测…" : "点击右上角“开始检测”。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
