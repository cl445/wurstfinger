//
//  ThemeEditorView.swift
//  wurstfinger
//
//  Edits a single user theme: name, the two surfaces, label colors, and the
//  gesture-trail color. Works on a local copy and calls back on Save/Delete,
//  so the gallery owns persistence. The live preview is the real keyboard
//  renderer, driven by the working copy through `themeOverride`.
//

import SwiftUI

struct ThemeEditorView: View {
    /// Working copy. Edits stay local until Save.
    @State private var theme: KeyboardThemeDefinition

    /// Whether Save *creates* the theme. A new theme is an unpersisted
    /// duplicate: Cancel has to leave no trace, and there is nothing to delete
    /// yet. A `Bool` rather than a `…Mode` enum — the glossary reserves that
    /// word for keyboard state.
    let isNewTheme: Bool

    /// The appearance the edited theme is destined for, or nil when it serves
    /// both. Everything that shows a color has to be judged in it: a theme
    /// bound for the dark slot but previewed light invites label colors that
    /// are near-invisible where they actually render — and the color wells
    /// freeze whatever they were seeded with.
    let appearanceOverride: ColorScheme?

    /// The user's real keyboard geometry, threaded through from the gallery so
    /// the preview here matches the one there — and so the corner-radius
    /// slider is judged against the key size the user actually types on.
    @Binding var previewAspectRatio: Double
    @Binding var previewWidth: Double
    @Binding var previewPosition: Double

    let onSave: (KeyboardThemeDefinition) -> Void
    let onDelete: (String) -> Void

    /// The trail color only renders when the user has the trail switched on,
    /// so the editor discloses that instead of offering a control that
    /// silently does nothing.
    @AppStorage(SettingsKey.gestureTrailEnabled.rawValue, store: SharedDefaults.store)
    private var gestureTrailEnabled = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showDeleteConfirmation = false
    @FocusState private var isNameFocused: Bool

    init(
        theme: KeyboardThemeDefinition,
        isNewTheme: Bool,
        appearanceOverride: ColorScheme? = nil,
        previewAspectRatio: Binding<Double> = .constant(DeviceLayoutUtils.defaultKeyAspectRatio),
        previewWidth: Binding<Double> = .constant(DeviceLayoutUtils.defaultKeyboardWidth),
        previewPosition: Binding<Double> = .constant(DeviceLayoutUtils.defaultKeyboardPosition),
        onSave: @escaping (KeyboardThemeDefinition) -> Void,
        onDelete: @escaping (String) -> Void
    ) {
        _theme = State(initialValue: theme)
        self.isNewTheme = isNewTheme
        self.appearanceOverride = appearanceOverride
        _previewAspectRatio = previewAspectRatio
        _previewWidth = previewWidth
        _previewPosition = previewPosition
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var trimmedName: String {
        theme.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The appearance every color in this editor is judged in: the slot's own
    /// when the theme is bound to one, the device's otherwise.
    private var editedAppearance: ColorScheme {
        appearanceOverride ?? systemColorScheme
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // The real renderer, not a mock: it is the only way to
                    // preview glass on glass, and because it mounts the actual
                    // grid, swiping over it draws the trail in the edited color.
                    InteractiveKeyboardPreview(
                        aspectRatio: $previewAspectRatio,
                        width: $previewWidth,
                        position: $previewPosition,
                        appearanceOverride: appearanceOverride,
                        themeOverride: theme
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("Theme name", text: $theme.name)
                        .focused($isNameFocused)
                }

                keysSection
                backgroundSection

                Section("Labels") {
                    colorRow(title: "Main letter", color: $theme.mainLabel)
                    colorRow(title: "Function label", color: $theme.utilityLabel)
                    colorRow(title: "Hint letter", color: $theme.hintLetter)
                    colorRow(title: "Hint symbol", color: $theme.hintSymbol)
                    colorRow(title: "Prominent icon", color: $theme.hintIconProminent)
                    colorRow(title: "Subtle icon", color: $theme.hintIconSubtle)
                }

                gestureTrailSection
                deleteSection
            }
            // Passed as `Text` rather than a ternary over two string literals
            // so the localization coverage test can see both keys.
            .navigationTitle(isNewTheme ? Text("New Theme") : Text("Edit Theme"))
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
            .onAppear {
                guard isNewTheme else { return }
                // A sheet's text field is not in the responder chain yet on the
                // run-loop pass that presents it, so the focus request has to
                // wait for the next one.
                DispatchQueue.main.async { isNameFocused = true }
            }
        }
    }

    // MARK: - Sections

