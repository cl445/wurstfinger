//
//  ModeDefinitionValidationTests.swift
//  WurstfingerTests
//
//  Tests for KeyboardMode, KeyboardDefinition, and Validation.
//

import Foundation
import Testing
@testable import WurstfingerApp

// MARK: - Test Helpers

private func letterBinding(_ char: String) -> KeyBinding {
    KeyBinding(label: char, action: .commitText(char), category: nil, returnAction: nil, accessibilityLabel: nil)
}

private func letterKey(_ id: String, _ char: String) -> KeyConfig {
    KeyConfig(id: id, bindings: [.tap: letterBinding(char)], swipeMode: .eightWay, slideType: .none, style: .primary, tapCycleActions: nil)
}

private func utilityKey(_ id: String, action: KeyAction) -> KeyConfig {
    KeyConfig(
        id: id,
        bindings: [.tap: KeyBinding(label: id, action: action, category: .utility, returnAction: nil, accessibilityLabel: nil)],
        swipeMode: .none, slideType: .none, style: .utility, tapCycleActions: nil
    )
}

/// Minimal valid mode with 4 keys and a portrait arrangement
private func minimalMode(
    name: String = "main",
    autoTransitions: [KeyCategory: String] = [:]
) -> KeyboardMode {
    let keys: [String: KeyConfig] = [
        "a": letterKey("a", "a"),
        "b": letterKey("b", "b"),
        "c": letterKey("c", "c"),
        "shift": utilityKey("shift", action: .switchMode(ModeNames.shifted)),
    ]
    let arrangement = GridArrangement(columns: 2, rows: [
        [KeyPlacement(keyId: "a"), KeyPlacement(keyId: "b")],
        [KeyPlacement(keyId: "c"), KeyPlacement(keyId: "shift")],
    ])
    return KeyboardMode(
        name: name, keys: keys,
        arrangements: [.portrait: arrangement],
        autoTransitions: autoTransitions
    )
}

/// Minimal valid definition with main + shifted modes
private func minimalDefinition(
    modes: [String: KeyboardMode]? = nil,
    defaultMode: String = ModeNames.main
) -> KeyboardDefinition {
    let defaultModes: [String: KeyboardMode] = [
        ModeNames.main: minimalMode(name: ModeNames.main),
        ModeNames.shifted: minimalMode(name: ModeNames.shifted, autoTransitions: [.letter: ModeNames.main]),
    ]
    return KeyboardDefinition(
        title: "Test", id: "test", localeIdentifier: "en_US",
        modes: modes ?? defaultModes,
        defaultMode: defaultMode,
        settings: KeyboardDefinitionSettings(autoCapitalize: true, composeRuleOverrides: nil)
    )
}

// MARK: - KeyboardMode Tests

struct KeyboardModeTests {
    @Test func keyLookup() {
        let mode = minimalMode()
        #expect(mode.key(for: "a") != nil)
        #expect(mode.key(for: "nonexistent") == nil)
    }

    @Test func arrangementFallbackToPortrait() {
        let mode = minimalMode()
        // Landscape not defined — should fall back to portrait
        let landscape = mode.arrangement(for: .landscape)
        let portrait = mode.arrangement(for: .portrait)
        #expect(landscape == portrait)
    }

    @Test func arrangementReturnsSpecificContext() throws {
        let landscapeArrangement = GridArrangement(columns: 4, rows: [
            [KeyPlacement(keyId: "a"), KeyPlacement(keyId: "b"), KeyPlacement(keyId: "c"), KeyPlacement(keyId: "shift")],
        ])
        let mode = try KeyboardMode(
            name: "main",
            keys: minimalMode().keys,
            arrangements: [
                .portrait: #require(minimalMode().arrangements[.portrait]),
                .landscape: landscapeArrangement,
            ],
            autoTransitions: [:]
        )
        let result = mode.arrangement(for: .landscape)
        #expect(result == landscapeArrangement)
        #expect(result != mode.arrangement(for: .portrait))
    }

