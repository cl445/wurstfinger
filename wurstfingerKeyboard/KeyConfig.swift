//
//  KeyConfig.swift
//  Wurstfinger
//
//  Complete definition of a single key (behavior, not layout).
//

import Foundation

/// Complete definition of a single key (behavior, not layout).
struct KeyConfig: Codable, Equatable, Identifiable {
    /// Semantic slot name (e.g. "topLeft", "center", "globe")
    let id: String

    /// Binding for each gesture. Only set entries are active.
    let bindings: [GestureType: KeyBinding]

    /// Allowed swipe directions (default: .eightWay)
    let swipeMode: SwipeMode

    /// Special drag behavior
    let slideType: SlideType

    /// Visual role — affects styling, not logic
    let style: KeyStyle

    /// Optional multi-tap actions (e.g. space → comma → period → ?)
    /// Inspired by Thumb-Key's nextTapActions
    let tapCycleActions: [KeyAction]?
}
