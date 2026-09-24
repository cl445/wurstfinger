//
//  KeyCategory.swift
//  Wurstfinger
//
//  Semantic classification of key bindings.
//

import Foundation

/// Categorizes a binding for context-dependent behavior.
enum KeyCategory: String, Codable {
    case letter // Letter — reacts to shift, triggers auto-capitalization
    case digit // Digit
    case symbol // Punctuation, special character
    case compose // Accent/compose trigger
    case modifier // Shift, symbols toggle, caps lock
    case utility // Globe, delete, return
    case whitespace // Space, newline
    case emoji // Direct emoji key — label always visible, no auto-shift
}

extension KeyAction {
    /// Derives the category automatically from the action.
    /// Sufficient for ~90% of cases. Explicit category only needed for edge cases
    /// (e.g. commitText("ß") should be .letter, not .symbol).
    var inferredCategory: KeyCategory {
        switch self {
        case let .commitText(text):
            guard let char = text.first else { return .symbol }
            if char.isLetter { return .letter }
            if char.isNumber { return .digit }
            return .symbol
        case .compose: return .compose
        case .cycleAccents: return .compose
        case .switchMode: return .modifier
        case .capitalizeWord: return .modifier
        case .space, .newline: return .whitespace
        case .deleteBackward, .deleteForward, .moveCursor,
             .advanceToNextInputMode, .dismissKeyboard, .switchToNextLanguage:
            return .utility
        case .copy, .paste, .cut, .cutAll: return .utility
        case .none: return .utility
        }
    }
}
