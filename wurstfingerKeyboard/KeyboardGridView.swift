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
/// are tracked in the model via `KeyPlacement.heightMultiplier` but the
/// rendering is not yet implemented here. Currently all placements fed to
/// this view must have `heightMultiplier == 1`.
struct KeyboardGridView: View {
    let arrangement: GridArrangement
    let keys: [String: KeyConfig]
    let activeModeName: String
    let onGesture: (KeyConfig, GestureType, Bool) -> Void
    var onTouchDown: (() -> Void)?
    var onSlide: ((KeyConfig, SlidePhase) -> Void)?

    var body: some View {
        Grid(
            horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
            verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing
        ) {
            ForEach(Array(arrangement.rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, placement in
                        cell(for: placement)
                    }
                }
            }
        }
    }

    private func cell(for placement: KeyPlacement) -> some View {
        assert(
            placement.heightMultiplier == 1,
            "Multi-row rendering is not yet implemented in KeyboardGridView"
        )
        return cellContent(for: placement)
    }

    @ViewBuilder
    private func cellContent(for placement: KeyPlacement) -> some View {
        if let key = keys[placement.keyId] {
            KeyView(
                key: key,
                activeModeName: activeModeName,
                onGesture: onGesture,
                onTouchDown: onTouchDown,
                onSlide: onSlide,
                spanRatio: CGFloat(placement.widthMultiplier) / CGFloat(placement.heightMultiplier)
            )
            .gridCellColumns(placement.widthMultiplier)
            .gridCellAnchor(.top)
            .id(placement.keyId)
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
