import AppKit
import SwiftUI
import XCTest
import IOKit.ps
@testable import Cosmos_Toolbox

@MainActor
final class MacEnvironmentTests: XCTestCase {
    private func fixture(_ name: String = "Fixture") -> MacEnvironmentSnapshot {
        MacEnvironmentService(model: { name }, processor: { "Processor" }, architecture: { "arm64" },
            disk: { .init(totalBytes: 1000, availableBytes: 400) }, battery: { .notApplicable("无内置电池") },
            version: { "macOS Fixture" }, memory: { 16 * 1024 * 1024 * 1024 }).read()
    }
    func testCapacityAndUnitConversions() {
        XCTAssertEqual(MacEnvironmentFormat.percentage(current: 40, maximum: 80), .value(50))
        XCTAssertEqual(MacEnvironmentFormat.percentage(current: 0, maximum: 100), .value(0))
        XCTAssertEqual(MacEnvironmentFormat.percentage(current: 100, maximum: 100), .value(100))
        for (current, maximum) in [(-1, 100), (101, 100), (0, 0)] {
            guard case .failed = MacEnvironmentFormat.percentage(current: current, maximum: maximum) else { return XCTFail("invalid capacity accepted") }
        }
        let binary = ByteCountFormatter(); binary.countStyle = .binary
        binary.allowedUnits = [.useGB, .useTB, .useMB, .useKB, .useBytes]
        XCTAssertEqual(MacEnvironmentFormat.binaryBytes(16 * 1024 * 1024 * 1024), binary.string(fromByteCount: 16 * 1024 * 1024 * 1024))
        let decimal = ByteCountFormatter(); decimal.countStyle = .decimal
        XCTAssertEqual(MacEnvironmentFormat.decimalBytes(1_000_000_000), decimal.string(fromByteCount: 1_000_000_000))
    }
    func testNoBatteryAndUPSNotApplicable() {
        XCTAssertEqual(MacEnvironmentService.parseBattery([]), .notApplicable("设备未报告内置电池。"))
        XCTAssertEqual(MacEnvironmentService.parseBattery([[kIOPSTypeKey: kIOPSUPSType]]), .notApplicable("设备未报告内置电池。"))
        XCTAssertEqual(MacEnvironmentService.parseBattery([[kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: false]]), .notApplicable("系统报告内置电池未安装。"))
    }
    func testBatteryUnknownFailureAndIndependentFields() {
        guard case .failed = MacEnvironmentService.parseBattery([[:]]) else { return XCTFail() }
        let source: [String: Any] = [kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: true,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue, kIOPSIsChargingKey: false]
        guard case .value(let value) = MacEnvironmentService.parseBattery([source]) else { return XCTFail() }
        guard case .unknown = value.percentage else { return XCTFail() }
        XCTAssertEqual(value.power, .value("外接电源")); XCTAssertEqual(value.charging, .value(false))
        var invalid = source; invalid[kIOPSCurrentCapacityKey] = 200; invalid[kIOPSMaxCapacityKey] = 100
        guard case .value(let battery) = MacEnvironmentService.parseBattery([invalid]), case .failed = battery.percentage else { return XCTFail() }
        XCTAssertEqual(battery.power, .value("外接电源"))
        guard case .failed = MacEnvironmentService.parseBattery([source, source]) else { return XCTFail() }
    }
    func testValidBatteryAndUnknownSupply() {
        let source: [String: Any] = [kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: true,
            kIOPSCurrentCapacityKey: 30, kIOPSMaxCapacityKey: 60]
        guard case .value(let value) = MacEnvironmentService.parseBattery([source]) else { return XCTFail() }
        XCTAssertEqual(value.percentage, .value(50))
        guard case .unknown = value.power, case .unknown = value.charging else { return XCTFail() }
    }
    func testSingleFailureDoesNotHideOtherFields() {
        let value = MacEnvironmentService(model: { throw MacEnvironmentService.ReadError.invalid("model denied") },
            processor: { "CPU" }, architecture: { "arm64" }, disk: { throw MacEnvironmentService.ReadError.invalid("volume denied") },
            battery: { .failed("power denied") }, version: { "Version" }, memory: { 4096 }).read()
        XCTAssertEqual(value.hardwareModel, .failed("model denied"))
        XCTAssertEqual(value.disk, .failed("volume denied")); XCTAssertEqual(value.battery, .failed("power denied"))
        XCTAssertEqual(value.physicalMemory, .value(4096)); XCTAssertEqual(value.processor, .value("CPU"))
        XCTAssertEqual(value.systemVersion, .value("Version"))
        guard case .unknown = value.memoryPressure else { return XCTFail() }
    }
    func testEmptyAndInvalidMemoryAreNotNormal() {
        let value = MacEnvironmentService(model: { " " }, memory: { 0 }).read()
        guard case .failed = value.hardwareModel, case .failed = value.physicalMemory else { return XCTFail() }
    }

