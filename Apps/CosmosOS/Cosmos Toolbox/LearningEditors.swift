import SwiftUI
import Combine
import AppKit

// MARK: - Edit sessions

enum LearningCloseChoice { case save, discard, cancel }

/// What a native editor window needs to expose for close / quit protection.
@MainActor
protocol LearningEditSession: AnyObject {
    var isDirty: Bool { get }
    var saving: Bool { get }
    var terminationPending: Bool { get set }
    func saveForClose() async -> Bool
}

extension LearningEditSession {
    /// Save / discard / cancel, shared by window close and quit. Never closes while a save is running.
    func allowClose(choice: LearningCloseChoice) async -> Bool {
        guard !saving else { return false }
        guard isDirty else { return true }
        switch choice {
        case .save: return await saveForClose()
        case .discard: return true
        case .cancel: return false
        }
    }
}

private func sameBytes(_ lhs: String, _ rhs: String) -> Bool { Data(lhs.utf8) == Data(rhs.utf8) }

final class LearningTopicEditSession: ObservableObject, LearningEditSession {
    let store: LearningStore
    let topicID: UUID
    private let newTopicCreatedAt = Date()
    @Published var name: String
    @Published var goal: String
    @Published var status: LearningStatus
    @Published var nextStep: String
    @Published var resource: String
    @Published private(set) var baseline: LearningTopic?
    @Published private(set) var message = ""
    @Published private(set) var saving = false
    @Published var terminationPending = false

    init(store: LearningStore, topic: LearningTopic?) {
        self.store = store; baseline = topic
        topicID = topic?.id ?? UUID()
        name = topic?.name ?? ""; goal = topic?.goal ?? ""; status = topic?.status ?? .planned
        nextStep = topic?.nextStep ?? ""; resource = topic?.resourceURL ?? ""
    }

    var isDirty: Bool {
        guard let baseline else {
            return !name.isEmpty || !goal.isEmpty || !nextStep.isEmpty || !resource.isEmpty || status != .planned
        }
        return !sameBytes(name, baseline.name) || !sameBytes(goal, baseline.goal)
            || !sameBytes(nextStep, baseline.nextStep) || !sameBytes(resource, baseline.resourceURL ?? "")
            || status != baseline.status
    }

    /// The whole draft as plain text, for the "copy draft" escape hatch after a failed save.
    var draftText: String {
        "名称：\(name)\n状态：\(status.title)\n目标：\n\(goal)\n下一步：\n\(nextStep)\n资料链接：\(resource)"
    }

    func saveForClose() async -> Bool { await save() }

    @discardableResult func save() async -> Bool {
        guard !saving else { return false }
        saving = true
        defer { saving = false }
        let candidate = LearningTopic(id: topicID, name: name, goal: goal, status: status, nextStep: nextStep,
            resourceURL: resource, createdAt: baseline?.createdAt ?? newTopicCreatedAt,
            revision: baseline?.revision ?? 1)
        guard await store.saveTopic(candidate, expectedRevision: baseline?.revision),
              let saved = store.topics.first(where: { $0.id == topicID }) else {
            message = store.error?.localizedDescription ?? "暂时无法保存，请等待加载／其他保存完成后重试。"
            return false
        }
        adopt(saved); message = "已保存。"
        return true
    }

    func reload() async {
        guard !saving else { return }
        await store.reload()
        guard store.loaded, let current = store.topics.first(where: { $0.id == topicID }) else {
            message = store.error?.localizedDescription ?? "原主题已不存在，草稿仍保留。"; return
        }
        adopt(current); message = "已显式重新加载保存版本。"
    }

    private func adopt(_ topic: LearningTopic) {
        baseline = topic
        name = topic.name; goal = topic.goal; status = topic.status
        nextStep = topic.nextStep; resource = topic.resourceURL ?? ""
    }
}

