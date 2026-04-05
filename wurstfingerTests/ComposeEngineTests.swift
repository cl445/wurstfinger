//
//  ComposeEngineTests.swift
//  WurstfingerTests
//
//  Tests for ComposeEngine composition and accent cycling.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct ComposeEngineTests {
    // MARK: - Compose Triggers (one test per trigger character)

    @Test func dieresisCompose() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "¨") == "ä")
        #expect(ComposeEngine.compose(previous: "A", trigger: "¨") == "Ä")
        #expect(ComposeEngine.compose(previous: "o", trigger: "¨") == "ö")
        #expect(ComposeEngine.compose(previous: "u", trigger: "¨") == "ü")
    }

    @Test func acuteCompose() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "´") == "á")
        #expect(ComposeEngine.compose(previous: "e", trigger: "´") == "é")
        #expect(ComposeEngine.compose(previous: "n", trigger: "´") == "ń")
    }

    @Test func graveCompose() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "ˋ") == "à")
        #expect(ComposeEngine.compose(previous: "e", trigger: "ˋ") == "è")
        #expect(ComposeEngine.compose(previous: "u", trigger: "ˋ") == "ù")
    }

    @Test func circumflexCompose() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "^") == "â")
        #expect(ComposeEngine.compose(previous: "e", trigger: "^") == "ê")
        #expect(ComposeEngine.compose(previous: "o", trigger: "^") == "ô")
    }

    @Test func tildeCompose() {
        #expect(ComposeEngine.compose(previous: "n", trigger: "~") == "ñ")
        #expect(ComposeEngine.compose(previous: "a", trigger: "~") == "ã")
        #expect(ComposeEngine.compose(previous: "o", trigger: "~") == "õ")
    }

    @Test func degreeCompose() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "°") == "å")
        #expect(ComposeEngine.compose(previous: "o", trigger: "°") == "ø")
        #expect(ComposeEngine.compose(previous: "u", trigger: "°") == "ů")
    }

    @Test func breveCompose() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "˘") == "ă")
        #expect(ComposeEngine.compose(previous: "g", trigger: "˘") == "ğ")
    }

    @Test func currencyCompose() {
        #expect(ComposeEngine.compose(previous: "e", trigger: "$") == "€")
        #expect(ComposeEngine.compose(previous: "l", trigger: "$") == "£")
        #expect(ComposeEngine.compose(previous: "y", trigger: "$") == "¥")
    }

    @Test func dakutenCompose() {
        #expect(ComposeEngine.compose(previous: "か", trigger: "゛") == "が")
        #expect(ComposeEngine.compose(previous: "は", trigger: "゛") == "ば")
    }

    @Test func hookAboveCompose() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "?") == "ả")
        #expect(ComposeEngine.compose(previous: "o", trigger: "?") == "ỏ")
    }

    @Test func dotBelowCompose() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "*") == "ạ")
        #expect(ComposeEngine.compose(previous: "e", trigger: "*") == "ẹ")
    }

    @Test func caronCompose() {
        #expect(ComposeEngine.compose(previous: "c", trigger: "ˇ") == "č")
        #expect(ComposeEngine.compose(previous: "s", trigger: "ˇ") == "š")
        #expect(ComposeEngine.compose(previous: "z", trigger: "ˇ") == "ž")
    }

    @Test func exclamationMarkCompose() {
        #expect(ComposeEngine.compose(previous: "s", trigger: "!") == "ß")
        #expect(ComposeEngine.compose(previous: "a", trigger: "!") == "æ")
        #expect(ComposeEngine.compose(previous: "!", trigger: "!") == "¡")
    }

    // MARK: - Space Compose (trigger + space = trigger character)

    @Test func spaceComposeReturnsTriggerCharacter() {
        #expect(ComposeEngine.compose(previous: " ", trigger: "¨") == "¨")
        #expect(ComposeEngine.compose(previous: " ", trigger: "´") == "'")
        #expect(ComposeEngine.compose(previous: " ", trigger: "ˋ") == "`")
        #expect(ComposeEngine.compose(previous: " ", trigger: "^") == "^")
        #expect(ComposeEngine.compose(previous: " ", trigger: "~") == "~")
        #expect(ComposeEngine.compose(previous: " ", trigger: "°") == "°")
        #expect(ComposeEngine.compose(previous: " ", trigger: "˘") == "˘")
        #expect(ComposeEngine.compose(previous: " ", trigger: "$") == "$")
        #expect(ComposeEngine.compose(previous: " ", trigger: "?") == "?")
        #expect(ComposeEngine.compose(previous: " ", trigger: "*") == "*")
        #expect(ComposeEngine.compose(previous: " ", trigger: "ˇ") == "ˇ")
        #expect(ComposeEngine.compose(previous: " ", trigger: "!") == "!")
    }

    // MARK: - Unknown Character Returns nil

    @Test func unknownPreviousReturnsNil() {
        #expect(ComposeEngine.compose(previous: "z", trigger: "¨") == nil)
        #expect(ComposeEngine.compose(previous: "b", trigger: "°") == nil)
    }

    @Test func unknownTriggerReturnsNil() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "@") == nil)
        #expect(ComposeEngine.compose(previous: "e", trigger: "#") == nil)
    }

    // MARK: - Accent Cycling

    @Test func accentCycleForBaseCharacter() {
        // "a" should cycle to some accented variant
        let result = ComposeEngine.cycleAccent(for: "a")
        #expect(result != nil)
        #expect(result != "a") // Should not return the same character
    }

    @Test func accentCycleReturnsToBase() {
        // Use "h", which has a short accent cycle and should wrap back to base.
        // This verifies cycle completion behavior independent of exact variant count.
        var current = "h"
        var seen = Set<String>()
        seen.insert(current)

        for _ in 0 ..< 100 { // Safety limit
            guard let next = ComposeEngine.cycleAccent(for: current) else { break }
            if seen.contains(next) {
                // We've completed the cycle — should return to "h"
                #expect(next == "h", "Cycle should return to base character 'h', got '\(next)'")
                return
            }
            seen.insert(next)
            current = next
        }
        // If we get here, the cycle didn't complete (unexpected)
        #expect(Bool(false), "Accent cycle for 'h' did not complete")
    }

    @Test func accentCycleIsDeterministic() {
        // Two calls with the same input should return the same result
        let result1 = ComposeEngine.cycleAccent(for: "a")
        let result2 = ComposeEngine.cycleAccent(for: "a")
        #expect(result1 == result2)
    }

    @Test func unknownCharacterCycleReturnsNil() {
        #expect(ComposeEngine.cycleAccent(for: "🎉") == nil)
        #expect(ComposeEngine.cycleAccent(for: "xyz") == nil)
    }

    // MARK: - Number Cycles

    @Test func numberCycleDigitToSuperscript() {
        let result = ComposeEngine.cycleAccent(for: "1")
        #expect(result == "¹")
    }

    @Test func numberCycleSuperscriptToFraction() {
        let result = ComposeEngine.cycleAccent(for: "¹")
        #expect(result == "½")
    }

    @Test func numberCycleZeroToSuperscript() {
        let result = ComposeEngine.cycleAccent(for: "0")
        #expect(result == "⁰")
    }

    @Test func numberCycleWrapsAround() {
        // "0" cycle is ["0", "⁰"], so "⁰" → "0"
        let result = ComposeEngine.cycleAccent(for: "⁰")
        #expect(result == "0")
    }

    // MARK: - Vietnamese Telex: Vowel Modifications

    @Test func telexVowelDoubling() {
        #expect(ComposeEngine.composeTelex(previous: "a", trigger: "a") == "â")
        #expect(ComposeEngine.composeTelex(previous: "e", trigger: "e") == "ê")
        #expect(ComposeEngine.composeTelex(previous: "o", trigger: "o") == "ô")
    }

    @Test func telexVowelBreve() {
        #expect(ComposeEngine.composeTelex(previous: "a", trigger: "w") == "ă")
    }

    @Test func telexVowelHorn() {
        #expect(ComposeEngine.composeTelex(previous: "o", trigger: "w") == "ơ")
        #expect(ComposeEngine.composeTelex(previous: "u", trigger: "w") == "ư")
    }

    @Test func telexConsonantStroke() {
        #expect(ComposeEngine.composeTelex(previous: "d", trigger: "d") == "đ")
    }

    @Test func telexVowelCasePreservation() {
        #expect(ComposeEngine.composeTelex(previous: "A", trigger: "a") == "Â")
        #expect(ComposeEngine.composeTelex(previous: "O", trigger: "o") == "Ô")
        #expect(ComposeEngine.composeTelex(previous: "D", trigger: "d") == "Đ")
        #expect(ComposeEngine.composeTelex(previous: "U", trigger: "w") == "Ư")
        #expect(ComposeEngine.composeTelex(previous: "A", trigger: "w") == "Ă")
        #expect(ComposeEngine.composeTelex(previous: "E", trigger: "e") == "Ê")
    }

    // MARK: - Vietnamese Telex: Digraph

    @Test func telexDigraphCompose() {
        let result = ComposeEngine.composeTelexDigraph(prev2: "u", prev1: "o", trigger: "w")
        #expect(result?.0 == "ươ")
        #expect(result?.1 == 2)
    }

    @Test func telexDigraphCasePreservation() {
        let result = ComposeEngine.composeTelexDigraph(prev2: "U", prev1: "o", trigger: "w")
        #expect(result?.0 == "Ươ")
        #expect(result?.1 == 2)
    }

    @Test func telexDigraphNonMatchReturnsNil() {
        // "ao" is not a recognized digraph for w
        #expect(ComposeEngine.composeTelexDigraph(prev2: "a", prev1: "o", trigger: "w") == nil)
        #expect(ComposeEngine.composeTelexDigraph(prev2: "u", prev1: "o", trigger: "s") == nil)
    }

    // MARK: - Vietnamese Telex: Tone Marks

    @Test func telexToneAcute() {
        #expect(ComposeEngine.composeTelex(previous: "a", trigger: "s") == "á")
        #expect(ComposeEngine.composeTelex(previous: "â", trigger: "s") == "ấ")
        #expect(ComposeEngine.composeTelex(previous: "ă", trigger: "s") == "ắ")
        #expect(ComposeEngine.composeTelex(previous: "e", trigger: "s") == "é")
        #expect(ComposeEngine.composeTelex(previous: "ê", trigger: "s") == "ế")
        #expect(ComposeEngine.composeTelex(previous: "o", trigger: "s") == "ó")
        #expect(ComposeEngine.composeTelex(previous: "ơ", trigger: "s") == "ớ")
        #expect(ComposeEngine.composeTelex(previous: "u", trigger: "s") == "ú")
        #expect(ComposeEngine.composeTelex(previous: "ư", trigger: "s") == "ứ")
        #expect(ComposeEngine.composeTelex(previous: "y", trigger: "s") == "ý")
    }

    @Test func telexToneGrave() {
        #expect(ComposeEngine.composeTelex(previous: "a", trigger: "f") == "à")
        #expect(ComposeEngine.composeTelex(previous: "â", trigger: "f") == "ầ")
        #expect(ComposeEngine.composeTelex(previous: "ê", trigger: "f") == "ề")
    }

    @Test func telexToneHookAbove() {
        #expect(ComposeEngine.composeTelex(previous: "a", trigger: "r") == "ả")
        #expect(ComposeEngine.composeTelex(previous: "ơ", trigger: "r") == "ở")
        #expect(ComposeEngine.composeTelex(previous: "ư", trigger: "r") == "ử")
    }

    @Test func telexToneTilde() {
        #expect(ComposeEngine.composeTelex(previous: "a", trigger: "x") == "ã")
        #expect(ComposeEngine.composeTelex(previous: "ô", trigger: "x") == "ỗ")
    }

    @Test func telexToneDotBelow() {
        #expect(ComposeEngine.composeTelex(previous: "a", trigger: "j") == "ạ")
        #expect(ComposeEngine.composeTelex(previous: "ă", trigger: "j") == "ặ")
        #expect(ComposeEngine.composeTelex(previous: "ô", trigger: "j") == "ộ")
        #expect(ComposeEngine.composeTelex(previous: "ơ", trigger: "j") == "ợ")
    }

    @Test func telexToneCasePreservation() {
        #expect(ComposeEngine.composeTelex(previous: "A", trigger: "s") == "Á")
        #expect(ComposeEngine.composeTelex(previous: "Ê", trigger: "f") == "Ề")
    }

    // MARK: - Vietnamese Telex: Tone Removal (z)

    @Test func telexToneRemoval() {
        #expect(ComposeEngine.composeTelex(previous: "á", trigger: "z") == "a")
        #expect(ComposeEngine.composeTelex(previous: "ấ", trigger: "z") == "â")
        #expect(ComposeEngine.composeTelex(previous: "ắ", trigger: "z") == "ă")
        #expect(ComposeEngine.composeTelex(previous: "ờ", trigger: "z") == "ơ")
        #expect(ComposeEngine.composeTelex(previous: "ự", trigger: "z") == "ư")
    }

    @Test func telexToneRemovalCasePreservation() {
        #expect(ComposeEngine.composeTelex(previous: "Á", trigger: "z") == "A")
        #expect(ComposeEngine.composeTelex(previous: "Ế", trigger: "z") == "Ê")
    }

    // MARK: - Vietnamese Telex: Undo Vowel Modifications

    @Test func telexUndoVowelMod() {
        #expect(ComposeEngine.composeTelex(previous: "â", trigger: "a") == "aa")
        #expect(ComposeEngine.composeTelex(previous: "ê", trigger: "e") == "ee")
        #expect(ComposeEngine.composeTelex(previous: "ô", trigger: "o") == "oo")
        #expect(ComposeEngine.composeTelex(previous: "ă", trigger: "w") == "aw")
        #expect(ComposeEngine.composeTelex(previous: "ơ", trigger: "w") == "ow")
        #expect(ComposeEngine.composeTelex(previous: "ư", trigger: "w") == "uw")
        #expect(ComposeEngine.composeTelex(previous: "đ", trigger: "d") == "dd")
    }

    @Test func telexUndoVowelModCasePreservation() {
        #expect(ComposeEngine.composeTelex(previous: "Â", trigger: "a") == "Aa")
        #expect(ComposeEngine.composeTelex(previous: "Đ", trigger: "d") == "Dd")
        #expect(ComposeEngine.composeTelex(previous: "Ô", trigger: "o") == "Oo")
    }

    // MARK: - Vietnamese Telex: Undo Tone Marks

    @Test func telexUndoToneMark() {
        #expect(ComposeEngine.composeTelex(previous: "á", trigger: "s") == "as")
        #expect(ComposeEngine.composeTelex(previous: "ấ", trigger: "s") == "âs")
        #expect(ComposeEngine.composeTelex(previous: "à", trigger: "f") == "af")
        #expect(ComposeEngine.composeTelex(previous: "ạ", trigger: "j") == "aj")
        #expect(ComposeEngine.composeTelex(previous: "ả", trigger: "r") == "ar")
        #expect(ComposeEngine.composeTelex(previous: "ã", trigger: "x") == "ax")
    }

    // MARK: - Vietnamese Telex: Undo Digraph

    @Test func telexUndoDigraph() {
        let result = ComposeEngine.composeTelexDigraph(prev2: "ư", prev1: "ơ", trigger: "w")
        #expect(result?.0 == "uo")
        #expect(result?.1 == 2)
    }

    // MARK: - Vietnamese Telex: Tone Replacement

    @Test func telexToneReplacement() {
        #expect(ComposeEngine.composeTelex(previous: "á", trigger: "f") == "à")
        #expect(ComposeEngine.composeTelex(previous: "á", trigger: "r") == "ả")
        #expect(ComposeEngine.composeTelex(previous: "á", trigger: "x") == "ã")
        #expect(ComposeEngine.composeTelex(previous: "á", trigger: "j") == "ạ")
    }

    @Test func telexToneReplacementOnModifiedVowel() {
        #expect(ComposeEngine.composeTelex(previous: "ấ", trigger: "f") == "ầ")
        #expect(ComposeEngine.composeTelex(previous: "ấ", trigger: "x") == "ẫ")
        #expect(ComposeEngine.composeTelex(previous: "ắ", trigger: "j") == "ặ")
    }

    // MARK: - Vietnamese Telex: Non-vowel Passthrough

    @Test func telexNonVowelPassthrough() {
        #expect(ComposeEngine.composeTelex(previous: "b", trigger: "s") == nil)
        #expect(ComposeEngine.composeTelex(previous: "n", trigger: "f") == nil)
        #expect(ComposeEngine.composeTelex(previous: "t", trigger: "r") == nil)
        #expect(ComposeEngine.composeTelex(previous: "c", trigger: "a") == nil)
        #expect(ComposeEngine.composeTelex(previous: "h", trigger: "w") == nil)
    }

    @Test func telexNonTelexTriggerReturnsNil() {
        #expect(ComposeEngine.composeTelex(previous: "a", trigger: "b") == nil)
        #expect(ComposeEngine.composeTelex(previous: "a", trigger: "n") == nil)
        #expect(ComposeEngine.composeTelex(previous: "e", trigger: "t") == nil)
    }
}
