//
//  KatakanaDerivationTests.swift
//  WurstfingerTests
//
//  Characterization tests for the katakana layout, which is now derived from
//  the hiragana tables via ICU `.hiraganaToKatakana` instead of a hand-authored
//  glyph-for-glyph mirror. The expected values below are the exact values that
//  were hand-authored before the refactor, so equality proves zero behavior
//  change. Also pins the two genuine katakana-only deltas (the ・ separator and
//  the wa-row voiced combine entries) and the #268 ゛-cascade / ja_JP locale.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct KatakanaDerivationTests {
    // MARK: - Derived tables equal the previously hand-authored ones

    @Test func derivedCenterCharactersMatchHandAuthored() {
        let expected: [[String]] = [
            ["ク", "ツ", "イ"],
            ["フ", "ル", "ラ"],
            ["ト", "ン", "ス"],
        ]
        #expect(LanguageDefinitions.katakanaCenterCharacters == expected)
    }

    @Test func derivedDirectionalOverridesMatchHandAuthored() {
        let expected: [String: [GestureType: String]] = [
            GridSlot.topLeft: [.swipeRight: "ー", .swipeDown: "ヤ", .swipeDownRight: "サ"],
            GridSlot.topCenter: [
                .swipeUp: "ソ", .swipeUpLeft: "メ", .swipeUpRight: "モ",
                .swipeDown: "マ",
            ],
            GridSlot.topRight: [.swipeDownLeft: "ヒ"],
            GridSlot.midLeft: [
                .swipeLeft: "セ", .swipeRight: "キ", .swipeDown: "ワ",
                .swipeDownLeft: "ヘ", .swipeDownRight: "ニ",
            ],
            GridSlot.center: [
                .swipeUp: "ア", .swipeUpLeft: "カ", .swipeUpRight: "シ",
                .swipeLeft: "ハ", .swipeRight: "リ", .swipeDown: "レ",
                .swipeDownLeft: "タ", .swipeDownRight: "ホ",
            ],
            GridSlot.midRight: [
                .swipeUpLeft: "ユ", .swipeLeft: "ロ", .swipeRight: "ミ",
                .swipeDownRight: "チ",
            ],
            GridSlot.bottomLeft: [
                .swipeUp: "ノ", .swipeUpLeft: "ヽ", .swipeUpRight: "ム",
                .swipeLeft: "ヲ", .swipeRight: "ウ", .swipeDown: "ナ",
            ],
            GridSlot.bottomCenter: [
                .swipeUp: "テ", .swipeUpLeft: "゛", .swipeLeft: "ネ",
                .swipeRight: "ケ", .swipeDownRight: "・",
            ],
            GridSlot.bottomRight: [
                .swipeUp: "エ", .swipeUpLeft: "コ", .swipeLeft: "ヨ",
                .swipeRight: "ヌ", .swipeDownLeft: "オ",
            ],
        ]
        #expect(LanguageDefinitions.katakanaDirectionalOverrides == expected)
    }

    // MARK: - Genuine katakana-only deltas survive

    @Test func nakaguroSeparatorIsPresent() {
        // The ・ separator has no hiragana counterpart; it must be layered on.
        #expect(
            LanguageDefinitions.katakanaDirectionalOverrides[GridSlot.bottomCenter]?[.swipeDownRight] == "・"
        )
        // …and it must not have leaked into the hiragana layout: hiragana has
        // no override there, so it keeps the shared default (":") instead.
        let hiraganaDef = KeyboardRegistry.load(id: "ja_JP")
        let hiraBottomCenter = hiraganaDef?.modes[ModeNames.main]?.key(for: GridSlot.bottomCenter)
        #expect(hiraBottomCenter?.bindings[.swipeDownRight]?.action == .commitText(":"))
    }

    @Test func waRowVoicedCombineEntriesSurvive() throws {
        let def = try #require(KeyboardRegistry.load(id: "ja_JP_katakana"))
        let rules = try #require(def.settings.combineRuleSet?.rules["゛"])
        // The wa-row voiced kana are unique to katakana and cannot be derived
        // from the hiragana table.
        #expect(rules["ワ"] == "ヷ")
        #expect(rules["ヰ"] == "ヸ")
        #expect(rules["ヱ"] == "ヹ")
        #expect(rules["ヲ"] == "ヺ")
    }

    @Test func dakutenCascadeAndLocaleRemainIntact() throws {
        let def = try #require(KeyboardRegistry.load(id: "ja_JP_katakana"))
        let rules = try #require(def.settings.combineRuleSet?.rules["゛"])
        // #268 handakuten cascade (voiced → semi-voiced) and sokuon.
        #expect(rules["バ"] == "パ")
        #expect(rules["ビ"] == "ピ")
        #expect(rules["ブ"] == "プ")
        #expect(rules["ベ"] == "ペ")
        #expect(rules["ボ"] == "ポ")
        #expect(rules["ヅ"] == "ッ")
        // Locale must stay a valid BCP-47 tag driving uppercasing / system APIs.
        #expect(def.localeIdentifier == "ja_JP")
    }

    // MARK: - Built definition renders the derived glyphs

    @Test func builtDefinitionExposesDerivedKatakana() throws {
        let def = try #require(KeyboardRegistry.load(id: "ja_JP_katakana"))
        let main = try #require(def.modes[ModeNames.main])
        // Center tap glyph and a representative swipe come through as commits.
        let center = main.key(for: GridSlot.center)
        #expect(center?.bindings[.tap]?.action == .commitText("ル"))
        #expect(center?.bindings[.swipeUp]?.action == .commitText("ア"))
        let bottomCenter = main.key(for: GridSlot.bottomCenter)
        #expect(bottomCenter?.bindings[.swipeDownRight]?.action == .commitText("・"))
    }
}