    private actor Gate {
        var pending: [Int: CheckedContinuation<MacEnvironmentSnapshot, Never>] = [:]
        var started: [Int: CheckedContinuation<Void, Never>] = [:]
        var count = 0
        func read() async -> MacEnvironmentSnapshot {
            count += 1; let index = count
            return await withCheckedContinuation { continuation in
                pending[index] = continuation; started.removeValue(forKey: index)?.resume()
            }
        }
        func wait(_ index: Int) async {
            if pending[index] != nil { return }
            await withCheckedContinuation { started[index] = $0 }
        }
        func finish(_ index: Int, _ value: MacEnvironmentSnapshot) { pending.removeValue(forKey: index)?.resume(returning: value) }
    }
    private func settle() async { for _ in 0..<40 { await Task.yield() } }
    func testRepeatedRefreshAndFirstVisitOnly() async {
        let gate = Gate(), value = fixture()
        let model = MacEnvironmentViewModel(read: { await gate.read() })
        model.loadIfNeeded(); model.refresh(); model.loadIfNeeded()
        await gate.wait(1)
        let count = await gate.count; XCTAssertEqual(count, 1)
        await gate.finish(1, value); await settle()
        XCTAssertEqual(model.snapshot, value); XCTAssertFalse(model.isReading)
        model.loadIfNeeded(); await settle()
        let after = await gate.count; XCTAssertEqual(after, 1)
        model.refresh(); await gate.wait(2)
        await gate.finish(2, value); await settle()
        XCTAssertFalse(model.isReading)
    }
    func testCancelledLateResultCannotReplaceNewResult() async {
        let gate = Gate(), old = fixture("old"), new = fixture("new")
        let model = MacEnvironmentViewModel(read: { await gate.read() })
        model.refresh(); await gate.wait(1); model.cancel()
        XCTAssertFalse(model.isReading); XCTAssertNil(model.snapshot)
        model.refresh(); await gate.wait(2)
        await gate.finish(2, new); await settle()
        XCTAssertEqual(model.snapshot, new)
        await gate.finish(1, old); await settle()
        XCTAssertEqual(model.snapshot, new); XCTAssertFalse(model.isReading)
    }
    func testCancelledReadRetainsLastSnapshot() async {
        let gate = Gate(), value = fixture()
        let model = MacEnvironmentViewModel(read: { await gate.read() })
        model.refresh(); await gate.wait(1); await gate.finish(1, value); await settle()
        model.refresh(); await gate.wait(2); model.cancel()
        await gate.finish(2, fixture("late")); await settle()
        XCTAssertEqual(model.snapshot, value); XCTAssertFalse(model.isReading)
    }
    func testLiveReadingMatchesSameScopeOfficialAPIsWithoutWritingDefaults() async throws {
        let before = UserDefaults.standard.dictionaryRepresentation()
        let service = MacEnvironmentService(), snapshot = await service.readInBackground()
        XCTAssertEqual(snapshot.physicalMemory, .value(ProcessInfo.processInfo.physicalMemory))
        XCTAssertEqual(snapshot.hardwareModel, .value(try service.model()))
        XCTAssertEqual(snapshot.processor, .value(try service.processor()))
        XCTAssertEqual(snapshot.architecture, .value(try service.architecture()))
        let volume = try FileManager.default.homeDirectoryForCurrentUser.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        guard case .value(let disk) = snapshot.disk else { return XCTFail("live volume unavailable") }
        XCTAssertEqual(disk.totalBytes, Int64(try XCTUnwrap(volume.volumeTotalCapacity)))
        // Available space can change between system reads; compare with a 64 MiB tolerance.
        XCTAssertLessThanOrEqual(abs(disk.availableBytes - Int64(try XCTUnwrap(volume.volumeAvailableCapacity))), 64 * 1024 * 1024)
        let info = try XCTUnwrap(IOPSCopyPowerSourcesInfo()?.takeRetainedValue())
        let sources = try XCTUnwrap(IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef])
        let battery = sources.compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
            .first { ($0[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType }
        if let battery, let current = battery[kIOPSCurrentCapacityKey] as? Int, let max = battery[kIOPSMaxCapacityKey] as? Int,
           case .value(let value) = snapshot.battery, case .value(let percentage) = value.percentage {
            XCTAssertEqual(percentage, Double(current) / Double(max) * 100, accuracy: 1)
        } else if battery == nil { guard case .notApplicable = snapshot.battery else { return XCTFail() } }
        XCTAssertTrue(NSDictionary(dictionary: before).isEqual(to: UserDefaults.standard.dictionaryRepresentation()))
        let report: [String: Any] = ["system": String(describing: snapshot.systemVersion), "model": String(describing: snapshot.hardwareModel),
            "processor": String(describing: snapshot.processor), "architecture": String(describing: snapshot.architecture),
            "memory": ProcessInfo.processInfo.physicalMemory, "diskTotal": disk.totalBytes, "diskAvailable": disk.availableBytes,
            "battery": String(describing: snapshot.battery), "sameScopeComparison": "passed", "defaultsUnchanged": true]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: "/private/tmp/CosmosMacEnvironment-live.json"))
    }
    func testReadOnlyViewRendersWithoutPersistence() async throws {
        let value = fixture(), model = MacEnvironmentViewModel(read: { value })
        model.refresh(); await settle()
        let before = UserDefaults.standard.dictionaryRepresentation()
        let view = NSHostingView(rootView: MacEnvironmentView(model: model))
        view.frame = NSRect(x: 0, y: 0, width: 1050, height: 1000); view.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(view.fittingSize.height, 0)
        XCTAssertTrue(NSDictionary(dictionary: before).isEqual(to: UserDefaults.standard.dictionaryRepresentation()))
    }
}
