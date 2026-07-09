//
//  SquareKeyboardWidthTests.swift
//  wurstfingerTests
//
//  Verifies the App Store screenshot geometry: resolving the point-anchored
//  metrics at `Calculations.squareKeyboardWidth` with aspect ratio 1.0 must
//  produce exactly square grid cells of the requested size, fed through the
//  real portrait arrangement and the same frame math `KeyboardGridLayout`
//  uses at render time (keys must be 1:1, the square marketing look).
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct SquareKeyboardWidthTests {
    @Test(arguments: [CGFloat(81), CGFloat(54), CGFloat(40)])
    func unitCellsAreSquareAtSquareKeyboardWidth(cellSize: CGFloat) throws {
        let arrangement = try #require(StandardArrangements.grid3x3[.portrait])

        // Wish exactly the width the screenshot mode forces; no fit-clamp
        // engaged (generous container/screen), so the wish is the result.
        let outerWidth = KeyboardConstants.Calculations.squareKeyboardWidth(
            cellSize: cellSize,
            columns: arrangement.columns
        )
        let metrics = KeyboardLayoutMetrics.resolve(
            wishWidth: outerWidth,
            aspectRatio: 1.0,
            columns: arrangement.columns,
            availableWidth: 10000,
            screenHeight: 10000
        )
        #expect(abs(metrics.cellWidth - cellSize) < 0.001)
        #expect(abs(metrics.cellHeight - cellSize) < 0.001)

        // The root view applies the horizontal padding inside the width frame,
        // so the grid itself receives the width minus both paddings.
        let gridWidth = metrics.keyboardWidth - 2 * KeyboardConstants.Layout.horizontalPadding

        let cells = GridLayoutSolver.solve(arrangement)
        let frames = KeyboardGridLayout.cellFrames(
            cells: cells,
            columns: arrangement.columns,
            bounds: CGRect(x: 0, y: 0, width: gridWidth, height: .greatestFiniteMagnitude),
            rowHeight: metrics.rowHeight,
            horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
            verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing
        )

        // `cellFrames` returns the touch frames, which grow into the inter-key
        // gaps; the drawn key is the frame inset by the same `gapInsets` that
        // `KeyView` applies. The square property must hold for the visible key.
        let totalRows = cells.map { $0.row + $0.rowSpan }.max() ?? 0
        var checked = 0
        for (cell, frame) in zip(cells, frames) where cell.columnSpan == 1 && cell.rowSpan == 1 {
            checked += 1
            let insets = KeyboardGridLayout.gapInsets(
                for: cell,
                columns: arrangement.columns,
                totalRows: totalRows,
                horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
                verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing
            )
            let visibleWidth = frame.width - insets.leading - insets.trailing
            let visibleHeight = frame.height - insets.top - insets.bottom
            #expect(
                abs(visibleWidth - visibleHeight) < 0.001,
                "cell \(cell.keyId): \(visibleWidth) x \(visibleHeight)"
            )
            #expect(abs(visibleHeight - cellSize) < 0.001)
        }
        #expect(checked > 0, "no single-span cells were checked for cellSize \(cellSize)")
    }
}
