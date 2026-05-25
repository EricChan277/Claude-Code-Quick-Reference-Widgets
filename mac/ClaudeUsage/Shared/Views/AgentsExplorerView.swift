// AgentsExplorerView.swift
// Header row + scrollable categorical / flat-match / empty-state body.
// Spec § Components → Agents explorer.

import SwiftUI
import AppIntents

// MARK: - AgentsExplorerView

struct AgentsExplorerView: View {
    @Environment(\.theme) private var theme

    var agents: [AgentInfo]
    var columnCount: Int = 3          // 3 for V4, 4 for V6
    var agentFontSize: CGFloat = 9.5  // 9.5pt V4, 10pt V6
    var columnGap: CGFloat = 10       // 10pt V4, 12pt V6
    var headerLabel: String = "AGENTS"
    var headerFontSize: CGFloat = 11  // 11pt V4, 12pt V6
    var v4CapPerCategory: Bool = true  // V4 caps at 2 + "+N more"
    var isCollapsed: Bool = false      // V4 only

    /// The persisted committed query. Read-only inside the widget; updated
    /// only from the host app via claudeusage://search deep-link.
    var committedQuery: String

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            if !isCollapsed {
                Spacer(minLength: 4)
                bodyContent
            }
        }
    }

    // MARK: - Header row

    private var headerRow: some View {
        HStack(spacing: 8) {
            // Collapse toggle (V4 only when the parent sets isCollapsed)
            Button(intent: ToggleAgentsCollapseIntent()) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 22, minHeight: 22)
            .contentShape(Rectangle())

            // "AGENTS (N)" or "AGENTS (matched/total)" label
            Text(headerCountText)
                .font(.system(size: headerFontSize, weight: .black))
                .kerning(0.5)
                .foregroundStyle(theme.accent)
                .textCase(.uppercase)

            Spacer(minLength: 0)

            // Search affordance (hidden when collapsed)
            if !isCollapsed {
                SearchInputView(
                    committedQuery: committedQuery,
                    placeholder: columnCount >= 4 ? "search agents…" : "search…"
                )
            }
        }
    }

    // MARK: - Header count text

    private var headerCountText: String {
        let total = agents.count
        let q = committedQuery.trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            return "\(headerLabel) (\(total))"
        } else {
            let matched = agents.matching(query: q).count
            return "\(headerLabel) (\(matched)/\(total))"
        }
    }

    // MARK: - Body content

    @ViewBuilder
    private var bodyContent: some View {
        if agents.isEmpty {
            agentsEmptyState
        } else {
            let q = committedQuery.trimmingCharacters(in: .whitespaces)
            if q.isEmpty {
                categoricalView
            } else {
                let matches = agents.matching(query: q)
                if matches.isEmpty {
                    noMatchesState(query: q)
                } else {
                    flatMatchView(matches: matches, query: q)
                }
            }
        }
    }

    // MARK: - Categorical view

    private var categoricalView: some View {
        let groups = agents.grouped()
        let perCol = Int(ceil(Double(groups.count) / Double(columnCount)))
        return HStack(alignment: .top, spacing: columnGap) {
            ForEach(0..<columnCount, id: \.self) { col in
                let start = col * perCol
                let end   = min(start + perCol, groups.count)
                VStack(alignment: .leading, spacing: 0) {
                    if start < end {
                        ForEach(start..<end, id: \.self) { idx in
                            CategoryBlock(
                                category: groups[idx].category,
                                agents: groups[idx].agents,
                                useShortLabel: columnCount < 4,
                                capAt: v4CapPerCategory ? 2 : Int.max,
                                fontSize: agentFontSize,
                                committedQuery: committedQuery
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    // MARK: - Flat match view

    @ViewBuilder
    private func flatMatchView(matches: [AgentInfo], query: String) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(matches) { agent in
                    AgentItemView(
                        agent: agent,
                        fontSize: agentFontSize,
                        searchQuery: query,
                        showCategory: true
                    )
                }
            }
        }
    }

    // MARK: - No matches state

    @ViewBuilder
    private func noMatchesState(query: String) -> some View {
        Text("no agents match \"\(query)\"")
            .font(.system(size: 11).italic())
            .foregroundStyle(theme.fgDim)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Agents empty state

    private var agentsEmptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("no agents installed")
                .font(.system(size: 11).italic())
                .foregroundStyle(theme.fgDim)
            (Text("run ")
             + Text("install-agents.sh")
                .font(.system(size: 9).monospaced())
             + Text(" from the docs"))
            .font(.system(size: 9))
            .foregroundStyle(theme.fgDim)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - CategoryBlock

struct CategoryBlock: View {
    @Environment(\.theme) private var theme

    var category: AgentCategory
    var agents: [AgentInfo]
    var useShortLabel: Bool = true
    var capAt: Int = 2
    var fontSize: CGFloat = 9.5
    var committedQuery: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Category label
            Text(useShortLabel ? category.shortLabel : category.fullLabel)
                .font(.system(size: 8.5, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(theme.accent)
                .textCase(.uppercase)
                .padding(.bottom, 1)

            // Agent items
            let visible = Array(agents.prefix(capAt))
            let hidden  = max(0, agents.count - capAt)

            ForEach(visible) { agent in
                AgentItemView(
                    agent: agent,
                    fontSize: fontSize,
                    searchQuery: committedQuery
                )
            }

            if hidden > 0 {
                Text("+ \(hidden) more")
                    .font(.system(size: 9).italic())
                    .foregroundStyle(theme.fgDim)
                    .padding(.leading, 4)
            }
        }
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
