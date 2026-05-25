// ClaudeUsageApp.swift
// Minimal host app. Spec § Target stack → "The host app can be minimal —
// just a launcher window + preferences."

import SwiftUI
import WidgetKit

@main
struct ClaudeUsageApp: App {
    @State private var showSearchSheet: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showSearchSheet) {
                    SearchSheetView()
                }
                .onOpenURL { url in
                    guard url.scheme == "claudeusage" else { return }
                    switch url.host {
                    case "search":
                        // Bring the app window forward and present the search sheet.
                        NSApp.activate(ignoringOtherApps: true)
                        showSearchSheet = true
                    case "grant":
                        // Bring the preferences window forward for permissions flow.
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    default:
                        break
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)

        Settings {
            PreferencesView()
        }
    }
}
