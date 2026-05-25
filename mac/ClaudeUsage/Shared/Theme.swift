// Theme.swift
// Design tokens verbatim from the spec § Design tokens.
// All colors are defined here; no inline literals anywhere else.

import SwiftUI

// MARK: - Theme

struct Theme {
    // Primary text
    let fg: Color
    // Bolded hint portions ("3h 28m" inside hint lines)
    let fgMuted: Color
    // Dim text – hints, "updated N ago", category labels secondary content
    let fgDim: Color
    // Horizontal rule
    let rule: Color
    // Meter track + ring track
    let track: Color
    // Meter fill – pct < 50%
    let meter: Color
    // Meter fill – 50% ≤ pct < 80%
    let meterWarn: Color
    // Meter fill + value text – pct ≥ 80%
    let meterCrit: Color
    // Leading accent stripe, model name, section headers, ring arc, sparkline
    let accent: Color
    // Search input background
    let chipBg: Color
    // Search input border
    let chipBorder: Color
    // Agent row hover / copied background
    let chipHoverBg: Color
    // Search highlight background
    let searchHighlight: Color
    // Card background tint (applied at 60% opacity over material)
    let bgTint: Color

    // MARK: - Static instances

    static let dark = Theme(
        fg: Color(hex: "#F2F2F2"),
        fgMuted: Color(hex: "#9A9A9D"),
        fgDim: Color(hex: "#6B6B6E"),
        rule: Color.white.opacity(0.06),
        track: Color(hex: "#3A3A3C"),
        meter: Color(hex: "#7FD07F"),
        meterWarn: Color(hex: "#E8B84A"),
        meterCrit: Color(hex: "#E5634A"),
        accent: Color(hex: "#FF8A3D"),
        chipBg: Color.white.opacity(0.04),
        chipBorder: Color.white.opacity(0.06),
        chipHoverBg: Color(hex: "#FF8A3D").opacity(0.10),
        searchHighlight: Color(hex: "#FF8A3D").opacity(0.28),
        bgTint: Color(hex: "#1C1C1E").opacity(0.60)
    )

    static let light = Theme(
        fg: Color(hex: "#111113"),
        fgMuted: Color(hex: "#6B6B70"),
        fgDim: Color(hex: "#9A9A9D"),
        rule: Color.black.opacity(0.06),
        track: Color.black.opacity(0.08),
        meter: Color(hex: "#3AAF5D"),
        meterWarn: Color(hex: "#C89020"),
        meterCrit: Color(hex: "#C8412A"),
        accent: Color(hex: "#D97557"),
        chipBg: Color.black.opacity(0.025),
        chipBorder: Color.black.opacity(0.06),
        chipHoverBg: Color(hex: "#D97557").opacity(0.10),
        searchHighlight: Color(hex: "#D97557").opacity(0.22),
        bgTint: Color(hex: "#FFFFFF").opacity(0.60)
    )

    // MARK: - pctColor

    /// Maps a usage percentage (0–1) to the appropriate meter fill color.
    /// Ports `pctColor()` from the Windows skin.
    func pctColor(_ pct: Double) -> Color {
        if pct >= 0.80 { return meterCrit }
        if pct >= 0.50 { return meterWarn }
        return meter
    }
}

// MARK: - Environment Key

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .dark
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Theme environment modifier

extension View {
    /// Injects the correct Theme for the current color scheme.
    func withTheme(_ colorScheme: ColorScheme) -> some View {
        self.environment(\.theme, colorScheme == .dark ? .dark : .light)
    }
}

// MARK: - Color(hex:) convenience

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
