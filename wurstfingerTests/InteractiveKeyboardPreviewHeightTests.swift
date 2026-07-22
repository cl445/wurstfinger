//
//  InteractiveKeyboardPreviewHeightTests.swift
//  wurstfingerTests
//
//  Tests for the settings preview's frame-height clamp seam.
//

import CoreGraphics
import Testing
@testable import WurstfingerApp

struct InteractiveKeyboardPreviewHeightTests {
    /// The preview frame applies only the lower bound: tall content is not
    /// clipped (no upper cap), while content below `minHeight` is floored.
    @Test func previewFrameHeightNeverClipsTallContent() {
        #expect(KeyboardConstants.Preview.frameHeight(forContentHeight: 590) == 590)
        #expect(
            KeyboardConstants.Preview.frameHeight(forContentHeight: 50)
                == KeyboardConstants.Preview.minHeight
        )
    }

    /// Demonstrates the clip precondition is reachable within shipped ranges:
    /// tall keys (aspect < 1) on a big screen produce content taller than the
    /// old 400 pt cap, which the removed upper clamp would have clipped.
    @Test func realisticLargeSettingProducesContentTallerThan400() {
        let metrics = KeyboardLayoutMetrics.resolve(
            wishWidth: 390,
            aspectRatio: 0.7,
            columns: 4,
            availableWidth: 390,
            screenHeight: 2000
        )
        #expect(metrics.totalHeight > KeyboardConstants.Preview.maxHeight)
    }
}
