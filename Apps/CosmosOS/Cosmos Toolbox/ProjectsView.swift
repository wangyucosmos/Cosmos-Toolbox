import SwiftUI

struct ProjectsView: View {
    @StateObject private var store: ProjectsStore
    @State private var search = ""
    @State private var status: ProjectsStatus?
    @State private var archived = false
    @Environment(\.cosmosPreferences) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    init(location: ProjectsLocation) { _store = StateObject(wrappedValue: ProjectsStore(location: location)) }
    init(store: ProjectsStore) { _store = StateObject(wrappedValue: store) }
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                CosmosPageHeader("个人项目", subtitle: "记录卓望以外的长期项目：目标、下一步和进展。",
                    info: "适合跟踪需要持续推进的个人项目。活动与 Workflow 仍在卓望工作区；这里不扫描源码仓库、不自动创建示例。文件与链接只登记引用，归档保留全部历史。")
                HStack(spacing: 12) {
                    TextField("搜索名称 / 说明", text: $search).textFieldStyle(.roundedBorder)
                    Picker("状态", selection: $status) {
                        Text("全部状态").tag(ProjectsStatus?.none)
                        ForEach(ProjectsStatus.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                    }.frame(maxWidth: 160)
                    CosmosSegmentedControl(title: "项目范围", options: [(false, "当前"), (true, "归档")], selection: $archived)
                }
                if let error = store.error { Text(error.localizedDescription).foregroundStyle(.orange).textSelection(.enabled) }
                if store.loading { ProgressView("读取项目…") }
                else if store.loaded {
                    let visible = ProjectsQuery.filter(store.projects, search: search, status: status, archived: archived)
                    if visible.isEmpty {
                        if store.projects.isEmpty && !archived && search.isEmpty && status == nil { starters }
                        else { CosmosEmptyState(icon: "line.3.horizontal.decrease.circle", title: "没有符合条件的项目", detail: "调整状态、范围或关键词后再查看。") }
                    } else {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { index, project in
                            CosmosCard(icon: "folder", title: project.name, action: { ProjectsWindowManager.shared.open(store: store, project: project) }) {
                                HStack { CosmosStatusBadge(text: project.status.title, icon: "circle.fill"); if project.isArchived { Text("已归档").font(CosmosDesign.font(.caption)).foregroundStyle(.secondary) } }
                                Text(project.goal.isEmpty ? "目标尚未填写" : project.goal).font(CosmosDesign.font(.body)).foregroundStyle(.secondary).lineLimit(3)
                                Label(project.nextStep.isEmpty ? "填写下一步，让项目继续推进" : project.nextStep, systemImage: "arrow.right.circle").font(CosmosDesign.font(.body)).lineLimit(2)
                                Text(project.progress.max(by: { $0.recordedAt < $1.recordedAt }).map { "最近进展：" + $0.recordedAt.formatted(date: .abbreviated, time: .shortened) } ?? "尚无进展记录 · 更新 " + project.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
                            }.cosmosEntrance(index)
                        }
                    }
                }
                Text("文件和链接仅保存引用；备份不包含实体文件。归档保留历史。").font(CosmosDesign.font(.caption)).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: CosmosDesign.contentMaxWidth, alignment: .leading).frame(maxWidth: .infinity)
        }.background(Color(nsColor: .windowBackgroundColor))
            .toolbar { ToolbarItem { CosmosGlassToolbarGroup {
                Button("新建项目", systemImage: "plus") { ProjectsWindowManager.shared.open(store: store, project: nil) }.disabled(!store.canSave)
                Button("刷新", systemImage: "arrow.clockwise") { Task { await store.reload() } }.disabled(store.loading || store.saving)
            } } }
            .task { if await CosmosDesign.beginPageLoad(reduced: preferences.reducesMotion(system: systemMotion)) { await store.reload() } }
    }
    private var starters: some View {
        VStack(alignment: .leading, spacing: 14) {
            CosmosEmptyState(icon: "folder.badge.plus", title: "从一个长期目标开始", detail: "开发软件、整理作品集，或做一个边学边用的小工具。")
            Text("从模板开始").font(CosmosDesign.font(.section))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                ForEach(Array(CosmosProjectStarter.allCases.enumerated()), id: \.element.id) { index, starter in
                    CosmosCard(icon: starter.icon, title: starter.title, action: {
                        ProjectsWindowManager.shared.open(store: store, project: nil, prefill: starter.draft)
                    }) { Text(starter.draft.goal).font(CosmosDesign.font(.body)).foregroundStyle(.secondary); Text("预填草稿 · 保存后才创建").font(CosmosDesign.font(.caption)).foregroundStyle(.secondary) }
                        .disabled(!store.canSave).cosmosEntrance(index)
                }
            }
        }
    }
}
