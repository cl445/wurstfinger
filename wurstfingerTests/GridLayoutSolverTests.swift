//
//  GridLayoutSolverTests.swift
//  WurstfingerTests
//
//  Reproduces the landscape multi-row return-key crash and verifies the
//  GridLayoutSolver resolves spans correctly.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct GridLayoutSolverReproTests {
    /// Reproduces the *crash input*: the landscape arrangement feeds the
    /// renderer a return key with `heightMultiplier == 2`. The old
    /// `KeyboardGridView.cell(for:)` rejected that with
    /// `assert(heightMultiplier == 1)`, trapping (EXC_BREAKPOINT) when the
    /// keyboard laid out in landscape. (A literal trap can't be caught
    /// in-process on the iOS simulator, so we pin the triggering data and
    /// verify the solver now handles it below.)
    @Test func landscapeArrangementContainsMultiRowReturnKey() {
        let landscape = StandardArrangements.grid3x3[.landscape]
        let placements = landscape?.rows.flatMap(\.self) ?? []
        let returnPlacement = placements.first { $0.keyId == UtilitySlot.return }
        #expect(returnPlacement?.heightMultiplier == 2)
    }

    /// The fix: the solver spans the return key across two rows at the correct
    /// position, instead of trapping.
    @Test func solverSpansLandscapeReturnKeyAcrossTwoRows() throws {
        let landscape = try #require(StandardArrangements.grid3x3[.landscape])
        let cells = GridLayoutSolver.solve(landscape)
        let returnCell = try #require(cells.first { $0.keyId == UtilitySlot.return })
        #expect(returnCell.rowSpan == 2)
        // In the 5-column landscape grid the return key sits in row 1, column 4.
        #expect(returnCell.row == 1)
        #expect(returnCell.column == 4)
    }

    /// The row below the spanning key must skip the occupied column: the
    /// bottom-row keys land in columns 0...3, never under the return key.
    @Test func cellsBelowSpanSkipOccupiedColumn() throws {
        let landscape = try #require(StandardArrangements.grid3x3[.landscape])
        let cells = GridLayoutSolver.solve(landscape)
        let returnCell = try #require(cells.first { $0.keyId == UtilitySlot.return })
        let lastRow = returnCell.row + returnCell.rowSpan - 1
        let cellsInLastRow = cells.filter { $0.row == lastRow && $0.keyId != UtilitySlot.return }
        #expect(cellsInLastRow.allSatisfy { $0.column < returnCell.column })
    }
}

/// A named arrangement so parameterised tests report which one failed.
struct NamedArrangement: CustomStringConvertible {
    let name: String
    let arrangement: GridArrangement
    var description: String {
        name
    }
}

struct GridLayoutSolverInvariantTests {
    /// Every standard arrangement (all contexts, alpha + numeric) must resolve
    /// to a fully tiled grid with no overlapping cells. This is the property the
    /// old renderer violated; it guards every layout, not just the one that
    /// happened to crash.
    @Test(arguments: GridLayoutSolverInvariantTests.allArrangements)
    func arrangementTilesWithoutOverlap(_ item: NamedArrangement) {
        let name = item.name
        let arrangement = item.arrangement
        let cells = GridLayoutSolver.solve(arrangement)
        // Derive expected rows from the fixture, not the function under test,
        // so a rowCount regression can't also lower the expected tiled area.
        let rows = arrangement.rows.count
        var covered = Set<[Int]>()
        for cell in cells {
            for row in cell.row ..< (cell.row + cell.rowSpan) {
                for column in cell.column ..< (cell.column + cell.columnSpan) {
                    let key = [row, column]
                    #expect(!covered.contains(key), "\(name): overlap at \(key)")
                    covered.insert(key)
                }
            }
        }
        // No cell escapes the declared column count.
        #expect(cells.allSatisfy { $0.column + $0.columnSpan <= arrangement.columns }, "\(name): column overflow")
        // Every grid slot is covered exactly once (full tiling).
        #expect(covered.count == rows * arrangement.columns, "\(name): grid not fully tiled")
    }

    static let allArrangements: [NamedArrangement] = {
        var result: [NamedArrangement] = []
        for (context, arrangement) in StandardArrangements.grid3x3 {
            result.append(NamedArrangement(name: "grid3x3.\(context)", arrangement: arrangement))
        }
        for (context, arrangement) in StandardArrangements.numeric3x3 {
            result.append(NamedArrangement(name: "numeric3x3.\(context)", arrangement: arrangement))
        }
        return result
    }()
}
