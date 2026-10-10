import SwiftUI

struct MacEnvironmentView: View {
    @ObservedObject var model: MacEnvironmentViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CosmosDesign.spacingXL) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mac 环境概览").font(.system(size: 32, weight: .semibold))
                        Text("只读设备与资源信息 · 不清理、不修改系统").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { model.refresh() } label: {
                        Label(model.isReading ? "正在读取…" : "刷新", systemImage: "arrow.clockwise")
                    }.disabled(model.isReading)
                }
                if let snapshot = model.snapshot {
                    Text("读取时间：\(snapshot.readAt.formatted(date: .numeric, time: .standard))").font(.caption).foregroundStyle(.secondary)
                    section("系统", source: "ProcessInfo / sysctl：硬件型号、处理器名称与硬件架构") {
                        row("系统版本", snapshot.systemVersion) { $0 }
                        row("硬件型号", snapshot.hardwareModel) { $0 }
                        row("芯片 / 处理器", snapshot.processor) { $0 }
                        row("硬件架构", snapshot.architecture) { $0 }
                    }
                    section("内存", source: "ProcessInfo.physicalMemory · 二进制单位（1 GiB = 2³⁰ 字节）；不推算应用占用") {
                        row("物理内存总量", snapshot.physicalMemory) { "\(MacEnvironmentFormat.binaryBytes($0))（\($0) 字节）" }
                        row("系统内存压力", snapshot.memoryPressure) { $0 }
                    }
                    section("磁盘", source: "用户主目录所在卷 · URL 卷容量 API；可用容量为 volumeAvailableCapacity，不含可清除空间估算。十进制单位（1 GB = 10⁹ 字节），不是目录大小。") {
                        row("卷容量", snapshot.disk) { "总量 \(MacEnvironmentFormat.decimalBytes($0.totalBytes)) · 可用 \(MacEnvironmentFormat.decimalBytes($0.availableBytes))" }
                    }
                    section("电池", source: "IOKit Power Sources · 只读取内置电池；电量为当前容量 / 满充容量。循环次数及健康最大容量本期未读取。") {
                        if case .value(let battery) = snapshot.battery {
                            row("电量", battery.percentage) { String(format: "%.1f%%", $0) }
                            row("供电", battery.power) { $0 }
                            row("充电", battery.charging) { $0 ? "正在充电" : "未充电" }
                        } else {
                            row("内置电池", snapshot.battery) { _ in "" }
                        }
                    }
                } else {
                    if model.isReading { ProgressView("正在读取系统信息…") }
                    else { Text("尚未读取。可手动刷新。").foregroundStyle(.secondary) }
                }
                Text("仅保存本次内存快照，无持续轮询、设备历史或上传。各项独立读取，未知与失败不会显示为正常。").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, CosmosDesign.pagePadding)
            .padding(.vertical, CosmosDesign.spacingXXL)
            .frame(maxWidth: CosmosDesign.contentMaxWidth, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task { model.loadIfNeeded() }
        .onDisappear { model.cancel() }
    }
    private func section<Content: View>(_ title: String, source: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2)
            content()
            Text(source).font(.caption).foregroundStyle(.secondary)
            Divider()
        }
    }
    private func row<T>(_ title: String, _ reading: MacEnvironmentReading<T>, format: (T) -> String) -> some View {
        HStack(alignment: .top) {
            Text(title).frame(width: 130, alignment: .leading)
            Group {
                switch reading {
                case .value(let value): Text(format(value))
                case .unknown(let reason): Text("未知：\(reason)").foregroundStyle(.secondary)
                case .failed(let reason): Text("读取失败：\(reason)").foregroundStyle(.orange)
                case .notApplicable(let reason): Text("不适用：\(reason)").foregroundStyle(.secondary)
                }
            }.textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}
