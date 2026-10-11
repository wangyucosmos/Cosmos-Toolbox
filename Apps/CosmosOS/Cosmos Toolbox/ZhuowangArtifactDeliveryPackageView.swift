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
                .background(.bar)
            Divider()

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: CosmosDesign.spacingL
                ) {
                    summaryCard
                    candidateList
                    statusArea
                }
                .padding(CosmosDesign.spacingL)
            }

            Divider()
            footer
                .background(.bar)
        }
        .frame(
            minWidth: 760,
            idealWidth: 820,
            minHeight: 560,
            idealHeight: 640
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .modifier(CosmosMotionPolicy())
        .onAppear {
            refreshCandidates()
        }
    }


    // MARK: Header

    private var header: some View {
        CampaignUIHeader(
            icon: "archivebox",
            title: "导出 Campaign 交付包",
            subtitle: campaign.name
        ) {
            Button("关闭") {
                dismiss()
            }
            .buttonStyle(.glass)
            .disabled(isExporting)
        }
    }


    // MARK: Summary

    private var summaryCard: some View {
        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingM
        ) {
            HStack(spacing: CosmosDesign.spacingXL) {
                CampaignUIKeyValue(
                    title: "已选择",
                    value: "\(selectedGroupKeys.count) 项"
                )
                CampaignUIKeyValue(
                    title: "可导出",
                    value: "\(eligibleCandidates.count) 项"
                )
                CampaignUIKeyValue(
                    title: "暂不可用",
                    value: "\(candidates.count - eligibleCandidates.count) 项"
                )
            }

            CampaignUINotice(
                text: "只导出当前已采用、真实落盘且位于该 Campaign 正式 Workspace 内的文件。源文件、Workflow 和采用状态不会被修改。",
                icon: "lock.shield"
            )
        }
        .campaignUICardSurface()
    }


    // MARK: Selection

    private var candidateList: some View {
        CampaignUICard(
            title: "选择要导出的工作产物",
            icon: "checklist",
            trailing: {
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
        ) {
            if candidates.isEmpty {
                CosmosEmptyState(
                    icon: "archivebox.circle",
                    title: "当前没有工作产物",
                    detail: "只有 Workflow 中已保存的 Artifact 才会出现在这里。"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(candidates) { candidate in
                        candidateRow(candidate)
                    }
                }
            }
        }
    }


    private func candidateRow(
        _ candidate:
            ZhuowangArtifactDeliveryCandidate
    ) -> some View {

        let selected = selectedGroupKeys.contains(candidate.groupKey)

        return HStack(spacing: CosmosDesign.spacingM) {
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

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(candidate.name)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(candidate.stepTitle)

                    if let fileName = candidate.fileName {
                        Text("·")
                        Text(fileName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )

            if let version = candidate.version {
                CampaignUIVersionBadge(
                    version: version,
                    isCurrent: candidate.isEligible
                )
            } else {
                Text(candidate.versionText)
                    .foregroundStyle(.secondary)
            }

            CampaignUIStatusPill(
                text: candidate.fileStatusText,
                icon:
                    candidate.isEligible
                    ? "checkmark.circle.fill"
                    : "exclamationmark.circle",
                tone:
                    candidate.isEligible
                    ? .success
                    : .warning
            )
            .frame(maxWidth: 230, alignment: .trailing)
        }
        .padding(.horizontal, CosmosDesign.spacingM)
        .padding(.vertical, CosmosDesign.spacingS + 2)
        .background(
            selected
            ? Color.accentColor.opacity(0.08)
            : Color.primary.opacity(0.025),
            in: RoundedRectangle(
                cornerRadius: CosmosDesign.cornerRadiusMedium,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: CosmosDesign.cornerRadiusMedium,
                style: .continuous
            )
            .stroke(
                selected
                ? Color.accentColor.opacity(0.4)
                : Color.primary.opacity(0.05),
                lineWidth: 1
            )
        }
        .opacity(candidate.isEligible ? 1 : 0.72)
        .campaignUIAnimation(value: selected)
    }


    // MARK: Status / Footer

    @ViewBuilder
    private var statusArea: some View {
        if let errorMessage {
            CampaignUINotice(
                text: errorMessage,
                icon: "exclamationmark.triangle.fill",
                tone: .warning
            )
            .transition(.opacity)
        }

        if let completedArchiveURL {
            HStack(spacing: CosmosDesign.spacingM) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("交付包已完成")
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)

                    Text(
                        completedArchiveURL
                            .lastPathComponent
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }

                Spacer()

                Button("在 Finder 中显示") {
                    NSWorkspace.shared
                        .activateFileViewerSelecting(
                            [completedArchiveURL]
                        )
                }
                .buttonStyle(.glass)
            }
            .padding(CosmosDesign.spacingM)
            .background(
                Color.green.opacity(0.08),
                in: RoundedRectangle(
                    cornerRadius: CosmosDesign.cornerRadiusMedium,
                    style: .continuous
                )
            )
            .transition(.opacity)
        }
    }


    private var footer: some View {
        HStack(spacing: CosmosDesign.spacingM) {
            Label(
                "ZIP 内包含所选文件、交付清单.md 和 manifest.json。",
                systemImage: "shippingbox"
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
            .buttonStyle(.glassProminent)
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
