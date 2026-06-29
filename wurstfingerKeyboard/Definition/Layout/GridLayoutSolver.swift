//
//  GridLayoutSolver.swift
//  Wurstfinger
//
//  Resolves a GridArrangement into absolutely-positioned, spanning cells.
//

import Foundation

/// A key placed at an absolute grid position with explicit column/row spans.
struct SolvedCell: Equatable {
    let keyId: String
    let row: Int
    let column: Int
    let rowSpan: Int
    let columnSpan: Int
}

/// Pure resolver that turns a `GridArrangement` — whose rows list placements in
/// reading order and omit cells already covered by a span from an earlier row —
/// into absolutely-positioned `SolvedCell`s.
///
/// This is what makes height-spanning keys (e.g. the landscape return key with
/// `heightMultiplier == 2`) renderable: the geometry lives in a pure, testable
/// function instead of being approximated in the SwiftUI tree. `KeyboardGridView`
/// consumes the result to place each key, including across multiple rows — the
/// case the old `Grid`-based renderer could not draw and trapped on.
enum GridLayoutSolver {
    /// Resolves an arrangement using first-fit, row-major placement: each
    /// placement takes the next free column in its row, skipping cells already
    /// occupied by a span descending from an earlier row.
    static func solve(_ arrangement: GridArrangement) -> [SolvedCell] {
        let columns = max(arrangement.columns, 1)
        var occupied: [[Bool]] = []

        func ensureRow(_ row: Int) {
            while occupied.count <= row {
                occupied.append(Array(repeating: false, count: columns))
            }
        }

        var cells: [SolvedCell] = []
        for (rowIndex, row) in arrangement.rows.enumerated() {
            ensureRow(rowIndex)
            var column = 0
            for placement in row {
                // Advance past cells already covered by a span from above.
                while column < columns, occupied[rowIndex][column] {
                    column += 1
                }
                guard column < columns else { break }

                let columnSpan = min(max(placement.widthMultiplier, 1), columns - column)
                let rowSpan = max(placement.heightMultiplier, 1)

                for spanRow in rowIndex ..< (rowIndex + rowSpan) {
                    ensureRow(spanRow)
                    for spanColumn in column ..< (column + columnSpan) {
                        occupied[spanRow][spanColumn] = true
                    }
                }

                cells.append(
                    SolvedCell(
                        keyId: placement.keyId,
                        row: rowIndex,
                        column: column,
                        rowSpan: rowSpan,
                        columnSpan: columnSpan
                    )
                )
                column += columnSpan
            }
        }
        return cells
    }

    /// Total number of grid rows the arrangement occupies, accounting for spans.
    static func rowCount(_ arrangement: GridArrangement) -> Int {
        solve(arrangement).map { $0.row + $0.rowSpan }.max() ?? arrangement.rows.count
    }
}
