// AppIntents.swift
// Interactive widget intents: copy agent name, clear search query, toggle agents.
// Spec § Interactions & behavior, § State management.
//
// NOTE: SetSearchQueryIntent is no longer called from within the widget
// (TextField is banned in WidgetKit on macOS 14+). Search queries are now
// committed from the host app's SearchSheet and written to
// ~/.claude/widget-state.json.  ClearSearchIntent remains so the widget can
// clear an active query without leaving the widget surface.

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

// MARK: - ClearSearchIntent

/// Clears the persisted committed query and reloads the widget timeline.
/// Displayed as an xmark.circle.fill button inside the widget when a query
/// is active.  This replaces the in-widget TextField; new queries are entered
/// via the host app (claudeusage://search deep-link).
struct ClearSearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Clear Search Query"
    static let description = IntentDescription("Clears the committed agent search query.")

    func perform() async throws -> some IntentResult {
        sharedDefaults.set(nil, forKey: DefaultsKey.committedQuery)
        WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsage")
        return .result()
    }
}

// MARK: - SetSearchQueryIntent
// Kept as a named type so any stored widget configurations that reference it
// do not produce an unresolvable-intent error on load.  Not called from
// widget views; called only from the host app's SearchSheet after the user
// commits a query there.

/// Persists a committed search query and triggers a timeline reload.
/// Must only be invoked from the host app, never from inside the widget.
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
