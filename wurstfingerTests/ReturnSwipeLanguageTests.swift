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
    /// uppercase version "H" (letter overrides auto-generate uppercase return actions).
    @Test func frenchReturnSwipeUpOnCenterKeyProducesUppercaseH() {
        let (vm, target) = makeViewModel(languageId: "fr_FR")

        vm.handleGesture(.swipeUp, keyId: GridSlot.center, isReturn: true)

        let inserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
        #expect(
            inserts.last == "H",
            "French return swipe up on center key should produce H (uppercase), got \(inserts.last ?? "nil")"
        )
    }

    /// Regression guard: for every language and every letter key, the return
    /// swipe must produce the uppercased version of the plain swipe. Where
    /// uppercasing is the identity (caseless scripts) the factory must not
    /// synthesize a return action at all — only an explicit `returnOverrides`
    /// entry may set one there, and it must differ from the plain swipe (Hebrew
    /// final forms כ → ך, Thai ท → ฿, kana や → ゃ). A return action that repeats
    /// its own swipe is a silent no-op and hides a missing override.
    @Test func letterKeyReturnSwipesMatchUppercasedSwipeForAllLanguages() {
        let swipeGestures = GestureType.allCases.filter(\.isSwipe)

        for info in KeyboardRegistry.available {
            guard let definition = KeyboardRegistry.load(id: info.id) else {
                Issue.record("Failed to load definition for \(info.id)")
                continue
            }
            guard let mainMode = definition.mode(ModeNames.main) else {
                Issue.record("No main mode for \(info.id)")
                continue
            }
            let locale = definition.locale

            for slotId in GridSlot.allSlots.flatMap(\.self) {
                guard let key = mainMode.key(for: slotId) else {
                    Issue.record("[\(info.id)] no key for slot \(slotId)")
                    continue
                }
                for gesture in swipeGestures {
                    // Only letter outputs that carry a return action.
                    guard let binding = key.bindings[gesture],
                          case let .commitText(swipeText) = binding.action,
                          swipeText.first?.isLetter == true,
                          case let .commitText(returnText)? = binding.returnAction
                    else { continue }

                    // keyboardUppercased, not uppercased: ß maps to ẞ, matching
                    // the factory that generated the return action.
                    let expected = swipeText.keyboardUppercased(with: locale)
                    if expected == swipeText {
                        #expect(
                            returnText != swipeText,
                            "[\(info.id)] \(slotId) \(gesture): return swipe silently repeats '\(swipeText)'"
                        )
                    } else {
                        #expect(
                            returnText == expected,
                            "[\(info.id)] \(slotId) \(gesture): expected '\(expected)', got '\(returnText)'"
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Hebrew Final Letters

/// The Hebrew layout must be able to produce all five final letters
/// (ך ם ן ף ץ). Following the MessagEase convention, a return swipe on a
/// base letter produces its final form; ן and ם additionally keep their
/// dedicated directional swipes.
@Suite(.serialized)
struct HebrewFinalLetterTests {
    static let hebrew = LanguageDefinitions.hebrew.makeDefinition()

    @Test func returnSwipeBindingsProduceFinalForms() throws {
        let main = try #require(Self.hebrew.modes[ModeNames.main])
        let center = try #require(main.keys[GridSlot.center])
        let topRight = try #require(main.keys[GridSlot.topRight])

        // Base letters stay on the regular swipe…
        #expect(center.bindings[.swipeDownLeft]?.action == .commitText("כ"))
        #expect(center.bindings[.swipeUpRight]?.action == .commitText("פ"))
        #expect(center.bindings[.swipeDown]?.action == .commitText("נ"))
        #expect(topRight.bindings[.swipeDownLeft]?.action == .commitText("צ"))

        // …while the return swipe yields the final form.
        #expect(center.bindings[.swipeDownLeft]?.returnAction == .commitText("ך"))
        #expect(center.bindings[.swipeUpRight]?.returnAction == .commitText("ף"))
        #expect(center.bindings[.swipeDown]?.returnAction == .commitText("ן"))
        #expect(topRight.bindings[.swipeDownLeft]?.returnAction == .commitText("ץ"))
    }

    @Test func dedicatedSwipesForFinalNunAndMemArePreserved() throws {
        let main = try #require(Self.hebrew.modes[ModeNames.main])
        #expect(main.keys[GridSlot.topLeft]?.bindings[.swipeDownRight]?.action == .commitText("ן"))
        #expect(main.keys[GridSlot.midLeft]?.bindings[.swipeRight]?.action == .commitText("ם"))
    }

    @Test func allFiveFinalLettersAreTypableThroughThePipeline() {
        let (vm, target) = makeViewModel(languageId: "he_IL")

        vm.handleGesture(.swipeDownLeft, keyId: GridSlot.center, isReturn: true) // ך
        vm.handleGesture(.swipeRight, keyId: GridSlot.midLeft, isReturn: false) // ם
        vm.handleGesture(.swipeDown, keyId: GridSlot.center, isReturn: true) // ן
        vm.handleGesture(.swipeUpRight, keyId: GridSlot.center, isReturn: true) // ף
        vm.handleGesture(.swipeDownLeft, keyId: GridSlot.topRight, isReturn: true) // ץ

        let inserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
        #expect(inserts == ["ך", "ם", "ן", "ף", "ץ"])
    }

    @Test func returnSwipeOverridesDoNotChangeRegularSwipeOutput() {
        let (vm, target) = makeViewModel(languageId: "he_IL")

        vm.handleGesture(.swipeDownLeft, keyId: GridSlot.center, isReturn: false) // כ
        vm.handleGesture(.swipeUpRight, keyId: GridSlot.center, isReturn: false) // פ
        vm.handleGesture(.swipeDownLeft, keyId: GridSlot.topRight, isReturn: false) // צ

        let inserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
        #expect(inserts == ["כ", "פ", "צ"])
    }
}
