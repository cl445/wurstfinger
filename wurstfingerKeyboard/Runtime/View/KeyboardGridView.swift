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

    @AppStorage(SettingsKey.keyboardScale.rawValue, store: SharedDefaults.store)
    private var keyboardScale: Double = DeviceLayoutUtils.defaultKeyboardScale

    @AppStorage(SettingsKey.keyAspectRatio.rawValue, store: SharedDefaults.store)
    private var keyAspectRatio: Double = DeviceLayoutUtils.defaultKeyAspectRatio

    /// Height of a single grid row, matching `KeyView`'s effective key height so
    /// portrait layouts are unchanged and a 2-row key is exactly twice as tall
    /// (plus the inter-row spacing).
    private var rowHeight: CGFloat {
        KeyboardConstants.Calculations.keyHeight(aspectRatio: keyAspectRatio) * keyboardScale
    }

    var body: some View {
        let cells = GridLayoutSolver.solve(arrangement)
        let totalRows = cells.map { $0.row + $0.rowSpan }.max() ?? 0
        KeyboardGridLayout(
            cells: cells,
            columns: arrangement.columns,
            rowHeight: rowHeight,
            horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
            verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing
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
                spanRatio: CGFloat(cell.columnSpan) / CGFloat(cell.rowSpan),
                visualInset: visualInset(for: cell, totalRows: totalRows)
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

    // MARK: - Span Inspection (Test Hooks)

    /// Returns the `(rows, columns)` grid span for a placement. Pure function
    /// so the spanning behavior can be unit tested without introspecting the
    /// rendered SwiftUI tree.
    static func gridCellSpan(for placement: KeyPlacement) -> (rows: Int, columns: Int) {
        (placement.heightMultiplier, placement.widthMultiplier)
    }
}