    /// Keys: the glass switch, the key colors it replaces, and the shape
    /// controls that apply either way.
    private var keysSection: some View {
        Section {
            Toggle("Liquid Glass", isOn: Binding(
                get: { theme.keySurface == .glass },
                set: { theme.setGlassKeys($0) }
            ))
            // Both surfaces carry the same visible label in different
            // sections; for VoiceOver the accessibility label is the only
            // thing that tells the two switches apart.
            .accessibilityLabel("Liquid Glass keys")

            // Hidden rather than disabled: a disabled color well still shows a
            // swatch and reads as a control that does something. The footer
            // carries the explanation, which VoiceOver reads with the section.
            if theme.keySurface == .color {
                colorRow(title: "Key", color: $theme.keyColor)
                colorRow(title: "Key (pressed)", color: $theme.keyColorActive)
            }

            // Border and radius stay visible in every state: the radius shapes
            // glass too, and the border is drawn on the pre-iOS-26 fallback.
            borderRows
            cornerRadiusRow
        } header: {
            Text("Keys")
        } footer: {
            if theme.keySurface == .glass {
                // Split per OS: the border controls stay live on both, but only
                // the pre-iOS-26 fallback actually draws the border. Stating
                // that unconditionally told an iOS 26 user — a VoiceOver one in
                // particular — that three controls do something they do not.
                // The literals have to stay on one line each: a comment between
                // `Text(` and the string would hide the key from the
                // localization coverage test.
                // swiftlint:disable line_length
                if #available(iOS 26.0, *) {
                    Text(
                        "Glass keys take their color from what is behind the keyboard, so the key colors do not apply. Corner radius still shapes them. Liquid Glass draws no border, so the border settings only take effect if this theme is used on a device before iOS 26."
                    )
                } else {
                    Text(
                        "Glass keys take their color from what is behind the keyboard, so the key colors do not apply. Corner radius and border still apply: this system renders a simplified translucent style instead of Liquid Glass."
                    )
                }
                // swiftlint:enable line_length
            }
        }
    }

    /// Background: the board behind the keys, which is either a color or
    /// near-clear glass.
    private var backgroundSection: some View {
        Section {
            Toggle("Liquid Glass", isOn: Binding(
                get: { theme.boardSurface == .glass },
                set: { theme.setGlassBoard($0) }
            ))
            .accessibilityLabel("Liquid Glass background")

            if theme.boardSurface == .color {
                colorRow(title: "Keyboard background", color: $theme.boardColor)
            }
        } header: {
            Text("Background")
        } footer: {
            if theme.boardSurface == .glass {
                Text("A glass background lets the app behind the keyboard show through, so the background color does not apply.")
            }
        }
    }

    private var gestureTrailSection: some View {
        Section {
            colorRow(title: "Trail color", color: $theme.gestureTrail)
        } header: {
            Text("Gesture Trail")
        } footer: {
            if !gestureTrailEnabled {
                Text("Turn on Gesture Trail in Settings to draw this color while you swipe.")
            }
        }
    }

    /// Absent while the theme is new — there is nothing persisted to delete,
    /// and Cancel already discards it.
    @ViewBuilder private var deleteSection: some View {
        if !isNewTheme {
            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Theme", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Rows

    /// A color well for one theme role. Seeds from the color as it renders in
    /// the edited appearance — not as it renders in the sheet the user happens
    /// to be looking at — because writing freezes the pick as a fixed hex (a
    /// user theme is fully explicit once edited) and there is no way back.
    private func colorRow(title: LocalizedStringKey, color: Binding<ThemeColor>) -> some View {
        ColorPicker(
            title,
            selection: Binding(
                get: { color.wrappedValue.resolvedColor(in: editedAppearance) ?? .gray },
                set: { color.wrappedValue = .from($0) }
            ),
            supportsOpacity: true
        )
    }

    @ViewBuilder private var borderRows: some View {
        // The coupled write (a border switched on needs a width to render)
        // lives in the model, so the rule is testable — see
        // `KeyboardThemeDefinition.setKeyBorder(_:)`.
        Toggle("Key border", isOn: Binding(
            get: { theme.keyBorder != nil },
            set: { theme.setKeyBorder($0) }
        ))

        if let border = theme.keyBorder {
            ColorPicker(
                "Border color",
                selection: Binding(
                    get: { border.resolvedColor(in: editedAppearance) ?? .gray },
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
            Slider(value: $theme.keyBorderWidth, in: KeyboardThemeDefinition.minimumKeyBorderWidth ... 4, step: 0.5)
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

#Preview {
    ThemeEditorView(
        theme: {
            var copy = BuiltInThemes.darkGold
            copy.id = "preview-user"
            copy.name = "My Theme"
            return copy
        }(),
        isNewTheme: false,
        onSave: { _ in },
        onDelete: { _ in }
    )
}
