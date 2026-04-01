# Changelog

## Unreleased

### Fixed

- Fix angle boundary overlap in swipe direction detection (half-open ranges)
- Fix non-deterministic accent cycle order
- Replace `fatalError` with `assertionFailure` in layout creation to prevent production crashes
- Fix hardcoded version "1.0.0" in settings — now reads from bundle
- Set `PrimaryLanguage` to `mul` (multi-language) and read active language directly from SharedDefaults so iOS Settings shows the correct keyboard language (#96)
- Auto-capitalization now re-evaluates after deleting characters (#88)
- Fix UserDefaults `as? CGFloat` casting with `double(forKey:)` for reliable settings loading
- Lower height constraint priority to `.defaultHigh` to prevent Auto Layout conflicts
- Fix deprecated APIs and SwiftUI view anti-patterns

### Added

- Accessibility labels for globe and return keys
- 50+ new tests for settings, haptics, Vector2D, and gesture calculations (#90)
- Tests for KeyboardDirection, RingBuffer, circular gestures, layout validation, and ComposeEngine (723 lines)
- CodeRabbit configuration for automated PR reviews

### Changed

- Consolidate all `@AppStorage` keys to use `SettingsKey` enum
- Fix `@AppStorage` defaults to use `DeviceLayoutUtils` constants instead of hardcoded 1.0
- Change `SharedDefaults.store` from computed `var` to cached `let`
- Make `LanguageSettings.init()` private (singleton pattern)
- Fix `selectedLanguage` fallback from `.german` to `.english` for consistency
- Remove deprecated `userDefaults.synchronize()` call
- Extract settings into HapticSettings/LayoutSettings classes (#90)
- Create HapticFeedbackManager for centralized haptic feedback (#90)
- Add Vector2D type with division-by-zero guard (#90)
- Extract GestureCalculations helpers and centralize GeometryUtils (#90)
- Convert `GestureFeatures.thresholds` from `static var` to instance `let`
- Filter `UserDefaults.didChangeNotification` to shared defaults instance only
- Deterministic MessagEaseKey IDs using center character
- Config-based return overrides instead of hardcoded letters
- Single-pass boundingBox calculation
- Cached haptic feedback generator
- Pass value types to KeyHintOverlay instead of ViewModel
- Consolidate DeleteKeyButton @State into GestureState struct
- Explicit LanguageConfig Equatable by id

## v1.1.1 — 2025-12-28

### Fixed

- Restore missing apostrophe (') on the e-key
- Fix settings persistence
- Fix Swedish å character

### Changed

- Restrict to iPhone only (defer iPad to future release)
- Remove misplaced screenshots folder from metadata

## v1.1.0 — 2025-12-27

### Added

- Clipboard actions: Copy, Cut & Paste via swipe gestures
- Bidirectional delete: swipe left/right on Delete key
- Auto-capitalization after sentence punctuation
- Globe key: dismiss keyboard via swipe
- iOS 18+ Dark Mode & Tinted App Icons
- Liquid Glass style for iOS 26+
- Extended touch areas between keys
- Expert Settings for gesture tuning
- Gesture Playground for testing

### Fixed

- Swipe direction detection on non-square buttons
- Keyboard background fills entire area
- Haptic feedback settings persistence

### Changed

- Swedish: added missing å character
- Better circular gesture detection
- Optimized landscape support
- Performance optimizations

## v1.0.0 — 2025-12-06

Initial public release of Wurstfinger — a MessagEase-inspired keyboard for iOS.

### Features

- Gesture-based typing: tap center for primary letters, swipe in 8 directions for additional characters
- 14 keyboard languages: German, English, Spanish, French, Italian, Portuguese, Dutch, Polish, Swedish, Norwegian, Danish, Finnish, Turkish, Vietnamese
- Compose rules: create accented characters by combining keys (e.g., ' + a → á)
- Circular gestures: draw a circle on a letter for uppercase
- Cursor control: drag on space bar to move cursor, long-press for text selection
- Haptic feedback: customizable vibration intensity (requires Full Access)
- Privacy-focused: no data collection, no network access
