//
//  KeyboardDefinition.swift
//  Wurstfinger
//
//  Complete definition of a keyboard with all modes and settings.
//

import Foundation

/// Complete definition of a keyboard with all modes and settings.
struct KeyboardDefinition: Codable, Equatable {
    /// Display name (e.g. "Deutsch MessagEase")
    let title: String

    /// Unique ID (e.g. "de_messagease")
    let id: String

    /// Locale identifier as String for Codable (e.g. "de_DE")
    let localeIdentifier: String

    /// Computed: Locale for uppercase logic, auto-capitalization, etc.
    var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    /// All available modes, accessible by name.
    /// Arbitrarily many modes possible: "main", "shifted", "numeric", "emoji", ...
    let modes: [String: KeyboardMode]

    /// Which mode is active at start (normally "main")
    let defaultMode: String

    /// Keyboard-specific settings
    let settings: KeyboardDefinitionSettings

    /// Convenience: Mode lookup
    func mode(_ name: String) -> KeyboardMode? {
        modes[name]
    }
}

/// Well-known mode names as constants (extensible without code change)
enum ModeNames {
    static let main = "main"
    static let shifted = "shifted"
    static let capsLock = "capsLock"
    static let numeric = "numeric"
    static let symbols = "symbols"
    static let emoji = "emoji"
}

/// Keyboard-specific settings for a KeyboardDefinition.
struct KeyboardDefinitionSettings: Codable, Equatable {
    /// Auto-capitalization enabled
    let autoCapitalize: Bool

    /// Language-specific auto-capitalizer rules (e.g. "i" → "I" in English)
    let autoCapitalizers: [AutoCapitalizerRule]

    /// Language-specific compose rule overrides.
    /// Merged with global base rules at runtime.
    /// nil = only use global rules (sufficient for most languages).
    let composeRuleOverrides: ComposeRuleSet?
}

/// A complete set of compose rules, loadable from JSON.
struct ComposeRuleSet: Codable, Equatable {
    /// trigger → (baseChar → result)
    /// e.g. "¨" → ["a": "ä", "o": "ö", ...]
    let rules: [String: [String: String]]
}

/// A rule for automatic capitalization.
struct AutoCapitalizerRule: Codable, Equatable {
    /// Pattern recognized in text before cursor
    let pattern: String

    /// Replacement
    let replacement: String
}
