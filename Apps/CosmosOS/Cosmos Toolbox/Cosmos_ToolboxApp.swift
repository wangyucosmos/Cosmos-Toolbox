//
//  Cosmos_ToolboxApp.swift
//  Cosmos Toolbox
//
//  Created by Cosmos on 2026/8/17.
//

import AppKit
import SwiftUI

@main
struct Cosmos_ToolboxApp: App {

    @NSApplicationDelegateAdaptor(CosmosPromptTerminationDelegate.self) private var promptTerminationDelegate

    var body: some Scene {

        WindowGroup {
            CosmosRootView()
                .environment(\.cosmosPreferences, CosmosUIPreferences.shared)
                .environment(\.cosmosNavigator, CosmosNavigator.shared)
                .modifier(CosmosMotionPolicy())
                .task { CosmosUIPreferences.shared.applyAppearance() }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 Cosmos OS") { showAbout() }
            }
        }
        Settings {
            CosmosSettingsSceneView()
                .environment(\.cosmosPreferences, CosmosUIPreferences.shared)
                .environment(\.cosmosNavigator, CosmosNavigator.shared)
        }

    }

    private func showAbout() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "未知"
        let build = info["CFBundleVersion"] as? String ?? "未知"
        let commit = info["CosmosBuildCommit"] as? String ?? "未记录（非部署构建）"
        let dirty = info["CosmosBuildDirty"] as? Bool
        let sourceState = dirty.map { $0 ? "含未提交改动" : "已提交源码" } ?? "源码状态未记录"
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Cosmos OS",
            .applicationVersion: "\(version)（构建 \(build)）",
            .version: "commit: \(commit) · \(sourceState)"
        ])
    }
}


// MARK: - Root View

/// The single, stable root of the main window in every build configuration.
///
/// AppKit derives the window-state autosave key (`NSWindow Frame …`,
/// `NSSplitView Subview Frames …`) from the type name of the WindowGroup's
/// direct root view. Keeping that root a plain, internal, non-conditional
/// type guarantees the key is identical across launches and configurations.
/// A `private` type or a `_ConditionalContent<…>` root would embed an
/// `(unknown context at $ADDR)` fragment and mint a new preference key on
/// every launch. Any DEBUG-only bootstrap decision therefore happens
/// *inside* this view, never at the WindowGroup level.
struct CosmosRootView: View {

#if DEBUG
    private let bootstrap =
        CosmosDebugStorePersistenceBootstrap.resolve()
#endif

    var body: some View {
#if DEBUG
        switch bootstrap {
        case .ready(let configuration):
            CoreRestoreStartupView(configuration: configuration)

        case .blocked(let message):
            CosmosStoreBootstrapBlockedView(
                message: message
            )
        }
#else
        CoreRestoreStartupView(configuration: .production)
#endif
    }
}


#if DEBUG
struct CosmosStoreBootstrapBlockedView: View {

    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(
                "Workspace 已停止加载",
                systemImage: "lock.trianglebadge.exclamationmark"
            )
        } description: {
            Text(message)
        }
        .frame(
            minWidth: 720,
            minHeight: 520
        )
    }
}
#endif
