//
//  BuiltInThemes.swift
//  Wurstfinger
//
//  The compiled-in themes. Their ids are API — persisted selections and
//  future export codes reference them — and must never change.
//

import Foundation

enum BuiltInThemes {
    /// System-color theme matching the pre-engine "classic" style.
    static let classic = KeyboardThemeDefinition(
        id: "classic",
        name: "Classic",
        boardBackground: .color(.semantic(.systemBackground)),
        keyFill: .color(.semantic(.secondarySystemBackground)),
        keyFillActive: .color(.semantic(.tertiarySystemFill)),
        keyBorder: nil,
        keyBorderWidth: 0,
        cornerRadius: Double(KeyboardConstants.KeyDimensions.cornerRadius),
        mainLabel: .semantic(.primary),
        utilityLabel: .semantic(.primary),
        hintLetter: .semantic(.primary, opacity: 0.65),
        hintSymbol: .semantic(.secondary, opacity: 0.55),
        hintIconProminent: .semantic(.primary, opacity: 0.5),
        hintIconSubtle: .semantic(.secondary, opacity: 0.45)
    )

    /// Bar-material theme matching the pre-engine "liquidGlass" style. The
    /// board is a near-invisible color fill, not a material — that is the
    /// touch fix from #198 (see DataDrivenKeyboardRootView).
    static let liquidGlass = KeyboardThemeDefinition(
        id: "liquid-glass",
        name: "Liquid Glass",
        // A faint neutral board: it reads as clear over the
        // `UIInputView(.keyboard)` backdrop (so the keyboard matches the system
        // row) while staying just opaque enough to keep the inter-key gaps
        // tappable (see `keyboardBackground` / `minimumBoardOpacity`, #198).
        boardBackground: .color(.semantic(.gray, opacity: 0.02)),
        keyFill: .material,
        keyFillActive: .material,
        keyBorder: .semantic(.primary, opacity: 0.1),
        keyBorderWidth: 0.5,
        cornerRadius: Double(KeyboardConstants.KeyDimensions.cornerRadius),
        mainLabel: .semantic(.primary),
        utilityLabel: .semantic(.primary),
        hintLetter: .semantic(.primary, opacity: 0.65),
        hintSymbol: .semantic(.secondary, opacity: 0.55),
        hintIconProminent: .semantic(.primary, opacity: 0.5),
        hintIconSubtle: .semantic(.secondary, opacity: 0.45)
    )

    /// The two adaptive/material styles, shown as cards in the gallery.
    static let styles: [KeyboardThemeDefinition] = [classic, liquidGlass]

    // MARK: - Color palettes

    /// The 16 fixed-color palettes ported from MessagEase, shown as swatches in
    /// the gallery. Each is derived from four channels (key/main/hint/pressed)
    /// via `paletteTheme`; the order matches the original app.
    static let palettes: [KeyboardThemeDefinition] = [
        paletteTheme(id: "black-yellow", name: "Black & Yellow", key: 0x000000, main: 0xFFF828, hint: 0xFFFFFF, pressed: 0x1E1E1E),
        paletteTheme(id: "black-red", name: "Black & Red", key: 0x000000, main: 0xFA3838, hint: 0xFFA459, pressed: 0x1E1E1E),
        paletteTheme(id: "terracotta", name: "Terracotta", key: 0x8A5042, main: 0x000000, hint: 0x1F2A4F, pressed: 0xC87460),
        paletteTheme(id: "black-violet", name: "Black & Violet", key: 0x000000, main: 0xCC66FF, hint: 0xFF578A, pressed: 0x1E1E1E),
        paletteTheme(id: "jade", name: "Jade", key: 0x009C7D, main: 0xFF0000, hint: 0xFFEE00, pressed: 0x1EE2B5),
        paletteTheme(id: "cornflower", name: "Cornflower", key: 0x5599EE, main: 0x6611AA, hint: 0x6611DD, pressed: 0x7BDDFF),
        paletteTheme(id: "turquoise", name: "Turquoise", key: 0x00C8CC, main: 0x4D2D78, hint: 0xFFFF00, pressed: 0x1EFFFF),
        paletteTheme(id: "mustard", name: "Mustard", key: 0xE1CF04, main: 0x265100, hint: 0x186EAA, pressed: 0xFFFF22),
        paletteTheme(id: "grape", name: "Grape", key: 0x8822CC, main: 0x68FF32, hint: 0x55DCDC, pressed: 0xC540FF),
        paletteTheme(id: "scarlet", name: "Scarlet", key: 0xEE3A3A, main: 0xFFD900, hint: 0x6E0000, pressed: 0xFF5858),
        paletteTheme(id: "olive", name: "Olive", key: 0x4A4400, main: 0x75C012, hint: 0xEBEB33, pressed: 0x6B621E),
        paletteTheme(id: "rust", name: "Rust", key: 0x8A2E00, main: 0xFF5A51, hint: 0xFFEE00, pressed: 0xC84C1E),
        darkGold,
        paletteTheme(id: "forest", name: "Forest", key: 0x265C00, main: 0xFFB947, hint: 0x16FF00, pressed: 0x44851E),
        paletteTheme(id: "midnight-blue", name: "Midnight Blue", key: 0x1D2F80, main: 0x06CDF5, hint: 0xFFEE00, pressed: 0x3B4DB9),
        paletteTheme(id: "espresso", name: "Espresso", key: 0x261001, main: 0xF1F506, hint: 0xFF1E00, pressed: 0x442E1F),
    ]

