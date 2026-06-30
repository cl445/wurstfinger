//
//  KeyboardSettings.swift
//  Wurstfinger
//
//  Extracted from KeyboardViewModel to reduce code duplication
//  and improve separation of concerns.
//

import Combine
import CoreGraphics
import Foundation

// MARK: - Settings Keys

/// Centralized storage for all UserDefaults keys used by the keyboard.
/// Using an enum prevents typos and makes refactoring easier.
enum SettingsKey: String {
    case hapticIntensityTap
    case hapticIntensityDrag
    case hapticEnabled
    case utilityColumnLeading
    case keyAspectRatio
    case keyboardScale
    case keyboardHorizontalPosition
    case numpadStyle
    case selectedLanguageId
    case enabledLanguageIds
    case pinnedLanguageId
    case autoCapitalizeEnabled
    case expertModeEnabled
    case keyboardStyle
    case keyboardFullAccess
    case cursorMovementStyle
    case hideLetters
    case hideStandardSymbols
    case hideExtraSymbols
}

// MARK: - Haptic Settings

/// Encapsulates all haptic-related settings with built-in persistence.
/// Eliminates duplicate didSet handlers by using a unified approach.
final class HapticSettings: ObservableObject {
    /// Default intensity values (0.0 - 1.0)
    static let defaultTapIntensity: CGFloat = 0.5
    static let defaultDragIntensity: CGFloat = 0.5

    private let defaults: UserDefaults
    private let shouldPersist: Bool

    @Published var enabled: Bool {
        didSet { persistIfNeeded(enabled, forKey: .hapticEnabled) }
    }

    @Published var tapIntensity: CGFloat {
        didSet {
            let clamped = Self.clamp(tapIntensity)
            if clamped != tapIntensity {
                tapIntensity = clamped
                return
            }
            persistIfNeeded(Double(clamped), forKey: .hapticIntensityTap)
        }
    }

    @Published var dragIntensity: CGFloat {
        didSet {
            let clamped = Self.clamp(dragIntensity)
            if clamped != dragIntensity {
                dragIntensity = clamped
                return
            }
            persistIfNeeded(Double(clamped), forKey: .hapticIntensityDrag)
        }
    }

    init(defaults: UserDefaults = SharedDefaults.store, shouldPersist: Bool = true) {
        self.defaults = defaults
        self.shouldPersist = shouldPersist

        // Load values with clamping
        enabled = defaults.object(forKey: SettingsKey.hapticEnabled.rawValue) as? Bool ?? true
        tapIntensity = Self.loadIntensity(from: defaults, key: .hapticIntensityTap, default: Self.defaultTapIntensity)
        dragIntensity = Self.loadIntensity(from: defaults, key: .hapticIntensityDrag, default: Self.defaultDragIntensity)
    }

    /// Reload settings from UserDefaults (e.g., after changes from host app)
    func reload() {
        let newEnabled = defaults.object(forKey: SettingsKey.hapticEnabled.rawValue) as? Bool ?? true
        if enabled != newEnabled { enabled = newEnabled }

        let newTap = Self.loadIntensity(from: defaults, key: .hapticIntensityTap, default: Self.defaultTapIntensity)
        if abs(tapIntensity - newTap) > 0.0001 { tapIntensity = newTap }

        let newDrag = Self.loadIntensity(from: defaults, key: .hapticIntensityDrag, default: Self.defaultDragIntensity)
        if abs(dragIntensity - newDrag) > 0.0001 { dragIntensity = newDrag }
    }

    /// Returns the intensity for a given haptic event type
    func intensity(for event: KeyboardHapticEvent) -> CGFloat {
        switch event {
        case .tap: tapIntensity
        case .drag: dragIntensity
        }
    }

    // MARK: - Private Helpers

    private static func loadIntensity(from defaults: UserDefaults, key: SettingsKey, default defaultValue: CGFloat) -> CGFloat {
        guard let stored = defaults.object(forKey: key.rawValue) as? NSNumber else {
            return defaultValue
        }
        return clamp(CGFloat(stored.doubleValue))
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    private func persistIfNeeded(_ value: some Any, forKey key: SettingsKey) {
        guard shouldPersist else { return }
        defaults.set(value, forKey: key.rawValue)
    }
}

// MARK: - Layout Settings

/// Encapsulates keyboard layout settings (position, scale, aspect ratio).
final class LayoutSettings: ObservableObject {
    private let defaults: UserDefaults
    private let shouldPersist: Bool

    @Published var utilityColumnLeading: Bool {
        didSet { persistIfNeeded(utilityColumnLeading, forKey: .utilityColumnLeading) }
    }

    /// Key aspect ratio (width/height). Range: 1.0 (square) to 1.62 (golden ratio)
    @Published var keyAspectRatio: Double {
        didSet {
            let clamped = Self.clampAspectRatio(keyAspectRatio)
            if clamped != keyAspectRatio {
                keyAspectRatio = clamped
                return
            }
            persistIfNeeded(clamped, forKey: .keyAspectRatio)
        }
    }

