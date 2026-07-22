//
//  KeyboardGridRenderingTests.swift
//  WurstfingerTests
//
//  Tests for ViewModel.currentContext, KeyboardGridView span behavior,
//  and KeyView style-based rendering helpers.
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

// MARK: - currentContext

@Suite(.serialized)
struct KeyboardViewModelContextTests {
    /// Builds a ViewModel with a deterministic utility-column setting. We use an
    /// in-memory UserDefaults so the suite never touches the shared store.
    private func makeViewModel(utilityLeft: Bool) -> KeyboardViewModel {
        let defaults = InMemoryUserDefaults()
        let viewModel = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
        viewModel.utilityColumnLeading = utilityLeft
        return viewModel
    }

    @Test func utilityRightSelectsPortrait() {
        let viewModel = makeViewModel(utilityLeft: false)
        #expect(viewModel.currentContext == .portrait)
    }

    @Test func utilityLeftSelectsPortraitUtilityLeft() {
        let viewModel = makeViewModel(utilityLeft: true)
        #expect(viewModel.currentContext == .portraitUtilityLeft)
    }

    @Test func currentArrangementIsNilWithoutMode() {
        let viewModel = makeViewModel(utilityLeft: false)
        #expect(viewModel.currentMode == nil)
        #expect(viewModel.currentArrangement == nil)
    }

    @Test func currentArrangementUsesContextLookup() {
        // Build a minimal mode with distinct arrangements per context so
        // we can verify currentArrangement chases the right one as the
        // utility-column preference changes.
        let utilityRightArrangement = GridArrangement(
            columns: 1,
            rows: [[KeyPlacement(keyId: "a")]]
        )
        let utilityLeftArrangement = GridArrangement(
            columns: 2,
            rows: [[KeyPlacement(keyId: "a"), KeyPlacement(keyId: "a")]]
        )
        let mode = KeyboardMode(
            name: "test",
            keys: ["a": KeyConfig(
                id: "a",
                bindings: [.tap: KeyBinding(
                    label: "a",
                    action: .commitText("a"),
                    category: nil,
                    returnAction: nil,
                    accessibilityLabel: nil
                )],
                swipeMode: .eightWay,
                slideType: .none,
                style: .primary,
                tapCycleActions: nil
            )],
            arrangements: [
                .portrait: utilityRightArrangement,
                .portraitUtilityLeft: utilityLeftArrangement,
            ],
            autoTransitions: [:]
        )

        let viewModel = makeViewModel(utilityLeft: false)
        viewModel.currentMode = mode
        #expect(viewModel.currentArrangement?.columns == 1)

        viewModel.utilityColumnLeading = true
        #expect(viewModel.currentArrangement?.columns == 2)
    }
}

// MARK: - KeyboardGridView Span Behavior

struct KeyboardGridViewSpanTests {
    @Test func defaultPlacementHasUnitSpan() {
        let placement = KeyPlacement(keyId: "topLeft")
        let span = KeyboardGridView.gridCellSpan(for: placement)
        #expect(span.rows == 1)
        #expect(span.columns == 1)
    }

    @Test func widthMultiplierMapsToColumns() {
        // Space bar in portrait spans 3 columns.
        let placement = KeyPlacement(keyId: "space", widthMultiplier: 3)
        let span = KeyboardGridView.gridCellSpan(for: placement)
        #expect(span.columns == 3)
        #expect(span.rows == 1)
    }

    @Test func heightMultiplierMapsToRows() {
        // Landscape return key spans 2 rows.
        let placement = KeyPlacement(keyId: "return", widthMultiplier: 1, heightMultiplier: 2)
        let span = KeyboardGridView.gridCellSpan(for: placement)
        #expect(span.rows == 2)
        #expect(span.columns == 1)
    }

    @Test func standardArrangementsRoundTripThroughSpan() throws {
        // Sanity: every placement in the standard portrait arrangement
        // produces a non-zero span. Catches accidental regressions where
        // we'd ever return zero or negative values.
        for row in try #require(StandardArrangements.grid3x3[.portrait]?.rows) {
            for placement in row {
                let span = KeyboardGridView.gridCellSpan(for: placement)
                #expect(span.rows >= 1)
                #expect(span.columns >= 1)
            }
        }
    }
}

// MARK: - KeyView Style Rendering

struct KeyViewStyleTests {
    @Test func primaryAndUtilityProduceDifferentFontSizes() {
        // Primary keys are large, utility keys use the utility label size.
        // The exact values don't matter; the test guards against the two
        // styles ever collapsing onto the same rendering path.
        let primary = KeyView.baseFontSize(for: .primary)
        let utility = KeyView.baseFontSize(for: .utility)
        #expect(primary != utility)
    }

    @Test func utilityIsIconOnly() {
        #expect(KeyView.isIconOnly(style: .utility))
        #expect(!KeyView.isIconOnly(style: .primary))
        #expect(!KeyView.isIconOnly(style: .secondary))
        #expect(!KeyView.isIconOnly(style: .spacebar))
        #expect(!KeyView.isIconOnly(style: .accent))
    }

    @Test func primaryLabelFallsBackToKeyId() {
        // A key with no tap binding still has a stable label so it can
        // be debugged in previews.
        let key = KeyConfig(
            id: "midLeft",
            bindings: [:],
            swipeMode: .eightWay,
            slideType: .none,
            style: .primary,
            tapCycleActions: nil
        )
        let view = KeyView(key: key, onGesture: { _, _, _ in }, onTouchDown: {}, metrics: .reference)
        #expect(view.primaryLabel == "midLeft")
    }

    @Test func primaryLabelUsesTapBindingLabel() {
        let key = KeyConfig(
            id: "midLeft",
            bindings: [.tap: KeyBinding(
                label: "d",
                action: .commitText("d"),
                category: nil,
                returnAction: nil,
                accessibilityLabel: nil
            )],
            swipeMode: .eightWay,
            slideType: .none,
            style: .primary,
            tapCycleActions: nil
        )
        let view = KeyView(key: key, onGesture: { _, _, _ in }, onTouchDown: {}, metrics: .reference)
        #expect(view.primaryLabel == "d")
    }

    @Test func accessibilityLabelPrefersExplicitOverride() {
        let key = KeyConfig(
            id: "delete",
            bindings: [.tap: KeyBinding(
                label: "⌫",
                action: .deleteBackward,
                category: nil,
                returnAction: nil,
                accessibilityLabel: "Löschen"
            )],
            swipeMode: .twoWayHorizontal,
            slideType: .delete,
            style: .utility,
            tapCycleActions: nil
        )
        let view = KeyView(key: key, onGesture: { _, _, _ in }, onTouchDown: {}, metrics: .reference)
        #expect(view.accessibilityLabel == "Löschen")
    }
}
