import Foundation
import Darwin
import IOKit.ps

/// Official read-only system APIs. No subprocesses, directory enumeration or stores.
nonisolated struct MacEnvironmentService: Sendable {
    typealias TextRead = @Sendable () throws -> String
    let model: TextRead
    let processor: TextRead
    let architecture: TextRead
    let disk: @Sendable () throws -> MacEnvironmentDisk
    let battery: @Sendable () -> MacEnvironmentReading<MacEnvironmentBattery>
    let version: @Sendable () -> String
    let memory: @Sendable () -> UInt64

    init(model: @escaping TextRead = { try Self.sysctlText("hw.model") },
         processor: @escaping TextRead = { try Self.sysctlText("machdep.cpu.brand_string") },
         architecture: @escaping TextRead = {
             var flag: Int32 = 0
             var size = MemoryLayout<Int32>.size
             if sysctlbyname("hw.optional.arm64", &flag, &size, nil, 0) == 0, flag == 1 { return "arm64" }
             return try Self.sysctlText("hw.machine")
         },
         disk: @escaping @Sendable () throws -> MacEnvironmentDisk = {
             let values = try FileManager.default.homeDirectoryForCurrentUser.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
             guard let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity,
                   total > 0, available >= 0, available <= total else {
                 throw ReadError.invalid("主目录所在卷未返回有效容量。")
             }
             return MacEnvironmentDisk(totalBytes: Int64(total), availableBytes: Int64(available))
         },
         battery: @escaping @Sendable () -> MacEnvironmentReading<MacEnvironmentBattery> = { Self.readBattery() },
         version: @escaping @Sendable () -> String = {
             let v = ProcessInfo.processInfo.operatingSystemVersion
             return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
         },
         memory: @escaping @Sendable () -> UInt64 = { ProcessInfo.processInfo.physicalMemory }) {
        self.model = model; self.processor = processor; self.architecture = architecture
        self.disk = disk; self.battery = battery; self.version = version; self.memory = memory
    }

    func read() -> MacEnvironmentSnapshot {
        let physical = memory()
        return MacEnvironmentSnapshot(readAt: Date(), systemVersion: .value(version()),
            hardwareModel: text(model), processor: text(processor), architecture: text(architecture),
            physicalMemory: physical > 0 ? .value(physical) : .failed("系统未返回有效物理内存总量。"),
            memoryPressure: .unknown("本期未读取可靠的当前系统内存压力，不推算或评估。"),
            disk: result(disk), battery: battery())
    }

    func readInBackground() async -> MacEnvironmentSnapshot {
        await Task.detached(priority: .userInitiated) { read() }.value
    }

    private func text(_ read: TextRead) -> MacEnvironmentReading<String> {
        result {
            let value = try read()
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ReadError.invalid("系统返回空值。") }
            return value
        }
    }
    private func result<T>(_ read: () throws -> T) -> MacEnvironmentReading<T> {
        do { return .value(try read()) }
        catch { return .failed(error.localizedDescription) }
    }
    enum ReadError: LocalizedError {
        case invalid(String)
        var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
    }
    private static func sysctlText(_ key: String) throws -> String {
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0, size <= 4096 else {
            throw ReadError.invalid("系统字段 \(key) 读取失败。")
        }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(key, &bytes, &size, nil, 0) == 0 else { throw ReadError.invalid("系统字段 \(key) 读取失败。") }
        guard let value = String(bytes: bytes.prefix(size).prefix { $0 != 0 }, encoding: .utf8) else {
            throw ReadError.invalid("系统字段 \(key) 编码无效。")
        }
        return value
    }

    private static func readBattery() -> MacEnvironmentReading<MacEnvironmentBattery> {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return .failed("IOKit 电源信息读取失败。")
        }
        var descriptions: [[String: Any]] = []
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
                return .failed("IOKit 电源描述读取失败，无法确定是否有内置电池。")
            }
            descriptions.append(description)
        }
        return parseBattery(descriptions)
    }

    /// Only the internal battery is relevant; a connected UPS is not a Mac battery.
    static func parseBattery(_ sources: [[String: Any]]) -> MacEnvironmentReading<MacEnvironmentBattery> {
        guard sources.allSatisfy({ $0[kIOPSTypeKey] is String }) else {
            return .failed("电源类型缺失，无法确定是否有内置电池。")
        }
        let internalSources = sources.filter { ($0[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType }
        guard !internalSources.isEmpty else { return .notApplicable("设备未报告内置电池。") }
        guard internalSources.count == 1 else { return .failed("系统报告多个内置电池，未合并读数。") }
        let source = internalSources[0]
        guard let present = source[kIOPSIsPresentKey] as? Bool else { return .failed("内置电池存在状态未知。") }
        guard present else { return .notApplicable("系统报告内置电池未安装。") }
        let percentage: MacEnvironmentReading<Double>
        if let current = source[kIOPSCurrentCapacityKey] as? Int, let maximum = source[kIOPSMaxCapacityKey] as? Int {
            percentage = MacEnvironmentFormat.percentage(current: current, maximum: maximum)
        } else { percentage = .unknown("系统未提供电量容量字段。") }
        let power: MacEnvironmentReading<String>
        switch source[kIOPSPowerSourceStateKey] as? String {
        case kIOPSACPowerValue: power = .value("外接电源")
        case kIOPSBatteryPowerValue: power = .value("电池供电")
        case kIOPSOffLineValue: power = .value("离线")
        default: power = .unknown("系统未提供可识别的供电状态。")
        }
        let charging: MacEnvironmentReading<Bool> = (source[kIOPSIsChargingKey] as? Bool).map { .value($0) } ?? .unknown("系统未提供充电状态。")
        return .value(MacEnvironmentBattery(percentage: percentage, power: power, charging: charging))
    }
}
