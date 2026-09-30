import SwiftUI
import AppKit
import UniformTypeIdentifiers


// MARK: - Delivery Package Selection

struct ZhuowangArtifactDeliveryPackageView: View {

    let campaign: ZhuowangCampaign
    let provinceName: String?
    let campaignWorkspaceURL: URL
    let snapshotProvider:
        ZhuowangArtifactDeliveryPackageService.SnapshotProvider

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var candidates: [
        ZhuowangArtifactDeliveryCandidate
    ] = []

    @State
    private var selectedGroupKeys = Set<String>()

    @State
    private var errorMessage: String?

    @State
    private var completedArchiveURL: URL?

    @State
    private var isExporting = false

    private let service =
        ZhuowangArtifactDeliveryPackageService()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            VStack(
                alignment: .leading,
                spacing: CosmosDesign.spacingM
            ) {
                explanation
                selectionControls
                candidateList
                statusArea
            }
            .padding(CosmosDesign.spacingL)

            Divider()
            footer
        }
        .frame(
            minWidth: 760,
            idealWidth: 820,
            minHeight: 560,
            idealHeight: 620
        )
        .onAppear {
            refreshCandidates()
        }
    }


    // MARK: Header

    private var header: some View {
        HStack(spacing: CosmosDesign.spacingM) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
                .fill(
                    Color.accentColor.opacity(0.09)
                )
                .frame(width: 42, height: 42)

                Image(systemName: "archivebox")
                    .font(
                        .system(
                            size: 18,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(.tint)
            }

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text("导出 Campaign 交付包")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(campaign.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("关闭") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .disabled(isExporting)
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


    private var explanation: some View {
        Text(
            "只导出当前已采用、真实落盘且位于该 Campaign 正式 Workspace 内的文件。源文件、Workflow 和采用状态不会被修改。"
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(
            horizontal: false,
            vertical: true
        )
    }


    // MARK: Selection

    private var selectionControls: some View {
        HStack(spacing: CosmosDesign.spacingM) {
            Text(
                "已选择 \(selectedGroupKeys.count) / \(eligibleCandidates.count) 项"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            Button(
                allEligibleSelected
                ? "取消全选"
                : "全选可用项"
            ) {
                if allEligibleSelected {
                    selectedGroupKeys.removeAll()
                } else {
                    selectedGroupKeys = Set(
                        eligibleCandidates.map(\.groupKey)
                    )
                }
            }
            .buttonStyle(.borderless)
            .disabled(
                eligibleCandidates.isEmpty
                    || isExporting
            )

            Button("刷新状态") {
                refreshCandidates()
            }
            .buttonStyle(.borderless)
            .disabled(isExporting)
        }
    }


    private var candidateList: some View {
        Group {
            if candidates.isEmpty {
                VStack(spacing: CosmosDesign.spacingM) {
                    Image(
                        systemName:
                            "archivebox.circle"
                    )
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)

                    Text("当前没有工作产物")
                        .font(.headline)

                    Text(
                        "只有 Workflow 中已保存的 Artifact 才会出现在这里。"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            } else {
                VStack(spacing: 0) {
                    candidateHeader
                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(candidates) {
                                candidate in

                                candidateRow(candidate)
                                Divider()
                                    .padding(.leading, 42)
                            }
                        }
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(
            Color.primary.opacity(0.018)
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
                Color.primary.opacity(0.06),
                lineWidth: 1
            )
        }
    }


    private var candidateHeader: some View {
        HStack(spacing: CosmosDesign.spacingM) {
            Color.clear
                .frame(width: 18)

            Text("步骤")
                .frame(
                    width: 120,
                    alignment: .leading
                )

            Text("工作产物")
                .frame(
                    minWidth: 170,
                    maxWidth: .infinity,
                    alignment: .leading
                )

            Text("采用版本")
                .frame(
                    width: 70,
                    alignment: .leading
                )

            Text("文件状态")
                .frame(
                    width: 220,
                    alignment: .leading
                )
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(
            .horizontal,
            CosmosDesign.spacingM
        )
        .padding(
            .vertical,
            CosmosDesign.spacingS
        )
    }


    private func candidateRow(
        _ candidate:
            ZhuowangArtifactDeliveryCandidate
    ) -> some View {

        HStack(spacing: CosmosDesign.spacingM) {
            Toggle(
                "",
                isOn: Binding(
                    get: {
                        selectedGroupKeys.contains(
                            candidate.groupKey
                        )
                    },
                    set: { selected in
                        if selected {
                            selectedGroupKeys.insert(
                                candidate.groupKey
                            )
                        } else {
                            selectedGroupKeys.remove(
                                candidate.groupKey
                            )
                        }
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(.checkbox)
            .frame(width: 18)
            .disabled(
                !candidate.isEligible
                    || isExporting
            )

            Text(candidate.stepTitle)
                .frame(
                    width: 120,
                    alignment: .leading
                )
                .lineLimit(2)

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(candidate.name)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let fileName = candidate.fileName {
                    Text(fileName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(
                minWidth: 170,
                maxWidth: .infinity,
                alignment: .leading
            )

            Text(candidate.versionText)
                .frame(
                    width: 70,
                    alignment: .leading
                )

            Label(
                candidate.fileStatusText,
                systemImage:
                    candidate.isEligible
                    ? "checkmark.circle.fill"
                    : "exclamationmark.circle"
            )
            .font(.caption)
            .foregroundStyle(
                candidate.isEligible
                ? Color.green
                : Color.orange
            )
            .frame(
                width: 220,
                alignment: .leading
            )
            .lineLimit(2)
        }
        .padding(
            .horizontal,
            CosmosDesign.spacingM
        )
        .padding(
            .vertical,
            CosmosDesign.spacingS
        )
    }


    // MARK: Status / Footer

    @ViewBuilder
    private var statusArea: some View {
        if let errorMessage {
            Label(
                errorMessage,
                systemImage:
                    "exclamationmark.triangle.fill"
            )
            .font(.callout)
            .foregroundStyle(.orange)
            .textSelection(.enabled)
        }

        if let completedArchiveURL {
            HStack(spacing: CosmosDesign.spacingM) {
                Label(
                    "交付包已完成",
                    systemImage:
                        "checkmark.circle.fill"
                )
                .font(.callout)
                .foregroundStyle(.green)

                Text(
                    completedArchiveURL
                        .lastPathComponent
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Spacer()

                Button("在 Finder 中显示") {
                    NSWorkspace.shared
                        .activateFileViewerSelecting(
                            [completedArchiveURL]
                        )
                }
                .buttonStyle(.bordered)
            }
        }
    }


    private var footer: some View {
        HStack(spacing: CosmosDesign.spacingM) {
            Text(
                "ZIP 内包含所选文件、交付清单.md 和 manifest.json。"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            if isExporting {
                ProgressView()
                    .controlSize(.small)
            }

            Button("选择位置并导出") {
                chooseDestinationAndExport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                selectedGroupKeys.isEmpty
                    || isExporting
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


    private var eligibleCandidates: [
        ZhuowangArtifactDeliveryCandidate
    ] {
        candidates.filter(\.isEligible)
    }


    private var allEligibleSelected: Bool {
        !eligibleCandidates.isEmpty
            && Set(
                eligibleCandidates.map(\.groupKey)
            ) == selectedGroupKeys
    }


    // MARK: Actions

    private func refreshCandidates() {
        candidates = service.candidates(
            snapshot: snapshotProvider(),
            campaignWorkspaceURL:
                campaignWorkspaceURL
        )

        let eligibleKeys = Set(
            candidates
                .filter(\.isEligible)
                .map(\.groupKey)
        )

        selectedGroupKeys.formIntersection(
            eligibleKeys
        )
    }


    private func chooseDestinationAndExport() {
        errorMessage = nil
        completedArchiveURL = nil

        let panel = NSSavePanel()
        panel.title = "保存 Campaign 交付包"
        panel.prompt = "导出"
        panel.nameFieldStringValue =
            defaultArchiveName
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK,
              let destinationURL = panel.url
        else {
            return
        }

        isExporting = true
        defer {
            isExporting = false
        }

        do {
            let result = try service.export(
                request:
                    ZhuowangArtifactDeliveryRequest(
                        campaign: campaign,
                        provinceName:
                            provinceName,
                        campaignWorkspaceURL:
                            campaignWorkspaceURL,
                        selections:
                            currentSelections,
                        destinationURL:
                            destinationURL
                    ),
                snapshotProvider:
                    snapshotProvider
            )

            completedArchiveURL =
                result.archiveURL
            refreshCandidates()
        } catch {
            errorMessage = error.localizedDescription
            refreshCandidates()
        }
    }


    private var defaultArchiveName: String {
        let cleanName = campaign.name
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .replacingOccurrences(
                of: "/",
                with: "_"
            )
            .replacingOccurrences(
                of: ":",
                with: "_"
            )

        return "\(cleanName.isEmpty ? "Campaign" : cleanName)_交付包.zip"
    }


    private var currentSelections:
        Set<ZhuowangArtifactDeliverySelection> {

        Set(
            candidates.compactMap { candidate in
                guard selectedGroupKeys.contains(
                    candidate.groupKey
                ),
                let artifactID = candidate.artifactID
                else {
                    return nil
                }

                return ZhuowangArtifactDeliverySelection(
                    groupKey: candidate.groupKey,
                    artifactID: artifactID
                )
            }
        )
    }
}
