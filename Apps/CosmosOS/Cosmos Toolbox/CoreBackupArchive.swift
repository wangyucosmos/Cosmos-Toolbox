import Foundation

/// V1 accepts only bounded, uncompressed ZIP entries generated here. Never extracts files.
/// Restricting compression, extras and names makes verification independent of ditto extraction.
nonisolated struct CoreBackupArchive {
    static let allowedPaths = Set(["manifest.json"] + CoreBackupSource.ids.map { "data/\($0).json" })
    private static let table: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 { crc = crc & 1 == 0 ? crc >> 1 : (crc >> 1) ^ 0xedb88320 }
        return crc
    }
    static func crc(_ data: Data) -> UInt32 {
        var value = UInt32.max
        for byte in data { value = (value >> 8) ^ table[Int((value ^ UInt32(byte)) & 255)] }
        return value ^ UInt32.max
    }
    private static func append(_ number: UInt32, bytes: Int, to data: inout Data) {
        for index in 0..<bytes { data.append(UInt8(truncatingIfNeeded: number >> (8 * index))) }
    }
    static func encode(_ entries: [String: Data]) throws -> Data {
        guard Set(entries.keys).isSubset(of: allowedPaths), entries.count <= 13 else { throw CoreBackupError.invalid("非法包条目。") }
        var archive = Data(), central = Data()
        for name in entries.keys.sorted() {
            let body = entries[name]!, text = Data(name.utf8), offset = UInt32(archive.count), checksum = crc(body)
            guard body.count <= CoreBackupService.sourceLimit else { throw CoreBackupError.invalid("条目超过容量限制。") }
            for (value, count) in [(UInt32(0x04034b50),4),(20,2),(0x0800,2),(0,2),(0,2),(0,2),(checksum,4),(UInt32(body.count),4),(UInt32(body.count),4),(UInt32(text.count),2),(0,2)] { append(value, bytes: count, to: &archive) }
            archive.append(text); archive.append(body)
            for (value, count) in [(UInt32(0x02014b50),4),(0x0314,2),(20,2),(0x0800,2),(0,2),(0,2),(0,2),(checksum,4),(UInt32(body.count),4),(UInt32(body.count),4),(UInt32(text.count),2),(0,2),(0,2),(0,2),(0,2),(0x81800000,4),(offset,4)] { append(value, bytes: count, to: &central) }
            central.append(text)
        }
        let offset = UInt32(archive.count)
        archive.append(central)
        for (value, count) in [(UInt32(0x06054b50),4),(0,2),(0,2),(UInt32(entries.count),2),(UInt32(entries.count),2),(UInt32(central.count),4),(offset,4),(0,2)] { append(value, bytes: count, to: &archive) }
        guard archive.count <= CoreBackupService.packageLimit else { throw CoreBackupError.invalid("备份包超过 128 MiB。") }
        return archive
    }
    static func decode(_ data: Data) throws -> [String: Data] {
        func reject(_ condition: Bool) throws { if !condition { throw CoreBackupError.invalid("备份 ZIP 格式、路径、条目或容量无效。仅支持 Cosmos 核心备份 V1。") } }
        func number(_ offset: Int, _ count: Int) throws -> Int {
            try reject(offset >= 0 && count <= 4 && offset <= data.count - count)
            var value = 0
            for index in 0..<count { value |= Int(data[offset + index]) << (index * 8) }
            return value
        }
        func slice(_ offset: Int, _ count: Int) throws -> Data {
            try reject(offset >= 0 && count >= 0 && offset <= data.count - count)
            return data.subdata(in: offset..<(offset + count))
        }
        try reject(data.count >= 22 && data.count <= CoreBackupService.packageLimit)
        let end = data.count - 22
        try reject(try number(end,4) == 0x06054b50 && number(end+4,2) == 0 && number(end+6,2) == 0 && number(end+20,2) == 0)
        let count = try number(end+10,2), centralStart = try number(end+16,4)
        try reject(try count > 0 && count <= 13 && number(end+8,2) == count && centralStart + number(end+12,4) == end)
        var cursor = centralStart, localCursor = 0, result = [String: Data]()
        for _ in 0..<count {
            try reject(try number(cursor,4) == 0x02014b50 && number(cursor+4,2) == 0x0314 && number(cursor+6,2) == 20
                && number(cursor+8,2) == 0x0800 && number(cursor+10,2) == 0 && number(cursor+30,2) == 0
                && number(cursor+32,2) == 0 && number(cursor+34,2) == 0 && number(cursor+36,2) == 0
                && number(cursor+38,4) == 0x81800000)
            let length = try number(cursor+28,2), size = try number(cursor+24,4), offset = try number(cursor+42,4)
            try reject(size <= CoreBackupService.sourceLimit && length > 0 && length <= 64 && offset == localCursor)
            let nameBytes = try slice(cursor+46,length)
            guard let name = String(data: nameBytes, encoding: .utf8) else { throw CoreBackupError.invalid("条目名称无效。") }
            try reject(allowedPaths.contains(name) && result[name] == nil)
            try reject(try number(cursor+20,4) == size && number(offset,4) == 0x04034b50
                && number(offset+4,2) == 20 && number(offset+6,2) == 0x0800 && number(offset+8,2) == 0
                && number(offset+14,4) == number(cursor+16,4) && number(offset+18,4) == size
                && number(offset+22,4) == size && number(offset+26,2) == length && number(offset+28,2) == 0)
            try reject(try slice(offset+30,length) == nameBytes)
            let body = try slice(offset+30+length,size)
            try reject(try Int(crc(body)) == number(cursor+16,4))
            localCursor = offset+30+length+size
            try reject(localCursor <= centralStart)
            result[name] = body; cursor += 46+length
        }
        try reject(cursor == end && localCursor == centralStart)
        return result
    }
}