    @Test func nextModeStateMachineShifted() {
        let shifted = minimalMode(autoTransitions: [.letter: ModeNames.main])
        #expect(shifted.nextMode(after: .letter) == ModeNames.main)
        #expect(shifted.nextMode(after: .symbol) == nil)
        #expect(shifted.nextMode(after: .utility) == nil)
    }

    @Test func nextModeStateMachineCapsLock() {
        let capsLock = minimalMode(autoTransitions: [:])
        // Empty autoTransitions — mode stays active
        #expect(capsLock.nextMode(after: .letter) == nil)
        #expect(capsLock.nextMode(after: .symbol) == nil)
    }

    @Test func nextModeStateMachineEmoji() {
        let emoji = minimalMode(autoTransitions: [.symbol: ModeNames.main])
        #expect(emoji.nextMode(after: .symbol) == ModeNames.main)
        #expect(emoji.nextMode(after: .letter) == nil)
    }

    @Test func withChangesAutoTransitions() {
        let mode = minimalMode()
        let modified = mode.with(autoTransitions: [.letter: ModeNames.main])
        #expect(modified.autoTransitions[.letter] == ModeNames.main)
        #expect(modified.name == mode.name)
        #expect(modified.keys == mode.keys)
    }

    @Test func withChangesName() {
        let mode = minimalMode()
        let modified = mode.with(name: "capsLock")
        #expect(modified.name == "capsLock")
        #expect(modified.keys == mode.keys)
    }

    @Test func codableRoundtrip() throws {
        let mode = minimalMode(autoTransitions: [.letter: "main"])
        let data = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(KeyboardMode.self, from: data)
        #expect(decoded == mode)
    }
}

// MARK: - KeyboardDefinition Tests

struct KeyboardDefinitionTests {
    @Test func modeLookup() {
        let def = minimalDefinition()
        #expect(def.mode(ModeNames.main) != nil)
        #expect(def.mode(ModeNames.shifted) != nil)
        #expect(def.mode("nonexistent") == nil)
    }

    @Test func locale() {
        let def = minimalDefinition()
        #expect(def.locale.identifier == "en_US")
    }

    @Test func codableRoundtrip() throws {
        let def = minimalDefinition()
        let data = try JSONEncoder().encode(def)
        let decoded = try JSONDecoder().decode(KeyboardDefinition.self, from: data)
        #expect(decoded == def)
    }
}

// MARK: - Native Digit Layer Tests

/// Covers the per-language numeric digit set (Arabic-Indic / Persian) plumbed
/// through `NumericLayouts`, `GridKeyboardFactory`, and `KeyboardDefinition`.
struct NativeDigitLayerTests {
    /// Reads the tap output of a numeric-mode key.
    private func digitTap(_ mode: KeyboardMode?, _ slot: String) -> String? {
        guard case let .commitText(text)? = mode?.keys[slot]?.bindings[.tap]?.action else { return nil }
        return text
    }

    @Test func phoneDefaultsToWesternDigits() {
        let mode = NumericLayouts.phone()
        #expect(digitTap(mode, GridSlot.topLeft) == "1")
        #expect(digitTap(mode, GridSlot.zero) == "0")
    }

    @Test func phoneUsesSuppliedNativeDigits() {
        let mode = NumericLayouts.phone(digits: NumericLayouts.arabicIndicDigits)
        #expect(digitTap(mode, GridSlot.topLeft) == "١") // value 1
        #expect(digitTap(mode, GridSlot.center) == "٥") // value 5
        #expect(digitTap(mode, GridSlot.zero) == "٠") // value 0
    }

    @Test func classicUsesSuppliedNativeDigits() {
        let mode = NumericLayouts.classic(digits: NumericLayouts.persianDigits)
        #expect(digitTap(mode, GridSlot.topLeft) == "۷") // classic top-left is value 7
        #expect(digitTap(mode, GridSlot.zero) == "۰")
    }

