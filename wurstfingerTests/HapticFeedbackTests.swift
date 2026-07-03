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

    @Test func defaultTapIntensityMapsToSoftImpact() {
        #expect(HapticPulse.pulse(for: HapticSettings.defaultTapIntensity) == .impact(.soft))
    }
}

struct HapticIntensityLevelTests {
    @Test func storedIntensityRoundTripsForAllLevels() {
        for level in HapticIntensityLevel.allCases {
            #expect(HapticIntensityLevel(storedIntensity: level.storedIntensity) == level)
        }
    }

    @Test func eachLevelProducesItsOwnPulse() {
        #expect(HapticPulse.pulse(for: HapticIntensityLevel.tick.storedIntensity) == .selectionTick)
        #expect(HapticPulse.pulse(for: HapticIntensityLevel.soft.storedIntensity) == .impact(.soft))
        #expect(HapticPulse.pulse(for: HapticIntensityLevel.light.storedIntensity) == .impact(.light))
        #expect(HapticPulse.pulse(for: HapticIntensityLevel.medium.storedIntensity) == .impact(.medium))
        #expect(HapticPulse.pulse(for: HapticIntensityLevel.heavy.storedIntensity) == .impact(.heavy))
    }

    @Test func legacyInBetweenValuesSnapToTheirBucket() {
        #expect(HapticIntensityLevel(storedIntensity: 0) == .off)
        #expect(HapticIntensityLevel(storedIntensity: 0.05) == .tick)
        #expect(HapticIntensityLevel(storedIntensity: 0.4) == .light)
        #expect(HapticIntensityLevel(storedIntensity: 0.65) == .medium)
        #expect(HapticIntensityLevel(storedIntensity: 1.0) == .heavy)
    }
}
