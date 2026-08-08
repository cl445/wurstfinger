//
//  AccessibilityLabelTests.swift
//  WurstfingerTests
//
//  Ensures every key in every mode of every registered language exposes a
//  usable VoiceOver label — i.e. a tap binding with a non-empty label, so the
//  rendered key never falls back to reading the raw slot id ("topLeft", …).
//
//  Complements LayoutValidationTests.allGridKeyTapBindingsAreNonEmpty, which
//  only checks grid keys in the main mode.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct AccessibilityLabelTests {
    private var definitions: [KeyboardDefinition] {
        KeyboardRegistry.available.compactMap { KeyboardRegistry.load(id: $0.id) }
    }

    /// Mirrors KeyView's accessibility-label resolution
    /// (custom accessibility label → tap label → slot id fallback).
    private func accessibilityLabel(for key: KeyConfig) -> String {
        if let tap = key.bindings[.tap] {
            return tap.accessibilityLabel ?? tap.label
        }
        return key.id
    }

    @Test func definitionsLoad() {
        #expect(!definitions.isEmpty, "Expected registered languages to load")
    }

    @Test func everyKeyHasATapBinding() {
        for def in definitions {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys {
                    #expect(
                        key.bindings[.tap] != nil,
                        "\(def.id)/\(modeName)/\(keyId) has no .tap binding — VoiceOver would read the raw slot id"
                    )
                }
            }
        }
    }

    @Test func everyKeyHasANonEmptyAccessibilityLabel() {
        for def in definitions {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys {
                    let label = accessibilityLabel(for: key)
                    #expect(
                        !label.isEmpty,
                        "\(def.id)/\(modeName)/\(keyId) resolves to an empty accessibility label"
                    )
                }
            }
        }
    }

    @Test func accessibilityLabelNeverFallsBackToSlotId() {
        let slotIds = Set(GridSlot.allSlots.flatMap(\.self))
        for def in definitions {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys where slotIds.contains(keyId) {
                    let label = accessibilityLabel(for: key)
                    #expect(
                        label != keyId,
                        "\(def.id)/\(modeName)/\(keyId) accessibility label is the raw slot id"
                    )
                }
            }
        }
    }

    // MARK: - Operability without gestures

    /// VoiceOver activates a key by synthesizing a tap, so a key whose tap is
    /// inert is unreachable unless it declares a substitute gesture. Also the
    /// guard for the derived layers: shifted/capsLock keys are made by copying,
    /// so a copy site that drops the declaration fails here.
    @Test func everyKeyIsOperableWithoutGestures() {
        for def in definitions {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys {
                    let tapAction: KeyAction = key.bindings[.tap]?.action ?? .none
                    #expect(
                        tapAction != .none || key.accessibilityActivationOverride != nil,
                        "\(def.id)/\(modeName)/\(keyId) has an inert tap and no accessibility activation"
                    )
                }
            }
        }
    }

    @Test func globeActivationAdvancesTheInputMode() {
        for def in definitions {
            for (modeName, mode) in def.modes {
                guard let globe = mode.keys[UtilitySlot.globe] else { continue }
                #expect(
                    globe.accessibilityActivationOverride == .swipeLeft,
                    "\(def.id)/\(modeName) globe does not route activation to the input-mode switch"
                )
                #expect(globe.bindings[.swipeLeft]?.action == .advanceToNextInputMode)
            }
        }
    }

    /// Reachability is by name, not by gesture: bindings sharing a label
    /// collapse into one rotor entry, so the entry must dispatch the same
    /// action for every gesture that folded into it.
    @Test func everyLabelledNonTapBindingIsReachableAsAnAction() {
        for def in definitions {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys {
                    let offered = Dictionary(
                        key.accessibilityActions.map { ($0.name, $0.gesture) },
                        uniquingKeysWith: { first, _ in first }
                    )
                    for (gesture, binding) in key.bindings
                        where gesture != .tap && binding.action != .none {
                        guard let label = binding.accessibilityLabel, !label.isEmpty else { continue }
                        guard gesture != key.accessibilityActivationOverride else { continue }
                        let origin = "\(def.id)/\(modeName)/\(keyId) \(gesture)"
                        guard let offeredGesture = offered[label] else {
                            Issue.record("\(origin) is named \"\(label)\" but unreachable")
                            continue
                        }
                        #expect(
                            key.bindings[offeredGesture]?.action == binding.action,
                            "\(origin) folds into \"\(label)\", which dispatches a different action"
                        )
                    }
                }
            }
        }
    }

    /// Cut-all is bound to both circle directions under one name; two
    /// identical rotor entries read as a bug.
    @Test func accessibilityActionNamesAreUnique() {
        for def in definitions {
            for (modeName, mode) in def.modes {
                for (keyId, key) in mode.keys {
                    let names = key.accessibilityActions.map(\.name)
                    #expect(
                        Set(names).count == names.count,
                        "\(def.id)/\(modeName)/\(keyId) offers duplicate action names: \(names)"
                    )
                }
            }
        }
    }

    /// End to end through the real resolver chain and pipeline: the gesture the
    /// globe declares has to actually reach the input-mode switch.
    @Test func globeActivationReachesTheInputModeSwitch() throws {
        var advanced = 0
        let (viewModel, _) = makeViewModel(advanceToNextInputMode: { advanced += 1 })
        let globe = try #require(viewModel.activeModeFromDefinition?.key(for: UtilitySlot.globe))
        let gesture = try #require(globe.accessibilityActivationOverride)
        viewModel.handleGesture(gesture, keyId: UtilitySlot.globe, isReturn: false)
        #expect(advanced == 1)
    }
}
