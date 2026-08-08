//
//  SettingsLayoutMetrics.swift
//  wurstfinger
//
//  The keyboard geometry the settings screens report and simulate.
//

import CoreGraphics

/// Resolves the stored size wish the way the settings screens present it:
/// without a render context, so the numbers are device- and
/// orientation-independent — exactly what the size slider edits.
///
/// Every arrangement the runtime selects is four columns wide (the portrait
/// grid is kept in all orientations, see `KeyboardViewModel.currentContext`),
/// so the cell this resolves is the cell the keyboard renders.
enum SettingsLayoutMetrics {
    private static let gridColumns = 4

    static func forStoredWish(width: CGFloat, aspectRatio: CGFloat) -> KeyboardLayoutMetrics {
        KeyboardLayoutMetrics.resolve(
            wishWidth: width,
            aspectRatio: aspectRatio,
            columns: gridColumns,
            availableWidth: 0,
            screenHeight: 0
        )
    }
}
