# Naming: enforcement and burn-down

`docs/GLOSSARY.md` has been the naming convention since #291. It was honour-system:
nothing stopped a new `slotId` from being written, and its "Legacy exceptions" section
ended in *"This list is not exhaustive"* — which is another way of saying nobody had
counted. This document records what the count actually is, what was decided, and how the
backlog comes out.

Measured against `develop` @ `d9e8cce`, 188 Swift files, 36,352 lines.

## 1. What the machine now owns

| Artefact | Holds |
| --- | --- |
| `docs/GLOSSARY.md` §1–§6 | The convention: ambiguity traps, zones, vocabulary, suffix and verb rules. Prose, hand-written. |
| `glossary.toml` | The machine-checkable half: one term per concept with its zone, the spellings it replaces, and shape rules for names nobody has written yet. |
| `scripts/check_naming.py` | Reads both. Reports findings, enforces the budget, regenerates §7–§9. |
| `.naming-budget.json` | The backlog, per file. Shrinks only. Deleted when it reaches zero. |

The split follows the failure it prevents. A hand-maintained copy of the rejected-spelling
list would drift from the rules that are actually enforced, and a spelling that is listed
but not enforced reads as enforced. So §7 (Do not write), §8 (The backlog) and §9
(Waivers) are generated; everything above them is reasoning a checker cannot hold.

§8 in particular is generated from the sources rather than hand-listed, which turns
*"not exhaustive"* into an exact number that shrinks in the diff.

## 2. How this was measured

Reproducible, not quoted:

```bash
python3 scripts/check_naming.py list --statistics    # the tally below
python3 scripts/check_naming.py list <path>          # what one file carries
```

Only identifiers count. Comments and string literals are stripped first, but the contents
of a string interpolation are kept — `"\(slotId)"` is a reference to the identifier, not
prose about it. That last detail matters: it is why the count for `slotId` is 31 rather
than the 21 a naive comment-stripping grep reports, and it is what makes the checker agree
with SwiftLint's `match_kinds: [identifier]` to the site.

## 3. Findings

**587 rejected names in 69 of the 188 Swift files**, concentrated in a handful of
families. Small enough to burn down in three changes rather than a campaign.

| Legacy spelling | Sites | Files | Becomes |
| --- | --- | --- | --- |
| `KeyConfig` | 98 | 22 | `KeyDefinition` |
| `create…` prefix | 97 | 2 | `make…` |
| `GesturePreprocessorConfig` | 80 | 7 | `GesturePreprocessorConfiguration` |
| vague type suffix (`DeviceLayoutUtils`, two file names) | 54 | 16 | a name that says what it does |
| `LanguageConfig` | 53 | 11 | merged into `LanguageDescriptor` |
| `hideLetters` / `hideStandardSymbols` / `hideExtraSymbols` | 109 | 10 | `are…LabelsHidden` |
| `slotId` | 31 | 4 | `keyId` |
| `layer` in identifiers | 30 | 10 | `mode` |
| `longPressNumbersEnabled` | 13 | 5 | `isLongPressDigitEnabled` |
| `KeyboardInfo` | 6 | 4 | merged into `LanguageDescriptor` |
| `showLanguageLabel` | 6 | 3 | `isLanguageLabelShown` |
| `ScreenshotConfig` | 3 | 1 | `ScreenshotConfiguration` |
| `ScreenshotMode` | 2 | 1 | `ScreenshotType` |
| `keyConfig` locals | 5 | 2 | follows its type |

Plus 88 comment and string lines across 32 files still saying "layer", which the checker
does not see and which come out together with the identifiers.

### The one that is not cosmetic

Three types describe one concept, and their field names disagree across the boundary:

```swift
struct LanguageConfig     { let id: String; let name: String;  let locale: Locale }
struct LanguageDescriptor { let id: String; let title: String; let localeIdentifier: String }
struct KeyboardInfo       { let id: String; let title: String; let localeIdentifier: String }
```

The display name is `name` in one and `title` in the other two; the locale is a `Locale`
in one and a `String` in the others. Everything else on this page is a name that reads
badly. This one is a name that can be read wrongly — it is a merge, not a rename, and it
is the reason the glossary exists rather than a style guide.

### What the first audit changed

Two findings are worth keeping, because both are failure modes of this kind of tooling
rather than of this codebase:

