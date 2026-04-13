//
//  ComposeMiddleware.swift
//  Wurstfinger
//
//  Resolves .compose actions into concrete .commitText actions.
//

import Foundation

/// Transforms `.compose(trigger)` into `.commitText(result)` when the
/// previous character combined with `trigger` has a compose rule.
///
/// If no rule matches, the action is transformed to `.commitText(trigger)`
/// so the user still gets the literal character. Non-compose actions are
/// passed through untouched.
///
/// The compose lookup and document access are injected as closures so this
/// file does not depend on `ComposeEngine` or `UITextDocumentProxy` —
/// `ComposeEngine` is excluded from the `WurstfingerApp` target, and
/// avoiding `UITextDocumentProxy` keeps the middleware unit-testable.
struct ComposeMiddleware: ActionMiddleware {
    /// Looks up `(previous, trigger) → replacement`. Returns nil when no
    /// rule applies.
    let compose: (_ previous: String, _ trigger: String) -> String?

    /// Reads the last character before the cursor. Empty string when
    /// there is no preceding character.
    let previousCharacter: () -> String

    /// Deletes the previous character from the document. Invoked when a
    /// compose rule matches and consumes the preceding letter.
    let deletePreviousCharacter: () -> Void

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        guard case let .compose(trigger) = context.action else {
            next(context)
            return
        }

        var transformed = context
        let previous = previousCharacter()
        if !previous.isEmpty, let replacement = compose(previous, trigger) {
            deletePreviousCharacter()
            transformed.action = .commitText(replacement)
        } else {
            // No rule — insert the trigger as plain text.
            transformed.action = .commitText(trigger)
        }
        next(transformed)
    }
}
