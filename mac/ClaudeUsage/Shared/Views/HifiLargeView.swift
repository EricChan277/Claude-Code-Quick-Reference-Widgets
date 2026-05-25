// HifiLargeView.swift
// V4 · systemLarge widget body (338×338pt).
// Spec § V4 layout spec.

import SwiftUI

// MARK: - HifiLargeView

struct HifiLargeView: View {
    @Environment(\.theme) private var theme

    var entry: UsageEntry

    /// Committed query read from ~/.claude/widget-state.json at timeline build time.
    /// Updated only from the host app; never mutated inside the widget.
    private var committedQuery: String {
        sharedDefaults.string(forKey: DefaultsKey.committedQuery) ?? ""
    }

    private var isCollapsed: Bool {
        sharedDefaults.bool(forKey: DefaultsKey.agentsCollapsed)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Background tint on top of the material
            theme.bgTint
                .ignoresSafeArea()

            // 2pt leading accent stripe (vertical) – spec: leading edge, not top.
            // Uses overlay on the leftmost 2pt, full height.
            HStack(spacing: 0) {
                Rectangle()
                    .fill(theme.accent)
                    .frame(width: 2)
                    .ignoresSafeArea()
                Spacer()
            }

            // Main content column
            if entry.dataState.isLoading {
                skeletonBody
            } else {
                mainBody
            }
        }
        .containerBackground(.thinMaterial, for: .widget)
    }

    // MARK: - Main body

    private var mainBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            WidgetHeaderView(
                modelName: entry.model,
                lastRefreshedAt: entry.lastRefreshedAt
            )
            .padding(.top, 10)
            .padding(.horizontal, 14)
            .padding(.leading, 2)  // account for accent stripe

            Spacer(minLength: 6)

            // Meter rows (gap: 7pt between them)
            VStack(alignment: .leading, spacing: 7) {
                MeterRow(
                    label: "Current session",
                    percent: entry.session.percent,
                    hasData: entry.session.hasData,
                    barHeight: 4,
                    resetDate: entry.session.resetAt,
                    permissionDenied: entry.dataState.permissionsDenied
                )
                MeterRow(
                    label: "Weekly · all models",
                    percent: entry.weekly.percent,
                    hasData: entry.weekly.hasData,
                    barHeight: 4,
                    resetDate: entry.weekly.resetAt,
                    permissionDenied: entry.dataState.permissionsDenied
                )
                MeterRow(
                    label: "Context window",
                    percent: contextPercent,
                    hasData: entry.context.usedTokens != nil,
                    barHeight: 4,
                    isContext: true,
                    contextUsed: entry.context.usedTokens,
                    contextTotal: entry.context.totalTokens,
                    permissionDenied: entry.dataState.permissionsDenied
                )
            }
            .padding(.horizontal, 16)  // 14pt + 2pt stripe offset

            // Divider
            ThemeDivider(marginTop: 8, marginBottom: 6)
                .padding(.horizontal, 14)

            // Agents section
            AgentsExplorerView(
                agents: entry.agents,
                columnCount: 3,
                agentFontSize: 9.5,
                columnGap: 10,
                headerLabel: "AGENTS",
                headerFontSize: 11,
                v4CapPerCategory: true,
                isCollapsed: isCollapsed,
                committedQuery: committedQuery
            )
            .padding(.horizontal, 14)

            Spacer(minLength: 6)
        }
    }

    // MARK: - Skeleton body

    private var skeletonBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonHeaderView()
                .padding(.top, 10)
                .padding(.horizontal, 16)
            Spacer(minLength: 6)
            VStack(spacing: 7) {
                SkeletonMeterRow()
                SkeletonMeterRow()
                SkeletonMeterRow()
            }
            .padding(.horizontal, 16)
            Spacer()
        }
    }

    // MARK: - Helpers

    private var contextPercent: Double? {
        guard let used = entry.context.usedTokens else { return nil }
        return Double(used) / Double(entry.context.totalTokens)
    }
}
