//
//  SettingsLayoutMetricsTests.swift
//  wurstfingerTests
//
//  The settings screens report and simulate the keyboard's geometry. Pins the
//  seam they share to the metrics resolver, so a practice key or a key-height
//  indicator cannot drift away from the cell the keyboard renders.
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct SettingsLayoutMetricsTests {
    @Test(arguments: [
        (wish: CGFloat(270), aspect: CGFloat(1.0)),
        (wish: CGFloat(392), aspect: CGFloat(1.62)),
        (wish: CGFloat(95), aspect: CGFloat(1.0)),
    ])
    func reportsTheRenderedCell(config: (wish: CGFloat, aspect: CGFloat)) {
        let settings = SettingsLayoutMetrics.forStoredWish(width: config.wish, aspectRatio: config.aspect)
        let rendered = KeyboardLayoutMetrics.resolve(
            wishWidth: config.wish,
            aspectRatio: config.aspect,
            columns: 4,
            availableWidth: config.wish,
            screenHeight: 0
        )
        #expect(abs(settings.cellWidth - rendered.cellWidth) < 0.0001)
        #expect(abs(settings.cellHeight - rendered.cellHeight) < 0.0001)
        #expect(abs(settings.cellAspectRatio - rendered.cellAspectRatio) < 0.0001)
    }

    /// At the default wish the keyboard renders a 57.75 pt cell, far from the
    /// 81 pt screenshot constant. Gesture thresholds are absolute point values,
    /// so a practice key drawn at that constant classifies gestures differently.
    @Test func defaultWishResolvesTheRenderedCellNotTheReferenceHeight() {
        let cellHeight = SettingsLayoutMetrics.forStoredWish(width: 270, aspectRatio: 1.0).cellHeight
        #expect(abs(cellHeight - 57.75) < 0.0001)
        #expect(abs(cellHeight - KeyboardConstants.Calculations.screenshotCellSize) > 20)
    }

    /// The marketing geometry is a constant of its own: moving it resizes every
    /// App Store screenshot.
    @Test func screenshotCellSizeIsUnchanged() {
        #expect(KeyboardConstants.Calculations.screenshotCellSize == 81)
    }
}
