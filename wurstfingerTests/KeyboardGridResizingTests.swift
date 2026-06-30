//
//  KeyboardGridResizingTests.swift
//  WurstfingerTests
//
//  Verifies Key-Target-Resizing in cellFrames (spec §5.4): a per-key offset
//  shifts the shared touch-cell boundaries while the tiling stays a disjoint,
//  gapless partition. Pure geometry, no SwiftUI host.
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct KeyboardGridResizingTests {
    private let horizontalSpacing = KeyboardConstants.Layout.gridHorizontalSpacing
    private let verticalSpacing = KeyboardConstants.Layout.gridVerticalSpacing
    private let rowHeight: CGFloat = 50

    private func frames(
        _ arrangement: GridArrangement, offsets: [String: CGVector]
    ) -> (cells: [SolvedCell], frames: [CGRect], bounds: CGRect) {
        let cells = GridLayoutSolver.solve(arrangement)
        let rows = GridLayoutSolver.rowCount(arrangement)
        let height = CGFloat(rows) * rowHeight + CGFloat(max(rows - 1, 0)) * verticalSpacing
        let bounds = CGRect(x: 0, y: 0, width: 321, height: height)
        let f = KeyboardGridLayout.cellFrames(
            cells: cells, columns: arrangement.columns, bounds: bounds,
            rowHeight: rowHeight, horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing, offsets: offsets, offsetClamp: 0.5
        )
        return (cells, f, bounds)
    }

    private func assertExactTiling(_ frames: [CGRect], bounds: CGRect, _ label: String) {
        for i in frames.indices {
            for j in (i + 1) ..< frames.count {
                let overlap = frames[i].intersection(frames[j])
                let touchesOnly = overlap.isNull || overlap.width < 0.001 || overlap.height < 0.001
                #expect(touchesOnly, "\(label): overlap \(overlap)")
            }
        }
        let totalArea = frames.reduce(0) { $0 + $1.width * $1.height }
        #expect(abs(totalArea - bounds.width * bounds.height) < 0.5, "\(label): coverage gap/overhang")
    }

    @Test func resizingPreservesExactTiling() throws {
        let arrangement = try #require(StandardArrangements.grid3x3[.portrait])
        let (_, f, bounds) = frames(arrangement, offsets: [GridSlot.center: CGVector(dx: 0.4, dy: -0.3)])
        assertExactTiling(f, bounds: bounds, "resized portrait")
    }

    @Test func positiveOffsetShiftsCenterCellRight() throws {
        let arrangement = try #require(StandardArrangements.grid3x3[.portrait])
        let (cells, baseline, _) = frames(arrangement, offsets: [:])
        let (_, shifted, _) = frames(arrangement, offsets: [GridSlot.center: CGVector(dx: 0.4, dy: 0)])
        let idx = try #require(cells.firstIndex { $0.keyId == GridSlot.center })
        // The center cell's hit frame moves right (both its shared vertical
        // boundaries shift right by the same amount → translation, width kept).
        #expect(shifted[idx].minX > baseline[idx].minX + 1.0)
        #expect(abs(shifted[idx].width - baseline[idx].width) < 0.5)
    }

    @Test func emptyOffsetsAreIdenticalToBaseline() throws {
        // Regression guard: the new offset path must not change anything when
        // no offsets are supplied.
        let arrangement = try #require(StandardArrangements.grid3x3[.portrait])
        let (_, withEmpty, _) = frames(arrangement, offsets: [:])
        let cells = GridLayoutSolver.solve(arrangement)
        let rows = GridLayoutSolver.rowCount(arrangement)
        let height = CGFloat(rows) * rowHeight + CGFloat(max(rows - 1, 0)) * verticalSpacing
        let bounds = CGRect(x: 0, y: 0, width: 321, height: height)
        let legacy = KeyboardGridLayout.cellFrames(
            cells: cells, columns: arrangement.columns, bounds: bounds,
            rowHeight: rowHeight, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing
        )
        for (a, b) in zip(withEmpty, legacy) {
            #expect(abs(a.minX - b.minX) < 1e-9 && abs(a.width - b.width) < 1e-9)
        }
    }
}
