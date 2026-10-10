import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

final class CoreRestoreViewModel: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var plan: CoreRestorePlan?
    @Published private(set) var status: String?
    @Published private(set) var finished = false
    let target: CoreRestoreTarget?
    init(target:CoreRestoreTarget?) { self.target = target }

    func choose(_ url:URL) async {
        guard !busy, !finished else { return }
        busy = true; plan = nil; status = "正在完整校验备份及关联…"
        let result:Result<CoreRestorePlan,Error> = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos:.userInitiated).async {
                do { continuation.resume(returning:.success(try CoreRestoreService.prepare(url))) }
                catch { continuation.resume(returning:.failure(error)) }
            }
        }
        switch result {
        case .success(let value):plan = value;status = "校验通过；尚未写入。请查看实际恢复项和限制。"
        case .failure(let error):status = "校验失败："+error.localizedDescription
        }
        busy = false
    }
    func cancel() {
        guard !busy else { return }; plan = nil; status = "已取消，未写入任何恢复数据。"
    }
    func confirm(confirmed:Bool) async {
        guard confirmed, !busy, !finished, let plan else { return }
        guard let target else { status = "恢复目标或隔离配置不可用；未写入。"; return }
        busy = true;status = "正在再次核对目标并恢复；完成前业务加载保持关闭…"
        let result:Result<Void,Error> = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos:.userInitiated).async {
                do { try CoreRestoreService(target:target).restore(plan); continuation.resume(returning:.success(())) }
                catch { continuation.resume(returning:.failure(error)) }
            }
        }
        switch result {
        case .success:finished = true;status = "恢复成功。请退出并重新打开 Cosmos OS 后加载恢复数据；当前会话不能继续编辑。"
        case .failure(let error):status = "恢复未完成："+error.localizedDescription
        }
        busy = false
    }
}

struct CoreRestoreView: View {
    @StateObject private var model:CoreRestoreViewModel
    @State private var confirmed = false
    var onFinished:() -> Void = {}
    var onBusyChange:(Bool) -> Void = { _ in }
    init(target:CoreRestoreTarget?, onFinished:@escaping () -> Void = {}, onBusyChange:@escaping (Bool) -> Void = { _ in }) {
        _model = StateObject(wrappedValue:CoreRestoreViewModel(target:target));self.onFinished = onFinished;self.onBusyChange = onBusyChange
    }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("核心数据恢复 · 仅空环境").font(.title2)
            Text("仅支持从未建立业务数据的环境。已有空库、主文件、备份、写锁或已开始使用的环境都不会覆盖或合并。新安装可在进入工作台前恢复。")
            Button("选择备份并预览恢复范围",systemImage:"arrow.counterclockwise") {
                let panel = NSOpenPanel();panel.allowedContentTypes = [.zip];panel.canChooseDirectories = false;panel.allowsMultipleSelection = false
                guard panel.runModal() == .OK,let url = panel.url else { return }
                confirmed = false;Task { await model.choose(url) }
            }.disabled(model.busy || model.finished)
            if let plan = model.plan {
                Text("备份时间：\(plan.manifest.exportedAt.formatted()) · 格式 V\(plan.manifest.version)").font(.headline)
                ForEach(plan.manifest.sources,id:\.id) { source in
                    Text("\(source.id)：\(source.status == "missing" ? "尚未建立，不恢复" : "恢复 · \((plan.payloads[source.id]?.count ?? 0)) 字节 · \(plan.summaries[source.id] ?? "")")")
                }
                ForEach(plan.warnings,id:\.self) { Text($0).font(.callout).foregroundStyle(.secondary) }
                Text("恢复按当前安装的存储位置写入，不采用备份中的绝对路径作为目标。失败只回退仍能确认归属且未变化的本次数据；不明状态保留事务门控。不是跨进程原子事务。")
                    .font(.callout).foregroundStyle(.secondary)
                Toggle("我已核对实际恢复项与限制，确认仅向未建立的空环境写入元数据",isOn:$confirmed).disabled(model.busy || model.finished)
                HStack {
                    Button("确认恢复到空环境") { Task { await model.confirm(confirmed:confirmed);if model.finished { onFinished() } } }
                        .disabled(!confirmed || model.busy || model.finished || model.target == nil)
                    Button("取消") { confirmed = false;model.cancel() }.disabled(model.busy || model.finished)
                }
            }
            if model.busy { ProgressView() }
            if let status = model.status { Text(status).textSelection(.enabled).accessibilityIdentifier("core-restore-status") }
        }.accessibilityIdentifier("core-restore-view").onChange(of:model.busy) { _,value in onBusyChange(value) }
    }
}
