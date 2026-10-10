import SwiftUI
import Combine
import AppKit

final class PromptTemplateEditSession: ObservableObject {
    enum CloseChoice { case save, discard, cancel }
    @Published var draft: PromptTemplate
    @Published private(set) var baseline: PromptTemplate?
    @Published private(set) var message = ""
    @Published private(set) var saving = false
    @Published var terminationPending = false
    let store: PromptVaultStore
    init(store: PromptVaultStore, template: PromptTemplate?) {
        self.store = store; baseline = template
        draft = template ?? PromptTemplate(name: "", body: "")
    }
    var isDirty: Bool {
        guard let baseline else { return !draft.name.isEmpty || !draft.body.isEmpty || draft.category != nil }
        return Data(draft.body.utf8) != Data(baseline.body.utf8) || draft.name != baseline.name
            || draft.category != baseline.category || draft.isFavorite != baseline.isFavorite
            || draft.isArchived != baseline.isArchived
    }
    @discardableResult func save() async -> Bool {
        guard !saving else { return false }
        saving = true
        defer { saving = false }
        let candidate = draft
        guard await store.save(candidate, expectedRevision: baseline?.revision),
              let saved = store.templates.first(where: { $0.id == candidate.id }) else {
            message = store.error?.localizedDescription ?? "暂时无法保存，请等待加载／其他保存完成后重试。"
            return false
        }
        baseline = saved; draft = saved; message = "已保存。"
        return true
    }
    /// After a version restore: a clean editor follows the new saved content; a dirty draft is never touched.
    func adoptSavedIfClean(_ saved: PromptTemplate) {
        guard !saving, !isDirty, saved.id == draft.id else { return }
        baseline = saved; draft = saved
    }
    func reload() async {
        guard !saving else { return }
        await store.reload()
        guard store.loaded, let current = store.templates.first(where: { $0.id == draft.id }) else {
            message = store.error?.localizedDescription ?? "原模板已不存在，草稿仍保留。"; return
        }
        baseline = current; draft = current; message = "已显式重新加载保存版本。"
    }
    static func allowTermination(_ sessions: [PromptTemplateEditSession],
        choose: (PromptTemplateEditSession) -> CloseChoice) async -> Bool {
        for session in sessions {
            guard !session.saving else { return false }
            if session.isDirty, !(await session.allowClose(choice: choose(session))) { return false }
        }
        return true
    }
    func allowClose(choice: CloseChoice) async -> Bool {
        guard !saving else { return false }
        guard isDirty else { return true }
        switch choice {
        case .save: return await save()
        case .discard: return true
        case .cancel: return false
        }
    }
}

struct PromptTemplateEditorView: View {
    @ObservedObject var session: PromptTemplateEditSession
    @ObservedObject var store: PromptVaultStore
    @State private var confirmReload = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.baseline == nil ? "新建提示词模板" : "编辑提示词模板").font(.title2)
                Spacer()
                Text(session.saving ? "保存中…" : session.isDirty ? "未保存" : "已保存").foregroundStyle(.secondary)
            }
            TextField("名称", text: $session.draft.name)
            HStack {
                TextField("分类（可选）", text: Binding(get: { session.draft.category ?? "" }, set: { session.draft.category = $0 }))
                Menu("已有分类") {
                    Button("未分类") { session.draft.category = nil }
                    ForEach(Array(Set(store.templates.compactMap(\.category))).sorted(), id: \.self) { category in
                        Button(category) { session.draft.category = category }
                    }
                }
                Toggle("收藏", isOn: $session.draft.isFavorite)
            }
            Text("正文 · {{变量名}}；\\{{变量名}} 保留字面量。变量值不保存到模板。")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $session.draft.body).font(.system(.body, design: .monospaced))
                .accessibilityIdentifier("prompt-editor-body")
                .overlay(Rectangle().stroke(Color(nsColor: .separatorColor)))
            Text(session.message.isEmpty ? (store.error?.localizedDescription ?? "") : session.message)
                .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            HStack {
                Button("复制草稿正文") {
                    NSPasteboard.general.clearContents()
                    _ = NSPasteboard.general.setString(session.draft.body, forType: .string)
                }
                if session.baseline != nil {
                    Button("重新加载保存版本…") { confirmReload = true }
                }
                Spacer()
                Button("保存") { Task { await session.save() } }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!store.canSave || session.saving)
                    .accessibilityIdentifier("prompt-editor-save")
            }
        }
        .padding(24).frame(minWidth: 680, minHeight: 500)
        .disabled(session.saving || session.terminationPending)
        .alert("放弃当前草稿并重新加载？", isPresented: $confirmReload) {
            Button("取消", role: .cancel) {}
            Button("重新加载", role: .destructive) { Task { await session.reload() } }
        } message: { Text("先复制需要保留的草稿；不会自动合并或覆盖磁盘版本。") }
    }
}

