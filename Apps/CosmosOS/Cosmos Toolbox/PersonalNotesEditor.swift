import AppKit
import Combine
import SwiftUI

@MainActor
final class PersonalNoteEditSession: ObservableObject, LearningEditSession {
    let store: PersonalNotesStore
    @Published var draft: PersonalNote
    @Published private(set) var baseline: PersonalNote?
    /// 已加入草稿、随下一次保存一并追加的引用。保存前可从草稿移除；保存后不可改写或删除。
    @Published private(set) var pendingReferences: [NoteReference] = []
    @Published var referenceName = ""
    @Published var linkText = ""
    @Published var correctionText = ""
    @Published var correctionTarget: UUID?
    @Published var message = ""
    @Published private(set) var saving = false
    @Published var terminationPending = false
    var systemOpen: (URL) -> Bool = { NSWorkspace.shared.open($0) }
    var copy: (String) -> Bool = { text in
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }
    private var cancellable: AnyCancellable?

    init(store: PersonalNotesStore, note: PersonalNote?) {
        self.store = store; baseline = note
        draft = note ?? PersonalNote(title: "")
        // 干净窗口跟随外部成功保存（列表收藏/归档、其它窗口的恢复）；有草稿时绝不替换。
        cancellable = store.$notes.sink { [weak self] notes in self?.adoptIfClean(notes) }
    }

    var hasUncommittedReferenceInput: Bool { !linkText.isEmpty || !referenceName.isEmpty || !correctionText.isEmpty }
    var isDirty: Bool {
        if !pendingReferences.isEmpty || hasUncommittedReferenceInput { return true }
        guard let baseline else {
            return !draft.title.isEmpty || !draft.body.isEmpty || draft.category != nil || draft.isFavorite || draft.isArchived
        }
        return !PersonalNote.sameText(draft.title, baseline.title) || !PersonalNote.sameText(draft.body, baseline.body)
            || !PersonalNote.sameText(draft.category, baseline.category)
            || draft.isFavorite != baseline.isFavorite || draft.isArchived != baseline.isArchived
    }

    private func adoptIfClean(_ notes: [PersonalNote]) {
        guard !saving, !isDirty, let baseline, let latest = notes.first(where: { $0.id == baseline.id }),
              latest != baseline else { return }
        self.baseline = latest; draft = latest
    }

    // MARK: Save

    func saveForClose() async -> Bool { await save() }
    @discardableResult func save() async -> Bool {
        guard !saving else { return false }
        guard !hasUncommittedReferenceInput else {
            message = "请先将链接或更正说明加入草稿，或清空未加入的输入；未保存。"; return false
        }
        saving = true; defer { saving = false }
        let candidate = draft, references = pendingReferences
        guard await store.save(candidate, newReferences: references, expected: baseline?.revision),
              let saved = store.notes.first(where: { $0.id == candidate.id }) else {
            message = store.error?.localizedDescription ?? "尚未完成读取或其他保存正在进行，草稿已保留。"; return false
        }
        baseline = saved; draft = saved; pendingReferences = []; message = "已保存。"
        return true
    }

    func reload() async {
        guard !saving else { return }
        await store.reload()
        guard store.loaded, let current = store.notes.first(where: { $0.id == draft.id }) else {
            message = store.error?.localizedDescription ?? "原笔记已不存在，草稿仍保留。"; return
        }
        baseline = current; draft = current; pendingReferences = []
        referenceName = ""; linkText = ""; correctionText = ""; correctionTarget = nil
        message = "已显式重新加载保存版本。"
    }

    // MARK: Body

    @discardableResult func copyBody() -> Bool {
        let ok = copy(draft.body)
        message = ok ? "已复制完整正文（仅正文原文）。" : "剪贴板写入失败，请重试。"
        return ok
    }

    // MARK: History

    @discardableResult func copyVersion(_ version: NoteVersion) -> Bool {
        let ok = copy(version.body)
        message = ok ? "已复制 v\(version.number) 的完整正文（仅正文原文）。" : "剪贴板写入失败，v\(version.number) 未复制，请重试。"
        return ok
    }

