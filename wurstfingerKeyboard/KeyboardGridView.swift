//
//  KeyboardGridView.swift
//  Wurstfinger
//
//  Generic SwiftUI Grid renderer for any GridArrangement + key pool.
//

import SwiftUI

/// Generic grid renderer that lays out a `GridArrangement` using SwiftUI's
/// `Grid` view (iOS 16+). Width multipliers map directly onto
/// `gridCellColumns`, so multi-column keys (e.g. space) are supported
/// without hardcoding any positions.
///
/// **Height-spanning keys.** SwiftUI's `Grid` does not expose a built-in
/// `gridCellRows` modifier. Multi-row placements (e.g. landscape return key)
/// are rendered with an explicit height frame that spans the equivalent number
/// of rows. Subsequent rows that would overlap the spanning key omit those
/// columns, allowing Grid to allocate the remaining space normally.
struct KeyboardGridView: View {
    let arrangement: GridArrangement
    let keys: [String: KeyConfig]
    let onGesture: (KeyConfig, GestureType, Bool) -> Void
    var onTouchDown: (() -> Void)?
    var onSlide: ((KeyConfig, SlidePhase) -> Void)?

    var body: some View {
        Grid(
            horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
            verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing
        ) {
            ForEach(Array(arrangement.rows.enumerated()), id: \.offset) { rowIdx, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, placement in
                        cell(for: placement, rowIndex: rowIdx)
                    }
                }
            }
        }
    }

    private func cell(for placement: KeyPlacement, rowIndex: Int) -> some View {
        cellContent(for: placement, rowIndex: rowIndex)
    }

    @ViewBuilder
    private func cellContent(for placement: KeyPlacement, rowIndex: Int) -> some View {
        if let key = keys[placement.keyId] {
            KeyView(
                key: key,
                onGesture: onGesture,
                onTouchDown: { onTouchDown?() },
                onSlide: onSlide
            )
            .gridCellColumns(placement.widthMultiplier)
            .gridCellAnchor(.top)
        } else {
            Color.clear
                .gridCellColumns(placement.widthMultiplier)
        }
    }

    // MARK: - Span Inspection (Test Hooks)

    /// Returns the `(rows, columns)` grid span for a placement. Pure function
    /// so the spanning behavior can be unit tested without introspecting the
    /// rendered SwiftUI tree.
    static func gridCellSpan(for placement: KeyPlacement) -> (rows: Int, columns: Int) {
        (placement.heightMultiplier, placement.widthMultiplier)
    }
}
