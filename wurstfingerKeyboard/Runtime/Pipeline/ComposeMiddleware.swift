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
///   when no rule matches or when the previous character is a space (the
///   space is never consumed).
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

    /// Returns the currently selected text, or nil/empty when there is no
    /// selection. When a selection is active the trigger must replace the
    /// selection verbatim, so the compose lookup (which deletes the previous
    /// character) is skipped and the raw trigger is committed instead.
    /// Defaults to "no selection" so existing call sites need not thread it
    /// through.
    var selectedText: () -> String? = { nil }

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        switch context.action {
        case let .compose(trigger):
            var transformed = context
            let previous = previousCharacter()
            // This middleware is a pure executor of the compose rule table:
            // space handling lives entirely in the rule data (e.g. the
            // " " + ´ → ' and " " + ˋ → ` normalizations), so no special
            // space branch is needed here. A rule match deletes the matched
            // previous character and commits its replacement; otherwise the
            // trigger is inserted as plain text.
            //
            // An active selection is the one exception: deleting the previous
            // character would corrupt the selection replacement, so when text
            // is selected the raw trigger is committed to replace it.
            if !previous.isEmpty, selectedText()?.isEmpty ?? true,
               let replacement = compose(previous, trigger) {
                deletePreviousCharacter()
                transformed.action = .commitText(replacement)
            } else {
                // No rule (or an active selection) — insert the trigger as
                // plain text so it replaces any selection verbatim.
                transformed.action = .commitText(trigger)
            }
            next(transformed)

        case .cycleAccents:
            let previous = previousCharacter()
            guard !previous.isEmpty, selectedText()?.isEmpty ?? true,
                  let replacement = cycleAccent(previous)
            else {
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
