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

    @AppStorage(SettingsKey.keyAspectRatio.rawValue, store: SharedDefaults.store)
    private var previewAspectRatio = DeviceLayoutUtils.defaultKeyAspectRatio

    @AppStorage(SettingsKey.keyboardWidthPoints.rawValue, store: SharedDefaults.store)
    private var previewWidth = DeviceLayoutUtils.defaultKeyboardWidth

    @AppStorage(SettingsKey.keyboardHorizontalPosition.rawValue, store: SharedDefaults.store)
    private var previewPosition = DeviceLayoutUtils.defaultKeyboardPosition

    /// Grid columns for the color-palette swatches.
    private let paletteColumns = [GridItem(.adaptive(minimum: 64), spacing: 10)]

    var body: some View {
        VStack(spacing: 20) {
            // Keyboard Preview
            InteractiveKeyboardPreview(aspectRatio: $previewAspectRatio, width: $previewWidth, position: $previewPosition)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 24) {
                    stylesSection
                    palettesSection
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 20)
        .navigationTitle("Style")
        .navigationBarTitleDisplayMode(.inline)
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

            if selectedThemeLight == BuiltInThemes.liquidGlass.id {
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
                    Button {
                        select(theme)
                    } label: {
                        ThemeSwatch(theme: theme, isSelected: selectedThemeLight == theme.id)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(theme.displayName)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// Both appearance slots follow one selection until the gallery gains its
    /// separate light/dark assignment (milestone M2b).
    private func select(_ theme: KeyboardThemeDefinition) {
        selectedThemeLight = theme.id
        selectedThemeDark = theme.id
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

                if selectedThemeLight == theme.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedThemeLight == theme.id ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
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
