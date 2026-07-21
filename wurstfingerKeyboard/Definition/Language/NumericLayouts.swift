//
//  NumericLayouts.swift
//  Wurstfinger
//
//  Numeric keyboard modes (phone and classic digit ordering).
//  Swipe bindings are inherited from CommonKeys.defaultSlotBindings so that
//  the numeric layer has the same punctuation layout as the letter layer.
//

import Foundation

/// Numeric keyboard modes shared across all languages.
enum NumericLayouts {
    /// Default Latin label for the back-to-alpha key. Languages whose
    /// alphabet is not Latin (Hebrew, Russian, …) should pass their own
    /// script-appropriate label via `phone(backToAlphaLabel:)`.
    static let defaultBackToAlphaLabel = "abc"

    /// Western (ASCII) digits, indexed by value 0–9. The default digit set.
    static let westernDigits = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

    /// Arabic-Indic digits (U+0660–0669), used by the Arabic layout.
    static let arabicIndicDigits = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]

    /// Extended Arabic-Indic (Persian) digits (U+06F0–06F9), used by the
    /// Persian and Urdu layouts.
    static let persianDigits = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

    /// Thai digits (U+0E50–0E59), used by the Thai layout.
    static let thaiDigits = ["๐", "๑", "๒", "๓", "๔", "๕", "๖", "๗", "๘", "๙"]

    /// Devanagari digits (U+0966–096F), used by the Hindi layout.
    static let devanagariDigits = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]

    /// Phone-style layout (1-2-3 in top row).
    ///
    /// - Parameter digits: Digit set indexed by value (0–9). Non-Latin layouts
    ///   (Arabic, Persian, …) pass their script-specific digits; both the tap
    ///   output and the key label use the supplied glyphs.
    static func phone(
        digits: [String] = westernDigits,
        backToAlphaLabel: String = defaultBackToAlphaLabel
    ) -> KeyboardMode {
        precondition(digits.count == 10, "digits must contain exactly 10 glyphs (values 0–9)")
        return buildMode(
            centerDigits: [
                [digits[1], digits[2], digits[3]],
                [digits[4], digits[5], digits[6]],
                [digits[7], digits[8], digits[9]],
            ],
            zeroDigit: digits[0],
            // Phone layout swaps digits but keeps circular gestures at their
            // physical positions.
            circularOverrides: phoneCircularOverrides,
            backToAlphaLabel: backToAlphaLabel
        )
    }

    /// Classic calculator style (7-8-9 in top row).
    static func classic(
        digits: [String] = westernDigits,
        backToAlphaLabel: String = defaultBackToAlphaLabel
    ) -> KeyboardMode {
        precondition(digits.count == 10, "digits must contain exactly 10 glyphs (values 0–9)")
        return buildMode(
            centerDigits: [
                [digits[7], digits[8], digits[9]],
                [digits[4], digits[5], digits[6]],
                [digits[1], digits[2], digits[3]],
            ],
            zeroDigit: digits[0],
            circularOverrides: classicCircularOverrides,
            backToAlphaLabel: backToAlphaLabel
        )
    }

    // MARK: - Numeric Utility Keys

    private static func backToMain(label: String) -> KeyConfig {
        KeyConfig.utility(
            UtilitySlot.symbols, label: label, action: .switchMode(ModeNames.main),
            swipeMode: .eightWay,
            swipes: CommonKeys.clipboardBindings
        )
    }

    /// Standalone "0" digit key in the bottom row.
    private static func zeroKey(digit: String) -> KeyConfig {
        KeyConfig(
            id: GridSlot.zero,
            bindings: [
                .tap: KeyBinding(
                    label: digit, action: .commitText(digit),
                    category: .digit, returnAction: nil, accessibilityLabel: nil
                ),
                .longPress: KeyBinding(
                    label: digit, action: .commitText(digit),
                    category: .digit, returnAction: nil, accessibilityLabel: nil
                ),
            ],
            swipeMode: .none,
            slideType: .none,
            style: .primary,
            tapCycleActions: nil
        )
    }

    private static func utilityKeys(zeroDigit: String, backToAlphaLabel: String) -> [String: KeyConfig] {
        [
            UtilitySlot.globe: CommonKeys.globe,
            UtilitySlot.delete: CommonKeys.delete,
            UtilitySlot.return: CommonKeys.return,
            UtilitySlot.symbols: backToMain(label: backToAlphaLabel),
            UtilitySlot.space: CommonKeys.spacebar,
            GridSlot.zero: zeroKey(digit: zeroDigit),
        ]
    }

    // MARK: - Numeric-Specific Overrides

    /// Extra swipe bindings that only appear on the numeric layer
    /// (beyond what CommonKeys.defaultSlotBindings provides).
    private static let numericExtraSwipes: [String: [GestureType: KeyBinding]] = [
        GridSlot.topLeft: [
            .swipeLeft: KeyBinding(
                label: "≤", action: .commitText("≤"), category: nil,
                returnAction: nil, accessibilityLabel: nil
            ),
        ],
        GridSlot.topRight: [
            .swipeRight: KeyBinding(
                label: "≥", action: .commitText("≥"), category: nil,
                returnAction: nil, accessibilityLabel: nil
            ),
        ],
    ]

    // MARK: - Circular Gestures

    /// Circular gesture bindings for the classic (7-8-9) layout.
    /// Both directions produce the same symbol.
    private static let classicCircularOverrides: [String: KeyBinding] = [
        GridSlot.topLeft: KeyBinding(
            label: "∫", action: .commitText("∫"), category: nil,
            returnAction: nil, accessibilityLabel: nil
        ),
        GridSlot.topCenter: KeyBinding(
            label: "∏", action: .commitText("∏"), category: nil,
            returnAction: nil, accessibilityLabel: nil
        ),
        GridSlot.topRight: KeyBinding(
            label: "∑", action: .commitText("∑"), category: nil,
            returnAction: nil, accessibilityLabel: nil
        ),
        GridSlot.midLeft: KeyBinding(
            label: "¼", action: .commitText("¼"), category: nil,
            returnAction: nil, accessibilityLabel: nil
        ),
        // Intentional: the numeric center key's circle gesture types a
        // plain lowercase "a" (the long-established convention for this
        // key in this layout family), even though every sibling is a
        // math/superscript symbol. Do not "fix" this to "ª".
        GridSlot.center: KeyBinding(
            label: "a", action: .commitText("a"), category: nil,
            returnAction: nil, accessibilityLabel: nil
        ),
        GridSlot.midRight: KeyBinding(
            label: "ⁿ", action: .commitText("ⁿ"), category: nil,
            returnAction: nil, accessibilityLabel: nil
        ),
        GridSlot.bottomLeft: KeyBinding(
            label: "¹", action: .commitText("¹"), category: nil,
            returnAction: nil, accessibilityLabel: nil
        ),
        GridSlot.bottomCenter: KeyBinding(
            label: "²", action: .commitText("²"), category: nil,
            returnAction: nil, accessibilityLabel: nil
        ),
        GridSlot.bottomRight: KeyBinding(
            label: "³", action: .commitText("³"), category: nil,
            returnAction: nil, accessibilityLabel: nil
        ),
    ]

    /// Phone layout: digits 1-2-3 sit in the top row (physical position of
    /// 7-8-9 in classic), so circular gestures follow the digit, not the
    /// position, not the grid slot. The top and bottom rows therefore swap
    /// their classic bindings; the middle row is unchanged.
    private static let phoneCircularOverrides: [String: KeyBinding] = {
        let slotRemap: [String: String] = [
            // Top row pulls from the classic bottom row, and vice versa.
            GridSlot.topLeft: GridSlot.bottomLeft,
            GridSlot.topCenter: GridSlot.bottomCenter,
            GridSlot.topRight: GridSlot.bottomRight,
            GridSlot.midLeft: GridSlot.midLeft,
            GridSlot.center: GridSlot.center,
            GridSlot.midRight: GridSlot.midRight,
            GridSlot.bottomLeft: GridSlot.topLeft,
            GridSlot.bottomCenter: GridSlot.topCenter,
            GridSlot.bottomRight: GridSlot.topRight,
        ]
        return slotRemap.reduce(into: [:]) { result, pair in
            result[pair.key] = classicCircularOverrides[pair.value]
        }
    }()

    // MARK: - Builder

    private static func buildMode(
        centerDigits: [[String]],
        zeroDigit: String,
        circularOverrides: [String: KeyBinding],
        backToAlphaLabel: String
    ) -> KeyboardMode {
        precondition(
            centerDigits.count == 3 && centerDigits.allSatisfy { $0.count == 3 },
            "centerDigits must be a 3×3 matrix"
        )
        var digitKeys: [String: KeyConfig] = [:]

        for (rowIdx, row) in centerDigits.enumerated() {
            for (colIdx, digit) in row.enumerated() {
                let slotId = GridSlot.allSlots[rowIdx][colIdx]

                // Start with shared punctuation defaults (same as letter layer),
                // but remove shift/capsLock bindings that don't apply to numeric.
                // This intentionally drops the entire binding including any returnAction
                // (e.g. midRight.swipeUp carries capitalizeWord as returnAction).
                var bindings: [GestureType: KeyBinding] = [:]
                for (gesture, binding) in CommonKeys.defaultSlotBindings[slotId] ?? [:] {
                    if case .switchMode = binding.action { continue }
                    bindings[gesture] = binding
                }

                // Merge numeric-specific extras (doesn't replace existing)
                if let extras = numericExtraSwipes[slotId] {
                    for (gesture, binding) in extras where bindings[gesture] == nil {
                        bindings[gesture] = binding
                    }
                }

                // Add circular gesture bindings
                if let circBinding = circularOverrides[slotId] {
                    bindings[.circularClockwise] = circBinding
                    bindings[.circularCounterclockwise] = circBinding
                }

                // Tap → digit. The same binding doubles as a long press:
                // GhostKeyResolver falls back to this layer for gestures the
                // letter layer leaves unbound, so holding a letter key types
                // its digit without a mode switch. Long presses only occur
                // with the opt-in "Type Numbers by Holding" setting enabled.
                let digitBinding = KeyBinding(
                    label: digit, action: .commitText(digit),
                    category: .digit, returnAction: nil, accessibilityLabel: nil
                )
                bindings[.tap] = digitBinding
                bindings[.longPress] = digitBinding

                digitKeys[slotId] = KeyConfig(
                    id: slotId, bindings: bindings, swipeMode: .eightWay,
                    slideType: .none, style: .primary, tapCycleActions: nil
                )
            }
        }

        let utilities = utilityKeys(zeroDigit: zeroDigit, backToAlphaLabel: backToAlphaLabel)
        precondition(
            Set(digitKeys.keys).isDisjoint(with: utilities.keys),
            "digit and utility key IDs must not overlap"
        )
        let allKeys = digitKeys.merging(utilities) { digit, _ in digit }

        return KeyboardMode(
            name: ModeNames.numeric,
            keys: allKeys,
            arrangements: StandardArrangements.numeric3x3,
            autoTransitions: [:]
        )
    }
}