final class LearningEntryEditSession: ObservableObject, LearningEditSession {
    let store: LearningStore
    let topicID: UUID
    let entryID: UUID
    private let newEntryCreatedAt = Date()
    private let initialDay: LearningDay
    @Published private(set) var topicName: String
    @Published var day: LearningDay
    @Published var body: String
    @Published var durationText: String
    @Published var nextStep: String
    @Published private(set) var baseline: LearningEntry?
    /// The topic revision / next step this draft was started from; the combined save checks it.
    private var topicBaseline: (revision: Int, nextStep: String)
    @Published private(set) var message = ""
    @Published private(set) var saving = false
    @Published var terminationPending = false

    init(store: LearningStore, topic: LearningTopic, entry: LearningEntry?, today: LearningDay = .today()) {
        self.store = store; baseline = entry; topicID = topic.id
        entryID = entry?.id ?? UUID(); topicName = topic.name
        initialDay = entry?.studyDay ?? today
        day = entry?.studyDay ?? today; body = entry?.body ?? ""
        durationText = entry?.durationMinutes.map(String.init) ?? ""
        nextStep = topic.nextStep; topicBaseline = (topic.revision, topic.nextStep)
    }

    var isDirty: Bool {
        let nextStepChanged = !sameBytes(nextStep, topicBaseline.nextStep)
        guard let baseline else {
            return !body.isEmpty || !durationText.isEmpty || day != initialDay || nextStepChanged
        }
        return day != baseline.studyDay || !sameBytes(body, baseline.body)
            || durationText != (baseline.durationMinutes.map(String.init) ?? "") || nextStepChanged
    }

    var draftText: String { "日期：\(day.string)\n时长（分钟）：\(durationText)\n正文：\n\(body)\n下一步：\n\(nextStep)" }

    /// Blank means "not recorded"; anything else must be a whole number of minutes.
    func parseDuration() throws -> Int? {
        let text = durationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        let message = LearningError.invalidInput("时长须为 1–1440 的整数分钟，或留空。")
        guard text.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }), let value = Int(text),
              LearningLimits.durationMinutes.contains(value) else { throw message }
        return value
    }

    func saveForClose() async -> Bool { await save() }

    @discardableResult func save() async -> Bool {
        guard !saving else { return false }
        saving = true
        defer { saving = false }
        let duration: Int?
        do { duration = try parseDuration() }
        catch { message = error.localizedDescription; return false }
        let candidate = LearningEntry(id: entryID, topicID: topicID, studyDay: day, body: body,
            durationMinutes: duration, createdAt: baseline?.createdAt ?? newEntryCreatedAt,
            revision: baseline?.revision ?? 1)
        let update = sameBytes(nextStep, topicBaseline.nextStep) ? nil
            : LearningNextStepUpdate(expectedTopicRevision: topicBaseline.revision, nextStep: nextStep)
        guard await store.saveEntry(candidate, expectedRevision: baseline?.revision, nextStep: update),
              let saved = store.entries.first(where: { $0.id == entryID }) else {
            message = store.error?.localizedDescription ?? "暂时无法保存，请等待加载／其他保存完成后重试。"
            return false
        }
        adopt(saved); message = "已保存。"
        return true
    }

    func reload() async {
        guard !saving else { return }
        await store.reload()
        guard store.loaded, let current = store.entries.first(where: { $0.id == entryID }) else {
            message = store.error?.localizedDescription ?? "原记录已不存在，草稿仍保留。"; return
        }
        adopt(current); message = "已显式重新加载保存版本。"
    }

    private func adopt(_ entry: LearningEntry) {
        baseline = entry
        day = entry.studyDay; body = entry.body
        durationText = entry.durationMinutes.map(String.init) ?? ""
        if let topic = store.topics.first(where: { $0.id == topicID }) {
            topicName = topic.name; nextStep = topic.nextStep
            topicBaseline = (topic.revision, topic.nextStep)
        }
    }
}

// MARK: - Editor views

private struct LearningTextArea: View {
    let title: String
    let hint: String
    @Binding var text: String
    var minHeight: CGFloat = 80
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(hint).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $text).font(.body).frame(minHeight: minHeight)
                .overlay(Rectangle().stroke(Color(nsColor: .separatorColor)))
        }
    }
}

private func copyToPasteboard(_ text: String) {
    NSPasteboard.general.clearContents()
    _ = NSPasteboard.general.setString(text, forType: .string)
}

