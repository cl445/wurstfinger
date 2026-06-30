//
//  KeyboardGridView.swift
//  Wurstfinger
//
//  Generic SwiftUI grid renderer for any GridArrangement + key pool.
//

import SwiftUI

/// Generic grid renderer for a `GridArrangement` and key pool.
///
/// Uses `GridLayoutSolver` to resolve the arrangement into absolutely
/// positioned cells and `KeyboardGridLayout` to place them, so keys can span
/// multiple columns **and** rows (e.g. the landscape return key with
/// `heightMultiplier == 2`). Width/height multipliers map directly onto the
/// cell's column/row span, without hardcoding any positions.
struct KeyboardGridView: View {
    let arrangement: GridArrangement
    let keys: [String: KeyConfig]
    let onGesture: (KeyConfig, GestureType, Bool) -> Void
    var onTouchDown: (() -> Void)?
    var onSlide: ((KeyConfig, SlidePhase) -> Void)?
    /// Forwarded to `KeyView`; returns whether the long press was handled.
    var onLongPress: ((KeyConfig) -> Bool)?
    /// Active-language hint for the switch key, supplied by `KeyboardViewModel`
    /// so it reflects the loaded definition rather than re-derived storage.
    var languageLabel: String = ""
    var showLanguageLabel: Bool = false

    /// Resolved layout metrics injected by `DataDrivenKeyboardRootView` from
    /// the view model rather than read via `@AppStorage`: the root view
    /// derives the keyboard *width* from the same metrics, and reading the
    /// settings from a second source desynchronizes width and row height
    /// whenever the view model is configured programmatically (screenshot and
    /// showcase modes with `shouldPersistSettings: false`).
    let metrics: KeyboardLayoutMetrics

    var body: some View {
        let cells = GridLayoutSolver.solve(arrangement)
        let totalRows = cells.map { $0.row + $0.rowSpan }.max() ?? 0
        KeyboardGridLayout(
            cells: cells,
            columns: arrangement.columns,
            rowHeight: metrics.rowHeight,
            horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
            verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing,
            offsets: spikeOffsets,
            offsetClamp: spikeClamp
        ) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                cellContent(for: cell, totalRows: totalRows)
            }
        }
    }

    @ViewBuilder
    private func cellContent(for cell: SolvedCell, totalRows: Int) -> some View {
        if let key = keys[cell.keyId] {
            KeyView(
                key: key,
                onGesture: onGesture,
                onTouchDown: onTouchDown,
                onSlide: onSlide,
                onLongPress: onLongPress,
                spanRatio: CGFloat(cell.columnSpan) / CGFloat(cell.rowSpan),
                visualInset: visualInset(for: cell, totalRows: totalRows),
                metrics: metrics,
                languageLabel: languageLabel,
                showLanguageLabel: showLanguageLabel
            )
            .id(cell.keyId)
        } else {
            Color.clear
        }
    }

    /// Inset that keeps the key's drawn bounds unchanged while its touch cell
    /// fills the gaps to neighbouring keys. Mirrors `KeyboardGridLayout`, which
    /// grows the cell frame by the same amount.
    private func visualInset(for cell: SolvedCell, totalRows: Int) -> EdgeInsets {
        let insets = KeyboardGridLayout.gapInsets(
            for: cell,
            columns: arrangement.columns,
            totalRows: totalRows,
            horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
            verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing
        )
        return EdgeInsets(
            top: insets.top,
            leading: insets.leading,
            bottom: insets.bottom,
            trailing: insets.trailing
        )
    }

    // MARK: - P3.5 Device Spike (TEMPORARY — remove after validation)

    #if DEBUG
        /// Flip to `true`, build & run **on device** to validate Key-Target-
        /// Resizing: the whole **center column** (`topCenter`/`center`/
        /// `bottomCenter`) shifts its hit cells ~0.18 column to the right (into
        /// the `…Right` column), so a tap on the *left edge* of the drawn right
        /// column produces the center column's character. Proves the touch frame
        /// — not the drawn key — decides assignment (§5.5/§11.6). The visible
        /// keys shift too here (invisible compensation is P7). The whole column
        /// is offset so the per-line averaging (§5.4) does not dilute it.
        private static let spikeActive = false
        private var spikeOffsets: [String: CGVector] {
            guard Self.spikeActive else { return [:] }
            let shift = CGVector(dx: 0.7, dy: 0) // clamped to 0.35 → ~0.18 col line shift
            return [
                GridSlot.topCenter: shift,
                GridSlot.center: shift,
                GridSlot.bottomCenter: shift,
            ]
        }

        private var spikeClamp: CGFloat {
            0.35
        }
    #else
        private var spikeOffsets: [String: CGVector] {
            [:]
        }

        private var spikeClamp: CGFloat {
            0.35
        }
    #endif

    // MARK: - Span Inspection (Test Hooks)

    /// Returns the `(rows, columns)` grid span for a placement. Pure function
    /// so the spanning behavior can be unit tested without introspecting the
    /// rendered SwiftUI tree.
    static func gridCellSpan(for placement: KeyPlacement) -> (rows: Int, columns: Int) {
        (placement.heightMultiplier, placement.widthMultiplier)
    }
}
