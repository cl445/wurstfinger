# Changelog

## Unreleased

### Fixed
- Fix iOS reporting wrong keyboard language for spell-check and autocorrect (#96)
- Auto-capitalization now re-evaluates after deleting characters (#88)
- Apostrophe no longer triggers compose/accent mode; dedicated ´ compose key remains for accented characters (#89)
- Fix UserDefaults CGFloat casting with `double(forKey:)` for reliable settings loading
- Fix angle boundary overlap in swipe direction detection (half-open ranges)
- Fix non-deterministic accent cycle order
- Replace `fatalError` with `assertionFailure` in layout creation to prevent production crashes
- Fix `@AppStorage` default mismatches (use `DeviceLayoutUtils` constants instead of hardcoded 1.0)
- Fix `selectedLanguage` fallback from `.german` to `.english` for consistency
- Fix hardcoded version "1.0.0" in settings — now reads from bundle
- Fix deprecated APIs and SwiftUI view anti-patterns

### Added
- Tests for KeyboardDirection, RingBuffer, circular gestures, layout validation, and ComposeEngine
- 50+ new tests for settings, haptics, Vector2D, and gesture calculations
- Accessibility labels for globe and return keys

### Changed
- Extract settings into HapticSettings/LayoutSettings classes
- Create HapticFeedbackManager for centralized haptic feedback
- Add Vector2D type with division-by-zero guard
- Extract GestureCalculations helpers and centralize GeometryUtils
- Consolidate SettingsKey enum usage, remove raw key strings
- Make SharedDefaults.store a cached `let` instead of computed `var`
- Make LanguageSettings.init() private (singleton pattern)
- Config-based return overrides instead of hardcoded letters
- Deterministic MessagEaseKey IDs using center character
- Cached haptic feedback generator
- Consolidate DeleteKeyButton @State into GestureState struct

## v1.1.1 (Draft)

### Fixed
- Restored missing apostrophe (') on the e-key

## v1.1.0

_Initial public release with multi-language support._

## v1.0.0

_First release._
