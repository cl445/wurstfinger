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
        InMemoryUserDefaults()
    }

    // MARK: - Initialization Tests

    @Test func initWithDefaultValues() {
        let defaults = createTestDefaults()
        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        #expect(settings.tapIntensity == HapticSettings.defaultTapIntensity)
        #expect(settings.dragIntensity == HapticSettings.defaultDragIntensity)
    }

    @Test func initLoadsPersistedValues() {
        let defaults = createTestDefaults()

        // Pre-populate UserDefaults
        defaults.set(0.3, forKey: SettingsKey.hapticIntensityTap.rawValue)
        defaults.set(0.9, forKey: SettingsKey.hapticIntensityDrag.rawValue)

        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        #expect(abs(settings.tapIntensity - 0.3) < 0.01)
        #expect(abs(settings.dragIntensity - 0.9) < 0.01)
    }

    // MARK: - Legacy Master Toggle Migration

    @Test func legacyDisabledToggleMigratesToOffLevels() {
        let defaults = createTestDefaults()
        defaults.set(false, forKey: SettingsKey.hapticEnabled.rawValue)
        defaults.set(0.5, forKey: SettingsKey.hapticIntensityTap.rawValue)
        defaults.set(0.9, forKey: SettingsKey.hapticIntensityDrag.rawValue)

        let settings = HapticSettings(defaults: defaults, shouldPersist: true)

        #expect(settings.tapIntensity == 0)
        #expect(settings.dragIntensity == 0)
        #expect(defaults.double(forKey: SettingsKey.hapticIntensityTap.rawValue) == 0)
        #expect(defaults.object(forKey: SettingsKey.hapticEnabled.rawValue) == nil)
    }

    @Test func legacyEnabledToggleKeepsIntensities() {
        let defaults = createTestDefaults()
        defaults.set(true, forKey: SettingsKey.hapticEnabled.rawValue)
        defaults.set(0.5, forKey: SettingsKey.hapticIntensityTap.rawValue)

        let settings = HapticSettings(defaults: defaults, shouldPersist: true)

        #expect(abs(settings.tapIntensity - 0.5) < 0.01)
        #expect(defaults.object(forKey: SettingsKey.hapticEnabled.rawValue) == nil)
    }

    @Test func migrationDoesNotPersistWhenPersistenceDisabled() {
        let defaults = createTestDefaults()
        defaults.set(false, forKey: SettingsKey.hapticEnabled.rawValue)

        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        #expect(settings.tapIntensity == 0)
        #expect(defaults.object(forKey: SettingsKey.hapticEnabled.rawValue) != nil)
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

        // Verify persisted
        let savedIntensity = defaults.double(forKey: SettingsKey.hapticIntensityTap.rawValue)

        #expect(abs(savedIntensity - 0.7) < 0.01)
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

        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        // Should fall back to defaults, not use 0.0
        #expect(settings.tapIntensity == HapticSettings.defaultTapIntensity)
    }

    @Test func missingDefaultsFallBackCorrectly() {
        let defaults = createTestDefaults()
        // Don't set any values — all should be defaults
        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        #expect(settings.tapIntensity == HapticSettings.defaultTapIntensity)
        #expect(settings.dragIntensity == HapticSettings.defaultDragIntensity)
    }

    // MARK: - Intensity For Event Tests

    @Test func intensityForEventReturnsCorrectValue() {
        let defaults = createTestDefaults()
        let settings = HapticSettings(defaults: defaults, shouldPersist: false)

        settings.tapIntensity = 0.3
        settings.dragIntensity = 0.9

        #expect(settings.intensity(for: .tap) == 0.3)
        #expect(settings.intensity(for: .drag) == 0.9)
    }
}

struct LayoutSettingsTests {
    private func createTestDefaults() -> UserDefaults {
        InMemoryUserDefaults()
    }

    // MARK: - Initialization Tests

    @Test func initWithDefaultValues() {
        let defaults = createTestDefaults()
        let settings = LayoutSettings(defaults: defaults, shouldPersist: false)

        #expect(settings.utilityColumnLeading == false)
        // The width default is a device-class constant, deliberately not
        // derived from (orientation-dependent) screen bounds.
        #expect(settings.keyboardWidth == DeviceLayoutUtils.defaultKeyboardWidth)
    }

