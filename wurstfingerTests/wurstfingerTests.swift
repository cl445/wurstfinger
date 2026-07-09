//
//  wurstfingerTests.swift
//  wurstfingerTests
//
//  Created by Claas Flint on 24.10.25.
//
//  Tests for behavior not covered by ViewModelPipelineTests:
//  ComposeEngine, haptic persistence, GestureFeatures, and
//  apostrophe/compose regression tests against the pipeline API.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct wurstfingerTests {
    // MARK: - ComposeEngine Tests

    @Test func composeEngineProducesReplacement() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "¨") == "ä")
        #expect(ComposeEngine.compose(previous: "l", trigger: "!") == "ł")
        #expect(ComposeEngine.compose(previous: "x", trigger: "~") == nil)
    }

    @Test func acuteComposeKeyProducesAccentedCharacters() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "´") == "á")
        #expect(ComposeEngine.compose(previous: "e", trigger: "´") == "é")
        #expect(ComposeEngine.compose(previous: "i", trigger: "´") == "í")
        #expect(ComposeEngine.compose(previous: "o", trigger: "´") == "ó")
        #expect(ComposeEngine.compose(previous: "u", trigger: "´") == "ú")
        #expect(ComposeEngine.compose(previous: "n", trigger: "´") == "ń")
    }

    @Test func graveComposeKeyProducesAccentedCharacters() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "ˋ") == "à")
        #expect(ComposeEngine.compose(previous: "e", trigger: "ˋ") == "è")
        #expect(ComposeEngine.compose(previous: "i", trigger: "ˋ") == "ì")
        #expect(ComposeEngine.compose(previous: "o", trigger: "ˋ") == "ò")
        #expect(ComposeEngine.compose(previous: "u", trigger: "ˋ") == "ù")
    }

    @Test func apostropheDoesNotComposeAccentedCharacters() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "'") == nil)
        #expect(ComposeEngine.compose(previous: "e", trigger: "'") == nil)
        #expect(ComposeEngine.compose(previous: "o", trigger: "'") == nil)
    }

    @Test func backtickDoesNotComposeAccentedCharacters() {
        #expect(ComposeEngine.compose(previous: "a", trigger: "`") == nil)
        #expect(ComposeEngine.compose(previous: "e", trigger: "`") == nil)
        #expect(ComposeEngine.compose(previous: "o", trigger: "`") == nil)
    }

    // MARK: - ComposeEngine Determinism Tests

    @Test func accentCycleOrderIsDeterministic() {
        let runs = (0 ..< 5).map { _ in
            ComposeEngine.cycleAccent(for: "a")
        }
        for run in runs {
            #expect(run == runs[0], "Accent cycle should be deterministic across calls")
        }
    }

    @Test func numberCycleOrderIsDeterministic() {
        let runs = (0 ..< 5).map { _ in
            ComposeEngine.cycleAccent(for: "1")
        }
        #expect(runs[0] != nil, "cycleAccent should return a value for '1'")
        for run in runs {
            #expect(run == runs[0], "Number cycle should be deterministic across calls")
        }
    }

    @Test func accentCycleRoundTripsBackToBase() {
        var current = "a"
        var visited: [String] = [current]

        for _ in 0 ..< 50 {
            guard let next = ComposeEngine.cycleAccent(for: current) else { break }
            if next == "a" {
                break
            }
            #expect(!visited.contains(next), "Cycle should not revisit '\(next)' — would loop forever. Visited: \(visited)")
            current = next
            visited.append(current)
        }

        #expect(visited.count > 1, "Should have at least one accent variant for 'a'")
        let lastStep = ComposeEngine.cycleAccent(for: current)
        #expect(lastStep == "a", "Last variant '\(current)' should cycle back to 'a', got '\(lastStep ?? "nil")'. Full cycle: \(visited)")
    }

    // MARK: - GestureFeatures.empty Tests

    @Test func gestureFeatureEmptyHasSensibleDefaults() {
        let empty = GestureFeatures.empty()

        #expect(empty.pathLength == 0)
        #expect(empty.chordLength == 0)
        #expect(empty.maxDisplacement == 0)
        #expect(empty.returnRatio == 1)
        #expect(empty.isTap == true)
        #expect(empty.isReturn == false)
        #expect(empty.isCircular == false)
    }

    @Test func gestureFeatureExtractHandlesEmptyPoints() {
        let empty = GestureFeatures.extract(from: [])
        #expect(empty.pathLength == 0)
        #expect(empty.isTap == true)

        let single = GestureFeatures.extract(from: [.zero])
        #expect(single.pathLength == 0)
        #expect(single.isTap == true)
    }

    // MARK: - Haptic Persistence Tests

    @Test @MainActor func hapticIntensitiesPersistToDefaults() {
        let defaults = InMemoryUserDefaults()

        let viewModel = KeyboardViewModel(userDefaults: defaults)
        viewModel.hapticIntensityTap = 0.8
        viewModel.hapticIntensityDrag = 1.1

        #expect(defaults.double(forKey: KeyboardViewModel.hapticTapIntensityKey) == 0.8)
        let dragDefault = defaults.double(forKey: KeyboardViewModel.hapticDragIntensityKey)
        #expect(abs(dragDefault - 1.0) < 0.0001)
    }

    @Test @MainActor func previewViewModelDoesNotPersist() {
        let defaults = InMemoryUserDefaults()

        defaults.set(0.3, forKey: KeyboardViewModel.hapticTapIntensityKey)

        let viewModel = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
        #expect(abs(viewModel.hapticIntensityTap - 0.3) < 0.0001)

        viewModel.hapticIntensityTap = 0.9
        let persistedTap = defaults.double(forKey: KeyboardViewModel.hapticTapIntensityKey)
        #expect(abs(persistedTap - 0.3) < 0.0001)
    }

    @Test @MainActor func hapticIntensityClampsWithinBounds() {
        let defaults = InMemoryUserDefaults()

        let viewModel = KeyboardViewModel(userDefaults: defaults)

        viewModel.hapticIntensityTap = -0.5
        viewModel.hapticIntensityDrag = 2.0

        #expect(abs(viewModel.hapticIntensityTap - 0.0) < 0.0001)
        #expect(abs(viewModel.hapticIntensityDrag - 1.0) < 0.0001)
        let storedDrag = defaults.double(forKey: KeyboardViewModel.hapticDragIntensityKey)
        #expect(abs(storedDrag - 1.0) < 0.0001)
    }

    // MARK: - Apostrophe / Compose Regression Tests (#89)

    @Test func apostropheIsNeverAComposeTriggerInDefinition() {
        // Verify no binding in any definition uses apostrophe (') as a compose trigger.
        // Composition uses ´ (U+00B4 acute accent), not ' (U+0027 apostrophe).
        for info in KeyboardRegistry.available {
            guard let definition = KeyboardRegistry.load(id: info.id) else { continue }
            for (modeName, mode) in definition.modes {
                for (keyId, keyConfig) in mode.keys {
                    for (gesture, binding) in keyConfig.bindings {
                        if case let .compose(trigger) = binding.action {
                            #expect(
                                trigger != "'",
                                "Apostrophe must not be a compose trigger (found in \(info.id), mode \(modeName), key \(keyId), gesture \(gesture))"
                            )
                        }
                    }
                }
            }
        }
    }

    @Test func backtickIsNeverAComposeTriggerInDefinition() {
        // Verify no binding uses backtick (`) as a compose trigger.
        // Composition uses ˋ (U+02CB modifier letter grave accent), not ` (U+0060).
        for info in KeyboardRegistry.available {
            guard let definition = KeyboardRegistry.load(id: info.id) else { continue }
            for (modeName, mode) in definition.modes {
                for (keyId, keyConfig) in mode.keys {
                    for (gesture, binding) in keyConfig.bindings {
                        if case let .compose(trigger) = binding.action {
                            #expect(
                                trigger != "`",
                                "Backtick must not be a compose trigger (found in \(info.id), mode \(modeName), key \(keyId), gesture \(gesture))"
                            )
                        }
                    }
                }
            }
        }
    }

    @Test func apostropheReturnSwipeInsertsTypographicQuote() {
        // Return swipe on N-key upRight in German should insert right single
        // quotation mark (U+2019), not trigger compose mode.
        let (vm, target) = makeViewModel(languageId: "de_DE")

        // In German, topCenter swipeUpRight is ´ (compose), return swipe is \u{2019}
        vm.handleGesture(.swipeUpRight, keyId: GridSlot.topCenter, isReturn: true)

        let inserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
        #expect(inserts.last == "\u{2019}", "Return swipe should insert right single quotation mark, got \(inserts.last ?? "nil")")
    }

    // MARK: - Return Swipe Typographic Variants (German layout)

    @Test func returnSwipesProduceTypographicVariants() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        func trigger(keyId: String, gesture: GestureType, expected: String) {
            target.events.removeAll()
            vm.handleGesture(gesture, keyId: keyId, isReturn: true)
            let inserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
            #expect(inserts.last == expected, "\(keyId) \(gesture) return: expected '\(expected)', got '\(inserts.last ?? "nil")'")
        }

        // ! → ¡ (topCenter, swipeRight)
        trigger(keyId: GridSlot.topCenter, gesture: .swipeRight, expected: "¡")
        // / → – (topCenter, swipeDownLeft)
        trigger(keyId: GridSlot.topCenter, gesture: .swipeDownLeft, expected: "–")
        // ? → ¿ (topRight, swipeLeft)
        trigger(keyId: GridSlot.topRight, gesture: .swipeLeft, expected: "¿")
        // - → ÷ (topLeft, swipeRight)
        trigger(keyId: GridSlot.topLeft, gesture: .swipeRight, expected: "÷")
        // . → … (bottomCenter, swipeDown)
        trigger(keyId: GridSlot.bottomCenter, gesture: .swipeDown, expected: "…")
        // < → ‹ (bottomLeft, swipeLeft)
        trigger(keyId: GridSlot.bottomLeft, gesture: .swipeLeft, expected: "‹")
        // * → † (bottomLeft, swipeRight)
        trigger(keyId: GridSlot.bottomLeft, gesture: .swipeRight, expected: "†")
        // > → › (bottomRight, swipeRight)
        trigger(keyId: GridSlot.bottomRight, gesture: .swipeRight, expected: "›")
        // % → ‰ (midLeft, swipeUpRight)
        trigger(keyId: GridSlot.midLeft, gesture: .swipeUpRight, expected: "‰")
        // + → × (topCenter, swipeLeft)
        trigger(keyId: GridSlot.topCenter, gesture: .swipeLeft, expected: "×")
    }

    // MARK: - Compose via Pipeline

    @Test func composeSwipeTriggersCompositionThroughPipeline() {
        // In German, topCenter swipeUpRight is ´ (compose trigger).
        // After typing "a", swiping ´ should produce "á" via the compose middleware.
        let (vm, target) = makeViewModel(languageId: "de_DE")

        // Type "a" first
        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false)
        #expect(target.events.contains(.insertText("a")))

        // Now trigger compose ´
        vm.handleGesture(.swipeUpRight, keyId: GridSlot.topCenter, isReturn: false)

        // The compose middleware should have: deleted "a", inserted "á"
        let inserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
        #expect(inserts.last == "á", "Compose should produce á, got \(inserts.last ?? "nil")")
    }

    @Test func composeSwipeWorksInShiftedMode() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        // Type "A" via shifted mode
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.shifted)
        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false)

        let inserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
        #expect(inserts.contains("A"))

        // Compose triggers should work from main mode (auto-transitioned back)
        vm.handleGesture(.swipeUpRight, keyId: GridSlot.topCenter, isReturn: false)

        let allInserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
        #expect(allInserts.last == "Á", "Compose should produce Á after uppercase A, got \(allInserts.last ?? "nil")")
    }

    @Test func composeAsFirstActionInShiftedModeConsumesShift() {
        // Auto-capitalization is off here (default in makeViewModel), so the
        // shift release must come from the mode transition itself, not from
        // an auto-cap side effect.
        let (vm, target) = makeViewModel(languageId: "de_DE")

        // Type "a", then engage shift manually.
        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false)
        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.shifted)

        // Compose as the FIRST action in shifted mode: ´ + a → á.
        vm.handleGesture(.swipeUpRight, keyId: GridSlot.topCenter, isReturn: false)

        let inserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
        #expect(inserts.last == "á", "Compose should produce á, got \(inserts.last ?? "nil")")
        #expect(
            vm.activeModeName == ModeNames.main,
            "A composed letter must consume the one-shot shift exactly like a plain letter"
        )
    }

    @Test func composeTriggerWithoutRuleKeepsShiftEngaged() {
        // Deliberate policy: when the compose gesture finds no rule (no
        // preceding character) it merely commits the trigger character —
        // a symbol, not a letter. Per the iOS-style one-shot shift
        // semantics, symbols must NOT consume shift, so the keyboard stays
        // shifted until an actual letter is produced.
        let (vm, target) = makeViewModel(languageId: "de_DE")

        vm.handleGesture(.swipeUp, keyId: GridSlot.midRight, isReturn: false)
        #expect(vm.activeModeName == ModeNames.shifted)

        // Empty document: ´ has nothing to compose with and commits "´".
        vm.handleGesture(.swipeUpRight, keyId: GridSlot.topCenter, isReturn: false)

        let inserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
        #expect(inserts.last == "´", "Trigger should commit literally, got \(inserts.last ?? "nil")")
        #expect(
            vm.activeModeName == ModeNames.shifted,
            "A committed trigger character is a symbol and must not consume shift"
        )
    }

    // MARK: - Asterisk Regression (Vietnamese tone rules must not be global)

    @Test func asteriskInsertsLiterallyAfterVowel() {
        // Regression: `a` + `*` used to compose the Vietnamese nặng tone (ạ)
        // on every layout because the tone table lived in the global rules.
        let (vm, target) = makeViewModel(languageId: "de_DE")

        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false) // a
        vm.handleGesture(.swipeRight, keyId: GridSlot.bottomLeft, isReturn: false) // *

        #expect(!target.events.contains(.deleteBackward), "Asterisk must not rewrite the preceding vowel")
        let inserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
        #expect(inserts == ["a", "*"], "Expected literal asterisk after 'a', got \(inserts)")
    }

    @Test func degreeComposeStillWorksAfterVowel() {
        // Guards the neighboring compose binding: a + ° (bottomRight
        // swipeUpRight) still composes å.
        let (vm, target) = makeViewModel(languageId: "de_DE")

        vm.handleGesture(.tap, keyId: GridSlot.topLeft, isReturn: false) // a
        vm.handleGesture(.swipeUpRight, keyId: GridSlot.bottomRight, isReturn: false) // °

        let inserts = target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
        #expect(inserts.last == "å", "Compose should produce å, got \(inserts.last ?? "nil")")
    }
}
