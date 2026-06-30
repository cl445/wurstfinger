//
//  KeyboardGridLayout.swift
//  Wurstfinger
//
//  SwiftUI Layout that positions keys with both column and row spans.
//

import SwiftUI

/// Positions keyboard keys on a fixed grid, honouring **both** column and row
/// spans. SwiftUI's `Grid` only supports column spans (`gridCellColumns`), which
/// is why a row-spanning key (e.g. the landscape return key) previously could
/// not be drawn — the old renderer trapped on it instead.
///
/// Cells are pre-resolved by `GridLayoutSolver`; the subviews handed to the
/// layout must be in the same order as `cells`. Each cell is given an explicit
/// frame, so a key can span multiple rows and/or columns.
struct KeyboardGridLayout: Layout {
    let cells: [SolvedCell]
    let columns: Int
    let rowHeight: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    private var rowCount: Int {
        cells.map { $0.row + $0.rowSpan }.max() ?? 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews _: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let rows = rowCount
        let height = CGFloat(rows) * rowHeight + CGFloat(max(rows - 1, 0)) * verticalSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let frames = Self.cellFrames(
            cells: cells,
            columns: columns,
            bounds: bounds,
            rowHeight: rowHeight,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )
        for (index, frame) in frames.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: frame.minX, y: frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    /// Computes the frame assigned to every cell — the pure geometry behind
    /// `placeSubviews`, exposed so touch coverage can be unit tested without a
    /// SwiftUI host. Frames are returned in the same order as `cells`.
    ///
    /// A cell's frame is the key's **effective touch target**: SwiftUI delivers
    /// touches to a Layout-placed subview within this frame. Each frame is grown
    /// by `gapInsets` so it meets its neighbours in the **middle** of the
    /// inter-key spacing, leaving no uncovered strip. The visible key is inset
    /// back by the same amount in `KeyView`, so the drawn layout is unchanged
    /// while the dead zones between keys disappear — see
    /// `KeyboardGridLayoutTouchCoverageTests`.
    static func cellFrames(
        cells: [SolvedCell],
        columns: Int,
        bounds: CGRect,
        rowHeight: CGFloat,
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat
    ) -> [CGRect] {
        guard columns > 0 else { return [] }
        let totalHorizontalSpacing = CGFloat(columns - 1) * horizontalSpacing
        let columnWidth = max((bounds.width - totalHorizontalSpacing) / CGFloat(columns), 0)
        let totalRows = cells.map { $0.row + $0.rowSpan }.max() ?? 0

        return cells.map { cell in
            // Visible frame: the key's drawn bounds (geometry unchanged).
            let originX = bounds.minX + CGFloat(cell.column) * (columnWidth + horizontalSpacing)
            let originY = bounds.minY + CGFloat(cell.row) * (rowHeight + verticalSpacing)
            let width = CGFloat(cell.columnSpan) * columnWidth
                + CGFloat(cell.columnSpan - 1) * horizontalSpacing
            let height = CGFloat(cell.rowSpan) * rowHeight
                + CGFloat(cell.rowSpan - 1) * verticalSpacing

            // Touch frame: grow into the surrounding gaps so adjacent frames meet.
            let insets = gapInsets(
                for: cell,
                columns: columns,
                totalRows: totalRows,
                horizontalSpacing: horizontalSpacing,
                verticalSpacing: verticalSpacing
            )
            return CGRect(
                x: originX - insets.leading,
                y: originY - insets.top,
                width: width + insets.leading + insets.trailing,
                height: height + insets.top + insets.bottom
            )
        }
    }

    /// Per-side amount by which a cell's touch frame grows into the gap toward
    /// its neighbours: half the spacing on each interior side, and zero at the
    /// keyboard's outer edges (so the grid still ends exactly at `bounds`).
    ///
    /// Single source of truth shared by `cellFrames` — which expands the touch
    /// frame — and `KeyView`, which insets the **visible** key by the same
    /// values so growing the touch target changes nothing the user sees.
    static func gapInsets(
        for cell: SolvedCell,
        columns: Int,
        totalRows: Int,
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat
    ) -> (top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        let halfH = horizontalSpacing / 2
        let halfV = verticalSpacing / 2
        return (
            top: cell.row == 0 ? 0 : halfV,
            leading: cell.column == 0 ? 0 : halfH,
            bottom: cell.row + cell.rowSpan >= totalRows ? 0 : halfV,
            trailing: cell.column + cell.columnSpan >= columns ? 0 : halfH
        )
    }
}
