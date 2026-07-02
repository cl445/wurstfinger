//
//  LabelCategory.swift
//  Wurstfinger
//
//  Display classification of a key label, used to hide categories of labels so
//  the layout can be practiced from memory. This is a *visual* classification
//  (by character content), distinct from `KeyCategory`, which describes a
//  binding's *behaviour* (auto-shift, haptics, hint styling).
//

import Foundation

/// Classifies a key label for visibility toggling. Letters, standard symbols,
/// and extra symbols can each be hidden independently; numbers and functional
/// labels are always visible.
enum LabelCategory {
    /// Alphabetic characters (a–z, ä, ö, ß, …).
    case letter
    /// Common everyday punctuation (`. , ! ? - + / = ( ) @ * " ' : ; & ° € %`).
    case standardSymbol
    /// Technical/rare symbols (`$ ^ ~ \ { } [ ] | _ < > #`, accents, …).
    case extraSymbol
    /// Digits (0–9) — never hidden.
    case number
    /// Control keys (shift, symbols toggle, capitalize, …) — never hidden.
    case functional

    /// Whether this category participates in user-controlled visibility toggling.
    var isHideable: Bool {
        switch self {
        case .letter, .standardSymbol, .extraSymbol: true
        case .number, .functional: false
        }
    }
}

extension LabelCategory {
    /// Characters classified as "standard" everyday punctuation. Everything else
    /// that is not a letter or digit is treated as `.extraSymbol`.
    private static let standardSymbolCharacters: Set<Character> = [
        ".", ",", "!", "?", "-", "+", "/", "=",
        "(", ")", "@", "*", "\"", "'", ":", ";",
        "&", "°", "€", "%",
    ]

    /// Classifies a plain text label by its first character. Letters and digits
    /// are recognised via Unicode properties; symbols fall back to an explicit
    /// standard set.
    static func classify(_ text: String) -> LabelCategory {
        guard let first = text.first else { return .extraSymbol }
        if first.isLetter { return .letter }
        if first.isNumber { return .number }
        if standardSymbolCharacters.contains(first) { return .standardSymbol }
        return .extraSymbol
    }

    /// Display category for a binding. The binding's semantic `KeyCategory`
    /// identifies the never-hidden buckets (modifiers, utility, whitespace,
    /// digits); letters, symbols, and compose triggers are then classified by
    /// their label text so the standard/extra split applies.
    static func of(_ binding: KeyBinding) -> LabelCategory {
        switch binding.resolvedCategory {
        case .letter: .letter
        case .digit: .number
        case .modifier, .utility, .whitespace: .functional
        case .compose:
            // The accent-cycle key (🅒) is a control and stays visible; compose
            // *triggers* (´ ¨ ~ ° …) read as symbols and hide with the symbol
            // toggles.
            if case .cycleAccents = binding.action {
                .functional
            } else {
                classify(binding.label)
            }
        case .symbol: classify(binding.label)
        }
    }

    /// Whether a label of this category should be shown given the user's
    /// hide toggles. Numbers and functional labels are always visible.
    func isVisible(hideLetters: Bool, hideStandardSymbols: Bool, hideExtraSymbols: Bool) -> Bool {
        switch self {
        case .letter: !hideLetters
        case .standardSymbol: !hideStandardSymbols
        case .extraSymbol: !hideExtraSymbols
        case .number, .functional: true
        }
    }
}