**An allow-list hid 15 real hits.** The `layer` rule allow-listed bare `layer` on the
assumption that it would be UIKit's `CALayer` property. This codebase uses no UIKit
layers at all, so the only bare `layer` is `ScreenshotConfig.layer` — the field that
feeds `FORCE_LAYER`. A speculative allow-list entry is not free: it silently subtracts
from the count everyone then trusts. Entries now name Apple types only, and only ones
that would otherwise match.

**The prose glossary was wrong in five places.** It said there were three `…Config` types
(there are four — `ScreenshotConfig` was undocumented), that `slotId` lived "in a few
factories" (it is also in two test files, 16 of its 31 sites), that `SlidePhase` has four
cases (it has six), and it filed four types under the wrong directory. All corrected here.
That is the argument for generating the machine-checkable sections: the hand-written ones
had drifted within four months.

## 4. Decisions

**`KeyConfig` becomes `KeyDefinition`, not `Key`.** The type's own doc comment already
reads *"Complete definition of a single key"*; the name never followed. `…Definition` is
what the glossary reserves for complete declarative data, and it pairs with
`KeyboardDefinition` — whole keyboard, one key. Bare `Key` was the alternative and loses
at the use sites: `keys: [String: Key]` reads as though `String` were not the key, and
`Dictionary.Key`, `SettingsKey` and `CodingKeys` already claim the bare word.

**The two `…Config` types take different suffixes.** `GesturePreprocessorConfig` holds
injected runtime parameters and becomes `…Configuration`; `KeyConfig` holds declarative
data and becomes `…Definition`. The suffix rule discriminates, so applying it needs a
judgement per type rather than a search-and-replace.

**Zones are new.** Every term now records who owns the name — internal (A), persisted (B),
or contract (C). Wurstfinger has a real zone C that the glossary previously said nothing
about: the `Localizable.xcstrings` keys *are* the English source strings, so rewording a
UI string drops that entry's translations in all 21 other languages. A case-only
difference is a separate key and has collided once already. Zone B is equally concrete:
`SettingsKey` rawValues are persisted, so a renamed settings property has to pin its old
string. Phase 1 already did this without naming it — the type is `NumpadType` while the
stored key stays `numpadStyle`.

## 5. Burn-down

| Step | Content | Depends on |
| --- | --- | --- |
| **G1** | `glossary.toml`, the checker, the budget frozen at 587, zones, generated §7–§9, CI and hook wiring | — |
| **G2** | SwiftLint `custom_rules` generated from the same file, so the rules fire in Xcode while typing | G1 |
| **G3** | `slotId` → `keyId`, `layer` → `mode` (identifiers and comments), `create…` → `make…`, the vague type and file names | G1 |
| **G4** | `KeyConfig` → `KeyDefinition`, `GesturePreprocessorConfig` → `…Configuration`, the `LanguageConfig` / `KeyboardInfo` merge, the settings booleans | G1; conflicts with the open PR stack |

G4 touches 227 sites in files that #253, #250, #245 and #221 are all editing, so it waits
until that stack lands rather than forcing four rebases.

### Why the SwiftLint rules carry exclusions

CI lints with `--strict`, so a warning fails the build. A rule for a spelling that still
has a backlog would therefore block every commit until the rename lands. Each generated
rule instead excludes exactly the files that still carry that spelling, and those files
stay covered by `.naming-budget.json`, which forbids growth. Every other file — including
every file added tomorrow — is gated in the editor. As a rename lands, `update` shrinks
both lists at once.

This is not the same as excluding a file wholesale: the budget still refuses a second
`slotId` in a file that carries one.

## 6. Open naming questions

`KeyboardDefinitionSettings` carries the `…Settings` suffix, which §4 reserves for
user-changeable persisted state — but it is declarative per-language data on a
`KeyboardDefinition`. The suffix is wrong and the right one is not obvious
(`…Options`, `…Behaviour`, or folding the fields into the definition itself), so no
canonical name is recorded for it yet. An alias pointing at the wrong target would be
worse than none.

## 7. What is still not covered

- **Comments.** The checker reads identifiers only. Prose in comments follows §7's second
  table by review, not by rule.
- **Zone C.** No rule can catch a reworded `xcstrings` key or a renamed environment
  variable; both fail outside CI. §2 documents the cost instead.
- **File names.** Only the vague-suffix rule reads them, because that is where the
  mismatch actually occurred (`GeometryUtils.swift` declares no type at all, so an
  identifier-only rule never sees the name).
