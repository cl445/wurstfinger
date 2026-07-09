//
//  StyleSettingsView.swift
//  wurstfinger
//
//  Theme selection for the keyboard appearance.
//

import SwiftUI

struct StyleSettingsView: View {
    @AppStorage(SettingsKey.selectedThemeLight.rawValue, store: SharedDefaults.store)
    private var selectedThemeLight = BuiltInThemes.classic.id

    @AppStorage(SettingsKey.selectedThemeDark.rawValue, store: SharedDefaults.store)
    private var selectedThemeDark = BuiltInThemes.classic.id

    @AppStorage(SettingsKey.themeSeparateDarkSlot.rawValue, store: SharedDefaults.store)
    private var separateDarkSlot = false

    /// Which slot the gallery currently edits and previews. Only meaningful
    /// while `separateDarkSlot` is on; otherwise selection writes both slots.
    @State private var editingAppearance: ColorScheme = .light

    @AppStorage(SettingsKey.keyAspectRatio.rawValue, store: SharedDefaults.store)
    private var previewAspectRatio = DeviceLayout.defaultKeyAspectRatio

    @AppStorage(SettingsKey.keyboardWidthPoints.rawValue, store: SharedDefaults.store)
    private var previewWidth = DeviceLayout.defaultKeyboardWidth

    @AppStorage(SettingsKey.keyboardHorizontalPosition.rawValue, store: SharedDefaults.store)
    private var previewPosition = DeviceLayout.defaultKeyboardPosition

    /// The theme id the gallery currently reflects: the dark slot while editing
    /// dark mode, otherwise the light slot (which both slots share when the
    /// separate-dark-slot toggle is off).
    private var activeThemeId: String {
        separateDarkSlot && editingAppearance == .dark ? selectedThemeDark : selectedThemeLight
    }

    var body: some View {
        VStack(spacing: 20) {
            // Keyboard Preview — forced into the edited appearance so the dark
            // slot can be previewed on a light device (and vice versa).
            InteractiveKeyboardPreview(
                aspectRatio: $previewAspectRatio,
                width: $previewWidth,
                position: $previewPosition,
                appearanceOverride: separateDarkSlot ? editingAppearance : nil
            )
            .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 24) {
                    appearanceSection
                    stylesSection
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 20)
        .navigationTitle("Style")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Toggle for assigning a separate dark-mode theme, plus the light/dark
    /// segment that picks which slot the gallery edits.
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use a different theme in Dark Mode", isOn: $separateDarkSlot)
                .padding(.horizontal, 16)
                .onChange(of: separateDarkSlot) { _, isOn in
                    if !isOn {
                        // Collapse back to one selection.
                        selectedThemeDark = selectedThemeLight
                        editingAppearance = .light
                    }
                }

            if separateDarkSlot {
                Picker("Editing appearance", selection: $editingAppearance) {
                    Label("Light Mode", systemImage: "sun.max").tag(ColorScheme.light)
                    Label("Dark Mode", systemImage: "moon").tag(ColorScheme.dark)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
            }
        }
    }

    /// The built-in themes as descriptive cards.
    private var stylesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visual Style")
                .font(.headline)
                .padding(.horizontal, 16)

            ForEach(BuiltInThemes.all) { theme in
                themeOption(theme)
            }

            if activeThemeId == BuiltInThemes.liquidGlass.id {
                if #unavailable(iOS 26.0) {
                    Text("Liquid Glass is designed for iOS 26 and later. On earlier versions a simplified translucent style is used.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    /// Assigns the theme to the slot being edited. With the separate-dark-slot
    /// toggle off, both slots follow one selection.
    private func select(_ theme: KeyboardThemeDefinition) {
        if separateDarkSlot {
            if editingAppearance == .dark {
                selectedThemeDark = theme.id
            } else {
                selectedThemeLight = theme.id
            }
        } else {
            selectedThemeLight = theme.id
            selectedThemeDark = theme.id
        }
    }

    private func themeOption(_ theme: KeyboardThemeDefinition) -> some View {
        Button {
            select(theme)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.displayName)
                        .font(.body)
                        .foregroundColor(.primary)

                    if let description = theme.displayDescription {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if activeThemeId == theme.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(activeThemeId == theme.id ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

#Preview {
    NavigationStack {
        StyleSettingsView()
    }
}
