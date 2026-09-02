//
//  KeyDefinition+Factories.swift
//  Wurstfinger
//
//  Convenience factory methods for creating KeyDefinition instances.
//

import Foundation

extension KeyDefinition {
    /// Creates a utility key (Globe, Delete, Return, etc.)
    static func utility(
        _ id: String,
        label: String,
        action: KeyAction,
        swipeMode: SwipeMode = .none,
        slideType: SlideType = .none,
        swipes: [GestureType: KeyBinding] = [:],
        accessibilityLabel: String? = nil
    ) -> KeyDefinition {
        var bindings = swipes
        bindings[.tap] = KeyBinding(
            label: label, action: action,
            category: .utility, returnAction: nil,
            accessibilityLabel: accessibilityLabel
        )
        return KeyDefinition(
            id: id, bindings: bindings, swipeMode: swipeMode,
            slideType: slideType, style: .utility, tapCycleActions: nil
        )
    }
}
