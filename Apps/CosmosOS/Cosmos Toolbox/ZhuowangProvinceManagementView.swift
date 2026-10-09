import SwiftUI

/// Province maintenance inside the existing "管理工作区" sheet: add, rename,
/// reorder, stop and restore. Nothing here deletes data or moves folders.
struct ZhuowangProvinceManagementSection: View {

    @ObservedObject var store: ZhuowangWorkspaceStore
    var campaignCount: (UUID) -> Int
    var report: (String) -> Void

    @State private var newName = ""
    @State private var newEnglishName = ""
    @State private var editingID: UUID?
    @State private var editName = ""
    @State private var editEnglishName = ""
    @State private var stopCandidate: ZhuowangProvince?

    private var canMutate: Bool {
        store.persistenceState.allowsMutations
    }

    var body: some View {
        Section("省份 · Provinces") {

            ForEach(
                ZhuowangProvinceRules.existingConflicts(in: store.provinces),
                id: \.self
            ) { note in
                Label(
                    note + "。已原样保留，不会自动合并或删除；可通过改名消除重名。",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            if store.provinces.isEmpty {
                Text("还没有省份。在下方添加你负责的省份；改名不会移动已有文件夹，停用不会删除历史。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(
                Array(store.provinces.enumerated()),
                id: \.element.id
            ) { index, province in
                row(province, index: index)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("新增省份 · Add Province")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("中文名称，例如：湖北", text: $newName)
                    .accessibilityIdentifier("province-new-name")
                TextField("English Name, e.g. Hubei", text: $newEnglishName)
                Button("添加省份") { add() }
                    .disabled(
                        newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !canMutate
                    )
                    .accessibilityIdentifier("province-add")
                Text("新增省份会固定一个文件夹名；之后改名不会改变它。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .alert(
            "停用省份？",
            isPresented: Binding(
                get: { stopCandidate != nil },
                set: { if !$0 { stopCandidate = nil } }
            )
        ) {
            Button("取消", role: .cancel) { stopCandidate = nil }
            Button("停用") {
                if let province = stopCandidate {
                    finish(store.setProvinceEnabled(id: province.id, isEnabled: false))
                }
                stopCandidate = nil
            }
        } message: {
            if let province = stopCandidate {
                Text("「\(province.name)」已有 \(campaignCount(province.id)) 个活动。停用后只是不能再新建活动；历史活动、产物和文件保持不变，仍可查看、编辑和推进。可随时恢复。")
            }
        }
    }

    // MARK: Row

    @ViewBuilder
    private func row(_ province: ZhuowangProvince, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if editingID == province.id {
                TextField("中文名称", text: $editName)
                TextField("English Name", text: $editEnglishName)
                HStack {
                    Button("保存") { saveRename(province) }
                        .disabled(!canMutate)
                    Button("取消") { editingID = nil }
                }
                Text("只修改显示名称；文件夹「\(province.pathName)」不会改变或移动。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text(province.name)
                        .foregroundStyle(province.isEnabled ? .primary : .secondary)
                    if !province.isEnabled {
                        Text("已停用").font(.caption).foregroundStyle(.orange)
                    }
                    Spacer()
                    Button {
                        finish(store.moveProvince(id: province.id, offset: -1))
                    } label: { Image(systemName: "chevron.up") }
                        .disabled(index == 0 || !canMutate)
                        .help("上移")
                    Button {
                        finish(store.moveProvince(id: province.id, offset: 1))
                    } label: { Image(systemName: "chevron.down") }
                        .disabled(index == store.provinces.count - 1 || !canMutate)
                        .help("下移")
                    Button("改名") {
                        editingID = province.id
                        editName = province.name
                        editEnglishName = province.englishName
                    }
                    .disabled(!canMutate)
                    if province.isEnabled {
                        Button("停用") { stopCandidate = province }
                            .disabled(!canMutate)
                    } else {
                        Button("恢复") {
                            finish(store.setProvinceEnabled(id: province.id, isEnabled: true))
                        }
                        .disabled(!canMutate)
                    }
                }
                Text("\(province.englishName) · 文件夹：\(province.pathName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: Actions

    private func add() {
        if let violation = ZhuowangProvinceRules.validateNew(
            name: newName, existing: store.provinces, modules: store.modules
        ) {
            report(violation.message)
            return
        }
        let result = store.addProvince(name: newName, englishName: newEnglishName)
        if result.succeeded {
            newName = ""
            newEnglishName = ""
        } else {
            report(result.userMessage ?? "操作失败，未保存任何修改。")
        }
    }

    private func saveRename(_ province: ZhuowangProvince) {
        if let violation = ZhuowangProvinceRules.validateRename(
            id: province.id, name: editName, existing: store.provinces, modules: store.modules
        ) {
            report(violation.message)
            return
        }
        let result = store.renameProvince(
            id: province.id, name: editName, englishName: editEnglishName
        )
        if result.succeeded {
            editingID = nil
        } else {
            report(result.userMessage ?? "操作失败，未保存任何修改。")
        }
    }

    private func finish(_ result: ZhuowangStoreMutationResult) {
        if !result.succeeded {
            report(result.userMessage ?? "操作失败，未保存任何修改。")
        }
    }
}