    @Test func factoryThreadsDigitsIntoDefinitionAndNumericMode() {
        let def = GridKeyboardFactory.layout(
            id: "test_ar", title: "Test", localeIdentifier: "ar",
            centerCharacters: [["ا", "ب", "ت"], ["ث", "ج", "ح"], ["خ", "د", "ذ"]],
            numericDigits: NumericLayouts.arabicIndicDigits
        )
        #expect(def.numericDigits == NumericLayouts.arabicIndicDigits)
        #expect(digitTap(def.mode(ModeNames.numeric), GridSlot.zero) == "٠")
    }

    @Test func numericDigitsSurviveNumpadStyleSwap() {
        let def = GridKeyboardFactory.layout(
            id: "test_ar", title: "Test", localeIdentifier: "ar",
            centerCharacters: [["ا", "ب", "ت"], ["ث", "ج", "ح"], ["خ", "د", "ذ"]],
            numericDigits: NumericLayouts.arabicIndicDigits
        )
        // Mirror KeyboardViewModel+Pipeline.applyNumpadStyle's classic rebuild.
        let swapped = def.replacingMode(
            ModeNames.numeric,
            with: NumericLayouts.classic(
                digits: def.numericDigits,
                backToAlphaLabel: def.numericBackToAlphaLabel
            )
        )
        #expect(swapped.numericDigits == NumericLayouts.arabicIndicDigits)
        #expect(digitTap(swapped.mode(ModeNames.numeric), GridSlot.zero) == "٠")
    }

    @Test func defaultDefinitionKeepsWesternDigits() {
        let def = GridKeyboardFactory.layout(
            id: "test_en", title: "Test", localeIdentifier: "en_US",
            centerCharacters: [["a", "n", "i"], ["h", "o", "r"], ["t", "e", "s"]]
        )
        #expect(def.numericDigits == NumericLayouts.westernDigits)
        #expect(digitTap(def.mode(ModeNames.numeric), GridSlot.topLeft) == "1")
    }

    @Test func rtlLanguagesShipNativeDigits() {
        #expect(LanguageDefinitions.arabic.makeDefinition().numericDigits == NumericLayouts.arabicIndicDigits)
        #expect(LanguageDefinitions.persian.makeDefinition().numericDigits == NumericLayouts.persianDigits)
        #expect(LanguageDefinitions.urdu.makeDefinition().numericDigits == NumericLayouts.persianDigits)
        #expect(LanguageDefinitions.thai.makeDefinition().numericDigits == NumericLayouts.thaiDigits)
        #expect(LanguageDefinitions.hindi.makeDefinition().numericDigits == NumericLayouts.devanagariDigits)
        // The new non-Arabic-script languages keep Western digits.
        #expect(LanguageDefinitions.greek.makeDefinition().numericDigits == NumericLayouts.westernDigits)
    }

    @Test func hindiCarriesVowelLengtheningCombineRules() {
        let settings = LanguageDefinitions.hindi.makeDefinition().settings
        // Sequential combine: short vowel typed twice → long vowel (इ + इ → ई).
        #expect(settings.combineRuleSet?.rules["इ"]?["इ"] == "ई")
        #expect(settings.combineRuleSet?.rules["उ"]?["उ"] == "ऊ")
        #expect(settings.combineRuleSet?.rules["ऋ"]?["ऋ"] == "ॠ")
        #expect(settings.combineRuleSet?.rules["ऌ"]?["ऌ"] == "ॡ")
        #expect(settings.combineRuleSet?.rules["ऍ"]?["ऍ"] == "ऎ")
        // Languages without combine leave it nil.
        #expect(LanguageDefinitions.thai.makeDefinition().settings.combineRuleSet == nil)
    }

