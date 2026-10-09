import SwiftUI

struct LearningCenterView: View {
    @StateObject private var store: LearningStore
    @StateObject private var model = LearningViewModel()

    init(location: LearningLocation) {
        _store = StateObject(wrappedValue: LearningStore(root: location.root, startupError: location.error))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("学习中心").font(.largeTitle)
                Spacer()
                Button("新建主题", systemImage: "plus") {
                    LearningEditorWindowManager.shared.openTopic(store: store, topic: nil)
                }.disabled(!store.canSave).accessibilityIdentifier("learning-new-topic")
                Button("刷新", systemImage: "arrow.clockwise") { Task { await store.reload() } }
                    .disabled(store.saving)
            }
            Text("正在学什么、想达到什么、上次学了什么、下一步从哪里继续。内容由你填写，不推断进度。")
                .foregroundStyle(.secondary).font(.callout)
            if let error = store.error {
                Text(error.localizedDescription).foregroundStyle(.orange).textSelection(.enabled)
            }
            if store.loading { ProgressView("正在读取学习库…") }
            HStack {
                TextField("搜索主题、目标、下一步或笔记", text: $model.query).accessibilityIdentifier("learning-search")
                Picker("状态", selection: $model.statusFilter) {
                    Text("全部状态").tag(LearningStatus?.none)
                    ForEach(LearningStatus.allCases, id: \.self) { Text($0.title).tag(LearningStatus?.some($0)) }
                }.labelsHidden().frame(maxWidth: 130)
                Toggle("仅有下一步", isOn: $model.onlyNextStep)
                Toggle("查看归档", isOn: $model.showArchived)
            }
            ViewThatFits(in: .horizontal) {
                HSplitView { list.frame(minWidth: 280, idealWidth: 320, maxWidth: 420); detail.frame(minWidth: 420) }
                    .frame(minWidth: 740)
                VStack(alignment: .leading) { list.frame(maxHeight: 260); detail }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await store.reload() }
        .onChange(of: store.topics) { _, topics in model.reconcileSelection(topics) }
    }

    private var list: some View {
        let summaries = model.summaries(topics: store.topics, entries: store.entries)
        return VStack {
            if summaries.isEmpty {
                ContentUnavailableView(store.topics.isEmpty ? "创建第一个学习主题" : "没有匹配的主题",
                    systemImage: "graduationcap",
                    description: Text(store.topics.isEmpty
                        ? "写下想学的内容和目标，再记录每一次学习。"
                        : "可调整搜索、状态、下一步或归档筛选。"))
            } else {
                List(selection: $model.selectedID) {
                    ForEach(summaries) { summary in
                        LearningTopicRow(summary: summary).tag(summary.id)
                            .accessibilityIdentifier("learning-topic-" + summary.id.uuidString)
                    }
                }
            }
        }
    }

    @ViewBuilder private var detail: some View {
        if let topic = store.topics.first(where: { $0.id == model.selectedID }) {
            LearningTopicDetailView(topic: topic, history: model.history(topicID: topic.id, entries: store.entries),
                store: store, model: model)
        } else {
            ContentUnavailableView("选择一个主题", systemImage: "text.book.closed",
                description: Text("查看目标、下一步和学习历史。"))
        }
    }
}

private func dayLabel(_ day: LearningDay) -> String {
    day == LearningDay.today() ? "今天" : day.string
}

struct LearningTopicRow: View {
    let summary: LearningTopicSummary
    var body: some View {
        let topic = summary.topic
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(topic.name).fontWeight(.medium).lineLimit(1)
                Text(topic.status.title).font(.caption).foregroundStyle(.secondary)
                if topic.isArchived { Text("已归档").font(.caption).foregroundStyle(.orange) }
            }
            Text(summary.lastEntry.map { "上次学习：" + dayLabel($0.studyDay) } ?? "尚无学习记录")
                .font(.caption).foregroundStyle(.secondary)
            if topic.hasNextStep {
                Text("下一步：" + topic.nextStep).font(.caption).lineLimit(1)
            }
        }
    }
}

struct LearningTopicDetailView: View {
    let topic: LearningTopic
    let history: [LearningEntry]
    @ObservedObject var store: LearningStore
    @ObservedObject var model: LearningViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(topic.name).font(.title2).textSelection(.enabled)
                HStack {
                    Picker("状态", selection: Binding(get: { topic.status },
                        set: { new in Task { await store.setStatus(topic, new) } })) {
                        ForEach(LearningStatus.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.frame(maxWidth: 180).disabled(topic.isArchived || !store.canSave)
                    if topic.isArchived { Text("已归档 · 只读").foregroundStyle(.orange) }
                }
                HStack {
                    Button("编辑主题", systemImage: "square.and.pencil") {
                        LearningEditorWindowManager.shared.openTopic(store: store, topic: topic)
                    }.disabled(topic.isArchived || !store.canSave).accessibilityIdentifier("learning-edit-topic")
                    Button("记录学习", systemImage: "plus.circle") {
                        LearningEditorWindowManager.shared.openEntry(store: store, topic: topic, entry: nil)
                    }.disabled(topic.isArchived || !store.canSave).accessibilityIdentifier("learning-new-entry")
                    Button(topic.isArchived ? "恢复" : "归档", systemImage: "archivebox") {
                        Task { await store.setArchived(topic, !topic.isArchived) }
                    }.disabled(!store.canSave).accessibilityIdentifier("learning-archive")
                }
                section("学习目标", topic.goal, empty: "未填写目标")
                section("下一步", topic.hasNextStep ? topic.nextStep : "", empty: "还没有下一步")
                if let link = topic.resourceURL {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("资料链接").font(.headline)
                        Text(link).textSelection(.enabled).foregroundStyle(.secondary)
                        Button("复制链接", systemImage: "doc.on.doc") { model.copyLink(topic) }
                        Text(model.copyMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
                Text("学习历史（\(history.count)）").font(.headline)
                if history.isEmpty {
                    Text("还没有学习记录。").foregroundStyle(.secondary)
                }
                ForEach(history) { entry in
                    LearningEntryRow(entry: entry, topic: topic, store: store)
                }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func section(_ title: String, _ text: String, empty: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            if text.isEmpty { Text(empty).foregroundStyle(.secondary) }
            else { Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
        }
    }
}

struct LearningEntryRow: View {
    let entry: LearningEntry
    let topic: LearningTopic
    @ObservedObject var store: LearningStore
    @State private var expanded = false
    private var isLong: Bool { entry.body.count > 280 || entry.body.split(separator: "\n", omittingEmptySubsequences: false).count > 6 }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.studyDay.string).fontWeight(.medium)
                if let minutes = entry.durationMinutes { Text("\(minutes) 分钟").foregroundStyle(.secondary) }
                Spacer()
                Button("编辑") {
                    LearningEditorWindowManager.shared.openEntry(store: store, topic: topic, entry: entry)
                }.disabled(topic.isArchived || !store.canSave)
            }
            Text(entry.body).textSelection(.enabled).lineLimit(expanded ? nil : 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isLong { Button(expanded ? "收起" : "展开全文") { expanded.toggle() }.buttonStyle(.link) }
        }
        .padding(10).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