    /// 恢复不覆盖未保存草稿：窗口有任何未保存内容时拒绝。成功后生成新的当前内容版本，全部历史保留。
    @discardableResult func restore(_ version: NoteVersion) async -> Bool {
        guard let baseline else { message = "笔记尚未保存，没有可恢复的历史版本。"; return false }
        guard !saving else { return false }
        guard version.id != baseline.currentVersionID else { message = "这已是当前内容，无需恢复。"; return false }
        guard !isDirty else {
            message = "本窗口有未保存的草稿；请先保存或放弃草稿再恢复历史版本。草稿未被覆盖，未做任何恢复。"; return false
        }
        saving = true; defer { saving = false }
        switch await store.restore(noteID: baseline.id, versionID: version.id, expectedRevision: baseline.revision) {
        case .restored:
            if let saved = store.notes.first(where: { $0.id == baseline.id }) {
                self.baseline = saved; draft = saved
                message = "已将 v\(version.number) 的标题、正文、分类保存为新的当前内容版本 v\(saved.contentVersion ?? 0)；全部历史已保留。"
            }
            return true
        case .unchanged:
            message = "所选内容与当前内容完全相同，未新增版本。"; return false
        case .failed:
            message = (store.error?.localizedDescription ?? "恢复失败") + "（历史与现有内容未改变）"; return false
        }
    }

    // MARK: References

    func addLink() {
        let reference = NoteReference(kind: .link, name: referenceName.isEmpty ? linkText : referenceName, location: linkText)
        do {
            try reference.validate(); try ensureCapacity()
            pendingReferences.append(reference); linkText = ""; referenceName = ""
            message = "链接已加入草稿，保存后追加；不会抓取网页。"
        } catch { message = error.localizedDescription }
    }
    func addFile(_ url: URL) {
        let reference = NoteReference(kind: .file, name: url.lastPathComponent, location: url.path)
        do {
            try reference.validate(); try ensureCapacity()
            pendingReferences.append(reference)
            message = "文件路径已加入草稿；不会复制、移动或读取源文件。"
        } catch { message = error.localizedDescription }
    }
    func chooseFile() {
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        addFile(url)
    }
    func addCorrection() {
        guard let target = correctionTarget else { return }
        let reference = NoteReference(kind: .correction, name: "更正说明", notes: correctionText, correctsReferenceID: target)
        do {
            try reference.validate(); try ensureCapacity()
            pendingReferences.append(reference); correctionText = ""; correctionTarget = nil
            message = "更正说明已加入草稿，保存后追加；原引用记录不会被改写。"
        } catch { message = error.localizedDescription }
    }
    func removePending(_ id: UUID) { pendingReferences.removeAll { $0.id == id } }
    private func ensureCapacity() throws {
        guard (baseline?.references.count ?? 0) + pendingReferences.count < PersonalNotesLimits.referencesPerNote else {
            throw PersonalNotesError.capacityExceeded("该笔记引用已达 \(PersonalNotesLimits.referencesPerNote) 条上限")
        }
    }
    /// 仅在用户明确点击时调用；复用受控打开检查，并遵守 DEBUG 隔离根门控。失效引用保留并说明原因。
    func open(_ reference: NoteReference) {
        if let reason = store.location.openBlockReason(for: reference) { message = reason; return }
        do {
            let url = try reference.openURL()
            message = systemOpen(url) ? "已请求系统打开。" : "系统未能打开该引用，登记记录仍保留。"
        } catch { message = error.localizedDescription }
    }
}

struct PersonalNoteEditorView: View {
    enum Tab: String, CaseIterable { case body = "正文", history = "版本历史", references = "文件与链接" }
    @ObservedObject var session: PersonalNoteEditSession
    @ObservedObject var store: PersonalNotesStore
    @State private var tab: Tab
    @State private var confirmReload = false
    @State private var viewedVersionID: UUID?
    @State private var pendingRestore: NoteVersion?
    private static let timeText: Date.FormatStyle = .dateTime.year().month().day().hour().minute().second()

