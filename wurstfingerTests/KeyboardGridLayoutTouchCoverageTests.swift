//
//  KeyboardGridLayoutTouchCoverageTests.swift
//  wurstfingerTests
//
//  Verifies that `KeyboardGridLayout` assigns each key a touch frame and that
//  adjacent frames tile the keyboard surface with no gaps — every interior
//  point belongs to some key's frame. Pure geometry, so it runs without a
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

    /// Frames for the real portrait arrangement, sized to exactly fill a bounds
    /// rect (matching `KeyboardGridLayout.sizeThatFits`), so every interior point
    /// *should* belong to some key.
    private func framesForPortrait() throws -> (frames: [CGRect], bounds: CGRect) {
        let arrangement = try #require(StandardArrangements.grid3x3[.portrait])
        let cells = GridLayoutSolver.solve(arrangement)
        let rows = GridLayoutSolver.rowCount(arrangement)
        let height = CGFloat(rows) * rowHeight + CGFloat(max(rows - 1, 0)) * verticalSpacing
        let bounds = CGRect(x: 0, y: 0, width: 320, height: height)
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

    /// Every point on the keyboard surface must belong to a key's touch target —
    /// otherwise a clean tap there produces nothing (a dead zone).
    @Test("No dead zones: key touch frames tile the keyboard surface without gaps")
    func keyFramesCoverSurfaceWithoutGaps() throws {
        let (frames, bounds) = try framesForPortrait()

        var firstUncovered: CGPoint?
        var uncoveredCount = 0
        var y = bounds.minY + 0.5
        while y < bounds.maxY {
            var x = bounds.minX + 0.5
            while x < bounds.maxX {
                let point = CGPoint(x: x, y: y)
                if !frames.contains(where: { $0.contains(point) }) {
                    uncoveredCount += 1
                    if firstUncovered == nil { firstUncovered = point }
                }
                x += 1
            }
            y += 1
        }

        let location = firstUncovered.map { "(\($0.x), \($0.y))" } ?? "n/a"
        #expect(
            uncoveredCount == 0,
            """
            Dead zone between keys: \(uncoveredCount) interior point(s) belong to no key's \
            touch frame (first at \(location)). Every point on the keyboard surface must be \
            covered by a key, so a clean tap in the inter-key gap still registers.
            """
        )
    }

    /// Horizontally adjacent keys must leave no uncovered strip between their
    /// touch frames: each key's right edge meets its neighbour's left edge.
    @Test("Horizontally adjacent keys leave no gap between their touch frames")
    func adjacentKeysAreContiguousHorizontally() throws {
        let (frames, _) = try framesForPortrait()

        // Group frames into rows by their vertical band, then check neighbours.
        let rowsOfFrames = Dictionary(grouping: frames) { $0.minY.rounded() }
        for (_, rowFrames) in rowsOfFrames {
            let ordered = rowFrames.sorted { $0.minX < $1.minX }
            for index in 1 ..< max(ordered.count, 1) where ordered.count > 1 {
                let left = ordered[index - 1]
                let right = ordered[index]
                #expect(
                    left.maxX >= right.minX - 0.001,
                    """
                    Gap of \(right.minX - left.maxX)pt between adjacent keys at y≈\(left.minY): \
                    left key ends at x=\(left.maxX), right key starts at x=\(right.minX). \
                    This strip receives no touches — a dead zone.
                    """
                )
            }
        }
    }
}
