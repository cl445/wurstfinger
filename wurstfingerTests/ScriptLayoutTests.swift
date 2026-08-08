//
//  ScriptLayoutTests.swift
//  WurstfingerTests
//
//  Script-specific characters of the non-Latin layouts, driven end-to-end
//  through the pipeline (makeViewModel + handleGesture) so the binding, the
//  resolver chain and the circle-gesture fallback are all covered.
//  Every position here comes from the MessagEase reference layout.
//

import Foundation
import Testing
@testable import WurstfingerApp

private func inserts(_ target: MockTextTarget) -> [String] {
    target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
}

// MARK: - Thai

struct ThaiLayoutTests {
    /// The reference's center returns live on the circle gesture. ฬ ฒ ฑ ฏ have
    /// no other position in the layout.
    @Test func circleGestureTypesTheReferenceCenterReturns() {
        let (vm, target) = makeViewModel(languageId: "th_TH")

        vm.handleGesture(.circularClockwise, keyId: GridSlot.topLeft, isReturn: false)
        vm.handleGesture(.circularClockwise, keyId: GridSlot.bottomLeft, isReturn: false)
        vm.handleGesture(.circularClockwise, keyId: GridSlot.bottomCenter, isReturn: false)
        vm.handleGesture(.circularClockwise, keyId: GridSlot.bottomRight, isReturn: false)

        #expect(inserts(target) == ["ฬ", "ฒ", "ฑ", "ฏ"])
    }

    /// Both directions carry the same binding — otherwise the wrong-direction
    /// circle falls into the uppercase fallback, which is the identity here.
    @Test func bothCircleDirectionsProduceTheSameConsonant() {
        let (vm, target) = makeViewModel(languageId: "th_TH")

        vm.handleGesture(.circularCounterclockwise, keyId: GridSlot.topLeft, isReturn: false)

        #expect(inserts(target) == ["ฬ"])
    }

    @Test func bahtSignRidesTheThoThahanReturnSwipe() {
        let (vm, target) = makeViewModel(languageId: "th_TH")

        vm.handleGesture(.swipeLeft, keyId: GridSlot.midRight, isReturn: false)
        vm.handleGesture(.swipeLeft, keyId: GridSlot.midRight, isReturn: true)

        #expect(inserts(target) == ["ท", "฿"])
    }
}

// MARK: - Japanese kana

struct KanaLayoutTests {
    @Test func hiraganaTypesIdeographicCommaAndFullStop() {
        let (vm, target) = makeViewModel(languageId: "ja_JP")

        vm.handleGesture(.swipeDown, keyId: GridSlot.bottomCenter, isReturn: false)
        vm.handleGesture(.swipeDownLeft, keyId: GridSlot.bottomCenter, isReturn: false)

        #expect(inserts(target) == ["。", "、"])
    }

    /// The Latin marks that 、 and 。 displace stay one return swipe away.
    @Test func hiraganaKeepsLatinPunctuationOnTheReturnSwipe() {
        let (vm, target) = makeViewModel(languageId: "ja_JP")

        vm.handleGesture(.swipeDown, keyId: GridSlot.bottomCenter, isReturn: true)
        vm.handleGesture(.swipeDownLeft, keyId: GridSlot.bottomCenter, isReturn: true)

        #expect(inserts(target) == [".", ","])
    }

    @Test func katakanaTypesIdeographicCommaAndFullStop() {
        let (vm, target) = makeViewModel(languageId: "ja_JP_katakana")

        vm.handleGesture(.swipeDown, keyId: GridSlot.bottomCenter, isReturn: false)
        vm.handleGesture(.swipeDownLeft, keyId: GridSlot.bottomCenter, isReturn: false)

        #expect(inserts(target) == ["。", "、"])
    }

    /// Small kana sit on the return swipe of their full-size counterpart; ぃ is
    /// the い key's circle output.
    @Test func hiraganaReturnSwipesTypeSmallKana() {
        let (vm, target) = makeViewModel(languageId: "ja_JP")

        vm.handleGesture(.swipeDown, keyId: GridSlot.topLeft, isReturn: true)
        vm.handleGesture(.swipeUp, keyId: GridSlot.center, isReturn: true)
        vm.handleGesture(.swipeUpLeft, keyId: GridSlot.midRight, isReturn: true)
        vm.handleGesture(.swipeRight, keyId: GridSlot.bottomLeft, isReturn: true)
        vm.handleGesture(.swipeUp, keyId: GridSlot.bottomRight, isReturn: true)
        vm.handleGesture(.swipeLeft, keyId: GridSlot.bottomRight, isReturn: true)
        vm.handleGesture(.swipeDownLeft, keyId: GridSlot.bottomRight, isReturn: true)
        vm.handleGesture(.circularClockwise, keyId: GridSlot.topRight, isReturn: false)

        #expect(inserts(target) == ["ゃ", "ぁ", "ゅ", "ぅ", "ぇ", "ょ", "ぉ", "ぃ"])
    }

