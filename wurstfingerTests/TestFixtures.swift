//
//  TestFixtures.swift
//  WurstfingerTests
//
//  Fixture builders and call conveniences that only the test suite uses.
//  They live here rather than in `wurstfingerKeyboard/` so they stay out of
//  the keyboard extension's binary — and so nobody mistakes them for a
//  supported production path (the definition layer builds `KeyConfig`s in
//  `GridKeyboardFactory`, not through `KeyConfig.letter`).
//

import Foundation
@testable import WurstfingerApp

extension KeyConfig {
    /// Creates a letter key. Category is automatically derived from the action.
    static func letter(
        _ id: String,
        tap: String,
        swipes: [GestureType: String] = [:],
        returnSwipes: [GestureType: String] = [:],
        composeSwipes: [GestureType: (trigger: String, label: String)] = [:]
    ) -> KeyConfig {
        var bindings: [GestureType: KeyBinding] = [:]
        bindings[.tap] = KeyBinding(
            label: tap, action: .commitText(tap),
            category: nil, returnAction: nil, accessibilityLabel: nil
        )
        for (gesture, char) in swipes {
            bindings[gesture] = KeyBinding(
                label: char, action: .commitText(char), category: nil,
                returnAction: returnSwipes[gesture].map { .commitText($0) },
                accessibilityLabel: nil
            )
        }
        for (gesture, compose) in composeSwipes {
            bindings[gesture] = KeyBinding(
                label: compose.label, action: .compose(trigger: compose.trigger),
                category: .compose, returnAction: nil, accessibilityLabel: nil
            )
        }
        return KeyConfig(
            id: id, bindings: bindings, swipeMode: .eightWay,
            slideType: .none, style: .primary, tapCycleActions: nil
        )
    }
}

extension LanguageConfig {
    static let german = LanguageConfig(
        id: "de_DE", name: "Deutsch", locale: Locale(identifier: "de_DE")
    )

    static let russian = LanguageConfig(
        id: "ru_RU", name: "Русский", locale: Locale(identifier: "ru_RU")
    )
}

extension GestureResolverChain {
    /// Convenience that returns the resolved `KeyAction` directly, or
    /// `.none` if nothing matched.
    func resolveAction(keyId: String, gesture: GestureType, in mode: KeyboardMode) -> KeyAction {
        resolve(keyId: keyId, gesture: gesture, in: mode)?.action ?? .none
    }
}

extension ComposeEngine {
    static func compose(previous: String, trigger: String) -> String? {
        shared.compose(previous: previous, trigger: trigger)
    }

    static func cycleAccent(for character: String) -> String? {
        shared.cycleAccent(for: character)
    }
}

/// Language ids whose script is caseless. These layouts have no shift
/// affordance (no shifted/capsLock modes, no shift binding) and
/// auto-capitalization disabled in their definition settings.
enum CaselessLanguages {
    static let ids: Set<String> = ["he_IL", "ar", "fa_IR", "ur", "th_TH", "hi_IN", "ja_JP", "ja_JP_katakana", "ko_KR"]
}

/// Creates a KeyboardViewModel wired to a MockTextTarget for testing.
func makeViewModel(
    languageId: String = "de_DE",
    advanceToNextInputMode: @escaping () -> Void = {},
    dismissKeyboard: @escaping () -> Void = {}
) -> (KeyboardViewModel, MockTextTarget) {
    let defaults = InMemoryUserDefaults()
    let vm = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
    let target = MockTextTarget()
    vm.bindTextInputTarget(target)
    vm.bindViewControllerActions(
        advanceToNextInputMode: advanceToNextInputMode,
        dismissKeyboard: dismissKeyboard
    )
    vm.loadDefinition(for: languageId)
    return (vm, target)
}
