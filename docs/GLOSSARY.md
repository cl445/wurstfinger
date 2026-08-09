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
nothing else. Known mismatches are listed under
[Legacy exceptions](#7-legacy-exceptions); that list is not exhaustive, so a name in the
codebase that contradicts this file is a legacy name, not a counter-example.

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

"Layer" means the same thing and appears in ~70 comment lines. It is **not** canonical —
never introduce it in new code, comments, or test names. `KeyboardMode+Shifted.swift`
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
- `slotId` is an alias used in a few factories. Prefer `keyId` in new code.

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

## 2. Core vocabulary

### Declarative model (`Definition/`)

| Term | Type | Means |
| --- | --- | --- |
| definition | `KeyboardDefinition` | the complete declarative description of one keyboard: all modes, keys, bindings, arrangements |
| mode | `KeyboardMode` | one state of a definition (`main`, `shifted`, `numeric`, …) with its own keys + arrangement |
| key | `KeyConfig` | one key: `id`, `bindings`, `swipeMode`, `slideType`, `style`, `tapCycleActions` |
| binding | `KeyBinding` | what one gesture on one key does: `label`, `action`, `category`, `returnAction`, `accessibilityLabel` |
| action | `KeyAction` | the command enum — `commitText`, `compose`, `cycleAccents`, `switchMode`, `capitalizeWord`, `advanceToNextInputMode`, `dismissKeyboard`, `switchToNextLanguage`, `deleteBackward`, `deleteForward`, `space`, `newline`, `moveCursor`, `copy`, `paste`, `cut`, `cutAll`, `none` |
| label | `KeyBinding.label` | the text drawn on the key. May differ from the output (`"⇧"` for shift) and is empty for icon-driven utility keys |
| compose | `ComposeRuleSet`, `ComposeEngine` | table-driven character composition (`' + a → á`) |
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
| metrics | `KeyboardLayoutMetrics` | resolved pixel geometry (heights, insets) for the current device and orientation |

### Gestures (`Runtime/Gesture/`)

| Term | Means |
| --- | --- |
| gesture | one recognized input, typed as `GestureType`: `tap`, the eight `swipe…` directions, `circularClockwise` / `circularCounterclockwise`, `longPress` |
| swipe | a directional gesture from the key center. Qualify direction; never say "swipe" for a slide |
| return swipe | out-and-back to the start position; fires `KeyBinding.returnAction`. Always two words |
| slide | a sustained drag on a held key, typed as `SlideType` (`none`, `moveCursor`, `delete`) and phased as `SlidePhase` (`began`, `changed(deltaX:)`, `ended`, `tap`). Never call this a swipe |
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
| target | `TextInputTarget` — the abstraction all text manipulation goes through. Production implementation is `DocumentProxyTarget` wrapping `UITextDocumentProxy`; tests substitute a mock |

### Settings (`Settings/`)

| Term | Means |
| --- | --- |
| settings | user-changeable, persisted values (`LayoutSettings`, `HapticSettings`, `LanguageSettings`) |
| constants | compile-time values that users cannot change (`KeyboardConstants`) |
| shared defaults | the app-group `UserDefaults` bridging host app and extension (`SharedDefaults`) |

---

## 3. Type-name suffixes

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

## 4. Function-name verbs

| Verb | Reserved for |
| --- | --- |
| `resolve…` | resolver-chain lookups returning an optional |
| `process…` | middleware entry points |
| `handle…` | view-model entry points reacting to user input |
| `make…` | pure factory returning a value (`makeDefinition`) |
| `build…` | assembling a larger structure in place (`buildMode`) |

`make…` is the factory verb — do not introduce `create…` alongside it.

## 5. General naming rules

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

## 6. Do not write

| Avoid | Write instead |
| --- | --- |
| layer | mode |
| slotId | keyId |
| `…Config` | `…Configuration` |
| `…Kind` | `…Type` |
| "return" for the gesture | "return swipe" |
| "swipe" for a held drag | "slide" |
| number (for 0–9 keys) | digit — except inside `LabelCategory`, where the case is named `number` |

## 7. Legacy exceptions

Known violations, deliberately left in place. **Do not rename them** — the existing code
will be brought in line in its own dedicated changes. This list is not exhaustive.

| Name | Problem |
| --- | --- |
| `GesturePreprocessorConfig`, `KeyConfig`, `LanguageConfig` | abbreviated suffix |
| `KeyConfig`, `LanguageConfig` | declarative data carrying the runtime-parameter suffix on top of that |
| `KeyboardInfo` | `…Info` says nothing about the contents; would be `…Metadata` |
| `LanguageConfig` / `LanguageDescriptor` / `KeyboardInfo` | three near-identical language metadata types; the latter two are field-identical. A merge, not a rename |
| `hideLetters`, `hideStandardSymbols`, `hideExtraSymbols`, `longPressNumbersEnabled` | booleans that do not read as assertions |
| `slotId` in `GridKeyboardFactory` and `NumericLayouts` | alias for `keyId` |
| ~70 comment lines saying "layer" | pre-date this glossary |