    @Test func kanaCarriesDakutenVoicingCombineRules() {
        // Dakuten voicing: base kana + ゛ → voiced kana (か + ゛ → が).
        let hira = LanguageDefinitions.hiragana.makeDefinition().settings
        #expect(hira.combineRuleSet?.rules["゛"]?["か"] == "が")
        #expect(hira.combineRuleSet?.rules["゛"]?["は"] == "ば")
        let kata = LanguageDefinitions.katakana.makeDefinition().settings
        #expect(kata.combineRuleSet?.rules["゛"]?["カ"] == "ガ")
        // Japanese kana keeps Western digits (no native digit layer).
        #expect(LanguageDefinitions.hiragana.makeDefinition().numericDigits == NumericLayouts.westernDigits)
    }
}

// MARK: - Validation Tests

struct ValidationTests {
    // MARK: Happy Path

    @Test func validDefinitionHasNoErrors() {
        let def = minimalDefinition()
        #expect(def.validate().isEmpty)
    }

    @Test func validModeHasNoErrors() {
        let mode = minimalMode()
        #expect(mode.validate().isEmpty)
    }

    // MARK: Missing Key

    @Test func missingKeyInArrangement() {
        let arrangement = GridArrangement(columns: 2, rows: [
            [KeyPlacement(keyId: "a"), KeyPlacement(keyId: "nonexistent")],
        ])
        let mode = KeyboardMode(
            name: "test",
            keys: ["a": letterKey("a", "a")],
            arrangements: [.portrait: arrangement],
            autoTransitions: [:]
        )
        let errors = mode.validate()
        #expect(errors.contains(.missingKey(keyId: "nonexistent", context: .portrait)))
    }

    // MARK: Missing Mode

    @Test func missingDefaultMode() {
        let def = minimalDefinition(defaultMode: "nonexistent")
        let errors = def.validate()
        #expect(errors.contains(.missingMode("nonexistent")))
    }

    @Test func missingSwitchModeTarget() {
        let shiftKey = KeyConfig(
            id: "shift",
            bindings: [.tap: KeyBinding(
                label: "⇧",
                action: .switchMode("nonexistent"),
                category: .modifier,
                returnAction: nil,
                accessibilityLabel: nil
            )],
            swipeMode: .none, slideType: .none, style: .utility, tapCycleActions: nil
        )
        let keys: [String: KeyConfig] = ["a": letterKey("a", "a"), "shift": shiftKey]
        let arrangement = GridArrangement(columns: 2, rows: [
            [KeyPlacement(keyId: "a"), KeyPlacement(keyId: "shift")],
        ])
        let mode = KeyboardMode(name: "main", keys: keys, arrangements: [.portrait: arrangement], autoTransitions: [:])
        let def = minimalDefinition(modes: [ModeNames.main: mode])
        let errors = def.validate()
        #expect(errors.contains(.missingMode("nonexistent")))
    }

    @Test func missingSwitchModeTargetInReturnAction() {
        let key = KeyConfig(
            id: "shift",
            bindings: [.tap: KeyBinding(
                label: "⇧",
                action: .commitText("x"),
                category: nil,
                returnAction: .switchMode("nonexistent"),
                accessibilityLabel: nil
            )],
            swipeMode: .none, slideType: .none, style: .utility, tapCycleActions: nil
        )
        let arrangement = GridArrangement(columns: 1, rows: [[KeyPlacement(keyId: "shift")]])
        let mode = KeyboardMode(name: "main", keys: ["shift": key], arrangements: [.portrait: arrangement], autoTransitions: [:])
        let def = minimalDefinition(modes: [ModeNames.main: mode])
        #expect(def.validate().contains(.missingMode("nonexistent")))
    }

    @Test func missingSwitchModeTargetInTapCycleActions() {
        let key = KeyConfig(
            id: "cycle",
            bindings: [.tap: KeyBinding(
                label: "c", action: .commitText("c"), category: nil,
                returnAction: nil, accessibilityLabel: nil
            )],
            swipeMode: .none, slideType: .none, style: .primary,
            tapCycleActions: [.commitText("c"), .switchMode("nonexistent")]
        )
        let arrangement = GridArrangement(columns: 1, rows: [[KeyPlacement(keyId: "cycle")]])
        let mode = KeyboardMode(name: "main", keys: ["cycle": key], arrangements: [.portrait: arrangement], autoTransitions: [:])
        let def = minimalDefinition(modes: [ModeNames.main: mode])
        #expect(def.validate().contains(.missingMode("nonexistent")))
    }

