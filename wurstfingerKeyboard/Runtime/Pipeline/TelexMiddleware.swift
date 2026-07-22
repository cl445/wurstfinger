//
//  TelexMiddleware.swift
//  Wurstfinger
//
//  Rewrites single-character `.commitText` actions according to the
//  Vietnamese Telex input method when Telex is active.
//

import Foundation

/// Applies Vietnamese Telex composition to single-character text commits.
///
/// Telex is a stateful input method: the meaning of a key depends on the
/// previous 1–2 characters in the document. This middleware reads those
/// characters via `documentContextBefore`, asks the injected compose closures
/// (which point at `ComposeEngine.composeTelexDigraph` / `composeTelex`) for
/// a replacement, and rewrites the action to the composed result — deleting
/// the consumed characters via `deleteBackward` before forwarding.
///
/// The middleware is inert when `isActive` returns `false`, so non-Vietnamese
/// layouts pay no runtime cost beyond a single closure call.
///
/// Injected closures keep this file independent of `ComposeEngine` (which is
/// excluded from the `WurstfingerApp` target), mirroring the pattern used by
/// `ComposeMiddleware`.
struct TelexMiddleware: ActionMiddleware {
    /// Whether Telex composition should be applied. Typically bound to the
    /// currently selected keyboard language.
    let isActive: () -> Bool

    /// Returns the document context immediately before the cursor. The
    /// middleware only inspects the last two characters.
    let documentContextBefore: () -> String?

    /// Deletes one character from the document. Called 1–2 times when a
    /// composition consumes preceding characters.
    let deleteBackward: () -> Void

    /// Returns the currently selected text, or nil/empty when there is no
    /// selection. When a selection is active the trigger must replace the
    /// selection verbatim, so Telex composition (which deletes lookback
    /// characters) is skipped entirely. Defaults to "no selection" so existing
    /// call sites need not thread it through.
    var selectedText: () -> String? = { nil }

    /// Two-char lookback composition. Returns `(replacement, charsToDelete)`
    /// or `nil`. Bound to `ComposeEngine.composeTelexDigraph`.
    let composeDigraph: (_ prev2: String, _ prev1: String, _ trigger: String) -> (String, Int)?

    /// Single-char composition. Returns the composed replacement or `nil`.
    /// Bound to `ComposeEngine.composeTelex`.
    let composeSingle: (_ previous: String, _ trigger: String) -> String?

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        guard isActive(),
              case let .commitText(text) = context.action,
              text.count == 1,
              selectedText()?.isEmpty ?? true,
              let documentContext = documentContextBefore(),
              !documentContext.isEmpty
        else {
            next(context)
            return
        }

        let chars = Array(documentContext.suffix(2))
        var transformed = context

        // Try two-char digraph lookback first (e.g. "uo" + "w" → "ươ").
        if chars.count >= 2,
           let (replacement, deleteCount) = composeDigraph(
               String(chars[chars.count - 2]),
               String(chars[chars.count - 1]),
               text
           ) {
            // Defensive guard: `deleteCount` comes from an injected closure.
            // Reject out-of-range values (including negatives and values
            // larger than the visible lookback) so a buggy rule table cannot
            // delete unrelated text before the forwarded commit.
            guard (1 ... chars.count).contains(deleteCount) else {
                assertionFailure("Telex digraph returned invalid deleteCount=\(deleteCount) for lookback size \(chars.count)")
                next(context)
                return
            }
            for _ in 0 ..< deleteCount {
                deleteBackward()
            }
            transformed.action = .commitText(replacement)
            next(transformed)
            return
        }

        // Fall back to single-char composition (e.g. "a" + "s" → "á").
        if let last = chars.last,
           let composed = composeSingle(String(last), text) {
            deleteBackward()
            transformed.action = .commitText(composed)
            next(transformed)
            return
        }

        next(context)
    }
}
