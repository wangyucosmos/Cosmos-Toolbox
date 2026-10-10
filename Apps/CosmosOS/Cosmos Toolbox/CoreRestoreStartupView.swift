import AppKit
import Combine
import SwiftUI

final class CoreRestoreStartupModel: ObservableObject {
    @Published private(set) var state = "checking"
    @Published private(set) var message:String?
    @Published private(set) var target:CoreRestoreTarget?
    private let configuration:ZhuowangStorePersistenceConfiguration
    init(configuration:ZhuowangStorePersistenceConfiguration) { self.configuration = configuration }
    func check() async {
        do {
            let target = try CoreRestoreTarget.resolve(configuration:configuration);self.target = target
            let service = CoreRestoreService(target:target)
            let result:Result<String,Error> = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos:.userInitiated).async {
                    do {
                        let status = try service.startup()
                        if status == "readyToLoad" { try service.activateCompleted();continuation.resume(returning:.success("restored")) }
                        else { continuation.resume(returning:.success(status)) }
                    } catch { continuation.resume(returning:.failure(error)) }
                }
            }
            switch result {
            case .success(let value):state = value;CoreRestoreRuntime.restoredInstallation = value == "restored"
            case .failure(let error):state = "blocked";message = error.localizedDescription
            }
        } catch { state = "blocked";message = error.localizedDescription }
    }
    func beginNew() async {
        guard state == "empty",let target else { return };state = "checking"
        let result:Result<Void,Error> = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos:.userInitiated).async {
                do { try CoreRestoreService(target:target).beginNewEnvironment();continuation.resume(returning:.success(())) }
                catch { continuation.resume(returning:.failure(error)) }
            }
        }
        switch result {
        case .success:CoreRestoreRuntime.restoredInstallation = false;state = "existing"
        case .failure(let error):state = "blocked";message = error.localizedDescription
        }
    }
    func rollback() async {
        guard state == "interrupted",let target else { return };state = "checking"
        let result:Result<Bool,Error> = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos:.userInitiated).async {
                do { continuation.resume(returning:.success(try CoreRestoreService(target:target).rollbackInterrupted())) }
                catch { continuation.resume(returning:.failure(error)) }
            }
        }
        switch result {
        case .success(true): await check()
        case .success(false):state = "blocked";message = "存在变化或归属不明的条目，无法安全回退；事务和数据保留，业务加载已阻止。"
        case .failure(let error):state = "blocked";message = error.localizedDescription
        }
    }
    func restored() { state = "restart" }
}

struct CoreRestoreStartupView:View {
    @StateObject private var model:CoreRestoreStartupModel
    let configuration:ZhuowangStorePersistenceConfiguration
    @State private var restoreBusy = false
    init(configuration:ZhuowangStorePersistenceConfiguration) {
        self.configuration = configuration
        _model = StateObject(wrappedValue:CoreRestoreStartupModel(configuration:configuration))
    }
    var body:some View {
        Group {
            if model.state == "existing" || model.state == "restored" {
                DashboardView(storePersistenceConfiguration:configuration)
            } else {
                ScrollView {
                    VStack(alignment:.leading,spacing:20) {
                        Text("Cosmos OS · 数据启动保护").font(.largeTitle.bold())
                        if model.state == "checking" { ProgressView("正在检查业务环境及恢复事务…") }
                        else if model.state == "empty" {
                            Text("尚未建立核心业务数据。可以先从备份恢复，或创建新环境；进入工作台后不支持覆盖恢复。")
                            CoreRestoreView(target:model.target,onFinished:{ model.restored() },onBusyChange:{ restoreBusy = $0 })
                            Divider()
                            Button("创建新环境并进入工作台") { Task { await model.beginNew() } }.disabled(restoreBusy)
                        } else if model.state == "interrupted" {
                            Text("发现未完成恢复，未加载业务 Store。可尝试安全回退已确认且未变化的本次数据；归属不明或变化的数据不会删除。")
                            Button("安全回退本次未完成恢复") { Task { await model.rollback() } }
                        } else if model.state == "restart" {
                            Text("恢复成功。请退出并重新打开 Cosmos OS；当前会话不加载业务 Store。")
                            Button("退出 Cosmos OS") { NSApplication.shared.terminate(nil) }
                        } else { Text(model.message ?? "数据状态无法确认，业务加载已阻止。") }
                    }.padding(28).frame(maxWidth:.infinity,alignment:.leading)
                }
            }
        }.task { if model.state == "checking" { await model.check() } }
    }
}
