import AppKit
import Observation
import SwiftUI
import CoreFoundation

@Observable @MainActor
final class CosmosUIPreferences {
    static let shared = CosmosUIPreferences()
    enum Appearance: String, CaseIterable { case system, light, dark
        var title: String { switch self { case .system: return "跟随系统"; case .light: return "浅色"; case .dark: return "深色" } }
    }
    enum TextSize: String, CaseIterable { case standard, large, extraLarge
        var title: String { switch self { case .standard: return "标准"; case .large: return "较大"; case .extraLarge: return "特大" } }
        var scale: CGFloat { switch self { case .standard: return 1; case .large: return 1.12; case .extraLarge: return 1.24 } }
    }
    enum Startup: String, CaseIterable { case dashboard, lastPage
        var title: String { self == .dashboard ? "仪表盘" : "上次所在页面" }
    }
    enum Motion: String, CaseIterable { case system, reduced
        var title: String { self == .system ? "跟随系统" : "始终减少" }
    }
    static let keys = ["appearance", "textSize", "startup", "sidebarEnglish", "motion", "lastPage"].map { "cosmos.ui." + $0 }
    private let defaults: UserDefaults
    var appearance: Appearance { didSet { write(appearance.rawValue, "appearance"); applyAppearance() } }
    var textSize: TextSize { didSet { write(textSize.rawValue, "textSize") } }
    var startup: Startup { didSet { write(startup.rawValue, "startup") } }
    var sidebarEnglish: Bool { didSet { write(sidebarEnglish, "sidebarEnglish") } }
    var motion: Motion { didSet { write(motion.rawValue, "motion") } }
    var lastPage: String { didSet { if Self.validPages.contains(lastPage) { write(lastPage, "lastPage") } } }
    static let validPages = ["dashboard", "unifiedSearch", "zhuowang", "projects", "knowledgeBase", "aiWorkspace", "promptVault", "learningCenter", "macOptimizer"]
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = Appearance(rawValue: defaults.string(forKey: "cosmos.ui.appearance") ?? "") ?? .system
        textSize = TextSize(rawValue: defaults.string(forKey: "cosmos.ui.textSize") ?? "") ?? .standard
        startup = Startup(rawValue: defaults.string(forKey: "cosmos.ui.startup") ?? "") ?? .dashboard
        motion = Motion(rawValue: defaults.string(forKey: "cosmos.ui.motion") ?? "") ?? .system
        let english = defaults.object(forKey: "cosmos.ui.sidebarEnglish") as? NSNumber
        sidebarEnglish = english.map { CFGetTypeID($0) == CFBooleanGetTypeID() && $0.boolValue } ?? false
        let last = defaults.string(forKey: "cosmos.ui.lastPage") ?? "dashboard"
        lastPage = Self.validPages.contains(last) ? last : "dashboard"
    }
    private func write(_ value: Any, _ name: String) { defaults.set(value, forKey: "cosmos.ui." + name) }
    func applyAppearance() {
        NSApp?.appearance = appearance == .system ? nil : NSAppearance(named: appearance == .light ? .aqua : .darkAqua)
    }
    func reducesMotion(system: Bool) -> Bool { system || motion == .reduced }
}

extension EnvironmentValues {
    @Entry var cosmosPreferences: CosmosUIPreferences = .shared
    @Entry var cosmosNavigator: CosmosNavigator = .shared
}

struct CosmosMotionPolicy: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var system
    @Environment(\.cosmosPreferences) private var preferences
    func body(content: Content) -> some View {
        content.transaction { if preferences.reducesMotion(system: system) { $0.animation = nil; $0.disablesAnimations = true } }
            .symbolEffectsRemoved(preferences.reducesMotion(system: system))
    }
}
