//
//  Cosmos_ToolboxApp.swift
//  Cosmos Toolbox
//
//  Created by Cosmos on 2026/8/17.
//

import SwiftUI

@main
struct Cosmos_ToolboxApp: App {

    var body: some Scene {

        WindowGroup {
            CosmosRootView()
        }
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
            DashboardView(
                storePersistenceConfiguration:
                    configuration
            )

        case .blocked(let message):
            CosmosStoreBootstrapBlockedView(
                message: message
            )
        }
#else
        DashboardView()
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
