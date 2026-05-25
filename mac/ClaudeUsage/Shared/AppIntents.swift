// AppIntents.swift
// Interactive widget intents: copy agent name + set search query.
// Spec § Interactions & behavior, § State management.

import AppIntents
import WidgetKit

#if canImport(AppKit)
import AppKit
#endif

// MARK: - CopyAgentIntent

/// Writes "@{slug}" to NSPasteboard and requests a single widget reload.
/// Fired when the user taps any AgentItem. Spec § Agent item → Click action.
struct CopyAgentIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Agent Name"
    static let description = IntentDescription("Copies @{slug} to the clipboard.")

    @Parameter(title: "Agent Slug")
    var slug: String

    func perform() async throws -> some IntentResult {
        #if canImport(AppKit)
        await MainActor.run {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("@\(slug)", forType: .string)
        }
        #endif

        // Persist copied state so the widget can reflect it on reload.
        sharedDefaults.set(slug, forKey: DefaultsKey.lastCopiedSlug)
        sharedDefaults.set(Date.now, forKey: DefaultsKey.lastCopiedAt)

        WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsage")
        return .result()
    }
}

// MARK: - SetSearchQueryIntent

/// Persists the debounced search query and triggers a timeline reload.
/// Must only be called after the 250ms debounce; never per-keystroke.
/// Spec § Interactions → Search.
struct SetSearchQueryIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Search Query"
    static let description = IntentDescription("Persists the agent search query.")

    @Parameter(title: "Query")
    var query: String

    func perform() async throws -> some IntentResult {
        sharedDefaults.set(query, forKey: DefaultsKey.committedQuery)
        WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsage")
        return .result()
    }
}

// MARK: - ToggleAgentsCollapseIntent

/// Toggles the agents panel collapsed state (V4 only).
/// Spec § Interactions → Collapse [−] toggle.
struct ToggleAgentsCollapseIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Agents Panel"
    static let description = IntentDescription("Collapses or expands the agents list in the widget.")

    func perform() async throws -> some IntentResult {
        let current = sharedDefaults.bool(forKey: DefaultsKey.agentsCollapsed)
        sharedDefaults.set(!current, forKey: DefaultsKey.agentsCollapsed)
        WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsage")
        return .result()
    }
}

// MARK: - Convenience initialisers

extension CopyAgentIntent {
    init(slug: String) {
        self.slug = slug
    }
}

extension SetSearchQueryIntent {
    init(query: String) {
        self.query = query
    }
}

// MARK: - OpenGrantAccessIntent

/// Placeholder: opens the host app via a URL scheme for permissions flow.
/// Spec § Data states → permissionsDenied.
struct OpenGrantAccessIntent: AppIntent {
    static let title: LocalizedStringResource = "Grant File Access"
    static let description = IntentDescription("Opens Claude Usage to grant ~/.claude/ access.")

    func perform() async throws -> some IntentResult {
        #if canImport(AppKit)
        await MainActor.run {
            if let url = URL(string: "claudeusage://grant") {
                NSWorkspace.shared.open(url)
            }
        }
        #endif
        return .result()
    }
}
