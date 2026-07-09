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

    var body: some View {
        VStack(spacing: 20) {
            // Keyboard Preview
            InteractiveKeyboardPreview(aspectRatio: $previewAspectRatio, width: $previewWidth, position: $previewPosition)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 24) {
                    // Theme Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Visual Style")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        ForEach(BuiltInThemes.all) { theme in
                            themeOption(theme)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 20)
        .navigationTitle("Style")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeOption(_ theme: KeyboardThemeDefinition) -> some View {
        Button {
            // Both appearance slots follow one selection until the gallery
            // gains its separate light/dark assignment (milestone M2).
            selectedThemeLight = theme.id
            selectedThemeDark = theme.id
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

#Preview {
    NavigationStack {
        StyleSettingsView()
    }
}
