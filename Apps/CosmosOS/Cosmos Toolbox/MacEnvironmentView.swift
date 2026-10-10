import SwiftUI

struct MacEnvironmentView: View {
    @ObservedObject var model: MacEnvironmentViewModel
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                CosmosPageHeader("Mac 环境概览", subtitle: "查看这台 Mac 的设备与资源信息。",
                    info: "只读系统 API，不清理、不修改系统。仅保留本次内存快照，无轮询、设备历史或上传；未知与失败单独显示，不当作正常值。")
                if let snapshot = model.snapshot {
                    Text("读取时间：" + snapshot.readAt.formatted(date: .abbreviated, time: .standard)).font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], alignment: .leading, spacing: 16) {
                        panel("系统", icon: "desktopcomputer", info: "ProcessInfo / sysctl：硬件型号、处理器名称与硬件架构。") {
                            row("系统版本", snapshot.systemVersion) { $0 }; row("硬件型号", snapshot.hardwareModel) { $0 }
                            row("芯片 / 处理器", snapshot.processor) { $0 }; row("硬件架构", snapshot.architecture) { $0 }
                        }.cosmosEntrance(0)
                        panel("磁盘", icon: "internaldrive", info: "用户主目录所在卷；可用容量不含可清除空间估算。十进制单位（1 GB = 10⁹ 字节），不是目录大小。") {
                            if case .value(let disk) = snapshot.disk, disk.totalBytes > 0, disk.availableBytes >= 0, disk.availableBytes <= disk.totalBytes {
                                Gauge(value: Double(disk.availableBytes), in: 0...Double(disk.totalBytes)) { Text("可用容量") }
                                    currentValueLabel: { Text(MacEnvironmentFormat.decimalBytes(disk.availableBytes)).font(CosmosDesign.font(.metric)) }
                                    minimumValueLabel: { Text("0") } maximumValueLabel: { Text(MacEnvironmentFormat.decimalBytes(disk.totalBytes)) }
                                    .gaugeStyle(.accessoryLinearCapacity).tint(Color.accentColor)
                                Text("总容量 " + MacEnvironmentFormat.decimalBytes(disk.totalBytes)).font(CosmosDesign.font(.body)).foregroundStyle(.secondary)
                            } else { row("卷容量", snapshot.disk) { "总量 \(MacEnvironmentFormat.decimalBytes($0.totalBytes)) · 可用 \(MacEnvironmentFormat.decimalBytes($0.availableBytes))" } }
                        }.cosmosEntrance(1)
                        panel("内存", icon: "memorychip", info: "物理内存总量为 ProcessInfo.physicalMemory。二进制单位（1 GiB = 2³⁰ 字节）；未读取应用占用，不推算使用率。") {
                            row("物理内存", snapshot.physicalMemory) { MacEnvironmentFormat.binaryBytes($0) }
                            row("系统内存压力", snapshot.memoryPressure) { $0 }
                        }.cosmosEntrance(2)
                        panel("电池", icon: "battery.100", info: "IOKit Power Sources：只读内置电池。电量为当前容量 / 满充容量，未读取循环次数或健康最大容量。") {
                            if case .value(let battery) = snapshot.battery {
                                if case .value(let percentage) = battery.percentage {
                                    Gauge(value: percentage, in: 0...100) { Text("当前电量") } currentValueLabel: { Text(String(format: "%.1f%%", percentage)) }
                                        .gaugeStyle(.accessoryLinearCapacity).tint(Color.accentColor)
                                } else { row("电量", battery.percentage) { String(format: "%.1f%%", $0) } }
                                row("供电", battery.power) { $0 }; row("充电", battery.charging) { $0 ? "正在充电" : "未充电" }
                            } else { row("内置电池", snapshot.battery) { _ in "" } }
                        }.cosmosEntrance(3)
                    }
                } else if model.isReading { ProgressView("正在读取系统信息…") }
                else { CosmosEmptyState(icon: "desktopcomputer", title: "正在准备环境概览", detail: "只读本机信息，不进行清理或修改。") }
            }.padding(24).frame(maxWidth: CosmosDesign.contentMaxWidth, alignment: .leading).frame(maxWidth: .infinity)
        }.background(Color(nsColor: .windowBackgroundColor))
            .toolbar { ToolbarItem { CosmosGlassToolbarGroup { Button(model.isReading ? "正在读取…" : "刷新", systemImage: "arrow.clockwise") { model.refresh() }.disabled(model.isReading) } } }
            .task { if await CosmosDesign.beginPageLoad(reduced: preferences.reducesMotion(system: systemMotion)) { model.loadIfNeeded() } }
            .onDisappear { model.cancel() }
    }
    private func panel<Content: View>(_ title: String, icon: String, info: String, @ViewBuilder content: () -> Content) -> some View {
        CosmosContentPanel {
            HStack { Label(title, systemImage: icon).font(CosmosDesign.font(.section)); Spacer(); CosmosInfoButton(text: info) }
            content()
        }
    }
    private func row<T>(_ title: String, _ reading: MacEnvironmentReading<T>, format: (T) -> String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
            Group {
                switch reading {
                case .value(let value): Text(format(value))
                case .unknown(let reason): Text("未知：\(reason)").foregroundStyle(.secondary)
                case .failed(let reason): Text("读取失败：\(reason)").foregroundStyle(.orange)
                case .notApplicable(let reason): Text("不适用：\(reason)").foregroundStyle(.secondary)
                }
            }.font(CosmosDesign.font(.body)).textSelection(.enabled)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
