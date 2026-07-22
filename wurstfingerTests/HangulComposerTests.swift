//
//  HangulComposerTests.swift
//  wurstfingerTests
//
//  Unit tests for the Korean Hangul syllable composition automaton.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct HangulComposerTests {
    // MARK: - Basic composition

    @Test func leadPlusVowelFormsSyllable() {
        #expect(HangulComposer.combine(previous: "ㅎ", jamo: "ㅏ") == "하")
        #expect(HangulComposer.combine(previous: "ㄱ", jamo: "ㅏ") == "가")
    }

    @Test func vowelAddsFinalConsonant() {
        // 하 (LV) + ㄴ → 한 (LVT)
        #expect(HangulComposer.combine(previous: "하", jamo: "ㄴ") == "한")
    }

    // MARK: - Final consonant migration

    @Test func finalMovesOntoFollowingVowel() {
        // 한 (ㅎㅏㄴ) + ㅏ → 하 + 나
        #expect(HangulComposer.combine(previous: "한", jamo: "ㅏ") == "하나")
    }

    @Test func compoundFinalSplitsWhenVowelFollows() {
        // 갃 (ㄱㅏㄳ) + ㅏ → 각 + 사
        #expect(HangulComposer.combine(previous: "갃", jamo: "ㅏ") == "각사")
    }

    // MARK: - Compound jamo

    @Test func compoundVowelFromSyllable() {
        // 고 (ㄱㅗ) + ㅏ → 과 (ㄱㅘ)
        #expect(HangulComposer.combine(previous: "고", jamo: "ㅏ") == "과")
    }

    @Test func compoundVowelFromLoneVowel() {
        #expect(HangulComposer.combine(previous: "ㅗ", jamo: "ㅏ") == "ㅘ")
        #expect(HangulComposer.combine(previous: "ㅡ", jamo: "ㅣ") == "ㅢ")
    }

    @Test func compoundFinalGrowsFromSyllable() {
        // 각 (ㄱㅏㄱ) + ㅅ → 갃 (ㄱㅏㄳ)
        #expect(HangulComposer.combine(previous: "각", jamo: "ㅅ") == "갃")
    }

    // MARK: - Non-composition (returns nil → jamo commits on its own)

    @Test func consonantAfterCompleteSyllableStartsFresh() {
        // 한 already has a final; a new consonant does not merge.
        #expect(HangulComposer.combine(previous: "한", jamo: "ㄱ") == nil)
    }

    @Test func twoLeadingConsonantsDoNotMerge() {
        #expect(HangulComposer.combine(previous: "ㄱ", jamo: "ㄴ") == nil)
    }

    // MARK: - Tense (쌍) consonants via same-consonant doubling

    @Test func tenseConsonantsFromDoubling() {
        // Repeating a base consonant produces its tense (doubled) form.
        #expect(HangulComposer.combine(previous: "ㄱ", jamo: "ㄱ") == "ㄲ")
        #expect(HangulComposer.combine(previous: "ㄷ", jamo: "ㄷ") == "ㄸ")
        #expect(HangulComposer.combine(previous: "ㅂ", jamo: "ㅂ") == "ㅃ")
        #expect(HangulComposer.combine(previous: "ㅅ", jamo: "ㅅ") == "ㅆ")
        #expect(HangulComposer.combine(previous: "ㅈ", jamo: "ㅈ") == "ㅉ")
        // Different consonants must still not merge.
        #expect(HangulComposer.combine(previous: "ㄱ", jamo: "ㄴ") == nil)
    }

    @Test func tenseFinalGrowsFromRepeatedTrailingConsonant() {
        // 갔 (ㄱㅏㅆ): the ㅆ batchim forms from a repeated ㅅ.
        #expect(HangulComposer.combine(previous: "갓", jamo: "ㅅ") == "갔")
        // Only ㄲ/ㅆ are valid tense finals; ㄷㄷ etc. never grow a batchim.
        #expect(HangulComposer.combine(previous: "닫", jamo: "ㄷ") == nil)
    }

    @Test func typesHangulWordWithTenseJamo() {
        // 있다: ㅇ ㅣ ㅅ ㅅ ㄷ ㅏ (tense final ㅆ).
        #expect(type(["ㅇ", "ㅣ", "ㅅ", "ㅅ", "ㄷ", "ㅏ"]) == "있다")
        // 깎: ㄱ ㄱ ㅏ ㄱ ㄱ (tense lead ㄲ and tense final ㄲ).
        #expect(type(["ㄱ", "ㄱ", "ㅏ", "ㄱ", "ㄱ"]) == "깎")
    }

    @Test func tenseFinalCollisionIsKnownLimitation() {
        // Documented tradeoff (see `tenseFinal`): a ㄱ-final syllable directly
        // followed by a ㄱ-initial one is tensed to a ㄲ batchim rather than
        // starting a new syllable, because single-character lookback cannot
        // tell 밖 (real ㄲ batchim) apart from 학+ㄱ. So 학교 (ㅎㅏㄱㄱㅛ) folds to
        // 하꾜. This is the price of making ㄲ/ㅆ batchim (있다, 밖) typeable at
        // all; the test pins it so the collision is not mistaken for a new bug.
        #expect(type(["ㅎ", "ㅏ", "ㄱ", "ㄱ", "ㅛ"]) == "하꾜")
    }

    @Test func nonHangulPreviousIsIgnored() {
        #expect(HangulComposer.combine(previous: "a", jamo: "ㄱ") == nil)
        #expect(HangulComposer.combine(previous: " ", jamo: "ㅏ") == nil)
    }

    @Test func nonJamoTriggerIsIgnored() {
        #expect(HangulComposer.combine(previous: "하", jamo: "1") == nil)
    }

    // MARK: - Word-level integration

    /// Simulates CombineMiddleware over a jamo stream: each step either folds
    /// into the last character (delete it, append the result) or, on nil,
    /// appends the jamo verbatim — exactly what the middleware does.
    private func type(_ jamos: [String]) -> String {
        var doc = ""
        for jamo in jamos {
            if let last = doc.last,
               let combined = HangulComposer.combine(previous: String(last), jamo: jamo) {
                doc.removeLast()
                doc += combined
            } else {
                doc += jamo
            }
        }
        return doc
    }

    @Test func typesHangulWord() {
        // 한글: ㅎ ㅏ ㄴ ㄱ ㅡ ㄹ
        #expect(type(["ㅎ", "ㅏ", "ㄴ", "ㄱ", "ㅡ", "ㄹ"]) == "한글")
        // 안녕: ㅇ ㅏ ㄴ ㄴ ㅕ ㅇ
        #expect(type(["ㅇ", "ㅏ", "ㄴ", "ㄴ", "ㅕ", "ㅇ"]) == "안녕")
        // 과자: ㄱ ㅗ ㅏ ㅈ ㅏ
        #expect(type(["ㄱ", "ㅗ", "ㅏ", "ㅈ", "ㅏ"]) == "과자")
    }
}
