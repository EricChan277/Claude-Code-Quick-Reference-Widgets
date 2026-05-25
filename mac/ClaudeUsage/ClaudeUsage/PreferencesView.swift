// PreferencesView.swift
// Preferences / settings window. Spec § Implementation checklist → host app.

import SwiftUI
import WidgetKit

struct PreferencesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("refreshInterval", store: sharedDefaults) private var refreshInterval: Int = 60

    private var accent: Color {
        colorScheme == .dark ? Color(hex: "#FF8A3D") : Color(hex: "#D97557")
    }

    var body: some View {
        Form {
            Section("Widget") {
                Picker("Refresh interval", selection: $refreshInterval) {
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                    Text("2 minutes").tag(120)
                }
                .pickerStyle(.segmented)
                .onChange(of: refreshInterval) { _, _ in
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }

            Section("Context window") {
                Text("Context window data is read from ~/.claude/context.json.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Status: \(contextStatus)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("File access") {
                Text("The widget reads ~/.claude/ directly. If data is missing, grant access:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Grant ~/.claude/ access") {
                    // Open a file panel pointed at ~/.claude to trigger system sandbox prompt
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".claude")
                    panel.begin { _ in
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 360)
        .padding()
    }

    private var contextStatus: String {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/context.json")
        if FileManager.default.fileExists(atPath: url.path) {
            return "context.json present"
        }
        return "not connected — see Setup in README"
    }
}
