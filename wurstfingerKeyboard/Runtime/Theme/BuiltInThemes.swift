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
        boardBackground: .color(.semantic(.systemBackground, opacity: 0.02)),
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

    /// Fixed dark-slate/gold palette. Identical in light and dark mode by
    /// design. Hint roles carry their prominence as alpha (0.9/0.7/0.5/0.45
    /// of white), mirroring Classic's opacity hierarchy.
    static let darkGold = KeyboardThemeDefinition(
        id: "dark-gold",
        name: "Dark Gold",
        boardBackground: .color(.fixed(hex: "#252A34")),
        keyFill: .color(.fixed(hex: "#333A48")),
        keyFillActive: .color(.fixed(hex: "#4A5468")),
        keyBorder: .fixed(hex: "#FFFFFF1F"),
        keyBorderWidth: 0.5,
        cornerRadius: Double(KeyboardConstants.KeyDimensions.cornerRadius),
        mainLabel: .fixed(hex: "#D1AA05"),
        utilityLabel: .fixed(hex: "#FFFFFF"),
        hintLetter: .fixed(hex: "#FFFFFFE6"),
        hintSymbol: .fixed(hex: "#FFFFFFB3"),
        hintIconProminent: .fixed(hex: "#FFFFFF80"),
        hintIconSubtle: .fixed(hex: "#FFFFFF73")
    )

    static let all: [KeyboardThemeDefinition] = [classic, liquidGlass, darkGold]

    static let ids: Set<String> = Set(all.map(\.id))

    static func theme(id: String) -> KeyboardThemeDefinition? {
        all.first { $0.id == id }
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
