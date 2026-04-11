//
//  LabelCategory.swift
//  Wurstfinger
//
//  Classification of key outputs for label visibility toggling.
//

import Foundation

/// Classifies a key label for visibility toggling.
/// Letters, standard symbols, and extra symbols can each be independently hidden.
/// Numbers and functional labels are always visible.
enum LabelCategory {
    /// Alphabetic characters (a-z, ä, ö, ß, etc.)
    case letter
    /// Common everyday punctuation (. , ! ? - + / = ( ) @ * " ' : ; & ° € %)
    case standardSymbol
    /// Technical/rare symbols ($ ^ ~ ` ´ \ { } [ ] | _ < > # tab ∫ ∏ ∑ …)
    case extraSymbol
    /// Digits (0-9, superscripts) — never hidden
    case number
    /// Control keys (Shift, Symbols toggle, capitalizeWord, etc.) — never hidden
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
    /// Characters classified as "standard" everyday punctuation.
    /// Everything not in this set and not a letter/digit is treated as .extraSymbol.
    private static let standardSymbolCharacters: Set<Character> = [
        ".", ",", "!", "?", "-", "+", "/", "=",
        "(", ")", "@", "*", "\"", "'", ":", ";",
        "&", "°", "€", "%"
    ]

    /// Classifies a plain text label by its first character.
    /// Letters and digits are recognized via Unicode properties;
    /// symbols fall back to an explicit standard set.
    static func classify(_ text: String) -> LabelCategory {
        guard let first = text.first else { return .extraSymbol }
        if first.isLetter { return .letter }
        if first.isNumber { return .number }
        if standardSymbolCharacters.contains(first) { return .standardSymbol }
        return .extraSymbol
    }
}

extension MessagEaseOutput {
    /// The display category for this output, used to decide label visibility.
    var labelCategory: LabelCategory {
        switch self {
        case let .text(value):
            LabelCategory.classify(value)
        case .compose:
            // Accent/compose triggers (^, ~, `, ´, ¨, ˘, etc.) are always extra.
            .extraSymbol
        case .toggleShift, .toggleSymbols, .capitalizeWord, .cycleAccents:
            .functional
        }
    }
}
