// ClaudeUsageWidget.swift
// WidgetKit entry point: declares both .systemLarge and .systemExtraLarge
// configurations. Spec § Two widget sizes.

import WidgetKit
import SwiftUI

// MARK: - Widget configuration

@main
struct ClaudeUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaudeUsageWidget()
    }
}

struct ClaudeUsageWidget: Widget {
    let kind: String = "ClaudeUsage"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClaudeUsageProvider()) { entry in
            ClaudeUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Claude Usage")
        .description("Live Claude Code session, weekly usage, context window, and agents.")
        .supportedFamilies([.systemLarge, .systemExtraLarge])
    }
}

// MARK: - Entry view dispatcher

struct ClaudeUsageWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    var entry: ClaudeUsageProvider.Entry

    var body: some View {
        Group {
            switch family {
            case .systemLarge:
                HifiLargeView(entry: entry.usage)
            case .systemExtraLarge:
                HifiXLargeView(entry: entry.usage)
            default:
                // Fallback: show the large view if somehow another family is used
                HifiLargeView(entry: entry.usage)
            }
        }
        .withTheme(colorScheme)
    }
}
