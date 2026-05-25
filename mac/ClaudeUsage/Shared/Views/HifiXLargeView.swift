// HifiXLargeView.swift
// V6 · systemExtraLarge widget body (688×338pt).
// Spec § V6 layout spec.

import SwiftUI

// MARK: - HifiXLargeView

struct HifiXLargeView: View {
    @Environment(\.theme) private var theme

    var entry: UsageEntry

    @State private var queryDraft: String = sharedDefaults.string(forKey: DefaultsKey.committedQuery) ?? ""

    var body: some View {
        ZStack(alignment: .leading) {
            theme.bgTint.ignoresSafeArea()

            // 2pt leading accent stripe
            HStack(spacing: 0) {
                Rectangle()
                    .fill(theme.accent)
                    .frame(width: 2)
                    .ignoresSafeArea()
                Spacer()
            }

            if entry.dataState.isLoading {
                skeletonBody
            } else {
                twoColumnBody
            }
        }
        .containerBackground(.thinMaterial, for: .widget)
    }

    // MARK: - Two column layout

    private var twoColumnBody: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left column: 268pt fixed
            leftColumn
                .frame(width: 268)
                .padding(.leading, 2)  // stripe offset

            // Vertical divider
            Rectangle()
                .fill(theme.rule)
                .frame(width: 1)

            // Right column: flex
            rightColumn
                .padding(.leading, 16)
                .padding(.trailing, 12)
        }
    }

    // MARK: - Left column

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            WidgetHeaderView(
                modelName: entry.model,
                lastRefreshedAt: entry.lastRefreshedAt
            )
            .padding(.top, 10)
            .padding(.horizontal, 14)

            // Ring + session block
            HStack(alignment: .center, spacing: 12) {
                if entry.dataState.permissionsDenied {
                    SkeletonRing(diameter: 58, strokeWidth: 7)
                } else {
                    RingView(
                        diameter: 58,
                        strokeWidth: 7,
                        percent: entry.session.hasData ? entry.session.percent : 0
                    )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("SESSION")
                        .font(.system(size: 10, weight: .regular))
                        .kerning(0.4)
                        .foregroundStyle(theme.fgDim)
                        .textCase(.uppercase)

                    let interval = max(entry.session.resetAt.timeIntervalSince(.now), 0)
                    Text(interval.compactDuration)
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                        .kerning(-0.5)
                        .foregroundStyle(theme.fg)

                    Text("resets \(entry.session.resetAt.resetTimeString)")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.fgDim)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            // Weekly + context meters
            VStack(spacing: 7) {
                MeterRow(
                    label: "Weekly · all models",
                    percent: entry.weekly.percent,
                    hasData: entry.weekly.hasData,
                    barHeight: 5,
                    resetDate: entry.weekly.resetAt,
                    permissionDenied: entry.dataState.permissionsDenied
                )
                MeterRow(
                    label: "Context window",
                    percent: contextPercent,
                    hasData: !entry.context.isStale && entry.context.usedTokens != nil,
                    barHeight: 5,
                    isContext: true,
                    contextUsed: entry.context.isStale ? nil : entry.context.usedTokens,
                    contextTotal: entry.context.totalTokens,
                    permissionDenied: entry.dataState.permissionsDenied
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            // Divider
            ThemeDivider(marginTop: 10, marginBottom: 6)
                .padding(.horizontal, 14)

            // Sparkline
            SparklineView(points: entry.sparkline)
                .padding(.horizontal, 14)

            Spacer(minLength: 12)
        }
    }

    // MARK: - Right column

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            AgentsExplorerView(
                agents: entry.agents,
                columnCount: 4,
                agentFontSize: 10,
                columnGap: 12,
                headerLabel: "INSTALLED AGENTS",
                headerFontSize: 12,
                v4CapPerCategory: false,
                isCollapsed: false,
                queryDraft: $queryDraft
            )
            .padding(.top, 10)
        }
    }

    // MARK: - Skeleton body

    private var skeletonBody: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SkeletonHeaderView()
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
                Spacer(minLength: 8)
                HStack(spacing: 12) {
                    SkeletonRing(diameter: 58, strokeWidth: 7)
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.3)).frame(width: 50, height: 8)
                        RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.3)).frame(width: 60, height: 14)
                    }
                }
                .padding(.horizontal, 16)
                Spacer(minLength: 8)
                VStack(spacing: 7) {
                    SkeletonMeterRow()
                    SkeletonMeterRow()
                }
                .padding(.horizontal, 16)
                Spacer()
            }
            .frame(width: 268)
            Spacer()
        }
    }

    // MARK: - Helpers

    private var contextPercent: Double? {
        guard let used = entry.context.usedTokens, !entry.context.isStale else { return nil }
        return Double(used) / Double(entry.context.totalTokens)
    }
}
