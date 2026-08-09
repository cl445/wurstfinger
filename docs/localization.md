# Localization Scope

The app UI ships in 23 languages: English plus the 22 in the project's
`knownRegions` (`de fr es it ru pl sv fi hr he vi fil el pt uk ar fa ur th hi
ja ko`). This document records where the strings live and which screens are
deliberately left in English.

## Catalogs

| Catalog | Holds |
| --- | --- |
| `wurstfinger/Localizable.xcstrings` | Everything the host app displays: settings, onboarding, the test area — plus the keyboard's own strings, because the app renders real keyboards in its previews and showcase. |
| `wurstfingerKeyboard/Localizable.xcstrings` | Only the strings the keyboard extension itself displays, today the VoiceOver labels of the utility keys. |

Sources under `wurstfingerKeyboard/` compile into **both** products, so a
string used there is looked up in whichever bundle is running and must exist in
**both** catalogs. A string that only ever appears in settings therefore belongs
in the host target — that is why `KeyboardStyle.displayName` lives in
`StyleSettingsView.swift` and `HapticIntensityLevel.displayName` in
`HapticSettingsView.swift`, next to the screens that show them, rather than
next to the enums in `wurstfingerKeyboard/Settings/`.

## English-only screens

The Expert section is English by decision. Its vocabulary — jitter threshold,
angular span, oriented compactness — cannot be reviewed by anyone on the team
in 22 translations, and the whole section is a diagnostic tool for power users
behind an acknowledgement gate:

- `ExpertSettingsView`
- `GesturePlaygroundView` (reachable only from the Expert screen)
- `KeyboardHealthView` (reachable only from the Expert screen)

Two more screens are English today, inherited rather than decided — worth
revisiting:

- `ImprintView` — legal notice, kept in a single authoritative wording. It is a
  § 5 DDG notice for a German company, currently shown to German users in
  English.
- `AppStoreScreenshotView` — marketing screenshot chrome, not app UI.

## What the tests guard

- `LocalizationCompletenessTests` — every catalog entry is translated into all
  22 languages, with no empty values, stale states, or stray languages.
- `LocalizationUsageTests` — every `String(localized:)` key exists in the
  catalog of every target that compiles the file using it.
- `LocalizedViewLiteralTests` — every literal a view hands to a
  `LocalizedStringKey` parameter exists in a catalog, unless its file is listed
  in `englishOnlyViewFiles` with a reason. Adding an English-only screen means
  adding it there and to the list above.
