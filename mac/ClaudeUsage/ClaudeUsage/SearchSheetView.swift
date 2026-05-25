// SearchSheetView.swift
// Real-TextField search for agents, presented when the widget's search affordance
// (a Link to claudeusage://search) is tapped.  Once the user commits a query,
// writes it to ~/.claude/widget-state.json and reloads widget timelines.
//
// Spec § Interactions → Search (adapted): keystroke filtering is local; only
// the committed value persists to the widget.

import SwiftUI
import WidgetKit

// MARK: - SearchSheetView

struct SearchSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var agents: [AgentInfo] = []
    @State private var isLoading: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Search Agents")
                    .font(.headline)
                Spacer()
                Button("Done") { commitAndDismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider()

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("search agents…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit { commitAndDismiss() }
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Results list
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let results = filteredAgents
                if results.isEmpty && !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("No agents match \"\(query)\"")
                        .font(.callout.italic())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(results) { agent in
                        Button {
                            query = agent.slug
                            commitAndDismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(agent.slug)
                                        .font(.system(size: 13))
                                    Text(agent.category.fullLabel)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }

            Divider()

            // Footer: clear + commit
            HStack {
                Button("Clear Filter") {
                    query = ""
                    WidgetState.set(nil as String?, forKey: DefaultsKey.committedQuery)
                    WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsage")
                    dismiss()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Search") { commitAndDismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 380, height: 480)
        .task {
            let scanner = AgentScanner()
            let result = await scanner.scan()
            agents = result.agents
            isLoading = false
        }
    }

    // MARK: - Helpers

    private var filteredAgents: [AgentInfo] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return agents }
        return agents.matching(query: q)
    }

    private func commitAndDismiss() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        WidgetState.set(trimmed.isEmpty ? nil : trimmed, forKey: DefaultsKey.committedQuery)
        WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsage")
        dismiss()
    }
}
