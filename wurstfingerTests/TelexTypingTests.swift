//
//  TelexTypingTests.swift
//  WurstfingerTests
//
//  Integration tests for the Vietnamese Telex input method end-to-end through
//  KeyboardViewModel: typing key gestures on the vi_VN layout should trigger
//  TelexMiddleware composition (digraphs and tone marks), not just commit the
//  raw letters.
//
//  vi_VN center grid (taps):  a n i / h o r / t e s
//  → topLeft = "a", center = "o", bottomRight = "s", center ↓ = "d".
//

import Foundation
import Testing
@testable import WurstfingerApp

@Suite(.serialized)
struct TelexTypingTests {
    /// Doubling a vowel composes its circumflex (a + a → â).
    @Test func doublingVowelComposesCircumflex() {
        let (vm, target) = makeViewModel(languageId: "vi_VN")

        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false) // a
        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false) // a → â

        #expect(target.documentContextBeforeInput == "â")
    }

    /// Doubling "o" composes ô (independent vowel, via the center key).
    @Test func doublingOComposesOCircumflex() {
        let (vm, target) = makeViewModel(languageId: "vi_VN")

        vm.handleGesture(.tap, keyId: GridSlot.center, isReturn: false) // o
        vm.handleGesture(.tap, keyId: GridSlot.center, isReturn: false) // o → ô

        #expect(target.documentContextBeforeInput == "ô")
    }

    /// The "s" key applies the acute tone to the preceding vowel (a + s → á).
    @Test func toneKeyAppliesAcuteAccent() {
        let (vm, target) = makeViewModel(languageId: "vi_VN")

        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false) // a
        vm.handleGesture(.tap, keyId: GridSlot.bottomRight, isReturn: false) // s → á

        #expect(target.documentContextBeforeInput == "á")
    }

    /// Doubling "d" composes the đ consonant (d is the center down-swipe).
    @Test func doublingDComposesDStroke() {
        let (vm, target) = makeViewModel(languageId: "vi_VN")

        vm.handleGesture(.swipeDown, keyId: GridSlot.center, isReturn: false) // d
        vm.handleGesture(.swipeDown, keyId: GridSlot.center, isReturn: false) // d → đ

        #expect(target.documentContextBeforeInput == "đ")
    }

    /// A non-Telex language (de_DE) does NOT apply Telex composition — typing
    /// "a" then "a" yields "aa", guarding against the middleware misfiring.
    @Test func telexDoesNotApplyForNonTelexLanguage() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false) // a
        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false) // a

        #expect(target.documentContextBeforeInput == "aa")
    }
}
