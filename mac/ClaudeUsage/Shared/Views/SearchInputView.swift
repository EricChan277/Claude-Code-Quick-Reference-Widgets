// SearchInputView.swift
// Widget-safe search affordance.  WidgetKit on macOS 14+ rejects TextField and
// any keyboard-editable view with a yellow "view not supported" overlay.
//
// Pattern used here (per constraints):
//  • Empty state  → Link(destination: claudeusage://search) styled like the spec
//                   search field.  Tapping deep-links to the host app where a
//                   real TextField lives.
//  • Active query → static pill showing the query text + a separate
//                   Button(intent: ClearSearchIntent()) for the xmark.
//
// Spec § Components → Search input, § Interactions → Search.

import SwiftUI
import AppIntents

// MARK: - SearchInputView

struct SearchInputView: View {
    @Environment(\.theme) private var theme

    /// The currently committed query (read-only in the widget).
    var committedQuery: String
    var placeholder: String = "search…"

    var body: some View {
        if committedQuery.isEmpty {
            emptyAffordance
        } else {
            activeAffordance
        }
    }

    // MARK: - Empty state: Link → host app

    /// Renders like the spec's search field but is a Link so WidgetKit accepts it.
    private var emptyAffordance: some View {
        Link(destination: URL(string: "claudeusage://search")!) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.chipBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.chipBorder, lineWidth: 1)
                    )
                    .frame(height: 22)

                HStack(spacing: 3) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .regular))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(theme.fgDim)
                        .padding(.leading, 6)

                    Text(placeholder)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.fgDim)

                    Spacer(minLength: 0)
                }
            }
            .frame(height: 22)
        }
    }

    // MARK: - Active state: committed query pill + clear button

    private var activeAffordance: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.chipBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.accent, lineWidth: 1)
                )
                .frame(height: 22)

            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(theme.accent)
                    .padding(.leading, 6)

                Text(committedQuery)
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.fg)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 3)
                    .padding(.trailing, 22)

                Spacer(minLength: 0)
            }

            // Trailing clear button — uses AppIntent, WidgetKit-approved.
            HStack {
                Spacer()
                Button(intent: ClearSearchIntent()) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(theme.fgDim)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
                .contentShape(Rectangle())
            }
        }
        .frame(height: 22)
    }
}
