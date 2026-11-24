//
//  TelexSyllable.swift
//  Wurstfinger
//

import Foundation

/// The vowel group before the cursor, its optional final consonants, and one
/// tone. Rebuilt from visible text on each key, so a cursor move or backspace
/// cannot leave a pending tone attached to the wrong word.
private struct TelexSyllable {
    private static let onsets: Set<String> = [
        "", "b", "c", "ch", "d", "đ", "g", "gh", "h", "k", "kh", "l", "m", "n", "ng", "ngh", "nh",
        "p", "ph", "q", "r", "s", "t", "th", "tr", "v", "x",
    ]
    private static let codas: Set<String> = ["", "c", "ch", "m", "n", "ng", "nh", "p", "t"]
    private static let shapedVowels: Set<String> = ["ă", "â", "ê", "ô", "ơ", "ư"]

    let onset: String
    var vowels: [String]
    var coda: String
    var tone: String?

    init?(_ word: [String]) {
        let bases = word.map { ComposeEngine.telexToneReverseMap[$0]?.base ?? $0 }
        func isVowel(_ letter: String) -> Bool {
            ComposeEngine.vietnameseBaseVowels.contains(letter.lowercased())
        }
        guard let first = bases.firstIndex(where: isVowel) else { return nil }
        let group = bases[first...].prefix(while: isVowel)
        onset = bases[..<first].joined().lowercased()
        vowels = Array(group)
        coda = bases[group.endIndex...].joined()
        let tones = word[group.indices].compactMap { ComposeEngine.telexToneReverseMap[$0]?.trigger }
        guard Self.onsets.contains(onset), Self.codas.contains(coda.lowercased()), tones.count <= 1 else { return nil }
        tone = tones.first
    }

    /// In `quá` and `già`, u/i belong to the initial consonant. The i in `gìn`
    /// is different: without another vowel it carries the tone itself.
    private var nucleus: ArraySlice<String> {
        let initial = onset + vowels[0].lowercased()
        return vowels.dropFirst(vowels.count > 1 && (initial == "qu" || initial == "gi") ? 1 : 0)
    }

    private var toneIndex: Int? {
        let group = nucleus
        guard (1 ... 3).contains(group.count) else { return nil }
        if let shaped = group.lastIndex(where: { Self.shapedVowels.contains($0.lowercased()) }) { return shaped }
        // Traditional open oa/oe/uy (hòa, khỏe, thủy); a coda moves the tone
        // onto the second vowel (hoàn). Three-vowel groups use the middle.
        return group.startIndex + (group.count == 3 || (group.count == 2 && !coda.isEmpty) ? 1 : 0)
    }

    /// Returns the new vowel group + coda (not the unchanged onset).
    mutating func typing(_ key: String) -> String? {
        let lower = key.lowercased()
        var literal = ""
        if ComposeEngine.telexToneMap[lower] != nil {
            if tone == lower { literal = key }
            tone = literal.isEmpty ? lower : nil
        } else if lower == "z" {
            guard tone != nil else { return nil }
            tone = nil
        } else {
            guard coda.isEmpty else { return nil }
            if let escaped = applyShape(key) {
                literal = escaped
            } else if tone != nil, ComposeEngine.vietnameseBaseVowels.contains(lower) {
                vowels.append(key)
            } else if tone != nil, Self.codas.contains(lower) {
                coda = key
            } else {
                return nil
            }
        }

        guard let index = toneIndex else { return nil }
        if let tone, let toned = ComposeEngine.composeTelex(previous: vowels[index], trigger: tone) { vowels[index] = toned }
        return vowels.joined() + coda + literal
    }

    /// Work on untoned vowels so `asw` and `aws` both produce `ắ`. On undo,
    /// keep the literal key separate: it belongs after any restored tone.
    private mutating func applyShape(_ key: String) -> String? {
        let end = vowels.count - 1
        if nucleus.count >= 2, let (pair, _) = ComposeEngine.composeTelexDigraph(
            prev2: vowels[end - 1], prev1: vowels[end], trigger: key
        ) {
            vowels.replaceSubrange((end - 1) ... end, with: pair.map(String.init))
            return ""
        }
        guard let result = ComposeEngine.composeTelex(previous: vowels[end], trigger: key), let first = result.first else { return nil }
        vowels[end] = String(first)
        return String(result.dropFirst())
    }
}

extension ComposeEngine {
    /// Return only the suffix that actually changed. A Vietnamese syllable has
    /// at most three onset letters, three vowels and two final consonants. Read
    /// one extra grapheme to reject longer tokens instead of rewriting a tail.
    static func composeTelexSyllable(context: String, trigger: String) -> (String, Int)? {
        let word = context.suffix(9).reversed().prefix(while: \.isLetter).reversed().map(String.init)
        guard word.count <= 8, var syllable = TelexSyllable(word) else { return nil }
        let original = word.dropFirst(syllable.onset.count)
        guard let replacement = syllable.typing(trigger) else { return nil }
        let common = zip(original, replacement).prefix { $0 == String($1) }.count
        // An ordinary appended key with no tone to move is already handled by
        // the text input target. Do not generate spurious delete/insert events.
        guard common < original.count else { return nil }
        return (String(replacement.dropFirst(common)), original.count - common)
    }
}
