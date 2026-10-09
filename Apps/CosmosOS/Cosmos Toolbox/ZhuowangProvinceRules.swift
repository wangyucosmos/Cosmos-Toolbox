import Foundation

/// Why a province change was refused. Business-layer only; the persistence
/// layer keeps its generic failure vocabulary.
enum ZhuowangProvinceViolation: Equatable {
    case emptyName
    case duplicateDisplayName
    case directoryConflict
    case reservedName
    case notFound
    case cannotMove

    var message: String {
        switch self {
        case .emptyName:
            return "省份名称不能为空。"
        case .duplicateDisplayName:
            return "已有同名省份（包括已停用的省份）；未保存。"
        case .directoryConflict:
            return "该名称对应的文件夹与已有省份的文件夹冲突（按保守的路径规则判断）；未保存。"
        case .reservedName:
            return "该名称保留给全国及其他活动，不能作为省份；未保存。"
        case .notFound:
            return "目标省份已不存在；未保存。"
        case .cannotMove:
            return "无法继续移动。"
        }
    }
}

/// Pure rules for maintainable provinces. Province identity is the UUID;
/// names are display only; `pathName` is the stable folder name.
enum ZhuowangProvinceRules {

    /// The folder that holds national / other Campaigns. Never a province.
    static let nationalPathName = "全国及其他"

    /// Names that must never become provinces: the national scope, the
    /// national folder (a real path collision) and the national module name.
    static func reservedNames(modules: [ZhuowangModule]) -> [String] {
        ["全国", nationalPathName] + modules.filter { $0.id == "national" }.map(\.name)
    }

    /// Conservative comparison key for display names: trimmed, canonical
    /// Unicode form, case- and width-insensitive.
    static func displayKey(_ name: String) -> String {
        fold(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Conservative comparison key for folder names: the same sanitization
    /// the file manager applies, then the same folding. It errs on the side
    /// of reporting a conflict; it is not a proof of file-system identity.
    static func pathKey(_ name: String) -> String {
        fold(ZhuowangWorkspaceFileManager.shared.sanitizedPathComponent(name))
    }

    private static func fold(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: nil)
    }

    private static func isReserved(_ name: String, modules: [ZhuowangModule]) -> Bool {
        let displayKeys = Set(reservedNames(modules: modules).map(displayKey))
        let pathKeys = Set(reservedNames(modules: modules).map(pathKey))
        return displayKeys.contains(displayKey(name)) || pathKeys.contains(pathKey(name))
    }

    /// New province: the display name must be unique among all provinces
    /// (stopped ones included) and the new folder name must not collide with
    /// any existing province's effective folder name.
    static func validateNew(
        name: String,
        existing: [ZhuowangProvince],
        modules: [ZhuowangModule]
    ) -> ZhuowangProvinceViolation? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return .emptyName }
        if isReserved(clean, modules: modules) { return .reservedName }
        if existing.contains(where: { displayKey($0.name) == displayKey(clean) }) {
            return .duplicateDisplayName
        }
        let key = pathKey(clean)
        if existing.contains(where: { pathKey($0.pathName) == key }) {
            return .directoryConflict
        }
        return nil
    }

    /// Rename: only the display name changes, so only display names are
    /// compared (excluding the province itself). The folder is untouched.
    /// An unchanged name is accepted even if old data already contained a
    /// duplicate; it is never merged or rejected retroactively.
    static func validateRename(
        id: UUID,
        name: String,
        existing: [ZhuowangProvince],
        modules: [ZhuowangModule]
    ) -> ZhuowangProvinceViolation? {
        guard let current = existing.first(where: { $0.id == id }) else { return .notFound }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return .emptyName }
        if displayKey(clean) == displayKey(current.name) { return nil }
        if isReserved(clean, modules: modules) { return .reservedName }
        if existing.contains(where: { $0.id != id && displayKey($0.name) == displayKey(clean) }) {
            return .duplicateDisplayName
        }
        return nil
    }

    /// Existing data that already contains duplicate display names or
    /// colliding folders. Reported to the user; never auto-fixed.
    static func existingConflicts(in provinces: [ZhuowangProvince]) -> [String] {
        var notes: [String] = []
        let byDisplay = Dictionary(grouping: provinces, by: { displayKey($0.name) })
        for group in byDisplay.values where group.count > 1 {
            notes.append("存在同名省份：\(group.map(\.name).joined(separator: "、"))")
        }
        let byPath = Dictionary(grouping: provinces, by: { pathKey($0.pathName) })
        for group in byPath.values where group.count > 1 {
            notes.append("以下省份共用同一个文件夹：\(group.map(\.name).joined(separator: "、"))")
        }
        return notes.sorted()
    }

    /// New Campaigns may only be created in a province that is *currently*
    /// enabled in the live configuration. Existing Campaigns are never
    /// affected by this rule.
    static func canCreateCampaign(provinceID: UUID, in provinces: [ZhuowangProvince]) -> Bool {
        provinces.first(where: { $0.id == provinceID })?.isEnabled == true
    }

    /// Save-time guard for a Campaign form that may have been opened before
    /// the province was stopped. Returns the refusal message (the input stays
    /// in the form) or `nil` when saving may proceed.
    static func creationRefusalMessage(
        province: ZhuowangProvince?,
        isEnabled: (UUID) -> Bool
    ) -> String? {
        guard let province, !isEnabled(province.id) else {
            return nil
        }
        return "「\(province.name)」已停用，不能新建活动。已填写的内容仍保留在表单中。"
    }
}
