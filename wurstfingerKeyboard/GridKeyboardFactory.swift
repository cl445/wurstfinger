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
    ///   - numericBackToAlphaLabel: Label shown on the symbols key in numeric
    ///     mode that switches back to the main (alphabetic) layer. Defaults to
    ///     the Latin "abc"; non-Latin layouts (Hebrew, Russian, …) should
    ///     supply a script-appropriate label.
    ///   - inputMethod: Which input method is applied to committed characters.
    ///     Defaults to `.direct`; Vietnamese layouts should pass `.telex` so
    ///     that `TelexMiddleware` activates for this keyboard at runtime.
    static func layout(
        id: String,
        title: String,
        localeIdentifier: String,
        centerCharacters: [[String]],
        directionalOverrides: [String: [GestureType: String]] = [:],
        numericBackToAlphaLabel: String = NumericLayouts.defaultBackToAlphaLabel,
        inputMethod: InputMethodKind = .direct
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
                // Letters get an auto-generated uppercase return action matching the
                // old KeyboardLayout behavior (return swipe = uppercase).
                if let overrides = directionalOverrides[slotId] {
                    for (gesture, text) in overrides {
                        let isLetter = text.unicodeScalars.contains { CharacterSet.letters.contains($0) }
                        let returnAction: KeyAction? = isLetter
                            ? .commitText(text.uppercased(with: locale))
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

                letterKeys[slotId] = KeyConfig(
                    id: slotId, bindings: bindings, swipeMode: .eightWay,
                    slideType: .none, style: .primary, tapCycleActions: nil
                )
            }
        }

        // 2. Merge utility keys
        let allKeys = letterKeys.merging(CommonKeys.allUtilityKeys) { letter, _ in letter }

        // 3. Build base mode with all keys (includes shift-down on midRight)
        let baseMode = KeyboardMode(
            name: ModeNames.main,
            keys: allKeys,
            arrangements: arrangements,
            autoTransitions: [:],
            doubleTapMode: nil
        )

        // Generate the shifted base once and derive both shifted + caps lock.
        let shiftedBase = baseMode.generateShifted(locale: locale)

        // 4. Shifted — shift-up points directly to capsLock (label stays ⇧).
        let shiftedMode = shiftedBase
            .with(autoTransitions: [.letter: ModeNames.main])
            .replacingShiftUpBinding(label: "⇧", action: .switchMode(ModeNames.capsLock))

        // 5. Caps lock — shift-up is no-op (stays in capsLock), label shows ⇪.
        let capsLockMode = shiftedBase
            .with(name: ModeNames.capsLock)
            .replacingShiftUpBinding(label: "⇪", action: .switchMode(ModeNames.capsLock))

        // 6. Main mode — remove shift-down hint from midRight.
        //    Old code hid "⇩" in lower layer; we replicate by omitting the binding.
        let mainMode = baseMode
            .removingBinding(keyId: GridSlot.midRight, gesture: .swipeDown)

        // 7. Assemble definition
        return KeyboardDefinition(
            title: title,
            id: id,
            localeIdentifier: localeIdentifier,
            modes: [
                ModeNames.main: mainMode,
                ModeNames.shifted: shiftedMode,
                ModeNames.capsLock: capsLockMode,
                ModeNames.numeric: NumericLayouts.phone(backToAlphaLabel: numericBackToAlphaLabel),
            ],
            defaultMode: ModeNames.main,
            settings: KeyboardDefinitionSettings(
                autoCapitalize: true,
                autoCapitalizers: [],
                composeRuleOverrides: nil,
                inputMethod: inputMethod
            )
        )
    }
}
