import Foundation
import Darwin

/// All file I/O and cache access are confined to one serial queue.
nonisolated final class ZhuowangAssetTextReader: @unchecked Sendable {
    static let bodyLimit = 2 * 1024 * 1024
    static let cacheLimit = 32 * 1024 * 1024
    private let queue = DispatchQueue(label: "cosmos.assets.read", qos: .userInitiated)
    private let allowedRoot: URL?
    private var cache: [ZhuowangAssetTextRequest: Cached] = [:]
    private var order: [ZhuowangAssetTextRequest] = []
    private var bytes = 0
    private var diskReads = 0

    private struct Fingerprint: Equatable {
        let device: UInt64
        let inode: UInt64
        let size: Int64
        let modified: Int64
        let modifiedNanos: Int64
        let changed: Int64
        let changedNanos: Int64
    }
    private struct Cached {
        let fingerprint: Fingerprint?
        let metadata: String?
        let body: ZhuowangAssetBody
        let cost: Int
    }
    private final class Cancellation: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false
        func cancel() { lock.lock(); cancelled = true; lock.unlock() }
        var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    }

    init(allowedRoot: URL? = nil) { self.allowedRoot = allowedRoot }

    func invalidate() async {
        await withCheckedContinuation { continuation in
            queue.async { self.cache.removeAll(); self.order.removeAll(); self.bytes = 0; continuation.resume() }
        }
    }

    func read(_ request: ZhuowangAssetTextRequest) async -> ZhuowangAssetBody? {
        let cancellation = Cancellation()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                queue.async {
                    guard !cancellation.isCancelled else { continuation.resume(returning: nil); return }
                    let body = self.resolve(request, cancellation: cancellation)
                    continuation.resume(returning: cancellation.isCancelled ? nil : body)
                }
            }
        } onCancel: { cancellation.cancel() }
    }

    func statistics() async -> (bytes: Int, diskReads: Int) {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: (self.bytes, self.diskReads)) }
        }
    }

    private func inspect(_ path: String) -> (Fingerprint?, String, String?) {
        guard !path.isEmpty else { return (nil, "未记录本地文件", nil) }
        guard path.hasPrefix("/"), !path.contains("\0"), !path.split(separator: "/").contains("..") else {
            return (nil, "拒绝相对路径、URL 或路径穿越", nil)
        }
        let url = URL(fileURLWithPath: path)
        if let allowedRoot {
            let root = allowedRoot.path
            guard url.path.hasPrefix(root + "/") else { return (nil, "隔离模式拒绝临时根之外的文件", nil) }
        }
        var cursor = url
        while cursor.path != "/" {
            var info = stat()
            guard lstat(cursor.path, &info) == 0 else { return (nil, "文件缺失或无法访问", nil) }
            guard (info.st_mode & mode_t(S_IFMT)) != mode_t(S_IFLNK) else { return (nil, "拒绝符号链接", nil) }
            if cursor == url {
                guard (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { return (nil, "不是普通文件", nil) }
            }
            cursor.deleteLastPathComponent()
        }
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return (nil, "文件无法访问", nil) }
        guard access(url.path, R_OK) == 0 else { return (nil, "文件不可读", nil) }
        return (Fingerprint(device: UInt64(info.st_dev), inode: UInt64(info.st_ino), size: info.st_size,
            modified: Int64(info.st_mtimespec.tv_sec), modifiedNanos: Int64(info.st_mtimespec.tv_nsec),
            changed: Int64(info.st_ctimespec.tv_sec), changedNanos: Int64(info.st_ctimespec.tv_nsec)), "本地文件可读", url.path)
    }

    private func resolve(_ request: ZhuowangAssetTextRequest, cancellation: Cancellation) -> ZhuowangAssetBody {
        let inspected = inspect(request.location.trimmingCharacters(in: .whitespacesAndNewlines))
        if let cached = cache[request], cached.fingerprint == inspected.0,
           cached.metadata.map({ Data($0.utf8) }) == request.content.map({ Data($0.utf8) }),
           cached.body.fileStatus == inspected.1 {
            order.removeAll { $0 == request }; order.append(request)
            return cached.body
        }
        if let old = cache.removeValue(forKey: request) { bytes -= old.cost }
        order.removeAll { $0 == request }
        let metadata = request.content.flatMap { $0.isEmpty ? nil : $0 }
        let metadataTooLarge = metadata.map { $0.utf8.count > Self.bodyLimit } ?? false
        var text = metadataTooLarge ? nil : metadata
        var source = metadata == nil ? "无可用正文" : "元数据正文"
        var status = inspected.1
        var comparison = "未核对"
        var limitation: String? = metadataTooLarge ? "元数据正文超过 2 MiB；未截断，正文检索、展示和复制不可用。" : nil
        var admittedPath = inspected.2
        if let fingerprint = inspected.0, let path = inspected.2, request.readsTextFile {
            if fingerprint.size > Int64(Self.bodyLimit) {
                status = "文件正文超过 2 MiB"
                comparison = "未核对：文件超限"
                if metadata == nil { limitation = "文件正文超过 2 MiB；未截断，正文检索、展示和复制不可用。" }
            } else if !cancellation.isCancelled {
                do {
                    let descriptor = open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
                    guard descriptor >= 0 else { throw ReadError.unavailable }
                    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
                    defer { try? handle.close() }
                    var opened = stat()
                    guard fstat(descriptor, &opened) == 0,
                          UInt64(opened.st_dev) == fingerprint.device, UInt64(opened.st_ino) == fingerprint.inode,
                          (opened.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { throw ReadError.changed }
                    diskReads += 1
                    let data = try handle.read(upToCount: Self.bodyLimit + 1) ?? Data()
                    guard data.count <= Self.bodyLimit else { throw ReadError.tooLarge }
                    guard data.count == Int(fingerprint.size) else { throw ReadError.changed }
                    guard inspect(path).0 == fingerprint else { throw ReadError.changed }
                    guard let fileText = String(data: data, encoding: .utf8) else { throw ReadError.encoding }
                    if let metadata, !metadataTooLarge {
                        comparison = metadata.utf8.elementsEqual(fileText.utf8) ? "正文一致（已读取核对）" : "正文不一致；使用元数据正文"
                    } else if metadataTooLarge { comparison = "未核对：元数据正文超限" }
                    else { text = fileText; source = "本地文件正文"; comparison = "不适用：无元数据正文" }
                } catch {
                    status = (error as? ReadError)?.label ?? "文件读取失败"
                    comparison = "未核对：" + status
                    admittedPath = nil
                }
            }
        } else if !request.readsTextFile { comparison = "不适用：非受支持文本文件" }
        else { comparison = "未核对：" + status }
        if !request.readsTextFile && metadata == nil { limitation = "此类型不支持正文提取；可按名称和活动检索。" }
        let body = ZhuowangAssetBody(text: text, source: source, fileStatus: status,
            comparison: comparison, admittedPath: admittedPath, limitation: limitation,
            fileRevision: inspected.0.map { "\($0.device):\($0.inode):\($0.size):\($0.modified):\($0.modifiedNanos):\($0.changed):\($0.changedNanos)" })
        // Account for both retained request content and resolved String storage.
        let cost = (metadata.map { max($0.utf8.count, $0.utf16.count * 2) } ?? 0)
            + (text.map { max($0.utf8.count, $0.utf16.count * 2) } ?? 0)
        if cost <= Self.cacheLimit && !metadataTooLarge && !cancellation.isCancelled {
            while bytes + cost > Self.cacheLimit, let first = order.first {
                order.removeFirst(); if let removed = cache.removeValue(forKey: first) { bytes -= removed.cost }
            }
            cache[request] = Cached(fingerprint: inspected.0, metadata: request.content, body: body, cost: cost)
            order.append(request); bytes += cost
        }
        return body
    }

    private enum ReadError: Error {
        case unavailable, changed, tooLarge, encoding
        var label: String {
            switch self {
            case .unavailable: return "文件不可读"
            case .changed: return "读取期间文件变化；请刷新"
            case .tooLarge: return "文件正文超过 2 MiB"
            case .encoding: return "文件不是有效 UTF-8 正文"
            }
        }
    }
}
