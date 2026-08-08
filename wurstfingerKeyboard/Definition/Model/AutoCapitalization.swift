//
//  AutoCapitalization.swift
//  wurstfingerKeyboard
//
//  Sentence punctuation: what ends a sentence (auto-capitalization) and what
//  a keyboard inserts to end one (the double-space shortcut).
//

import Foundation

enum AutoCapitalization {
    /// Punctuation that ends a sentence and triggers capitalization after space/newline.
    static let sentenceEnders: Set<Character> = [
        ".", "!", "?", // Standard Western punctuation
        "…", // Ellipsis
        "。", "！", "？", // CJK punctuation
        "।", // Devanagari danda
        "۔", // Arabic full stop (Urdu)
    ]

    /// CJK sentence-ending punctuation. CJK text has no inter-sentence spaces,
    /// so these trigger capitalization even without trailing whitespace.
    static let cjkSentenceEnders: Set<Character> = [
        "。", "！", "？",
    ]

    /// Punctuation that opens a sentence and triggers immediate capitalization.
    static let sentenceOpeners: Set<Character> = [
        "¿", "¡", // Spanish inverted punctuation
    ]

    /// Sentence terminator for the scripts that write the Western full stop.
    static let defaultSentenceTerminator = ". "

    /// Sentence terminators that differ from `defaultSentenceTerminator`, keyed
    /// by language code. Each carries the trailing space its script writes
    /// after the mark — the full-width CJK stop takes none.
    ///
    /// Keyed by language rather than script on purpose: Arabic, Persian and
    /// Urdu all write the Arabic script, but only Urdu ends a sentence with
    /// `"۔"`; the other two use the Western full stop and fall through to the
    /// default.
    static let sentenceTerminators: [String: String] = [
        "hi": "। ", // Devanagari danda
        "ja": "。", // Ideographic full stop, written without a following space
        "ur": "۔ ", // Arabic full stop
    ]

    /// The text a keyboard for `locale` inserts to end a sentence: the mark
    /// plus the trailing space its script writes after it.
    static func sentenceTerminator(for locale: Locale) -> String {
        guard let language = locale.language.languageCode?.identifier else {
            return defaultSentenceTerminator
        }
        return sentenceTerminators[language] ?? defaultSentenceTerminator
    }

    /// Determines if the next character should be capitalized based on context.
    /// Returns true at the start of text or after sentence-ending punctuation followed by whitespace.
    static func shouldCapitalize(context: String?) -> Bool {
        // At start of text field
        guard let context else { return true }
        if context.isEmpty { return true }

        // Only whitespace means start of input
        if context.allSatisfy(\.isWhitespace) { return true }

        guard let lastChar = context.last else { return false }

        if lastChar.isWhitespace {
            // A Western ender only triggers when actually followed by whitespace,
            // so "e.g" does not capitalize the "g" (the ender has no trailing
            // space) while "Hello. " does.
            guard let lastNonWhitespace = context.reversed().first(where: { !$0.isWhitespace })
            else { return true }
            return sentenceEnders.contains(lastNonWhitespace)
        }

        // No trailing whitespace: only CJK enders (which need no space) trigger.
        return cjkSentenceEnders.contains(lastChar)
    }

    /// Determines if the next character should be capitalized immediately (without space).
    /// This is used for Spanish inverted punctuation (¿ and ¡).
    static func shouldCapitalizeImmediately(after character: String) -> Bool {
        // Only check single characters
        guard let char = character.first, character.count == 1 else { return false }
        return sentenceOpeners.contains(char)
    }
}
