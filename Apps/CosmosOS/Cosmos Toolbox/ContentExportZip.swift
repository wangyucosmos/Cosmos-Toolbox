import Foundation

/// 内容导出专用的最小 ZIP 编解码（不压缩、UTF-8 名称标志、无额外字段、无注释）。
/// 与核心备份的 `CoreBackupArchive` 相互独立：路径集合不同，核心备份校验 / 恢复会拒绝本格式。
/// 解码只在内存中解析并校验，从不解压到磁盘。
nonisolated enum ContentExportZip {
    static let maxEntries = 60_000
    static let maxTotalBytes = 256 * 1024 * 1024
    private static let externalAttributes: UInt32 = 0x81A4_0000      // 0100644 << 16

    private static let table: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 { crc = crc & 1 == 0 ? crc >> 1 : (crc >> 1) ^ 0xedb8_8320 }
        return crc
    }
    static func crc32(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { buffer in
            var value = UInt32.max
            for byte in buffer { value = (value >> 8) ^ table[Int((value ^ UInt32(byte)) & 255)] }
            return value ^ UInt32.max
        }
    }

    private static func put(_ number: UInt64, bytes: Int, to data: inout Data) {
        for index in 0..<bytes { data.append(UInt8(truncatingIfNeeded: number >> (8 * UInt64(index)))) }
    }
    private static func dosStamp(_ date: Date) -> (time: UInt16, date: UInt16) {
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max(1980, min(2107, parts.year ?? 1980))
        let time = UInt16(((parts.hour ?? 0) << 11) | ((parts.minute ?? 0) << 5) | ((parts.second ?? 0) / 2))
        let day = UInt16(((year - 1980) << 9) | ((parts.month ?? 1) << 5) | (parts.day ?? 1))
        return (time, day)
    }

    static func encode(_ entries: [(path: String, data: Data)], date: Date) throws -> Data {
        guard entries.count <= maxEntries else { throw ContentExportError.tooLarge("条目数超过 \(maxEntries)") }
        var seen = Set<String>()
        var total = 0
        for entry in entries {
            guard ContentExportFileName.isSafeArchivePath(entry.path) else {
                throw ContentExportError.buildFailed("包内路径不安全：\(entry.path)")
            }
            guard seen.insert(entry.path.lowercased()).inserted else {
                throw ContentExportError.buildFailed("包内路径重复（忽略大小写）：\(entry.path)")
            }
            total += entry.data.count
            guard total <= maxTotalBytes, entry.data.count < 0xFFFF_FFFF else {
                throw ContentExportError.tooLarge("总大小超过 \(maxTotalBytes / 1024 / 1024) MiB")
            }
        }
        let stamp = dosStamp(date)
        var archive = Data(), central = Data()
        for entry in entries {
            let name = Data(entry.path.utf8), offset = UInt64(archive.count), crc = UInt64(crc32(entry.data))
            let size = UInt64(entry.data.count)
            for (value, count) in [(UInt64(0x0403_4b50), 4), (20, 2), (0x0800, 2), (0, 2), (UInt64(stamp.time), 2),
                                   (UInt64(stamp.date), 2), (crc, 4), (size, 4), (size, 4), (UInt64(name.count), 2), (0, 2)] {
                put(value, bytes: count, to: &archive)
            }
            archive.append(name); archive.append(entry.data)
            for (value, count) in [(UInt64(0x0201_4b50), 4), (0x0314, 2), (20, 2), (0x0800, 2), (0, 2), (UInt64(stamp.time), 2),
                                   (UInt64(stamp.date), 2), (crc, 4), (size, 4), (size, 4), (UInt64(name.count), 2), (0, 2),
                                   (0, 2), (0, 2), (0, 2), (UInt64(externalAttributes), 4), (offset, 4)] {
                put(value, bytes: count, to: &central)
            }
            central.append(name)
            guard archive.count < 0xFFFF_FFFF else { throw ContentExportError.tooLarge("ZIP 超过 4 GiB") }
        }
        let centralOffset = UInt64(archive.count)
        archive.append(central)
        for (value, count) in [(UInt64(0x0605_4b50), 4), (0, 2), (0, 2), (UInt64(entries.count), 2), (UInt64(entries.count), 2),
                               (UInt64(central.count), 4), (centralOffset, 4), (0, 2)] {
            put(value, bytes: count, to: &archive)
        }
        return archive
    }

    /// 严格解析 `encode` 生成的包；任何偏差（压缩、额外字段、注释、路径、CRC、重叠）都抛错。
    static func decode(_ data: Data) throws -> [(path: String, data: Data)] {
        func reject(_ reason: String) -> ContentExportError { .verifyFailed("ZIP 结构无效（\(reason)）") }
        let bytes = [UInt8](data)
        /// 越界读取返回 nil；所有比较都经由 `expect`，nil 一律视为不匹配。
        func number(_ offset: Int, _ count: Int) -> Int? {
            guard offset >= 0, count <= 4, offset <= bytes.count - count else { return nil }
            var value = 0
            for index in 0..<count { value |= Int(bytes[offset + index]) << (index * 8) }
            return value
        }
        func expect(_ offset: Int, _ count: Int, _ wanted: Int) -> Bool { number(offset, count) == wanted }
        guard bytes.count >= 22, bytes.count <= maxTotalBytes + 64 * 1024 * 1024 else { throw reject("大小") }
        let end = bytes.count - 22
        guard expect(end, 4, 0x0605_4b50), expect(end + 4, 2, 0), expect(end + 6, 2, 0), expect(end + 20, 2, 0),
              let count = number(end + 10, 2), let centralStart = number(end + 16, 4), let centralSize = number(end + 12, 4),
              expect(end + 8, 2, count), count <= maxEntries, centralStart + centralSize == end else { throw reject("目录范围") }
        var cursor = centralStart, localCursor = 0
        var result: [(path: String, data: Data)] = []
        var seen = Set<String>()
        for _ in 0..<count {
            guard expect(cursor, 4, 0x0201_4b50), expect(cursor + 4, 2, 0x0314), expect(cursor + 6, 2, 20),
                  expect(cursor + 8, 2, 0x0800), expect(cursor + 10, 2, 0), expect(cursor + 30, 2, 0),
                  expect(cursor + 32, 2, 0), expect(cursor + 34, 2, 0), expect(cursor + 36, 2, 0),
                  expect(cursor + 38, 4, Int(externalAttributes)),
                  let length = number(cursor + 28, 2), let size = number(cursor + 24, 4), let offset = number(cursor + 42, 4),
                  let crc = number(cursor + 16, 4), expect(cursor + 20, 4, size) else { throw reject("中央目录条目") }
            guard length > 0, offset == localCursor, cursor + 46 + length <= end else { throw reject("条目边界") }
            let nameBytes = Data(bytes[(cursor + 46)..<(cursor + 46 + length)])
            guard let path = String(data: nameBytes, encoding: .utf8), ContentExportFileName.isSafeArchivePath(path),
                  seen.insert(path.lowercased()).inserted else { throw reject("路径") }
            guard expect(offset, 4, 0x0403_4b50), expect(offset + 4, 2, 20), expect(offset + 6, 2, 0x0800),
                  expect(offset + 8, 2, 0), expect(offset + 14, 4, crc), expect(offset + 18, 4, size),
                  expect(offset + 22, 4, size), expect(offset + 26, 2, length), expect(offset + 28, 2, 0) else {
                throw reject("本地头")
            }
            let nameStart = offset + 30, bodyStart = nameStart + length
            guard bodyStart + size <= centralStart, Data(bytes[nameStart..<bodyStart]) == nameBytes else { throw reject("本地数据范围") }
            let body = Data(bytes[bodyStart..<(bodyStart + size)])
            guard Int(crc32(body)) == crc else { throw ContentExportError.verifyFailed("ZIP 条目 CRC 不一致：\(path)") }
            localCursor = bodyStart + size
            result.append((path, body))
            cursor += 46 + length
        }
        guard cursor == end, localCursor == centralStart else { throw reject("多余数据") }
        return result
    }
}
