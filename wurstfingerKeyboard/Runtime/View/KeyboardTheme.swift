//
//  KeyboardTheme.swift
//  Wurstfinger
//
//  Fixed color palette for themed keyboard styles.
//

import SwiftUI

/// Color palette used by themed keyboard styles.
///
/// `classic` and `liquidGlass` derive their appearance from semantic system
/// colors and do not carry a theme. The MessagEase style renders from a fixed
/// palette instead, so it looks the same in light and dark mode — matching how
/// MessagEase themes behave. Kept as plain data so a follow-up can make the
/// values user-configurable.
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

    /// The default MessagEase palette (theme 12 of the original app): dark
    /// slate keys, golden main letters, white hints. The pressed fill is a
    /// lightened key color rather than MessagEase's "busy" gray, which is a
    /// text color there.
    static let messagEase = KeyboardTheme(
        boardBackground: Color(hexRGB: 0x252A34),
        keyBackground: Color(hexRGB: 0x333A48),
        keyBackgroundActive: Color(hexRGB: 0x4A5468),
        mainLabel: Color(hexRGB: 0xD1AA05),
        hintLabel: .white,
        keyBorder: Color.white.opacity(0.12),
        keyBorderWidth: 0.5
    )
}

extension KeyboardStyle {
    /// Fixed palette for themed styles; nil for styles that render from
    /// semantic system colors.
    var theme: KeyboardTheme? {
        switch self {
        case .classic, .liquidGlass:
            nil
        case .messagEase:
            .messagEase
        }
    }
}

extension Color {
    /// Opaque color from a 0xRRGGBB literal.
    fileprivate init(hexRGB value: UInt32) {
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
