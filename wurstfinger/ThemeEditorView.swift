//
//  ThemeEditorView.swift
//  wurstfinger
//
//  Edits a single user theme: name, surface fills, and label colors. Works on
//  a local copy and calls back on Save/Delete, so the gallery owns
//  persistence. A live preview renders the working copy through the same
//  `ResolvedTheme` path as the keyboard.
//

import SwiftUI

struct ThemeEditorView: View {
    /// Working copy. Edits stay local until Save.
    @State private var theme: KeyboardThemeDefinition

    let onSave: (KeyboardThemeDefinition) -> Void
    let onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    init(
        theme: KeyboardThemeDefinition,
        onSave: @escaping (KeyboardThemeDefinition) -> Void,
        onDelete: @escaping (String) -> Void
    ) {
        _theme = State(initialValue: theme)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var trimmedName: String {
        theme.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ThemePreviewGrid(theme: theme.resolved())
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("Theme name", text: $theme.name)
                }

                Section("Surfaces") {
                    fillRow("Keyboard background", fill: $theme.boardBackground)
                    fillRow("Key", fill: $theme.keyFill)
                    fillRow("Key (pressed)", fill: $theme.keyFillActive)
                    borderRows
                    cornerRadiusRow
                }

                Section("Labels") {
                    colorRow("Main letter", color: $theme.mainLabel)
                    colorRow("Function label", color: $theme.utilityLabel)
                    colorRow("Hint letter", color: $theme.hintLetter)
                    colorRow("Hint symbol", color: $theme.hintSymbol)
                    colorRow("Prominent icon", color: $theme.hintIconProminent)
                    colorRow("Subtle icon", color: $theme.hintIconSubtle)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Theme", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Edit Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(theme)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .confirmationDialog(
                "Delete this theme?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Theme", role: .destructive) {
                    onDelete(theme.id)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Rows

    /// A color well for a label color. Reads the resolved color; writing stores
    /// a fixed hex (a user theme is fully explicit once edited).
    private func colorRow(_ title: LocalizedStringKey, color: Binding<ThemeColor>) -> some View {
        ColorPicker(
            title,
            selection: Binding(
                get: { color.wrappedValue.resolvedColor() ?? .gray },
                set: { color.wrappedValue = .from($0) }
            ),
            supportsOpacity: true
        )
    }

    /// A color well for a surface fill. The glass material has no single color,
    /// so it reads as a neutral gray and picking any color converts the fill to
    /// a solid color.
    private func fillRow(_ title: LocalizedStringKey, fill: Binding<ThemeFill>) -> some View {
        ColorPicker(
            title,
            selection: Binding(
                get: {
                    if case let .color(color) = fill.wrappedValue {
                        return color.resolvedColor() ?? .gray
                    }
                    return .gray
                },
                set: { fill.wrappedValue = .color(.from($0)) }
            ),
            supportsOpacity: true
        )
    }

    @ViewBuilder private var borderRows: some View {
        Toggle("Key border", isOn: Binding(
            get: { theme.keyBorder != nil },
            set: { isOn in
                theme.keyBorder = isOn ? (theme.keyBorder ?? .fixed(hex: "#00000030")) : nil
                if isOn, theme.keyBorderWidth == 0 { theme.keyBorderWidth = 0.5 }
            }
        ))

        if let border = theme.keyBorder {
            ColorPicker(
                "Border color",
                selection: Binding(
                    get: { border.resolvedColor() ?? .gray },
                    set: { theme.keyBorder = .from($0) }
                ),
                supportsOpacity: true
            )

            HStack {
                Text("Border width")
                Spacer()
                Text(theme.keyBorderWidth, format: .number.precision(.fractionLength(1)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $theme.keyBorderWidth, in: 0.5 ... 4, step: 0.5)
        }
    }

    private var cornerRadiusRow: some View {
        VStack {
            HStack {
                Text("Corner radius")
                Spacer()
                Text(theme.cornerRadius, format: .number.precision(.fractionLength(0)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $theme.cornerRadius, in: 0 ... 24, step: 1)
        }
    }
}

// MARK: - Preview grid

/// A static, representative slice of the keyboard rendered from a resolved
/// theme: the board fill behind a small grid of keys, with a pressed key and a
/// couple of hint glyphs so every editable role is visible at a glance.
struct ThemePreviewGrid: View {
    let theme: ResolvedTheme

    private let letters = [["a", "n", "i"], ["h", "d", "r"], ["t", "e", "s"]]
    /// The center key renders in the pressed fill to preview `keyFillActive`.
    private let pressed = (row: 1, column: 1)

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(letters.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 6) {
                    ForEach(Array(row.enumerated()), id: \.offset) { columnIndex, letter in
                        key(letter, isPressed: rowIndex == pressed.row && columnIndex == pressed.column)
                    }
                }
            }
        }
        .padding(10)
        .background { fill(theme.boardBackground) }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.vertical, 4)
    }

    private func key(_ letter: String, isPressed: Bool) -> some View {
        ZStack {
            fill(isPressed ? theme.keyFillActive : theme.keyFill)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .strokeBorder(theme.keyBorder ?? .clear, lineWidth: theme.keyBorderWidth)
                )

            Text(verbatim: letter)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.mainLabel)

            // Corner hints preview the hint roles.
            Text(verbatim: "+")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.hintLetter)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text(verbatim: "!")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.hintSymbol)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: 52, height: 52)
    }

    @ViewBuilder private func fill(_ resolved: ResolvedFill) -> some View {
        switch resolved {
        case let .color(color): color
        case .material: Rectangle().fill(.regularMaterial)
        }
    }
}

#Preview {
    ThemeEditorView(
        theme: {
            var copy = BuiltInThemes.darkGold
            copy.id = "preview-user"
            copy.name = "My Theme"
            return copy
        }(),
        onSave: { _ in },
        onDelete: { _ in }
    )
}
