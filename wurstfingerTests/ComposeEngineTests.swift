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
        #expect(ComposeEngine.compose(previous: "a", trigger: "'") == "á")
        #expect(ComposeEngine.compose(previous: "e", trigger: "'") == "é")
        #expect(ComposeEngine.compose(previous: "n", trigger: "'") == "ń")
    }

    @Test func graveCompose() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "`") == "à")
        #expect(ComposeEngine.compose(previous: "e", trigger: "`") == "è")
        #expect(ComposeEngine.compose(previous: "u", trigger: "`") == "ù")
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
        #expect(ComposeEngine.compose(previous: " ", trigger: "'") == "'")
        #expect(ComposeEngine.compose(previous: " ", trigger: "`") == "`")
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
}
