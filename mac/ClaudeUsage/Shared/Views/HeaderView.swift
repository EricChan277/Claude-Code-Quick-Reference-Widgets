// HeaderView.swift
// "CLAUDE USAGE" + model name + "updated N ago" header row.
// Identical in V4 and V6. Spec § Components → Header.

import SwiftUI

// MARK: - WidgetHeaderView

struct WidgetHeaderView: View {
    @Environment(\.theme) private var theme

    var modelName: String
    var lastRefreshedAt: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("CLAUDE USAGE")
                .font(.system(size: 13, weight: .black))
                .kerning(0.5)
                .foregroundStyle(theme.fg)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(modelName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.accent)

                Text(lastRefreshedAt.updatedAgoString())
                    .font(.system(size: 9))
                    .foregroundStyle(theme.fgDim)
            }
        }
    }
}

// MARK: - Skeleton header

struct SkeletonHeaderView: View {
    @Environment(\.theme) private var theme
    @State private var opacity: Double = 0.6

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("CLAUDE USAGE")
                .font(.system(size: 13, weight: .black))
                .kerning(0.5)
                .foregroundStyle(theme.fg)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.track)
                    .frame(width: 70, height: 10)
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.track)
                    .frame(width: 50, height: 8)
            }
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    opacity = 1.0
                }
            }
        }
    }
}

// MARK: - Divider

struct ThemeDivider: View {
    @Environment(\.theme) private var theme
    var marginTop: CGFloat = 8
    var marginBottom: CGFloat = 6

    var body: some View {
        Rectangle()
            .fill(theme.rule)
            .frame(height: 1)
            .padding(.top, marginTop)
            .padding(.bottom, marginBottom)
    }
}
