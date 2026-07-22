//
//  HangulComposer.swift
//  Wurstfinger
//
//  Korean Hangul syllable composition automaton.
//
//  Korean is written in syllable blocks of a leading consonant (choseong),
//  a vowel (jungseong) and an optional trailing consonant (jongseong),
//  encoded as precomposed syllables in U+AC00…U+D7A3:
//
//      syllable = 0xAC00 + (L * 21 + V) * 28 + T
//
//  The keyboard emits individual compatibility jamo (U+3131…U+3163). This
//  composer folds each newly typed jamo into the syllable currently under the
//  cursor, driving a two-set (두벌식-style) automaton with single-character
//  lookback: it decomposes the previous character, applies the jamo, and
//  returns the recomposed replacement — which may be two syllables when a
//  trailing consonant "moves" onto a following vowel (한 + ㅏ → 하나).
//

import Foundation

/// Stateless Hangul syllable composition, driven by single-character lookback.
///
/// `combine(previous:jamo:)` returns the string that should replace
/// `previous + jamo`, or `nil` when the jamo cannot fold into `previous` and
/// should be committed on its own (starting a fresh syllable). It plugs into
/// `SequentialCompositionMiddleware` exactly like a table lookup — the
/// middleware deletes the single `previous` character and commits the
/// (possibly multi-character) result.
enum HangulComposer {
    // Compatibility-jamo tables in composition-index order.
    private static let choseong = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    private static let jungseong = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
    private static let jongseong = Array("\u{0}ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ")

    private static let syllableBase = 0xAC00
    private static let jungseongCount = 21
    private static let jongseongCount = 28

    // Vowel + vowel → compound vowel (e.g. ㅗ + ㅏ → ㅘ).
    private static let compoundVowel: [String: Character] = [
        "ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ",
        "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ",
        "ㅡㅣ": "ㅢ",
    ]

    // Final + consonant → compound final (e.g. ㄱ + ㅅ → ㄳ), plus its inverse
    // used when a compound final splits across a syllable boundary.
    private static let compoundFinal: [String: Character] = [
        "ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ", "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ",
        "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ", "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ",
        "ㅂㅅ": "ㅄ",
    ]
    private static let splitFinal: [Character: (Character, Character)] = {
        var out: [Character: (Character, Character)] = [:]
        for (pair, combined) in compoundFinal {
            let chars = Array(pair)
            out[combined] = (chars[0], chars[1])
        }
        return out
    }()

    // Same-consonant doubling → tense (쌍) consonant, typed by repeating the
    // base jamo (ㄱㄱ→ㄲ …). Standalone form, used when two lone consonants are
    // typed with no syllable to attach to.
    private static let tenseDouble: [Character: Character] = [
        "ㄱ": "ㄲ", "ㄷ": "ㄸ", "ㅂ": "ㅃ", "ㅅ": "ㅆ", "ㅈ": "ㅉ",
    ]

    // Tense finals reachable by repeating a trailing consonant. Only ㄲ and ㅆ
    // are valid 받침 (batchim); ㄸ/ㅃ/ㅉ never occur as finals, so they are
    // absent here. Deliberately kept out of `compoundFinal` so `splitFinal`
    // still moves ㄲ/ㅆ onto a following vowel as a whole unit (밖 + ㅏ → 바까,
    // not 박가).
    //
    // Known tradeoff: with only single-character lookback and no tense-jamo
    // key, doubling is the *only* way to type a ㄲ/ㅆ batchim (있다, 갔다, 밖,
    // 깎 — past-tense verbs make ㅆ batchim extremely common). The cost is that
    // a ㄱ-final syllable immediately followed by a ㄱ-initial one is tensed
    // instead of starting a new syllable, so 학교 (ㅎㅏㄱㄱㅛ) folds to 하꾜, and
    // likewise 축구/국가/식구. Making 있다 typeable outweighs the collision, so
    // the behavior is kept and pinned by `tenseFinalCollisionIsKnownLimitation`.
    private static let tenseFinal: [String: Character] = [
        "ㄱㄱ": "ㄲ", "ㅅㅅ": "ㅆ",
    ]

    // MARK: - Classification

    private static func choseongIndex(_ c: Character) -> Int? {
        choseong.firstIndex(of: c)
    }

