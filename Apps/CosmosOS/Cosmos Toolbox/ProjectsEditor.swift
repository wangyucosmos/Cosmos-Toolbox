import AppKit
import Combine
import SwiftUI

@MainActor
final class ProjectsEditSession: ObservableObject, LearningEditSession {
    let store: ProjectsStore
    @Published var draft: PersonalProject
    @Published var progressText = ""
    @Published var referenceName = ""
    @Published var linkText = ""
    @Published var message = ""
    @Published private(set) var baseline: PersonalProject?
    @Published private(set) var saving = false
    @Published var terminationPending = false
    init(store: ProjectsStore, project: PersonalProject?) {
        self.store = store; baseline = project; draft = project ?? PersonalProject(name: "")
    }
    var isDirty: Bool {
        if !progressText.isEmpty || !linkText.isEmpty || !referenceName.isEmpty { return true }
        guard let baseline else { return !draft.name.isEmpty || !draft.goal.isEmpty || !draft.nextStep.isEmpty || draft.status != .planned || draft.isArchived || !draft.references.isEmpty }
        return (try? ProjectsCoding.encoder().encode(draft)) != (try? ProjectsCoding.encoder().encode(baseline))
    }
    func addLink() {
        let reference = ProjectReference(kind: .link, name: referenceName.isEmpty ? linkText : referenceName, location: linkText)
        do { try reference.validate(); draft.references.append(reference); linkText = ""; referenceName = ""; message = "链接已加入草稿，保存后持久化。" }
        catch { message = error.localizedDescription }
    }
    func chooseFile() {
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        draft.references.append(ProjectReference(kind: .file, name: url.lastPathComponent, location: url.path))
        message = "文件路径已加入草稿；不会复制或移动源文件。"
    }
    func open(_ reference: ProjectReference) {
        if let reason = reference.availability() { message = reason; return }
        guard let url = reference.url, NSWorkspace.shared.open(url) else { message = "系统未能打开该引用，引用仍保留。"; return }
        message = "已请求系统打开。"
    }
    func saveForClose() async -> Bool { await save() }
    @discardableResult func save() async -> Bool {
        guard !saving else { return false }
        guard linkText.isEmpty, referenceName.isEmpty else { message = "请先将链接加入草稿，或清空未加入的链接输入。"; return false }
        saving = true; defer { saving = false }
        var candidate = draft
        if !progressText.isEmpty { candidate.progress.append(ProjectProgress(body: progressText)) }
        guard await store.save(candidate, expected: baseline?.revision), let saved = store.projects.first(where: { $0.id == candidate.id }) else {
            message = store.error?.localizedDescription ?? "尚未完成读取或其他保存正在进行，草稿保留。"; return false
        }
        baseline = saved; draft = saved; progressText = ""; message = "已保存。"; return true
    }
    func reload() async {
        await store.reload()
        guard store.loaded, let current = store.projects.first(where: { $0.id == draft.id }) else { message = store.error?.localizedDescription ?? "项目已不存在，草稿仍保留。"; return }
        draft = current; baseline = current; progressText = ""; referenceName = ""; linkText = ""; message = "已显式重新加载。"
    }
}

