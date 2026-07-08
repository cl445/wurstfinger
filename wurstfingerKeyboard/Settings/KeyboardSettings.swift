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
    /// Legacy master toggle — only read to migrate an explicit "off" into
    /// intensity 0, then removed.
    case hapticEnabled
    case utilityColumnLeading
    case keyAspectRatio
    /// Legacy fraction-of-screen-width size. Read once to migrate into
    /// `keyboardWidthPoints`; the stored value is kept for downgrade safety
    /// but no longer consulted afterwards.
    case keyboardScale
    /// Keyboard width wish in points (density- and orientation-independent).
    case keyboardWidthPoints
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
    /// Default intensity values (0.0 - 1.0). Both map to a discrete
    /// `HapticIntensityLevel`; level `.off` (intensity 0) disables the
    /// respective feedback, so there is no separate master switch.
    /// Defaults mirror the iOS system keyboard's subtle feel: a soft tap
    /// per keystroke, detent ticks for drags.
    static let defaultTapIntensity: CGFloat = HapticIntensityLevel.soft.storedIntensity
    static let defaultDragIntensity: CGFloat = HapticIntensityLevel.tick.storedIntensity

    private let defaults: UserDefaults
    private let shouldPersist: Bool

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
        tapIntensity = Self.loadIntensity(from: defaults, key: .hapticIntensityTap, default: Self.defaultTapIntensity)
        dragIntensity = Self.loadIntensity(from: defaults, key: .hapticIntensityDrag, default: Self.defaultDragIntensity)

        // Migrate the removed master toggle: an explicit "off" becomes level
        // `.off` on both sliders, so users who had haptics disabled stay
        // silent after the update.
        if defaults.object(forKey: SettingsKey.hapticEnabled.rawValue) as? Bool == false {
            tapIntensity = 0
            dragIntensity = 0
            if shouldPersist {
                defaults.set(0.0, forKey: SettingsKey.hapticIntensityTap.rawValue)
                defaults.set(0.0, forKey: SettingsKey.hapticIntensityDrag.rawValue)
            }
        }
        if shouldPersist {
            defaults.removeObject(forKey: SettingsKey.hapticEnabled.rawValue)
        }
    }

    /// Reload settings from UserDefaults (e.g., after changes from host app)
    func reload() {
        let newTap = Self.loadIntensity(from: defaults, key: .hapticIntensityTap, default: Self.defaultTapIntensity)
        if abs(tapIntensity - newTap) > 0.0001 { tapIntensity = newTap }

        let newDrag = Self.loadIntensity(from: defaults, key: .hapticIntensityDrag, default: Self.defaultDragIntensity)
        if abs(dragIntensity - newDrag) > 0.0001 { dragIntensity = newDrag }
    }

    /// Returns the intensity for a given haptic event type
    func intensity(for event: KeyboardHapticEvent) -> CGFloat {
        switch event {
        case .tap, .stateChange: tapIntensity
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

    /// Keyboard width wish in points. Range: 90 to 600.
    ///
    /// This is the *wish*: what the user asked for, independent of device
    /// and orientation. The rendered *result* may be smaller (fit-clamped by
    /// `KeyboardLayoutMetrics.resolve`), but the clamp is never written back.
    @Published var keyboardWidth: Double {
        didSet {
            let clamped = Self.clampWidth(keyboardWidth)
            if clamped != keyboardWidth {
                keyboardWidth = clamped
                return
            }
            persistIfNeeded(clamped, forKey: .keyboardWidthPoints)
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

        keyboardWidth = Self.loadWishWidth(from: defaults, shouldPersist: shouldPersist)

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

        let newWidth = Self.loadWishWidth(from: defaults, shouldPersist: shouldPersist)
        if keyboardWidth != newWidth { keyboardWidth = newWidth }

        let savedPosition = defaults.object(forKey: SettingsKey.keyboardHorizontalPosition.rawValue) as? Double
            ?? DeviceLayoutUtils.defaultKeyboardPosition
        let newPosition = Self.clampPosition(savedPosition)
        if keyboardHorizontalPosition != newPosition { keyboardHorizontalPosition = newPosition }
    }

    // MARK: - Layout Metrics

    /// Resolves the persisted wish (width + aspect ratio) into concrete
    /// metrics for a render context. Pure: fit-clamps shrink the result but
    /// never write back to the store.
    func resolveMetrics(columns: Int, availableWidth: CGFloat, screenHeight: CGFloat) -> KeyboardLayoutMetrics {
        KeyboardLayoutMetrics.resolve(
            wishWidth: keyboardWidth,
            aspectRatio: keyAspectRatio,
            columns: columns,
            availableWidth: availableWidth,
            screenHeight: screenHeight
        )
    }

    // MARK: - Migration

    /// Performs the one-time legacy `keyboardScale` → `keyboardWidthPoints`
    /// migration without constructing a settings instance. The host app calls
    /// this at launch **before** registering defaults (a registered width
    /// would make the key appear present and mask a pending migration); the
    /// extension migrates in `init`/`reload`.
    static func migrateLegacyScaleIfNeeded(in defaults: UserDefaults) {
        _ = loadWishWidth(from: defaults, shouldPersist: true)
    }

    /// Loads the wish width, migrating a legacy `keyboardScale` exactly once.
    ///
    /// - A stored `keyboardWidthPoints` always wins (clamped on load).
    /// - Otherwise a user-persisted legacy scale (fraction of screen width)
    ///   is converted against the orientation-stable shortest screen side —
    ///   on iPhone this preserves the rendered width existing users see —
    ///   and persisted once. The legacy key stays in the store for downgrade
    ///   safety; it is simply no longer read afterwards.
    /// - With neither present, the device-class default applies and is NOT
    ///   persisted (fallback only, like the other layout defaults).
    private static func loadWishWidth(from defaults: UserDefaults, shouldPersist: Bool) -> Double {
        if let stored = defaults.object(forKey: SettingsKey.keyboardWidthPoints.rawValue) as? Double {
            return clampWidth(stored)
        }
        if let legacyScale = defaults.object(forKey: SettingsKey.keyboardScale.rawValue) as? Double {
            let bounds = DeviceLayoutUtils.screenBounds
            let shortestSide = min(bounds.width, bounds.height)
            let clampedScale = min(1.0, max(0.25, legacyScale))
            let width = clampWidth(clampedScale * shortestSide)
            if shouldPersist {
                defaults.set(width, forKey: SettingsKey.keyboardWidthPoints.rawValue)
            }
            return width
        }
        return DeviceLayoutUtils.defaultKeyboardWidth
    }

    // MARK: - Private Helpers

    /// Aspect ratio range: 1.0 (square) to 1.62 (golden ratio)
    private static func clampAspectRatio(_ value: Double) -> Double {
        min(1.62, max(1.0, value))
    }

    /// Wish-width range in points: 90 (below the old 0.25×iPhone-mini
    /// minimum) to 600 (beyond any full iPhone width, room for iPad tuning).
    private static func clampWidth(_ value: Double) -> Double {
        min(600, max(90, value))
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
    case liquidGlass // iOS 26+ Liquid Glass effect (renders as a simplified translucent style on older iOS)

    var displayName: String {
        switch self {
        case .classic:
            String(localized: "Classic")
        case .liquidGlass:
            String(localized: "Liquid Glass")
        }
    }

    var description: String {
        switch self {
        case .classic:
            String(localized: "Traditional opaque keys")
        case .liquidGlass:
            String(localized: "Transparent glass effect (iOS 26+)")
        }
    }
}
