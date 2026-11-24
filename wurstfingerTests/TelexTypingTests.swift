//
//  TelexTypingTests.swift
//  WurstfingerTests
//
//  Integration tests for the Vietnamese Telex input method end-to-end through
//  KeyboardViewModel: typing key gestures on the vi_VN layout should trigger
//  Telex composition (vowel shapes and syllable tones), not just commit the
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

    /// Whole keystroke sequences, not precomposed fixtures: a tone may come
    /// after a final consonant, or before the rest of its syllable is known.
    @Test(arguments: [
        ("Tieengs Vieetj", "Tiếng Việt"), ("dduwowngf", "đường"), ("nuowcs", "nước"),
        ("hoangf", "hoàng"), ("hoafng", "hoàng"), ("hofang", "hoàng"),
        ("hoaf", "hòa"), ("khoer", "khỏe"), ("thuys", "thúy"), ("mair", "mải"), ("ngoais", "ngoái"),
        ("nguyeenx", "nguyễn"), ("quowr", "quở"), ("buowir", "bưởi"),
        ("quas", "quá"), ("quoocs", "quốc"), ("giaf", "già"), ("ginf", "gìn"),
        ("muoosi", "muối"), ("asw", "ắ"), ("TOANS", "TOÁN"),
        ("toanfs", "toán"), ("toansz", "toan"), ("tieengsz", "tiêng"), ("toanss", "toans"),
        ("a s", "a s"), ("an,s", "an,s"), ("an1s", "an1s"), ("an🙂s", "an🙂s"),
    ])
    func typingSyllable(keys: String, expected: String) {
        let (vm, target) = makeViewModel(languageId: "vi_VN")
        for key in keys {
            vm.dispatchAction(.commitText(String(key)))
        }
        #expect(target.documentContextBeforeInput == expected)
    }

    @Test func standaloneWGestureCanBeEscaped() {
        let (vm, target) = makeViewModel(languageId: "vi_VN")
        vm.handleGesture(.swipeUp, keyId: GridSlot.bottomCenter, isReturn: false)
        #expect(target.documentContextBeforeInput == "ư")
        // Hosts can report either nil or empty text at the end of the field.
        target.documentContextAfterInput = ""
        vm.handleGesture(.swipeUp, keyId: GridSlot.bottomCenter, isReturn: false)
        #expect(target.documentContextBeforeInput == "w")
    }

    @Test(arguments: [
        ("twf", "từ"), ("wweb", "web"), ("W", "Ư"), ("Wweb", "Web"), ("WW", "W"), ("wW", "w"),
        ("aw ow uw uow", "ă ơ ư ươ"), ("aww oww uww", "aw ow uw"), ("www", "wư"),
    ])
    func standaloneWTyping(keys: String, expected: String) {
        let (vm, target) = makeViewModel(languageId: "vi_VN")
        for key in keys {
            vm.dispatchAction(.commitText(String(key)))
        }
        #expect(target.documentContextBeforeInput == expected)
    }

    @Test func interveningEditsDisarmStandaloneW() {
        let (vm, target) = makeViewModel(languageId: "vi_VN")
        vm.dispatchAction(.commitText("w"))
        vm.dispatchAction(.commitText("n"))
        vm.dispatchAction(.deleteBackward)
        vm.dispatchAction(.commitText("w"))
        #expect(target.documentContextBeforeInput == "uw") // ordinary undo on an existing ư
    }

    @Test func caretMoveDoesNotEscapeAnUnrelatedHorn() {
        let (vm, target) = makeViewModel(languageId: "vi_VN")
        vm.dispatchAction(.commitText("w"))
        target.documentContextBeforeInput = "tư"
        vm.dispatchAction(.commitText("w"))
        #expect(target.documentContextBeforeInput == "tuw")
    }

    @Test func fieldSwitchDoesNotEscapeAnIdenticalHorn() {
        let (vm, target) = makeViewModel(languageId: "vi_VN")
        target.documentIdentifier = UUID()
        vm.dispatchAction(.commitText("w"))
        target.documentIdentifier = UUID() // new field, same visible text on both sides
        vm.dispatchAction(.commitText("w"))
        #expect(target.documentContextBeforeInput == "uw")
    }

    @Test func selectedTextAndMultiCharacterCommitsKeepLiteralW() {
        let (vm, target) = makeViewModel(languageId: "vi_VN")
        vm.dispatchAction(.commitText("w"))
        target.selectedText = "selection"
        vm.dispatchAction(.commitText("w"))
        vm.dispatchAction(.commitText("ww"))
        #expect(target.documentContextBeforeInput == "ưwww")
        #expect(!target.events.contains(.deleteBackward))
    }

    @Test func standaloneWDoesNotApplyToOtherLanguages() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        vm.dispatchAction(.commitText("w"))
        vm.dispatchAction(.commitText("w"))
        #expect(target.documentContextBeforeInput == "ww")
    }

    @Test func toneAtCursorRewritesOnlyChangedSuffix() {
        let (vm, target) = makeViewModel(languageId: "vi_VN")
        target.documentContextBeforeInput = "🙂 tie\u{302}ng"
        target.documentContextAfterInput = "!"
        vm.dispatchAction(.commitText("s"))
        #expect(target.events == [.deleteBackward, .deleteBackward, .deleteBackward, .insertText("ếng")])
        #expect(target.documentContextBeforeInput == "🙂 tiếng")
        #expect(target.documentContextAfterInput == "!")
    }

    @Test func selectedTextIsReplacedByLiteralToneKey() {
        let (vm, target) = makeViewModel(languageId: "vi_VN")
        target.documentContextBeforeInput = "tiêng"
        target.selectedText = "word"
        vm.dispatchAction(.commitText("s"))
        #expect(target.events == [.insertText("s")])
        #expect(target.documentContextBeforeInput == "tiêngs")
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
