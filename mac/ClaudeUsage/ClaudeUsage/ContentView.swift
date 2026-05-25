// ContentView.swift
// Launcher window for the host app. Provides a "Rescan agents" button
// and a link to open Notification Center.
// Spec § Implementation checklist → "Add the host .app — preferences window …"

import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var scanStatus: String = ""

    var body: some View {
        VStack(spacing: 20) {
            // App icon placeholder
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(colorScheme == .dark ? Color(hex: "#FF8A3D") : Color(hex: "#D97557"))

            Text("Claude Usage Widget")
                .font(.title2.bold())

            Text("Add the widget from Notification Center.\nRight-click the desktop → Edit Widgets.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 12) {
                Button("Rescan Agents Now") {
                    Task {
                        let scanner = AgentScanner()
                        let (agents, _) = await scanner.scan()
                        WidgetCenter.shared.reloadAllTimelines()
                        scanStatus = "Found \(agents.count) agents. Widget refreshed."
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(colorScheme == .dark ? Color(hex: "#FF8A3D") : Color(hex: "#D97557"))

                Button("Open Preferences") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.bordered)
            }

            if !scanStatus.isEmpty {
                Text(scanStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Context window needs a statusline hook — see **mac/README.md**.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 420)
    }
}
