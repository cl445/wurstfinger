//
//  ReturnSwipeLanguageTests.swift
//  wurstfingerTests
//
//  Tests that return swipe overrides on the center key produce the correct
//  uppercased variant for every language, not hardcoded English values.
//

import Foundation
import Testing
@testable import WurstfingerApp

@Suite(.serialized)
struct ReturnSwipeLanguageTests {
    /// French layout: return swipe up on center key (O) should produce the
    /// regular swipe character "h" (no special returnAction is defined for
    /// language-specific directional overrides in the data-driven pipeline).
    @Test func frenchReturnSwipeUpOnCenterKeyProducesH() {
        let (vm, target) = makeViewModel(languageId: "fr_FR")

        vm.handleGesture(.swipeUp, keyId: GridSlot.center, isReturn: true)

        let inserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
        #expect(
            inserts.last == "h",
            "French return swipe up on center key should produce h (regular swipe fallback), got \(inserts.last ?? "nil")"
        )
    }

    /// Regression guard: for every language, the center key's return swipe overrides
    /// for letter bindings should match the uppercased version of the regular swipe output.
    @Test func centerKeyReturnSwipeMatchesUppercasedSwipeForAllLanguages() {
        for info in KeyboardRegistry.available {
            guard let definition = KeyboardRegistry.load(id: info.id) else {
                Issue.record("Failed to load definition for \(info.id)")
                continue
            }
            guard let mainMode = definition.mode(ModeNames.main) else {
                Issue.record("No main mode for \(info.id)")
                continue
            }
            guard let centerKey = mainMode.key(for: GridSlot.center) else {
                Issue.record("No center key for \(info.id)")
                continue
            }

            let locale = definition.locale

            // Check all swipe directions on the center key
            let swipeGestures: [GestureType] = [
                .swipeUp, .swipeDown, .swipeLeft, .swipeRight,
                .swipeUpLeft, .swipeUpRight, .swipeDownLeft, .swipeDownRight,
            ]

            for gesture in swipeGestures {
                guard let binding = centerKey.bindings[gesture] else { continue }

                // Only check letter outputs (commitText with a letter)
                guard case let .commitText(swipeText) = binding.action,
                      swipeText.first?.isLetter == true
                else { continue }

                // Check if there's a return action
                guard let returnAction = binding.returnAction,
                      case let .commitText(returnText) = returnAction
                else { continue }

                let expected = swipeText.uppercased(with: locale)
                #expect(
                    returnText == expected,
                    "[\(info.id)] center key return swipe \(gesture): expected '\(expected)', got '\(returnText)'"
                )
            }
        }
    }
}
