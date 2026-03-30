//
//  KeyboardSettingsTests.swift
//  wurstfingerTests
//
//  Tests for HapticSettings and LayoutSettings classes
//

import Foundation
import Testing
@testable import WurstfingerApp

struct HapticSettingsTests {
    // Helper to create isolated UserDefaults for testing
    private func createTestDefaults() -> UserDefaults {
        let suiteName = "test.haptic.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    // MARK: - Initialization Tests

    @Test func initWithDefaultValues() {
        let defaults = createTestDefaults()
        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        #expect(settings.enabled == true)
        #expect(settings.tapIntensity == HapticSettings.defaultTapIntensity)
        #expect(settings.modifierIntensity == HapticSettings.defaultModifierIntensity)
        #expect(settings.dragIntensity == HapticSettings.defaultDragIntensity)
    }

    @Test func initLoadsPersistedValues() {
        let defaults = createTestDefaults()

        // Pre-populate UserDefaults
        defaults.set(false, forKey: SettingsKey.hapticEnabled.rawValue)
        defaults.set(0.3, forKey: SettingsKey.hapticIntensityTap.rawValue)
        defaults.set(0.6, forKey: SettingsKey.hapticIntensityModifier.rawValue)
        defaults.set(0.9, forKey: SettingsKey.hapticIntensityDrag.rawValue)

        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        #expect(settings.enabled == false)
        #expect(abs(settings.tapIntensity - 0.3) < 0.01)
        #expect(abs(settings.modifierIntensity - 0.6) < 0.01)
        #expect(abs(settings.dragIntensity - 0.9) < 0.01)
    }

    // MARK: - Clamping Tests

    @Test func intensityClampedToValidRange() {
        let defaults = createTestDefaults()
        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        settings.tapIntensity = 1.5 // above max
        #expect(settings.tapIntensity == 1.0)

        settings.tapIntensity = -0.5 // below min
        #expect(settings.tapIntensity == 0.0)

        settings.tapIntensity = 0.5 // valid
        #expect(settings.tapIntensity == 0.5)
    }

    // MARK: - Persistence Tests

    @Test func changesPersistToUserDefaults() {
        let defaults = createTestDefaults()
        let settings = HapticSettings(defaults: defaults, shouldPersist: true)

        settings.tapIntensity = 0.7
        settings.enabled = false

        // Verify persisted
        let savedIntensity = defaults.double(forKey: SettingsKey.hapticIntensityTap.rawValue)
        let savedEnabled = defaults.bool(forKey: SettingsKey.hapticEnabled.rawValue)

        #expect(abs(savedIntensity - 0.7) < 0.01)
        #expect(savedEnabled == false)
    }

    @Test func changesNotPersistedWhenDisabled() {
        let defaults = createTestDefaults()
        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        settings.tapIntensity = 0.8

        // Should not be persisted
        let savedIntensity = defaults.object(forKey: SettingsKey.hapticIntensityTap.rawValue)
        #expect(savedIntensity == nil)
    }

    // MARK: - Reload Tests

    @Test func reloadUpdatesFromUserDefaults() {
        let defaults = createTestDefaults()
        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        // Externally change UserDefaults
        defaults.set(0.2, forKey: SettingsKey.hapticIntensityTap.rawValue)

        settings.reload()

        #expect(abs(settings.tapIntensity - 0.2) < 0.01)
    }

    // MARK: - Non-numeric Defaults Safety Tests

    @Test func nonNumericDefaultsFallBackToDefaults() {
        let defaults = createTestDefaults()

        // Store non-numeric values that could corrupt settings
        defaults.set("not_a_number", forKey: SettingsKey.hapticIntensityTap.rawValue)
        defaults.set(true, forKey: SettingsKey.hapticIntensityModifier.rawValue)

        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        // Should fall back to defaults, not use 0.0
        #expect(settings.tapIntensity == HapticSettings.defaultTapIntensity)
        // Boolean stored as NSNumber: true -> 1.0, clamped to 1.0
        #expect(settings.modifierIntensity == 1.0)
    }

    @Test func missingDefaultsFallBackCorrectly() {
        let defaults = createTestDefaults()
        // Don't set any values — all should be defaults
        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        #expect(settings.tapIntensity == HapticSettings.defaultTapIntensity)
        #expect(settings.modifierIntensity == HapticSettings.defaultModifierIntensity)
        #expect(settings.dragIntensity == HapticSettings.defaultDragIntensity)
        #expect(settings.enabled == true)
    }

    // MARK: - Intensity For Event Tests

    @Test func intensityForEventReturnsCorrectValue() {
        let defaults = createTestDefaults()
        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        settings.tapIntensity = 0.3
        settings.modifierIntensity = 0.6
        settings.dragIntensity = 0.9

        #expect(settings.intensity(for: .tap) == 0.3)
        #expect(settings.intensity(for: .modifier) == 0.6)
        #expect(settings.intensity(for: .drag) == 0.9)
    }
}

struct LayoutSettingsTests {
    private func createTestDefaults() -> UserDefaults {
        let suiteName = "test.layout.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    // MARK: - Initialization Tests

    @Test func initWithDefaultValues() {
        let defaults = createTestDefaults()
        let settings = LayoutSettings(defaults: defaults, shouldPersist: false)

        #expect(settings.utilityColumnLeading == false)
        // Note: keyAspectRatio, keyboardScale, keyboardHorizontalPosition
        // have device-dependent defaults
    }

    @Test func initLoadsPersistedValues() {
        let defaults = createTestDefaults()

        defaults.set(true, forKey: SettingsKey.utilityColumnLeading.rawValue)
        defaults.set(1.3, forKey: SettingsKey.keyAspectRatio.rawValue)
        defaults.set(0.8, forKey: SettingsKey.keyboardScale.rawValue)
        defaults.set(0.25, forKey: SettingsKey.keyboardHorizontalPosition.rawValue)

        let settings = LayoutSettings(defaults: defaults, shouldPersist: false)

        #expect(settings.utilityColumnLeading == true)
        #expect(abs(settings.keyAspectRatio - 1.3) < 0.01)
        #expect(abs(settings.keyboardScale - 0.8) < 0.01)
        #expect(abs(settings.keyboardHorizontalPosition - 0.25) < 0.01)
    }

    // MARK: - Clamping Tests

    @Test func aspectRatioClampedToValidRange() {
        let defaults = createTestDefaults()
        let settings = LayoutSettings(defaults: defaults, shouldPersist: false)

        settings.keyAspectRatio = 2.0 // above max (1.62)
        #expect(settings.keyAspectRatio == 1.62)

        settings.keyAspectRatio = 0.5 // below min (1.0)
        #expect(settings.keyAspectRatio == 1.0)
    }

    @Test func scaleClampedToValidRange() {
        let defaults = createTestDefaults()
        let settings = LayoutSettings(defaults: defaults, shouldPersist: false)

        settings.keyboardScale = 1.5 // above max (1.0)
        #expect(settings.keyboardScale == 1.0)

        settings.keyboardScale = 0.1 // below min (0.25)
        #expect(settings.keyboardScale == 0.25)
    }

    @Test func positionClampedToValidRange() {
        let defaults = createTestDefaults()
        let settings = LayoutSettings(defaults: defaults, shouldPersist: false)

        settings.keyboardHorizontalPosition = 1.5 // above max (1.0)
        #expect(settings.keyboardHorizontalPosition == 1.0)

        settings.keyboardHorizontalPosition = -0.5 // below min (0.0)
        #expect(settings.keyboardHorizontalPosition == 0.0)
    }

    // MARK: - Persistence Tests

    @Test func changesPersistToUserDefaults() {
        let defaults = createTestDefaults()
        let settings = LayoutSettings(defaults: defaults, shouldPersist: true)

        settings.utilityColumnLeading = true
        settings.keyAspectRatio = 1.4

        let savedLeading = defaults.bool(forKey: SettingsKey.utilityColumnLeading.rawValue)
        let savedRatio = defaults.double(forKey: SettingsKey.keyAspectRatio.rawValue)

        #expect(savedLeading == true)
        #expect(abs(savedRatio - 1.4) < 0.01)
    }

    // MARK: - Reload Tests

    @Test func reloadUpdatesFromUserDefaults() {
        let defaults = createTestDefaults()
        let settings = LayoutSettings(defaults: defaults, shouldPersist: false)

        defaults.set(true, forKey: SettingsKey.utilityColumnLeading.rawValue)
        defaults.set(1.5, forKey: SettingsKey.keyAspectRatio.rawValue)

        settings.reload()

        #expect(settings.utilityColumnLeading == true)
        #expect(abs(settings.keyAspectRatio - 1.5) < 0.01)
    }
}

// MARK: - SettingsKey Tests

struct SettingsKeyTests {
    @Test func settingsKeysHaveCorrectRawValues() {
        #expect(SettingsKey.hapticIntensityTap.rawValue == "hapticIntensityTap")
        #expect(SettingsKey.hapticEnabled.rawValue == "hapticEnabled")
        #expect(SettingsKey.utilityColumnLeading.rawValue == "utilityColumnLeading")
        #expect(SettingsKey.keyAspectRatio.rawValue == "keyAspectRatio")
        #expect(SettingsKey.keyboardScale.rawValue == "keyboardScale")
        #expect(SettingsKey.numpadStyle.rawValue == "numpadStyle")
    }
}
