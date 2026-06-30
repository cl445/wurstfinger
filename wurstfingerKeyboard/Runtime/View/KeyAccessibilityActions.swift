//
//  KeyAccessibilityActions.swift
//  Wurstfinger
//
//  Exposes a key's non-tap gestures to assistive technologies.
//

import SwiftUI

/// Makes a key operable without gestures.
///
/// VoiceOver activates an element by synthesizing a touch, which reaches the
/// gesture recognizer as a plain tap — so every swipe-only binding is out of
/// reach, including the globe's input-method switch, whose tap is inert by
/// design. Each labelled binding becomes a named custom action, and a key
/// with an inert tap additionally overrides the element's default activation
/// with the gesture it declares. Both dispatch through the same `onGesture`
/// callback as a real touch, so they share the resolver chain and pipeline.
struct KeyAccessibilityActions: ViewModifier {
    let key: KeyConfig
    let onGesture: (KeyConfig, GestureClassification) -> Void

    func body(content: Content) -> some View {
        withActivation(content)
            .accessibilityActions {
                ForEach(key.accessibilityActions, id: \.gesture) { action in
                    Button(action.name) { onGesture(key, Self.classification(action.gesture)) }
                }
            }
    }

    /// A synthesized activation carries no real touch, so it reports the
    /// centre of the key as its touchdown and no feature vector — it must not
    /// feed the touch-offset learner a made-up sample (a centred touchdown
    /// carries zero error and moves no offset).
    static func classification(_ gesture: GestureType) -> GestureClassification {
        GestureClassification(gesture: gesture, isReturn: false)
    }

    /// Applied only where it is needed: a key whose tap already acts keeps the
    /// synthesized tap, so activation and touch stay one code path.
    @ViewBuilder
    private func withActivation(_ content: Content) -> some View {
        if let gesture = key.accessibilityActivationOverride {
            content.accessibilityAction { onGesture(key, Self.classification(gesture)) }
        } else {
            content
        }
    }
}
