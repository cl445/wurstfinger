//
//  NumericLayouts.swift
//  Wurstfinger
//
//  Numeric keyboard modes (phone and classic digit ordering).
//

import Foundation

/// Numeric keyboard modes shared across all languages.
enum NumericLayouts {
    /// Default Latin label for the back-to-alpha key. Languages whose
    /// alphabet is not Latin (Hebrew, Russian, …) should pass their own
    /// script-appropriate label via `phone(backToAlphaLabel:)`.
    static let defaultBackToAlphaLabel = "abc"

    /// Phone-style layout (1-2-3 in top row).
    static func phone(backToAlphaLabel: String = defaultBackToAlphaLabel) -> KeyboardMode {
        buildMode(
            centerDigits: [
                ["1", "2", "3"],
                ["4", "5", "6"],
                ["7", "8", "9"],
            ],
            backToAlphaLabel: backToAlphaLabel
        )
    }

    /// Classic calculator style (7-8-9 in top row).
    static func classic(backToAlphaLabel: String = defaultBackToAlphaLabel) -> KeyboardMode {
        buildMode(
            centerDigits: [
                ["7", "8", "9"],
                ["4", "5", "6"],
                ["1", "2", "3"],
            ],
            backToAlphaLabel: backToAlphaLabel
        )
    }

    // MARK: - Numeric Utility Keys

    /// Builds the symbols key in numeric mode, which switches back to main.
    /// The label is locale/script-aware so non-Latin keyboards (e.g. Hebrew,
    /// Russian) can show an appropriate label instead of the Latin "abc".
    private static func backToMain(label: String) -> KeyConfig {
        KeyConfig.utility(
            UtilitySlot.symbols, label: label, action: .switchMode(ModeNames.main)
        )
    }

    /// Space key with "0" on tap in numeric mode.
    private static let spaceWithZero = KeyConfig.utility(
        UtilitySlot.space, label: "0", action: .commitText("0"),
        slideType: .moveCursor
    )

    /// Builds the utility-key dictionary for numeric mode using the supplied
    /// back-to-alpha label.
    private static func utilityKeys(backToAlphaLabel: String) -> [String: KeyConfig] {
        [
            UtilitySlot.globe: CommonKeys.globe,
            UtilitySlot.delete: CommonKeys.delete,
            UtilitySlot.return: CommonKeys.return,
            UtilitySlot.symbols: backToMain(label: backToAlphaLabel),
            UtilitySlot.space: spaceWithZero,
        ]
    }

    // MARK: - Symbol Swipes per Digit

    /// Default symbol swipes for each digit key position.
    private static let digitSwipes: [String: [GestureType: String]] = [
        GridSlot.topLeft: [
            .swipeRight: "#",
            .swipeDown: "(",
            .swipeDownRight: "/",
        ],
        GridSlot.topCenter: [
            .swipeDown: "$",
            .swipeLeft: "+",
            .swipeRight: "!",
        ],
        GridSlot.topRight: [
            .swipeLeft: ")",
            .swipeDown: "=",
            .swipeDownLeft: "\\",
        ],
        GridSlot.midLeft: [
            .swipeRight: "*",
            .swipeUp: "[",
            .swipeDown: "{",
        ],
        GridSlot.midRight: [
            .swipeLeft: "%",
            .swipeUp: "]",
            .swipeDown: "}",
        ],
        GridSlot.bottomLeft: [
            .swipeRight: "-",
            .swipeUp: "<",
        ],
        GridSlot.bottomCenter: [
            .swipeDown: ".",
            .swipeLeft: ",",
            .swipeRight: ":",
        ],
        GridSlot.bottomRight: [
            .swipeLeft: "@",
            .swipeUp: ">",
        ],
    ]

    // MARK: - Builder

    private static func buildMode(centerDigits: [[String]], backToAlphaLabel: String) -> KeyboardMode {
        precondition(
            centerDigits.count == 3 && centerDigits.allSatisfy { $0.count == 3 },
            "centerDigits must be a 3×3 matrix"
        )
        var digitKeys: [String: KeyConfig] = [:]

        for (rowIdx, row) in centerDigits.enumerated() {
            for (colIdx, digit) in row.enumerated() {
                let slotId = GridSlot.allSlots[rowIdx][colIdx]
                var bindings: [GestureType: KeyBinding] = [:]

                // Tap → digit
                bindings[.tap] = KeyBinding(
                    label: digit, action: .commitText(digit),
                    category: .digit, returnAction: nil, accessibilityLabel: nil
                )

                // Symbol swipes
                if let swipes = digitSwipes[slotId] {
                    for (gesture, symbol) in swipes {
                        bindings[gesture] = KeyBinding(
                            label: symbol, action: .commitText(symbol),
                            category: nil, returnAction: nil, accessibilityLabel: nil
                        )
                    }
                }

                digitKeys[slotId] = KeyConfig(
                    id: slotId, bindings: bindings, swipeMode: .eightWay,
                    slideType: .none, style: .primary, tapCycleActions: nil
                )
            }
        }

        let allKeys = digitKeys.merging(utilityKeys(backToAlphaLabel: backToAlphaLabel)) { digit, _ in digit }

        return KeyboardMode(
            name: ModeNames.numeric,
            keys: allKeys,
            arrangements: StandardArrangements.grid3x3,
            autoTransitions: [:],
            doubleTapMode: nil
        )
    }
}
