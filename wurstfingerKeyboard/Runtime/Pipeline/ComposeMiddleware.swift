//
//  ComposeMiddleware.swift
//  Wurstfinger
//
//  Resolves .compose and .cycleAccents actions.
//

import Foundation

/// Handles compose-related actions:
///
/// - `.compose(trigger)`: checks `ComposeEngine` for a rule combining the
///   previous character with the trigger. Inserts the trigger as plain text
///   when no rule matches.
/// - `.cycleAccents`: cycles through accent variants of the previous character.
///
/// All other actions pass through untouched.
///
/// The compose lookup and document access are injected as closures so this
/// file does not depend on `ComposeEngine` or `UITextDocumentProxy`.
struct ComposeMiddleware: ActionMiddleware {
    /// Looks up `(previous, trigger) → replacement`. Returns nil when no
    /// rule applies.
    let compose: (_ previous: String, _ trigger: String) -> String?

    /// Cycles through accent variants for a character (ä → â → à → …).
    /// Returns nil when no cycle exists.
    let cycleAccent: (_ character: String) -> String?

    /// Reads the last character before the cursor. Empty string when
    /// there is no preceding character.
    let previousCharacter: () -> String

    /// Deletes the previous character from the document. Invoked when a
    /// compose rule matches and consumes the preceding letter.
    let deletePreviousCharacter: () -> Void

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        switch context.action {
        case let .compose(trigger):
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

        case .cycleAccents:
            let previous = previousCharacter()
            guard !previous.isEmpty, let replacement = cycleAccent(previous) else {
                next(context)
                return
            }
            var transformed = context
            deletePreviousCharacter()
            transformed.action = .commitText(replacement)
            next(transformed)

        default:
            next(context)
        }
    }
}