final class PromptTemplateWindowManager: NSObject, NSWindowDelegate {
    static let shared = PromptTemplateWindowManager()
    private struct Entry { let controller: NSWindowController; let session: PromptTemplateEditSession }
    private var entries: [String: Entry] = [:]
    private var closing: Set<String> = []
    private var approved: Set<String> = []
    private var terminationPending = false

    private func keyPrefix(_ store: PromptVaultStore) -> String { store.storageIdentity + "::" }
    func hasUnsavedDraft(store: PromptVaultStore, templateID: UUID) -> Bool {
        entries[keyPrefix(store) + templateID.uuidString]?.session.isDirty ?? false
    }
    func syncCleanSession(store: PromptVaultStore, saved: PromptTemplate) {
        entries[keyPrefix(store) + saved.id.uuidString]?.session.adoptSavedIfClean(saved)
    }
    func open(store: PromptVaultStore, template: PromptTemplate?) {
        guard !terminationPending else { return }
        let session = PromptTemplateEditSession(store: store, template: template)
        let key = store.storageIdentity + "::" + session.draft.id.uuidString
        if let entry = entries[key] { entry.controller.window?.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = template?.name ?? "新建提示词模板"
        window.identifier = NSUserInterfaceItemIdentifier(key)
        window.minSize = NSSize(width: 700, height: 540)
        window.contentViewController = NSHostingController(rootView: PromptTemplateEditorView(session: session, store: store))
        window.delegate = self; window.isReleasedWhenClosed = false
        let controller = NSWindowController(window: window)
        entries[key] = Entry(controller: controller, session: session)
        window.center(); controller.showWindow(nil)
    }
    private func choice(for session: PromptTemplateEditSession) -> PromptTemplateEditSession.CloseChoice {
        let alert = NSAlert()
        alert.messageText = "保存未完成的模板修改？"
        alert.informativeText = "保存失败将保留草稿并阻止关闭。放弃只丢弃此窗口的未保存修改。"
        alert.addButton(withTitle: "保存"); alert.addButton(withTitle: "放弃"); alert.addButton(withTitle: "取消")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let key = sender.identifier?.rawValue, let entry = entries[key] else { return true }
        if approved.remove(key) != nil { return true }
        guard !terminationPending, !entry.session.saving, !closing.contains(key) else { return false }
        guard entry.session.isDirty else { return true }
        closing.insert(key)
        let decision = choice(for: entry.session)
        Task {
            if await entry.session.allowClose(choice: decision) {
                approved.insert(key); sender.performClose(nil)
            }
            closing.remove(key)
        }
        return false
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let key = window.identifier?.rawValue else { return }
        entries.removeValue(forKey: key); approved.remove(key); closing.remove(key)
    }
}

/// Quit protection is coordinated with the learning center (see `CosmosTerminationCoordinator`).
extension PromptTemplateWindowManager: CosmosTerminationParticipant {
    var terminationBlocked: Bool { terminationPending || !closing.isEmpty || entries.values.contains { $0.session.saving } }
    var hasUnsavedWork: Bool { entries.values.contains { $0.session.isDirty } }
    func freezeForTermination() {
        terminationPending = true
        for entry in entries.values { entry.session.terminationPending = true }
    }
    func unfreezeAfterTermination() {
        for entry in entries.values { entry.session.terminationPending = false }
        terminationPending = false
    }
    func resolveUnsavedWork() async -> Bool {
        let currentEntries = Array(entries.values)
        return await PromptTemplateEditSession.allowTermination(currentEntries.map(\.session)) { session in
            currentEntries.first(where: { $0.session === session })?.controller.window?.makeKeyAndOrderFront(nil)
            return self.choice(for: session)
        }
    }
}

final class CosmosPromptTerminationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        CosmosTerminationCoordinator.shared.request(
            participants: [PromptTemplateWindowManager.shared, LearningEditorWindowManager.shared, ProjectsWindowManager.shared, PersonalNoteWindowManager.shared]
        ) { allow in sender.reply(toApplicationShouldTerminate: allow) }
    }
}
