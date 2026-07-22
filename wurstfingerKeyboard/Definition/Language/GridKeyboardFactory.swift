//
//  GridKeyboardFactory.swift
//  Wurstfinger
//
//  Factory for creating grid-based keyboard definitions.
//

import Foundation

/// Factory for creating complete grid-based keyboard definitions.
/// All shared structure (punctuation, utility keys, arrangements, shifted layer)
/// is generated automatically — only language-specific parameters are needed.
enum GridKeyboardFactory {
    /// Creates a complete keyboard definition from language-specific parameters.
    ///
    /// - Parameters:
    ///   - id: Unique keyboard identifier (e.g. "de_messagease")
    ///   - title: Display name (e.g. "Deutsch MessagEase")
    ///   - localeIdentifier: Locale string for uppercasing (e.g. "de_DE")
    ///   - centerCharacters: 3x3 grid of center tap characters
    ///   - directionalOverrides: Per-slot overrides that replace CommonKeys defaults
    ///   - returnOverrides: Per-slot return-swipe outputs that replace the
    ///     auto-generated uppercase return action (e.g. Hebrew final forms:
    ///     a return swipe on כ produces ך). Each entry must target a gesture
    ///     that already has a binding on that slot.
    ///   - composeRuleOverrides: Language-specific compose rules merged over the
    ///     global base rules at runtime (override wins for the same trigger +
    ///     base character). Defaults to nil (global rules only).
    ///   - supportsCapitalization: Whether the script distinguishes letter case.
    ///     Caseless scripts (Hebrew) pass `false`: the layout then has no
    ///     shifted/capsLock modes, no shift binding on the midRight key, and
    ///     auto-capitalization is disabled in the definition settings.
    ///   - numericBackToAlphaLabel: Label shown on the symbols key in numeric
    ///     mode that switches back to the main (alphabetic) layer. Defaults to
    ///     the Latin "abc"; non-Latin layouts (Hebrew, Russian, …) should
    ///     supply a script-appropriate label.
    ///   - numericDigits: Digit set (indexed by value 0–9) used in the numeric
    ///     layer. Defaults to Western ASCII digits; Arabic, Persian, and Urdu
    ///     layouts should pass their script-specific digit set.
    ///   - inputMethod: Which input method is applied to committed characters.
    ///     Defaults to `.direct`; Vietnamese layouts should pass `.telex` so
    ///     that `SequentialCompositionMiddleware` activates for this keyboard
    ///     at runtime.
    static func layout(
        id: String,
        title: String,
        localeIdentifier: String,
        centerCharacters: [[String]],
        directionalOverrides: [String: [GestureType: String]] = [:],
        returnOverrides: [String: [GestureType: String]] = [:],
        composeRuleOverrides: ComposeRuleSet? = nil,
        supportsCapitalization: Bool = true,
        numericBackToAlphaLabel: String = NumericLayouts.defaultBackToAlphaLabel,
        numericDigits: [String] = NumericLayouts.westernDigits,
        inputMethod: InputMethodKind = .direct,
        combineRuleSet: ComposeRuleSet? = nil
    ) -> KeyboardDefinition {
        precondition(
            centerCharacters.count == 3 && centerCharacters.allSatisfy { $0.count == 3 },
            "centerCharacters must be a 3×3 matrix"
        )

        let locale = Locale(identifier: localeIdentifier)
        let arrangements = StandardArrangements.grid3x3

        // 1. Build 9 letter keys from center characters + shared defaults + overrides
        var letterKeys: [String: KeyConfig] = [:]
        for (rowIdx, row) in centerCharacters.enumerated() {
            for (colIdx, char) in row.enumerated() {
                let slotId = GridSlot.allSlots[rowIdx][colIdx]

                // Start with shared defaults for this slot
                var bindings = CommonKeys.defaultSlotBindings[slotId] ?? [:]

                // Apply language-specific overrides (replace default binding for that gesture).
                // Letters get an auto-generated uppercase return action.
                if let overrides = directionalOverrides[slotId] {
                    for (gesture, text) in overrides {
                        let isLetter = text.unicodeScalars.contains { CharacterSet.letters.contains($0) }
                        let returnAction: KeyAction? = isLetter
                            ? .commitText(text.keyboardUppercased(with: locale))
                            : nil
                        bindings[gesture] = KeyBinding(
                            label: text, action: .commitText(text),
                            category: nil, returnAction: returnAction, accessibilityLabel: nil
                        )
                    }
                }

                // Set the tap binding from center character
                bindings[.tap] = KeyBinding(
                    label: char, action: .commitText(char),
                    category: nil, returnAction: nil, accessibilityLabel: nil
                )

                // Apply explicit return-swipe outputs (replace the auto-generated
                // uppercase return action). Needed for caseless scripts where
                // uppercasing is the identity, e.g. Hebrew final forms (כ → ך).
                if let returns = returnOverrides[slotId] {
                    for (gesture, text) in returns {
                        guard gesture.isSwipe else {
                            preconditionFailure(
                                "returnOverrides[\(slotId)][\(gesture)] must target a swipe gesture"
                            )
                        }
                        guard let base = bindings[gesture] else {
                            preconditionFailure(
                                "returnOverrides[\(slotId)][\(gesture)] has no base binding"
                            )
                        }
                        bindings[gesture] = KeyBinding(
                            label: base.label, action: base.action,
                            category: base.category, returnAction: .commitText(text),
                            accessibilityLabel: base.accessibilityLabel
                        )
                    }
                }

                letterKeys[slotId] = KeyConfig(
                    id: slotId, bindings: bindings, swipeMode: .eightWay,
                    slideType: .none, style: .primary, tapCycleActions: nil
                )
            }
        }

        // 2. Merge utility keys — the slot-id sets must be disjoint or the
        // merge would silently swallow a utility key (same invariant as
        // `NumericLayouts.buildMode`).
        precondition(
            Set(letterKeys.keys).isDisjoint(with: CommonKeys.allUtilityKeys.keys),
            "letter and utility key IDs must not overlap"
        )
        var allKeys = letterKeys.merging(CommonKeys.allUtilityKeys) { letter, _ in letter }
        // Bind the space-bar hold-for-zero to this layout's own digit set so
        // non-Latin layouts type their native zero (e.g. Arabic ٠) instead of
        // ASCII "0". `.first ?? "0"` avoids an index crash on a short digit set.
        allKeys[UtilitySlot.space] = CommonKeys.spacebar(zeroDigit: numericDigits.first ?? "0")

        // 3. Build base mode with all keys (includes shift-down on midRight)
        let baseMode = KeyboardMode(
            name: ModeNames.main,
            keys: allKeys,
            arrangements: arrangements,
            autoTransitions: [:]
        )

        var modes: [String: KeyboardMode] = [
            ModeNames.numeric: NumericLayouts.phone(
                digits: numericDigits, backToAlphaLabel: numericBackToAlphaLabel
            ),
        ]

        if supportsCapitalization {
            // Generate the shifted base once and derive both shifted + caps lock.
            let shiftedBase = baseMode.generateShifted(locale: locale)

            // 4. Shifted — shift-up points directly to capsLock (label stays ⇧).
            modes[ModeNames.shifted] = shiftedBase
                .with(autoTransitions: [.letter: ModeNames.main])
                .replacingShiftUpBinding(label: "⇧", action: .switchMode(ModeNames.capsLock))

            // 5. Caps lock — shift-up is no-op (stays in capsLock), label shows ⇪.
            modes[ModeNames.capsLock] = shiftedBase
                .with(name: ModeNames.capsLock)
                .replacingShiftUpBinding(label: "⇪", action: .switchMode(ModeNames.capsLock))

            // 6. Main mode — remove shift-down hint from midRight (only shown in shifted/capsLock).
            modes[ModeNames.main] = baseMode
                .removingBinding(keyId: GridSlot.midRight, gesture: .swipeDown)
        } else {
            // Caseless script: no shifted/capsLock modes. Strip only the
            // auto-generated shift affordance from midRight (the ⇧ shift-up
            // binding and the ⇩ back-to-main hint from CommonKeys); a language
            // letter that a directional override placed on those gestures
            // (e.g. Hindi ट/।, Urdu ڑ/ڈ) must survive.
            modes[ModeNames.main] = baseMode
                .removingBinding(
                    keyId: GridSlot.midRight, gesture: .swipeUp,
                    ifAction: .switchMode(ModeNames.shifted)
                )
                .removingBinding(
                    keyId: GridSlot.midRight, gesture: .swipeDown,
                    ifAction: .switchMode(ModeNames.main)
                )
        }

        // 7. Assemble definition
        return KeyboardDefinition(
            title: title,
            id: id,
            localeIdentifier: localeIdentifier,
            modes: modes,
            defaultMode: ModeNames.main,
            settings: KeyboardDefinitionSettings(
                autoCapitalize: supportsCapitalization,
                composeRuleOverrides: composeRuleOverrides,
                inputMethod: inputMethod,
                combineRuleSet: combineRuleSet
            ),
            numericBackToAlphaLabel: numericBackToAlphaLabel,
            numericDigits: numericDigits
        )
    }
}
