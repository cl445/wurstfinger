//
//  KeyboardGridLayoutTouchCoverageTests.swift
//  wurstfingerTests
//
//  Verifies that `KeyboardGridLayout` assigns each key a touch frame and that
//  the frames partition the keyboard surface exactly — no gaps (every point
//  belongs to a key) and no overlaps. Pure geometry, so it runs without a
//  SwiftUI host.
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct KeyboardGridLayoutTouchCoverageTests {
    private let horizontalSpacing = KeyboardConstants.Layout.gridHorizontalSpacing
    private let verticalSpacing = KeyboardConstants.Layout.gridVerticalSpacing
    private let rowHeight: CGFloat = 50

    /// Arrangements under test: the real portrait layout (1×1 letter cells plus
    /// its utility column) and a synthetic layout that adds a row-spanning and a
    /// column-spanning key, so the span paths in `cellFrames` / `gapInsets` are
    /// exercised rather than only unit cells.
    private func arrangements() throws -> [(name: String, value: GridArrangement)] {
        try [
            ("portrait", #require(StandardArrangements.grid3x3[.portrait])),
            ("synthetic-spans", spanningArrangement()),
        ]
    }

    /// A fully-tiled 3-column arrangement that uses a row-spanning key (C) and a
    /// column-spanning key (D):
    ///
    ///   row 0:  A   B   C(rowSpan 2)
    ///   row 1:  D(colSpan 2)   ·C·
    private func spanningArrangement() -> GridArrangement {
        GridArrangement(columns: 3, rows: [
            [
                KeyPlacement(keyId: "A"),
                KeyPlacement(keyId: "B"),
                KeyPlacement(keyId: "C", heightMultiplier: 2),
            ],
            [KeyPlacement(keyId: "D", widthMultiplier: 2)],
        ])
    }

    /// Frames sized to exactly fill the bounds (matching `sizeThatFits`). The
    /// width is deliberately not divisible by the column count, so cell frames
    /// land on fractional coordinates and any sub-point gap would surface.
    private func layout(for arrangement: GridArrangement) -> (frames: [CGRect], bounds: CGRect) {
        let cells = GridLayoutSolver.solve(arrangement)
        let rows = GridLayoutSolver.rowCount(arrangement)
        let height = CGFloat(rows) * rowHeight + CGFloat(max(rows - 1, 0)) * verticalSpacing
        let bounds = CGRect(x: 0, y: 0, width: 321, height: height)
        let frames = KeyboardGridLayout.cellFrames(
            cells: cells,
            columns: arrangement.columns,
            bounds: bounds,
            rowHeight: rowHeight,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )
        return (frames, bounds)
    }

    /// The touch frames must partition the surface exactly. Proven analytically
    /// rather than by sampling: no two frames overlap, and their areas sum to the
    /// bounds area. Together that means full coverage with no gaps — including
    /// sub-point gaps that a point scan could miss — on both axes and for
    /// span-bearing cells.
    @Test("Touch frames tile the surface with no gaps or overlaps")
    func touchFramesTileExactly() throws {
        for (name, arrangement) in try arrangements() {
            let (frames, bounds) = layout(for: arrangement)

            // No overlaps. Adjacent frames share an edge, which produces a
            // degenerate (zero-width or zero-height) intersection — allowed.
            for i in frames.indices {
                for j in (i + 1) ..< frames.count {
                    let overlap = frames[i].intersection(frames[j])
                    let touchesOnly = overlap.isNull || overlap.width < 0.001 || overlap.height < 0.001
                    #expect(
                        touchesOnly,
                        "\(name): touch frames overlap by \(overlap) — \(frames[i]) vs \(frames[j])"
                    )
                }
            }

            // Given no overlaps, equal areas prove the frames cover the bounds
            // exactly: any gap would leave the total short, any overhang long.
            let totalArea = frames.reduce(0) { $0 + $1.width * $1.height }
            let boundsArea = bounds.width * bounds.height
            #expect(
                abs(totalArea - boundsArea) < 0.5,
                """
                \(name): touch frames cover \(totalArea)pt² but the surface is \
                \(boundsArea)pt² — a gap (dead zone) or overhang.
                """
            )
        }
    }
}
