# Changelog

## Unreleased

### Added

- The naming glossary is now checkable: its vocabulary lives in `glossary.toml` with a zone per term (internal, persisted, or user-facing contract), `scripts/check_naming.py` reports every identifier that contradicts it, and `.naming-budget.json` freezes the existing backlog per file so it can shrink but never grow. Sections 7 to 9 of `docs/GLOSSARY.md` are generated from the same source, so the list of rejected spellings and the list of what is actually enforced cannot drift apart

### Fixed

- Flicks that launch out of a rolling start are recognized again. A flick that follows a slight drag — settling on the key, then flicking — lost every one of its fast samples, because the filter measured them against the drift and a drift is slow by definition. The letter that got committed came from the drift instead, which for a drift running across the flick is a neighbouring letter rather than the center one. A jump is now measured against the longer of the movement already established and the movement it leads into (#303)

## v1.4.1 — 2026-08-09

### Added

- Optional gesture trail — a soft, tapered stroke follows the finger while it swipes and fades out when it lifts, in the style of the iOS keyboard's swipe trail. A press that never moves leaves a dot, so a plain keystroke is visible too. Off by default, enabled under Settings › Gestures (#279, #289)
- A naming glossary (`docs/GLOSSARY.md`) that pins down the codebase's domain vocabulary: modes, keys, gestures, pipeline stages, and the type-suffix and function-verb rules (#291, #294)
- Markdown linting (markdownlint) as a pre-commit hook and a CI check (#292)

### Fixed

- Fast flicks are recognized as swipes again instead of committing the key's center letter. The outlier filter judged each sample only by where it landed, so a fling that covered more than the jump budget per sample lost every one of its samples and the classifier saw a tap. It now also weighs the direction the accepted path established, and keeps a jump that continues it within 45° and three times the previous step (#295)
- Characters that could not be typed at all on the non-Latin layouts: Thai ฬ ฒ ฑ ฏ (circle gesture) and the baht sign ฿, the Japanese 、 and 。 plus the small kana on return swipes, the Persian/Urdu half-space (ZWNJ), Arabic-script punctuation ؟ ، ؛ ٭ in place of the Latin marks, the Hindi rupee sign ₹, and the Hebrew geresh and gershayim ׳ ״ (#284)
- The voiced kana iteration marks ゞ and ヾ: they ride the return swipe of ゝ/ヽ and the ゛ key voices them too, instead of being reachable only through the accent cycle (#290)
- Forward-delete and capitalize-word with an active selection: forward-delete now removes the selection, and capitalize-word changes the case of the selection instead of eating the word in front of it (#281)
- The double-space shortcut now requires two consecutive space presses within a short window, so a space typed into an already-finished sentence is no longer rewritten and a deliberate double space stays typable; it also inserts the script's own sentence mark (Devanagari danda, Japanese full-width stop, Urdu full stop) (#281)
- Cut-all is bounded by the same size ceiling as a paste instead of issuing an unbounded number of delete round-trips to the host app (#281)
- Returning to an app that was in the background now brings the keyboard back fully refreshed: settings, language, size and auto-capitalization changed in the meantime take effect before the first keystroke instead of the keyboard resurfacing on stale state (#277)
- The app switcher no longer shows an empty gap where the keyboard was — a frozen stand-in keeps the card intact, and it neither swallows taps nor shows up in VoiceOver (#277)
- Diagonal drags on the delete key are no longer dropped: a delete slide that drifts upwards deletes instead of doing nothing at all (#282)
- A long press that was still armed when its key disappeared — switching mode or language mid-hold — no longer types the old key's digit into the new mode (#282)
- VoiceOver reaches keys it could not before: activating the globe switches the input mode, and swipe-only actions such as copy, cut, paste and hide keyboard are offered as rotor actions (#283). Shift, the sentence punctuation and the mode keys carry semantic names too, where VoiceOver used to announce the mode switches as the number `123` and the letters `abc` and offered no way to reach shift at all (#283, #295). Outside that named set the swipe outputs stay unreachable: a letter key offers only its center character, and no key offers its return swipes. Naming all eight directions would put eight to sixteen rotor entries on every key, so exposing swipe output as spoken-glyph actions is follow-up design work (#295)
- Key labels can no longer outgrow their key at the smallest keyboard sizes (#283)
- Size & Position was shown in English whatever the app language, and its explanation was compressed into a single truncated line; the controls now scroll below the pinned preview like on the other preview screens (#286, #295)
- 70 translations across the 23 app languages that were wrong rather than missing: a Hebrew setting described the opposite of what the toggle does, ten languages still promised a keyboard style that no longer exists, Arabic rendered `(1-2-3)` mirrored, and French and Portuguese translated the golden ratio as the colour gold (#295)
- The key aspect-ratio subtitle read `1:1.00` and reordered its parts under right-to-left scripts, because only the number was substituted into the sentence (#295)
- Both privacy manifests declared the UserDefaults reason code that explicitly excludes cross-app access, although the dominant use on both sides is the shared app group (#295)
- The gesture playground drew an 81 pt key while the keyboard itself resolves 57.75 pt, so thresholds tuned in the playground behaved differently on the keyboard (#286)
- Health log entries read the memory footprint before the teardown had reclaimed it, overstating what survived by 1.3–3.3 MB (#295)
- The App Store description claimed 14 keyboard languages including four that do not exist, and promised long-press text selection, which a keyboard extension cannot do; both are corrected, and a test pins the language count to the registry (#286)
- Screenshot generation, broken since 2026-07-09: the CI image started shipping several Xcode 26.x versions, so the same simulator name now exists once per iOS runtime, and the workflow's warm-boot step and the script targeted different devices (#296)

### Changed

- The app icon is an Icon Composer bundle, so iOS 26 renders it as Liquid Glass; the thumbs-up is split into two layers for parallax depth on the Home Screen, and the system derives the tinted appearance instead of shipping a pinned variant. The artwork and palette are unchanged, and pre-iOS-26 devices keep a flat icon (#280, generator hardened in #288)
- The `^` compose key's return swipe now types the caron dead key, so č ď ě ň ř š ť ž are reachable directly instead of only through the accent cycle. The stand-alone modifier circumflex `ˆ` (U+02C6) that this return swipe used to type is deliberately gone with it; the ASCII `^` on the same key is unchanged (#285)
- Leaner keyboard rendering: fewer allocations per keystroke and cached layouts released under memory pressure, leaving more headroom in the tight memory budget iOS gives keyboard extensions (#278)
- Legacy type names brought in line with the glossary: `InputMethodKind` → `InputMethodType`, `HapticFeedbackManager` → `HapticFeedbackPlayer`, `NumpadStyle` → `NumpadType`, `CursorMovementStyle` → `CursorMovementType`. Stored settings keys, enum raw values and user-facing labels are unchanged, so existing settings survive (#297)
- UI tests run against a throwaway defaults suite instead of the shared app group, and the screenshot-generating tests are opt-in behind `GENERATE_SCREENSHOTS` rather than running on every full test invocation (#287)
- Dead code removed and the keyboard health log hardened (#285)

## v1.4.0 — 2026-07-23

### Added

- 11 new keyboard layouts: Arabic, Persian, and Urdu (right-to-left, #244), Thai (#247), Hindi with sequential vowel combining (#248), Greek, Portuguese, and Ukrainian (#243), Japanese Hiragana and Katakana (#249), Korean Hangul with syllable composition (#251)
- Native digit layers for scripts with their own numerals — Arabic-Indic, Extended Arabic-Indic, Devanagari, and Thai (#244, #247, #248, #268)
- Optional long-press on a letter key to type its digit (#240)
- Optional double-space period shortcut (#267)
- Cut-all circular gesture on the clipboard key — circling it cuts the text around the cursor, off by default and gated behind a new Gestures setting (#260, active-selection handling in #274)
- App UI localized into the 10 new keyboard languages (#252, #261)
- Release-safe keyboard health log for diagnosing extension suspensions (#230, append-only JSONL in #271)
- Å restored on the Finnish layout (#265)

### Fixed

- Input correctness across the new layouts: Hindi/Urdu letter bindings, Korean tense consonants, Japanese handakuten and sokuon, native digits on the space bar (#268)
- Sequential composition with an active selection, compose space normalization, and RTL hint mirroring (#269)
- Keyboard extension memory footprint at suspension — the SwiftUI hosting graph is shed before suspension so the keyboard survives the next resume instead of falling back to the system keyboard (#273)
- One-shot shift semantics, Spanish auto-capitalization, and caseless Hebrew (#236)
- Gesture edge cases: return-up hijack, ProMotion buffer sizing, aspect-ratio guard (#234)
- Utility-left layout now moves only the utility keys (#233)
- Host app preview wiring, settings copy, and screenshot language persistence (#235)
- Case-insensitive String Catalog key collision that broke symbol generation on Xcode 26, plus repo-wide lint drift (#264)
- Stretched App Store screenshots — square keys restored (#229)
- Release pipeline: Xcode 26 selection, upload error handling, screenshot generation, CI keychain cleanup (#227, #228, #232)

### Changed

- Keyboard size anchored in points via a single layout metrics resolver; landscape rescales only on genuine overflow (#254, #270)
- Composition pipeline consolidated behind a single combiner strategy (#272)
- Pipeline, definition-layer, and test-hygiene polish from the full codebase review (#237, #238)

## v1.3.1 — 2026-07-04

### Added

- Space-bar label-visibility gestures — swipe up toggles the extra-symbol labels, a return-up swipe toggles letters and standard symbols as a group (#220, reliability fix in #225)
- Hebrew final letters via return swipes (#208)
- Compose trigger labels can now be hidden (#217)

### Fixed

- Double haptic pulse per keystroke (#216, #222)
- Keyboard rendered narrower than the screen after the window-bounds sizing change (#219, #223)
- Cursor offsets for emoji and surrogate pairs (#205)
- Outlier filter cascade discarding fast swipes (#209)
- Auto-capitalization engagement and mode guards (#212)
- Stale language settings re-enabling disabled languages (#213)
- Vietnamese tone rules leaking into other languages' compose tables (#218)
- Touch cancellation now handled in the gesture handlers (#206)
- Expert gesture thresholds applied only when expert mode is on (#210)
- Compose rule overrides wired into the pipeline (#214)

### Changed

- Reworked haptic feedback — exactly one pulse per keystroke and a wider intensity scale (#222)
- Settings strings routed through the String Catalog (#207)
- KeyboardRegistry cache made thread-safe (#211)
- Screenshot scale, navigation nesting, and shared-defaults duplication cleaned up (#215)

## v1.3.0 — 2026-06-30

### Added

- In-keyboard language switching — cycle through enabled languages with a swipe on the globe key (#199, #135)
- Label visibility — hide letters, standard symbols, or extra symbols independently to choose which labels appear on the keys (#200)
- App localization in 12 languages (#189)
- Vietnamese Telex input method (#134)
- Cursor movement style setting — continuous or step-by-step, with word-wise movement (#173)
- Extensive new test coverage: gesture classification, action pipeline, middlewares, compose integrity, accessibility, and end-to-end typing UI tests (#181, #182, #183, #186, #188)

### Fixed

- Fix Liquid Glass inter-key dead zones — taps in the gaps between keys now register in the real keyboard extension (#198)
- Harden the keyboard extension against memory jetsam so it opens more reliably (#190)
- Re-anchor the gesture origin on ring-buffer overflow for reliable long gestures (#174)
- Fix auto-capitalization whitespace handling, layout validation, and force-unwrap risks (#177)

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