    @Test func missingAutoTransitionTarget() {
        let mode = minimalMode(autoTransitions: [.letter: "nonexistent"])
        let def = minimalDefinition(modes: [ModeNames.main: mode])
        let errors = def.validate()
        #expect(errors.contains(.missingMode("nonexistent")))
    }

    // MARK: Column Mismatch

    @Test func columnMismatch() {
        let arrangement = GridArrangement(columns: 3, rows: [
            [KeyPlacement(keyId: "a"), KeyPlacement(keyId: "b")], // sum = 2, expected 3
        ])
        let mode = KeyboardMode(
            name: "test",
            keys: ["a": letterKey("a", "a"), "b": letterKey("b", "b")],
            arrangements: [.portrait: arrangement],
            autoTransitions: [:]
        )
        let errors = mode.validate()
        #expect(errors.contains(.columnMismatch(row: 0, context: .portrait, expected: 3, got: 2)))
    }

    // MARK: Height Multiplier Spanning

    @Test func heightMultiplierSpanningValid() {
        // Row 0: a(1) + b(1, height:2) = 2 columns
        // Row 1: c(1) + [b spans] = 1 + 1 = 2 columns ✓
        let arrangement = GridArrangement(columns: 2, rows: [
            [KeyPlacement(keyId: "a"), KeyPlacement(keyId: "b", widthMultiplier: 1, heightMultiplier: 2)],
            [KeyPlacement(keyId: "c")],
        ])
        let mode = KeyboardMode(
            name: "test",
            keys: ["a": letterKey("a", "a"), "b": letterKey("b", "b"), "c": letterKey("c", "c")],
            arrangements: [.portrait: arrangement],
            autoTransitions: [:]
        )
        #expect(mode.validate().filter { if case .columnMismatch = $0 { true } else { false } }.isEmpty)
    }

    @Test func heightMultiplierSpanningInvalid() {
        // Row 0: a(1) + b(1, height:2) = 2 columns
        // Row 1: c(1) + d(1) + [b spans] = 2 + 1 = 3 ≠ 2
        let arrangement = GridArrangement(columns: 2, rows: [
            [KeyPlacement(keyId: "a"), KeyPlacement(keyId: "b", widthMultiplier: 1, heightMultiplier: 2)],
            [KeyPlacement(keyId: "c"), KeyPlacement(keyId: "d")],
        ])
        let mode = KeyboardMode(
            name: "test",
            keys: [
                "a": letterKey("a", "a"), "b": letterKey("b", "b"),
                "c": letterKey("c", "c"), "d": letterKey("d", "d"),
            ],
            arrangements: [.portrait: arrangement],
            autoTransitions: [:]
        )
        let errors = mode.validate()
        #expect(errors.contains(.columnMismatch(row: 1, context: .portrait, expected: 2, got: 3)))
    }

    @Test func heightMultiplierSpansPastLastRow() {
        // Single row, but key "a" has height 2 — spans into non-existent row 1
        let arrangement = GridArrangement(columns: 2, rows: [
            [KeyPlacement(keyId: "a", widthMultiplier: 1, heightMultiplier: 2), KeyPlacement(keyId: "b")],
        ])
        let mode = KeyboardMode(
            name: "test",
            keys: ["a": letterKey("a", "a"), "b": letterKey("b", "b")],
            arrangements: [.portrait: arrangement],
            autoTransitions: [:]
        )
        let errors = mode.validate()
        #expect(errors.contains(.rowSpanOutOfBounds(keyId: "a", context: .portrait)))
    }

    // MARK: Duplicate Key ID

