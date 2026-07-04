//
//  HapticFeedbackTests.swift
//  wurstfingerTests
//
//  Tests for the haptic pulse mapping and the pipeline event routing that
//  keeps text actions silent (their haptic fires on touch-down).
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

struct PipelineHapticEventTests {
    @Test func textActionsAreSilent() {
        #expect(KeyboardHapticEvent.forPipelineAction(.commitText("a")) == nil)
        #expect(KeyboardHapticEvent.forPipelineAction(.compose(trigger: "'")) == nil)
        #expect(KeyboardHapticEvent.forPipelineAction(.space) == nil)
        #expect(KeyboardHapticEvent.forPipelineAction(.newline) == nil)
        #expect(KeyboardHapticEvent.forPipelineAction(.deleteBackward) == nil)
        #expect(KeyboardHapticEvent.forPipelineAction(.moveCursor(offset: 1)) == nil)
        #expect(KeyboardHapticEvent.forPipelineAction(.none) == nil)
    }

    @Test func stateChangingActionsGetConfirmationTick() {
        let actions: [KeyAction] = [
            .switchMode("numeric"), .switchToNextLanguage,
            .advanceToNextInputMode, .dismissKeyboard,
            .copy, .cut, .paste,
        ]
        for action in actions {
            #expect(KeyboardHapticEvent.forPipelineAction(action) == .stateChange)
        }
    }

    @Test func stateChangeUsesTapIntensity() {
        let settings = HapticSettings(defaults: InMemoryUserDefaults(), shouldPersist: false)
        settings.tapIntensity = 0.7
        settings.dragIntensity = 0.1

        #expect(settings.intensity(for: .stateChange) == 0.7)
    }
}
