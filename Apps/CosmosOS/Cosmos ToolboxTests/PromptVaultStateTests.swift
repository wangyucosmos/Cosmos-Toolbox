import XCTest
import AppKit
import SwiftUI
@testable import Cosmos_Toolbox

@MainActor
final class PromptVaultStateTests: XCTestCase {
    var roots: [URL] = []
    override func tearDown() {
        for root in roots { try? FileManager.default.removeItem(at: root) }
        roots = []; super.tearDown()
    }
    func makeStore() async -> PromptVaultStore {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosPromptVaultPhase1-" + UUID().uuidString)
        roots.append(root)
        let store = PromptVaultStore(root: root); await store.reload(); return store
    }
    func testSearchCategoryFavoriteArchiveAndRestore() async {
        let store = await makeStore()
        var a = PromptTemplate(name: "策划", body: "活动说明", category: "工作", isFavorite: true)
        let b = PromptTemplate(name: "研发", body: "交接说明")
        _ = await store.save(a, expectedRevision: nil); _ = await store.save(b, expectedRevision: nil)
        let model = PromptVaultViewModel(copy: { _ in true })
        model.query = "活动"; XCTAssertEqual(model.filtered(store.templates).map(\.id), [a.id])
        model.query = ""; model.category = "未分类"; XCTAssertEqual(model.filtered(store.templates).map(\.id), [b.id])
        model.category = ""; model.favoritesOnly = true; XCTAssertEqual(model.filtered(store.templates).map(\.id), [a.id])
        a = store.templates.first { $0.id == a.id }!
        await store.setArchived(a)
        XCTAssertTrue(model.filtered(store.templates).isEmpty)
        model.showArchived = true; XCTAssertEqual(model.filtered(store.templates).map(\.id), [a.id])
        a = store.templates.first { $0.id == a.id }!
        await store.setArchived(a)
        model.showArchived = false; XCTAssertEqual(model.filtered(store.templates).map(\.id), [a.id])
        a = store.templates.first { $0.id == a.id }!
        await store.setFavorite(a); XCTAssertTrue(model.filtered(store.templates).isEmpty)
    }
    func testVariableSessionAndSavedDraftIsolationReconcile() async {
        let store = await makeStore()
        let a = PromptTemplate(name: "A", body: "{{保留}}/{{删除}}"), b = PromptTemplate(name: "B", body: "{{保留}}")
        _ = await store.save(a, expectedRevision: nil); _ = await store.save(b, expectedRevision: nil)
        let model = PromptVaultViewModel(copy: { _ in true })
        let variables = PromptTemplateRenderer(a.body).variables
        model.setValue("a", variable: variables[0], templateID: a.id)
        model.setValue("old", variable: variables[1], templateID: a.id)
        model.selectedID = b.id; XCTAssertEqual(model.rendered(b).missing, ["保留"])
        model.query = "nothing"; model.category = "unknown"; model.favoritesOnly = true
        XCTAssertEqual(model.values[a.id]?[variables[0].id], "a")
        let session = PromptTemplateEditSession(store: store, template: a)
        session.draft.body = "{{保留}}/{{新增}}"
        XCTAssertEqual(store.templates.first { $0.id == a.id }?.body, a.body)
        XCTAssertEqual(model.rendered(a).text, "a/old")
        let saved = await session.save(); XCTAssertTrue(saved)
        model.reconcile(store.templates)
        XCTAssertEqual(model.values[a.id]?[variables[0].id], "a")
        XCTAssertNil(model.values[a.id]?[variables[1].id])
        XCTAssertEqual(model.rendered(session.draft).missing, ["新增"])
        model.clearSession(); XCTAssertTrue(model.values.isEmpty)
    }
    func testNamedPasteboardExactAndMissingDoesNotWrite() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("CosmosPromptTests-" + UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("sentinel", forType: .string)
        let model = PromptVaultViewModel(copy: { text in
            pasteboard.clearContents(); return pasteboard.setString(text, forType: .string)
        })
        let template = PromptTemplate(name: "n", body: "\t\r\n{{值}} \\{{字面}}\n ")
        let change = pasteboard.changeCount
        XCTAssertFalse(model.copyResult(template)); XCTAssertEqual(pasteboard.changeCount, change)
        model.setValue(" 😀 {{other}} \n", variable: PromptTemplateRenderer(template.body).variables[0], templateID: template.id)
        XCTAssertTrue(model.copyResult(template))
        XCTAssertEqual(Data((pasteboard.string(forType: .string) ?? "").utf8), Data("\t\r\n 😀 {{other}} \n {{字面}}\n ".utf8))
        model.copyOriginal(template)
        XCTAssertEqual(Data((pasteboard.string(forType: .string) ?? "").utf8), Data(template.body.utf8))
    }
    func testTwoEditingSessionsConflictAndExplicitReload() async {
        let store = await makeStore(), item = PromptTemplate(name: "n", body: "initial")
        _ = await store.save(item, expectedRevision: nil)
        let a = PromptTemplateEditSession(store: store, template: item), b = PromptTemplateEditSession(store: store, template: item)
        a.draft.body = "first"; b.draft.body = "second"
        let savedA = await a.save(), savedB = await b.save()
        XCTAssertTrue(savedA); XCTAssertFalse(savedB); XCTAssertEqual(store.error, .conflict)
        XCTAssertEqual(b.draft.body, "second"); XCTAssertTrue(b.isDirty)
        await b.reload(); XCTAssertEqual(b.draft.body, "first"); XCTAssertFalse(b.isDirty)
    }
    func testCloseAndTerminationSaveDiscardCancelAndFailure() async {
        let store = await makeStore()
        let session = PromptTemplateEditSession(store: store, template: nil)
        session.draft.name = "n"; session.draft.body = "draft"
        let cancel = await session.allowClose(choice: .cancel), discard = await session.allowClose(choice: .discard)
        XCTAssertFalse(cancel); XCTAssertTrue(discard); XCTAssertTrue(session.isDirty)
        let save = await session.allowClose(choice: .save)
        XCTAssertTrue(save); XCTAssertFalse(session.isDirty)
        let other = PromptTemplateEditSession(store: store, template: session.draft)
        other.draft.body = "   "
        let blocked = await PromptTemplateEditSession.allowTermination([session, other], choose: { _ in .save })
        XCTAssertFalse(blocked); XCTAssertTrue(other.isDirty)
        let canceled = await PromptTemplateEditSession.allowTermination([other], choose: { _ in .cancel })
        XCTAssertFalse(canceled)
        let abandoned = await PromptTemplateEditSession.allowTermination([other], choose: { _ in .discard })
        XCTAssertTrue(abandoned)
    }
    func testByteExactDirtyDetection() async {
        let store = await makeStore(), template = PromptTemplate(name: "n", body: "é")
        let session = PromptTemplateEditSession(store: store, template: template)
        session.draft.body = "e\u{301}"
        XCTAssertTrue(session.isDirty)
    }
    func testDebugLocationFailClosed() {
        let bundle = "com.wangyucosmos.cosmostoolbox.persistenceui.prompttests"
        let root = "/private/tmp/CosmosPromptVaultPhase1-" + UUID().uuidString
        let flag = "--cosmos-prompt-fixture-root"
        XCTAssertNil(PromptVaultLocation.resolve(isIsolated: true, bundleIdentifier: bundle, arguments: []).root)
        XCTAssertNil(PromptVaultLocation.resolve(isIsolated: true, bundleIdentifier: "com.wangyucosmos.Cosmos-Toolbox", arguments: [flag, root]).root)
        XCTAssertNil(PromptVaultLocation.resolve(isIsolated: false, bundleIdentifier: bundle, arguments: [flag, root]).root)
        XCTAssertNil(PromptVaultLocation.resolve(isIsolated: true, bundleIdentifier: bundle, arguments: [flag, "/tmp/unapproved"]).root)
        XCTAssertEqual(PromptVaultLocation.resolve(isIsolated: true, bundleIdentifier: bundle, arguments: [flag, root]).root?.path, root)
    }
    func testNoExistingBusinessWritesAndOffscreenView() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosPromptVaultPhase1-" + UUID().uuidString)
        roots.append(root)
        // The test host must use the temporary Bundle ID supplied by the verification command.
        XCTAssertTrue(Bundle.main.bundleIdentifier?.hasPrefix("com.wangyucosmos.cosmostoolbox.persistenceui.") == true)
        let defaults = UserDefaults.standard
        let key = "cosmos.zhuowang.campaigns.v1"
        let original = defaults.object(forKey: key)
        defer {
            if let original { defaults.set(original, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        defaults.set(Data("sentinel".utf8), forKey: key)
        let before = defaults.dictionaryRepresentation().filter { $0.key.hasPrefix("cosmos.zhuowang.") }
            .compactMapValues { $0 as? Data }
        let store = PromptVaultStore(root: root); await store.reload()
        _ = await store.save(PromptTemplate(name: "n", body: "{{值}}"), expectedRevision: nil)
        let after = defaults.dictionaryRepresentation().filter { $0.key.hasPrefix("cosmos.zhuowang.") }
            .compactMapValues { $0 as? Data }
        XCTAssertEqual(after, before)
        let renderer = ImageRenderer(content: PromptVaultView(location: PromptVaultLocation(root: root, error: nil)).frame(width: 1060, height: 700))
        let image = try XCTUnwrap(renderer.nsImage)
        let representation = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        try png.write(to: root.appendingPathComponent("offscreen.png"))
        XCTAssertGreaterThan(png.count, 1000)
    }
}
