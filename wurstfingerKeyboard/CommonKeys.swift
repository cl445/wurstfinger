//
//  CommonKeys.swift
//  Wurstfinger
//
//  Shared key definitions reusable across all MessagEase languages.
//

import Foundation

/// Shared key definitions reusable across all MessagEase languages.
/// Utility keys and default punctuation/symbol bindings for the 3x3 grid.
enum CommonKeys {
    // MARK: - Utility Keys

    static let globe: KeyConfig = {
        var bindings: [GestureType: KeyBinding] = [:]
        bindings[.tap] = KeyBinding(
            label: "", action: .advanceToNextInputMode,
            category: .utility, returnAction: nil,
            accessibilityLabel: "Tastatur wechseln"
        )
        bindings[.swipeLeft] = KeyBinding(
            label: "", action: .advanceToNextInputMode,
            category: .utility, returnAction: nil, accessibilityLabel: nil
        )
        bindings[.swipeDown] = KeyBinding(
            label: "", action: .dismissKeyboard,
            category: .utility, returnAction: nil,
            accessibilityLabel: "Tastatur ausblenden"
        )
        return KeyConfig(
            id: UtilitySlot.globe, bindings: bindings,
            swipeMode: .fourWayCross, slideType: .none,
            style: .utility, tapCycleActions: nil
        )
    }()

    static let delete = KeyConfig.utility(
        UtilitySlot.delete, label: "⌫", action: .deleteBackward,
        swipeMode: .twoWayHorizontal, slideType: .delete,
        accessibilityLabel: "Löschen"
    )

    static let `return` = KeyConfig.utility(
        UtilitySlot.return, label: "↵", action: .newline,
        accessibilityLabel: "Zeilenumbruch"
    )

    static let symbols = KeyConfig.utility(
        UtilitySlot.symbols, label: "123", action: .switchMode(ModeNames.numeric),
        swipeMode: .eightWay,
        swipes: [
            .swipeUp: KeyBinding(
                label: "", action: .copy, category: .utility,
                returnAction: nil, accessibilityLabel: "Kopieren"
            ),
            .swipeUpRight: KeyBinding(
                label: "", action: .cut, category: .utility,
                returnAction: nil, accessibilityLabel: "Ausschneiden"
            ),
            .swipeDown: KeyBinding(
                label: "", action: .paste, category: .utility,
                returnAction: nil, accessibilityLabel: "Einsetzen"
            ),
        ]
    )

    static let spacebar = KeyConfig(
        id: UtilitySlot.space,
        bindings: [
            .tap: KeyBinding(
                label: "␣", action: .space, category: .utility,
                returnAction: nil, accessibilityLabel: nil
            ),
        ],
        swipeMode: .none,
        slideType: .moveCursor,
        style: .spacebar,
        tapCycleActions: nil
    )

    /// All utility keys as dictionary, mergeable with language keys.
    static let allUtilityKeys: [String: KeyConfig] = [
        UtilitySlot.globe: globe,
        UtilitySlot.delete: delete,
        UtilitySlot.return: `return`,
        UtilitySlot.symbols: symbols,
        UtilitySlot.space: spacebar,
    ]

    // MARK: - Default Slot Bindings

