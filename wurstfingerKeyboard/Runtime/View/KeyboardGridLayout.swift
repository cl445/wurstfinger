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
    /// Per-key learned offset in pitch fractions (`keyId` → `(dx, dy)`), driving
    /// Key-Target-Resizing of the touch cells (§5.4). Empty = no resizing.
    var offsets: [String: CGVector] = [:]
    /// Per-axis clamp on the offset (pitch fraction) so cells never invert (§4.3).
    var offsetClamp: CGFloat = 0.35

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
            verticalSpacing: verticalSpacing,
            offsets: offsets,
            offsetClamp: offsetClamp
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
    /// while the touch frames tile the surface with no gaps — see
    /// `KeyboardGridLayoutTouchCoverageTests`.
    static func cellFrames(
        cells: [SolvedCell],
        columns: Int,
        bounds: CGRect,
        rowHeight: CGFloat,
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat,
        offsets: [String: CGVector] = [:],
        offsetClamp: CGFloat = 0.35
    ) -> [CGRect] {
        guard columns > 0 else { return [] }
        let totalHorizontalSpacing = CGFloat(columns - 1) * horizontalSpacing
        let columnWidth = max((bounds.width - totalHorizontalSpacing) / CGFloat(columns), 0)
        let totalRows = cells.map { $0.row + $0.rowSpan }.max() ?? 0
        let (vLine, hLine) = offsets.isEmpty
            ? ([CGFloat](repeating: 0, count: columns + 1), [CGFloat](repeating: 0, count: totalRows + 1))
            : lineShifts(
                cells: cells, columns: columns, totalRows: totalRows, offsets: offsets,
                clamp: offsetClamp, columnWidth: columnWidth, rowHeight: rowHeight
            )

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
            // Key-Target-Resizing (§5.4): the touch grid lines are perturbed
            // (separable per line), so the tiling stays a valid rectangular
            // partition even for 2D offsets. Each edge follows its shared line.
            let leftEdge = originX - insets.leading + vLine[cell.column]
            let rightEdge = originX + width + insets.trailing + vLine[cell.column + cell.columnSpan]
            let topEdge = originY - insets.top + hLine[cell.row]
            let bottomEdge = originY + height + insets.bottom + hLine[cell.row + cell.rowSpan]
            return CGRect(x: leftEdge, y: topEdge, width: rightEdge - leftEdge, height: bottomEdge - topEdge)
        }
    }

    private struct GridPos: Hashable { let row: Int; let column: Int }

    /// Signed shift (points) of every interior grid line, derived from per-key
    /// offsets. A single vertical/horizontal line is shared by all cells along
    /// it, so it must move by **one** value — hence the per-key offsets adjacent
    /// to a line are averaged onto it (the smooth reach-bias component is
    /// captured; per-key residual is partially realized). Outer lines stay at 0.
    /// This guarantees a disjoint, gapless partition for arbitrary 2D offsets,
    /// which independent per-edge shifts cannot (diagonal-corner mismatch).
    private static func lineShifts(
        cells: [SolvedCell], columns: Int, totalRows: Int,
        offsets: [String: CGVector], clamp: CGFloat, columnWidth: CGFloat, rowHeight: CGFloat
    ) -> (vertical: [CGFloat], horizontal: [CGFloat]) {
        var grid: [GridPos: CGVector] = [:]
        for cell in cells {
            let raw = offsets[cell.keyId] ?? .zero
            let clamped = CGVector(dx: min(max(raw.dx, -clamp), clamp), dy: min(max(raw.dy, -clamp), clamp))
            for r in cell.row ..< (cell.row + cell.rowSpan) {
                for c in cell.column ..< (cell.column + cell.columnSpan) {
                    grid[GridPos(row: r, column: c)] = clamped
                }
            }
        }

        var vertical = [CGFloat](repeating: 0, count: columns + 1)
        if columns > 1 {
            for c in 1 ..< columns {
                var sum: CGFloat = 0
                var n = 0
                for r in 0 ..< totalRows {
                    guard let l = grid[GridPos(row: r, column: c - 1)],
                          let rt = grid[GridPos(row: r, column: c)] else { continue }
                    sum += (l.dx + rt.dx) / 2 * columnWidth
                    n += 1
                }
                vertical[c] = n > 0 ? sum / CGFloat(n) : 0
            }
        }

        var horizontal = [CGFloat](repeating: 0, count: totalRows + 1)
        if totalRows > 1 {
            for r in 1 ..< totalRows {
                var sum: CGFloat = 0
                var n = 0
                for c in 0 ..< columns {
                    guard let t = grid[GridPos(row: r - 1, column: c)],
                          let b = grid[GridPos(row: r, column: c)] else { continue }
                    sum += (t.dy + b.dy) / 2 * rowHeight
                    n += 1
                }
                horizontal[r] = n > 0 ? sum / CGFloat(n) : 0
            }
        }
        return (vertical, horizontal)
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
