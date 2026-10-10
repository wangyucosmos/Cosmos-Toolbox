import SwiftUI

struct ProjectsView: View {
    @StateObject private var store: ProjectsStore
    @State private var search = ""
    @State private var status: ProjectsStatus?
    @State private var archived = false
    init(location: ProjectsLocation) { _store = StateObject(wrappedValue: ProjectsStore(location: location)) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("个人项目").font(.system(size: 32, weight: .semibold))
                        Text("非卓望的长期项目 · 目标、下一步与进展由你记录").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("新建项目", systemImage: "plus") { ProjectsWindowManager.shared.open(store: store, project: nil) }.disabled(!store.canSave)
                    Button("刷新", systemImage: "arrow.clockwise") { Task { await store.reload() } }.disabled(store.loading || store.saving)
                }
                HStack {
                    TextField("搜索名称 / 说明", text: $search)
                    Picker("状态", selection: $status) {
                        Text("全部状态").tag(ProjectsStatus?.none)
                        ForEach(ProjectsStatus.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                    }.frame(maxWidth: 180)
                    Picker("项目范围", selection: $archived) { Text("当前项目").tag(false); Text("已归档").tag(true) }.pickerStyle(.segmented).frame(maxWidth: 220)
                }
                if let error = store.error { Text(error.localizedDescription).foregroundStyle(.orange).textSelection(.enabled) }
                if store.loading { ProgressView("读取项目…") }
                else if store.loaded {
                    let visible = ProjectsQuery.filter(store.projects, search: search, status: status, archived: archived)
                    if visible.isEmpty {
                        ContentUnavailableView(store.established ? "没有符合条件的项目" : "尚未建立个人项目库", systemImage: "folder", description: Text(store.established ? "真实项目列表为空，或当前筛选没有结果。" : "新建第一个项目后保存；不会预置示例或扫描源码仓库。"))
                    } else {
                        ForEach(visible) { project in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(project.name).font(.headline)
                                    Text("\(project.status.title) · \(project.isArchived ? "已归档" : "当前项目")").foregroundStyle(.secondary)
                                    Text(project.goal).lineLimit(3)
                                    Text(project.nextStep.isEmpty ? "下一步：尚未填写" : "下一步：\(project.nextStep)")
                                    Text("更新：\(project.updatedAt.formatted())").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("查看 / 编辑") { ProjectsWindowManager.shared.open(store: store, project: project) }
                            }.padding(.vertical, 12)
                            Divider()
                        }
                    }
                }
                Text("文件和链接仅保存引用；元数据备份不包含实体文件。归档保留历史，不永久删除。").font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, CosmosDesign.pagePadding).padding(.vertical, CosmosDesign.spacingXXL)
                .frame(maxWidth: CosmosDesign.contentMaxWidth, alignment: .leading)
        }.background(Color(nsColor: .windowBackgroundColor)).task { await store.reload() }
    }
}
