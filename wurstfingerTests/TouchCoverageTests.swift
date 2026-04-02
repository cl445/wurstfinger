//
//  TouchCoverageTests.swift
//  wurstfingerTests
//
//  Tests that every pixel on the keyboard surface is covered by at least one
//  key's touch area, eliminating dead zones.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct TouchCoverageTests {
    // MARK: - Touch padding constant

    @Test("touchPadding covers horizontal padding")
    func touchPaddingCoversHorizontalPadding() {
        #expect(
            KeyboardConstants.Layout.touchPadding >= KeyboardConstants.Layout.horizontalPadding,
            "touchPadding must reach the keyboard edge through horizontal padding"
        )
    }

    @Test("touchPadding covers bottom padding")
    func touchPaddingCoversBottomPadding() {
        #expect(
            KeyboardConstants.Layout.touchPadding >= KeyboardConstants.Layout.verticalPaddingBottom,
            "touchPadding must reach the keyboard edge through bottom padding"
        )
    }

    @Test("touchPadding covers top padding")
    func touchPaddingCoversTopPadding() {
        #expect(
            KeyboardConstants.Layout.touchPadding >= KeyboardConstants.Layout.verticalPaddingTop,
            "touchPadding must reach the keyboard edge through top padding"
        )
    }

    @Test("touchPadding covers horizontal grid spacing")
    func touchPaddingCoversHorizontalSpacing() {
        #expect(
            KeyboardConstants.Layout.touchPadding >= KeyboardConstants.Layout.gridHorizontalSpacing / 2,
            "touchPadding must cover at least half the horizontal grid spacing"
        )
    }

    @Test("touchPadding covers vertical grid spacing")
    func touchPaddingCoversVerticalSpacing() {
        #expect(
            KeyboardConstants.Layout.touchPadding >= KeyboardConstants.Layout.gridVerticalSpacing / 2,
            "touchPadding must cover at least half the vertical grid spacing"
        )
    }

    // MARK: - Row-level horizontal coverage

    /// Verifies that for a standard row (3 grid keys + 1 utility key),
    /// the union of all touch areas covers the entire row width with no gaps.
    @Test("Key touch areas cover full row width")
    func keyTouchAreasCoverFullRowWidth() {
        let aspectRatio = DeviceLayoutUtils.defaultKeyAspectRatio
        let keyHeight: CGFloat = 54
        let keyWidth = keyHeight * aspectRatio
        let spacing = KeyboardConstants.Layout.gridHorizontalSpacing
        let padding = KeyboardConstants.Layout.horizontalPadding
        let touchPad = KeyboardConstants.Layout.touchPadding

        // 4 keys per row (3 grid + 1 utility)
        let keyCount = 4
        let contentWidth = CGFloat(keyCount) * keyWidth + CGFloat(keyCount - 1) * spacing
        let totalRowWidth = contentWidth + 2 * padding

        // Build touch intervals for each key
        // Keys are positioned: padding + i * (keyWidth + spacing)
        var touchIntervals: [(min: CGFloat, max: CGFloat)] = []
        for i in 0 ..< keyCount {
            let keyLeft = padding + CGFloat(i) * (keyWidth + spacing)
            let keyRight = keyLeft + keyWidth
            let touchLeft = keyLeft - touchPad
            let touchRight = keyRight + touchPad
            touchIntervals.append((min: touchLeft, max: touchRight))
        }

        // Sort by min
        let sorted = touchIntervals.sorted { $0.min < $1.min }

        // Verify coverage from 0 to totalRowWidth
        #expect(sorted[0].min <= 0, "First key touch area must reach left edge (got \(sorted[0].min))")
        #expect(sorted.last!.max >= totalRowWidth, "Last key touch area must reach right edge (got \(sorted.last!.max) vs \(totalRowWidth))")

        // Verify no gaps between adjacent intervals
        for i in 1 ..< sorted.count {
            #expect(
                sorted[i].min <= sorted[i - 1].max,
                "Gap between key \(i - 1) and key \(i): \(sorted[i].min) > \(sorted[i - 1].max)"
            )
        }
    }

    // MARK: - Vertical coverage

    /// Verifies that 4 rows of keys with touchPadding cover the full keyboard height.
    @Test("Key touch areas cover full keyboard height")
    func keyTouchAreasCoverFullKeyboardHeight() {
        let keyHeight: CGFloat = 54
        let spacing = KeyboardConstants.Layout.gridVerticalSpacing
        let paddingTop = KeyboardConstants.Layout.verticalPaddingTop
        let paddingBottom = KeyboardConstants.Layout.verticalPaddingBottom
        let touchPad = KeyboardConstants.Layout.touchPadding

        let rowCount = KeyboardConstants.KeyDimensions.totalRows
        let totalHeight = CGFloat(rowCount) * keyHeight +
            CGFloat(rowCount - 1) * spacing +
            paddingTop + paddingBottom

        // Build vertical touch intervals for each row
        var touchIntervals: [(min: CGFloat, max: CGFloat)] = []
        for i in 0 ..< rowCount {
            let rowTop = paddingTop + CGFloat(i) * (keyHeight + spacing)
            let rowBottom = rowTop + keyHeight
            touchIntervals.append((min: rowTop - touchPad, max: rowBottom + touchPad))
        }

        let sorted = touchIntervals.sorted { $0.min < $1.min }

        #expect(sorted[0].min <= 0, "Top row touch area must reach keyboard top edge")
        #expect(sorted.last!.max >= totalHeight, "Bottom row touch area must reach keyboard bottom edge")

        for i in 1 ..< sorted.count {
            #expect(
                sorted[i].min <= sorted[i - 1].max,
                "Vertical gap between row \(i - 1) and row \(i)"
            )
        }
    }
}
