import AppKit
import CryptoKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

private final class KnowledgeFault: @unchecked Sendable {
    private let lock = NSLock()
    private var stage: KnowledgeSourceStorageStage?
    func arm(_ stage: KnowledgeSourceStorageStage?) { lock.lock(); self.stage = stage; lock.unlock() }
    func fires(_ current: KnowledgeSourceStorageStage) -> Bool { lock.lock(); defer { lock.unlock() }; return stage == current }
}

/// 记录每次调用，并按命令返回预设结果的进程替身。
private final class RecordingRunner: KnowledgeProcessRunning, @unchecked Sendable {
    struct Call: Sendable { let executable: URL; let arguments: [String]; let directory: URL; let environment: [String: String]; let timeout: TimeInterval }
    private let lock = NSLock()
    private var recorded: [Call] = []
    var responses: [String: KnowledgeProcessResult] = [:]     // 键 = 全局选项之后的第一个参数
    var calls: [Call] { lock.lock(); defer { lock.unlock() }; return recorded }
    func run(executable: URL, arguments: [String], directory: URL, environment: [String: String], timeout: TimeInterval) async -> KnowledgeProcessResult {
        lock.lock(); recorded.append(Call(executable: executable, arguments: arguments, directory: directory, environment: environment, timeout: timeout)); lock.unlock()
        let verb = arguments.dropFirst(KnowledgeGitCommand.globalOptions.count).first ?? ""
        return responses[verb] ?? KnowledgeProcessResult(exitCode: 0, stdout: "", stderr: "")
    }
    func verbs() -> [String] { calls.map { $0.arguments.dropFirst(KnowledgeGitCommand.globalOptions.count).first ?? "" } }
}

