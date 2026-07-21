//
//  KeyboardLayoutMetricsTests.swift
//  wurstfingerTests
//
//  Tests for the point-anchored layout metrics resolver: aspect-ratio
//  exactness, the total-height formula, orientation invariance, and the
//  width/height fit-clamps (which must shrink proportionally and never
//  persist anything).
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct KeyboardLayoutMetricsTests {
    private let hChrome = KeyboardLayoutMetrics.horizontalChrome(columns: 4)
    private let vChrome = KeyboardLayoutMetrics.verticalChrome(rows: 4)

    // MARK: - Aspect exactness

    @Test(arguments: [
        (wish: CGFloat(270), aspect: CGFloat(1.0)),
        (wish: CGFloat(270), aspect: CGFloat(1.3)),
        (wish: CGFloat(270), aspect: CGFloat(1.62)),
        (wish: CGFloat(120), aspect: CGFloat(1.0)),
        (wish: CGFloat(390), aspect: CGFloat(1.5)),
    ])
    func cellAspectRatioMatchesSettingExactly(config: (wish: CGFloat, aspect: CGFloat)) {
        let metrics = KeyboardLayoutMetrics.resolve(
            wishWidth: config.wish,
            aspectRatio: config.aspect,
            columns: 4,
            availableWidth: 1000,
            screenHeight: 2000
        )
        #expect(abs(metrics.cellWidth / metrics.cellHeight - config.aspect) < 0.0001)
        #expect(abs(metrics.cellAspectRatio - config.aspect) < 0.0001)
    }

    @Test func cellWidthDividesUsableWidthAcrossColumns() {
        let metrics = KeyboardLayoutMetrics.resolve(
            wishWidth: 270,
            aspectRatio: 1.0,
            columns: 4,
            availableWidth: 1000,
            screenHeight: 2000
        )
        #expect(metrics.keyboardWidth == 270)
        #expect(abs(metrics.cellWidth - (270 - hChrome) / 4) < 0.0001)
    }

    // MARK: - Total height formula

    @Test func totalHeightIsRowsPlusConstantChrome() {
        let metrics = KeyboardLayoutMetrics.resolve(
            wishWidth: 300,
            aspectRatio: 1.2,
            columns: 4,
            availableWidth: 1000,
            screenHeight: 2000
        )
        let expected = metrics.cellHeight * 4 + vChrome
        #expect(abs(metrics.totalHeight - expected) < 0.0001)
        // The chrome (spacing + paddings) is constant, never scaled:
        // 3 × 5 pt inter-row gaps + 4 pt top + 10 pt bottom.
        #expect(vChrome == CGFloat(5 * 3 + 4 + 10))
    }

    @Test func totalHeightMatchesRenderedGridContent() {
        // Height-constraint ≡ content-height: the grid renders rows·rowHeight
        // plus (rows−1)·spacing; adding the vertical paddings must give
        // exactly totalHeight (the old formula scaled the paddings, M7).
        let metrics = KeyboardLayoutMetrics.resolve(
            wishWidth: 270,
            aspectRatio: 1.0,
            columns: 4,
            availableWidth: 1000,
            screenHeight: 2000
        )
        let gridContent = metrics.rowHeight * 4 +
            KeyboardConstants.Layout.gridVerticalSpacing * 3
        let content = gridContent +
            KeyboardConstants.Layout.verticalPaddingTop +
            KeyboardConstants.Layout.verticalPaddingBottom
        #expect(abs(metrics.totalHeight - content) < 0.0001)
    }

    // MARK: - Orientation invariance

    @Test func sameWishResolvesIdenticallyInPortraitAndLandscape() {
        // Same wish, no clamp engaged in either orientation: the rendered
        // keyboard must be identical (H1: the old screen-relative default
        // halved the keyboard in landscape).
        let portrait = KeyboardLayoutMetrics.resolve(
            wishWidth: 270,
            aspectRatio: 1.0,
            columns: 4,
            availableWidth: 393,
            screenHeight: 852
        )
        let landscape = KeyboardLayoutMetrics.resolve(
            wishWidth: 270,
            aspectRatio: 1.0,
            columns: 4,
            availableWidth: 852,
            screenHeight: 393
        )
        #expect(portrait == landscape)
    }

    @Test func sameLargeWishResolvesIdenticallyInPortraitAndLandscapeWithinSliderRange() {
        // Large square wish on a screen tall enough that Option C's reserved
        // band engages (screenHeight 450 → cap 330, above the 0.70 floor 315).
        // Under the old flat 0.70 cap the landscape (screenHeight 450) clamped
        // this 330 pt wish while portrait did not, so the keyboard shrank in
        // landscape only. Option C reserves a fixed band instead, so the wish
        // now fits in both orientations and the rendered keyboard is identical.
        //
        // Caveat: on the shortest-landscape iPhones (screenHeight ≈ 393) the
        // reserved band drops below the 0.70 floor, so the very largest wishes
        // still clamp there — see `heightGuardShrinksProportionallyAndPreservesAspect`.
        let portrait = KeyboardLayoutMetrics.resolve(
            wishWidth: 330,
            aspectRatio: 1.0,
            columns: 4,
            availableWidth: 450,
            screenHeight: 900
        )
        let landscape = KeyboardLayoutMetrics.resolve(
            wishWidth: 330,
            aspectRatio: 1.0,
            columns: 4,
            availableWidth: 900,
            screenHeight: 450
        )
        #expect(portrait == landscape)
        #expect(abs(portrait.cellHeight - landscape.cellHeight) < 0.0001)
        #expect(abs(portrait.cellWidth - landscape.cellWidth) < 0.0001)
    }

    // MARK: - Explicit row count

    @Test func resolveRespectsExplicitRowCountInTotalHeight() {
        // The resolver must size the height from the row count it is given
        // (the VM threads the arrangement's own row count through), not a
        // pinned global constant. A 5-row arrangement produces a 5-row height.
        let metrics = KeyboardLayoutMetrics.resolve(
            wishWidth: 270,
            aspectRatio: 1.0,
            columns: 4,
            rows: 5,
            availableWidth: 1000,
            screenHeight: 2000
        )
        #expect(metrics.rows == 5)
        let expected = metrics.cellHeight * 5 + KeyboardLayoutMetrics.verticalChrome(rows: 5)
        #expect(abs(metrics.totalHeight - expected) < 0.0001)
    }

    // MARK: - squareKeyboardWidth shares horizontalChrome

    @Test(arguments: [3, 4, 5])
    func squareKeyboardWidthEqualsCellsPlusHorizontalChrome(columns: Int) {
        let cellSize: CGFloat = 60
        let expected = cellSize * CGFloat(columns) +
            KeyboardLayoutMetrics.horizontalChrome(columns: columns)
        #expect(
            KeyboardConstants.Calculations.squareKeyboardWidth(cellSize: cellSize, columns: columns)
                == expected
        )
    }

    // MARK: - Width fit-clamp

    @Test func wishWiderThanContainerClampsToContainerPreservingAspect() {
        let clamped = KeyboardLayoutMetrics.resolve(
            wishWidth: 600,
            aspectRatio: 1.3,
            columns: 4,
            availableWidth: 375,
            screenHeight: 2000
        )
        #expect(clamped.keyboardWidth == 375)
        #expect(abs(clamped.cellWidth - (375 - hChrome) / 4) < 0.0001)
        #expect(abs(clamped.cellAspectRatio - 1.3) < 0.0001)
    }

    @Test func wishNarrowerThanContainerIsNotClamped() {
        let metrics = KeyboardLayoutMetrics.resolve(
            wishWidth: 340,
            aspectRatio: 1.0,
            columns: 4,
            availableWidth: 375,
            screenHeight: 2000
        )
        #expect(metrics.keyboardWidth == 340)
    }

    // MARK: - Height fit-clamp

    @Test func heightGuardShrinksProportionallyAndPreservesAspect() {
        // Shortest-landscape iPhone (screen height 393): the reserved band
        // (393 − 120 = 273) drops below the 0.70 floor (275.1), so the floor
        // governs the cap here (Option C). A big square wish still overflows
        // and must be scaled down, aspect preserved exactly.
        let metrics = KeyboardLayoutMetrics.resolve(
            wishWidth: 392,
            aspectRatio: 1.0,
            columns: 4,
            availableWidth: 852,
            screenHeight: 393
        )
        // Track the Option C cap directly so the expectation follows whatever
        // reserve/fraction ships (here it resolves to 393·0.70 = 275.1).
        let maxHeight = max(
            393 - KeyboardLayoutMetrics.minReservedScreenHeight,
            393 * KeyboardLayoutMetrics.maxScreenHeightFraction
        )
        #expect(abs(metrics.totalHeight - maxHeight) < 0.0001)
        #expect(abs(metrics.cellAspectRatio - 1.0) < 0.0001)
        // The width shrinks consistently with the cells (chrome constant).
        let expectedWidth = metrics.cellWidth * 4 + hChrome
        #expect(abs(metrics.keyboardWidth - expectedWidth) < 0.0001)
        #expect(metrics.keyboardWidth < 392)
    }

    @Test func heightGuardIsSkippedWhenScreenHeightUnknown() {
        let metrics = KeyboardLayoutMetrics.resolve(
            wishWidth: 392,
            aspectRatio: 1.0,
            columns: 4,
            availableWidth: 852,
            screenHeight: 0
        )
        #expect(metrics.keyboardWidth == 392)
    }

    // MARK: - Clamps never persist

    @Test func resolvingClampedMetricsNeverWritesBackToTheStore() {
        let defaults = InMemoryUserDefaults()
        let settings = LayoutSettings(defaults: defaults, shouldPersist: true)
        settings.keyboardWidth = 600
        #expect(defaults.object(forKey: SettingsKey.keyboardWidthPoints.rawValue) as? Double == 600)

        let metrics = settings.resolveMetrics(columns: 4, availableWidth: 375, screenHeight: 812)
        #expect(metrics.keyboardWidth == 375)

        // The wish stays untouched: a bigger device restores the full width.
        #expect(defaults.object(forKey: SettingsKey.keyboardWidthPoints.rawValue) as? Double == 600)
        #expect(settings.keyboardWidth == 600)
    }

    // MARK: - Hardening

    @Test func degenerateInputsProduceFiniteMetrics() {
        let metrics = KeyboardLayoutMetrics.resolve(
            wishWidth: .nan,
            aspectRatio: 0,
            columns: 0,
            rows: 0,
            availableWidth: -1,
            screenHeight: .infinity
        )
        #expect(metrics.keyboardWidth.isFinite)
        #expect(metrics.cellWidth > 0)
        #expect(metrics.cellHeight > 0)
        #expect(metrics.totalHeight.isFinite)
    }
}