    init(session: PersonalNoteEditSession, store: PersonalNotesStore, initialTab: Tab = .body) {
        self.session = session; self.store = store; _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.baseline == nil ? "新建个人笔记" : "个人笔记").font(.title2)
                Spacer()
                Text(session.saving ? "保存中…" : session.isDirty ? "未保存" : "已保存").foregroundStyle(.secondary)
            }
            TextField("标题（必填）", text: $session.draft.title).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("note-editor-title")
            HStack {
                TextField("分类（可选，单一文本）", text: Binding(
                    get: { session.draft.category ?? "" }, set: { session.draft.category = $0.isEmpty ? nil : $0 }))
                    .accessibilityIdentifier("note-editor-category")
                Menu("已有分类") {
                    Button("未分类") { session.draft.category = nil }
                    ForEach(PersonalNotesQuery.categories(store.notes), id: \.self) { name in
                        Button(name) { session.draft.category = name }
                    }
                }
                Toggle("收藏", isOn: $session.draft.isFavorite)
                if session.baseline != nil { Toggle("归档", isOn: $session.draft.isArchived) }
            }
            if let saved = session.baseline {
                Text("创建 \(saved.createdAt.formatted(Self.timeText)) · 更新 \(saved.updatedAt.formatted(Self.timeText)) · 已保存 r\(saved.revision) · 内容 v\(saved.contentVersion ?? 0)\(saved.isArchived ? " · 已归档" : "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker("", selection: $tab) { ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented).labelsHidden()
            Group {
                switch tab {
                case .body: bodyTab
                case .history: historyTab
                case .references: referencesTab
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(session.message.isEmpty ? (store.error?.localizedDescription ?? "") : session.message)
                .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                .accessibilityIdentifier("note-editor-message")
            HStack {
                Button("复制完整正文", systemImage: "doc.on.doc") { session.copyBody() }
                    .accessibilityIdentifier("note-editor-copy")
                if session.baseline != nil { Button("重新加载保存版本…") { confirmReload = true } }
                Spacer()
                Button("保存") { Task { await session.save() } }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!store.canSave || session.saving).accessibilityIdentifier("note-editor-save")
            }
        }
        .padding(24).frame(minWidth: 720, minHeight: 560)
        .disabled(session.saving || session.terminationPending)
        .alert("放弃当前草稿并重新加载？", isPresented: $confirmReload) {
            Button("取消", role: .cancel) {}
            Button("重新加载", role: .destructive) { Task { await session.reload() } }
        } message: { Text("先复制需要保留的草稿；不会自动合并或覆盖磁盘版本，已保存的历史与引用保持原样。") }
    }

    // MARK: Body

    private var bodyTab: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("正文 · 纯文本 / Markdown 源文，不渲染、不联网、不执行脚本；空白与换行按原样保存，正文可暂时留空。")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $session.draft.body).font(.system(.body, design: .monospaced))
                .accessibilityIdentifier("note-editor-body")
                .overlay(Rectangle().stroke(Color(nsColor: .separatorColor)))
            Text("\(session.draft.body.utf8.count) / \(PersonalNotesLimits.bodyBytes) 字节").font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: History

    private var historyTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let note = session.baseline, let latest = note.versions.last {
                    Text("内容版本记录标题、正文、分类的实际变化；收藏、归档、恢复归档与文件/链接引用不产生内容版本。")
                        .font(.caption).foregroundStyle(.secondary)
                    let viewed = note.versions.first { $0.id == viewedVersionID } ?? latest
                    ForEach(note.versions.reversed()) { version in
                        Button { viewedVersionID = version.id } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("v\(version.number)\(version.id == note.currentVersionID ? " · 当前内容" : "")")
                                        .fontWeight(version.id == note.currentVersionID ? .semibold : .regular)
                                    Text(version.title).lineLimit(1)
                                    Spacer()
                                    if version.id == viewed.id { Image(systemName: "eye") }
                                }
                                Text(version.recordedAt.formatted(Self.timeText)).font(.caption).foregroundStyle(.secondary)
                            }.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).padding(6)
                        .background(version.id == viewed.id ? Color.accentColor.opacity(0.12) : Color.clear)
                        .accessibilityIdentifier("note-version-" + version.id.uuidString)
                    }
                    Divider()
                    Text("正在查看：v\(viewed.number) · \(viewed.title) · \(viewed.category ?? "未分类")").font(.subheadline)
                    Text(viewed.body).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.background)
                        .accessibilityIdentifier("note-version-body")
                    HStack {
                        Button("复制此版本正文（v\(viewed.number)）", systemImage: "doc.on.doc") { session.copyVersion(viewed) }
                            .accessibilityIdentifier("note-version-copy")
                        if viewed.id != note.currentVersionID {
                            Button("恢复此版本…", systemImage: "clock.arrow.circlepath") { pendingRestore = viewed }
                                .disabled(!store.canSave).accessibilityIdentifier("note-version-restore")
                        }
                    }
                } else {
                    Text("笔记保存后建立首个内容版本 v1。").foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .alert("将 v\(pendingRestore?.number ?? 0) 恢复为新的当前版本？", isPresented: Binding(
            get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })) {
            Button("取消", role: .cancel) { pendingRestore = nil }
            Button("恢复") {
                guard let version = pendingRestore else { return }
                pendingRestore = nil
                Task { if await session.restore(version) { viewedVersionID = nil } }
            }
        } message: { Text("所选版本的标题、正文、分类会保存为一个新的当前内容版本；全部历史保留，收藏、归档状态及文件/链接引用不变。") }
    }

    // MARK: References

    private func kindTitle(_ kind: NoteReference.Kind) -> String {
        switch kind { case .file: return "文件"; case .link: return "链接"; case .correction: return "更正" }
    }
    private func referenceRow(_ reference: NoteReference, pending: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(kindTitle(reference.kind)) · \(reference.name)").fontWeight(.medium)
                if pending { Text("待保存").font(.caption).foregroundStyle(.orange) }
                Spacer()
                if reference.kind != .correction { Button("打开") { session.open(reference) } }
                if pending { Button("移除") { session.removePending(reference.id) } }
                else if reference.kind != .correction {
                    Button("追加更正…") { session.correctionTarget = reference.id }
                }
            }
            if !reference.location.isEmpty { Text(reference.location).font(.caption).textSelection(.enabled) }
            if reference.kind == .correction {
                if let target = session.baseline?.references.first(where: { $0.id == reference.correctsReferenceID }) {
                    Text("更正对象：\(target.name)").font(.caption).foregroundStyle(.secondary)
                }
                Text(reference.notes).textSelection(.enabled)
            }
            if !pending { Text("登记于 " + reference.recordedAt.formatted(Self.timeText)).font(.caption).foregroundStyle(.secondary) }
            if let reason = reference.unavailableReason() { Text(reason).font(.caption).foregroundStyle(.orange) }
        }.padding(.vertical, 4)
    }
    private var referencesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("已保存的引用（只追加，不可改写或删除）").font(.headline)
                let saved = session.baseline?.references ?? []
                if saved.isEmpty { Text("尚无已保存的引用。").foregroundStyle(.secondary) }
                ForEach(saved) { referenceRow($0, pending: false); Divider() }
                if !session.pendingReferences.isEmpty {
                    Text("待保存（随下一次保存一并追加）").font(.headline)
                    ForEach(session.pendingReferences) { referenceRow($0, pending: true); Divider() }
                }
                if let target = session.correctionTarget,
                   let reference = session.baseline?.references.first(where: { $0.id == target }) {
                    Text("为「\(reference.name)」追加更正说明").font(.headline)
                    TextEditor(text: $session.correctionText).frame(minHeight: 70)
                        .overlay(Rectangle().stroke(Color(nsColor: .separatorColor)))
                    HStack {
                        Button("加入更正说明") { session.addCorrection() }.disabled(session.correctionText.isEmpty)
                        Button("取消") { session.correctionText = ""; session.correctionTarget = nil }
                    }
                }
                Button("选择文件引用…") { session.chooseFile() }.accessibilityIdentifier("note-reference-choose")
                TextField("链接名称（可选）", text: $session.referenceName)
                HStack {
                    TextField("http / https 链接", text: $session.linkText).accessibilityIdentifier("note-reference-link")
                    Button("加入链接") { session.addLink() }.accessibilityIdentifier("note-reference-add-link")
                }
                Text("只登记你选取的文件路径或链接：不复制、移动、删除文件，不读取文件内容，不抓取网页；点击「打开」才交给系统。失效引用会保留并说明原因。恢复历史正文不会撤销引用或更正记录；复制正文不含引用位置。核心备份只含引用登记记录，不含文件实体。")
                    .font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@MainActor