@MainActor
final class KnowledgeSourceTests: XCTestCase {
    private var roots: [URL] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots = []; super.tearDown()
    }

    // MARK: Helpers

    private func tempDir(_ name: String = "kb") throws -> URL {
        let url = URL(fileURLWithPath: "/private/tmp/CosmosKnowledgeTest-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        roots.append(url)
        let child = url.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        return child
    }
    /// 尚不存在的存储根（缺库 ≠ 失败，是被测行为的一部分）。
    private func newStorageRoot() -> URL {
        let url = URL(fileURLWithPath: "/private/tmp/CosmosKnowledgeSourcesTest-" + UUID().uuidString, isDirectory: true)
        roots.append(url); return url
    }
    private func write(_ root: URL, _ relative: String, _ text: String) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }
    private func writeBytes(_ root: URL, _ relative: String, _ data: Data) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
    private func bytes(_ url: URL) -> Data? { try? Data(contentsOf: url) }
    private func makeStorage(_ root: URL, fault: KnowledgeFault? = nil) -> KnowledgeSourceFileStorage {
        KnowledgeSourceFileStorage(root: root, hook: { stage in if fault?.fires(stage) == true { throw NSError(domain: "inject", code: 1) } })
    }
    private func source(_ dir: URL, name: String? = nil, enabled: Bool = true) -> KnowledgeSource {
        KnowledgeSource(displayName: name ?? dir.lastPathComponent, path: KnowledgeSourceScanner.canonicalDirectory(dir) ?? dir.path, isEnabled: enabled)
    }
    /// 目录树指纹：相对路径 → 内容哈希（目录为 "dir"，符号链接为目标路径）。
    private func fingerprint(_ root: URL) throws -> [String: String] {
        var result: [String: String] = [:]
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [])! {
            let relative = String(url.path.dropFirst(root.path.count))
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { result[relative] = "link:" + ((try? fm.destinationOfSymbolicLink(atPath: url.path)) ?? "") }
            else if values.isDirectory == true { result[relative] = "dir" }
            else { result[relative] = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined() }
        }
        return result
    }

    /// 持久化的时间戳为毫秒精度；其余字段必须逐一相同。
    private func assertSame(_ x: [KnowledgeSource], _ y: [KnowledgeSource], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(x.count, y.count, file: file, line: line)
        for (l, r) in zip(x, y) {
            XCTAssertEqual([l.id.uuidString, l.displayName, l.path], [r.id.uuidString, r.displayName, r.path], file: file, line: line)
            XCTAssertEqual(l.isEnabled, r.isEnabled, file: file, line: line)
            XCTAssertEqual(l.addedAt.timeIntervalSince1970, r.addedAt.timeIntervalSince1970, accuracy: 0.002, file: file, line: line)
        }
    }

    // MARK: 1. Source registry storage (§4.2 pattern)

    func testMissingLibraryIsReadOnlyZeroInitialisedAndCreatesNothing() async throws {
        let root = newStorageRoot(), storage = makeStorage(root)
        let snapshot = try await storage.load()
        XCTAssertFalse(snapshot.established); XCTAssertTrue(snapshot.sources.isEmpty); XCTAssertEqual(snapshot.revision, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        let sync = try storage.loadSynchronously()
        XCTAssertFalse(sync.established); XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testAddPublishesAtomicallyWithExactByteBackupAndRevisionAndPrivateLayout() async throws {
        let root = newStorageRoot(), storage = makeStorage(root)
        let a = source(try tempDir("a")), b = source(try tempDir("b"))
        let first = try await storage.apply(.add(a, expectedRevision: 0))
        XCTAssertEqual(first.revision, 1); XCTAssertTrue(first.established); assertSame(first.sources, [a])
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.backupURL.path), "no backup before the first replacement")
        let firstBytes = try XCTUnwrap(bytes(storage.primaryURL))
        let second = try await storage.apply(.add(b, expectedRevision: 1))
        XCTAssertEqual(second.revision, 2); XCTAssertEqual(second.sources.map(\.id), [a.id, b.id])
        XCTAssertEqual(bytes(storage.backupURL), firstBytes, "backup is the exact prior primary bytes")
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
        XCTAssertEqual(names, [".sources.lock", "sources.backup.json", "sources.json"], "no temp files are left behind")
        let reloaded = try await makeStorage(root).load()
        XCTAssertEqual(reloaded, second); XCTAssertEqual(reloaded.sources.map(\.id), [a.id, b.id])
        let document = try JSONDecoder().decode(KnowledgeSourcesDocument.self, from: try XCTUnwrap(bytes(storage.primaryURL)).replacingISODates())
        XCTAssertEqual(document.schemaVersion, 1)
    }

    func testFailureInjectionAtEveryStageLeavesPrimaryUntouchedAndReadBackFailureLocks() async throws {
        let root = newStorageRoot(), fault = KnowledgeFault(), storage = makeStorage(root, fault: fault)
        _ = try await storage.apply(.add(source(try tempDir("seed")), expectedRevision: 0))
        let before = try XCTUnwrap(bytes(storage.primaryURL))
        let extra = source(try tempDir("extra"))
        for stage in [KnowledgeSourceStorageStage.read, .encode, .backup, .backupReadBack, .replace] {
            fault.arm(stage)
            do { _ = try await storage.apply(.add(extra, expectedRevision: 1)); XCTFail("expected failure at \(stage)") }
            catch let error as KnowledgeSourceError { XCTAssertFalse(error.locksSaving, "pre-replace failures are retryable: \(stage)") }
            XCTAssertEqual(bytes(storage.primaryURL), before, "primary bytes unchanged after failure at \(stage)")
        }
        fault.arm(nil)
        let ok = try await storage.apply(.add(extra, expectedRevision: 1))
        XCTAssertEqual(ok.sources.count, 2)
        // 主文件已替换后读回失败 = 不确定写入，必须锁定。
        fault.arm(.readBack)
        do { _ = try await storage.apply(.add(source(try tempDir("late")), expectedRevision: 2)); XCTFail() }
        catch let error as KnowledgeSourceError { XCTAssertEqual(error, .uncertainWrite); XCTAssertTrue(error.locksSaving) }
    }

    func testCorruptUnknownSchemaDuplicateMissingPrimaryAndSymlinksLockWritesWithoutOverwriting() async throws {
        let seedDir = source(try tempDir("seed"))
        func fresh(_ content: Data?, backup: Data? = nil) throws -> (KnowledgeSourceFileStorage, URL) {
            let root = newStorageRoot(); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if let content { try content.write(to: root.appendingPathComponent("sources.json")) }
            if let backup { try backup.write(to: root.appendingPathComponent("sources.backup.json")) }
            return (makeStorage(root), root)
        }
        let candidate = source(try tempDir("candidate"))
        func expectLocked(_ storage: KnowledgeSourceFileStorage, _ expected: KnowledgeSourceError, file: StaticString = #filePath, line: UInt = #line) async {
            do { _ = try await storage.load(); XCTFail("load should fail", file: file, line: line) }
            catch { XCTAssertEqual(error as? KnowledgeSourceError, expected, file: file, line: line); XCTAssertTrue((error as? KnowledgeSourceError)?.locksSaving == true, file: file, line: line) }
            do { _ = try await storage.apply(.add(candidate, expectedRevision: 0)); XCTFail("write should fail", file: file, line: line) }
            catch { XCTAssertEqual(error as? KnowledgeSourceError, expected, file: file, line: line) }
        }
        let garbage = Data("not json".utf8)
        var (storage, root) = try fresh(garbage)
        await expectLocked(storage, .corruptData); XCTAssertEqual(bytes(storage.primaryURL), garbage)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.backupURL.path), "no backup of unreadable data is fabricated")

        let enc = KnowledgeSourceCoding.encoder()
        var future = KnowledgeSourcesDocument(); future.schemaVersion = 2
        let futureBytes = try enc.encode(future)
        (storage, root) = try fresh(futureBytes); await expectLocked(storage, .unsupportedSchema); XCTAssertEqual(bytes(storage.primaryURL), futureBytes)

        let duplicate = try enc.encode(KnowledgeSourcesDocument(revision: 1, sources: [seedDir, KnowledgeSource(displayName: "again", path: seedDir.path)]))
        (storage, root) = try fresh(duplicate); await expectLocked(storage, .duplicateIdentity)

        (storage, root) = try fresh(nil, backup: Data("{}".utf8)); await expectLocked(storage, .missingPrimaryWithBackup)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.primaryURL.path), "never initialises over a backup")

        (storage, root) = try fresh(Data([0x7B, 0x00, 0x7D])); await expectLocked(storage, .corruptData)

        // 符号链接：主文件、存储根都拒绝，链接目标不被改写。
        let victim = try tempDir("victim").appendingPathComponent("target.json"); try Data("keep".utf8).write(to: victim)
        (storage, root) = try fresh(nil)
        try FileManager.default.createSymbolicLink(at: storage.primaryURL, withDestinationURL: victim)
        await expectLocked(storage, .unsafePath); XCTAssertEqual(bytes(victim), Data("keep".utf8))
        let realRoot = try tempDir("realroot"), linkRoot = newStorageRoot()
        try FileManager.default.createSymbolicLink(at: linkRoot, withDestinationURL: realRoot)
        await expectLocked(makeStorage(linkRoot), .unsafePath)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: realRoot.path), [], "nothing is created through a linked root")
    }

    func testStaleRevisionConflictsAndConcurrentWritersNeverCorrupt() async throws {
        let root = newStorageRoot()
        let one = makeStorage(root), two = makeStorage(root)
        _ = try await one.apply(.add(source(try tempDir("first")), expectedRevision: 0))
        do { _ = try await two.apply(.add(source(try tempDir("stale")), expectedRevision: 0)); XCTFail() }
        catch { XCTAssertEqual(error as? KnowledgeSourceError, .conflict); XCTAssertFalse((error as! KnowledgeSourceError).locksSaving) }
        let dirs = try (0..<8).map { try tempDir("c\($0)") }.map { source($0) }
        await withTaskGroup(of: Void.self) { group in
            for s in dirs {
                group.addTask {
                    let storage = KnowledgeSourceFileStorage(root: root)
                    for _ in 0..<40 {
                        guard let snapshot = try? await storage.load() else { continue }
                        if (try? await storage.apply(.add(s, expectedRevision: snapshot.revision))) != nil { return }
                    }
                }
            }
        }
        let final = try await makeStorage(root).load()
        XCTAssertEqual(final.sources.count, 9); XCTAssertEqual(Set(final.sources.map(\.id)).count, 9)
        XCTAssertEqual(final.revision, 9)
    }

    func testRenameEnableRemoveValidationCapacityAndNotFound() throws {
        let dir = source(try tempDir("a"))
        var doc = KnowledgeSourcesDocument()
        doc = try KnowledgeSourceFileStorage.apply(.add(dir, expectedRevision: 0), to: doc)
        doc = try KnowledgeSourceFileStorage.apply(.rename(id: dir.id, name: "  新名字  ", expectedRevision: 1), to: doc)
        XCTAssertEqual(doc.sources[0].displayName, "新名字"); XCTAssertEqual(doc.revision, 2)
        for bad in ["", "   ", "a\nb", String(repeating: "长", count: 101), "x\0y"] {
            XCTAssertThrowsError(try KnowledgeSourceFileStorage.apply(.rename(id: dir.id, name: bad, expectedRevision: 2), to: doc)) {
                guard case KnowledgeSourceError.invalidInput = $0 else { return XCTFail("\($0)") }
            }
        }
        doc = try KnowledgeSourceFileStorage.apply(.setEnabled(id: dir.id, enabled: false, expectedRevision: 2), to: doc)
        XCTAssertFalse(doc.sources[0].isEnabled)
        XCTAssertThrowsError(try KnowledgeSourceFileStorage.apply(.rename(id: UUID(), name: "x", expectedRevision: 3), to: doc)) { XCTAssertEqual($0 as? KnowledgeSourceError, .notFound) }
        XCTAssertThrowsError(try KnowledgeSourceFileStorage.apply(.remove(id: dir.id, expectedRevision: 99), to: doc)) { XCTAssertEqual($0 as? KnowledgeSourceError, .conflict) }
        doc = try KnowledgeSourceFileStorage.apply(.remove(id: dir.id, expectedRevision: 3), to: doc)
        XCTAssertTrue(doc.sources.isEmpty)
        var full = KnowledgeSourcesDocument()
        for i in 0..<KnowledgeSourceLimits.maxSources { full.sources.append(KnowledgeSource(displayName: "s\(i)", path: "/private/tmp/CosmosKnowledgeCap-\(i)")) }
        XCTAssertThrowsError(try KnowledgeSourceFileStorage.apply(.add(KnowledgeSource(displayName: "x", path: "/private/tmp/CosmosKnowledgeCap-x"), expectedRevision: 0), to: full)) {
            guard case KnowledgeSourceError.capacityExceeded = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertFalse(KnowledgeSource.validPath("/a/../b")); XCTAssertFalse(KnowledgeSource.validPath("relative")); XCTAssertFalse(KnowledgeSource.validPath("/a/b/"))
    }

    func testOverlapRulesDuplicateNestedExcludedAndReverseContainment() throws {
        let kb = try tempDir("kb")
        try write(kb, ".gitignore", "卓望工作相关/卓望/\n")
        try write(kb, "卓望工作相关/卓望/doc.md", "x"); try FileManager.default.createDirectory(at: kb.appendingPathComponent("卓望工作相关/卓望/.git"), withIntermediateDirectories: true)
        try write(kb, "其他/sub/doc.md", "x")
        try write(kb, "node_modules/pkg/a.md", "x")
        try write(kb, "repo2/.git/HEAD", "x"); try write(kb, "repo2/a.md", "x")
        try write(kb, ".hiddendir/a.md", "x")
        let parent = source(kb)
        func reject(_ path: URL, existing: [KnowledgeSource]) -> KnowledgeSourceError? {
            KnowledgeSourceOverlap.rejection(candidate: KnowledgeSourceScanner.canonicalDirectory(path)!, existing: existing)
        }
        guard case .duplicateSource? = reject(kb, existing: [parent]) else { return XCTFail("same path must be rejected") }
        guard case .overlap? = reject(kb.appendingPathComponent("其他/sub"), existing: [parent]) else { return XCTFail("non-excluded child must be rejected") }
        XCTAssertNil(reject(kb.appendingPathComponent("卓望工作相关/卓望"), existing: [parent]), "gitignored nested repo can be its own source")
        XCTAssertNil(reject(kb.appendingPathComponent("node_modules/pkg"), existing: [parent]), "built-in excluded")
        XCTAssertNil(reject(kb.appendingPathComponent("repo2"), existing: [parent]), "nested repository")
        XCTAssertNil(reject(kb.appendingPathComponent(".hiddendir"), existing: [parent]), "hidden")
        // 反向：候选包含已有来源。
        let child = source(kb.appendingPathComponent("卓望工作相关/卓望"))
        XCTAssertNil(reject(kb, existing: [child]), "parent that already excludes the child is fine")
        let plain = source(kb.appendingPathComponent("其他/sub"))
        guard case .overlap? = reject(kb, existing: [plain]) else { return XCTFail("parent would swallow an existing source") }
        // 同前缀的兄弟目录（按路径分量比较，不是字符串前缀）。
        let sibling = kb.deletingLastPathComponent().appendingPathComponent("kb-evil"); try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        XCTAssertNil(reject(sibling, existing: [parent]))
        // 大小写 / Unicode 规范化不敏感。
        XCTAssertNotNil(KnowledgeSourceOverlap.rejection(candidate: parent.path.uppercased(), existing: [parent]))
    }

    func testLocationResolutionFailsClosedAndUsesProductionOtherwise() throws {
#if DEBUG
        let prefix = CosmosDebugStorePersistenceBootstrap.isolatedBundleIdentifierPrefix + "x"
        let flag = "--cosmos-knowledge-sources-fixture-root", good = "/private/tmp/CosmosKnowledgeSources-" + UUID().uuidString
        let production = KnowledgeSourcesLocation.resolve(isIsolated: false, bundleIdentifier: "com.wangyucosmos.Cosmos-Toolbox", arguments: [])
        XCTAssertTrue(production.root?.path.hasSuffix("Cosmos OS/KnowledgeSources") == true); XCTAssertFalse(production.isolated)
        let ok = KnowledgeSourcesLocation.resolve(isIsolated: true, bundleIdentifier: prefix, arguments: [flag, good])
        XCTAssertEqual(ok.root?.path, good); XCTAssertTrue(ok.isolated); XCTAssertNil(ok.error)
        let failures: [(Bool, String?, [String])] = [
            (true, prefix, []), (true, nil, [flag, good]), (true, "com.wangyucosmos.Cosmos-Toolbox", [flag, good]),
            (true, prefix, [flag, "/private/tmp/Other-" + UUID().uuidString]), (true, prefix, [flag, "/private/tmp/CosmosKnowledgeSources-not-a-uuid"]),
            (true, prefix, [flag, good + "/../x"]), (false, prefix, [flag, good]), (false, nil, [flag]),
        ]
        for (isolated, bundle, args) in failures {
            let location = KnowledgeSourcesLocation.resolve(isIsolated: isolated, bundleIdentifier: bundle, arguments: args)
            XCTAssertNil(location.root, "\(isolated) \(String(describing: bundle)) \(args)"); XCTAssertEqual(location.error, .unsafePath)
        }
#endif
    }

    func testStoreAddScanRenameDisableRemoveNeverTouchesFolderAndIsolationRejectsOutsideTmp() async throws {
        let kb = try tempDir("kb")
        try write(kb, "a.md", "---\ntitle: 甲\n---\n正文\n"); try write(kb, "sub/b.md", "乙")
        let before = try fingerprint(kb)
        let root = newStorageRoot()
        let store = KnowledgeSourceStore(storage: makeStorage(root))
        await store.reload()
        XCTAssertTrue(store.loaded); XCTAssertTrue(store.sources.isEmpty); XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        let added = await store.add(folder: kb)
        XCTAssertTrue(added)
        let id = try XCTUnwrap(store.sources.first?.id)
        await store.waitForScan(id)
        XCTAssertEqual(store.indexes[id]?.documents.map(\.title).sorted(), ["b", "甲"])
        let again = await store.add(folder: kb)
        XCTAssertFalse(again); XCTAssertNotNil(store.error); XCTAssertTrue(store.canSave, "duplicate is a retryable error")
        await store.rename(id, to: "我的库"); XCTAssertEqual(store.sources.first?.displayName, "我的库")
        await store.setEnabled(id, false); XCTAssertNil(store.indexes[id])
        await store.setEnabled(id, true); await store.waitForScan(id); XCTAssertNotNil(store.indexes[id])
        await store.remove(id); XCTAssertTrue(store.sources.isEmpty); XCTAssertNil(store.indexes[id])
        XCTAssertEqual(try fingerprint(kb), before, "registering, scanning and removing never touch the folder")
        // 隔离位置只接受 /private/tmp 下的文件夹。
        let isolated = KnowledgeSourceStore(storage: makeStorage(newStorageRoot()), location: KnowledgeSourcesLocation(root: nil, error: nil, isolated: true))
        await isolated.reload()
        let outside = URL(fileURLWithPath: NSHomeDirectory())
        let rejected = await isolated.add(folder: outside)
        XCTAssertFalse(rejected); XCTAssertTrue(isolated.sources.isEmpty)
    }

    // MARK: 2. Scanner

    private func buildKnowledgeTree() throws -> URL {
        let kb = try tempDir("我的知识库")
        try write(kb, "INDEX.md", "---\ntitle: 索引\ntype: index\ncreated: 2026-03-12\ntags: [a, b]\n---\n# 索引\n[[HOME]]\n")
        try write(kb, "HOME.md", "无 frontmatter 的首页\n")
        try write(kb, "知识库规则.md", "规则\n")
        try write(kb, ".gitignore", """
        # 注释
        .DS_Store
        .obsidian/workspace.json
        卓望工作相关/卓望/
        .venv/
        _草稿-cowork/
        Claude 搭建措施相关/*真实密钥版*
        !保留.md
        **/deep
        """ + "\n")
        try write(kb, ".obsidian/app.json", "TOPSECRET-SENTINEL"); try write(kb, ".git/config", "TOPSECRET-SENTINEL")
        try write(kb, ".trash/x.md", "TOPSECRET-SENTINEL"); try write(kb, "node_modules/a.md", "TOPSECRET-SENTINEL")
        try write(kb, "__pycache__/b.md", "TOPSECRET-SENTINEL"); try write(kb, ".venv/c.md", "TOPSECRET-SENTINEL")
        try write(kb, ".hidden.md", "TOPSECRET-SENTINEL")
        try write(kb, "卓望工作相关/卓望/doc.md", "TOPSECRET-SENTINEL"); try write(kb, "卓望工作相关/卓望/.git/HEAD", "x")
        try write(kb, "卓望工作相关/其他.md", "ok")
        try write(kb, "_草稿-cowork/draft.md", "TOPSECRET-SENTINEL")
        try write(kb, "Claude 搭建措施相关/ISP 真实密钥版.md", "TOPSECRET-SENTINEL")
        try write(kb, "Claude 搭建措施相关/说明.md", "说明")
        try write(kb, "private-notes/frontmatter-case.md", "---\ntitle: 看起来无害\ntype: secret\n---\nTOPSECRET-SENTINEL\n")
        try write(kb, "private-notes/list-case.md", "---\ntype: [note, Secret]\n---\nTOPSECRET-SENTINEL\n")
        try write(kb, "private-notes/my-Token-list.md", "TOPSECRET-SENTINEL"); try write(kb, "private-notes/PASSWORD.txt", "TOPSECRET-SENTINEL")
        try write(kb, "private-notes/prod.env", "TOPSECRET-SENTINEL"); try write(kb, "private-notes/客户密钥表.md", "TOPSECRET-SENTINEL")
        try write(kb, "private-notes/my_secret_plan.pdf", "TOPSECRET-SENTINEL")
        try write(kb, "nested/repo/.git/HEAD", "x"); try write(kb, "nested/repo/a.md", "TOPSECRET-SENTINEL")
        try write(kb, "nested/normal.md", "正常")
        try write(kb, "assets/img.png", "png"); try write(kb, "assets/doc.pdf", "pdf"); try write(kb, "assets/report.docx", "docx")
        try write(kb, "big.md", String(repeating: "a", count: KnowledgeSourceLimits.fileBytes + 10))
        try write(kb, "big-classified.md", "---\ntype: secret\n---\n" + String(repeating: "TOPSECRET-SENTINEL", count: 130_000))
        try FileManager.default.createSymbolicLink(at: kb.appendingPathComponent("dirlink"), withDestinationURL: kb.appendingPathComponent("nested"))
        try FileManager.default.createSymbolicLink(at: kb.appendingPathComponent("filelink.md"), withDestinationURL: kb.appendingPathComponent("HOME.md"))
        try write(kb, "bad-utf8.md", "")
        try writeBytes(kb, "bad-utf8.md", Data([0xFF, 0xFE, 0x41, 0x42]))
        return kb
    }

    func testScanExclusionRulesAreHardAndNeverLeakContent() throws {
        let kb = try buildKnowledgeTree()
        let before = try fingerprint(kb)
        let src = source(kb)
        let index = try KnowledgeSourceScanner.scan(source: src)
        XCTAssertEqual(try fingerprint(kb), before, "scan is strictly read-only")
        XCTAssertEqual(index.documents.map(\.relativePath), ["HOME.md", "INDEX.md", "bad-utf8.md", "big.md", "nested/normal.md", "Claude 搭建措施相关/说明.md", "卓望工作相关/其他.md", "知识库规则.md"].sorted())
        XCTAssertEqual(index.attachments.map(\.relativePath), ["assets/doc.pdf", "assets/img.png", "assets/report.docx"])
        let reasons = Dictionary(uniqueKeysWithValues: index.exclusions.map { ($0.relativePath, $0.reason) })
        func expect(_ path: String, _ reason: KnowledgeExclusionReason, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(reasons[path], reason, path, file: file, line: line)
        }
        expect(".git", .builtinDirectory); expect(".obsidian", .builtinDirectory); expect(".trash", .builtinDirectory)
        expect("node_modules", .builtinDirectory); expect("__pycache__", .builtinDirectory); expect(".venv", .builtinDirectory)
        expect(".hidden.md", .hidden); expect(".gitignore", .hidden)
        expect("卓望工作相关/卓望", .gitignore); expect("_草稿-cowork", .gitignore)
        expect("Claude 搭建措施相关/ISP 真实密钥版.md", .sensitiveName)
        expect("private-notes/frontmatter-case.md", .sensitiveFrontmatter); expect("private-notes/list-case.md", .sensitiveFrontmatter)
        expect("private-notes/my-Token-list.md", .sensitiveName); expect("private-notes/PASSWORD.txt", .sensitiveName)
        expect("private-notes/prod.env", .sensitiveName); expect("private-notes/客户密钥表.md", .sensitiveName); expect("private-notes/my_secret_plan.pdf", .sensitiveName)
        expect("nested/repo", .nestedRepository); expect("big-classified.md", .sensitiveFrontmatter)
        expect("dirlink", .symlink); expect("filelink.md", .symlink)
        XCTAssertEqual(index.unsupportedIgnoreLines, ["!保留.md", "**/deep"])
        // 硬规则：任何被排除文件的内容都不出现在索引里（标题、正文、原文、描述）。
        let dump = index.documents.map { $0.title + $0.rawText + $0.relativePath }.joined() + String(describing: index.documents) + String(describing: index.attachments)
        XCTAssertFalse(dump.contains("TOPSECRET-SENTINEL"))
        XCTAssertFalse(index.documents.contains { $0.relativePath.hasPrefix("private-notes/") || $0.relativePath.contains("密钥") })
        XCTAssertFalse(index.attachments.contains { $0.relativePath.contains("secret") })
        // 文件夹树不暴露被排除的目录。
        let tree = KnowledgeFolderTree.build(index).map(\.path)
        XCTAssertFalse(tree.contains("private-notes")); XCTAssertFalse(tree.contains("nested/repo")); XCTAssertTrue(tree.contains("nested"))
        // 大小上限：超限文件只列出、不读内容；坏编码只列出。
        XCTAssertEqual(index.document(at: "big.md")?.contentState, .tooLarge); XCTAssertEqual(index.document(at: "big.md")?.rawText, "")
        XCTAssertEqual(index.document(at: "bad-utf8.md")?.contentState, .notText)
        XCTAssertEqual(index.document(at: "INDEX.md")?.contentState, .loaded)
        XCTAssertEqual(index.exclusionSummary.map { $0.0 }.contains(.sensitiveFrontmatter), true)
    }

    func testTotalTextBudgetListsButDoesNotReadAndSecretClassificationStillApplies() throws {
        let kb = try tempDir("budget")
        for i in 0..<6 { try write(kb, "f\(i).md", String(repeating: "x", count: 400)) }
        try write(kb, "z-secret.md", "---\ntype: secret\n---\n" + String(repeating: "y", count: 400))
        let index = try KnowledgeSourceScanner.scan(source: source(kb), limits: KnowledgeScanLimits(fileBytes: 1000, totalTextBytes: 1000))
        XCTAssertEqual(index.documents.filter { $0.contentState == .loaded }.count, 2)
        XCTAssertEqual(index.documents.filter { $0.contentState == .budgetExceeded }.count, 4)
        XCTAssertTrue(index.documents.filter { $0.contentState == .budgetExceeded }.allSatisfy { $0.rawText.isEmpty })
        XCTAssertEqual(index.exclusions.map(\.relativePath), ["z-secret.md"], "even over budget, type: secret is excluded")
        XCTAssertLessThanOrEqual(index.loadedTextBytes, 1000)
    }

    func testMetadataModeKeepsNoBodiesAndAgreesWithFullModeOnExclusions() throws {
        let kb = try buildKnowledgeTree(), src = source(kb)
        let full = try KnowledgeSourceScanner.scan(source: src, mode: .full)
        let meta = try KnowledgeSourceScanner.scan(source: src, mode: .metadata)
        XCTAssertEqual(full.exclusions.map(\.relativePath), meta.exclusions.map(\.relativePath))
        XCTAssertEqual(full.documents.map(\.relativePath), meta.documents.map(\.relativePath))
        XCTAssertTrue(meta.documents.allSatisfy { $0.rawText.isEmpty && $0.bodyOffset == 0 })
        XCTAssertEqual(meta.document(at: "INDEX.md")?.title, "索引"); XCTAssertEqual(meta.document(at: "INDEX.md")?.tags, ["a", "b"])
    }

    func testScanCancellationAndMissingRootFailWithoutPartialIndexes() throws {
        let missing = URL(fileURLWithPath: "/private/tmp/CosmosKnowledgeMissing-" + UUID().uuidString)
        XCTAssertThrowsError(try KnowledgeSourceScanner.scan(root: missing.path, sourceID: UUID()))
        let kb = try tempDir("link-root"), real = try tempDir("real")
        let link = kb.appendingPathComponent("L"); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        XCTAssertThrowsError(try KnowledgeSourceScanner.scan(root: link.path, sourceID: UUID()), "a symlinked root is refused")
    }

    // MARK: 3. Frontmatter / .gitignore / links

    func testFrontmatterParsingCoversListsQuotesCRLFAndBodyOffsets() {
        let list = "---\ntitle: \"含: 冒号\"\ntype: note\ncreated: 2026-03-12\ntags:\n  - 甲\n  - '#乙'\n---\n正文\n"
        let a = KnowledgeFrontmatter.parse(list)
        XCTAssertEqual(a.frontmatter.title, "含: 冒号"); XCTAssertEqual(a.frontmatter.type, "note")
        XCTAssertEqual(a.frontmatter.created, "2026-03-12"); XCTAssertEqual(a.frontmatter.tags, ["甲", "乙"])
        XCTAssertEqual(String(Substring(list.utf8.dropFirst(a.bodyOffset))), "正文\n")
        let inline = KnowledgeFrontmatter.parse("---\ntags: [x, \"y, z\", w]\ntype: [a, secret]\n---\nB")
        XCTAssertEqual(inline.frontmatter.tags, ["x", "y, z", "w"]); XCTAssertTrue(inline.frontmatter.isSecret)
        let crlf = KnowledgeFrontmatter.parse("---\r\ntitle: T\r\n---\r\nbody\r\n")
        XCTAssertEqual(crlf.frontmatter.title, "T"); XCTAssertEqual(crlf.bodyOffset, 20)
        let scalarTags = KnowledgeFrontmatter.parse("---\ntags: a, b\n---\n")
        XCTAssertEqual(scalarTags.frontmatter.tags, ["a", "b"])
        for text in ["no front matter", "---\ntitle: never closed\nmore", "", "--- not\n---\n", "\n---\ntype: secret\n---\n"] {
            let r = KnowledgeFrontmatter.parse(text); XCTAssertFalse(r.frontmatter.present, text); XCTAssertEqual(r.bodyOffset, 0); XCTAssertFalse(r.frontmatter.isSecret)
        }
        for variant in ["secret", "Secret", "SECRET", "\"secret\"", "'secret'", "[secret]", "[a, secret]"] {
            XCTAssertTrue(KnowledgeFrontmatter.parse("---\ntype: \(variant)\n---\n").frontmatter.isSecret, variant)
        }
        XCTAssertFalse(KnowledgeFrontmatter.parse("---\ntype: secretary\n---\n").frontmatter.isSecret)
        XCTAssertFalse(KnowledgeFrontmatter.parse("---\nnote: type: secret\n---\n").frontmatter.isSecret)
        let unclosedLast = KnowledgeFrontmatter.parse("---\ntitle: T\n---")
        XCTAssertEqual(unclosedLast.frontmatter.title, "T")
    }

    func testGitignoreSubsetMatchesRealRulesAndRecordsUnsupportedLines() {
        let rules = KnowledgeIgnoreRules.parse("""
        # c
        .DS_Store
        .obsidian/cache
        卓望工作相关/卓望/
        node_modules/
        *.log
        /build
        docs/*.tmp
        !keep
        a/**/b
        [abc].md
        """ + "\n")
        XCTAssertEqual(rules.unsupported, ["!keep", "a/**/b", "[abc].md"])
        func hit(_ path: String, dir: Bool = false) -> String? { rules.matchedRule(path: path.split(separator: "/").map(String.init), isDirectory: dir)?.raw }
        XCTAssertEqual(hit("x/y/.DS_Store"), ".DS_Store")
        XCTAssertEqual(hit(".obsidian/cache", dir: true), ".obsidian/cache"); XCTAssertEqual(hit(".obsidian/cache/deep.json"), ".obsidian/cache")
        XCTAssertNil(hit(".obsidian/app.json"))
        XCTAssertEqual(hit("卓望工作相关/卓望", dir: true), "卓望工作相关/卓望/"); XCTAssertEqual(hit("卓望工作相关/卓望/doc.md"), "卓望工作相关/卓望/")
        XCTAssertNil(hit("卓望工作相关/卓望"), "directory-only rule ignores a plain file with that name")
        XCTAssertNil(hit("别处/卓望工作相关/卓望", dir: true), "path rules are anchored at the source root")
        XCTAssertEqual(hit("a/node_modules", dir: true), "node_modules/"); XCTAssertNil(hit("a/node_modules"))
        XCTAssertEqual(hit("deep/run.LOG"), "*.log"); XCTAssertEqual(hit("build", dir: true), "/build"); XCTAssertNil(hit("sub/build"))
        XCTAssertEqual(hit("docs/x.tmp"), "docs/*.tmp"); XCTAssertNil(hit("docs/sub/x.tmp"))
        XCTAssertTrue(KnowledgeIgnoreRules.glob("*真实密钥版*", "ISP 真实密钥版.md")); XCTAssertTrue(KnowledgeIgnoreRules.glob("a?c", "abc"))
        XCTAssertFalse(KnowledgeIgnoreRules.glob("a?c", "ac")); XCTAssertTrue(KnowledgeIgnoreRules.glob("*", "")); XCTAssertTrue(KnowledgeIgnoreRules.glob("Cafe\u{301}", "Café"))
    }

    func testWikiLinkResolutionNearestPathAliasHeadingUnicodeAndRelativeLinks() {
        let resolver = KnowledgeLinkResolver(documents: ["a/Note.md", "b/Note.md", "Plan/计划.md", "INDEX.md", "Café.md", "a/x.md", "docs/readme.txt"],
                                            attachments: ["assets/pic.png", "a/pic.png"])
        func wiki(_ t: String, from: String = "INDEX.md") -> (KnowledgeLinkResolver.Target, String?) { let r = resolver.resolveWiki(t, from: from); return (r.target, r.heading) }
        XCTAssertTrue(wiki("Note", from: "a/x.md") == (.document("a/Note.md"), nil))
        XCTAssertTrue(wiki("Note", from: "b/y.md") == (.document("b/Note.md"), nil))
        XCTAssertTrue(wiki("note") == (.document("a/Note.md"), nil), "ties broken alphabetically")
        XCTAssertTrue(wiki("Note.md", from: "b/y.md") == (.document("b/Note.md"), nil))
        XCTAssertTrue(wiki("计划#目标") == (.document("Plan/计划.md"), "目标"))
        XCTAssertTrue(wiki("Plan/计划") == (.document("Plan/计划.md"), nil))
        XCTAssertTrue(wiki("Cafe\u{301}") == (.document("Café.md"), nil))
        XCTAssertTrue(wiki("#小节", from: "a/x.md") == (.document("a/x.md"), "小节"))
        XCTAssertTrue(wiki("pic.png", from: "a/x.md") == (.attachment("a/pic.png"), nil))
        XCTAssertTrue(wiki("assets/pic.png") == (.attachment("assets/pic.png"), nil))
        XCTAssertTrue(wiki("readme.txt") == (.document("docs/readme.txt"), nil))
        XCTAssertTrue(wiki("不存在") == (.unresolved, nil)); XCTAssertTrue(wiki("") == (.unresolved, nil))
        XCTAssertEqual(resolver.resolveRelative("../b/Note.md", from: "a/x.md").target, .document("b/Note.md"))
        XCTAssertEqual(resolver.resolveRelative("Note.md#h", from: "a/x.md").heading, "h")
        XCTAssertEqual(resolver.resolveRelative("../../../etc/passwd", from: "a/x.md").target, .unresolved)
        XCTAssertEqual(resolver.resolveRelative("pic.png", from: "a/x.md").target, .attachment("a/pic.png"))
        XCTAssertEqual(resolver.resolveAttachment("pic.png", from: "docs/readme.txt"), "a/pic.png")
    }

    func testInlinePreprocessingCodeSpansLinkSchemesAndActionRoundTrip() {
        let resolver = KnowledgeLinkResolver(documents: ["笔记&甲.md", "目标.md"], attachments: ["p ic.png"])
        let attributed = KnowledgeMarkdownInline.attributed("见 [[笔记&甲|别名]]、[[目标#小 节]]、`[[代码里]]`、[[不存在]]、![[p ic.png]]、[网页](https://example.com/a?b=1&c=2)", document: "x.md", resolver: resolver)
        let links = attributed.runs.compactMap(\.link)
        XCTAssertEqual(links.count, 5)
        XCTAssertEqual(KnowledgeMarkdownInline.action(for: links[0]), .document(path: "笔记&甲.md", heading: nil))
        XCTAssertEqual(KnowledgeMarkdownInline.action(for: links[1]), .document(path: "目标.md", heading: "小 节"))
        XCTAssertEqual(KnowledgeMarkdownInline.action(for: links[2]), .missing(name: "不存在"))
        XCTAssertEqual(KnowledgeMarkdownInline.action(for: links[3]), .attachment(path: "p ic.png"))
        XCTAssertEqual(KnowledgeMarkdownInline.action(for: links[4]), .web(URL(string: "https://example.com/a?b=1&c=2")!))
        let text = String(attributed.characters)
        XCTAssertTrue(text.contains("别名")); XCTAssertTrue(text.contains("[[代码里]]"), "code spans are never converted")
        XCTAssertEqual(KnowledgeMarkdownInline.action(for: URL(string: "javascript:alert(1)")!), .ignored)
        XCTAssertEqual(KnowledgeMarkdownInline.action(for: URL(string: "file:///etc/passwd")!), .ignored)
        XCTAssertEqual(KnowledgeMarkdownInline.action(for: URL(string: "other.md")!), .relative("other.md"))
        // 稳定 ID 派生：确定、对来源与路径敏感。
        let s1 = UUID(), s2 = UUID()
        XCTAssertEqual(KnowledgeDocumentRef(sourceID: s1, relativePath: "a.md").stableID, KnowledgeDocumentRef(sourceID: s1, relativePath: "a.md").stableID)
        XCTAssertNotEqual(KnowledgeDocumentRef(sourceID: s1, relativePath: "a.md").stableID, KnowledgeDocumentRef(sourceID: s2, relativePath: "a.md").stableID)
        XCTAssertNotEqual(KnowledgeDocumentRef(sourceID: s1, relativePath: "a.md").stableID, KnowledgeDocumentRef(sourceID: s1, relativePath: "b.md").stableID)
        XCTAssertEqual(KnowledgeDocumentRef(sourceID: s1, relativePath: "Cafe\u{301}.md").stableID, KnowledgeDocumentRef(sourceID: s1, relativePath: "Café.md").stableID)
    }

    // MARK: 4. Markdown block structure (pure)

    func testMarkdownBlockStructure() throws {
        let md = """
        # 标题 一 ##

        段落 **粗** 第一行
        第二行

        - 甲
        - 乙
          - 乙一
        - [ ] 待办
        - [x] 完成

        3. 三
        4. 四

        > 引用 A
        > 引用 B

        > [!warning] 小心
        > 提示内容
        >
        > - 提示列表

        > [!tip]
        > 无标题

        ```swift
        let a = 1
        ```

        ~~~
        未闭合 代码
        还有一行
        """
        let blocks = KnowledgeMarkdown.parse(md)
        guard blocks.count == 9 else { return XCTFail("\(blocks.map(\.kind))") }
        XCTAssertEqual(blocks[0].kind, .heading(level: 1, text: "标题 一"))
        XCTAssertEqual(blocks[1].kind, .paragraph("段落 **粗** 第一行\n第二行"))
        guard case .list(false, _, let items) = blocks[2].kind else { return XCTFail() }
        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items[2].task, false); XCTAssertEqual(items[3].task, true)
        guard case .list(false, _, let nested) = items[1].blocks.last?.kind else { return XCTFail("nested list") }
        XCTAssertEqual(nested.count, 1)
        guard case .list(true, 3, let ordered) = blocks[3].kind else { return XCTFail() }
        XCTAssertEqual(ordered.count, 2)
        guard case .quote(let quoted) = blocks[4].kind else { return XCTFail() }
        XCTAssertEqual(quoted.first?.kind, .paragraph("引用 A\n引用 B"))
        guard case .callout("warning", "小心", let body) = blocks[5].kind else { return XCTFail() }
        XCTAssertEqual(body.count, 2)
        guard case .callout("tip", "Tip", _) = blocks[6].kind else { return XCTFail("default callout title") }
        XCTAssertEqual(blocks[7].kind, .code(language: "swift", text: "let a = 1"))
        XCTAssertEqual(blocks[8].kind, .code(language: nil, text: "未闭合 代码\n还有一行"))
        // 起始行号随源文本。
        XCTAssertEqual(blocks[0].line, 0); XCTAssertEqual(blocks[1].line, 2); XCTAssertEqual(KnowledgeMarkdown.blockID(containingLine: 3, in: blocks), blocks[1].id)
        XCTAssertEqual(KnowledgeMarkdown.blockID(containingLine: 0, in: blocks), blocks[0].id)
        XCTAssertEqual(KnowledgeMarkdown.headingBlockID("标题  一", in: blocks), nil)
        XCTAssertEqual(KnowledgeMarkdown.headingBlockID("标题 一", in: blocks), blocks[0].id)
    }

    func testMarkdownTablesRulesImagesSetextAndEdgeCases() {
        let md = "| 名称 | 数量 | 备注 |\n|:--|--:|:-:|\n| a \\| b | 1 |\n| `x|y` | 2 | z | 多余 |\n\n---\n\n![图](assets/a%20b.png)\n\n![[pic.png|200]]\n\nSetext 一\n=====\n\nSetext 二\n-----\n\n***\n\n1) 甲\n2) 乙\n\n行内 ![x](a.png) 图片\n\n`# 不是标题`\n\n#没有空格不是标题\n\n* * *\n"
        let blocks = KnowledgeMarkdown.parse(md)
        guard case .table(let header, let alignments, let rows) = blocks[0].kind else { return XCTFail("\(blocks[0].kind)") }
        XCTAssertEqual(header, ["名称", "数量", "备注"]); XCTAssertEqual(alignments, [.leading, .trailing, .center])
        XCTAssertEqual(rows, [["a | b", "1", ""], ["`x|y`", "2", "z"]])
        XCTAssertEqual(blocks[1].kind, .rule)
        XCTAssertEqual(blocks[2].kind, .image(alt: "图", target: "assets/a b.png"))
        XCTAssertEqual(blocks[3].kind, .image(alt: "pic.png", target: "pic.png"))
        XCTAssertEqual(blocks[4].kind, .heading(level: 1, text: "Setext 一")); XCTAssertEqual(blocks[5].kind, .heading(level: 2, text: "Setext 二"))
        XCTAssertEqual(blocks[6].kind, .rule)
        guard case .list(true, 1, let items) = blocks[7].kind else { return XCTFail("\(blocks[7].kind)") }
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(blocks[8].kind, .paragraph("行内 ![x](a.png) 图片"))
        XCTAssertEqual(blocks[9].kind, .paragraph("`# 不是标题`")); XCTAssertEqual(blocks[10].kind, .paragraph("#没有空格不是标题"))
        XCTAssertEqual(blocks[11].kind, .rule)
        XCTAssertTrue(KnowledgeMarkdown.parse("").isEmpty); XCTAssertTrue(KnowledgeMarkdown.parse("\n\n  \n").isEmpty)
        XCTAssertEqual(KnowledgeMarkdown.parse("a\r\nb\r\n").first?.kind, .paragraph("a\nb"))
        // 图片只通过索引解析：网络图片与被排除文件不会被加载。
        let resolver = KnowledgeLinkResolver(documents: ["d.md"], attachments: ["assets/ok.png", "assets/note.txt"])
        XCTAssertEqual(KnowledgeImageLoader.resolve("https://x.test/a.png", document: "d.md", resolver: resolver), .network)
        XCTAssertEqual(KnowledgeImageLoader.resolve("data:image/png;base64,AAA", document: "d.md", resolver: resolver), .network)
        XCTAssertEqual(KnowledgeImageLoader.resolve("assets/ok.png", document: "d.md", resolver: resolver), .file(path: "assets/ok.png"))
        XCTAssertEqual(KnowledgeImageLoader.resolve("ok.png", document: "d.md", resolver: resolver), .file(path: "assets/ok.png"))
        XCTAssertEqual(KnowledgeImageLoader.resolve("assets/note.txt", document: "d.md", resolver: resolver), .missing, "non-image attachments are never rendered as images")
        XCTAssertEqual(KnowledgeImageLoader.resolve("secret-key.png", document: "d.md", resolver: resolver), .missing, "files absent from the index (excluded) are unreachable")
        XCTAssertEqual(KnowledgeImageLoader.resolve("../../etc/passwd.png", document: "d.md", resolver: resolver), .missing)
    }

    // MARK: 5. Page search

    func testPageSearchCoversTitlePathTagsBodyAttachmentsAndNeverExcludedFiles() throws {
        let kb = try buildKnowledgeTree()
        try write(kb, "笔记/调研.md", "---\ntitle: 竞品调研\ntags: [市场]\n---\n第一行\n第二行里有 Needle 关键词，后面还有很长很长的内容\n")
        let index = try KnowledgeSourceScanner.scan(source: source(kb))
        let byBody = try KnowledgeSourceSearch.search("needle", in: index)
        XCTAssertEqual(byBody.map(\.path), ["笔记/调研.md"]); XCTAssertEqual(byBody[0].fields, [.body]); XCTAssertEqual(byBody[0].line, 1)
        XCTAssertTrue(byBody[0].snippet.contains("Needle")); XCTAssertFalse(byBody[0].snippet.contains("第一行"))
        XCTAssertEqual(try KnowledgeSourceSearch.search("竞品", in: index).first?.fields, [.title])
        XCTAssertEqual(try KnowledgeSourceSearch.search("市场", in: index).first?.fields, [.tag])
        XCTAssertEqual(try KnowledgeSourceSearch.search("笔记/", in: index).first?.fields, [.path])
        XCTAssertEqual(try KnowledgeSourceSearch.search("report", in: index).first?.isAttachment, true)
        XCTAssertTrue(try KnowledgeSourceSearch.search("TOPSECRET-SENTINEL", in: index).isEmpty, "excluded content cannot be found")
        XCTAssertTrue(try KnowledgeSourceSearch.search("密钥", in: index).isEmpty, "excluded names cannot be found")
        XCTAssertTrue(try KnowledgeSourceSearch.search("   ", in: index).isEmpty)
        XCTAssertEqual(try KnowledgeSourceSearch.search("cafe", in: KnowledgeIndex(sourceID: UUID(), rootPath: "/x", scannedAt: Date(), documents: [KnowledgeDocument(relativePath: "c.md", title: "Café", frontmatter: .none, byteSize: 1, modifiedAt: Date(), contentState: .loaded, rawText: "", bodyOffset: 0)])).count, 1)
    }

    // MARK: 6. Git: pure parts

    func testGitStatusParsingPullPolicyAndCommandWhitelist() throws {
        let porcelain = """
        # branch.oid 1234567890abcdef
        # branch.head main
        # branch.upstream origin/main
        # branch.ab +2 -3
        1 .M N... 100644 100644 100644 aaa bbb README.md
        1 M. N... 100644 100644 100644 aaa bbb staged.md
        1 MM N... 100644 100644 100644 aaa bbb both.md
        2 R. N... 100644 100644 100644 aaa bbb R100 new.md\told.md
        u UU N... 1 2 3 4 aaa bbb ccc conflict.md
        ? untracked.md
        ? dir/
        ! ignored.md
        """
        let s = KnowledgeGitStatusParser.parse(porcelain)
        XCTAssertEqual([s.branch, s.upstream], ["main", "origin/main"]); XCTAssertEqual([s.ahead, s.behind], [2, 3])
        XCTAssertEqual([s.changedTracked, s.stagedTracked, s.unmerged, s.untracked], [2, 3, 1, 2])
        let detached = KnowledgeGitStatusParser.parse("# branch.oid abc\n# branch.head (detached)\n")
        XCTAssertTrue(detached.detached); XCTAssertNil(detached.branch); XCTAssertNil(detached.upstream)
        let commit = try XCTUnwrap(KnowledgeGitStatusParser.parseCommit("0123456789abcdef0123456789abcdef01234567\u{1F}1800000000\u{1F}fix: 标题\n"))
        XCTAssertEqual(commit.shortHash, "01234567"); XCTAssertEqual(commit.subject, "fix: 标题"); XCTAssertEqual(commit.date.timeIntervalSince1970, 1_800_000_000)
        XCTAssertNil(KnowledgeGitStatusParser.parseCommit("")); XCTAssertNil(KnowledgeGitStatusParser.parseCommit("abc"))

        func clean(_ edit: (inout KnowledgeGitStatus) -> Void = { _ in }) -> KnowledgeGitStatus {
            var status = KnowledgeGitStatus(isRepository: true, branch: "main", upstream: "origin/main"); edit(&status); return status
        }
        func decide(_ edit: (inout KnowledgeGitStatus) -> Void = { _ in }) -> KnowledgeGitPullDecision { KnowledgeGitPullPolicy.evaluate(clean(edit)) }
        XCTAssertTrue(decide().allowed)
        XCTAssertTrue(decide { $0.behind = 4 }.allowed)
        let untracked = decide { $0.untracked = 2 }; XCTAssertTrue(untracked.allowed); XCTAssertEqual(untracked.warnings.count, 1)
        let ahead = decide { $0.ahead = 1 }; XCTAssertTrue(ahead.allowed); XCTAssertEqual(ahead.warnings.count, 1)
        for blocked in [decide { $0.changedTracked = 1 }, decide { $0.stagedTracked = 1 }, decide { $0.unmerged = 1 }, decide { $0.detached = true; $0.branch = nil },
                        decide { $0.upstream = nil }, decide { $0.branch = nil }, decide { $0.operationInProgress = "合并" }, decide { $0.failure = "boom" }] {
            XCTAssertFalse(blocked.allowed); XCTAssertFalse(blocked.reason?.isEmpty ?? true)
        }
        XCTAssertFalse(KnowledgeGitPullPolicy.evaluate(KnowledgeGitStatus()).allowed, "not a repository")

        // 命令白名单：只存在这五个命令，且只有 fetch / pull 会写仓库。
        let forbidden: Set<String> = ["commit", "push", "merge", "rebase", "stash", "reset", "clean", "checkout", "switch", "restore", "add", "rm", "mv", "cherry-pick", "revert", "tag", "branch", "config", "gc", "prune"]
        let all: [KnowledgeGitCommand] = [.status, .lastCommit, .gitDirectory, .fetch, .pullFastForwardOnly]
        for command in all {
            XCTAssertFalse(forbidden.contains(command.arguments[0]), "\(command)")
            XCTAssertTrue(["status", "log", "rev-parse", "fetch", "pull"].contains(command.arguments[0]))
            XCTAssertEqual(command.writesRepository, command == .fetch || command == .pullFastForwardOnly)
        }
        XCTAssertEqual(KnowledgeGitCommand.pullFastForwardOnly.arguments.prefix(2), ["pull", "--ff-only"])
        XCTAssertEqual(KnowledgeGitCommand.fetch.arguments.last, "origin")
        XCTAssertTrue(KnowledgeGitCommand.globalOptions.contains("--no-optional-locks"))
        XCTAssertTrue(KnowledgeGitCommand.globalOptions.joined(separator: " ").contains("core.fsmonitor=false"))
    }

    func testGitServiceUsesFixedExecutableEnvironmentTimeoutAndDoesNotPullWhenBlocked() async throws {
        let kb = try tempDir("repo"); try FileManager.default.createDirectory(at: kb.appendingPathComponent(".git"), withIntermediateDirectories: true)
        let runner = RecordingRunner()
        runner.responses["status"] = KnowledgeProcessResult(exitCode: 0, stdout: "# branch.head main\n# branch.upstream origin/main\n# branch.ab +0 -2\n1 .M N... 100644 100644 100644 a b notes.md\n", stderr: "")
        let service = KnowledgeSourceGitService(runner: runner)
        let result = await service.pull(root: kb)
        XCTAssertEqual(result.outcome, .blocked)
        XCTAssertFalse(runner.verbs().contains("pull"), "a dirty tracked tree must never reach git pull")
        for call in runner.calls {
            XCTAssertEqual(call.executable.path, "/usr/bin/git"); XCTAssertEqual(call.timeout, 60)
            XCTAssertEqual(call.environment["GIT_TERMINAL_PROMPT"], "0"); XCTAssertEqual(call.directory.path, kb.path)
            XCTAssertEqual(Array(call.arguments.prefix(KnowledgeGitCommand.globalOptions.count)), KnowledgeGitCommand.globalOptions, "global options come first and no shell string is built")
            XCTAssertFalse(call.arguments.contains { $0.contains(" ") && !$0.hasPrefix("--format") })
        }
        // 干净时才发出 pull，且参数正是快进拉取。
        runner.responses["status"] = KnowledgeProcessResult(exitCode: 0, stdout: "# branch.head main\n# branch.upstream origin/main\n# branch.ab +0 -2\n", stderr: "")
        runner.responses["pull"] = KnowledgeProcessResult(exitCode: 0, stdout: "Updating a..b\nFast-forward\n", stderr: "")
        let ok = await service.pull(root: kb)
        XCTAssertEqual(ok.outcome, .success)
        let pull = try XCTUnwrap(runner.calls.last { $0.arguments.contains("pull") })
        XCTAssertEqual(Array(pull.arguments.dropFirst(KnowledgeGitCommand.globalOptions.count)), ["pull", "--ff-only", "--no-rebase", "--no-recurse-submodules"])
        // 非仓库目录：不执行任何 git。
        let plain = try tempDir("plain"); let before = runner.calls.count
        let status = await service.status(root: plain); XCTAssertFalse(status.isRepository)
        let fetch = await service.fetch(root: plain); XCTAssertEqual(fetch.outcome, .blocked); XCTAssertEqual(runner.calls.count, before)
    }

    func testGitOutputIsRedactedAndOutcomesAreInterpreted() {
        let raw = """
        fatal: unable to access 'https://wangyucosmos:ghp_abcdefghijklmnopqrstuvwxyz0123456789@github.com/wangyucosmos/my-knowledge-base.git/': error
        remote: ssh://git:secrettoken@host/x  Authorization: Bearer abc123def456
        token github_pat_11ABCDEFG0123456789_abcdefghijklmnop and glpat-abcdefghijklmnop1234
        """
        let cleaned = KnowledgeGitOutput.summary(raw)
        for leak in ["ghp_abcdefgh", "secrettoken", "abc123def456", "github_pat_11ABC", "glpat-abcdef", "wangyucosmos:ghp"] { XCTAssertFalse(cleaned.contains(leak), leak) }
        XCTAssertTrue(cleaned.contains("github.com/wangyucosmos/my-knowledge-base.git"), "useful non-secret context is kept")
        XCTAssertEqual(KnowledgeGitOutput.summary(String(repeating: "line\n", count: 100), maxLines: 3), "line\nline\nline")
        XCTAssertTrue(KnowledgeGitOutput.summary(String(repeating: "x", count: 5000)).hasSuffix("…"))
        func r(_ code: Int32 = 0, out: String = "", err: String = "", timedOut: Bool = false, cancelled: Bool = false, launch: String? = nil) -> KnowledgeProcessResult {
            KnowledgeProcessResult(exitCode: code, stdout: out, stderr: err, timedOut: timedOut, cancelled: cancelled, launchError: launch)
        }
        XCTAssertEqual(KnowledgeSourceGitService.interpret(r(), success: "好").outcome, .success)
        XCTAssertEqual(KnowledgeSourceGitService.interpret(r(), success: "好").message, "好")
        XCTAssertEqual(KnowledgeSourceGitService.interpret(r(128, err: "fatal: Not possible to fast-forward, aborting."), success: "").outcome, .failed)
        XCTAssertEqual(KnowledgeSourceGitService.interpret(r(-1, timedOut: true), success: "").outcome, .timedOut)
        XCTAssertEqual(KnowledgeSourceGitService.interpret(r(-1, cancelled: true), success: "").outcome, .cancelled)
        XCTAssertEqual(KnowledgeSourceGitService.interpret(r(-1, launch: "nope"), success: "").outcome, .failed)
    }

    // MARK: 7. Process runner (real processes)

    func testProcessRunnerTimeoutCancellationOutputCapAndNoShell() async throws {
        let runner = KnowledgeProcessRunner(), dir = try tempDir("proc")
        let echo = await runner.run(executable: URL(fileURLWithPath: "/bin/echo"), arguments: ["a b", "$HOME;", "`x`"], directory: dir, environment: ["PATH": "/usr/bin"], timeout: 10)
        XCTAssertEqual(echo.stdout, "a b $HOME; `x`\n", "arguments are passed verbatim, never through a shell"); XCTAssertEqual(echo.exitCode, 0)
        let started = Date()
        let slow = await runner.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["20"], directory: dir, environment: [:], timeout: 0.4)
        XCTAssertTrue(slow.timedOut); XCTAssertLessThan(Date().timeIntervalSince(started), 6)
        let cancelStart = Date()
        let task = Task { await runner.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["20"], directory: dir, environment: [:], timeout: 30) }
        try await Task.sleep(for: .milliseconds(300)); task.cancel()
        let cancelled = await task.value
        XCTAssertTrue(cancelled.cancelled); XCTAssertLessThan(Date().timeIntervalSince(cancelStart), 6)
        let flood = await runner.run(executable: URL(fileURLWithPath: "/usr/bin/yes"), arguments: [], directory: dir, environment: [:], timeout: 0.6)
        XCTAssertLessThanOrEqual(flood.stdout.utf8.count, KnowledgeProcessRunner.outputLimit); XCTAssertTrue(flood.timedOut)
        let missing = await runner.run(executable: URL(fileURLWithPath: "/nonexistent/git"), arguments: [], directory: dir, environment: [:], timeout: 5)
        XCTAssertNotNil(missing.launchError)
    }

    // MARK: 8. Git integration against temporary local repositories only

    private struct Repos { let base: URL; let origin: URL; let work: URL; let other: URL }
    @discardableResult
    private func git(_ arguments: [String], in dir: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-c", "user.name=Tester", "-c", "user.email=t@example.com", "-c", "commit.gpgsign=false", "-c", "init.defaultBranch=main", "-c", "core.hooksPath=/dev/null"] + arguments
        process.currentDirectoryURL = dir
        var env = ProcessInfo.processInfo.environment; env["GIT_TERMINAL_PROMPT"] = "0"; process.environment = env
        let out = Pipe(), err = Pipe(); process.standardOutput = out; process.standardError = err
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile(), errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw NSError(domain: "git", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: String(decoding: errData, as: UTF8.self)]) }
        return String(decoding: data, as: UTF8.self)
    }
    private func makeRepos() throws -> Repos {
        let base = try tempDir("repos").deletingLastPathComponent()
        let origin = base.appendingPathComponent("origin.git"), other = base.appendingPathComponent("other"), work = base.appendingPathComponent("work")
        try FileManager.default.createDirectory(at: origin, withIntermediateDirectories: true)
        try git(["init", "--bare", "--initial-branch=main"], in: origin)
        try git(["clone", origin.path, other.path], in: base)
        try write(other, "README.md", "# 初始\n"); try write(other, "笔记/甲.md", "甲 v1\n")
        try git(["add", "-A"], in: other); try git(["commit", "-m", "feat: 初始提交"], in: other); try git(["push", "-u", "origin", "main"], in: other)
        try git(["clone", origin.path, work.path], in: base)
        return Repos(base: base, origin: origin, work: work, other: other)
    }
    private func pushFromOther(_ repos: Repos, file: String, text: String, message: String) throws {
        try write(repos.other, file, text); try git(["add", "-A"], in: repos.other); try git(["commit", "-m", message], in: repos.other)
        try git(["push", "origin", "main"], in: repos.other)
    }

    func testRealGitStatusFetchAndFastForwardPullAgainstLocalRepositories() async throws {
        let repos = try makeRepos(), service = KnowledgeSourceGitService(timeout: 30)
        let indexFile = repos.work.appendingPathComponent(".git/index")
        let indexBefore = try Data(contentsOf: indexFile)
        var status = await service.status(root: repos.work)
        XCTAssertTrue(status.isRepository); XCTAssertEqual(status.branch, "main"); XCTAssertEqual(status.upstream, "origin/main")
        XCTAssertEqual(status.lastCommit?.subject, "feat: 初始提交"); XCTAssertEqual(status.totalChanged, 0); XCTAssertTrue(KnowledgeGitPullPolicy.evaluate(status).allowed)
        XCTAssertEqual(try Data(contentsOf: indexFile), indexBefore, "status never rewrites the index")
        // 用户本地改动 / 未跟踪文件。
        try write(repos.work, "README.md", "# 本地改动\n"); try write(repos.work, "新文件.md", "x")
        status = await service.status(root: repos.work)
        XCTAssertEqual(status.changedTracked, 1); XCTAssertEqual(status.untracked, 1)
        XCTAssertFalse(KnowledgeGitPullPolicy.evaluate(status).allowed)
        try pushFromOther(repos, file: "笔记/甲.md", text: "甲 v2\n", message: "docs: 更新甲")
        // 脏树：fetch 可以，pull 被拒绝且完全不改动工作区。
        let fetched = await service.fetch(root: repos.work); XCTAssertEqual(fetched.outcome, .success)
        status = await service.status(root: repos.work)
        XCTAssertEqual(status.behind, 1); XCTAssertEqual(status.ahead, 0); XCTAssertNotNil(status.lastFetch)
        let headBefore = try git(["rev-parse", "HEAD"], in: repos.work)
        let blocked = await service.pull(root: repos.work)
        XCTAssertEqual(blocked.outcome, .blocked); XCTAssertEqual(try git(["rev-parse", "HEAD"], in: repos.work), headBefore)
        XCTAssertEqual(try String(contentsOf: repos.work.appendingPathComponent("README.md"), encoding: .utf8), "# 本地改动\n")
        // 还原本地改动（测试夹具操作，不是被测代码），只留未跟踪文件 → 允许并带提示。
        try git(["checkout", "--", "README.md"], in: repos.work)
        status = await service.status(root: repos.work)
        let decision = KnowledgeGitPullPolicy.evaluate(status); XCTAssertTrue(decision.allowed); XCTAssertEqual(decision.warnings.count, 1)
        let pulled = await service.pull(root: repos.work)
        XCTAssertEqual(pulled.outcome, .success, pulled.message)
        XCTAssertEqual(try String(contentsOf: repos.work.appendingPathComponent("笔记/甲.md"), encoding: .utf8), "甲 v2\n")
        XCTAssertEqual(try git(["rev-parse", "HEAD"], in: repos.work), try git(["rev-parse", "origin/main"], in: repos.work))
        XCTAssertEqual(try String(contentsOf: repos.work.appendingPathComponent("新文件.md"), encoding: .utf8), "x", "untracked files survive")
        status = await service.status(root: repos.work); XCTAssertEqual(status.behind, 0); XCTAssertEqual(status.lastCommit?.subject, "docs: 更新甲")
        XCTAssertEqual(try git(["log", "--merges", "--oneline"], in: repos.work), "", "fast-forward only: never a merge commit")
    }

    func testNonFastForwardIsRefusedByGitAndLeavesTheCloneUntouched() async throws {
        let repos = try makeRepos(), service = KnowledgeSourceGitService(timeout: 30)
        try write(repos.work, "本地.md", "本地提交\n"); try git(["add", "-A"], in: repos.work); try git(["commit", "-m", "本地独有提交"], in: repos.work)
        try pushFromOther(repos, file: "README.md", text: "# 远端改动\n", message: "远端提交")
        _ = await service.fetch(root: repos.work)
        let status = await service.status(root: repos.work)
        XCTAssertEqual([status.ahead, status.behind], [1, 1])
        let headBefore = try git(["rev-parse", "HEAD"], in: repos.work), treeBefore = try fingerprint(repos.work.appendingPathComponent("笔记"))
        let result = await service.pull(root: repos.work)
        XCTAssertEqual(result.outcome, .failed); XCTAssertFalse(result.message.isEmpty)
        XCTAssertEqual(try git(["rev-parse", "HEAD"], in: repos.work), headBefore, "HEAD unchanged")
        XCTAssertEqual(try fingerprint(repos.work.appendingPathComponent("笔记")), treeBefore)
        XCTAssertEqual(try git(["log", "--merges", "--oneline"], in: repos.work), "")
        XCTAssertEqual(try git(["status", "--porcelain"], in: repos.work), "")
    }

    func testUntrackedFileThatCollidesWithRemoteIsRefusedByGitWithVisibleError() async throws {
        let repos = try makeRepos(), service = KnowledgeSourceGitService(timeout: 30)
        try write(repos.work, "冲突.md", "本地未跟踪内容\n")
        try pushFromOther(repos, file: "冲突.md", text: "远端内容\n", message: "远端新增同名文件")
        _ = await service.fetch(root: repos.work)
        let result = await service.pull(root: repos.work)
        XCTAssertEqual(result.outcome, .failed); XCTAssertFalse(result.message.isEmpty)
        XCTAssertEqual(try String(contentsOf: repos.work.appendingPathComponent("冲突.md"), encoding: .utf8), "本地未跟踪内容\n", "never overwritten")
    }

    func testStoreFetchPullRescanAndNoGitUiForPlainFolders() async throws {
        let repos = try makeRepos()
        let store = KnowledgeSourceStore(storage: makeStorage(newStorageRoot()), gitService: KnowledgeSourceGitService(timeout: 30))
        await store.reload()
        let added = await store.add(folder: repos.work); XCTAssertTrue(added)
        let id = try XCTUnwrap(store.sources.first?.id)
        await store.waitForScan(id); await store.waitForGit(id)
        XCTAssertEqual(store.gitStatuses[id]?.branch, "main"); XCTAssertEqual(store.indexes[id]?.documents.count, 2)
        try pushFromOther(repos, file: "新增.md", text: "# 新增文档\n", message: "docs: 新增")
        store.fetchRemote(id); await store.waitForGit(id)
        XCTAssertEqual(store.gitStatuses[id]?.behind, 1); XCTAssertEqual(store.gitResults[id]?.outcome, .success)
        store.pullRemote(id); await store.waitForGit(id); await store.waitForScan(id)
        XCTAssertEqual(store.gitResults[id]?.outcome, .success)
        XCTAssertEqual(store.gitStatuses[id]?.behind, 0)
        for _ in 0..<100 where store.indexes[id]?.documents.count != 3 { try await Task.sleep(for: .milliseconds(30)) }
        XCTAssertEqual(store.indexes[id]?.documents.count, 3, "pull triggers a rescan of that source")
        // 普通文件夹不是 Git 仓库：不运行 git。
        let plain = try tempDir("plain"); try write(plain, "a.md", "x")
        XCTAssertFalse(KnowledgeSourceGitService.isRepository(plain))
        _ = await store.add(folder: plain)
        let plainID = try XCTUnwrap(store.sources.first { $0.path == KnowledgeSourceScanner.canonicalDirectory(plain) }?.id)
        await store.waitForScan(plainID); store.refreshGit(plainID)
        XCTAssertNil(store.gitStatuses[plainID])
    }

    // MARK: 9. Open / reveal helpers

    func testObsidianURLEncodingSafeOpenAllowlistAndFileURLBoundary() throws {
        let url = try XCTUnwrap(KnowledgeSourceActions.obsidianURL(path: "/Users/我/Documents/知识库 & 笔记/a b.md"))
        XCTAssertEqual(url.scheme, "obsidian"); XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "/Users/我/Documents/知识库 & 笔记/a b.md")
        XCTAssertFalse(url.absoluteString.contains(" ")); XCTAssertFalse(url.absoluteString.contains("&"))
        XCTAssertNil(KnowledgeSourceActions.obsidianURL(path: "relative.md"))
        for ok in ["a.md", "b.PDF", "c.docx", "d.png", "e.html"] { XCTAssertTrue(KnowledgeSourceActions.canOpenWithDefaultApp(ok), ok) }
        for no in ["run.command", "a.sh", "App.app", "x.pkg", "y.dmg", "z.scpt", "w.py", "noext", "t.terminal", "u.jar", "v.workflow"] { XCTAssertFalse(KnowledgeSourceActions.canOpenWithDefaultApp(no), no) }
        let kb = try tempDir("open"); try write(kb, "a.md", "x"); try write(kb, "d/b.md", "y")
        try FileManager.default.createSymbolicLink(at: kb.appendingPathComponent("l.md"), withDestinationURL: kb.appendingPathComponent("a.md"))
        XCTAssertNotNil(KnowledgeSourceActions.fileURL(root: kb.path, relative: "d/b.md"))
        for bad in ["l.md", "../x.md", "d/../../x", "/etc/passwd", "", "d", "missing.md"] { XCTAssertNil(KnowledgeSourceActions.fileURL(root: kb.path, relative: bad), bad) }
    }

    func testOpenCenterDeliversEachRequestOnceAndStableTargetsRepeat() {
        let center = KnowledgeSourceOpenCenter()
        XCTAssertNil(center.consume())
        let request = KnowledgeSourceOpenRequest(document: KnowledgeDocumentRef(sourceID: UUID(), relativePath: "a.md"), heading: "标题")
        center.post(request); XCTAssertEqual(center.consume(), request); XCTAssertNil(center.consume())
        let again = KnowledgeSourceOpenRequest(document: request.document)
        XCTAssertNotEqual(again, request, "a repeated click on the same target is a new request")
    }

    // MARK: 10. UI mounting (offscreen)

    private func settle(_ seconds: TimeInterval = 0.3) async { try? await Task.sleep(for: .seconds(seconds)); RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }

    private func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, dark: Bool, to url: URL?) async throws {
        let scheme: ColorScheme = dark ? .dark : .light
        let content = view.environment(\.colorScheme, scheme).frame(width: width, height: height).background(Color(nsColor: .windowBackgroundColor))
        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.appearance = host.appearance; window.contentView = host
        defer { window.contentView = nil; window.close() }
        window.orderBack(nil)        // `.task` 只在视图进入窗口层级后才启动
        for _ in 0..<12 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(150)) }
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(png.count, 1500)
        if let url { try png.write(to: url) }
    }

    func testPageMountsOnboardingAndBrowserReadOnlyAndSuggestionIsNeverAutoAdded() async throws {
        let kb = try buildKnowledgeTree()
        try write(kb, "示例.md", "---\ntitle: 渲染示例\ntype: note\ncreated: 2026-03-12\ntags: [示例, 渲染]\n---\n# 渲染示例\n\n正文含 **粗体**、*斜体*、`代码` 与 [[INDEX|索引页]]、[[不存在的页面]]。\n\n> [!note] 提示框\n> 这是 callout 内容。\n\n| 列 A | 列 B |\n|---|--:|\n| 1 | 2 |\n\n```swift\nlet value = 42 // 横向很长的一行代码用于检查水平滚动是否正常工作而不是撑破布局\n```\n\n- [x] 完成\n- [ ] 待办\n")
        let before = try fingerprint(kb)
        let shots = ProcessInfo.processInfo.environment["COSMOS_KB_SCREENSHOT_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let shots { try FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true) }
        // 空来源：引导 + 建议按钮；建议绝不自动添加。
        let emptyStore = KnowledgeSourceStore(storage: makeStorage(newStorageRoot()))
        let onboarding = KnowledgeSourcesRootView(store: emptyStore, suggestedFolder: kb)
        for dark in [false, true] { try await render(onboarding, width: 1180, height: 700, dark: dark, to: shots?.appendingPathComponent("onboarding-\(dark ? "dark" : "light").png")) }
        await settle()
        XCTAssertTrue(emptyStore.sources.isEmpty, "the suggestion must be clicked by the user")
        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyStore.location.root?.path ?? "/nonexistent"))
        // 有来源：浏览、阅读。
        let store = KnowledgeSourceStore(storage: makeStorage(newStorageRoot()))
        await store.reload(); _ = await store.add(folder: kb)
        let id = try XCTUnwrap(store.sources.first?.id); await store.waitForScan(id)
        KnowledgeSourceOpenCenter.shared.post(KnowledgeSourceOpenRequest(document: KnowledgeDocumentRef(sourceID: id, relativePath: "示例.md")))
        for dark in [false, true] {
            let page = KnowledgeSourcesRootView(store: store)
            try await render(page, width: 1280, height: 780, dark: dark, to: shots?.appendingPathComponent("reader-\(dark ? "dark" : "light").png"))
            KnowledgeSourceOpenCenter.shared.post(KnowledgeSourceOpenRequest(document: KnowledgeDocumentRef(sourceID: id, relativePath: "示例.md")))
        }
        try await render(KnowledgeSourcesRootView(store: store), width: 820, height: 640, dark: false, to: shots?.appendingPathComponent("reader-narrow-light.png"))
        XCTAssertEqual(try fingerprint(kb), before, "mounting the page never writes into the knowledge folder")
    }

    func testReaderRendersSourceViewGitPanelStatesAndExclusionPopover() async throws {
        let kb = try buildKnowledgeTree()
        try write(kb, "示例.md", "---\ntitle: 渲染示例\ntype: note\ncreated: 2026-03-12\ntags: [示例, 渲染]\n---\n# 渲染示例\n\n正文含 **粗体**、*斜体*、`代码` 与 [[INDEX|索引页]]、[[不存在的页面]]。\n\n> [!warning] 注意事项\n> 这是 callout 内容，包含**强调**。\n\n| 列 A | 列 B |\n|:--|--:|\n| 1 | 2 |\n| 长一点的内容 | 3 |\n\n```swift\nlet value = 42 // 横向很长的一行代码用于检查水平滚动是否正常工作而不是撑破布局，再多写一些字符让它超出\n```\n\n- [x] 完成\n- [ ] 待办\n  - 嵌套项\n")
        let src = source(kb), index = try KnowledgeSourceScanner.scan(source: src)
        let document = try XCTUnwrap(index.document(at: "示例.md"))
        let shots = ProcessInfo.processInfo.environment["COSMOS_KB_SCREENSHOT_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let shots { try FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true) }
        let before = try fingerprint(kb)
        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            try await render(KnowledgeDocumentReaderView(document: document, source: src, index: index, showSource: .constant(false), onOpenDocument: { _, _ in }, onOpenAttachment: { _ in }, onMessage: { _ in }),
                       width: 900, height: 720, dark: dark, to: shots?.appendingPathComponent("reader-only-\(suffix).png"))
            try await render(KnowledgeDocumentReaderView(document: document, source: src, index: index, showSource: .constant(true), onOpenDocument: { _, _ in }, onOpenAttachment: { _ in }, onMessage: { _ in }),
                       width: 900, height: 720, dark: dark, to: shots?.appendingPathComponent("source-text-\(suffix).png"))
            let when = Date(timeIntervalSince1970: 1_790_000_000)
            let commit = KnowledgeGitCommit(hash: "0123456789abcdef0123456789abcdef01234567", date: when, subject: "docs: 更新求职相关笔记")
            let cleanStatus = KnowledgeGitStatus(isRepository: true, branch: "main", upstream: "origin/main", lastCommit: commit, lastFetch: when)
            var dirty = cleanStatus; dirty.changedTracked = 2; dirty.untracked = 3
            var behind = cleanStatus; behind.behind = 4; behind.untracked = 1
            let panels = VStack(spacing: 16) {
                KnowledgeGitPanelView(status: cleanStatus, activity: .idle, result: nil)
                KnowledgeGitPanelView(status: dirty, activity: .idle, result: KnowledgeGitOperationResult(outcome: .blocked, message: "有 2 个已修改的跟踪文件；为避免覆盖，请先在终端处理。"))
                KnowledgeGitPanelView(status: behind, activity: .idle, result: KnowledgeGitOperationResult(outcome: .success, message: "Already up to date."))
                KnowledgeGitPanelView(status: behind, activity: .pulling, result: nil)
            }.padding(24)
            try await render(panels, width: 980, height: 720, dark: dark, to: shots?.appendingPathComponent("git-panel-\(suffix).png"))
            try await render(KnowledgeExclusionPopover(index: index), width: 440, height: 360, dark: dark, to: shots?.appendingPathComponent("exclusions-\(suffix).png"))
        }
        XCTAssertEqual(try fingerprint(kb), before)
    }
}

private extension Data {
    /// 文档里的日期是 ISO8601 字符串；这里只为让 `JSONDecoder` 的默认策略解析 schemaVersion 做一个无害替换。
    func replacingISODates() -> Data {
        guard var text = String(data: self, encoding: .utf8) else { return self }
        text = text.replacingOccurrences(of: #""addedAt" : "[^"]*""#, with: #""addedAt" : 0"#, options: .regularExpression)
        return Data(text.utf8)
    }
}
