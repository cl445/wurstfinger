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
    let onGesture: (KeyConfig, GestureClassification) -> Void
    var onTouchDown: (() -> Void)?
    var onSlide: ((KeyConfig, SlidePhase) -> Void)?
    /// Forwarded to `KeyView`; returns whether the long press was handled.
    var onLongPress: ((KeyConfig) -> Bool)?
    /// Active-language hint for the switch key, supplied by `KeyboardViewModel`
    /// so it reflects the loaded definition rather than re-derived storage.
    var languageLabel: String = ""
    var showLanguageLabel: Bool = false
    /// Learned per-key offsets in pitch fractions, driving Key-Target-Resizing
    /// (§5.4). Empty = no correction.
    var offsets: [String: CGVector] = [:]
    /// The width available to the grid (= the layout's `bounds.width`), needed to
    /// compute the visible compensation in points so drawn keys stay put (§5.5).
    var availableWidth: CGFloat = 0

    /// Resolved layout metrics injected by `DataDrivenKeyboardRootView` from
    /// the view model rather than read via `@AppStorage`: the root view
    /// derives the keyboard *width* from the same metrics, and reading the
    /// settings from a second source desynchronizes width and row height
    /// whenever the view model is configured programmatically (screenshot and
    /// showcase modes with `shouldPersistSettings: false`).
    let metrics: KeyboardLayoutMetrics

    /// The offsets that actually drive resizing: the validation spike when
    /// enabled (UI tests / device), otherwise the learned `offsets`.
    private var effectiveOffsets: [String: CGVector] {
        Self.spikeEnabled ? spikeOffsets : offsets
    }

    private var columnWidth: CGFloat {
        let columns = max(arrangement.columns, 1)
        let spacing = CGFloat(columns - 1) * KeyboardConstants.Layout.gridHorizontalSpacing
        return max((availableWidth - spacing) / CGFloat(columns), 0)
    }

    var body: some View {
        let cells = GridLayoutSolver.solve(arrangement)
        let totalRows = cells.map { $0.row + $0.rowSpan }.max() ?? 0
        let offs = effectiveOffsets
        // Same per-line shifts the layout applies to the touch frames; used here
        // to produce the matching *inverse* visible compensation (§5.5).
        let lines: (vertical: [CGFloat], horizontal: [CGFloat]) =
            offs.isEmpty || columnWidth <= 0
                ? (Array(repeating: 0, count: arrangement.columns + 1), Array(repeating: 0, count: totalRows + 1))
                : KeyboardGridLayout.lineShifts(
                    cells: cells, columns: arrangement.columns, totalRows: totalRows,
                    offsets: offs, clamp: 0.35, columnWidth: columnWidth, rowHeight: metrics.rowHeight
                )
        KeyboardGridLayout(
            cells: cells,
            columns: arrangement.columns,
            rowHeight: metrics.rowHeight,
            horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
            verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing,
            offsets: offs,
            offsetClamp: 0.35
        ) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                cellContent(for: cell, totalRows: totalRows, lines: lines)
            }
        }
    }

    @ViewBuilder
    private func cellContent(
        for cell: SolvedCell, totalRows: Int, lines: (vertical: [CGFloat], horizontal: [CGFloat])
    ) -> some View {
        if let key = keys[cell.keyId] {
            KeyView(
                key: key,
                onGesture: onGesture,
                onTouchDown: onTouchDown,
                onSlide: onSlide,
                onLongPress: onLongPress,
                spanRatio: CGFloat(cell.columnSpan) / CGFloat(cell.rowSpan),
                visualInset: visualInset(for: cell, totalRows: totalRows, lines: lines),
                metrics: metrics,
                languageLabel: languageLabel,
                showLanguageLabel: showLanguageLabel
            )
            .id(cell.keyId)
        } else {
            Color.clear
        }
    }

    /// Inset that keeps the key's drawn bounds unchanged. Base part fills the
    /// inter-key gaps (mirrors the touch frame's gap growth); the offset part
    /// **cancels** the Key-Target-Resizing line shift so the visible key stays
    /// put while the touch frame moves (§5.5). May go negative (content draws
    /// outside the touch frame) — SwiftUI allows this and KeyView does not clip.
    private func visualInset(
        for cell: SolvedCell, totalRows: Int, lines: (vertical: [CGFloat], horizontal: [CGFloat])
    ) -> EdgeInsets {
        let g = KeyboardGridLayout.gapInsets(
            for: cell,
            columns: arrangement.columns,
            totalRows: totalRows,
            horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
            verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing
        )
        return EdgeInsets(
            top: g.top - lines.horizontal[cell.row],
            leading: g.leading - lines.vertical[cell.column],
            bottom: g.bottom + lines.horizontal[cell.row + cell.rowSpan],
            trailing: g.trailing + lines.vertical[cell.column + cell.columnSpan]
        )
    }

    // MARK: - Resizing Spike (validation hook — TEMPORARY)

    /// Active when the resizing validation spike is enabled. The whole **center
    /// column** (`topCenter`/`center`/`bottomCenter`) shifts its hit cells
    /// ~0.18 column right (into the `…Right` column). A fixed screen point just
    /// right of the nominal center|right boundary is then reassigned from the
    /// right key to the center key — provable by coordinate taps (the visible
    /// keys shift too; invisible compensation is P7). Enabled via the
    /// `TOUCH_OFFSET_SPIKE=1` launch environment (UI tests) or, in DEBUG, the
    /// manual constant (device runs).
    private static var spikeEnabled: Bool {
        if ProcessInfo.processInfo.environment["TOUCH_OFFSET_SPIKE"] == "1" { return true }
        #if DEBUG
            return manualSpikeActive
        #else
            return false
        #endif
    }

    #if DEBUG
        /// Manual device toggle (P3.5): flip to `true`, build & run on device.
        private static let manualSpikeActive = false
    #endif

    private var spikeOffsets: [String: CGVector] {
        guard Self.spikeEnabled else { return [:] }
        let shift = CGVector(dx: 0.7, dy: 0) // clamped to 0.35 → ~0.18 col line shift
        return [
            GridSlot.topCenter: shift,
            GridSlot.center: shift,
            GridSlot.bottomCenter: shift,
        ]
    }

    // MARK: - Span Inspection (Test Hooks)

    /// Returns the `(rows, columns)` grid span for a placement. Pure function
    /// so the spanning behavior can be unit tested without introspecting the
    /// rendered SwiftUI tree.
    static func gridCellSpan(for placement: KeyPlacement) -> (rows: Int, columns: Int) {
        (placement.heightMultiplier, placement.widthMultiplier)
    }
}