    @Test func katakanaSmallKanaAreDerivedFromHiragana() {
        let (vm, target) = makeViewModel(languageId: "ja_JP_katakana")

        vm.handleGesture(.swipeDown, keyId: GridSlot.topLeft, isReturn: true)
        vm.handleGesture(.swipeUp, keyId: GridSlot.center, isReturn: true)
        vm.handleGesture(.swipeUpLeft, keyId: GridSlot.midRight, isReturn: true)
        vm.handleGesture(.swipeRight, keyId: GridSlot.bottomLeft, isReturn: true)
        vm.handleGesture(.swipeUp, keyId: GridSlot.bottomRight, isReturn: true)
        vm.handleGesture(.swipeLeft, keyId: GridSlot.bottomRight, isReturn: true)
        vm.handleGesture(.swipeDownLeft, keyId: GridSlot.bottomRight, isReturn: true)
        vm.handleGesture(.circularClockwise, keyId: GridSlot.topRight, isReturn: false)
        // ヮ has no hiragana counterpart on this key, so it is layered on.
        vm.handleGesture(.swipeDown, keyId: GridSlot.midLeft, isReturn: true)

        #expect(inserts(target) == ["ャ", "ァ", "ュ", "ゥ", "ェ", "ョ", "ォ", "ィ", "ヮ"])
    }

    @Test func katakanaSeparatorKeepsTheColonOnItsReturnSwipe() {
        let (vm, target) = makeViewModel(languageId: "ja_JP_katakana")

        vm.handleGesture(.swipeDownRight, keyId: GridSlot.bottomCenter, isReturn: false)
        vm.handleGesture(.swipeDownRight, keyId: GridSlot.bottomCenter, isReturn: true)

        #expect(inserts(target) == ["・", ":"])
    }
}

// MARK: - Arabic script

struct ArabicScriptLayoutTests {
    static let ids = ["ar", "fa_IR", "ur"]

    /// Slot and gesture of every mark `ScriptPunctuation.arabicScript` places.
    static let punctuationPositions: [(slot: String, gesture: GestureType)] = [
        (GridSlot.topRight, .swipeLeft),
        (GridSlot.bottomCenter, .swipeDownLeft),
        (GridSlot.bottomRight, .swipeDownLeft),
        (GridSlot.bottomLeft, .swipeRight),
    ]

    @Test(arguments: ArabicScriptLayoutTests.ids)
    func layoutsUseArabicPunctuation(id: String) {
        let (vm, target) = makeViewModel(languageId: id)

        for position in Self.punctuationPositions {
            vm.handleGesture(position.gesture, keyId: position.slot, isReturn: false)
        }

        #expect(inserts(target) == ["؟", "،", "؛", "٭"], "[\(id)] Latin punctuation in right-to-left text")
    }

    @Test(arguments: ArabicScriptLayoutTests.ids)
    func displacedLatinPunctuationStaysOnTheReturnSwipe(id: String) {
        let (vm, target) = makeViewModel(languageId: id)

        for position in Self.punctuationPositions {
            vm.handleGesture(position.gesture, keyId: position.slot, isReturn: true)
        }

        #expect(inserts(target) == ["?", ",", ";", "*"], "[\(id)] displaced Latin mark is unreachable")
    }

    /// The three layouts share one punctuation table, so they cannot drift.
    @Test func punctuationPositionsCannotDriftApart() throws {
        let modes = try Self.ids.map { id in
            try #require(KeyboardRegistry.load(id: id)?.mode(ModeNames.main), "no main mode for \(id)")
        }

        for position in Self.punctuationPositions {
            let bindings = modes.map { $0.key(for: position.slot)?.bindings[position.gesture] }
            let reference = try #require(
                bindings.first ?? nil,
                "\(position.slot) \(position.gesture) is unbound in \(Self.ids[0])"
            )
            #expect(
                bindings.allSatisfy { $0?.action == reference.action },
                "\(position.slot) \(position.gesture) differs between the Arabic-script layouts"
            )
            #expect(
                bindings.allSatisfy { $0?.returnAction == reference.returnAction },
                "\(position.slot) \(position.gesture) return differs between the Arabic-script layouts"
            )
        }
    }

    /// Standard Persian and Urdu orthography needs the half-space inside words.
    @Test(arguments: ["fa_IR", "ur"])
    func persianAndUrduTatweelReturnTypesZeroWidthNonJoiner(id: String) {
        let (vm, target) = makeViewModel(languageId: id)

        vm.handleGesture(.swipeRight, keyId: GridSlot.topLeft, isReturn: false)
        vm.handleGesture(.swipeRight, keyId: GridSlot.topLeft, isReturn: true)

        #expect(inserts(target) == ["ـ", "\u{200C}"])
    }
}

// MARK: - Hindi

struct HindiLayoutTests {
    @Test func rupeeSignIsTypable() {
        let (vm, target) = makeViewModel(languageId: "hi_IN")

        vm.handleGesture(.swipeLeft, keyId: GridSlot.bottomCenter, isReturn: false)

        #expect(inserts(target) == ["₹"])
    }
}

// MARK: - Hebrew

struct HebrewPunctuationTests {
    @Test func gereshAndGershayimAreTypable() {
        let (vm, target) = makeViewModel(languageId: "he_IL")

        vm.handleGesture(.swipeUpRight, keyId: GridSlot.bottomCenter, isReturn: false)
        vm.handleGesture(.swipeUpLeft, keyId: GridSlot.bottomCenter, isReturn: false)

        #expect(inserts(target) == ["׳", "״"])
    }

    @Test func latinQuotesStayOnTheReturnSwipe() {
        let (vm, target) = makeViewModel(languageId: "he_IL")

        vm.handleGesture(.swipeUpRight, keyId: GridSlot.bottomCenter, isReturn: true)
        vm.handleGesture(.swipeUpLeft, keyId: GridSlot.bottomCenter, isReturn: true)

        #expect(inserts(target) == ["'", "\""])
    }
}
