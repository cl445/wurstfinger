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
        boardSurface: .color,
        boardColor: .semantic(.systemBackground),
        keySurface: .color,
        keyColor: .semantic(.secondarySystemBackground),
        keyColorActive: .semantic(.tertiarySystemFill),
        keyBorder: nil,
        keyBorderWidth: 0,
        cornerRadius: Double(KeyboardConstants.KeyDimensions.cornerRadius),
        mainLabel: .semantic(.primary),
        utilityLabel: .semantic(.primary),
        hintLetter: .semantic(.primary, opacity: 0.65),
        hintSymbol: .semantic(.secondary, opacity: 0.55),
        hintIconProminent: .semantic(.primary, opacity: 0.5),
        hintIconSubtle: .semantic(.secondary, opacity: 0.45),
        // The pre-engine trail color, now a theme role. Its alpha is used as
        // it stands: `GestureTrailOverlay` multiplies in the fade-out only.
        gestureTrail: .semantic(.primary, opacity: KeyboardConstants.GestureTrail.opacity)
    )

    /// Glass theme matching the pre-engine "liquidGlass" style: native Liquid
    /// Glass keys over a board that is a near-invisible color fill rather than
    /// a material — that is the touch fix from #198 (see
    /// `ResolvedTheme.boardBackground` / `KeyboardThemeDefinition.minimumBoardOpacity`).
    ///
    /// The color fields are real fallbacks, not placeholders: switching either
    /// surface back to `.color` has to yield a usable keyboard, so the board
    /// carries Classic's opaque background (a 2% gray would make the toggle
    /// look dead) and the keys carry Classic's key colors.
    static let liquidGlass = KeyboardThemeDefinition(
        id: "liquid-glass",
        name: "Liquid Glass",
        boardSurface: .glass,
        boardColor: .semantic(.systemBackground),
        keySurface: .glass,
        keyColor: .semantic(.secondarySystemBackground),
        keyColorActive: .semantic(.tertiarySystemFill),
        keyBorder: .semantic(.primary, opacity: 0.1),
        keyBorderWidth: 0.5,
        cornerRadius: Double(KeyboardConstants.KeyDimensions.cornerRadius),
        mainLabel: .semantic(.primary),
        utilityLabel: .semantic(.primary),
        hintLetter: .semantic(.primary, opacity: 0.65),
        hintSymbol: .semantic(.secondary, opacity: 0.55),
        hintIconProminent: .semantic(.primary, opacity: 0.5),
        hintIconSubtle: .semantic(.secondary, opacity: 0.45),
        gestureTrail: .semantic(.primary, opacity: KeyboardConstants.GestureTrail.opacity)
    )

    /// Fixed dark-slate/gold palette. Identical in light and dark mode by
    /// design. Hint roles carry their prominence as alpha (0.9/0.7/0.5/0.45
    /// of white), mirroring Classic's opacity hierarchy.
    static let darkGold = KeyboardThemeDefinition(
        id: "dark-gold",
        name: "Dark Gold",
        boardSurface: .color,
        boardColor: .fixed(hex: "#252A34"),
        keySurface: .color,
        keyColor: .fixed(hex: "#333A48"),
        keyColorActive: .fixed(hex: "#4A5468"),
        keyBorder: .fixed(hex: "#FFFFFF1F"),
        keyBorderWidth: 0.5,
        cornerRadius: Double(KeyboardConstants.KeyDimensions.cornerRadius),
        mainLabel: .fixed(hex: "#D1AA05"),
        utilityLabel: .fixed(hex: "#FFFFFF"),
        hintLetter: .fixed(hex: "#FFFFFFE6"),
        hintSymbol: .fixed(hex: "#FFFFFFB3"),
        hintIconProminent: .fixed(hex: "#FFFFFF80"),
        hintIconSubtle: .fixed(hex: "#FFFFFF73"),
        // Gold at 0xA6 (0.65). Measured per WCAG over the key color #333A48:
        // gold at 0.38 reaches only 1.95:1 and disappears under the finger,
        // 0.65 reaches 3.06:1. White at 0.38 would give a comparable 3.09:1 but
        // collides with the already-white `utilityLabel` / `hintLetter` roles.
        gestureTrail: .fixed(hex: "#D1AA05A6")
    )

    static let all: [KeyboardThemeDefinition] = [classic, liquidGlass, darkGold]

    static let ids: Set<String> = Set(all.map(\.id))

    static func theme(id: String) -> KeyboardThemeDefinition? {
        all.first { $0.id == id }
    }
}

extension KeyboardThemeDefinition {
    /// Whether this theme is compiled in. Derived from the id, never trusted
    /// from persisted data — built-ins are not editable or deletable.
    var isBuiltIn: Bool {
        BuiltInThemes.ids.contains(id)
    }

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