    @Test func duplicateKeyId() {
        let arrangement = GridArrangement(columns: 2, rows: [
            [KeyPlacement(keyId: "a"), KeyPlacement(keyId: "a")],
        ])
        let mode = KeyboardMode(
            name: "test",
            keys: ["a": letterKey("a", "a")],
            arrangements: [.portrait: arrangement],
            autoTransitions: [:]
        )
        let errors = mode.validate()
        #expect(errors.contains(.duplicateKeyId("a")))
    }

    // MARK: Empty Key Pool

    @Test func emptyKeyPool() {
        let arrangement = GridArrangement(columns: 0, rows: [])
        let mode = KeyboardMode(
            name: "test", keys: [:],
            arrangements: [.portrait: arrangement],
            autoTransitions: [:]
        )
        let errors = mode.validate()
        #expect(errors.contains(.emptyKeyPool))
    }

    // MARK: No Portrait Arrangement

    @Test func noPortraitArrangement() {
        let arrangement = GridArrangement(columns: 2, rows: [
            [KeyPlacement(keyId: "a"), KeyPlacement(keyId: "b")],
        ])
        let mode = KeyboardMode(
            name: "test",
            keys: ["a": letterKey("a", "a"), "b": letterKey("b", "b")],
            arrangements: [.landscape: arrangement], // No portrait!
            autoTransitions: [:]
        )
        let errors = mode.validate()
        #expect(errors.contains(.noPortraitArrangement))
    }

    // MARK: Mode Name Mismatch

    @Test func modeNameMismatchDetected() {
        let mode = minimalMode()
        let definition = KeyboardDefinition(
            title: "Test", id: "test", localeIdentifier: "en_US",
            modes: ["wrong_key": mode], // key "wrong_key" != mode.name "main"
            defaultMode: "wrong_key",
            settings: KeyboardDefinitionSettings(
                autoCapitalize: false,
                composeRuleOverrides: nil
            )
        )
        let errors = definition.validate()
        #expect(errors.contains(.modeNameMismatch(key: "wrong_key", modeName: "main")))
    }
}

// MARK: - Japanese Kana / Locale Tests

struct KanaAndLocaleTests {
    @Test func kanaHandakutenAndSokuonReachable() {
        let hira = LanguageDefinitions.hiragana.makeDefinition().settings
        // Handakuten cascade は→ば→ぱ and sokuon つ→づ→っ on the same ゛ key.
        #expect(hira.combineRuleSet?.rules["゛"]?["ば"] == "ぱ")
        #expect(hira.combineRuleSet?.rules["゛"]?["づ"] == "っ")

        let kata = LanguageDefinitions.katakana.makeDefinition().settings
        #expect(kata.combineRuleSet?.rules["゛"]?["バ"] == "パ")
        #expect(kata.combineRuleSet?.rules["゛"]?["ヅ"] == "ッ")
    }

    @Test func katakanaLocaleIsBcp47() {
        // The registry key stays unique, but the locale tag must be valid BCP-47.
        #expect(LanguageDefinitions.katakana.id == "ja_JP_katakana")
        #expect(LanguageDefinitions.katakana.localeIdentifier == "ja_JP")
        #expect(LanguageDefinitions.katakana.makeDefinition().localeIdentifier == "ja_JP")
    }
}

// MARK: - Supporting Type Tests

struct SupportingTypeTests {
    @Test func composeRuleSetCodable() throws {
        let rules = ComposeRuleSet(rules: [
            "¨": ["a": "ä", "o": "ö", "u": "ü"],
            "´": ["a": "á", "e": "é"],
        ])
        let data = try JSONEncoder().encode(rules)
        let decoded = try JSONDecoder().decode(ComposeRuleSet.self, from: data)
        #expect(decoded == rules)
    }

    @Test func modeNamesConstants() {
        #expect(ModeNames.main == "main")
        #expect(ModeNames.shifted == "shifted")
        #expect(ModeNames.capsLock == "capsLock")
        #expect(ModeNames.numeric == "numeric")
        #expect(ModeNames.symbols == "symbols")
        #expect(ModeNames.emoji == "emoji")
    }
}
