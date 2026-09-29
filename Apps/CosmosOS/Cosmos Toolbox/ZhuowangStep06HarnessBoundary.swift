import Foundation
import CryptoKit
import Darwin


nonisolated enum ZhuowangStep06HarnessBoundaryError: LocalizedError {
    case sandboxUnavailable
    case unsafeHarnessHome
    case snapshotFailed
    case formalFilesChanged

    var errorDescription: String? {
        switch self {
        case .sandboxUnavailable:
            return "Step 06 无法启用本机文件隔离，已阻止生成，未提供可采用草稿。"
        case .unsafeHarnessHome:
            return "DeepSeek Harness 数据目录与正式文档目录重叠，已阻止生成。"
        case .snapshotFailed:
            return "无法核验正式 Workspace 或知识库文件，已阻止生成。"
        case .formalFilesChanged:
            return "执行期间正式 Workspace 或知识库文件发生变化，结果已拒绝，不可采用。请保留现场文件并检查。"
        }
    }
}


nonisolated struct ZhuowangStep06HarnessBoundary: @unchecked Sendable {
    let protectedRoots: [URL]
    let fileManager: FileManager

    static var productionRoots: [URL] {
        let documents = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
        return [
            documents.appendingPathComponent("Cosmos OS", isDirectory: true),
            documents.appendingPathComponent("我的知识库", isDirectory: true)
        ]
    }

    init(
        protectedRoots: [URL] = Self.productionRoots,
        fileManager: FileManager = .default
    ) {
        self.protectedRoots = protectedRoots
        self.fileManager = fileManager
    }

    func makeLaunchConfiguration(
        harnessHome: URL
    ) throws -> (workingDirectory: URL, harnessHome: URL, profile: String) {
        let sandboxURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
        guard fileManager.isExecutableFile(atPath: sandboxURL.path) else {
            throw ZhuowangStep06HarnessBoundaryError.sandboxUnavailable
        }

        let safeHarnessHome = try Self.canonicalExistingURL(harnessHome)
        let documents = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
        let safeDocuments = try Self.canonicalExistingURL(documents)
        guard !Self.isWithin(safeHarnessHome, root: safeDocuments),
              !protectedRoots.contains(where: {
                  Self.isWithin(
                      safeHarnessHome,
                      root: $0.resolvingSymlinksInPath().standardizedFileURL
                  )
              }) else {
            throw ZhuowangStep06HarnessBoundaryError.unsafeHarnessHome
        }

        let requestedWorkingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("Cosmos-Step06-Harness-\(UUID().uuidString)", isDirectory: true)
            .standardizedFileURL
        try fileManager.createDirectory(
            at: requestedWorkingDirectory,
            withIntermediateDirectories: false
        )
        let workingDirectory = try Self.canonicalExistingURL(requestedWorkingDirectory)

        let writable = [workingDirectory, safeHarnessHome]
            .map { "(allow file-write* (subpath \(Self.sandboxLiteral($0.path))))" }
            .joined(separator: "\n")
        let unreadable = protectedRoots
            .map { $0.resolvingSymlinksInPath().standardizedFileURL }
            .map { "(deny file-read* (subpath \(Self.sandboxLiteral($0.path))))" }
            .joined(separator: "\n")

        let profile = """
        (version 1)
        (allow default)
        (deny file-write*)
        (deny process-exec (literal "/usr/bin/git"))
        (deny process-exec (literal "/opt/homebrew/bin/git"))
        (deny process-exec (literal "/usr/local/bin/git"))
        (deny process-exec (literal "/Applications/Xcode.app/Contents/Developer/usr/bin/git"))
        \(writable)
        (allow file-write* (literal "/dev/null"))
        \(unreadable)
        """

        return (workingDirectory, safeHarnessHome, profile)
    }

    func snapshot() throws -> String {
        do {
            return try snapshotUnchecked()
        } catch {
            throw ZhuowangStep06HarnessBoundaryError.snapshotFailed
        }
    }

    private func snapshotUnchecked() throws -> String {
        var digest = SHA256()
        for root in protectedRoots {
            let normalizedRoot = root.standardizedFileURL
            digest.update(data: Data(normalizedRoot.path.utf8))
            guard fileManager.fileExists(atPath: normalizedRoot.path) else {
                digest.update(data: Data("MISSING\n".utf8))
                continue
            }
            var enumerationFailed = false
            guard let enumerator = fileManager.enumerator(
                at: normalizedRoot,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .isDirectoryKey,
                    .isSymbolicLinkKey
                ],
                options: [],
                errorHandler: { _, _ in
                    enumerationFailed = true
                    return false
                }
            ) else {
                throw ZhuowangStep06HarnessBoundaryError.snapshotFailed
            }
            var entries: [String] = []
            for case let url as URL in enumerator {
                let relative = String(url.path.dropFirst(normalizedRoot.path.count))
                let values = try url.resourceValues(forKeys: [
                    .isRegularFileKey,
                    .isDirectoryKey,
                    .isSymbolicLinkKey
                ])
                if values.isSymbolicLink == true {
                    let target = try fileManager.destinationOfSymbolicLink(atPath: url.path)
                    entries.append("L\t\(relative)\t\(target)")
                } else if values.isRegularFile == true {
                    let data = try Data(contentsOf: url, options: .mappedIfSafe)
                    let hash = SHA256.hash(data: data)
                        .map { String(format: "%02x", $0) }.joined()
                    entries.append("F\t\(relative)\t\(hash)")
                } else if values.isDirectory == true {
                    entries.append("D\t\(relative)")
                } else {
                    throw ZhuowangStep06HarnessBoundaryError.snapshotFailed
                }
            }
            if enumerationFailed {
                throw ZhuowangStep06HarnessBoundaryError.snapshotFailed
            }
            for entry in entries.sorted() {
                digest.update(data: Data((entry + "\n").utf8))
            }
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func isWithin(_ url: URL, root: URL) -> Bool {
        url.path == root.path || url.path.hasPrefix(root.path + "/")
    }

    private static func canonicalExistingURL(_ url: URL) throws -> URL {
        guard let pointer = realpath(url.path, nil) else {
            throw ZhuowangStep06HarnessBoundaryError.unsafeHarnessHome
        }
        defer { free(pointer) }
        return URL(fileURLWithPath: String(cString: pointer), isDirectory: true)
    }

    private static func sandboxLiteral(_ path: String) -> String {
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
