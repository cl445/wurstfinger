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

    /// Label for the numeric layer's "back to alphabet" key (e.g. "abc",
    /// "אבג", "абв"). Retained on the definition so the numeric mode can be
    /// rebuilt at load time (e.g. when switching the numpad style) without
    /// re-deriving the per-language label.
    let numericBackToAlphaLabel: String

    init(
        title: String,
        id: String,
        localeIdentifier: String,
        modes: [String: KeyboardMode],
        defaultMode: String,
        settings: KeyboardDefinitionSettings,
        numericBackToAlphaLabel: String = NumericLayouts.defaultBackToAlphaLabel
    ) {
        self.title = title
        self.id = id
        self.localeIdentifier = localeIdentifier
        self.modes = modes
        self.defaultMode = defaultMode
        self.settings = settings
        self.numericBackToAlphaLabel = numericBackToAlphaLabel
    }

    /// Convenience: Mode lookup
    func mode(_ name: String) -> KeyboardMode? {
        modes[name]
    }

    /// Returns a copy with `name`'s mode replaced. Used to swap the numeric
    /// layer (phone/classic) at load time based on user settings.
    func replacingMode(_ name: String, with mode: KeyboardMode) -> KeyboardDefinition {
        var updated = modes
        updated[name] = mode
        return KeyboardDefinition(
            title: title, id: id, localeIdentifier: localeIdentifier,
            modes: updated, defaultMode: defaultMode, settings: settings,
            numericBackToAlphaLabel: numericBackToAlphaLabel
        )
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

/// Identifies which text input method is applied to committed characters.
///
/// Most languages commit characters directly. A few need a stateful
/// transformation over recent document context — Vietnamese Telex being
/// the first real example. Making this a data-driven enum on the keyboard
/// definition keeps language activation out of view-controller locale checks.
enum InputMethodKind: String, Codable, Equatable {
    /// Characters are committed verbatim. Default.
    case direct

    /// Vietnamese Telex: single-char and digraph lookback composition
    /// handled by `TelexMiddleware`.
    case telex
}

/// Keyboard-specific settings for a KeyboardDefinition.
struct KeyboardDefinitionSettings: Codable, Equatable {
    /// Auto-capitalization enabled
    let autoCapitalize: Bool

    /// Language-specific compose rule overrides.
    /// Merged with global base rules at runtime.
    /// nil = only use global rules (sufficient for most languages).
    let composeRuleOverrides: ComposeRuleSet?

    /// Which input method to apply to committed characters. Defaults to
    /// `.direct`; set to `.telex` for Vietnamese Telex composition.
    let inputMethod: InputMethodKind

    init(
        autoCapitalize: Bool,
        composeRuleOverrides: ComposeRuleSet?,
        inputMethod: InputMethodKind = .direct
    ) {
        self.autoCapitalize = autoCapitalize
        self.composeRuleOverrides = composeRuleOverrides
        self.inputMethod = inputMethod
    }
}
