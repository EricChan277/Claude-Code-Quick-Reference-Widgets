// ClaudeUsageApp.swift
// Minimal host app. Spec § Target stack → "The host app can be minimal —
// just a launcher window + preferences."

import SwiftUI
import WidgetKit

@main
struct ClaudeUsageApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle claudeusage://grant from widget's permissions CTA
                    if url.scheme == "claudeusage", url.host == "grant" {
                        // Bring the preferences window forward
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
