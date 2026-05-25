// SparklineView.swift
// 24-point hourly sparkline with gradient fill.
// Spec § V6 layout spec → Sparkline.

import SwiftUI

// MARK: - SparklineView

struct SparklineView: View {
    @Environment(\.theme) private var theme

    /// 24 integers (hourly token-per-minute buckets).
    var points: [Int]

    /// Tokens/min peak rate to show in the header.
    var peakRate: Int { points.max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header row: "LAST 24H" + peak rate
            HStack(alignment: .firstTextBaseline) {
                Text("LAST 24H")
                    .font(.system(size: 10, weight: .regular))
                    .kerning(0.4)
                    .foregroundStyle(theme.fgDim)
                    .textCase(.uppercase)
                Spacer()
                Text("\(peakRate) tok/min")
                    .font(.system(size: 10).monospaced())
                    .foregroundStyle(theme.fgMuted)
            }

            // Spark canvas
            sparkCanvas
                .frame(minHeight: 24)
        }
    }

    // MARK: - Canvas drawing

    @ViewBuilder
    private var sparkCanvas: some View {
        Canvas { ctx, size in
            guard points.count > 1 else { return }
            let maxVal = Double(points.max() ?? 1)
            let safeMax = maxVal > 0 ? maxVal : 1
            let n = points.count
            let stepX = size.width / CGFloat(n - 1)
            let h = size.height

            func pt(_ i: Int) -> CGPoint {
                CGPoint(
                    x: CGFloat(i) * stepX,
                    y: h - CGFloat(points[i]) / safeMax * h
                )
            }

            // Build line path
            var linePath = Path()
            linePath.move(to: pt(0))
            for i in 1..<n {
                linePath.addLine(to: pt(i))
            }

            // Build fill path (close below the line)
            var fillPath = linePath
            fillPath.addLine(to: CGPoint(x: pt(n - 1).x, y: h))
            fillPath.addLine(to: CGPoint(x: pt(0).x, y: h))
            fillPath.closeSubpath()

            // Area gradient fill: accent @ 30% → transparent
            let gradient = Gradient(stops: [
                .init(color: theme.accent.opacity(0.30), location: 0),
                .init(color: theme.accent.opacity(0), location: 1)
            ])
            let gradientShading = GraphicsContext.Shading.linearGradient(
                gradient,
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: h)
            )
            ctx.fill(fillPath, with: gradientShading)

            // Line stroke
            ctx.stroke(
                linePath,
                with: .color(theme.accent),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
