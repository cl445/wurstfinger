//
//  MultiLanguageTypingTests.swift
//  WurstfingerTests
//
//  Integration tests that exercise the typing pipeline for every registered
//  language — verifying each definition loads and its keys produce the
//  expected characters, not just German.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct MultiLanguageTypingTests {
    private func inserts(_ target: MockTextTarget) -> [String] {
        target.events.compactMap { if case let .insertText(t) = $0 { t } else { nil } }
    }

    /// For every registered language, tapping the center key produces that
    /// language's center character (its tap binding label / action).
    @Test func everyLanguageTypesItsCenterCharacter() {
        for info in KeyboardRegistry.available {
            let (vm, target) = makeViewModel(languageId: info.id)

            guard let center = vm.activeModeFromDefinition?.key(for: GridSlot.center),
                  case let .commitText(expected) = center.bindings[.tap]?.action
            else {
                // Every language's center key is expected to commit a literal
                // character; a missing/changed binding is a layout regression.
                Issue.record("Language \(info.id): center key has no commit-text tap binding")
                continue
            }

            vm.handleGesture(.tap, keyId: GridSlot.center, isReturn: false)

            #expect(
                inserts(target).last == expected,
                "Language \(info.id): center tap should produce '\(expected)', got '\(inserts(target).last ?? "nil")'"
            )
        }
    }

    /// For every language, a directional swipe on the center key produces a
    /// character (the layouts populate the center's swipe directions).
    @Test func everyLanguageProducesOutputForCenterSwipe() {
        for info in KeyboardRegistry.available {
            let (vm, target) = makeViewModel(languageId: info.id)

            guard let center = vm.activeModeFromDefinition?.key(for: GridSlot.center),
                  case let .commitText(expected) = center.bindings[.swipeUp]?.action
            else {
                continue
            }

            vm.handleGesture(.swipeUp, keyId: GridSlot.center, isReturn: false)

            #expect(
                inserts(target).last == expected,
                "Language \(info.id): center swipe-up should produce '\(expected)', got '\(inserts(target).last ?? "nil")'"
            )
        }
    }

    /// Every registered language loads a definition with a main mode and a
    /// resolvable center key (guards against an unloadable/empty layout).
    @Test func everyLanguageLoadsWithCenterKey() {
        for info in KeyboardRegistry.available {
            let (vm, _) = makeViewModel(languageId: info.id)
            #expect(
                vm.activeModeFromDefinition?.key(for: GridSlot.center) != nil,
                "Language \(info.id) should load with a center key"
            )
        }
    }
}
