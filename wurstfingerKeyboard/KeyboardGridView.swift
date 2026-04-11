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
/// PR 9 introduces this view as additive infrastructure. The legacy
/// `KeyboardRootView` continues to render the keyboard until PR 12 swaps
/// the rendering path over.
///
/// **Height-spanning keys.** SwiftUI's `Grid` does not expose a built-in
/// `gridCellRows` modifier; row spanning is therefore tracked on the
/// `KeyPlacement` and exposed via `gridCellSpan(for:)` for tests, while the
/// actual visual rendering of multi-row keys is handled by PR 12 once the
/// data-driven path replaces `KeyboardRootView`.
struct KeyboardGridView: View {
    let arrangement: GridArrangement
    let keys: [String: KeyConfig]
    let onGesture: (KeyConfig, GestureType) -> Void

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
            "KeyboardGridView currently renders only single-row cells; multi-row rendering is deferred to PR 12."
        )
        return cellContent(for: placement)
    }

    @ViewBuilder
    private func cellContent(for placement: KeyPlacement) -> some View {
        if let key = keys[placement.keyId] {
            KeyView(key: key, onGesture: onGesture)
                .gridCellColumns(placement.widthMultiplier)
        } else {
            // Missing key in pool — render an empty placeholder so the
            // surrounding layout still aligns. PR 12 will surface this as
            // a validation error during keyboard load.
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