    private static func jungseongIndex(_ c: Character) -> Int? {
        jungseong.firstIndex(of: c)
    }

    /// Trailing-consonant index (1…27); nil if the character is not a valid final.
    private static func jongseongIndex(_ c: Character) -> Int? {
        let i = jongseong.firstIndex(of: c)
        return (i == 0) ? nil : i
    }

    private static func isConsonant(_ c: Character) -> Bool {
        choseongIndex(c) != nil
    }

    private static func isVowel(_ c: Character) -> Bool {
        jungseongIndex(c) != nil
    }

    // MARK: - Compose / decompose

    /// Builds a precomposed syllable from a leading consonant, vowel and
    /// optional trailing consonant. Returns nil if any part is out of set.
    private static func compose(_ lead: Character, _ vowel: Character, _ tail: Character?) -> String? {
        guard let li = choseongIndex(lead), let vi = jungseongIndex(vowel) else { return nil }
        let ti = tail.flatMap(jongseongIndex) ?? 0
        let scalar = syllableBase + (li * jungseongCount + vi) * jongseongCount + ti
        return UnicodeScalar(scalar).map { String($0) }
    }

    private static func decompose(_ syllable: Character) -> (Character, Character, Character?)? {
        guard let scalar = syllable.unicodeScalars.first?.value,
              (0xAC00 ... 0xD7A3).contains(scalar) else { return nil }
        let index = Int(scalar) - syllableBase
        let ti = index % jongseongCount
        let vi = (index / jongseongCount) % jungseongCount
        let li = index / (jungseongCount * jongseongCount)
        return (choseong[li], jungseong[vi], ti == 0 ? nil : jongseong[ti])
    }

    // MARK: - Combine

    /// Folds `jamo` into `previous`. See the type doc for the contract.
    static func combine(previous: String, jamo: String) -> String? {
        guard previous.count == 1, jamo.count == 1,
              let prev = previous.first, let j = jamo.first,
              isConsonant(j) || isVowel(j)
        else { return nil }

        if let (lead, vowel, tail) = decompose(prev) {
            return foldIntoSyllable(lead: lead, vowel: vowel, tail: tail, jamo: j)
        }
        return foldIntoLoneJamo(prev: prev, jamo: j)
    }

    private static func foldIntoSyllable(
        lead: Character, vowel: Character, tail: Character?, jamo j: Character
    ) -> String? {
        if isVowel(j) {
            guard let tail else {
                // No final yet: extend the vowel into a compound if possible.
                if let cv = compoundVowel[String(vowel) + String(j)] {
                    return compose(lead, cv, nil)
                }
                return nil // A fresh vowel starts a new (standalone) syllable.
            }
            // A final followed by a vowel moves onto the new syllable.
            if let (keep, move) = splitFinal[tail] {
                guard let first = compose(lead, vowel, keep),
                      let second = compose(move, j, nil) else { return nil }
                return first + second
            }
            guard let first = compose(lead, vowel, nil),
                  let second = compose(tail, j, nil) else { return nil }
            return first + second
        }

        // Consonant.
        guard let tail else {
            // Attach as the trailing consonant when it is a valid final.
            return jongseongIndex(j) != nil ? compose(lead, vowel, j) : nil
        }
        // Grow the final into a compound if this consonant allows it.
        if let cf = compoundFinal[String(tail) + String(j)] {
            return compose(lead, vowel, cf)
        }
        // A repeated trailing consonant tenses the final (ㄱㄱ→ㄲ, ㅅㅅ→ㅆ).
        if let tf = tenseFinal[String(tail) + String(j)] {
            return compose(lead, vowel, tf)
        }
        return nil // Otherwise the consonant begins a new syllable.
    }

    private static func foldIntoLoneJamo(prev: Character, jamo j: Character) -> String? {
        if prev == j, let tense = tenseDouble[prev] {
            return String(tense) // Repeated consonant → standalone tense jamo.
        }
        if isConsonant(prev), isVowel(j) {
            return compose(prev, j, nil) // Leading consonant + vowel → syllable.
        }
        if isVowel(prev), isVowel(j), let cv = compoundVowel[String(prev) + String(j)] {
            return String(cv) // Two vowels → standalone compound vowel.
        }
        return nil
    }
}