struct LearningTopicEditorView: View {
    @ObservedObject var session: LearningTopicEditSession
    @ObservedObject var store: LearningStore
    @State private var confirmReload = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.baseline == nil ? "新建学习主题" : "编辑学习主题").font(.title2)
                Spacer()
                Text(session.saving ? "保存中…" : session.isDirty ? "未保存" : "已保存").foregroundStyle(.secondary)
            }
            TextField("名称", text: $session.name).accessibilityIdentifier("learning-topic-name")
            Picker("状态", selection: $session.status) {
                ForEach(LearningStatus.allCases, id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            LearningTextArea(title: "学习目标（可选）", hint: "你想达到什么；按原文保存。", text: $session.goal)
            LearningTextArea(title: "下一步（可选）", hint: "下一次从哪里继续；由你填写，不会推断截止时间。",
                text: $session.nextStep, minHeight: 60)
            TextField("资料链接（可选，仅 http/https；只做引用，不会抓取或自动打开）", text: $session.resource)
            Text(session.message.isEmpty ? (store.error?.localizedDescription ?? "") : session.message)
                .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            HStack {
                Button("复制草稿") { copyToPasteboard(session.draftText) }
                if session.baseline != nil { Button("重新加载保存版本…") { confirmReload = true } }
                Spacer()
                Button("保存") { Task { await session.save() } }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!store.canSave || session.saving)
                    .accessibilityIdentifier("learning-topic-save")
            }
        }
        .padding(24).frame(minWidth: 560, minHeight: 540)
        .disabled(session.saving || session.terminationPending)
        .alert("放弃当前草稿并重新加载？", isPresented: $confirmReload) {
            Button("取消", role: .cancel) {}
            Button("重新加载", role: .destructive) { Task { await session.reload() } }
        } message: { Text("先复制需要保留的草稿；不会自动合并或覆盖磁盘版本。") }
    }
}

struct LearningEntryEditorView: View {
    @ObservedObject var session: LearningEntryEditSession
    @ObservedObject var store: LearningStore
    @State private var confirmReload = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.baseline == nil ? "记录学习" : "编辑学习记录").font(.title2)
                Spacer()
                Text(session.saving ? "保存中…" : session.isDirty ? "未保存" : "已保存").foregroundStyle(.secondary)
            }
            Text("主题：\(session.topicName)").foregroundStyle(.secondary)
            HStack {
                DatePicker("日期", selection: Binding(
                    get: { session.day.date() }, set: { session.day = LearningDay(date: $0) }),
                    displayedComponents: .date)
                TextField("时长（分钟，可选）", text: $session.durationText).frame(maxWidth: 180)
                    .accessibilityIdentifier("learning-entry-duration")
            }
            LearningTextArea(title: "学习内容／笔记", hint: "按原文保存，包括空白和换行。", text: $session.body,
                minHeight: 160)
            LearningTextArea(title: "下一步（可选，与本次记录一并保存）",
                hint: "只有修改此处，才会同时更新主题的下一步。", text: $session.nextStep, minHeight: 60)
            Text(session.message.isEmpty ? (store.error?.localizedDescription ?? "") : session.message)
                .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            HStack {
                Button("复制草稿") { copyToPasteboard(session.draftText) }
                if session.baseline != nil { Button("重新加载保存版本…") { confirmReload = true } }
                Spacer()
                Button("保存") { Task { await session.save() } }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!store.canSave || session.saving)
                    .accessibilityIdentifier("learning-entry-save")
            }
        }
        .padding(24).frame(minWidth: 600, minHeight: 600)
        .disabled(session.saving || session.terminationPending)
        .alert("放弃当前草稿并重新加载？", isPresented: $confirmReload) {
            Button("取消", role: .cancel) {}
            Button("重新加载", role: .destructive) { Task { await session.reload() } }
        } message: { Text("先复制需要保留的草稿；不会自动合并或覆盖磁盘版本。") }
    }
}

// MARK: - Native window manager

