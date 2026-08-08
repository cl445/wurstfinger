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
/// consumes the result to place each key, including across multiple rows.
enum GridLayoutSolver {
    /// Memoized results per arrangement. `solve` runs in `KeyboardGridView.body`
    /// on every grid render, but its result depends only on the arrangement —
    /// a stored value inside the (registry-cached) definition — so re-solving
    /// per render is pure allocation churn. Bounded by the distinct
    /// arrangements ever rendered (languages × modes × contexts, each a few
    /// hundred bytes), but *not* self-limiting: the keys are `GridArrangement`
    /// values whose row arrays are shared with the definitions, so a cached
    /// entry keeps the arrangement storage of an evicted language alive. It is
    /// therefore dropped alongside the definition cache on the memory-pressure
    /// and pre-suspension paths (`GridLayoutSolver.evictAll`); re-solving takes
    /// microseconds, once per arrangement per appearance. Locked for the same
    /// reason as `KeyboardRegistry.cache`: production access is main-thread
    /// only, but tests run in parallel.
    private static var cache: [GridArrangement: [SolvedCell]] = [:]
    private static let cacheLock = NSLock()

    /// Resolves an arrangement using first-fit, row-major placement: each
    /// placement takes the next free column in its row, skipping cells already
    /// occupied by a span descending from an earlier row. Memoized.
    static func solve(_ arrangement: GridArrangement) -> [SolvedCell] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = cache[arrangement] { return cached }
        let cells = resolve(arrangement)
        cache[arrangement] = cells
        return cells
    }

    /// Drops every memoized result. Called from the keyboard's memory-warning
    /// and pre-suspension paths next to `KeyboardRegistry.evictAll`: the
    /// entries are cheap to rebuild but hold arrangement storage that the
    /// definition eviction is trying to free. Nothing observes the cache, so
    /// clearing it is invisible apart from one re-solve per arrangement.
    static func evictAll() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeAll()
    }

    /// Whether an arrangement is currently memoized (for testing). Mirrors
    /// `KeyboardRegistry.isCached(id:)`: per-arrangement rather than a global
    /// count, so a test probing its own arrangement cannot race the suites
    /// solving theirs in parallel.
    static func isCached(_ arrangement: GridArrangement) -> Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[arrangement] != nil
    }

    private static func resolve(_ arrangement: GridArrangement) -> [SolvedCell] {
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
