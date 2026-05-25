// MeterView.swift
// Rounded-rect progress bar: track + fill rect.
// Spec § Components → Meter row, § V4/V6 layout spec.

import SwiftUI

// MARK: - MeterBar

/// The pure horizontal bar (track + fill). Height and fill color are injected.
struct MeterBar: View {
    @Environment(\.theme) private var theme

    var percent: Double         // 0.0 … 1.0
    var fillColor: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(theme.track)

                // Fill
                if percent > 0 {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(fillColor)
                        .frame(width: max(height, geo.size.width * percent))
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - MeterRow

/// Full meter row: label/value line + bar + hint line.
/// Spec § Components → Meter row.
struct MeterRow: View {
    @Environment(\.theme) private var theme

    var label: String
    var percent: Double?          // nil → show "—" (stale / no data)
    var hasData: Bool = true
    var barHeight: CGFloat = 4
    var resetDate: Date?          // nil → show "no usage in this window"
    var isContext: Bool = false    // context row uses dim value + mono hint
    var contextUsed: Int? = nil
    var contextTotal: Int = 200_000
    var permissionDenied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Label / value row
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.fg)
                Spacer()
                valueText
            }

            // Progress bar
            MeterBar(
                percent: hasData ? (percent ?? 0) : 0,
                fillColor: fillColor,
                height: barHeight
            )

            // Hint text
            hintText
        }
    }

    // MARK: Value text

    @ViewBuilder
    private var valueText: some View {
        if permissionDenied {
            Text("—")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.fgDim)
        } else if let pct = percent, hasData {
            let pctInt = Int((pct * 100).rounded())
            Text("\(pctInt)%")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(pct >= 0.80 ? theme.meterCrit : theme.fg)
        } else if isContext {
            // Context stale or no data: show "—" dimmed
            Text("—")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.fgDim)
        } else {
            Text("0%")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.fgDim)
        }
    }

    // MARK: Hint text

    @ViewBuilder
    private var hintText: some View {
        if permissionDenied {
            Button(intent: OpenGrantAccessIntent()) {
                Text("cannot read ~/.claude — open Claude Usage app to grant access")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.fgDim)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
        } else if isContext {
            contextHint
        } else if !hasData {
            Text("no usage in this window")
                .font(.system(size: 9))
                .foregroundStyle(theme.fgDim)
        } else if let reset = resetDate {
            resetHint(reset: reset)
        }
    }

    @ViewBuilder
    private var contextHint: some View {
        if let used = contextUsed {
            (Text(used.kFormatted).font(.system(size: 9).monospaced()).foregroundStyle(theme.fgMuted)
             + Text(" / ").font(.system(size: 9)).foregroundStyle(theme.fgDim)
             + Text(contextTotal.kFormatted + " tokens").font(.system(size: 9).monospaced()).foregroundStyle(theme.fgDim))
        } else {
            (Text("—").font(.system(size: 9).monospaced()).foregroundStyle(theme.fgDim)
             + Text(" / \(contextTotal.kFormatted) tokens").font(.system(size: 9).monospaced()).foregroundStyle(theme.fgDim))
        }
    }

    @ViewBuilder
    private func resetHint(reset: Date) -> some View {
        let interval = reset.timeIntervalSince(.now)
        if interval > 0 {
            (Text("resets in ").font(.system(size: 9)).foregroundStyle(theme.fgDim)
             + Text(interval.compactDuration).font(.system(size: 9, weight: .semibold)).foregroundStyle(theme.fgMuted)
             + Text(" · " + reset.resetTimeString).font(.system(size: 9)).foregroundStyle(theme.fgDim))
        } else {
            Text("resets soon")
                .font(.system(size: 9))
                .foregroundStyle(theme.fgDim)
        }
    }

    // MARK: Fill color

    private var fillColor: Color {
        guard hasData, let pct = percent else { return .clear }
        return theme.pctColor(pct)
    }
}

// MARK: - Skeleton MeterRow

/// Spec § Data states → Skeleton: placeholder shimmer while loading.
struct SkeletonMeterRow: View {
    @Environment(\.theme) private var theme
    @State private var opacity: Double = 0.6

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.track)
                    .frame(width: 100, height: 10)
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.track)
                    .frame(width: 28, height: 10)
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.track)
                .frame(height: 4)
            RoundedRectangle(cornerRadius: 3)
                .fill(theme.track)
                .frame(width: 160, height: 8)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
            ) {
                opacity = 1.0
            }
        }
    }
}
