//
//  ModeTransitionMiddleware.swift
//  Wurstfinger
//
//  Applies KeyboardMode.autoTransitions after an action completes.
//

import Foundation

/// Runs after all other middlewares and applies the state machine defined
/// in `KeyboardMode.autoTransitions`.
///
/// If the current mode declares a transition for the category of the
/// action's binding (e.g. `.letter → main` in `shifted`), `onModeChange`
/// is invoked with the target mode name.
///
/// The middleware does not mutate state itself — the owner of the pipeline
/// decides what to do with the callback (update a `@Published` mode name,
/// re-configure arrangements, …).
struct ModeTransitionMiddleware: ActionMiddleware {
    let definition: KeyboardDefinition
    let onModeChange: (String) -> Void

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        next(context)
        guard let currentMode = definition.modes[context.mode] else { return }
        let category = Self.transitionCategory(for: context)
        guard let nextMode = currentMode.nextMode(after: category) else { return }
        guard nextMode != context.mode else { return }
        onModeChange(nextMode)
    }

    /// Category driving the auto-transition lookup.
    ///
    /// Normally the binding's resolved category. Compose bindings are the
    /// exception: `ComposeMiddleware` rewrites their action before it gets
    /// here (`.compose("´")` → `.commitText("á")`), and the transition must
    /// follow the *result* — a composed letter consumes a one-shot shift
    /// exactly like a plain letter, while a compose trigger that merely
    /// commits its trigger character behaves like a symbol and keeps shift
    /// engaged (matching iOS system shift semantics).
    static func transitionCategory(for context: ActionContext) -> KeyCategory {
        guard let binding = context.binding else { return context.action.inferredCategory }
        if binding.resolvedCategory == .compose, context.action != binding.action {
            return context.action.inferredCategory
        }
        return binding.resolvedCategory
    }
}
