//
//  KeyConfig+Factories.swift
//  Wurstfinger
//
//  Convenience factory methods for creating KeyConfig instances.
//

import Foundation

extension KeyConfig {
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