final class PersonalNoteWindowManager: NSObject, NSWindowDelegate, CosmosTerminationParticipant {
    static let shared = PersonalNoteWindowManager()
    private struct Entry {
        let controller: NSWindowController
        let session: PersonalNoteEditSession
        let titleSync: AnyCancellable
    }
    private var entries: [String: Entry] = [:]
    private var closing: Set<String> = [], approved: Set<String> = []
    private var pending = false
    var chooseClose: (PersonalNoteEditSession) -> LearningCloseChoice = { _ in
        let alert = NSAlert(); alert.messageText = "保存个人笔记的未完成修改？"
        alert.informativeText = "保存失败会保留草稿并阻止关闭。放弃只影响本窗口未保存内容。"
        alert.addButton(withTitle: "保存"); alert.addButton(withTitle: "放弃"); alert.addButton(withTitle: "取消")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }

    private func key(store: PersonalNotesStore, noteID: UUID) -> String { store.storageIdentity + "::note::" + noteID.uuidString }
    func hasWindow(store: PersonalNotesStore, noteID: UUID) -> Bool { entries[key(store: store, noteID: noteID)] != nil }
    func session(store: PersonalNotesStore, noteID: UUID) -> PersonalNoteEditSession? {
        entries[key(store: store, noteID: noteID)]?.session
    }
    func hasUnsavedDraft(store: PersonalNotesStore, noteID: UUID) -> Bool {
        session(store: store, noteID: noteID)?.isDirty ?? false
    }

