//
//  KeyboardTheme.swift
//  Wurstfinger
//
//  Color palette and key shape for themed keyboard styles.
//

import SwiftUI
import UIKit

// MARK: - Theme

/// Colors and key shape used by themed keyboard styles.
///
/// `classic` and `liquidGlass` derive their appearance from semantic system
/// colors and do not carry a theme. The MessagEase style renders from a
/// user-configurable palette instead (`SettingsKey.theme*`), so it looks the
/// same in light and dark mode — matching how MessagEase themes behave.
struct KeyboardTheme: Equatable {
    /// Fill behind the whole keyboard; shows through the gaps between keys.
    var boardBackground: Color
    /// Key fill.
    var keyBackground: Color
    /// Key fill while the key is pressed.
    var keyBackgroundActive: Color
    /// Center label color for letter and number keys.
    var mainLabel: Color
    /// Directional hints and utility glyphs.
    var hintLabel: Color
    /// Thin edge line around each key.
    var keyBorder: Color
    var keyBorderWidth: CGFloat
    var cornerRadius: CGFloat

    static let defaultCornerRadius: Double = 8
    static let defaultShowKeyEdges = true
    static let cornerRadiusRange: ClosedRange<Double> = 0 ... 20

    /// Builds a theme from stored hex colors, falling back to the standard
    /// palette for any value that does not parse.
    init(
        keyHex: String,
        mainHex: String,
        hintHex: String,
        pressedHex: String,
        cornerRadius: Double,
        showKeyEdges: Bool
    ) {
        let standard = KeyboardThemePreset.standard
        let key = HexColor.parse(keyHex) ?? HexColor.parse(standard.keyHex) ?? 0x333A48
        let main = HexColor.parse(mainHex) ?? HexColor.parse(standard.mainHex) ?? 0xD1AA05
        let hint = HexColor.parse(hintHex) ?? HexColor.parse(standard.hintHex) ?? 0xFFFFFF
        let pressed = HexColor.parse(pressedHex) ?? HexColor.parse(standard.pressedHex) ?? 0x4A5468

        boardBackground = Color(hexRGB: Self.boardValue(forKey: key))
        keyBackground = Color(hexRGB: key)
        keyBackgroundActive = Color(hexRGB: pressed)
        mainLabel = Color(hexRGB: main)
        hintLabel = Color(hexRGB: hint)
        // Edge lines must stay visible on any key color, so pick black or
        // white based on the key fill's luminance.
        keyBorder = HexColor.luminance(of: key) > 0.5
            ? Color.black.opacity(0.18)
            : Color.white.opacity(0.12)
        keyBorderWidth = showKeyEdges ? 0.5 : 0
        self.cornerRadius = CGFloat(cornerRadius)
    }

    /// The default MessagEase look (theme 12 of the original app): dark slate
    /// keys, golden main letters, white hints.
    static let messagEase = KeyboardTheme(preset: .standard)

    init(preset: KeyboardThemePreset) {
        self.init(
            keyHex: preset.keyHex,
            mainHex: preset.mainHex,
            hintHex: preset.hintHex,
            pressedHex: preset.pressedHex,
            cornerRadius: Self.defaultCornerRadius,
            showKeyEdges: Self.defaultShowKeyEdges
        )
    }

    /// The board fill derived from a stored key color, for callers that only
    /// need the background (keyboard root view). Slightly darker than the
    /// keys, so the inter-key gaps read as grid lines.
    static func boardBackground(forKeyHex keyHex: String) -> Color {
        let key = HexColor.parse(keyHex) ?? 0x333A48
        return Color(hexRGB: boardValue(forKey: key))
    }

    private static func boardValue(forKey key: UInt32) -> UInt32 {
        HexColor.scaled(key, by: 0.725)
    }
}

// MARK: - Presets

/// One of the built-in palettes, ported from the original MessagEase themes
/// (base → keys, main → letters, extra → hints; the pressed fill is a
/// lightened key color, as MessagEase's "busy" channel is a text color and
/// has no fill equivalent here).
struct KeyboardThemePreset: Equatable, Identifiable {
    let id: Int
    let keyHex: String
    let mainHex: String
    let hintHex: String
    let pressedHex: String

