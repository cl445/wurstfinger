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
        // Tap is intentionally inert: switching the input method lives on the
        // swipe-left gesture below. The empty `.none` slot keeps the key's
        // accessibility label without re-triggering the globe on a plain tap;
        // `accessibilityActivationGesture` routes a VoiceOver activation to
        // that swipe so the label stays true for gesture-free input.
        bindings[.tap] = KeyBinding(
            label: "", action: .none,
            category: .utility, returnAction: nil,
            accessibilityLabel: String(localized: "Switch keyboard")
        )
        bindings[.swipeLeft] = KeyBinding(
            label: "", action: .advanceToNextInputMode,
            category: .utility, returnAction: nil,
            accessibilityLabel: String(localized: "Switch keyboard")
        )
        bindings[.swipeDown] = KeyBinding(
            label: "", action: .dismissKeyboard,
            category: .utility, returnAction: nil,
            accessibilityLabel: String(localized: "Hide keyboard")
        )
        bindings[.swipeRight] = KeyBinding(
            label: "", action: .switchToNextLanguage,
            category: .utility, returnAction: nil,
            accessibilityLabel: String(localized: "Next language")
        )
        return KeyConfig(
            id: UtilitySlot.globe, bindings: bindings,
            swipeMode: .fourWayCross, slideType: .none,
            style: .utility, tapCycleActions: nil,
            accessibilityActivationGesture: .swipeLeft
        )
    }()

    static let delete = KeyConfig.utility(
        UtilitySlot.delete, label: "⌫", action: .deleteBackward,
        swipeMode: .twoWayHorizontal, slideType: .delete,
        accessibilityLabel: String(localized: "Delete")
    )

    static let `return` = KeyConfig.utility(
        UtilitySlot.return, label: "↵", action: .newline,
        accessibilityLabel: String(localized: "New line")
    )

    /// Cut-all, bound to both circle directions below.
    ///
    /// Circling one key is easier to aim than circling a letter, and the key
    /// already owns the clipboard, so the gesture reads as "cut, but for
    /// everything". The direction is deliberately not distinguished: a thumb
    /// circle rarely comes out the way it was intended, and mapping the two
    /// directions to different clipboard actions would make a slip destructive.
    private static let cutAll = KeyBinding(
        label: "", action: .cutAll, category: .utility,
        returnAction: nil, accessibilityLabel: String(localized: "Cut all")
    )

    /// Clipboard bindings shared between the symbols key and numeric back-to-main key.
    static let clipboardBindings: [GestureType: KeyBinding] = [
        .swipeUp: KeyBinding(
            label: "", action: .copy, category: .utility,
            returnAction: nil, accessibilityLabel: String(localized: "Copy")
        ),
        .swipeUpRight: KeyBinding(
            label: "", action: .cut, category: .utility,
            returnAction: nil, accessibilityLabel: String(localized: "Cut")
        ),
        .swipeDown: KeyBinding(
            label: "", action: .paste, category: .utility,
            returnAction: nil, accessibilityLabel: String(localized: "Paste")
        ),
        .circularClockwise: cutAll,
        .circularCounterclockwise: cutAll,
    ]

    /// Switches to the numeric mode. The label is the glyph sequence "123",
    /// which VoiceOver reads as the *number* one hundred twenty-three, so the
    /// tap carries a semantic name — as every neighbouring utility key does.
    /// Its counterpart is `NumericLayouts.backToMain`, named "Letters".
    static let symbols = KeyConfig.utility(
        UtilitySlot.symbols, label: "123", action: .switchMode(ModeNames.numeric),
        swipeMode: .eightWay,
        swipes: clipboardBindings,
        accessibilityLabel: String(localized: "Numbers")
    )

    /// Space bar. The `zeroDigit` parameterizes the hold-for-digit output so
    /// each layout can emit its own native zero (e.g. Arabic ٠); it defaults to
    /// ASCII "0". `GridKeyboardFactory` and `NumericLayouts` pass the layout's
    /// first numeric digit.
    static func spacebar(zeroDigit: String = "0") -> KeyConfig {
        KeyConfig(
            id: UtilitySlot.space,
            bindings: [
                .tap: KeyBinding(
                    label: "␣", action: .space, category: .utility,
                    returnAction: nil, accessibilityLabel: String(localized: "Space")
                ),
                // The hold-for-digit feature pairs 0 with the space bar (no
                // letter-layer slot maps to 0 otherwise). Long presses
                // only occur with the opt-in setting enabled, so this is inert by
                // default; .longPress has no hint alignment, so nothing renders.
                .longPress: KeyBinding(
                    label: zeroDigit, action: .commitText(zeroDigit),
                    category: .digit, returnAction: nil, accessibilityLabel: nil
                ),
            ],
            swipeMode: .none,
            slideType: .moveCursor,
            style: .spacebar,
            tapCycleActions: nil
        )
    }

    /// All utility keys as dictionary, mergeable with language keys.
    static let allUtilityKeys: [String: KeyConfig] = [
        UtilitySlot.globe: globe,
        UtilitySlot.delete: delete,
        UtilitySlot.return: `return`,
        UtilitySlot.symbols: symbols,
        UtilitySlot.space: spacebar(),
    ]

    // MARK: - Default Slot Bindings

    /// Shared punctuation, symbol, compose, and action bindings for each grid slot.
    /// The factory merges these with language-specific center characters.
    /// Each KeyBinding includes both the primary action and an optional return-swipe action.
    ///
    /// **Which of these carry an `accessibilityLabel`, and why so few.** A label
    /// is the opt-in for a VoiceOver custom action (`KeyConfig.accessibilityActions`)
    /// and every named binding becomes a rotor entry on that key, so naming all
    /// eight directions would put eight to sixteen entries on every letter key —
    /// exactly what the opt-in exists to prevent. Until swipe outputs can be
    /// offered as generated, spoken-glyph actions (follow-up design work), only
    /// bindings that are unreachable without gestures *and* have no workaround
    /// are named:
    ///
    /// - `,` `.` `?` — sentence punctuation. Auto-capitalization and the
    ///   double-space shortcut can stand in for a period; nothing stands in for
    ///   comma and question mark, and a keyboard that cannot end a question is
    ///   not usable without gestures.
    /// - `⇧` / `⇩` — deliberate capitalization. Auto-capitalization only produces
    ///   sentence-initial capitals, so names and acronyms need the modifier. Both
    ///   directions are named so that caps lock is not a one-way door: `⇧` in the
    ///   caps-lock mode is a no-op, and `⇩` is the only way back.
    ///
    /// Letter bindings stay unnamed on purpose: a key's own center letter is
    /// already reachable by activating it, and naming its other eight directions
    /// is the flooding case above. Names state the *function*, not the glyph, so
    /// `GridKeyboardFactory` hands them down when a layout substitutes its own
    /// script's mark (Arabic `،`, Japanese `。`).
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
                returnAction: .compose(trigger: "ˇ"), accessibilityLabel: nil
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
                returnAction: .commitText("¿"),
                accessibilityLabel: String(localized: "Question mark")
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
            // `KeyboardMode.replacingShiftUpBinding` repoints this to caps lock
            // in the shifted mode and to a no-op in caps lock itself, which
            // matches how a single shift key behaves everywhere else — and it
            // decides the name per mode, because the caps-lock no-op must not
            // become a rotor action. The return swipe (`capitalizeWord`) cannot
            // be named separately: a binding carries one label, and a custom
            // action always dispatches `isReturn: false`.
            .swipeUp: KeyBinding(
                label: "⇧", action: .switchMode(ModeNames.shifted), category: .modifier,
                returnAction: .capitalizeWord(uppercased: true),
                accessibilityLabel: String(localized: "Shift")
            ),
            .swipeUpRight: KeyBinding(
                label: "}", action: .commitText("}"), category: nil,
                returnAction: .commitText("{"), accessibilityLabel: nil
            ),
            .swipeRight: KeyBinding(
                label: ")", action: .commitText(")"), category: nil,
                returnAction: .commitText("("), accessibilityLabel: nil
            ),
            // Only present in the shifted and caps-lock modes (the factory strips
            // it from main). Named because it is the only way out of caps lock,
            // where the ⇧ above switches to the mode it is already in.
            .swipeDown: KeyBinding(
                label: "⇩", action: .switchMode(ModeNames.main), category: .modifier,
                returnAction: nil, accessibilityLabel: String(localized: "Lowercase")
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
                label: "*", action: .commitText("*"), category: nil,
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
                returnAction: .commitText("…"),
                accessibilityLabel: String(localized: "Period")
            ),
            .swipeDownLeft: KeyBinding(
                label: ",", action: .commitText(","), category: nil,
                returnAction: .commitText(","),
                accessibilityLabel: String(localized: "Comma")
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