    /// 同一存储与笔记身份只保留一个窗口；已有窗口直接置前。
    @discardableResult
    func open(store: PersonalNotesStore, note: PersonalNote?) -> PersonalNoteEditSession? {
        guard !pending else { return nil }
        let session = PersonalNoteEditSession(store: store, note: note)
        let key = key(store: store, noteID: session.draft.id)
        if let old = entries[key] { old.controller.window?.makeKeyAndOrderFront(nil); return old.session }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 880, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = note?.title ?? "新建个人笔记"
        window.identifier = NSUserInterfaceItemIdentifier(key)
        window.minSize = NSSize(width: 720, height: 600)
        window.contentViewController = NSHostingController(rootView: PersonalNoteEditorView(session: session, store: store))
        window.delegate = self; window.isReleasedWhenClosed = false
        let titleSync = session.$baseline.sink { [weak window] saved in
            if let saved { window?.title = saved.title }
        }
        let controller = NSWindowController(window: window)
        entries[key] = Entry(controller: controller, session: session, titleSync: titleSync)
        window.center(); controller.showWindow(nil)
        return session
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let key = sender.identifier?.rawValue, let entry = entries[key] else { return true }
        if approved.remove(key) != nil { return true }
        guard !pending, !entry.session.saving, !closing.contains(key) else { return false }
        guard entry.session.isDirty else { return true }
        closing.insert(key)
        let choice = chooseClose(entry.session)
        Task {
            if await entry.session.allowClose(choice: choice) { approved.insert(key); sender.performClose(nil) }
            closing.remove(key)
        }
        return false
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let key = window.identifier?.rawValue else { return }
        entries.removeValue(forKey: key); approved.remove(key); closing.remove(key)
    }

    var terminationBlocked: Bool { pending || !closing.isEmpty || entries.values.contains { $0.session.saving } }
    var hasUnsavedWork: Bool { entries.values.contains { $0.session.isDirty } }
    func freezeForTermination() { pending = true; for entry in entries.values { entry.session.terminationPending = true } }
    func unfreezeAfterTermination() { pending = false; for entry in entries.values { entry.session.terminationPending = false } }
    func resolveUnsavedWork() async -> Bool {
        for entry in Array(entries.values) where entry.session.isDirty {
            entry.controller.window?.makeKeyAndOrderFront(nil)
            if !(await entry.session.allowClose(choice: chooseClose(entry.session))) { return false }
        }
        return true
    }
}
