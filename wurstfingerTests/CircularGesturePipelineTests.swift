//
//  CircularGesturePipelineTests.swift
//  WurstfingerTests
//
//  Tests for KeyboardViewModel's circular-gesture handling (handleCircular /
//  tryCircularUppercase / dispatchBinding), driven end-to-end through the
//  data-driven pipeline via makeViewModel + MockTextTarget.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct CircularGesturePipelineTests {
    /// Path 2: a plain letter key with no explicit circular binding inserts
    /// the uppercase center character.
    @Test func clockwiseOnLetterKeyInsertsUppercase() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        guard let key = vm.activeModeFromDefinition?.key(for: GridSlot.topLeft),
              case let .commitText(letter) = key.bindings[.tap]?.action,
              key.bindings[.circularClockwise] == nil
        else {
            Issue.record("Expected topLeft to be a plain letter key without an explicit circular binding")
            return
        }

        vm.handleGesture(.circularClockwise, keyId: GridSlot.topLeft, isReturn: false)

        // Match production: tryCircularUppercase uppercases with the pipeline
        // locale, so locale-sensitive letters can't drift from the assertion.
        #expect(target.events.contains(.insertText(letter.uppercased(with: vm.pipelineLocale ?? .current))))
    }

    /// Counterclockwise uses the same uppercase fallback (exercises the
    /// opposite-direction computation too).
    @Test func counterclockwiseOnLetterKeyInsertsUppercase() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        guard let key = vm.activeModeFromDefinition?.key(for: GridSlot.topLeft),
              case let .commitText(letter) = key.bindings[.tap]?.action
        else {
            Issue.record("Expected topLeft to be a letter key")
            return
        }

        vm.handleGesture(.circularCounterclockwise, keyId: GridSlot.topLeft, isReturn: false)

        // Match production: tryCircularUppercase uppercases with the pipeline
        // locale, so locale-sensitive letters can't drift from the assertion.
        #expect(target.events.contains(.insertText(letter.uppercased(with: vm.pipelineLocale ?? .current))))
    }

    /// Path 1: numeric layer keys carry an explicit circular binding
    /// (superscripts / math symbols) which takes precedence over uppercasing.
    @Test func circularInNumericModeDispatchesExplicitBinding() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        vm.handleGesture(.tap, keyId: UtilitySlot.symbols, isReturn: false)
        #expect(vm.activeModeName == ModeNames.numeric)

        guard let key = vm.activeModeFromDefinition?.key(for: GridSlot.topLeft),
              case let .commitText(symbol) = key.bindings[.circularClockwise]?.action
        else {
            Issue.record("Expected numeric topLeft to carry an explicit circular binding")
            return
        }

        vm.handleGesture(.circularClockwise, keyId: GridSlot.topLeft, isReturn: false)

        #expect(target.events.contains(.insertText(symbol)))
    }

    /// An unknown key id is ignored (guard in handleCircular).
    @Test func circularOnUnknownKeyIsNoop() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        vm.handleGesture(.circularClockwise, keyId: "nonexistent-key", isReturn: false)

        #expect(target.events.isEmpty)
    }

    /// The uppercase fallback must route through `keyboardUppercased` so a
    /// layout with ß on a tap position yields the capital sharp S (ẞ) instead
    /// of the plain-`uppercased` two-letter "SS" expansion — matching the
    /// shifted-layer generation in the definition layer. No shipped layout
    /// carries ß on tap today, so the definition is injected directly.
    @Test func circularOnSharpSKeyInsertsCapitalSharpS() {
        let (vm, target) = makeViewModel(languageId: "de_DE")

        let sharpSKey = KeyConfig(
            id: "sz",
            bindings: [
                .tap: KeyBinding(
                    label: "ß", action: .commitText("ß"), category: .letter,
                    returnAction: nil, accessibilityLabel: nil
                ),
            ],
            swipeMode: .eightWay, slideType: .none,
            style: .primary, tapCycleActions: nil
        )
        let mainMode = KeyboardMode(
            name: ModeNames.main,
            keys: [sharpSKey.id: sharpSKey],
            arrangements: [
                .portrait: GridArrangement(
                    columns: 1,
                    rows: [[KeyPlacement(keyId: sharpSKey.id)]]
                ),
            ],
            autoTransitions: [:]
        )
        vm.currentDefinition = KeyboardDefinition(
            title: "Fixture", id: "fixture", localeIdentifier: "de_DE",
            modes: [ModeNames.main: mainMode], defaultMode: ModeNames.main,
            settings: KeyboardDefinitionSettings(
                autoCapitalize: false, composeRuleOverrides: nil
            )
        )
        vm.activeModeName = ModeNames.main
        vm.currentMode = mainMode
        vm.pipelineLocale = Locale(identifier: "de_DE")
        vm.rebuildResolverChain()
        vm.rebuildPipeline()

        vm.handleGesture(.circularClockwise, keyId: sharpSKey.id, isReturn: false)

        #expect(target.events == [.insertText("ẞ")])
    }
}

// MARK: - Cut-all

/// The clipboard key's circular bindings, asserted on the definition rather
/// than by circling it end-to-end: dispatching cut-all writes to the
/// process-wide `UIPasteboard.general`, which would race the serialized
/// clipboard suite in `AdvancedTextMiddlewareTests`. The cut itself is covered
/// there; what matters here is that both directions reach it.
struct CircularCutAllBindingTests {
    private func symbolsKey(_ vm: KeyboardViewModel) -> KeyConfig? {
        vm.activeModeFromDefinition?.key(for: UtilitySlot.symbols)
    }

    /// Both directions are bound explicitly, so neither relies on
    /// `handleCircular`'s opposite-direction fallback.
    @Test func symbolsKeyBindsBothCircleDirectionsToCutAll() {
        let (vm, _) = makeViewModel(languageId: "de_DE")

        guard let key = symbolsKey(vm) else {
            Issue.record("Expected a symbols key in the main mode")
            return
        }

        #expect(key.bindings[.circularClockwise]?.action == .cutAll)
        #expect(key.bindings[.circularCounterclockwise]?.action == .cutAll)
    }

    /// The numeric layer's back-to-main key shares the same clipboard bindings.
    @Test func numericBackKeyBindsBothCircleDirectionsToCutAll() {
        let (vm, _) = makeViewModel(languageId: "de_DE")

        vm.handleGesture(.tap, keyId: UtilitySlot.symbols, isReturn: false)
        #expect(vm.activeModeName == ModeNames.numeric)

        guard let key = symbolsKey(vm) else {
            Issue.record("Expected a back-to-main key in the numeric mode")
            return
        }

        #expect(key.bindings[.circularClockwise]?.action == .cutAll)
        #expect(key.bindings[.circularCounterclockwise]?.action == .cutAll)
    }

    /// Circling the key must not fall through to its tap action (the mode
    /// switch). Full access is off, so cut-all no-ops before the pasteboard.
    @Test func circleOnSymbolsKeyDoesNotSwitchMode() {
        let (vm, target) = makeViewModel(languageId: "de_DE")
        target.hasFullAccess = false
        target.documentContextBeforeInput = "hallo"

        vm.handleGesture(.circularCounterclockwise, keyId: UtilitySlot.symbols, isReturn: false)

        #expect(vm.activeModeName == ModeNames.main)
        #expect(target.events.isEmpty)
        #expect(target.documentContextBeforeInput == "hallo")
    }
}
