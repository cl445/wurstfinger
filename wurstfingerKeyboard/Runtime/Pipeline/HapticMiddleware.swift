//
//  HapticMiddleware.swift
//  Wurstfinger
//
//  Triggers haptic feedback as an action flows through the pipeline.
//

import Foundation

/// Passes the current action to the injected feedback trigger, then forwards
/// the context unchanged. The trigger decides which actions get feedback:
/// state-changing actions receive a confirmation tick, text actions stay
/// silent because their haptic already fired on touch-down.
///
/// The concrete feedback implementation is injected as a closure so this
/// file stays free of UIKit/`HapticFeedbackManager` dependencies. Wiring
/// happens in `KeyboardViewModel` when the pipeline is assembled.
struct HapticMiddleware: ActionMiddleware {
    /// Called with the action before it is forwarded.
    let trigger: (KeyAction) -> Void

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        trigger(context.action)
        next(context)
    }
}
