// RingView.swift
// Circular progress ring (V6 left column).
// Spec § Components → Ring, § V6 layout spec → Ring + session block.

import SwiftUI

// MARK: - RingView

/// Two-concentric-circle ring: background track full circle + arc fill.
/// Starts at 12 o'clock (rotated -90°), round caps, accent color.
struct RingView: View {
    @Environment(\.theme) private var theme

    /// Diameter in points (spec: 58pt).
    var diameter: CGFloat = 58
    /// Stroke width (spec: 7pt).
    var strokeWidth: CGFloat = 7
    /// Fill fraction 0.0 … 1.0
    var percent: Double

    private var radius: CGFloat { (diameter - strokeWidth) / 2 }

    var body: some View {
        ZStack {
            // Track – full circle
            Circle()
                .stroke(theme.track, lineWidth: strokeWidth)

            // Arc fill – trimmed from 0 → percent, rotated so 0 is at top
            Circle()
                .trim(from: 0, to: CGFloat(percent))
                .stroke(
                    theme.accent,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center label: ~26% of diameter → ≈15pt for 58pt ring
            let labelSize = diameter * 0.26
            let pctInt = Int((percent * 100).rounded())
            Text("\(pctInt)%")
                .font(
                    .system(size: labelSize, weight: .bold)
                    .monospacedDigit()
                )
                .minimumScaleFactor(0.5)
                .foregroundStyle(theme.fg)
                .kerning(-0.5)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Skeleton Ring

struct SkeletonRing: View {
    @Environment(\.theme) private var theme
    var diameter: CGFloat = 58
    var strokeWidth: CGFloat = 7

    @State private var opacity: Double = 0.6

    var body: some View {
        Circle()
            .stroke(theme.track, lineWidth: strokeWidth)
            .frame(width: diameter, height: diameter)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    opacity = 1.0
                }
            }
    }
}
