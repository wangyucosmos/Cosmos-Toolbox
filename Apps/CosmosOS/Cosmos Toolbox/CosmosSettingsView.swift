import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CosmosSettingsView: View {
    let source: CoreBackupSource
    let restoreTarget: CoreRestoreTarget?
    @Environment(\.cosmosNavigator) private var navigator
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    var body: some View {
        @Bindable var navigator = navigator
        TabView(selection: $navigator.settingsTab) {
            general.tabItem { Label("通用", systemImage: "gearshape") }.tag(CosmosSettingsTab.general)
            CosmosSettingsBackupView(source: source, restoreTarget: restoreTarget)
                .tabItem { Label("数据与备份", systemImage: "externaldrive") }.tag(CosmosSettingsTab.data)
            about.tabItem { Label("关于", systemImage: "info.circle") }.tag(CosmosSettingsTab.about)
        }.padding(16).frame(width: 720, height: navigator.settingsTab == .data ? 660 : navigator.settingsTab == .about ? 400 : 460)
            .animation(CosmosDesign.pageAnimation(reduced: preferences.reducesMotion(system: systemMotion)), value: navigator.settingsTab)
            .modifier(CosmosMotionPolicy())
    }
    private var general: some View {
        @Bindable var preferences = preferences
        return Form {
            Section("外观与阅读") {
                Picker("外观", selection: $preferences.appearance) { ForEach(CosmosUIPreferences.Appearance.allCases, id: \.self) { Text($0.title).tag($0) } }
                Picker("文字大小", selection: $preferences.textSize) { ForEach(CosmosUIPreferences.TextSize.allCases, id: \.self) { Text($0.title).tag($0) } }
                Text("调整 Cosmos 字体层级；系统控件自身的字号不受此项影响。").font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
                Text("阅读预览 · 清晰、专注、自然").font(CosmosDesign.font(.section))
            }
            Section("启动与导航") {
                Picker("启动时打开", selection: $preferences.startup) { ForEach(CosmosUIPreferences.Startup.allCases, id: \.self) { Text($0.title).tag($0) } }
                Toggle("侧栏显示英文名称", isOn: $preferences.sidebarEnglish)
            }
            Section("动态效果") {
                Picker("减少动效", selection: $preferences.motion) { ForEach(CosmosUIPreferences.Motion.allCases, id: \.self) { Text($0.title).tag($0) } }
                Text("系统开启减少动态效果时，Cosmos 始终遵循系统设置。").font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
    private var about: some View {
        let info = Bundle.main.infoDictionary ?? [:]
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CosmosPageHeader("Cosmos OS", subtitle: "本地优先的个人工作操作系统")
                LabeledContent("版本", value: (info["CFBundleShortVersionString"] as? String ?? "未知") + "（构建 " + (info["CFBundleVersion"] as? String ?? "未知") + "）")
                LabeledContent("Commit", value: info["CosmosBuildCommit"] as? String ?? "未记录（非部署构建）")
                LabeledContent("源码状态", value: (info["CosmosBuildDirty"] as? Bool).map { $0 ? "含未提交改动" : "已提交源码" } ?? "未记录")
                Divider()
                storageLocations
            }.font(CosmosDesign.font(.body)).textSelection(.enabled).padding(16)
        }
    }
    private var storageLocations: some View { CosmosSettingsLocations(source: source, restoreTarget: restoreTarget) }
}

struct CosmosSettingsLocations: View {
    let source: CoreBackupSource
    let restoreTarget: CoreRestoreTarget?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("数据位置").font(CosmosDesign.font(.section))
            Text("活动、Workflow 与 AI 配置：当前应用的 UserDefaults 域（核心备份按白名单读取）。").font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
            if let error = source.isolationError { Text(error).foregroundStyle(.orange).font(CosmosDesign.font(.caption)) }
            ForEach(Array(source.fileRoots.enumerated()), id: \.offset) { index, url in
                let names = ["提示词库", "学习中心", "AI 交接记录", "项目", "个人笔记"]
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(names.indices.contains(index) ? names[index] : "数据目录").font(CosmosDesign.font(.body))
                        Text(url.path).font(CosmosDesign.font(.caption)).foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("在 Finder 中显示", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }.labelStyle(.iconOnly).help("在 Finder 中显示")
                }
            }
            if let root = restoreTarget?.transactionRoot { Text("恢复控制：" + root.path).font(CosmosDesign.font(.caption)).foregroundStyle(.secondary).textSelection(.enabled) }
        }
    }
}

