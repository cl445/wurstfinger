//
//  HapticFeedbackTests.swift
//  wurstfingerTests
//
//  Tests for the haptic pulse mapping.
//

import Testing
import UIKit
@testable import WurstfingerApp

struct HapticPulseTests {
    @Test func lowestIntensityMapsToSelectionTick() {
        #expect(HapticPulse.pulse(for: 0.05) == .selectionTick)
        #expect(HapticPulse.pulse(for: 0.19) == .selectionTick)
    }

    @Test func intensityBucketsScaleUpToHeavy() {
        #expect(HapticPulse.pulse(for: 0.2) == .impact(.soft))
        #expect(HapticPulse.pulse(for: 0.4) == .impact(.light))
        #expect(HapticPulse.pulse(for: 0.6) == .impact(.medium))
        #expect(HapticPulse.pulse(for: 0.8) == .impact(.heavy))
        #expect(HapticPulse.pulse(for: 1.0) == .impact(.heavy))
    }

    @Test func defaultTapIntensityMapsToLightImpact() {
        #expect(HapticPulse.pulse(for: HapticSettings.defaultTapIntensity) == .impact(.light))
    }
}