    /// The default gold palette (MessagEase theme 12). Kept as a named constant
    /// because its id is referenced by the legacy-style migration and its name
    /// is localized (unlike the other palettes, which use their proper name).
    static let darkGold = paletteTheme(
        id: "dark-gold", name: "Dark Gold",
        key: 0x333A48, main: 0xD1AA05, hint: 0xFFFFFF, pressed: 0x4A5468
    )

    static let all: [KeyboardThemeDefinition] = styles + palettes

    static let ids: Set<String> = Set(all.map(\.id))

    static func theme(id: String) -> KeyboardThemeDefinition? {
        all.first { $0.id == id }
    }

    /// Builds a fixed-color palette theme from four MessagEase channels
    /// (see THEME_ENGINE_CONCEPT.md §3): the board is a darkened key color, the
    /// border is light or dark depending on the key's luminance, and the hint
    /// roles carry their prominence as alpha over the single hint color.
    private static func paletteTheme(
        id: String, name: String, key: UInt32, main: UInt32, hint: UInt32, pressed: UInt32
    ) -> KeyboardThemeDefinition {
        func fixed(_ rgb: UInt32, alpha: Double = 1) -> ThemeColor {
            .fixed(hex: HexColor.string(from: .init(rgb: rgb, alpha: alpha)))
        }
        let keyIsLight = HexColor.luminance(of: key) > 0.5
        return KeyboardThemeDefinition(
            id: id,
            name: name,
            boardBackground: .color(fixed(HexColor.scaled(key, by: 0.725))),
            keyFill: .color(fixed(key)),
            keyFillActive: .color(fixed(pressed)),
            keyBorder: keyIsLight ? fixed(0x000000, alpha: 0.18) : fixed(0xFFFFFF, alpha: 0.12),
            keyBorderWidth: 0.5,
            cornerRadius: Double(KeyboardConstants.KeyDimensions.cornerRadius),
            mainLabel: fixed(main),
            utilityLabel: fixed(hint),
            hintLetter: fixed(hint, alpha: 0.9),
            hintSymbol: fixed(hint, alpha: 0.7),
            hintIconProminent: fixed(hint, alpha: 0.5),
            hintIconSubtle: fixed(hint, alpha: 0.45)
        )
    }
}

extension KeyboardThemeDefinition {
    /// Localized display name for built-ins; user themes show their stored
    /// name verbatim.
    var displayName: String {
        switch id {
        case BuiltInThemes.classic.id: String(localized: "Classic")
        case BuiltInThemes.liquidGlass.id: String(localized: "Liquid Glass")
        case BuiltInThemes.darkGold.id: String(localized: "Dark Gold")
        default: name
        }
    }

    /// Short description shown in the theme list (built-ins only).
    var displayDescription: String? {
        switch id {
        case BuiltInThemes.classic.id: String(localized: "Traditional opaque keys")
        case BuiltInThemes.liquidGlass.id: String(localized: "Transparent glass effect (iOS 26+)")
        case BuiltInThemes.darkGold.id: String(localized: "Dark keys with golden letters")
        default: nil
        }
    }
}