    /// Keyboard scale relative to screen width. Range: 0.25 to 1.0
    @Published var keyboardScale: Double {
        didSet {
            let clamped = Self.clampScale(keyboardScale)
            if clamped != keyboardScale {
                keyboardScale = clamped
                return
            }
            persistIfNeeded(clamped, forKey: .keyboardScale)
        }
    }

    /// Horizontal position (0.0 = left, 0.5 = center, 1.0 = right)
    @Published var keyboardHorizontalPosition: Double {
        didSet {
            let clamped = Self.clampPosition(keyboardHorizontalPosition)
            if clamped != keyboardHorizontalPosition {
                keyboardHorizontalPosition = clamped
                return
            }
            persistIfNeeded(clamped, forKey: .keyboardHorizontalPosition)
        }
    }

    init(defaults: UserDefaults = SharedDefaults.store, shouldPersist: Bool = true) {
        self.defaults = defaults
        self.shouldPersist = shouldPersist

        utilityColumnLeading = defaults.object(forKey: SettingsKey.utilityColumnLeading.rawValue) as? Bool ?? false

        let savedRatio = defaults.object(forKey: SettingsKey.keyAspectRatio.rawValue) as? Double
            ?? DeviceLayoutUtils.defaultKeyAspectRatio
        keyAspectRatio = Self.clampAspectRatio(savedRatio)

        let savedScale = defaults.object(forKey: SettingsKey.keyboardScale.rawValue) as? Double
            ?? DeviceLayoutUtils.defaultKeyboardScale
        keyboardScale = Self.clampScale(savedScale)

        let savedPosition = defaults.object(forKey: SettingsKey.keyboardHorizontalPosition.rawValue) as? Double
            ?? DeviceLayoutUtils.defaultKeyboardPosition
        keyboardHorizontalPosition = Self.clampPosition(savedPosition)
    }

    /// Reload settings from UserDefaults
    func reload() {
        let newUtility = defaults.object(forKey: SettingsKey.utilityColumnLeading.rawValue) as? Bool ?? false
        if utilityColumnLeading != newUtility { utilityColumnLeading = newUtility }

        let savedRatio = defaults.object(forKey: SettingsKey.keyAspectRatio.rawValue) as? Double
            ?? DeviceLayoutUtils.defaultKeyAspectRatio
        let newRatio = Self.clampAspectRatio(savedRatio)
        if keyAspectRatio != newRatio { keyAspectRatio = newRatio }

        let savedScale = defaults.object(forKey: SettingsKey.keyboardScale.rawValue) as? Double
            ?? DeviceLayoutUtils.defaultKeyboardScale
        let newScale = Self.clampScale(savedScale)
        if keyboardScale != newScale { keyboardScale = newScale }

        let savedPosition = defaults.object(forKey: SettingsKey.keyboardHorizontalPosition.rawValue) as? Double
            ?? DeviceLayoutUtils.defaultKeyboardPosition
        let newPosition = Self.clampPosition(savedPosition)
        if keyboardHorizontalPosition != newPosition { keyboardHorizontalPosition = newPosition }
    }

    // MARK: - Private Helpers

    /// Aspect ratio range: 1.0 (square) to 1.62 (golden ratio)
    private static func clampAspectRatio(_ value: Double) -> Double {
        min(1.62, max(1.0, value))
    }

    /// Scale range: 0.25 (iPad minimum) to 1.0 (full width)
    private static func clampScale(_ value: Double) -> Double {
        min(1.0, max(0.25, value))
    }

    /// Position range: 0.0 (left) to 1.0 (right)
    private static func clampPosition(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    private func persistIfNeeded(_ value: some Any, forKey key: SettingsKey) {
        guard shouldPersist else { return }
        defaults.set(value, forKey: key.rawValue)
    }
}

// MARK: - Numpad Style

enum NumpadStyle: String, CaseIterable {
    case phone // 1-2-3 / 4-5-6 / 7-8-9 (default, like phone keypad)
    case classic // 7-8-9 / 4-5-6 / 1-2-3 (like calculator)
}

// MARK: - Cursor Movement Style

/// Space bar cursor movement style
enum CursorMovementStyle: String, CaseIterable {
    case continuous // Joystick-style: drag distance controls cursor position
    case discrete // MessagEase-style: one swipe = one character, return-swipe = one word
}

// MARK: - Keyboard Style

/// Visual style for the keyboard appearance
enum KeyboardStyle: String, CaseIterable {
    case classic // Traditional opaque key backgrounds
    case liquidGlass // iOS 26+ Liquid Glass effect (falls back to classic on older iOS)

    var displayName: String {
        switch self {
        case .classic:
            "Classic"
        case .liquidGlass:
            "Liquid Glass"
        }
    }

    var description: String {
        switch self {
        case .classic:
            "Traditional opaque keys"
        case .liquidGlass:
            "Transparent glass effect (iOS 26+)"
        }
    }
}
