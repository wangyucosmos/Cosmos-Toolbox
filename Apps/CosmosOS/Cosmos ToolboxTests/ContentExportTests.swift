import AppKit
import CryptoKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

private final class ExportBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _stages: [ContentExportCheckpoint] = [], _mainThread: [Bool] = []
    func record(_ stage: ContentExportCheckpoint) { lock.lock(); _stages.append(stage); _mainThread.append(Thread.isMainThread); lock.unlock() }
    var stages: [ContentExportCheckpoint] { lock.lock(); defer { lock.unlock() }; return _stages }
    var anyOnMain: Bool { lock.lock(); defer { lock.unlock() }; return _mainThread.contains(true) }
}

@MainActor
final class ContentExportTests: XCTestCase {
    private var roots: [URL] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots = []; super.tearDown()
    }

    // MARK: Helpers

    private func uniqueRoot(_ name: String, create: Bool = false) -> URL {
        let url = URL(fileURLWithPath: "/private/tmp/CosmosContentExportTest-\(name)-" + UUID().uuidString, isDirectory: true)
        roots.append(url)
        if create { try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
        return url
    }
    private struct Env {
        let notes: PersonalNotesFileStorage, prompts: PromptVaultFileStorage
        let notesRoot: URL, promptsRoot: URL, out: URL, temp: URL
    }
    private func makeEnv() -> Env {
        let notesRoot = uniqueRoot("notes"), promptsRoot = uniqueRoot("prompts")
        return Env(notes: PersonalNotesFileStorage(root: notesRoot), prompts: PromptVaultFileStorage(root: promptsRoot),
                   notesRoot: notesRoot, promptsRoot: promptsRoot, out: uniqueRoot("out", create: true), temp: uniqueRoot("tmp", create: true))
    }
    private func service(_ env: Env, hook: @escaping @Sendable (ContentExportCheckpoint) throws -> Void = { _ in }) -> ContentExportService {
        var service = ContentExportService(libraries: ContentExportLibraries(notes: env.notes, prompts: env.prompts))
        service.checkpoint = hook; service.temporaryRoot = env.temp
        return service
    }
    @discardableResult
    private func addNote(_ env: Env, _ title: String, body: String = "正文", category: String? = nil, archived: Bool = false,
                         references: [NoteReference] = []) async throws -> PersonalNote {
        let draft = PersonalNote(title: title, body: body, category: category, isArchived: archived)
        let result = try await env.notes.apply(.save(draft, newReferences: references, expectedRevision: nil))
        return try XCTUnwrap(result.snapshot.notes.first { $0.id == draft.id })
    }
    @discardableResult
    private func editNote(_ env: Env, _ note: PersonalNote, _ change: (inout PersonalNote) -> Void,
                          references: [NoteReference] = []) async throws -> PersonalNote {
        var draft = note; change(&draft)
        let result = try await env.notes.apply(.save(draft, newReferences: references, expectedRevision: note.revision))
        return try XCTUnwrap(result.snapshot.notes.first { $0.id == note.id })
    }
    @discardableResult
    private func addPrompt(_ env: Env, _ name: String, body: String = "提示 {{变量}}", category: String? = nil, archived: Bool = false) async throws -> PromptTemplate {
        let template = PromptTemplate(name: name, body: body, category: category, isArchived: archived)
        let all = try await env.prompts.save(template, expectedRevision: nil)
        return try XCTUnwrap(all.first { $0.id == template.id })
    }
    @discardableResult
    private func editPrompt(_ env: Env, _ template: PromptTemplate, _ change: (inout PromptTemplate) -> Void) async throws -> PromptTemplate {
        var draft = template; change(&draft)
        let all = try await env.prompts.save(draft, expectedRevision: template.revision)
        return try XCTUnwrap(all.first { $0.id == template.id })
    }
    private func listing(_ url: URL) -> [String] { ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).sorted() }
    private func data(_ url: URL) throws -> Data { try Data(contentsOf: url) }
    private func hex(_ data: Data) -> String { ContentExportService.sha(data) }
    private func singleNote(_ note: PersonalNote, _ version: ContentExportSingleVersion? = nil) -> ContentExportSingleRequest {
        ContentExportSingleRequest(source: .personalNote, id: note.id, version: version ?? .current(expectedVersionID: note.currentVersionID))
    }
    private func singlePrompt(_ template: PromptTemplate, _ version: ContentExportSingleVersion? = nil) -> ContentExportSingleRequest {
        ContentExportSingleRequest(source: .promptTemplate, id: template.id, version: version ?? .current(expectedVersionID: template.versions.last?.id))
    }
    /// Snapshot of every file under a directory: names, bytes and modification times.
    private func tree(_ root: URL) -> [String: String] {
        var result: [String: String] = [:]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { return result }
        for case let url as URL in enumerator {
            let relative = String(url.path.dropFirst(root.path.count))
            let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0
            result[relative] = hex((try? Data(contentsOf: url)) ?? Data()) + "@\(mtime)"
        }
        return result
    }
    private func run(_ executable: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        return (process.terminationStatus, String(decoding: output, as: UTF8.self))
    }
    private let tricky = "\u{FEFF}  第一行 e\u{301}\r\n\t制表 😀  \r\n\n{{name}} \\{{字面}} 结尾空白   "

    private func exportSingle(_ env: Env, _ request: ContentExportSingleRequest, to name: String, service custom: ContentExportService? = nil) async throws -> (ContentExportResult, URL) {
        let svc = custom ?? service(env)
        let plan = try await svc.prepare(single: request)
        let url = env.out.appendingPathComponent(name)
        return (try await svc.export(plan: plan, to: url), url)
    }

    // MARK: 1. Single export — byte exact

    func testSingleCurrentMarkdownIsByteExactForNotesPromptsAndEmptyBody() async throws {
        let env = makeEnv()
        let note = try await addNote(env, "笔记", body: tricky)
        let empty = try await addNote(env, "空正文", body: "")
        let prompt = try await addPrompt(env, "提示词", body: tricky)
        for (index, (request, body)) in [(singleNote(note), tricky), (singleNote(empty), ""), (singlePrompt(prompt), tricky)].enumerated() {
            let (result, url) = try await exportSingle(env, request, to: "out\(index).md")
            XCTAssertEqual(try data(url), Data(body.utf8), "byte-exact body, no title / front matter / newline")
            XCTAssertEqual(result.byteCount, body.utf8.count)
            XCTAssertEqual(result.sha256, hex(Data(body.utf8)))
        }
        XCTAssertEqual(try data(env.out.appendingPathComponent("out1.md")).count, 0, "empty note exports an empty file")
        XCTAssertEqual(listing(env.out).filter { $0.hasPrefix(".") }, [], "no .part leftovers")
        XCTAssertEqual(listing(env.temp), [], "only this export's temp dir is created, and it is removed")
    }

    func testSingleHistoricalVersionExportsThatVersionNotCurrentBody() async throws {
        let env = makeEnv()
        var note = try await addNote(env, "多版本", body: "v1 body\r\n")
        let v1 = note.versions[0]
        note = try await editNote(env, note) { $0.body = "v2 body" }
        note = try await editNote(env, note) { $0.body = "v3 body e\u{301}" }
        let plan = try await service(env).prepare(single: singleNote(note, .specific(v1.id)))
        XCTAssertEqual(plan.suggestedFileName, "多版本_v1.md")
        let (_, url) = try await exportSingle(env, singleNote(note, .specific(v1.id)), to: "v1.md")
        XCTAssertEqual(try data(url), Data("v1 body\r\n".utf8))
        let missing = ContentExportSingleRequest(source: .personalNote, id: note.id, version: .specific(UUID()))
        do { _ = try await service(env).prepare(single: missing); XCTFail("unknown version must not fall back to current") }
        catch let error as ContentExportError { XCTAssertEqual(error, .versionMissing("多版本")) }

        var template = try await addPrompt(env, "提示词版本", body: "旧 {{x}}")
        let first = template.versions[0]
        template = try await editPrompt(env, template) { $0.body = "新 {{x}}" }
        let (_, promptURL) = try await exportSingle(env, singlePrompt(template, .specific(first.id)), to: "pv1.md")
        XCTAssertEqual(try data(promptURL), Data("旧 {{x}}".utf8))
    }

    func testLegacyPromptWithoutHistoryExportsCurrentAndNeverInventsVersions() async throws {
        let env = makeEnv()
        let legacy = PromptTemplate(name: "旧提示词", body: "旧内容 {{a}}\r\n", category: "旧")
        try FileManager.default.createDirectory(at: env.promptsRoot, withIntermediateDirectories: true)
        let raw = try JSONEncoder().encode(PromptVaultDocument(schemaVersion: 1, templates: [legacy]))
        try raw.write(to: env.prompts.primaryURL)
        let before = tree(env.promptsRoot)
        let (_, url) = try await exportSingle(env, ContentExportSingleRequest(source: .promptTemplate, id: legacy.id,
            version: .current(expectedVersionID: nil)), to: "legacy.md")
        XCTAssertEqual(try data(url), Data("旧内容 {{a}}\r\n".utf8))

        let svc = service(env)
        let plan = try await svc.prepare(batch: ContentExportBatchRequest(selections: [ContentExportSelection(source: .promptTemplate, id: legacy.id)], scope: .includeHistory))
        XCTAssertTrue(plan.preview.notices.contains { $0.contains("没有历史版本") })
        let zipURL = env.out.appendingPathComponent("legacy.zip")
        _ = try await svc.export(plan: plan, to: zipURL)
        let entries = try ContentExportZip.decode(data(zipURL))
        XCTAssertEqual(entries.map(\.path).filter { $0.hasSuffix(".md") && $0 != "说明.md" }.count, 1, "only current.md; no history files")
        let manifest = try JSONDecoder().decode(ContentExportManifest.self, from: try XCTUnwrap(entries.first { $0.path == "manifest.json" }).data)
        let file = try XCTUnwrap(manifest.items.first?.files.first)
        XCTAssertNil(file.versionID); XCTAssertNil(file.versionNumber); XCTAssertNil(file.savedAt); XCTAssertEqual(file.role, "current")
        XCTAssertEqual(tree(env.promptsRoot), before, "export must not upgrade or touch the legacy library")

        // A stale view that believed the legacy prompt had a version must stop, not silently swap.
        do { _ = try await svc.prepare(single: ContentExportSingleRequest(source: .promptTemplate, id: legacy.id, version: .current(expectedVersionID: UUID()))); XCTFail() }
        catch let error as ContentExportError { XCTAssertEqual(error, .sourceChanged("旧提示词")) }
    }

    // MARK: 2. Batch package — structure, manifest, independent unzip

    func testBatchArchiveStructureManifestHashesAndIndependentUnzip() async throws {
        let env = makeEnv()
        let sentinel = uniqueRoot("ref", create: true).appendingPathComponent("参考.txt")
        try Data("SENTINEL-SECRET".utf8).write(to: sentinel)
        let file = NoteReference(kind: .file, name: "参考.txt", location: sentinel.path)
        let link = NoteReference(kind: .link, name: "站点", location: "https://example.com/a?b=1")
        var a = try await addNote(env, "同名", body: "A1\r\n  e\u{301}", category: "工作", references: [file, link])
        a = try await editNote(env, a, { $0.body = "A2 😀" }, references: [NoteReference(kind: .correction, name: "更正说明", notes: "路径应为另一个", correctsReferenceID: file.id)])
        let b = try await addNote(env, "同名", body: "B1", archived: true)
        let weird = try await addNote(env, "a/b:c*?\"<>|", body: "weird")
        let dots = try await addNote(env, "..", body: "dots")
        let reserved = try await addNote(env, "CON", body: "reserved")
        let longName = try await addNote(env, String(repeating: "长", count: 150), body: "long")
        var p = try await addPrompt(env, "同名", body: "P1 {{x}}")
        p = try await editPrompt(env, p) { $0.body = "P2 {{x}} \\{{lit}}" }
        let pArchived = try await addPrompt(env, "归档提示", body: "arch", archived: true)

        let selections = [a, b, weird, dots, reserved, longName].map { ContentExportSelection(source: .personalNote, id: $0.id) }
            + [ContentExportSelection(source: .promptTemplate, id: p.id), ContentExportSelection(source: .promptTemplate, id: pArchived.id)]
        let svc = service(env)
        let plan = try await svc.prepare(batch: ContentExportBatchRequest(selections: selections, scope: .includeHistory))
        let zipURL = env.out.appendingPathComponent("batch.zip")
        let result = try await svc.export(plan: plan, to: zipURL)
        XCTAssertEqual(result.byteCount, try data(zipURL).count)

        // Expected files by stable identity: id -> [versionID? -> body]
        var expected: [String: [(role: String, version: Int?, body: String)]] = [:]
        let disk = try await env.notes.load().notes
        for note in disk where selections.contains(ContentExportSelection(source: .personalNote, id: note.id)) {
            expected[note.id.uuidString] = note.versions.map { ($0.id == note.currentVersionID ? "current" : "history", $0.number, $0.body) }
        }
        let diskPrompts = try await env.prompts.load()
        for template in diskPrompts { expected[template.id.uuidString] = template.versions.map { ($0.id == template.versions.last?.id ? "current" : "history", $0.number, $0.body) } }

        // (1) Swift strict decode + manifest
        let entries = try ContentExportZip.decode(data(zipURL))
        let paths = entries.map(\.path)
        XCTAssertEqual(Set(paths.map { $0.lowercased() }).count, paths.count, "no case-insensitive path collisions")
        for path in paths { XCTAssertTrue(ContentExportFileName.isSafeArchivePath(path), path) }
        XCTAssertTrue(paths.contains("说明.md")); XCTAssertTrue(paths.contains("manifest.json"))
        let manifest = try JSONDecoder().decode(ContentExportManifest.self, from: try XCTUnwrap(entries.first { $0.path == "manifest.json" }).data)
        XCTAssertEqual(manifest.exportFormat, "CosmosContentExport"); XCTAssertEqual(manifest.formatVersion, 1)
        XCTAssertEqual(manifest.history, "includeHistory"); XCTAssertFalse(manifest.isCoreBackup)
        XCTAssertEqual(manifest.items.count, 8)
        let byID = Dictionary(uniqueKeysWithValues: manifest.items.map { ($0.id, $0) })
        XCTAssertEqual(byID.count, 8, "same-named records stay distinct by stable id")
        let folders = Set(manifest.items.map { $0.files[0].path.split(separator: "/").dropLast().joined(separator: "/") })
        XCTAssertEqual(folders.count, 8, "same-named / sanitized names never share a folder")
        for (id, wanted) in expected {
            let item = try XCTUnwrap(byID[id], id)
            let current = try XCTUnwrap(item.files.first { $0.role == "current" })
            XCTAssertEqual(item.files.count, wanted.count)
            for file in item.files {
                let entry = try XCTUnwrap(entries.first { $0.path == file.path })
                XCTAssertEqual(file.sha256, hex(entry.data)); XCTAssertEqual(file.bytes, entry.data.count)
                let expectedBody = try XCTUnwrap(wanted.first { $0.version == file.versionNumber }).body
                XCTAssertEqual(entry.data, Data(expectedBody.utf8), "\(file.path) is the exact saved body")
                XCTAssertNotNil(file.savedAt); XCTAssertNotNil(file.versionID)
            }
            XCTAssertEqual(current.versionNumber, wanted.last?.version)
        }
        XCTAssertEqual(byID[a.id.uuidString]?.archived, false); XCTAssertEqual(byID[b.id.uuidString]?.archived, true)
        XCTAssertEqual(byID[pArchived.id.uuidString]?.archived, true)

        // (2) References: registered info only, exactly as stored; no entity read/packed.
        let storedA = try XCTUnwrap(disk.first { $0.id == a.id })
        let refs = try XCTUnwrap(byID[a.id.uuidString]?.references)
        XCTAssertEqual(refs.count, 3)
        for (manifestRef, stored) in zip(refs, storedA.references) {
            XCTAssertEqual(manifestRef.id, stored.id.uuidString); XCTAssertEqual(manifestRef.kind, stored.kind.rawValue)
            XCTAssertEqual(manifestRef.name, stored.name); XCTAssertEqual(manifestRef.location, stored.location)
            XCTAssertEqual(manifestRef.notes, stored.notes); XCTAssertEqual(manifestRef.correctsReferenceID, stored.correctsReferenceID?.uuidString)
            XCTAssertEqual(manifestRef.recordedAt, ContentExportTime.string(stored.recordedAt))
        }
        XCTAssertNil(byID[p.id.uuidString]?.references, "prompts carry no reference list")
        XCTAssertFalse(entries.contains { String(decoding: $0.data, as: UTF8.self).contains("SENTINEL-SECRET") }, "reference file content is never packed")
        XCTAssertEqual(try data(sentinel), Data("SENTINEL-SECRET".utf8))

        // (3) Independent unpack #1: macOS ditto, byte comparison of every manifest file.
        let dittoDir = uniqueRoot("ditto", create: true)
        let ditto = try run("/usr/bin/ditto", ["-x", "-k", zipURL.path, dittoDir.path])
        XCTAssertEqual(ditto.status, 0, ditto.output)
        for file in manifest.items.flatMap(\.files) {
            let extracted = try data(dittoDir.appendingPathComponent(file.path))
            XCTAssertEqual(hex(extracted), file.sha256, file.path)
        }
        // (4) Independent unpack #2: Python's stdlib zipfile (default settings), recomputing hashes against the manifest.
        let report = uniqueRoot("py", create: true).appendingPathComponent("report.json")
        let python = try run("/usr/bin/python3", ["-I", "-c", """
        import hashlib, json, struct, sys, zipfile
        archive, report = sys.argv[1:3]
        raw = open(archive, 'rb').read()
        out = {}
        with zipfile.ZipFile(archive) as z:
            assert z.testzip() is None
            for i in z.infolist():
                assert not i.is_dir()
                assert i.flag_bits & 0x800, i.filename
                assert i.compress_type == 0
                assert not i.filename.startswith('/') and '..' not in i.filename.split('/') and '\\\\' not in i.filename
            manifest = json.loads(z.read('manifest.json').decode('utf-8'))
            assert manifest['exportFormat'] == 'CosmosContentExport' and manifest['isCoreBackup'] is False
            for item in manifest['items']:
                for f in item['files']:
                    body = z.read(f['path'])
                    assert hashlib.sha256(body).hexdigest() == f['sha256'] and len(body) == f['bytes'], f['path']
                    out[f['path']] = hashlib.sha256(body).hexdigest()
        json.dump(out, open(report, 'w'))
        """, zipURL.path, report.path])
        XCTAssertEqual(python.status, 0, python.output)
        let pyReport = try JSONDecoder().decode([String: String].self, from: data(report))
        XCTAssertEqual(pyReport.count, manifest.items.flatMap(\.files).count)
        for file in manifest.items.flatMap(\.files) { XCTAssertEqual(pyReport[file.path], file.sha256) }
        // (5) The content package is not a core backup and core backup / restore refuse it.
        XCTAssertThrowsError(try CoreBackupService.verify(zipURL))
        XCTAssertThrowsError(try CoreRestoreService.prepare(zipURL))
        let manifestObject = try JSONSerialization.jsonObject(with: try XCTUnwrap(entries.first { $0.path == "manifest.json" }).data) as? [String: Any]
        XCTAssertNil(manifestObject?["format"], "no CosmosCoreMetadata marker")
    }

    func testCurrentOnlyBatchAndSelectionSemantics() async throws {
        let env = makeEnv()
        var note = try await addNote(env, "有历史", body: "old")
        note = try await editNote(env, note) { $0.body = "new" }
        let svc = service(env)
        do { _ = try await svc.prepare(batch: ContentExportBatchRequest(selections: [], scope: .currentOnly)); XCTFail() }
        catch let error as ContentExportError { XCTAssertEqual(error, .noSelection) }
        let selection = ContentExportSelection(source: .personalNote, id: note.id)
        let plan = try await svc.prepare(batch: ContentExportBatchRequest(selections: [selection, selection], scope: .currentOnly))
        XCTAssertEqual(plan.records.count, 1, "duplicates collapse")
        let url = env.out.appendingPathComponent("cur.zip")
        _ = try await svc.export(plan: plan, to: url)
        let entries = try ContentExportZip.decode(data(url))
        XCTAssertEqual(entries.filter { $0.path.contains("/history/") }.count, 0)
        XCTAssertEqual(try XCTUnwrap(entries.first { $0.path.hasSuffix("/current.md") }).data, Data("new".utf8))

        // Listing filter: archived and other-source rows only appear by explicit filter choice.
        let archivedNote = try await addNote(env, "归档笔记", archived: true)
        _ = archivedNote
        _ = try await addPrompt(env, "提示一")
        let rows = try await svc.listing(.personalNote) + (try await svc.listing(.promptTemplate))
        XCTAssertEqual(ContentExportListingFilter.apply(rows, source: nil, archived: false, search: "").count, 2)
        XCTAssertEqual(ContentExportListingFilter.apply(rows, source: .personalNote, archived: false, search: "").map(\.name), ["有历史"])
        XCTAssertEqual(ContentExportListingFilter.apply(rows, source: nil, archived: true, search: "").map(\.name), ["归档笔记"])
        XCTAssertEqual(ContentExportListingFilter.apply(rows, source: nil, archived: false, search: "提示").map(\.name), ["提示一"])
        XCTAssertEqual(rows.first { $0.name == "有历史" }?.contentVersion, 2)
    }

    // MARK: 3. Snapshot freezing and source changes

    func testSelectedSourceChangeStopsExportButUnrelatedChangesAreIgnored() async throws {
        let env = makeEnv()
        var a = try await addNote(env, "选中A", body: "a1")
        let b = try await addNote(env, "选中B", body: "b1")
        var other = try await addNote(env, "无关", body: "o1")
        let template = try await addPrompt(env, "无关提示")
        let selections = [a, b].map { ContentExportSelection(source: .personalNote, id: $0.id) }
        let svc = service(env)
        let plan = try await svc.prepare(batch: ContentExportBatchRequest(selections: selections, scope: .includeHistory))

        // Unrelated: edit another note, favorite a selected one (not exported), edit a prompt, add a record.
        other = try await editNote(env, other) { $0.body = "o2" }
        a = try await editNote(env, a) { $0.isFavorite = true }
        _ = try await editPrompt(env, template) { $0.body = "changed" }
        try await addNote(env, "新增", body: "n")
        let good = env.out.appendingPathComponent("ok.zip")
        _ = try await svc.export(plan: plan, to: good)
        let ids = Set(try JSONDecoder().decode(ContentExportManifest.self, from: try XCTUnwrap(ContentExportZip.decode(data(good)).first { $0.path == "manifest.json" }.map(\.data))).items.map(\.id))
        XCTAssertEqual(ids, Set([a.id, b.id].map(\.uuidString)))

        // Related: body edit, archive flag, added reference → each must stop with nothing published.
        let cases: [(String, (PersonalNote) async throws -> Void)] = [
            ("body", { _ = try await self.editNote(env, $0) { $0.body = "a-changed" } }),
            ("archive", { _ = try await self.editNote(env, $0) { $0.isArchived = true } }),
            ("reference", { _ = try await self.editNote(env, $0, { _ in }, references: [NoteReference(kind: .link, name: "x", location: "https://example.com")]) }),
            ("title", { _ = try await self.editNote(env, $0) { $0.title = "改名" } }),
        ]
        for (label, mutate) in cases {
            let current = try await env.notes.load().notes.first { $0.id == a.id }!
            let fresh = try await svc.prepare(batch: ContentExportBatchRequest(selections: [ContentExportSelection(source: .personalNote, id: a.id)], scope: .currentOnly))
            try await mutate(current)
            let url = env.out.appendingPathComponent("blocked-\(label).zip")
            do { _ = try await svc.export(plan: fresh, to: url); XCTFail("\(label) change must block export") }
            catch let error as ContentExportError { if case .sourceChanged = error {} else { XCTFail("\(label): \(error)") } }
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
        XCTAssertEqual(listing(env.out).filter { $0.hasPrefix("blocked") }, [])
        XCTAssertEqual(listing(env.temp), [])
    }

    func testSingleExportBoundToShownVersionAndSpecificVersionSurvivesLaterEdits() async throws {
        let env = makeEnv()
        var note = try await addNote(env, "单条", body: "s1")
        let shown = singleNote(note)                                            // UI showed v1 as current
        let pinned = singleNote(note, .specific(note.versions[0].id))
        let svc = service(env)
        let currentPlan = try await svc.prepare(single: shown)
        let pinnedPlan = try await svc.prepare(single: pinned)
        note = try await editNote(env, note) { $0.body = "s2" }
        do { _ = try await svc.export(plan: currentPlan, to: env.out.appendingPathComponent("c.md")); XCTFail("edited since prepare") }
        catch let error as ContentExportError { XCTAssertEqual(error, .sourceChanged("单条")) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: env.out.appendingPathComponent("c.md").path))
        _ = try await svc.export(plan: pinnedPlan, to: env.out.appendingPathComponent("p.md"))
        XCTAssertEqual(try data(env.out.appendingPathComponent("p.md")), Data("s1".utf8), "immutable history is unaffected")
        do { _ = try await svc.prepare(single: shown); XCTFail("stale view must not silently export a newer version") }
        catch let error as ContentExportError { XCTAssertEqual(error, .sourceChanged("单条")) }
    }

    func testReadOnlySourcesMissingLibrariesAndReadFailuresAreNotEmpty() async throws {
        let env = makeEnv()
        let svc = service(env)
        let rowsNotes = try await svc.listing(.personalNote), rowsPrompts = try await svc.listing(.promptTemplate)
        XCTAssertTrue(rowsNotes.isEmpty && rowsPrompts.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: env.notesRoot.path), "missing library is never created")
        XCTAssertFalse(FileManager.default.fileExists(atPath: env.promptsRoot.path))
        do { _ = try await svc.prepare(batch: ContentExportBatchRequest(selections: [ContentExportSelection(source: .personalNote, id: UUID())], scope: .currentOnly)); XCTFail() }
        catch let error as ContentExportError { if case .recordMissing = error {} else { XCTFail("\(error)") } }
        XCTAssertFalse(FileManager.default.fileExists(atPath: env.notesRoot.path))

        let note = try await addNote(env, "只读", body: "ro")
        var template = try await addPrompt(env, "只读提示", body: "ro")
        template = try await editPrompt(env, template) { $0.isFavorite = true }
        let before = (tree(env.notesRoot), tree(env.promptsRoot))
        let plan = try await svc.prepare(batch: ContentExportBatchRequest(selections: [
            ContentExportSelection(source: .personalNote, id: note.id), ContentExportSelection(source: .promptTemplate, id: template.id)], scope: .includeHistory))
        _ = try await svc.export(plan: plan, to: env.out.appendingPathComponent("ro.zip"))
        _ = try await exportSingle(env, singleNote(note), to: "ro.md")
        let after = (tree(env.notesRoot), tree(env.promptsRoot))
        XCTAssertEqual(before.0, after.0, "notes library: no new files / locks / backups / mtime changes")
        XCTAssertEqual(before.1, after.1, "prompt library untouched")

        try Data("{ broken".utf8).write(to: env.notes.primaryURL)
        do { _ = try await svc.listing(.personalNote); XCTFail("corrupt library must not read as empty") }
        catch let error as ContentExportError { if case .sourceUnavailable = error {} else { XCTFail("\(error)") } }
        XCTAssertEqual(try data(env.notes.primaryURL), Data("{ broken".utf8))
        let blocked = ContentExportService(libraries: ContentExportLibraries(notes: nil, prompts: nil, notesUnavailable: "位置被阻止"))
        do { _ = try await blocked.listing(.personalNote); XCTFail() } catch let error as ContentExportError { if case .sourceUnavailable = error {} else { XCTFail() } }
    }

    // MARK: 4. Publishing and failure protection

    func testExistingDestinationNeverOverwrittenIncludingRaces() async throws {
        let env = makeEnv()
        let note = try await addNote(env, "目标", body: "fresh")
        let svc = service(env)
        let plan = try await svc.prepare(single: singleNote(note))
        let existing = env.out.appendingPathComponent("exists.md")
        try Data("PRECIOUS".utf8).write(to: existing)
        do { _ = try await svc.export(plan: plan, to: existing); XCTFail() } catch let error as ContentExportError { XCTAssertEqual(error, .destinationExists) }
        XCTAssertEqual(try data(existing), Data("PRECIOUS".utf8))
        let dir = env.out.appendingPathComponent("folder.md"); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        do { _ = try await svc.export(plan: plan, to: dir); XCTFail() } catch let error as ContentExportError { XCTAssertEqual(error, .destinationExists) }
        let dangling = env.out.appendingPathComponent("dangling.md")
        try FileManager.default.createSymbolicLink(atPath: dangling.path, withDestinationPath: "/private/tmp/CosmosContentExportTest-nonexistent-\(UUID().uuidString)")
        do { _ = try await svc.export(plan: plan, to: dangling); XCTFail() } catch let error as ContentExportError { XCTAssertEqual(error, .destinationExists) }

        // Races: a same-named target appears after preparation / after the staging file is written.
        for stage in [ContentExportCheckpoint.beforePublish, .afterPartWritten] {
            let target = env.out.appendingPathComponent("race-\(stage).md")
            let racing = service(env) { current in
                if current == stage { try Data("COMPETITOR".utf8).write(to: target) }
            }
            do { _ = try await racing.export(plan: plan, to: target); XCTFail("\(stage)") }
            catch let error as ContentExportError { XCTAssertEqual(error, .destinationExists, "\(stage)") }
            XCTAssertEqual(try data(target), Data("COMPETITOR".utf8), "the competing file is never replaced")
        }
        XCTAssertEqual(listing(env.out).filter { $0.hasSuffix(".part") || $0.contains(".part") }, [], "no staging leftovers")
        XCTAssertEqual(listing(env.temp), [])
    }

    func testFailureAtEveryStageAndCancellationPublishNothing() async throws {
        let env = makeEnv()
        let note = try await addNote(env, "故障", body: "fault")
        let plan = try await service(env).prepare(batch: ContentExportBatchRequest(selections: [ContentExportSelection(source: .personalNote, id: note.id)], scope: .includeHistory))
        let stages: [ContentExportCheckpoint] = [.afterRecheck, .afterBuild, .afterVerify, .afterSecondRecheck, .beforePublish, .afterPartWritten]
        for stage in stages {
            let target = env.out.appendingPathComponent("fail-\(stage).zip")
            let failing = service(env) { current in if current == stage { throw NSError(domain: "inject", code: 7) } }
            do { _ = try await failing.export(plan: plan, to: target); XCTFail("\(stage) should fail") } catch {}
            XCTAssertFalse(FileManager.default.fileExists(atPath: target.path), "\(stage): no disguised success")
            XCTAssertEqual(listing(env.out), [], "\(stage): nothing left in the destination folder")
            XCTAssertEqual(listing(env.temp), [], "\(stage): own temp dir removed")
        }
        // Cancel before publish: nothing is published.
        for stage in [ContentExportCheckpoint.afterRecheck, .afterBuild, .afterSecondRecheck] {
            let token = ContentExportCancellation()
            let cancelling = service(env) { current in if current == stage { token.cancel() } }
            let target = env.out.appendingPathComponent("cancel-\(stage).zip")
            do { _ = try await cancelling.export(plan: plan, to: target, cancellation: token); XCTFail() }
            catch let error as ContentExportError { XCTAssertEqual(error, .cancelled, "\(stage)") }
            XCTAssertEqual(listing(env.out), []); XCTAssertEqual(listing(env.temp), [])
        }
        // Past the point of no return a cancel request cannot interrupt the publish.
        let late = ContentExportCancellation()
        let lateService = service(env) { current in if current == .afterPartWritten { late.cancel() } }
        let target = env.out.appendingPathComponent("late.zip")
        let result = try await lateService.export(plan: plan, to: target, cancellation: late)
        XCTAssertEqual(result.url.lastPathComponent, "late.zip"); XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
    }

    func testDestinationValidationAndSourceFolderProtection() async throws {
        let env = makeEnv()
        let note = try await addNote(env, "校验", body: "v")
        let svc = service(env)
        let single = try await svc.prepare(single: singleNote(note))
        let batch = try await svc.prepare(batch: ContentExportBatchRequest(selections: [ContentExportSelection(source: .personalNote, id: note.id)], scope: .currentOnly))
        for (plan, name) in [(single, "wrong.txt"), (batch, "wrong.md")] {
            do { _ = try await svc.export(plan: plan, to: env.out.appendingPathComponent(name)); XCTFail(name) }
            catch let error as ContentExportError { if case .destinationInvalid = error {} else { XCTFail("\(error)") } }
        }
        do { _ = try await svc.export(plan: single, to: env.out.appendingPathComponent("no/such/dir/x.md")); XCTFail() }
        catch let error as ContentExportError { if case .destinationInvalid = error {} else { XCTFail("\(error)") } }
        let before = tree(env.notesRoot)
        do { _ = try await svc.export(plan: single, to: env.notesRoot.appendingPathComponent("leak.md")); XCTFail("must not write into the source library") }
        catch let error as ContentExportError { if case .destinationInvalid = error {} else { XCTFail("\(error)") } }
        XCTAssertEqual(tree(env.notesRoot), before)
        XCTAssertEqual(ContentExportFileName.ensureExtension(URL(fileURLWithPath: "/tmp/a"), allowed: ["md"], default: "md").lastPathComponent, "a.md")
        XCTAssertEqual(ContentExportFileName.ensureExtension(URL(fileURLWithPath: "/tmp/a.MD"), allowed: ["md"], default: "md").lastPathComponent, "a.MD")
    }

    // MARK: 5. Names, ZIP codec, async state

    func testFileNameSanitizationNeverTouchesBodiesAndPathSafety() {
        XCTAssertEqual(ContentExportFileName.safeDisplay("a/b:c*?\"<>|\\x"), "a_b_c" + String(repeating: "_", count: 7) + "x")
        XCTAssertEqual(ContentExportFileName.safeDisplay(".."), "_")
        XCTAssertEqual(ContentExportFileName.safeDisplay(".hidden"), "_hidden")
        XCTAssertEqual(ContentExportFileName.safeDisplay("  "), "未命名")
        XCTAssertEqual(ContentExportFileName.safeDisplay("CON"), "CON_")
        XCTAssertEqual(ContentExportFileName.safeDisplay("a\u{202E}txt\n"), "a_txt_")
        XCTAssertEqual(ContentExportFileName.safeDisplay(String(repeating: "长", count: 150)).count, 40, "capped by bytes")
        XCTAssertLessThanOrEqual(ContentExportFileName.safeDisplay(String(repeating: "😀", count: 100)).utf8.count, 120)
        for bad in ["", "/abs", "a/../b", "a//b", "./a", "a\\b", "a/", "a\0b", "../x"] { XCTAssertFalse(ContentExportFileName.isSafeArchivePath(bad), bad) }
        for good in ["manifest.json", "notes/x--1/current.md", "说明.md"] { XCTAssertTrue(ContentExportFileName.isSafeArchivePath(good), good) }
    }

    func testZipCodecRoundTripAndRejectsTampering() throws {
        let entries: [(path: String, data: Data)] = [("a.txt", Data("x".utf8)), ("d/空.md", Data()), ("d/e.md", Data(repeating: 7, count: 1000))]
        let zip = try ContentExportZip.encode(entries, date: Date())
        let decoded = try ContentExportZip.decode(zip)
        XCTAssertEqual(decoded.map(\.path), entries.map(\.path)); XCTAssertEqual(decoded.map(\.data), entries.map(\.data))
        var corrupt = zip; corrupt[30 + 5] ^= 0xFF                             // first entry's body byte
        XCTAssertThrowsError(try ContentExportZip.decode(corrupt))
        XCTAssertThrowsError(try ContentExportZip.decode(zip.dropLast(1)))
        XCTAssertThrowsError(try ContentExportZip.decode(zip + Data([0])))
        XCTAssertThrowsError(try ContentExportZip.decode(Data()))
        XCTAssertThrowsError(try ContentExportZip.encode([("../x", Data())], date: Date()))
        XCTAssertThrowsError(try ContentExportZip.encode([("A.md", Data()), ("a.MD", Data())], date: Date()))
        XCTAssertThrowsError(try CoreBackupArchive.decode(zip), "core backup decoder refuses the content format")
    }

    func testControllerBusyStateDuplicateSubmissionAndCancelBoundary() async throws {
        let env = makeEnv()
        let note = try await addNote(env, "控制器", body: "c")
        let box = ExportBox()
        let gate = DispatchSemaphore(value: 0), reached = DispatchSemaphore(value: 0)
        var svc = service(env) { stage in
            box.record(stage)
            if stage == .afterBuild { reached.signal(); gate.wait() }
        }
        svc.temporaryRoot = env.temp
        let controller = ContentExportController(service: svc)
        var panelCalls = 0
        let target = env.out.appendingPathComponent("busy.zip")
        controller.chooseDestination = { _ in panelCalls += 1; return target }
        await controller.prepare(batch: ContentExportBatchRequest(selections: [ContentExportSelection(source: .personalNote, id: note.id)], scope: .currentOnly))
        XCTAssertEqual(controller.phase, .ready)
        let first = Task { await controller.exportPrepared() }
        let waited = await Task.detached { reached.wait(timeout: .now() + 20) }.value
        XCTAssertEqual(waited, .success)
        XCTAssertEqual(controller.phase, .exporting); XCTAssertTrue(controller.isBusy)
        await controller.exportPrepared()                                   // duplicate submission is ignored
        await controller.prepare(batch: ContentExportBatchRequest(selections: [], scope: .currentOnly))
        XCTAssertEqual(panelCalls, 1); XCTAssertEqual(controller.phase, .exporting)
        controller.cancel()
        XCTAssertTrue(controller.cancelRequested)
        gate.signal()
        await first.value
        XCTAssertEqual(controller.phase, .ready, "cancel before publish returns to a retryable preview")
        XCTAssertTrue(controller.message.contains("取消"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        XCTAssertFalse(box.anyOnMain, "recheck / build / verify / publish never run on the main thread")
        XCTAssertTrue(box.stages.contains(.afterBuild) && !box.stages.contains(.beforePublish))
        XCTAssertEqual(listing(env.out), []); XCTAssertEqual(listing(env.temp), [])
    }

    func testControllerOutcomesSuccessRevealFailureAndRePrepareRules() async throws {
        let env = makeEnv()
        var note = try await addNote(env, "结果", body: "r1")
        let controller = ContentExportController(service: service(env))
        // User dismisses the save panel: nothing exported, still retryable.
        controller.chooseDestination = { _ in nil }
        await controller.prepare(single: singleNote(note))
        await controller.exportPrepared()
        XCTAssertEqual(controller.phase, .ready); XCTAssertEqual(listing(env.out), [])
        // Existing name → refusal, state stays retryable with the frozen plan.
        let existing = env.out.appendingPathComponent("keep.md"); try Data("KEEP".utf8).write(to: existing)
        controller.chooseDestination = { _ in existing }
        await controller.exportPrepared()
        XCTAssertEqual(controller.phase, .ready); XCTAssertEqual(try data(existing), Data("KEEP".utf8))
        // Success; a Finder failure must not turn the finished export into a failure or delete the file.
        let target = env.out.appendingPathComponent("done.md")
        controller.chooseDestination = { _ in target }
        controller.reveal = { _ in false }
        await controller.exportPrepared()
        XCTAssertEqual(controller.phase, .succeeded); XCTAssertEqual(try data(target), Data("r1".utf8))
        controller.revealResult()
        XCTAssertEqual(controller.phase, .succeeded); XCTAssertTrue(controller.revealMessage.contains("导出已完成"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        // Source change after preparing → failed and the stale plan is dropped (re-prepare required).
        controller.reset()
        await controller.prepare(single: singleNote(note))
        note = try await editNote(env, note) { $0.body = "r2" }
        controller.chooseDestination = { _ in self.env_url(env, "stale.md") }
        await controller.exportPrepared()
        XCTAssertEqual(controller.phase, .failed); XCTAssertNil(controller.plan)
        XCTAssertFalse(FileManager.default.fileExists(atPath: env.out.appendingPathComponent("stale.md").path))
        await controller.exportPrepared()                                   // nothing prepared: ignored
        XCTAssertEqual(controller.phase, .failed)
    }
    private func env_url(_ env: Env, _ name: String) -> URL { env.out.appendingPathComponent(name) }

    func testLargeBatchBuildsOffMainThreadAndStaysExact() async throws {
        let env = makeEnv()
        var expected: [UUID: String] = [:]
        for index in 0..<6 {
            let body = String(repeating: "段落 \(index) e\u{301}\r\n", count: 45_000)        // ~630 KiB each
            expected[try await addNote(env, "大文件\(index)", body: body).id] = body
        }
        let box = ExportBox()
        let svc = service(env) { box.record($0) }
        let plan = try await svc.prepare(batch: ContentExportBatchRequest(selections: expected.keys.map { ContentExportSelection(source: .personalNote, id: $0) }, scope: .includeHistory))
        let url = env.out.appendingPathComponent("big.zip")
        let result = try await svc.export(plan: plan, to: url)
        XCTAssertGreaterThan(result.byteCount, 3_000_000)
        XCTAssertFalse(box.anyOnMain)
        let entries = try ContentExportZip.decode(data(url))
        for (id, body) in expected {
            let entry = try XCTUnwrap(entries.first { $0.path.hasSuffix("--\(id.uuidString.lowercased())/current.md") })
            XCTAssertEqual(entry.data, Data(body.utf8))
        }
    }

    func testBatchSheetMountsOffscreenWithoutWritingOrCreatingLibraries() async throws {
        let env = makeEnv()
        let libraries = ContentExportLibraries(notes: env.notes, prompts: env.prompts)
        let host = NSHostingView(rootView: ContentExportBatchSheet(libraries: libraries, initialSource: .promptTemplate))
        host.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds: 400_000_000)
        host.layoutSubtreeIfNeeded()
        XCTAssertFalse(FileManager.default.fileExists(atPath: env.notesRoot.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: env.promptsRoot.path))
        XCTAssertEqual(listing(env.out), [])
    }
}
