//
//  NumericLayouts.swift
//  Wurstfinger
//
//  Numeric keyboard modes (phone and classic digit ordering).
//

import Foundation

/// Numeric keyboard modes shared across all languages.
enum NumericLayouts {
    /// Phone-style layout (1-2-3 in top row).
    static let phone: KeyboardMode = buildMode(centerDigits: [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
    ])

    /// Classic calculator style (7-8-9 in top row).
    static let classic: KeyboardMode = buildMode(centerDigits: [
        ["7", "8", "9"],
        ["4", "5", "6"],
        ["1", "2", "3"],
    ])

    // MARK: - Numeric Utility Keys

    /// Symbols key in numeric mode switches back to main (label "abc").
    private static let backToMain = KeyConfig.utility(
        UtilitySlot.symbols, label: "abc", action: .switchMode(ModeNames.main)
    )

    /// Space key with "0" on tap in numeric mode.
    private static let spaceWithZero = KeyConfig.utility(
        UtilitySlot.space, label: "0", action: .commitText("0"),
        slideType: .moveCursor
    )

    /// Utility keys for numeric mode (symbols → back to main, space → 0).
    private static let utilityKeys: [String: KeyConfig] = [
        UtilitySlot.globe: CommonKeys.globe,
        UtilitySlot.delete: CommonKeys.delete,
        UtilitySlot.return: CommonKeys.return,
        UtilitySlot.symbols: backToMain,
        UtilitySlot.space: spaceWithZero,
    ]

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

    private static func buildMode(centerDigits: [[String]]) -> KeyboardMode {
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

        let allKeys = digitKeys.merging(utilityKeys) { digit, _ in digit }

        return KeyboardMode(
            name: ModeNames.numeric,
            keys: allKeys,
            arrangements: StandardArrangements.grid3x3,
            autoTransitions: [:],
            doubleTapMode: nil
        )
    }
}