struct ProjectsEditorView: View {
    @ObservedObject var session: ProjectsEditSession
    @ObservedObject var store: ProjectsStore
    let close: () -> Void
    @State private var confirmReload = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text(session.baseline == nil ? "新建个人项目" : "项目详情").font(.title); Spacer(); Text(session.isDirty ? "未保存" : "已保存").foregroundStyle(.secondary) }
                TextField("项目名称（必填）", text: $session.draft.name)
                Picker("状态", selection: $session.draft.status) { ForEach(ProjectsStatus.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                area("目标 / 说明", text: $session.draft.goal)
                area("下一步行动", text: $session.draft.nextStep)
                Toggle("归档（保留全部历史，取消勾选可恢复）", isOn: $session.draft.isArchived)
                if let saved = session.baseline { Text("创建：\(saved.createdAt.formatted()) · 更新：\(saved.updatedAt.formatted())").font(.caption).foregroundStyle(.secondary) }
                Divider()
                Text("进展记录（按原文追加，历史不改写）").font(.headline)
                ForEach(session.draft.progress.sorted { $0.recordedAt > $1.recordedAt }) { progress in
                    Text(progress.recordedAt.formatted()).font(.caption).foregroundStyle(.secondary)
                    Text(progress.body).textSelection(.enabled)
                }
                area("新增本次进展（可选，保存时一并追加）", text: $session.progressText)
                Divider()
                Text("文件 / 链接引用").font(.headline)
                ForEach(session.draft.references) { reference in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Text(reference.name); Spacer(); Button("打开") { session.open(reference) } }
                        Text(reference.location).font(.caption).textSelection(.enabled)
                        if let reason = reference.availability() { Text(reason).font(.caption).foregroundStyle(.orange) }
                    }
                }
                Button("选择文件引用…") { session.chooseFile() }
                TextField("链接名称（可选）", text: $session.referenceName)
                HStack { TextField("http / https 链接", text: $session.linkText); Button("加入链接") { session.addLink() } }
                Text("只登记用户选取的文件路径或链接，不复制/移动文件、不抓取网页。备份与恢复只保留引用。").font(.caption).foregroundStyle(.secondary)
                Text(session.message).foregroundStyle(.secondary).textSelection(.enabled)
                HStack {
                    Button("取消 / 关闭") { close() }
                    if session.baseline != nil { Button("重新加载保存版本…") { confirmReload = true } }
                    Spacer()
                    Button("保存") { Task { await session.save() } }.keyboardShortcut("s", modifiers: .command).disabled(!store.canSave)
                }
            }.padding(24)
        }.frame(minWidth: 620, minHeight: 560).disabled(session.saving || session.terminationPending)
            .alert("放弃本窗口未保存修改并重新加载？", isPresented: $confirmReload) {
                Button("取消", role: .cancel) {}
                Button("重新加载", role: .destructive) { Task { await session.reload() } }
            } message: { Text("不会自动合并旧草稿；已保存的项目和历史保持原样。") }
    }
    private func area(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(label).font(.headline); TextEditor(text: text).frame(minHeight: 90).overlay(Rectangle().stroke(Color(nsColor: .separatorColor))) }
    }
}

@MainActor
final class ProjectsWindowManager: NSObject, NSWindowDelegate, CosmosTerminationParticipant {
    static let shared = ProjectsWindowManager()
    private struct Entry { let controller: NSWindowController; let session: ProjectsEditSession }
    private var entries: [String: Entry] = [:]
    private var closing: Set<String> = [], approved: Set<String> = []
    private var pending = false
    var chooseClose: (ProjectsEditSession) -> LearningCloseChoice = { _ in
        let alert = NSAlert(); alert.messageText = "保存个人项目的未完成修改？"; alert.informativeText = "保存失败会保留草稿并阻止关闭。放弃只影响本窗口未保存内容。"
        alert.addButton(withTitle: "保存"); alert.addButton(withTitle: "放弃"); alert.addButton(withTitle: "取消")
        switch alert.runModal() { case .alertFirstButtonReturn: return .save; case .alertSecondButtonReturn: return .discard; default: return .cancel }
    }
    func open(store: ProjectsStore, project: PersonalProject?) {
        guard !pending else { return }
        let session = ProjectsEditSession(store: store, project: project)
        let key = store.storageIdentity + "::project::" + session.draft.id.uuidString
        if let old = entries[key] { old.controller.window?.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 780), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = project?.name ?? "新建个人项目"; window.identifier = NSUserInterfaceItemIdentifier(key)
        window.minSize = NSSize(width: 660, height: 600); window.isReleasedWhenClosed = false; window.delegate = self
        window.contentViewController = NSHostingController(rootView: ProjectsEditorView(session: session, store: store, close: { [weak window] in window?.performClose(nil) }))
        let controller = NSWindowController(window: window); entries[key] = Entry(controller: controller, session: session)
        window.center(); controller.showWindow(nil)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let key = sender.identifier?.rawValue, let entry = entries[key] else { return true }
        if approved.remove(key) != nil { return true }
        guard !pending, !entry.session.saving, !closing.contains(key) else { return false }
        guard entry.session.isDirty else { return true }
        closing.insert(key); let choice = chooseClose(entry.session)
        Task {
            if await entry.session.allowClose(choice: choice) { approved.insert(key); sender.performClose(nil) }
            closing.remove(key)
        }; return false
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
        }; return true
    }
}
