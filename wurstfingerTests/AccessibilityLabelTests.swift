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
}
