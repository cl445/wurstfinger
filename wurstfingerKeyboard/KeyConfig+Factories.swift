//
//  KeyConfig+Factories.swift
//  Wurstfinger
//
//  Convenience factory methods for creating KeyConfig instances.
//

import Foundation

extension KeyConfig {
    /// Creates a letter key. Category is automatically derived from the action.
    static func letter(
        _ id: String,
        tap: String,
        swipes: [GestureType: String] = [:],
        returnSwipes: [GestureType: String] = [:],
        composeSwipes: [GestureType: (trigger: String, label: String)] = [:]
    ) -> KeyConfig {
        var bindings: [GestureType: KeyBinding] = [:]
        bindings[.tap] = KeyBinding(
            label: tap, action: .commitText(tap),
            category: nil, returnAction: nil, accessibilityLabel: nil
        )
        for (gesture, char) in swipes {
            bindings[gesture] = KeyBinding(
                label: char, action: .commitText(char), category: nil,
                returnAction: returnSwipes[gesture].map { .commitText($0) },
                accessibilityLabel: nil
            )
        }
        for (gesture, compose) in composeSwipes {
            bindings[gesture] = KeyBinding(
                label: compose.label, action: .compose(trigger: compose.trigger),
                category: .compose, returnAction: nil, accessibilityLabel: nil
            )
        }
        return KeyConfig(
            id: id, bindings: bindings, swipeMode: .eightWay,
            slideType: .none, style: .primary, tapCycleActions: nil
        )
    }

    /// Creates a utility key (Globe, Delete, Return, etc.)
    static func utility(
        _ id: String,
        label: String,
        action: KeyAction,
        swipeMode: SwipeMode = .none,
        slideType: SlideType = .none,
        swipes: [GestureType: KeyBinding] = [:],
        accessibilityLabel: String? = nil
    ) -> KeyConfig {
        var bindings = swipes
        bindings[.tap] = KeyBinding(
            label: label, action: action,
            category: .utility, returnAction: nil,
            accessibilityLabel: accessibilityLabel
        )
        return KeyConfig(
            id: id, bindings: bindings, swipeMode: swipeMode,
            slideType: slideType, style: .utility, tapCycleActions: nil
        )
    }
}