@MainActor
final class LearningEditorWindowManager: NSObject, NSWindowDelegate {
    static let shared = LearningEditorWindowManager()
    private struct Entry { let controller: NSWindowController; let session: any LearningEditSession }
    private var entries: [String: Entry] = [:]
    private var closing: Set<String> = []
    private var approved: Set<String> = []
    private(set) var terminationPending = false
    var openSessions: [any LearningEditSession] { entries.values.map(\.session) }
    /// Replaced in tests; production asks with a native alert.
    var chooseClose: (any LearningEditSession) -> LearningCloseChoice = { _ in LearningEditorWindowManager.askUser() }

    func openTopic(store: LearningStore, topic: LearningTopic?) {
        guard !terminationPending else { return }
        let session = LearningTopicEditSession(store: store, topic: topic)
        let key = store.storageIdentity + "::topic::" + session.topicID.uuidString
        present(key: key, title: topic?.name ?? "新建学习主题", session: session, size: NSSize(width: 640, height: 640),
            root: LearningTopicEditorView(session: session, store: store))
    }

    func openEntry(store: LearningStore, topic: LearningTopic, entry: LearningEntry?) {
        guard !terminationPending else { return }
        let session = LearningEntryEditSession(store: store, topic: topic, entry: entry)
        let key = store.storageIdentity + "::entry::" + session.entryID.uuidString
        present(key: key, title: (entry == nil ? "记录学习" : "编辑学习记录") + " · " + topic.name, session: session,
            size: NSSize(width: 700, height: 680), root: LearningEntryEditorView(session: session, store: store))
    }

    private func present<Content: View>(key: String, title: String, session: any LearningEditSession,
                                        size: NSSize, root: Content) {
        if let entry = entries[key] { entry.controller.window?.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = title
        window.identifier = NSUserInterfaceItemIdentifier(key)
        window.minSize = NSSize(width: 580, height: 520)
        window.contentViewController = NSHostingController(rootView: root)
        window.delegate = self; window.isReleasedWhenClosed = false
        let controller = NSWindowController(window: window)
        entries[key] = Entry(controller: controller, session: session)
        window.center(); controller.showWindow(nil)
    }

    private static func askUser() -> LearningCloseChoice {
        let alert = NSAlert()
        alert.messageText = "保存未完成的学习修改？"
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
        let decision = chooseClose(entry.session)
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

extension LearningEditorWindowManager: CosmosTerminationParticipant {
    var terminationBlocked: Bool {
        terminationPending || !closing.isEmpty || entries.values.contains { $0.session.saving }
    }
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
        for entry in Array(entries.values) where entry.session.isDirty {
            entry.controller.window?.makeKeyAndOrderFront(nil)
            if !(await entry.session.allowClose(choice: chooseClose(entry.session))) { return false }
        }
        return true
    }
}

// MARK: - Shared quit protection

/// A module that can hold unsaved editor drafts and takes part in application quit.
@MainActor
protocol CosmosTerminationParticipant: AnyObject {
    /// A save or close is already in flight, or a quit is already pending: quitting must be cancelled.
    var terminationBlocked: Bool { get }
    var hasUnsavedWork: Bool { get }
    /// Disables editing and refuses new editor windows until `unfreezeAfterTermination`.
    func freezeForTermination()
    func unfreezeAfterTermination()
    /// Asks about / saves every dirty draft. `false` means the user cancelled or a save failed.
    func resolveUnsavedWork() async -> Bool
}

/// Serializes one quit request over every participant and replies to AppKit exactly once.
@MainActor
final class CosmosTerminationCoordinator {
    static let shared = CosmosTerminationCoordinator()
    private(set) var pending = false

    func request(participants: [any CosmosTerminationParticipant],
                 reply: @escaping @MainActor (Bool) -> Void) -> NSApplication.TerminateReply {
        guard !pending, !participants.contains(where: { $0.terminationBlocked }) else { return .terminateCancel }
        guard participants.contains(where: { $0.hasUnsavedWork }) else { return .terminateNow }
        pending = true
        for participant in participants { participant.freezeForTermination() }
        Task { @MainActor in
            var allow = true
            for participant in participants where participant.hasUnsavedWork {
                if !(await participant.resolveUnsavedWork()) { allow = false; break }
            }
            for participant in participants { participant.unfreezeAfterTermination() }
            pending = false
            reply(allow)
        }
        return .terminateLater
    }
}
