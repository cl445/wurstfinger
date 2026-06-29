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
        guard columns > 0 else { return }
        let totalHorizontalSpacing = CGFloat(columns - 1) * horizontalSpacing
        let columnWidth = max((bounds.width - totalHorizontalSpacing) / CGFloat(columns), 0)

        for (index, cell) in cells.enumerated() where index < subviews.count {
            let originX = bounds.minX + CGFloat(cell.column) * (columnWidth + horizontalSpacing)
            let originY = bounds.minY + CGFloat(cell.row) * (rowHeight + verticalSpacing)
            let width = CGFloat(cell.columnSpan) * columnWidth
                + CGFloat(cell.columnSpan - 1) * horizontalSpacing
            let height = CGFloat(cell.rowSpan) * rowHeight
                + CGFloat(cell.rowSpan - 1) * verticalSpacing
            subviews[index].place(
                at: CGPoint(x: originX, y: originY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: height)
            )
        }
    }
}
