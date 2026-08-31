//
//  KeyDefinition.swift
//  Wurstfinger
//
//  Complete definition of a single key (behavior, not layout).
//

import Foundation

/// Complete definition of a single key (behavior, not layout).
struct KeyDefinition: Codable, Equatable, Identifiable {
    /// Semantic slot name (e.g. "topLeft", "center", "globe")
    let id: String

    /// Binding for each gesture. Only set entries are active.
    /// `var` so a derived key (shifted mode, removed binding) can be made by
    /// copying this one and swapping the bindings — rebuilding it field by
    /// field silently drops everything added to the type later.
    var bindings: [GestureType: KeyBinding]

    /// Allowed swipe directions (default: .eightWay)
    let swipeMode: SwipeMode

    /// Special drag behavior
    let slideType: SlideType

    /// Visual role — affects styling, not logic
    let style: KeyStyle

    /// Optional multi-tap actions (e.g. space → comma → period → ?)
    /// Inspired by Thumb-Key's nextTapActions
    let tapCycleActions: [KeyAction]?

    /// Gesture an assistive technology performs instead of the tap it would
    /// otherwise synthesize. Only needed where the tap is deliberately inert
    /// (the globe, whose input-method switch lives on swipe-left): without it
    /// a VoiceOver double tap resolves to `.none` and the key is unreachable.
    var accessibilityActivationGesture: GestureType? = nil
}
