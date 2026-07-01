# Changelog

## Unreleased

## v1.3.0 — 2026-06-30

### Added

- In-keyboard language switching — cycle through enabled languages with a swipe on the globe key (#199, #135)
- Label visibility — hide letters, standard symbols, or extra symbols independently to choose which labels appear on the keys (#200)
- App localization in 12 languages (#189)
- Vietnamese Telex input method (#134)
- Cursor movement style setting — continuous or step-by-step, with word-wise movement (#173)
- Numpad style setting — phone or classic layout (#172)
- Extensive new test coverage: gesture classification, action pipeline, middlewares, compose integrity, accessibility, and end-to-end typing UI tests (#181, #182, #183, #186, #188)

### Fixed

- Fix Liquid Glass inter-key dead zones — taps in the gaps between keys now register in the real keyboard extension (#198)
- Fix landscape keyboard crash with multi-row key rendering (#193)
- Guarantee the keyboard always renders a layout and never comes up blank (#196)
- Harden the keyboard extension against memory jetsam so it opens more reliably (#190)
- Re-anchor the gesture origin on ring-buffer overflow for reliable long gestures (#174)
- Fix auto-capitalization whitespace handling, layout validation, and force-unwrap risks (#177)
- Harden settings loading against UserDefaults suite crashes (#185)

### Changed

- Restructure the keyboard extension into a data-driven architecture (Definition/Runtime/Settings): layouts are declared as data and executed by a generic runtime (#169, plus the #155–#168 series)
- Keep the portrait key arrangement in landscape orientation (#197)
- Gesture tuning: delete-step, turn angle, and slide dead-zone thresholds (#175)
- Settings robustness: pipeline cache and text-field input clamps (#176)
- Run CI unit tests serially to avoid flaky simulator-clone failures (#192)

## v1.2.0 — 2026-04-04

### Fixed

- Eliminate dead zones on keyboard surface — every pixel now responds to touch (#125)
- Fix keyboard content gap by replacing scaleEffect with direct scaling (#124)
- Fix keyboard misalignment after orientation change while backgrounded (#92)
- Fix French layout return swipe on center key producing U instead of H; all center key return overrides are now config-driven (#94)
- Fix auto-capitalization after delete canceling manual temporary shift (#113)
- Fix angle boundary overlap in swipe direction detection (half-open ranges)
- Fix non-deterministic accent cycle order
- Replace `fatalError` with `assertionFailure` in layout creation to prevent production crashes
- Fix hardcoded version "1.0.0" in settings — now reads from bundle
- Set `PrimaryLanguage` to `mul` (multi-language) and read active language directly from SharedDefaults so iOS Settings shows the correct keyboard language (#96)
- Auto-capitalization now re-evaluates after deleting characters (#88)
- Fix UserDefaults `as? CGFloat` casting with `double(forKey:)` for reliable settings loading
- Lower height constraint priority to `.defaultHigh` to prevent Auto Layout conflicts
- Fix deprecated APIs and SwiftUI view anti-patterns
- Fix apostrophe triggering compose/accent mode (#101)

### Added

- Haptic feedback now fires on touch-down instead of action completion for snappier feel (#121)
- FAQ section documenting iOS limitations (#86)
- Accessibility labels for globe and return keys
- 50+ new tests for settings, haptics, Vector2D, and gesture calculations (#90)
- Tests for KeyboardDirection, RingBuffer, circular gestures, layout validation, and ComposeEngine
- SwiftLint, SwiftFormat, and Periphery dead code detection in CI
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
- Upgrade GitHub Actions to latest versions (Node.js 24)

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
- 15 keyboard languages: Catalan, Croatian, English, Estonian-Finnish, Finnish, French, German, Hebrew, Italian, Polish, Russian, Spanish, Swedish, Tagalog, Vietnamese (with Telex input)
- Compose rules: create accented characters by combining keys (e.g., ' + a → á)
- Circular gestures: draw a circle on a letter for uppercase
- Cursor control: drag on space bar to move cursor, long-press for text selection
- Haptic feedback: customizable vibration intensity (requires Full Access)
- Privacy-focused: no data collection, no network access
