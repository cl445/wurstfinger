//
//  KeyboardMode.swift
//  Wurstfinger
//
//  A complete keyboard mode (e.g. lowercase, uppercase, numbers).
//

import Foundation

/// A complete keyboard mode (e.g. lowercase, uppercase, numbers).
/// Separates key definitions (WHAT the keys do) from arrangements (WHERE they are).
/// Contains state machine rules for automatic mode transitions.
struct KeyboardMode: Codable, Equatable {
    /// Unique name of the mode
    let name: String

    /// Pool of all keys in this mode, accessible by ID
    let keys: [String: KeyConfig]

    /// Different grid arrangements for different contexts.
    /// At least `.portrait` must be present.
    let arrangements: [ArrangementContext: GridArrangement]

    // MARK: - State Machine

    /// Automatic mode transitions after input of a certain category.
    /// e.g. in "shifted" mode: [.letter: "main"] → after letter back to main.
    /// Empty dictionary = mode stays active (like caps lock or numeric).
    ///
    /// Note: double-tap-shift → caps lock is not a mode property; it is
    /// implemented by rebinding shift-up in `GridKeyboardFactory`.
    let autoTransitions: [KeyCategory: String]

    // MARK: - Convenience

    func key(for id: String) -> KeyConfig? {
        keys[id]
    }

    func arrangement(for context: ArrangementContext) -> GridArrangement? {
        arrangements[context] ?? arrangements[.portrait]
    }

    /// Determines the next mode after an action with the given category.
    /// Returns nil if the current mode should be kept.
    func nextMode(after category: KeyCategory) -> String? {
        autoTransitions[category]
    }

    /// Creates a copy with changed state machine properties.
    func with(
        name: String? = nil,
        autoTransitions: [KeyCategory: String]? = nil
    ) -> KeyboardMode {
        KeyboardMode(
            name: name ?? self.name,
            keys: keys,
            arrangements: arrangements,
            autoTransitions: autoTransitions ?? self.autoTransitions
        )
    }

    /// Returns a copy with a specific binding removed from a key.
    func removingBinding(keyId: String, gesture: GestureType) -> KeyboardMode {
        guard var key = keys[keyId] else { return self }
        var bindings = key.bindings
        bindings.removeValue(forKey: gesture)
        key = KeyConfig(
            id: key.id, bindings: bindings, swipeMode: key.swipeMode,
            slideType: key.slideType, style: key.style,
            tapCycleActions: key.tapCycleActions
        )
        var updatedKeys = keys
        updatedKeys[keyId] = key
        return KeyboardMode(
            name: name, keys: updatedKeys, arrangements: arrangements,
            autoTransitions: autoTransitions
        )
    }

    /// Returns a copy with a binding removed only when its action matches
    /// `expected`. Used to strip an auto-generated affordance (e.g. the shift
    /// binding on a caseless layout's midRight key) without clobbering a
    /// language letter that a directional override placed on the same gesture.
    func removingBinding(keyId: String, gesture: GestureType, ifAction expected: KeyAction) -> KeyboardMode {
        guard keys[keyId]?.bindings[gesture]?.action == expected else { return self }
        return removingBinding(keyId: keyId, gesture: gesture)
    }

    /// Returns a copy where the shift-up binding on midRight is replaced.
    /// Used to point shifted → capsLock and capsLock → capsLock (no-op).
    func replacingShiftUpBinding(label: String, action: KeyAction) -> KeyboardMode {
        guard var midRight = keys[GridSlot.midRight],
              let existing = midRight.bindings[.swipeUp]
        else { return self }
        var bindings = midRight.bindings
        bindings[.swipeUp] = KeyBinding(
            label: label, action: action,
            category: existing.category, returnAction: existing.returnAction,
            accessibilityLabel: existing.accessibilityLabel
        )
        midRight = KeyConfig(
            id: midRight.id, bindings: bindings, swipeMode: midRight.swipeMode,
            slideType: midRight.slideType, style: midRight.style,
            tapCycleActions: midRight.tapCycleActions
        )
        var updatedKeys = keys
        updatedKeys[GridSlot.midRight] = midRight
        return KeyboardMode(
            name: name, keys: updatedKeys, arrangements: arrangements,
            autoTransitions: autoTransitions
        )
    }
}