    @Test func initLoadsPersistedValues() {
        let defaults = createTestDefaults()

        defaults.set(true, forKey: SettingsKey.utilityColumnLeading.rawValue)
        defaults.set(1.3, forKey: SettingsKey.keyAspectRatio.rawValue)
        defaults.set(300.0, forKey: SettingsKey.keyboardWidthPoints.rawValue)
        defaults.set(0.25, forKey: SettingsKey.keyboardHorizontalPosition.rawValue)

        let settings = LayoutSettings(defaults: defaults, shouldPersist: false)

        #expect(settings.utilityColumnLeading == true)
        #expect(abs(settings.keyAspectRatio - 1.3) < 0.01)
        #expect(abs(settings.keyboardWidth - 300.0) < 0.01)
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

    @Test func widthClampedToValidRange() {
        let defaults = createTestDefaults()
        let settings = LayoutSettings(defaults: defaults, shouldPersist: false)

        settings.keyboardWidth = 10000 // above max (600)
        #expect(settings.keyboardWidth == 600)

        settings.keyboardWidth = 10 // below min (90)
        #expect(settings.keyboardWidth == 90)
    }

    @Test func widthClampedOnLoad() {
        let defaults = createTestDefaults()
        defaults.set(10000.0, forKey: SettingsKey.keyboardWidthPoints.rawValue)

        let settings = LayoutSettings(defaults: defaults, shouldPersist: false)

        #expect(settings.keyboardWidth == 600)
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

// MARK: - Legacy Scale Migration Tests

struct LayoutSettingsMigrationTests {
    private var shortestScreenSide: Double {
        Double(min(DeviceLayoutUtils.screenBounds.width, DeviceLayoutUtils.screenBounds.height))
    }

    @Test func legacyScaleMigratesToWidthAndPersistsOnce() {
        let defaults = InMemoryUserDefaults()
        defaults.set(0.5, forKey: SettingsKey.keyboardScale.rawValue)

        let settings = LayoutSettings(defaults: defaults, shouldPersist: true)

        // Converted against the orientation-stable shortest screen side, so
        // the rendered portrait width existing users see is preserved.
        let expected = 0.5 * shortestScreenSide
        #expect(abs(settings.keyboardWidth - expected) < 0.01)
        let persisted = defaults.object(forKey: SettingsKey.keyboardWidthPoints.rawValue) as? Double
        #expect(persisted != nil)
        #expect(abs((persisted ?? 0) - expected) < 0.01)
        // Downgrade safety: the legacy key stays in the store.
        #expect(defaults.object(forKey: SettingsKey.keyboardScale.rawValue) as? Double == 0.5)
    }

    @Test func migrationIsIdempotentOnSecondLoad() {
        let defaults = InMemoryUserDefaults()
        defaults.set(0.5, forKey: SettingsKey.keyboardScale.rawValue)

        let first = LayoutSettings(defaults: defaults, shouldPersist: true)
        let migratedWidth = first.keyboardWidth

        // A later legacy-scale change must be ignored: the persisted width
        // is now the single source of truth.
        defaults.set(0.9, forKey: SettingsKey.keyboardScale.rawValue)
        let second = LayoutSettings(defaults: defaults, shouldPersist: true)

        #expect(second.keyboardWidth == migratedWidth)
    }

    @Test func freshInstallUsesDeviceDefaultWithoutPersisting() {
        let defaults = InMemoryUserDefaults()

        let settings = LayoutSettings(defaults: defaults, shouldPersist: true)

        #expect(settings.keyboardWidth == DeviceLayoutUtils.defaultKeyboardWidth)
        // The default is a fallback, never written (consistent with the
        // registered-defaults behavior of the other layout settings).
        #expect(defaults.object(forKey: SettingsKey.keyboardWidthPoints.rawValue) == nil)
    }

    @Test func existingWidthWinsOverLegacyScale() {
        let defaults = InMemoryUserDefaults()
        defaults.set(0.5, forKey: SettingsKey.keyboardScale.rawValue)
        defaults.set(333.0, forKey: SettingsKey.keyboardWidthPoints.rawValue)

        let settings = LayoutSettings(defaults: defaults, shouldPersist: true)

        #expect(settings.keyboardWidth == 333.0)
    }

    @Test func nonPersistingInstanceMigratesWithoutWriting() {
        let defaults = InMemoryUserDefaults()
        defaults.set(0.5, forKey: SettingsKey.keyboardScale.rawValue)

        let settings = LayoutSettings(defaults: defaults, shouldPersist: false)

        let expected = 0.5 * shortestScreenSide
        #expect(abs(settings.keyboardWidth - expected) < 0.01)
        #expect(defaults.object(forKey: SettingsKey.keyboardWidthPoints.rawValue) == nil)
    }

    @Test func standaloneMigrationHelperPersistsTheWidth() {
        let defaults = InMemoryUserDefaults()
        defaults.set(0.5, forKey: SettingsKey.keyboardScale.rawValue)

        // The host app runs this at launch before registering defaults.
        LayoutSettings.migrateLegacyScaleIfNeeded(in: defaults)

        let persisted = defaults.object(forKey: SettingsKey.keyboardWidthPoints.rawValue) as? Double
        #expect(persisted != nil)
        #expect(abs((persisted ?? 0) - 0.5 * shortestScreenSide) < 0.01)
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
        #expect(SettingsKey.keyboardWidthPoints.rawValue == "keyboardWidthPoints")
        #expect(SettingsKey.numpadStyle.rawValue == "numpadStyle")
    }
}