    /// Shared punctuation, symbol, compose, and action bindings for each grid slot.
    /// The factory merges these with language-specific center characters.
    /// Each KeyBinding includes both the primary action and an optional return-swipe action.
    static let defaultSlotBindings: [String: [GestureType: KeyBinding]] = [
        // MARK: topLeft

        GridSlot.topLeft: [
            .swipeUpLeft: KeyBinding(
                label: "\u{1F152}", action: .cycleAccents, category: .compose,
                returnAction: .cycleAccents, accessibilityLabel: nil
            ),
            .swipeRight: KeyBinding(
                label: "-", action: .commitText("-"), category: nil,
                returnAction: .commitText("÷"), accessibilityLabel: nil
            ),
            .swipeDownLeft: KeyBinding(
                label: "$", action: .compose(trigger: "$"), category: .compose,
                returnAction: .commitText("¥"), accessibilityLabel: nil
            ),
        ],

        // MARK: topCenter

        GridSlot.topCenter: [
            .swipeUpLeft: KeyBinding(
                label: "`", action: .compose(trigger: "ˋ"), category: .compose,
                returnAction: .commitText("\u{2018}"), accessibilityLabel: nil
            ),
            .swipeUp: KeyBinding(
                label: "^", action: .compose(trigger: "^"), category: .compose,
                returnAction: .commitText("ˆ"), accessibilityLabel: nil
            ),
            .swipeUpRight: KeyBinding(
                label: "´", action: .compose(trigger: "´"), category: .compose,
                returnAction: .commitText("\u{2019}"), accessibilityLabel: nil
            ),
            .swipeRight: KeyBinding(
                label: "!", action: .commitText("!"), category: nil,
                returnAction: .commitText("¡"), accessibilityLabel: nil
            ),
            .swipeDownRight: KeyBinding(
                label: "\\", action: .commitText("\\"), category: nil,
                returnAction: .commitText("—"), accessibilityLabel: nil
            ),
            .swipeDownLeft: KeyBinding(
                label: "/", action: .commitText("/"), category: nil,
                returnAction: .commitText("–"), accessibilityLabel: nil
            ),
            .swipeLeft: KeyBinding(
                label: "+", action: .commitText("+"), category: nil,
                returnAction: .commitText("×"), accessibilityLabel: nil
            ),
        ],

        // MARK: topRight

        GridSlot.topRight: [
            .swipeUpRight: KeyBinding(
                label: "", action: .commitText("\n"), category: nil,
                returnAction: .commitText("\n"), accessibilityLabel: nil
            ),
            .swipeDownRight: KeyBinding(
                label: "€", action: .commitText("€"), category: nil,
                returnAction: .commitText("£"), accessibilityLabel: nil
            ),
            .swipeDown: KeyBinding(
                label: "=", action: .commitText("="), category: nil,
                returnAction: .commitText("±"), accessibilityLabel: nil
            ),
            .swipeLeft: KeyBinding(
                label: "?", action: .commitText("?"), category: nil,
                returnAction: .commitText("¿"), accessibilityLabel: nil
            ),
        ],

        // MARK: midLeft

        GridSlot.midLeft: [
            .swipeUpLeft: KeyBinding(
                label: "{", action: .commitText("{"), category: nil,
                returnAction: .commitText("}"), accessibilityLabel: nil
            ),
            .swipeUpRight: KeyBinding(
                label: "%", action: .commitText("%"), category: nil,
                returnAction: .commitText("‰"), accessibilityLabel: nil
            ),
            .swipeDownRight: KeyBinding(
                label: "_", action: .commitText("_"), category: nil,
                returnAction: .commitText("¬"), accessibilityLabel: nil
            ),
            .swipeDownLeft: KeyBinding(
                label: "[", action: .commitText("["), category: nil,
                returnAction: .commitText("]"), accessibilityLabel: nil
            ),
            .swipeLeft: KeyBinding(
                label: "(", action: .commitText("("), category: nil,
                returnAction: .commitText(")"), accessibilityLabel: nil
            ),
        ],

        // MARK: center — no defaults (all 8 directions are language-specific)

        // MARK: midRight

        GridSlot.midRight: [
            .swipeUpLeft: KeyBinding(
                label: "|", action: .commitText("|"), category: nil,
                returnAction: .commitText("¶"), accessibilityLabel: nil
            ),
            .swipeUp: KeyBinding(
                label: "⇧", action: .switchMode(ModeNames.shifted), category: .modifier,
                returnAction: .capitalizeWord(uppercased: true), accessibilityLabel: nil
            ),
            .swipeUpRight: KeyBinding(
                label: "}", action: .commitText("}"), category: nil,
                returnAction: .commitText("{"), accessibilityLabel: nil
            ),
            .swipeRight: KeyBinding(
                label: ")", action: .commitText(")"), category: nil,
                returnAction: .commitText("("), accessibilityLabel: nil
            ),
            .swipeDown: KeyBinding(
                label: "⇩", action: .switchMode(ModeNames.main), category: .modifier,
                returnAction: nil, accessibilityLabel: nil
            ),
            .swipeDownRight: KeyBinding(
                label: "]", action: .commitText("]"), category: nil,
                returnAction: .commitText("["), accessibilityLabel: nil
            ),
            .swipeDownLeft: KeyBinding(
                label: "@", action: .commitText("@"), category: nil,
                returnAction: .commitText("ª"), accessibilityLabel: nil
            ),
        ],

        // MARK: bottomLeft

        GridSlot.bottomLeft: [
            .swipeUpLeft: KeyBinding(
                label: "~", action: .compose(trigger: "~"), category: .compose,
                returnAction: .commitText("˜"), accessibilityLabel: nil
            ),
            .swipeUp: KeyBinding(
                label: "¨", action: .compose(trigger: "¨"), category: .compose,
                returnAction: .commitText("˝"), accessibilityLabel: nil
            ),
            .swipeRight: KeyBinding(
                label: "*", action: .compose(trigger: "*"), category: .compose,
                returnAction: .commitText("†"), accessibilityLabel: nil
            ),
            .swipeDownRight: KeyBinding(
                label: "⇥", action: .commitText("\t"), category: nil,
                returnAction: .commitText("\t"), accessibilityLabel: nil
            ),
            .swipeLeft: KeyBinding(
                label: "<", action: .commitText("<"), category: nil,
                returnAction: .commitText("‹"), accessibilityLabel: nil
            ),
        ],

        // MARK: bottomCenter

        GridSlot.bottomCenter: [
            .swipeUpLeft: KeyBinding(
                label: "\"", action: .commitText("\""), category: nil,
                returnAction: .commitText("\u{201C}"), accessibilityLabel: nil
            ),
            .swipeUpRight: KeyBinding(
                label: "'", action: .commitText("'"), category: nil,
                returnAction: .commitText("\u{201D}"), accessibilityLabel: nil
            ),
            .swipeDownRight: KeyBinding(
                label: ":", action: .commitText(":"), category: nil,
                returnAction: .commitText("„"), accessibilityLabel: nil
            ),
            .swipeDown: KeyBinding(
                label: ".", action: .commitText("."), category: nil,
                returnAction: .commitText("…"), accessibilityLabel: nil
            ),
            .swipeDownLeft: KeyBinding(
                label: ",", action: .commitText(","), category: nil,
                returnAction: .commitText(","), accessibilityLabel: nil
            ),
        ],

        // MARK: bottomRight

        GridSlot.bottomRight: [
            .swipeUp: KeyBinding(
                label: "&", action: .commitText("&"), category: nil,
                returnAction: .commitText("§"), accessibilityLabel: nil
            ),
            .swipeUpRight: KeyBinding(
                label: "°", action: .compose(trigger: "°"), category: .compose,
                returnAction: .commitText("º"), accessibilityLabel: nil
            ),
            .swipeRight: KeyBinding(
                label: ">", action: .commitText(">"), category: nil,
                returnAction: .commitText("›"), accessibilityLabel: nil
            ),
            .swipeDownRight: KeyBinding(
                label: "", action: .commitText(" "), category: nil,
                returnAction: .commitText(" "), accessibilityLabel: nil
            ),
            .swipeDownLeft: KeyBinding(
                label: ";", action: .commitText(";"), category: nil,
                returnAction: .commitText(";"), accessibilityLabel: nil
            ),
            .swipeLeft: KeyBinding(
                label: "#", action: .commitText("#"), category: nil,
                returnAction: .commitText("£"), accessibilityLabel: nil
            ),
        ],
    ]
}
