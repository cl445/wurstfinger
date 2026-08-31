# Localization Scope

The app UI ships in 23 languages: English plus the 22 in the project's
`knownRegions` (`de fr es it ru pl sv fi hr he vi fil el pt uk ar fa ur th hi
ja ko`). This document records where the strings live and which screens are
deliberately left in English.

## Catalogs

| Catalog | Holds |
| --- | --- |
| `wurstfinger/Localizable.xcstrings` | Everything the host app displays: settings, onboarding, the test area — plus the keyboard's own strings, because the app renders real keyboards in its previews and showcase. |
| `wurstfingerKeyboard/Localizable.xcstrings` | The strings that live in extension sources: the VoiceOver labels of the utility keys, plus the built-in theme names and descriptions. |

Sources under `wurstfingerKeyboard/` compile into **both** products, so a
string used there is looked up in whichever bundle is running and must exist in
**both** catalogs. `catalogsRequiredBySourceDir` in
`wurstfingerTests/LocalizationCompletenessTests.swift` encodes exactly that rule:
a string found under `wurstfinger/` is required in the host catalog only, one
found under `wurstfingerKeyboard/` is required in both.

Where a display name is declared therefore decides how often it has to be
translated. `HapticIntensityLevel.displayName` lives in
`wurstfinger/HapticSettingsView.swift`, next to the screen that shows it rather
than next to the enum in `wurstfingerKeyboard/Settings/`, so "Minimal", "Soft"
and "Strong" exist in the host catalog only. The theme names go the other way:
`displayName` and `displayDescription` are declared on `KeyboardThemeDefinition`
in `wurstfingerKeyboard/Runtime/Theme/BuiltInThemes.swift` because extension code
reads them too — `ThemeStore.duplicate` names a copied theme after its source.
"Classic", "Liquid Glass", "Dark Gold" and their three descriptions are
consequently duplicated into **both** catalogs, and a new built-in theme has to
be translated in both.

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
