// AgentItemView.swift
// Individual agent name button with idle / hover / copied states.
// Spec § Components → Agent item.

import SwiftUI
import AppIntents

// MARK: - AgentItemView

struct AgentItemView: View {
    @Environment(\.theme) private var theme

    var agent: AgentInfo
    var fontSize: CGFloat = 9.5       // 9.5pt V4, 10pt V6
    var searchQuery: String = ""       // non-empty → highlight matching substring
    var showCategory: Bool = false     // V6 search results append " · SHORT_CAT"

    // Local hover state (onHover)
    @State private var isHovered: Bool = false

    // Read copied state from sharedDefaults (set by CopyAgentIntent)
    private var isCopied: Bool {
        guard let slug = sharedDefaults.string(forKey: DefaultsKey.lastCopiedSlug),
              slug == agent.slug,
              let at = sharedDefaults.object(forKey: DefaultsKey.lastCopiedAt) as? Date
        else { return false }
        return Date.now.timeIntervalSince(at) < 1.4
    }

    var body: some View {
        Button(intent: CopyAgentIntent(slug: agent.slug)) {
            label
        }
        .buttonStyle(AgentButtonStyle(
            isHovered: isHovered,
            isCopied: isCopied,
            theme: theme
        ))
        .onHover { isHovered = $0 }
        .accessibilityLabel("Copy @\(agent.slug) to clipboard")
        .help("Click to copy @\(agent.slug)")
    }

    // MARK: - Label content

    @ViewBuilder
    private var label: some View {
        HStack(spacing: 2) {
            if isCopied {
                copiedLabel
            } else {
                normalLabel
            }

            if showCategory && !isCopied {
                Text(" · \(agent.category.shortLabel)")
                    .font(.system(size: max(fontSize - 1, 8)))
                    .foregroundStyle(theme.fgDim)
            }
        }
        .lineLimit(1)
        .truncationMode(.tail)
    }

    @ViewBuilder
    private var copiedLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.accent)
                .symbolRenderingMode(.monochrome)

            // Omit the literal " copied " word so the @slug stays readable
            // in narrow V6 columns — shows "✓ @swift-expert" instead of
            // "✓ co... @swi..." when the column clips mid-affordance.
            Text("@\(agent.slug)")
                .font(.system(size: fontSize, weight: .bold).monospaced())
                .foregroundStyle(theme.accent)
        }
    }

    @ViewBuilder
    private var normalLabel: some View {
        if searchQuery.isEmpty {
            Text(agent.slug)
                .font(.system(size: fontSize))
                .foregroundStyle(theme.fg)
        } else {
            highlightedText(full: agent.slug, query: searchQuery, fontSize: fontSize)
        }
    }

    // MARK: - Search highlight

    private func highlightedText(full: String, query: String, fontSize: CGFloat) -> some View {
        Text(buildHighlighted(full: full, query: query))
            .font(.system(size: fontSize))
            .foregroundStyle(theme.fg)
            .lineLimit(1)
    }

    private func buildHighlighted(full: String, query: String) -> AttributedString {
        var attr = AttributedString(full)
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty,
              let range = full.lowercased().range(of: q),
              let attrRange = Range(range, in: attr) else {
            return attr
        }
        attr[attrRange].backgroundColor = theme.searchHighlight
        return attr
    }
}

// MARK: - AgentButtonStyle

private struct AgentButtonStyle: ButtonStyle {
    var isHovered: Bool
    var isCopied: Bool
    var theme: Theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered || isCopied ? theme.chipHoverBg : .clear)
            )
            .contentShape(Rectangle())
    }
}

