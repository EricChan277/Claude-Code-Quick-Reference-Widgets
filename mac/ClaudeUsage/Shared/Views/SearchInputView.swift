// SearchInputView.swift
// Search input with leading magnifier SF Symbol + trailing clear button.
// Spec § Components → Search input, § Icons.

import SwiftUI
import AppIntents

// MARK: - SearchInputView

struct SearchInputView: View {
    @Environment(\.theme) private var theme

    @Binding var query: String
    var placeholder: String = "search…"
    var isFocused: Bool = false

    // Debounce timer reference (stored outside the view to survive redraws)
    @State private var debounceTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack(alignment: .leading) {
            // Background + border
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.chipBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isFocused ? theme.accent : theme.chipBorder, lineWidth: 1)
                )
                .frame(height: 22)

            HStack(spacing: 0) {
                // Leading magnifier icon (SF Symbol, not unicode ⌕)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(theme.fgDim)
                    .allowsHitTesting(false)
                    .padding(.leading, 6)

                // Text field
                TextField(placeholder, text: $query)
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.fg)
                    .textFieldStyle(.plain)
                    .padding(.leading, 3)
                    .padding(.trailing, query.isEmpty ? 6 : 22)
                    .onChange(of: query) { _, newValue in
                        // Local filtering is immediate (no intent per keystroke).
                        // Spec § Interactions → Search: debounce commit at 250ms.
                        debounceTask?.cancel()
                        debounceTask = Task {
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            guard !Task.isCancelled else { return }
                            // Fire intent only on debounced pause
                            _ = try? await SetSearchQueryIntent(query: newValue).perform()
                        }
                    }

                Spacer(minLength: 0)
            }

            // Trailing clear button (SF Symbol xmark.circle.fill, not unicode ×)
            if !query.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        query = ""
                        debounceTask?.cancel()
                        debounceTask = Task {
                            _ = try? await SetSearchQueryIntent(query: "").perform()
                        }
                    } label: {
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
        }
        .frame(height: 22)
    }
}

