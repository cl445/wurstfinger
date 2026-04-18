//
//  ActionPipeline.swift
//  Wurstfinger
//
//  Composes multiple ActionMiddlewares into a processing chain.
//

import Foundation

/// Composes multiple `ActionMiddleware`s into a processing chain.
///
/// Each middleware receives the `ActionContext` and may mutate it before
/// calling `next`. The pipeline guarantees ordered execution and short-
/// circuits cleanly if any middleware skips calling `next`.
struct ActionPipeline {
    let middlewares: [ActionMiddleware]

    /// Runs `context` through every middleware in order.
    func process(_ context: ActionContext) {
        run(index: 0, context: context)
    }

    private func run(index: Int, context: ActionContext) {
        guard index < middlewares.count else { return }
        middlewares[index].process(context) { nextContext in
            run(index: index + 1, context: nextContext)
        }
    }
}
