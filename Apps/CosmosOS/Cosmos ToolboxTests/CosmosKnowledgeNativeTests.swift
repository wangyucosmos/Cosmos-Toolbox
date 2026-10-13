import AppKit
import SwiftUI
import XCTest
@testable import Cosmos_Toolbox

@MainActor
final class CosmosKnowledgeNativeTests: XCTestCase {
    private var notes: [PersonalNote] {
        [
            PersonalNote(title: "标题命中", body: "关键正文", category: "研发", isFavorite: true),
            PersonalNote(title: "第二条", body: "普通正文", category: "研发", isArchived: true),
            PersonalNote(title: "未分类", body: "关键正文", isFavorite: true, isArchived: true),
            PersonalNote(title: "另一类", body: "普通正文", category: "生活")
        ]
    }

    func testNoteFilterCombinationsMatchExistingQuery() {
        let saved = notes
        for category in [NoteCategoryFilter.all, .uncategorized, .named("研发"), .named("生活")] {
            for favorite in [false, true] {
                for archived in [false, true] {
                    for search in ["", "关键", " 标题命中 ", "不存在"] {
                        let filter = PersonalNotesListFilter(search: search, category: category,
                            favoritesOnly: favorite, archived: archived)
                        XCTAssertEqual(filter.matching(saved).map(\.id),
                            PersonalNotesQuery.filter(saved, search: search, category: category,
                                favoritesOnly: favorite, archived: archived).map(\.id))
                    }
                }
            }
        }
        XCTAssertEqual(PersonalNotesListFilter(search: "关键", category: .named("研发"), favoritesOnly: true).matching(saved).map(\.title), ["标题命中"])
    }

    func testClearNoteFiltersRestoresCurrentUnfilteredDefaults() {
        var filter = PersonalNotesListFilter(search: "关键", category: .named("研发"), favoritesOnly: true, archived: true)
        XCTAssertTrue(filter.isActive)
        PersonalNotesListFilter.clear(search: &filter.search, category: &filter.category,
            favoritesOnly: &filter.favoritesOnly, archived: &filter.archived)
        XCTAssertEqual(filter.search, "")
        XCTAssertEqual(filter.category, .all)
        XCTAssertFalse(filter.favoritesOnly)
        XCTAssertFalse(filter.archived)
        XCTAssertFalse(filter.isActive)
        XCTAssertTrue(filter.summary.isEmpty)
        XCTAssertEqual(Set(filter.matching(notes).map(\.title)), ["标题命中", "另一类"])
    }

    func testBlockedNoteStoreCannotRequestCreateFavoriteOrArchive() {
        let store = PersonalNotesStore(location: .init(root: nil, error: .unsafePath, isolated: true))
        XCTAssertFalse(store.canSave)
        var requested: [String] = []
        let actions = PersonalNotesUIActions(canSave: { store.canSave }, newNote: { requested.append("create") },
            favorite: { _ in requested.append("favorite") }, archive: { _ in requested.append("archive") })
        actions.create(); actions.setFavorite(notes[0]); actions.setArchived(notes[0])
        XCTAssertTrue(requested.isEmpty, "工具栏、行尾、右键与滑动入口共享实时不可写门控")
        XCTAssertTrue(store.notes.isEmpty)
    }

    func testNoteActionsUseLiveSaveGateAndPreserveRequestedIdentity() {
        var writable = true
        var created = 0
        var favorites: [UUID] = [], archives: [UUID] = []
        let note = notes[0]
        let actions = PersonalNotesUIActions(canSave: { writable }, newNote: { created += 1 },
            favorite: { favorites.append($0.id) }, archive: { archives.append($0.id) })
        actions.create(); actions.setFavorite(note); actions.setArchived(note)
        XCTAssertEqual(created, 1); XCTAssertEqual(favorites, [note.id]); XCTAssertEqual(archives, [note.id])
        writable = false
        actions.create(); actions.setFavorite(note); actions.setArchived(note)
        XCTAssertEqual(created, 1); XCTAssertEqual(favorites, [note.id]); XCTAssertEqual(archives, [note.id])
    }

    func testKnowledgeSectionBindingIsBidirectionalAndLeavesSearchFocusUntouched() {
        let navigator = CosmosNavigator()
        navigator.selection = .knowledgeBase
        navigator.requestSearchFocus()
        let serial = navigator.searchFocusRequest
        let selection = CosmosKnowledgeDestinationView.sectionBinding(navigator: navigator)
        for section in [CosmosKnowledgeSection.notes, .assets, .sources] {
            selection.wrappedValue = section
            XCTAssertEqual(navigator.knowledgeSection, section)
            navigator.knowledgeSection = .notes
            XCTAssertEqual(selection.wrappedValue, .notes)
            XCTAssertEqual(navigator.selection, .knowledgeBase)
            XCTAssertEqual(navigator.searchFocusRequest, serial)
            XCTAssertTrue(navigator.searchFocusRequested)
        }
    }

    func testNativeNotesListAndToolbarMountPreserveTemporaryLibrary() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/CosmosPersonalNotesPhase1-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PersonalNotesStore(location: .init(root: root, error: nil, isolated: true))
        await store.reload()
        let saved = await store.save(PersonalNote(title: "原生笔记夹具", body: "# 合成正文\n\n只用临时根。", category: "测试"), expected: nil)
        XCTAssertTrue(saved)
        let file = root.appendingPathComponent("notes.json")
        let before = try Data(contentsOf: file)
        let suite = "CosmosKnowledgeNativeTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = CosmosUIPreferences(defaults: defaults)
        preferences.motion = .reduced
        let content = PersonalNotesView(store: store).environment(\.cosmosPreferences, preferences)
            .defaultAppStorage(defaults).frame(width: 1100, height: 800)
        let window = CosmosWindowFactory.makeWindow(
            .init(title: "合成笔记", contentSize: NSSize(width: 1100, height: 800), minSize: NSSize(width: 800, height: 600)),
            rootView: content)
        defer { window.contentViewController = nil; window.close() }
        let view = try XCTUnwrap(window.contentViewController?.view)
        view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(250))
        view.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(view.fittingSize.height, 0)
        XCTAssertEqual(try Data(contentsOf: file), before)
        XCTAssertEqual(store.notes.count, 1)
    }
}