/// Presentation-only migration. The original backup model and restore view retain every safety check.
struct CosmosSettingsBackupView: View {
    @StateObject private var model: CoreBackupViewModel
    let source: CoreBackupSource
    let restoreTarget: CoreRestoreTarget?
    init(source: CoreBackupSource, restoreTarget: CoreRestoreTarget?) {
        self.source = source; self.restoreTarget = restoreTarget
        _model = StateObject(wrappedValue: CoreBackupViewModel(source: source))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CosmosPageHeader("数据与备份", subtitle: "手动导出核心元数据，或只读校验已有备份。",
                    info: "Cosmos 核心元数据 ZIP V3，不压缩，兼容读取 V1/V2。V1 不含 Projects 与个人笔记，V2 不含个人笔记。单源最多 16 MiB，包最多 128 MiB，清单最多 256 KiB。缺失主数据记为尚未建立，真实空库保留为已建立。源错误或变化时中止。读取前后检查修订、发布前逐源复读；不是跨进程事务，不能保证外部进程在最终检查后不再写入。SHA-256 不是签名或加密。")
                Text("备份不包含文件实体，也不加密。已保存正文保留原文，请妥善保管备份；登记路径仍依赖原文件。").font(CosmosDesign.font(.body)).foregroundStyle(.secondary)
                GroupBox("包含范围") {
                    Text("Campaign 与引用登记、Workspace / 省份配置、Workflow / Artifact / Run / Approval、AI 非敏感配置、提示词及版本、学习主题和记录、AI 交接、项目及进展、个人笔记正文及全部版本与引用登记。")
                        .font(CosmosDesign.font(.body)).frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
                DisclosureGroup("不包含与安全排除（不是完整换机恢复）") {
                    ForEach(CoreBackupSource.currentExclusions, id: \.self) { Text($0).font(CosmosDesign.font(.body)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4) }
                }
                CosmosGlassToolbarGroup {
                    Button("导出核心数据备份", systemImage: "square.and.arrow.up") { chooseExport() }
                    Button("校验备份", systemImage: "checkmark.shield") { chooseVerify() }
                    if let result = model.result { Button("在 Finder 中查看", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([result.url]) } }
                }.disabled(model.busy)
                if model.busy { ProgressView() }
                if let status = model.status { Text(status).font(CosmosDesign.font(.body)).textSelection(.enabled).accessibilityIdentifier("core-backup-status") }
                if let result = model.result {
                    ForEach(result.manifest.sources, id: \.id) { item in
                        Text("\(item.id)：\(item.status == "missing" ? "尚未建立" : "已建立 · \(item.bytes) 字节")\(item.transformation == nil ? "" : " · 已安全转换")").font(CosmosDesign.font(.caption))
                    }
                }
                Divider()
                CoreRestoreView(target: restoreTarget)
                Divider()
                CosmosSettingsLocations(source: source, restoreTarget: restoreTarget)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityIdentifier("core-backup-settings")
    }
    private func chooseExport() {
        let panel = NSSavePanel(); panel.title = "导出核心数据备份（已有目标不会覆盖）"
        panel.allowedContentTypes = [.zip]; panel.canCreateDirectories = true
        let formatter = DateFormatter(); formatter.dateFormat = "yyyyMMdd-HHmmss"
        panel.nameFieldStringValue = "Cosmos-Core-\(formatter.string(from: Date())).zip"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.run(url: url, exporting: true) }
    }
    private func chooseVerify() {
        let panel = NSOpenPanel(); panel.title = "校验 Cosmos 核心元数据备份"
        panel.allowedContentTypes = [.zip]; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.run(url: url, exporting: false) }
    }
}

struct CosmosSettingsSceneView: View {
    var body: some View {
#if DEBUG
        switch CosmosDebugStorePersistenceBootstrap.resolve() {
        case .ready(let configuration): content(configuration)
        case .blocked(let error): ContentUnavailableView("设置已停止加载", systemImage: "lock", description: Text(error))
        }
#else
        content(.production)
#endif
    }
    private func content(_ configuration: ZhuowangStorePersistenceConfiguration) -> some View {
        let isolated = configuration.isIsolatedForUI
        let bundle = Bundle.main.bundleIdentifier, args = ProcessInfo.processInfo.arguments
        let prompts = PromptVaultLocation.resolve(isIsolated: isolated, bundleIdentifier: bundle, arguments: args)
        let notes = PersonalNotesLocation.resolve(isIsolated: isolated, bundleIdentifier: bundle, arguments: args)
        let learning = LearningLocation.resolve(isIsolated: isolated, bundleIdentifier: bundle, arguments: args)
        let projects = ProjectsLocation.resolve(isIsolated: isolated, bundleIdentifier: bundle, arguments: args)
        let handoffs = AIWorkspaceHandoffLocation.resolve(isIsolated: isolated, bundleIdentifier: bundle, arguments: args)
        let source = CoreBackupSource(configuration: configuration, promptRoot: prompts.root, learningRoot: learning.root, handoffRoot: handoffs.root, projectsRoot: projects.root, notesRoot: notes.root)
        return CosmosSettingsView(source: source, restoreTarget: try? CoreRestoreTarget.resolve(configuration: configuration))
    }
}
