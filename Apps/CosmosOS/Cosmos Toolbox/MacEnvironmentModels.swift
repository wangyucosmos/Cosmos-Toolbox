import Foundation

/// Each field retains its own availability; missing values never imply health.
nonisolated enum MacEnvironmentReading<Value: Equatable & Sendable>: Equatable, Sendable {
    case value(Value)
    case unknown(String)
    case failed(String)
    case notApplicable(String)
}

nonisolated struct MacEnvironmentDisk: Equatable, Sendable {
    let totalBytes: Int64
    let availableBytes: Int64
}

nonisolated struct MacEnvironmentBattery: Equatable, Sendable {
    let percentage: MacEnvironmentReading<Double>
    let power: MacEnvironmentReading<String>
    let charging: MacEnvironmentReading<Bool>
}

nonisolated struct MacEnvironmentSnapshot: Equatable, Sendable {
    let readAt: Date
    let systemVersion: MacEnvironmentReading<String>
    let hardwareModel: MacEnvironmentReading<String>
    let processor: MacEnvironmentReading<String>
    let architecture: MacEnvironmentReading<String>
    let physicalMemory: MacEnvironmentReading<UInt64>
    let memoryPressure: MacEnvironmentReading<String>
    let disk: MacEnvironmentReading<MacEnvironmentDisk>
    let battery: MacEnvironmentReading<MacEnvironmentBattery>
}

nonisolated enum MacEnvironmentFormat {
    static func binaryBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useGB, .useTB, .useMB, .useKB, .useBytes]
        return formatter.string(fromByteCount: Int64(clamping: bytes))
    }
    static func decimalBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        return formatter.string(fromByteCount: bytes)
    }
    static func percentage(current: Int, maximum: Int) -> MacEnvironmentReading<Double> {
        guard maximum > 0, current >= 0, current <= maximum else {
            return .failed("系统电量数值无效。")
        }
        return .value(Double(current) / Double(maximum) * 100)
    }
}
