import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

final class CoreBackupViewModel: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var status: String?
    @Published private(set) var result: CoreBackupResult?
    private let service: CoreBackupService
    init(source: CoreBackupSource) { service = CoreBackupService(source: source) }

    func run(url: URL, exporting: Bool) async {
        guard !busy else { return }
        busy = true; result = nil
        status = exporting ? "正在读取源数据、导出及校验…" : "正在校验备份…"
        let service = service
        let outcome: Result<CoreBackupResult, Error> = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do { continuation.resume(returning: .success(try exporting ? service.export(to: url) : CoreBackupService.verify(url))) }
                catch { continuation.resume(returning: .failure(error)) }
            }
        }
        switch outcome {
        case .success(let value): result = value; status = (exporting ? "导出成功。" : "") + value.summary
        case .failure(let error): status = "操作失败：" + error.localizedDescription
        }
        busy = false
    }
}

struct CoreBackupSettingsView: View {
    @StateObject private var model: CoreBackupViewModel
    let restoreTarget: CoreRestoreTarget?
    init(source: CoreBackupSource, restoreTarget: CoreRestoreTarget? = nil) {
        _model = StateObject(wrappedValue: CoreBackupViewModel(source: source)); self.restoreTarget = restoreTarget
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("设置").font(.largeTitle.bold())
                Text("核心数据备份").font(.title2)
                Text("手动导出核心元数据，或校验已有备份。校验只读备份包，不导入、不恢复业务数据。")
                GroupBox("包含范围") {
                    Text("Campaign（含资料与外部成果引用记录，不含原文件或网页）、Workspace / 省份配置；Workflow（含 Artifact 元数据、Run、Approval）；AI Provider / Connection / Tool / Route 非敏感配置；Prompt Vault；学习主题和记录；AI 工作台交接记录；个人项目（含进展及文件/链接引用元数据）。")
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
                GroupBox("不包含与安全排除") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(CoreBackupSource.exclusions, id: \.self) { Text($0) }
                        Text("不是完整换机恢复：产物实体、项目引用文件和外部资料不打包，登记路径仍依赖原文件。已保存的业务正文保留原文，请妥善保管备份。")
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
                Text("格式：Cosmos 核心元数据 ZIP V2（不压缩，兼容读取 V1；V1 未包含 Projects）。单源最多 16 MiB，包最多 128 MiB，清单最多 256 KiB。缺失主数据记为尚未建立，真实空库仍作为已建立数据保存。源错误或变化时中止，不以空数据替代。")
                    .font(.callout).foregroundStyle(.secondary)
                Text("一致性：读取前后检查文件修订，发布前逐源复读字节和修订；不是跨进程事务，不能保证外部进程在最终检查后不再写入。SHA-256 用于完整性检查，不是签名或加密。")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("导出核心数据备份", systemImage: "square.and.arrow.up") { chooseExport() }
                    Button("校验备份", systemImage: "checkmark.shield") { chooseVerify() }
                    if let result = model.result {
                        Button("在 Finder 中查看", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([result.url]) }
                    }
                }.disabled(model.busy)
                Divider()
                CoreRestoreView(target: restoreTarget)
                if model.busy { ProgressView() }
                if let status = model.status { Text(status).textSelection(.enabled).accessibilityIdentifier("core-backup-status") }
                if let result = model.result {
                    ForEach(result.manifest.sources, id: \.id) { item in
                        Text("\(item.id)：\(item.status == "missing" ? "尚未建立" : "已建立 · \(item.bytes) 字节")\(item.transformation == nil ? "" : " · 已安全转换")")
                    }
                }
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityIdentifier("core-backup-settings")
    }
    private func chooseExport() {
        let panel = NSSavePanel()
        panel.title = "导出核心数据备份（已有目标不会覆盖）"
        panel.allowedContentTypes = [.zip]; panel.canCreateDirectories = true
        let formatter = DateFormatter(); formatter.dateFormat = "yyyyMMdd-HHmmss"
        panel.nameFieldStringValue = "Cosmos-Core-\(formatter.string(from: Date())).zip"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.run(url: url, exporting: true) }
    }
    private func chooseVerify() {
        let panel = NSOpenPanel(); panel.title = "校验 Cosmos 核心元数据备份"
        panel.allowedContentTypes = [.zip]; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.run(url: url, exporting: false) }
    }
}
