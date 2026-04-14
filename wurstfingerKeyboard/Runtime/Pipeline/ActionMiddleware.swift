//
//  ActionMiddleware.swift
//  Wurstfinger
//
//  Protocol and context type for the action-processing pipeline.
//

import Foundation

/// Context that flows through the `ActionPipeline`.
///
/// Middlewares may mutate the action they forward (e.g. `ComposeMiddleware`
/// replaces `.compose` with `.commitText`), and subsequent middlewares see
/// the mutated context. The context intentionally does **not** carry a
/// `UITextDocumentProxy` reference — middlewares inject whatever host
/// dependencies they need via their initializer so every middleware can be
/// unit-tested without a view controller.
struct ActionContext {
    /// The action currently being processed. Middlewares may transform it
    /// before calling `next`.
    var action: KeyAction

    /// The binding that produced the action, if any. Used for category-based
    /// decisions (e.g. auto-shift after a `.letter`).
    let binding: KeyBinding?

    /// Name of the currently active keyboard mode. Middlewares may read it
    /// for mode-aware decisions; mode transitions themselves are triggered
    /// via callbacks (see `ModeTransitionMiddleware`).
    var mode: String
}

/// A single step in the action-processing pipeline.
///
/// A middleware receives the `ActionContext` and must call `next(_:)` zero
/// or one time to forward a (possibly transformed) context to the next step.
/// Not calling `next` short-circuits the pipeline.
protocol ActionMiddleware {
    func process(_ context: ActionContext, next: (ActionContext) -> Void)
}
