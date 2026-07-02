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

    /// Regression guard: for every language, the center key's return swipe overrides
    /// for letter bindings should match the uppercased version of the regular swipe output.
    /// Caseless letters (uppercasing is the identity) are exempt — there the return
    /// swipe may carry an explicit `returnOverrides` output instead (e.g. Hebrew
    /// final forms: return swipe on כ produces ך).
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

                // Caseless letters have no meaningful uppercase — explicit
                // return overrides (final forms) are legitimate there.
                guard expected != swipeText else { continue }
                #expect(
                    returnText == expected,
                    "[\(info.id)] center key return swipe \(gesture): expected '\(expected)', got '\(returnText)'"
                )
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
