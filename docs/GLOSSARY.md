# Glossary

Canonical vocabulary for Wurstfinger. Written primarily for LLM agents working in this
repo, but binding for humans too.

**Scope: new and changed code only.** The existing codebase is grandfathered. This file is
not a TODO list, and nothing here justifies a rename in code you were not already
modifying — the existing names will be brought in line in their own dedicated changes.
When code and this file disagree, the code wins for *reading*; this file wins for
*writing*.

**How to use it:** before naming a type, parameter, or test — and before writing a doc
comment — check whether the concept already has a canonical term here. Use that term and
nothing else. What the codebase still spells the old way is measured, not guessed: it is
listed in [The backlog](#8-the-backlog), which is generated from the sources, so a name
that contradicts this file is a legacy name rather than a counter-example.

**How it is enforced.** The machine-checkable half of this document — the vocabulary, the
rejected spellings, the shape rules — lives in [`glossary.toml`](../glossary.toml).
`scripts/check_naming.py` reads it and reports every identifier that contradicts it;
`.naming-budget.json` records the backlog per file, may shrink but never grow, and is
deleted once it reaches zero. Sections [7](#7-do-not-write), [8](#8-the-backlog) and
[9](#9-waivers) below are generated from those two files — edit `glossary.toml` and run
`render`, not this document.

```bash
python3 scripts/check_naming.py list <path>   # what a file carries
python3 scripts/check_naming.py check         # what CI runs
python3 scripts/check_naming.py update        # record a rename
```

Where this file does not decide something, the
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
do: clarity at the point of use, no abbreviations, names by role rather than by type.

---

## 1. Ambiguity traps

These five are the ones that actually cause wrong code. Read them first.

### `mode`, never `layer`

A **mode** is one keyboard state with its own key set and arrangement: `main`, `shifted`,
`capsLock`, `numeric`, `symbols`, `emoji` (`ModeNames` in
`Definition/Language/KeyboardDefinition.swift`). The type is `KeyboardMode`, the action is
`.switchMode(name)`.

"Layer" means the same thing and still appears in 30 identifiers and 88 comment and
string lines across 32 files. It is **not** canonical — never introduce it in new code,
comments, or test names. `KeyboardMode+Shifted.swift`
currently manages both words in one sentence; that is the bug this rule prevents.

Do not confuse `KeyboardMode` (keyboard state) with `SwipeMode` (which *directions* a
single key accepts: `.eightWay`, `.fourWayCross`, …). Different axes, same word — always
qualify which one you mean.

### `return` means three different things

| Usage | Meaning |
| --- | --- |
| `UtilitySlot.return`, `KeyAction.newline` | the Return/Enter **key** |
| `KeyBinding.returnAction`, `isReturn`, `returnOverrides`, `ReturnSwipeResolver` | the **return-swipe gesture** — swipe out and back to the start |
| Swift `return` | the language keyword |

`returnAction` is the output of a *return swipe*, **not** the action of the Return key.
When writing prose, always say "return swipe" in full; never abbreviate it to "return".

### slot id == key id — same string, two names

A **slot** is a named position in the layout. A **key id** is the string identifying a
`KeyConfig`. They are the same value: `KeyConfig.id` is documented as "Semantic slot name",
and `KeyPlacement.keyId` references it.

- The **names** live in `GridSlot` (`topLeft` … `bottomRight`, `zero`) and `UtilitySlot`
  (`globe`, `delete`, `return`, `space`, `symbols`).
- The **variable/parameter name** for such a string is `keyId` (established API surface,
  e.g. `GestureResolver.resolve(keyId:gesture:in:)`).
- `slotId` is a rejected alias, still carried by two factories and two test files
  ([the backlog](#8-the-backlog) has the count). Never write it in new code.

Use "slot" when talking about the *position* ("the `topLeft` slot"), "key" when talking
about the *thing bound to it* ("the `topLeft` key commits `q`").

### `…Style` is visual only

`KeyStyle` (`.primary`, `.utility`, `.spacebar`, …) and `KeyboardStyle` (`.classic`,
`.liquidGlass`) are appearance. `NumpadType` (digit order) and `CursorMovementType`
(drag behavior) are **not** visual and therefore carry `…Type`.

For new code: `…Style` = how it looks, `…Type` = a closed set of behavioral variants (as in
`GestureType`, `SlideType`). Never `…Mode` for either — that word belongs to keyboard
state.

### `KeyCategory` vs `LabelCategory`

Two classification enums over the same keys on different axes. Both are legitimate; picking
the wrong one is a silent behavior bug.

| | Axis | Cases |
| --- | --- | --- |
| `KeyCategory` | runtime behavior: auto-shift, haptics, hint styling | `letter`, `digit`, `symbol`, `compose`, `modifier`, `utility`, `whitespace` |
| `LabelCategory` | render-time visibility (the "hide labels" settings) | `letter`, `standardSymbol`, `extraSymbol`, `number`, `functional` |

Note the vocabulary clash: the same concept is `digit` in one and `number` in the other.

That two enums named `…Category` classify the same keys is the underlying smell. A new
classification enum must name its **axis**, not just the word "category" — the reader has
to be able to tell from the name alone which of several classifications applies.

---

## 2. Zones: who owns a name

Before renaming anything, ask who owns the name. Every term in `glossary.toml` records it.

- **Zone A, free.** Types, properties, parameters, locals, test names. Nobody outside the
  code sees them, so renaming is pure refactoring.
- **Zone B, migratable.** Anything read back from disk. The Swift spelling and the stored
  spelling are two different names: rename the property and **pin the old string**
  — `case areLetterLabelsHidden = "hideLetters"` — or ship a migration. Phase 1 already
  works this way: the type is `NumpadType` while the stored key stays `numpadStyle`, and
  that divergence is correct rather than drift.

  | Name | Note |
  | --- | --- |
  | `SettingsKey` cases | 24 cases, **all with implicit rawValues** — the case name *is* the stored key, so a rename orphans the setting unless the old string is pinned. |
  | `AppSettingsKey` cases | 3 cases, all with explicit rawValues (`onboarding.*`). Here the case names are free and the strings are the contract. |
  | `gesture.*` | The tuning keys in `GesturePreprocessor`, written as string literals. |
  | `KeyboardHealthLog.Entry` properties | `Codable` with no `CodingKeys`, written to a JSON file in the app group — the property names *are* the on-disk field names. |
  | Language ids (`de_DE`, `ja_JP_katakana`, …) | Persisted in `selectedLanguageId`, `enabledLanguageIds`, `pinnedLanguageId`. |

- **Zone C, contract.** Names that leave the codebase. Renaming one costs somebody
  something outside this repository, so it is a release decision, not a refactoring:

  | Name | What a rename costs |
  | --- | --- |
  | `Localizable.xcstrings` keys | The English source string *is* the key. Rewording a UI string re-keys the entry and drops its translations — 156 keys across 22 languages. A case-only difference is a separate key, and has collided once already (`Switch Keyboard` vs. `Switch keyboard`). |
  | `accessibilityIdentifier` values | The UI tests query keys by slot id; renaming a slot renames the test hook with it. |
  | `group.de.akator.wurstfinger.shared` | The app-group suite. Renaming it orphans every setting on every installed device. |
  | `FORCE_LANGUAGE`, `FORCE_LAYER`, `SCREENSHOT_MODE`, `GENERATE_SCREENSHOTS`, … | Read by `scripts/generate-screenshots.sh` and the workflows. They move together with those files or not at all — which is why `FORCE_LAYER` still says "layer", and why its values are `lower`, `upper`, `numbers`, `symbols` rather than the mode names they map to. |
  | `ISOLATED_DEFAULTS` | Declared in `SharedDefaults` **and hand-copied** into `UITestApp`, because the UI-test target cannot import the app module. Renaming one side compiles cleanly and silently stops isolating the test defaults. |

The checker only sees zone A and the Swift half of zone B. Zone C is documented here
because no rule can catch it: it fails in the App Store, not in CI.

---

## 3. Core vocabulary

### Declarative model (`Definition/`)

| Term | Type | Means |
| --- | --- | --- |
| definition | `KeyboardDefinition` | the complete declarative description of one keyboard: all modes, keys, bindings, arrangements |
| mode | `KeyboardMode` | one state of a definition (`main`, `shifted`, `numeric`, …) with its own keys + arrangement |
| key | `KeyConfig` | one key: `id`, `bindings`, `swipeMode`, `slideType`, `style`, `tapCycleActions` |
| binding | `KeyBinding` | what one gesture on one key does: `label`, `action`, `category`, `returnAction`, `accessibilityLabel` |
| action | `KeyAction` | the command enum — `commitText`, `compose`, `cycleAccents`, `switchMode`, `capitalizeWord`, `advanceToNextInputMode`, `dismissKeyboard`, `switchToNextLanguage`, `deleteBackward`, `deleteForward`, `space`, `newline`, `moveCursor`, `copy`, `paste`, `cut`, `cutAll`, `none` |
| label | `KeyBinding.label` | the text drawn on the key. May differ from the output (`"⇧"` for shift) and is empty for icon-driven utility keys |
| compose | `ComposeRuleSet` (here), `ComposeEngine` (in `Runtime/Compose/`) | table-driven character composition (`' + a → á`) |
| input method | `InputMethodType` | stateful transformation of committed text: `direct`, `telex`, `hangul` |
| descriptor | `LanguageDescriptor` | lazy handle to a language: cheap metadata plus a builder that materializes the definition on demand |

### Layout (`Definition/Layout/`)

| Term | Type | Means |
| --- | --- | --- |
| slot | `GridSlot`, `UtilitySlot` | semantic name of a position; the string that is also a key id |
| arrangement | `GridArrangement` | which keys sit where, at what size, for one `ArrangementContext` |
| arrangement context | `ArrangementContext` | the situation an arrangement applies to: `portrait`, `portraitUtilityLeft`, `landscape`, `landscapeUtilityLeft` |
| placement | `KeyPlacement` | one key's entry in an arrangement: `keyId` + `widthMultiplier` + `heightMultiplier` |
| cell | `SolvedCell` | a *computed* grid rectangle, output of `GridLayoutSolver`. "Cell" is always a result, never a declaration — declare with slot/placement, compute into cells |
| metrics | `KeyboardLayoutMetrics` (in `Settings/`) | resolved pixel geometry (heights, insets) for the current device and orientation |

### Gestures (`Runtime/Gesture/`)

| Term | Means |
| --- | --- |
| gesture | one recognized input, typed as `GestureType`: `tap`, the eight `swipe…` directions, `circularClockwise` / `circularCounterclockwise`, `longPress` |
| swipe | a directional gesture from the key center. Qualify direction; never say "swipe" for a slide |
| return swipe | out-and-back to the start position; fires `KeyBinding.returnAction`. Always two words |
| slide | a sustained drag on a held key, typed as `SlideType` (`none`, `moveCursor`, `delete`; declared in `Definition/Model/`) and phased as `SlidePhase` (`began`, `changed(deltaX:)`, `swipeUp(isReturn:)`, `ended`, `tap`, `cancelled`). Never call this a swipe |
| ghost key | a binding inherited from a fallback mode when the active mode leaves that gesture unbound (`GhostKeyResolver`) |
| trail | the visual stroke drawn behind the finger (`GestureTrail*`). Purely cosmetic — it never resolves to an action |

### Runtime pipeline (`Runtime/Pipeline/`)

| Term | Means |
| --- | --- |
| resolver | `GestureResolver` — maps (`keyId`, gesture, mode) to a `KeyBinding?`. Returning `nil` delegates to the next resolver |
| resolver chain | `GestureResolverChain` — priority-ordered resolvers; first non-`nil` wins, else `KeyAction.none` |
| middleware | `ActionMiddleware` — `process(_ context:next:)`; may mutate the context, call `next`, or short-circuit |
| action pipeline | `ActionPipeline` — the ordered middleware chain an action runs through |
| context | `ActionContext` — the mutable state carried through the pipeline |
| target | `TextInputTarget` (declared in `Definition/Model/`) — the abstraction all text manipulation goes through. Production implementation is `DocumentProxyTarget` wrapping `UITextDocumentProxy`; tests substitute a mock |

### Settings (`Settings/`)

| Term | Means |
| --- | --- |
| settings | user-changeable, persisted values (`LayoutSettings`, `HapticSettings`, `LanguageSettings`) |
| constants | compile-time values that users cannot change (`KeyboardConstants`) |
| shared defaults | the app-group `UserDefaults` bridging host app and extension (`SharedDefaults`) |

---

## 4. Type-name suffixes

| Suffix | Reserved for | Example |
| --- | --- | --- |
| `…Definition` | complete declarative data | `KeyboardDefinition` |
| `…Descriptor` | lazy handle: metadata + a builder that materializes the real thing | `LanguageDescriptor` |
| `…Configuration` | injected parameters of a runtime component | `SlideGestureConfiguration` |
| `…Settings` | user-changeable, persisted | `LayoutSettings` |
| `…Metrics` | computed geometry | `KeyboardLayoutMetrics` |
| `…Style` | visual appearance | `KeyStyle` |
| `…Type` | closed set of behavioral variants | `GestureType`, `SlideType` |
| `…Mode` | keyboard state — **reserved**, do not use for anything else | `KeyboardMode` |
| `…Category` | classification; the prefix must name the axis | `KeyCategory` |
| `…Resolver` / `…Middleware` | pipeline participants | `GhostKeyResolver` |
| `…Factory` / `…Registry` | build / look up + cache definitions | `GridKeyboardFactory` |

Spell suffixes out: `…Configuration`, not `…Config`. Apple's own APIs are consistent about
this (`URLSessionConfiguration`, `WKWebViewConfiguration`), and the Swift API Design
Guidelines rule out abbreviations. The three `…Config` types in the codebase are legacy.

Do not introduce `…Manager` or `…Helper`. Both describe no responsibility; name the type
after what it actually does.

## 5. Function-name verbs

| Verb | Reserved for |
| --- | --- |
| `resolve…` | resolver-chain lookups returning an optional |
| `process…` | middleware entry points |
| `handle…` | view-model entry points reacting to user input |
| `make…` | pure factory returning a value (`makeDefinition`) |
| `build…` | assembling a larger structure in place (`buildMode`) |

`make…` is the factory verb — do not introduce `create…` alongside it.

## 6. General naming rules

These are not domain-specific, but they are where new code drifts most.

- **Booleans read as assertions:** `is…`, `has…`, `should…` (`isSliding`, `shouldCapitalize`).
  A settings flag is `isSomethingEnabled`, not `enableSomething` or `hideSomething` — the
  latter read as commands. Existing `hideLetters` / `longPressNumbersEnabled` are legacy.
- **Tests carry no `test` prefix.** All `@Test` functions are named as the assertion
  they make: `symbolsKeySwitchesToNumeric()`, `allLanguagesHaveUniqueIds()`. Write the
  expected behavior as a sentence; the `@Test` attribute already says it is a test.
  Exception: the XCTest-based UI tests (`wurstfingerUITests`) **must** keep the `test`
  prefix — XCTest discovers test methods by that prefix, so a UI test without it
  silently never runs.
- **No abbreviations** beyond `id`, `min`, `max`, and the `…Idx` loop-index locals already
  in use.
- **Name parameters by role, not by type:** `keyId: String`, not `string: String`.

## 7. Do not write

### In code

Generated from `glossary.toml`; `scripts/check_naming.py` enforces every row.

<!-- generated by scripts/check_naming.py — do not edit: rejected -->

| Avoid | Write instead |
| --- | --- |
| config suffix | `…Configuration` for injected runtime parameters, `…Definition` for declarative data |
| create prefix | `make…` |
| `GesturePreprocessorConfig` | `GesturePreprocessorConfiguration` |
| `hideExtraSymbols` | `areExtraSymbolLabelsHidden` |
| `hideLetters` | `areLetterLabelsHidden` |
| `hideStandardSymbols` | `areStandardSymbolLabelsHidden` |
| `KeyboardInfo` | `LanguageDescriptor` |
| `KeyConfig` | `KeyDefinition` |
| kind suffix | `…Type` |
| `LanguageConfig` | `LanguageDescriptor` |
| layer word | `mode` |
| `longPressNumbersEnabled` | `isLongPressDigitEnabled` |
| `ScreenshotConfig` | `ScreenshotConfiguration` |
| `ScreenshotMode` | `ScreenshotType` |
| `showLanguageLabel` | `isLanguageLabelShown` |
| `slotId` | `keyId` |
| vague type suffix | a name that says what the type does |

<!-- /generated: rejected -->

### In prose

The rules a checker cannot see, because they are about which word describes a thing
rather than how an identifier is spelled.

| Avoid | Write instead |
| --- | --- |
| "layer" for a keyboard state | "mode" |
| "return" for the gesture | "return swipe" |
| "swipe" for a held drag | "slide" |
| "number" for the 0–9 keys | "digit" — except inside `LabelCategory`, where the case is named `number` |

## 8. The backlog

What the codebase still spells the old way, counted from the sources. **Do not rename
these in passing** — each family comes out in its own dedicated change, so a rename you
did not sign up for never lands in your pull request. `.naming-budget.json` freezes these
counts per file: they may shrink, never grow.

<!-- generated by scripts/check_naming.py — do not edit: backlog -->

| Legacy spelling | Replacement | Sites | Files |
| --- | --- | --- | --- |
| `KeyConfig` | `KeyDefinition` | 98 | 22 |
| create prefix | `make…` | 97 | 2 |
| `GesturePreprocessorConfig` | `GesturePreprocessorConfiguration` | 80 | 7 |
| vague type suffix | a name that says what the type does | 54 | 16 |
| `LanguageConfig` | `LanguageDescriptor` | 53 | 11 |
| `hideLetters` | `areLetterLabelsHidden` | 37 | 10 |
| `hideStandardSymbols` | `areStandardSymbolLabelsHidden` | 37 | 10 |
| `hideExtraSymbols` | `areExtraSymbolLabelsHidden` | 35 | 10 |
| `slotId` | `keyId` | 31 | 4 |
| layer word | `mode` | 30 | 10 |
| `longPressNumbersEnabled` | `isLongPressDigitEnabled` | 13 | 5 |
| `KeyboardInfo` | `LanguageDescriptor` | 6 | 4 |
| `showLanguageLabel` | `isLanguageLabelShown` | 6 | 3 |
| config suffix | `…Configuration` for injected runtime parameters, `…Definition` for declarative data | 5 | 2 |
| `ScreenshotConfig` | `ScreenshotConfiguration` | 3 | 1 |
| `ScreenshotMode` | `ScreenshotType` | 2 | 1 |
| **total** | | **587** | **69** |

<!-- /generated: backlog -->

Comments are not counted — the checker reads identifiers only — so the ~85 comment lines
still saying "layer" are not in the table above. They come out with the identifiers.

## 9. Waivers

Where a rejected spelling is the correct name after all. Each one needs a reason;
without it the checker's findings stop being trustworthy.

<!-- generated by scripts/check_naming.py — do not edit: exceptions -->

No waivers are recorded.

<!-- /generated: exceptions -->
