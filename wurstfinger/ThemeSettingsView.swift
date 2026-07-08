//
//  ThemeSettingsView.swift
//  wurstfinger
//
//  Configuration sub-page for the Dark Gold keyboard style: built-in
//  theme presets, per-channel colors, and key shape.
//

import SwiftUI

struct ThemeSettingsView: View {
    @AppStorage(SettingsKey.themeKeyColor.rawValue, store: SharedDefaults.store)
    private var keyHex = KeyboardThemePreset.standard.keyHex

    @AppStorage(SettingsKey.themeMainColor.rawValue, store: SharedDefaults.store)
    private var mainHex = KeyboardThemePreset.standard.mainHex

    @AppStorage(SettingsKey.themeHintColor.rawValue, store: SharedDefaults.store)
    private var hintHex = KeyboardThemePreset.standard.hintHex

    @AppStorage(SettingsKey.themePressedColor.rawValue, store: SharedDefaults.store)
    private var pressedHex = KeyboardThemePreset.standard.pressedHex

    @AppStorage(SettingsKey.themeCornerRadius.rawValue, store: SharedDefaults.store)
    private var cornerRadius = KeyboardTheme.defaultCornerRadius

    @AppStorage(SettingsKey.themeKeyEdges.rawValue, store: SharedDefaults.store)
    private var showKeyEdges = KeyboardTheme.defaultShowKeyEdges

    @AppStorage(SettingsKey.keyAspectRatio.rawValue, store: SharedDefaults.store)
    private var previewAspectRatio = DeviceLayoutUtils.defaultKeyAspectRatio

    @AppStorage(SettingsKey.keyboardScale.rawValue, store: SharedDefaults.store)
    private var previewScale = DeviceLayoutUtils.defaultKeyboardScale

    @AppStorage(SettingsKey.keyboardHorizontalPosition.rawValue, store: SharedDefaults.store)
    private var previewPosition = DeviceLayoutUtils.defaultKeyboardPosition

    var body: some View {
        VStack(spacing: 0) {
            InteractiveKeyboardPreview(aspectRatio: $previewAspectRatio, scale: $previewScale, position: $previewPosition)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 8)

            Form {
                Section("Themes") {
                    presetGrid
                }

                Section("Colors") {
                    ColorPicker("Keys", selection: colorBinding($keyHex), supportsOpacity: false)
                    ColorPicker("Main Letters", selection: colorBinding($mainHex), supportsOpacity: false)
                    ColorPicker("Hints", selection: colorBinding($hintHex), supportsOpacity: false)
                    ColorPicker("Pressed Key", selection: colorBinding($pressedHex), supportsOpacity: false)
                }

                Section("Key Shape") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Corner Radius")
                        Slider(
                            value: $cornerRadius,
                            in: KeyboardTheme.cornerRadiusRange,
                            step: 1
                        )
                    }
                    Toggle("Key Edges", isOn: $showKeyEdges)
                }

                Section {
                    Button("Reset to Default", role: .destructive) {
                        applyPreset(.standard)
                        cornerRadius = KeyboardTheme.defaultCornerRadius
                        showKeyEdges = KeyboardTheme.defaultShowKeyEdges
                    }
                }
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Presets

    private var presetGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
            ForEach(KeyboardThemePreset.all) { preset in
                Button {
                    applyPreset(preset)
                } label: {
                    PresetSwatch(preset: preset, isSelected: isActive(preset))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func applyPreset(_ preset: KeyboardThemePreset) {
        keyHex = preset.keyHex
        mainHex = preset.mainHex
        hintHex = preset.hintHex
        pressedHex = preset.pressedHex
    }

    private func isActive(_ preset: KeyboardThemePreset) -> Bool {
        HexColor.parse(keyHex) == HexColor.parse(preset.keyHex)
            && HexColor.parse(mainHex) == HexColor.parse(preset.mainHex)
            && HexColor.parse(hintHex) == HexColor.parse(preset.hintHex)
            && HexColor.parse(pressedHex) == HexColor.parse(preset.pressedHex)
    }

    // MARK: - Color Binding

    /// Bridges a stored `#RRGGBB` string to the `Color` a `ColorPicker` needs.
    /// Unparsable stored values fall back to the standard palette's key color;
    /// picker colors that cannot be resolved to RGB leave the setting unchanged.
    private func colorBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding(
            get: {
                Color(hexRGB: HexColor.parse(hex.wrappedValue) ?? 0x333A48)
            },
            set: { newColor in
                if let string = HexColor.string(from: newColor) {
                    hex.wrappedValue = string
                }
            }
        )
    }
}

/// Miniature key rendering a preset's palette: key fill, main letter, hint dot.
private struct PresetSwatch: View {
    let preset: KeyboardThemePreset
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hexRGB: HexColor.parse(preset.keyHex) ?? 0x333A48))

            Text(verbatim: "a")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hexRGB: HexColor.parse(preset.mainHex) ?? 0xD1AA05))

            Circle()
                .fill(Color(hexRGB: HexColor.parse(preset.hintHex) ?? 0xFFFFFF))
                .frame(width: 4, height: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(4)
        }
        .frame(height: 34)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.15),
                    lineWidth: isSelected ? 2 : 0.5
                )
        )
        .accessibilityLabel(Text(verbatim: preset.name))
    }
}

#Preview {
    NavigationStack {
        ThemeSettingsView()
    }
}
