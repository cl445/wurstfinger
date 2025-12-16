//
//  AutoCapitalization.swift
//  wurstfingerKeyboard
//
//  Helper for auto-capitalization logic after sentence-ending punctuation.
//

import Foundation

enum AutoCapitalization {
    /// Punctuation that ends a sentence and triggers capitalization after space/newline.
    static let sentenceEnders: Set<Character> = [
        ".", "!", "?",      // Standard Western punctuation
        "…",                // Ellipsis
        "。", "！", "？",    // CJK punctuation
    ]

    /// Punctuation that opens a sentence and triggers immediate capitalization.
    static let sentenceOpeners: Set<Character> = [
        "¿", "¡",           // Spanish inverted punctuation
    ]

    /// Determines if the next character should be capitalized based on context.
    /// Returns true at the start of text or after sentence-ending punctuation followed by whitespace.
    static func shouldCapitalize(context: String?) -> Bool {
        // At start of text field
        guard let context = context else { return true }
        if context.isEmpty { return true }

        // Only whitespace means start of input
        let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }

        // Check if last non-whitespace character is a sentence ender
        guard let lastChar = trimmed.last else { return false }
        return sentenceEnders.contains(lastChar)
    }

    /// Determines if the next character should be capitalized immediately (without space).
    /// This is used for Spanish inverted punctuation (¿ and ¡).
    static func shouldCapitalizeImmediately(after character: String) -> Bool {
        // Only check single characters
        guard let char = character.first, character.count == 1 else { return false }
        return sentenceOpeners.contains(char)
    }
}
