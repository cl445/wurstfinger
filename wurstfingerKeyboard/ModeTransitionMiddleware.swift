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
        let category = context.binding?.resolvedCategory
            ?? context.action.inferredCategory
        guard let nextMode = currentMode.nextMode(after: category) else { return }
        guard nextMode != context.mode else { return }
        onModeChange(nextMode)
    }
}