    /// All 16 MessagEase themes, in the original order.
    static let all: [KeyboardThemePreset] = [
        .init(id: 0, keyHex: "#000000", mainHex: "#FFF828", hintHex: "#FFFFFF", pressedHex: "#1E1E1E"),
        .init(id: 1, keyHex: "#000000", mainHex: "#FA3838", hintHex: "#FFA459", pressedHex: "#1E1E1E"),
        .init(id: 2, keyHex: "#8A5042", mainHex: "#000000", hintHex: "#1F2A4F", pressedHex: "#C87460"),
        .init(id: 3, keyHex: "#000000", mainHex: "#CC66FF", hintHex: "#FF578A", pressedHex: "#1E1E1E"),
        .init(id: 4, keyHex: "#009C7D", mainHex: "#FF0000", hintHex: "#FFEE00", pressedHex: "#1EE2B5"),
        .init(id: 5, keyHex: "#5599EE", mainHex: "#6611AA", hintHex: "#6611DD", pressedHex: "#7BDDFF"),
        .init(id: 6, keyHex: "#00C8CC", mainHex: "#4D2D78", hintHex: "#FFFF00", pressedHex: "#1EFFFF"),
        .init(id: 7, keyHex: "#E1CF04", mainHex: "#265100", hintHex: "#186EAA", pressedHex: "#FFFF22"),
        .init(id: 8, keyHex: "#8822CC", mainHex: "#68FF32", hintHex: "#55DCDC", pressedHex: "#C540FF"),
        .init(id: 9, keyHex: "#EE3A3A", mainHex: "#FFD900", hintHex: "#6E0000", pressedHex: "#FF5858"),
        .init(id: 10, keyHex: "#4A4400", mainHex: "#75C012", hintHex: "#EBEB33", pressedHex: "#6B621E"),
        .init(id: 11, keyHex: "#8A2E00", mainHex: "#FF5A51", hintHex: "#FFEE00", pressedHex: "#C84C1E"),
        .init(id: 12, keyHex: "#333A48", mainHex: "#D1AA05", hintHex: "#FFFFFF", pressedHex: "#4A5468"),
        .init(id: 13, keyHex: "#265C00", mainHex: "#FFB947", hintHex: "#16FF00", pressedHex: "#44851E"),
        .init(id: 14, keyHex: "#1D2F80", mainHex: "#06CDF5", hintHex: "#FFEE00", pressedHex: "#3B4DB9"),
        .init(id: 15, keyHex: "#261001", mainHex: "#F1F506", hintHex: "#FF1E00", pressedHex: "#442E1F"),
    ]

    /// MessagEase's default theme (index 12), also our fallback palette.
    static let standard = all[12]
}

// MARK: - Hex Colors

/// Parsing and formatting of `#RRGGBB` strings, the storage format for the
/// theme's color settings.
enum HexColor {
    /// Parses `#RRGGBB` or `RRGGBB` (case-insensitive) into a packed RGB value.
    static func parse(_ string: String) -> UInt32? {
        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else {
            return nil
        }
        return value
    }

    /// Formats a color as `#RRGGBB`, or nil when its components cannot be
    /// resolved into RGB.
    static func string(from color: Color) -> String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        func component(_ value: CGFloat) -> UInt32 {
            UInt32((min(max(value, 0), 1) * 255).rounded())
        }
        return String(format: "#%02X%02X%02X", component(red), component(green), component(blue))
    }

    /// Multiplies each RGB channel by `factor`, clamping to 0...255.
    static func scaled(_ value: UInt32, by factor: Double) -> UInt32 {
        func scale(_ channel: UInt32) -> UInt32 {
            UInt32(min(max(Double(channel) * factor, 0), 255))
        }
        let red = scale((value >> 16) & 0xFF)
        let green = scale((value >> 8) & 0xFF)
        let blue = scale(value & 0xFF)
        return (red << 16) | (green << 8) | blue
    }

    /// Relative luminance (0...1), sufficient for light/dark decisions.
    static func luminance(of value: UInt32) -> Double {
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}

extension Color {
    /// Opaque color from a packed 0xRRGGBB value.
    init(hexRGB value: UInt32) {
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
