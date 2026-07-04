//
//  SquareKeyboardWidthTests.swift
//  wurstfingerTests
//
//  Verifies that `Calculations.squareKeyboardWidth` produces exactly square
//  grid cells when fed through the real portrait arrangement and the same
//  frame math `KeyboardGridLayout` uses at render time. Guards the App Store
//  screenshot geometry (keys must be 1:1, the MessagEase marketing look).
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct SquareKeyboardWidthTests {
    @Test(arguments: [
        (aspectRatio: CGFloat(1.0), scale: CGFloat(1.0)),
        (aspectRatio: CGFloat(1.0), scale: CGFloat(0.6)),
        (aspectRatio: CGFloat(1.5), scale: CGFloat(1.0)),
    ])
    func unitCellsAreSquareAtSquareKeyboardWidth(
        config: (aspectRatio: CGFloat, scale: CGFloat)
    ) throws {
        let arrangement = try #require(StandardArrangements.grid3x3[.portrait])
        let rowHeight = KeyboardConstants.Calculations.keyHeight(
            aspectRatio: config.aspectRatio
        ) * config.scale

        // The root view applies the horizontal padding inside the width frame,
        // so the grid itself receives the width minus both paddings.
        let outerWidth = KeyboardConstants.Calculations.squareKeyboardWidth(
            aspectRatio: config.aspectRatio,
            scale: config.scale,
            columns: arrangement.columns
        )
        let gridWidth = outerWidth - 2 * KeyboardConstants.Layout.horizontalPadding

        let cells = GridLayoutSolver.solve(arrangement)
        let frames = KeyboardGridLayout.cellFrames(
            cells: cells,
            columns: arrangement.columns,
            bounds: CGRect(x: 0, y: 0, width: gridWidth, height: .greatestFiniteMagnitude),
            rowHeight: rowHeight,
            horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
            verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing
        )

        // `cellFrames` returns the touch frames, which grow into the inter-key
        // gaps; the drawn key is the frame inset by the same `gapInsets` that
        // `KeyView` applies. The square property must hold for the visible key.
        let totalRows = cells.map { $0.row + $0.rowSpan }.max() ?? 0
        for (cell, frame) in zip(cells, frames) where cell.columnSpan == 1 && cell.rowSpan == 1 {
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
            #expect(abs(visibleHeight - rowHeight) < 0.001)
        }
    }
}
