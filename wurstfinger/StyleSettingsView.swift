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
    private var previewAspectRatio = DeviceLayoutUtils.defaultKeyAspectRatio

    @AppStorage(SettingsKey.keyboardWidthPoints.rawValue, store: SharedDefaults.store)
    private var previewWidth = DeviceLayoutUtils.defaultKeyboardWidth

    @AppStorage(SettingsKey.keyboardHorizontalPosition.rawValue, store: SharedDefaults.store)
    private var previewPosition = DeviceLayoutUtils.defaultKeyboardPosition

    /// Grid columns for the color-palette swatches.
    private let paletteColumns = [GridItem(.adaptive(minimum: 64), spacing: 10)]

    /// User-created themes, reloaded from the store after every edit.
    @State private var userThemes: [KeyboardThemeDefinition] = ThemeStore.userThemes()

    /// The theme currently open in the editor sheet.
    @State private var editingTheme: KeyboardThemeDefinition?

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
                    palettesSection
                    userThemesSection
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 20)
        .navigationTitle("Style")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTheme) { theme in
            ThemeEditorView(
                theme: theme,
                onSave: { updated in
                    ThemeStore.saveUserTheme(updated)
                    reloadUserThemes()
                },
                onDelete: { id in
                    ThemeStore.deleteUserTheme(id: id)
                    reloadUserThemes()
                }
            )
        }
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

    /// Adaptive/material styles (Classic, Liquid Glass) as descriptive cards.
    private var stylesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Styles")
                .font(.headline)
                .padding(.horizontal, 16)

            ForEach(BuiltInThemes.styles) { theme in
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

    /// Fixed-color palettes as a swatch grid.
    private var palettesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color Themes")
                .font(.headline)
                .padding(.horizontal, 16)

            LazyVGrid(columns: paletteColumns, spacing: 10) {
                ForEach(BuiltInThemes.palettes) { theme in
                    swatchButton(theme)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// User-created themes as a swatch grid, with edit/delete in the menu.
    /// Hidden until the user duplicates their first theme.
    @ViewBuilder private var userThemesSection: some View {
        if !userThemes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("My Themes")
                    .font(.headline)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: paletteColumns, spacing: 10) {
                    ForEach(userThemes) { theme in
                        swatchButton(theme)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    /// A selectable swatch with the shared theme context menu.
    private func swatchButton(_ theme: KeyboardThemeDefinition) -> some View {
        Button {
            select(theme)
        } label: {
            ThemeSwatch(theme: theme, isSelected: activeThemeId == theme.id)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.displayName)
        .contextMenu { themeMenu(for: theme) }
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
        .contextMenu { themeMenu(for: theme) }
    }

    // MARK: - Theme actions

    /// Shared context menu: any theme can be duplicated into an editable copy;
    /// user themes can also be edited and deleted (built-ins cannot).
    @ViewBuilder private func themeMenu(for theme: KeyboardThemeDefinition) -> some View {
        Button {
            duplicate(theme)
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }

        if !theme.isBuiltIn {
            Button {
                editingTheme = theme
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                ThemeStore.deleteUserTheme(id: theme.id)
                reloadUserThemes()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// Creates a user-owned copy and opens it in the editor immediately.
    private func duplicate(_ theme: KeyboardThemeDefinition) {
        let copy = ThemeStore.duplicate(theme, existing: userThemes)
        ThemeStore.saveUserTheme(copy)
        reloadUserThemes()
        editingTheme = copy
    }

    private func reloadUserThemes() {
        userThemes = ThemeStore.userThemes()
    }
}

/// Miniature key rendering a palette: key fill, main letter, hint dot. Draws
/// from the theme's own resolved colors, so it always matches the keyboard.
private struct ThemeSwatch: View {
    let theme: KeyboardThemeDefinition
    let isSelected: Bool

    var body: some View {
        let resolved = theme.resolved()
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(keyColor(resolved.keyFill))

            Text(verbatim: "a")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(resolved.mainLabel)

            Circle()
                .fill(resolved.hintLetter)
                .frame(width: 5, height: 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(6)
        }
        .frame(height: 48)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                    lineWidth: isSelected ? 2.5 : 0.5
                )
        )
    }

    /// The swatch fill color. Palettes are always color fills; the material
    /// fallback is only a safety net (styles aren't shown as swatches).
    private func keyColor(_ fill: ResolvedFill) -> Color {
        if case let .color(color) = fill {
            return color
        }
        return Color(.secondarySystemBackground)
    }
}

#Preview {
    NavigationStack {
        StyleSettingsView()
    }
}
