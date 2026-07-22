//
//  CombineMiddleware.swift
//  Wurstfinger
//
//  Rewrites a single-character `.commitText` action into a combined character
//  when it follows a matching preceding character (sequential A+B→C combine).
//

import Foundation

/// Applies sequential character composition: when the just-typed character
/// (the trigger) follows a matching preceding character in the document, both
/// are replaced by a single combined character.
///
/// This is the "type base, then modifier" pattern used by scripts that build
/// characters from a base plus a following mark — e.g. Devanagari vowel
/// lengthening (इ + इ → ई) or Japanese kana voicing (か + ゛ → が). It differs
/// from `ComposeMiddleware`, which reacts to an explicit `.compose` dead-key
/// action; here both characters are ordinary committed letters.
///
/// The lookup uses the same `trigger → base → result` shape as
/// `ComposeRuleSet`, with the trigger being the *second* character typed and
/// the base the character already in the document. The middleware is inert
/// when `isActive` returns `false`, so non-combine layouts pay no runtime cost
/// beyond a single closure call.
///
/// Injected closures keep this file independent of the definition/data layer,
/// mirroring `TelexMiddleware` and `ComposeMiddleware`.
struct CombineMiddleware: ActionMiddleware {
    /// Whether combine composition should be applied. Typically bound to
    /// whether the active definition carries a combine rule set.
    let isActive: () -> Bool

    /// Returns the document context immediately before the cursor. Only the
    /// last character is inspected.
    let documentContextBefore: () -> String?

    /// Deletes one character from the document (the consumed base character).
    let deleteBackward: () -> Void

    /// Returns the currently selected text, or nil/empty when there is no
    /// selection. When a selection is active the lookback base character is
    /// not the character the combine should consume, so combining is skipped
    /// and the raw trigger is forwarded to replace the selection instead.
    /// Defaults to "no selection" so call sites that never surface a selection
    /// (and the existing unit tests) need not thread it through.
    var selectedText: () -> String? = { nil }

    /// Lookup: `(previous, trigger) -> result?`. Bound to a plain dictionary
    /// lookup over the definition's combine rule set.
    let combine: (_ previous: String, _ trigger: String) -> String?

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        guard isActive(),
              case let .commitText(text) = context.action,
              text.count == 1,
              selectedText()?.isEmpty ?? true,
              let documentContext = documentContextBefore(),
              let previous = documentContext.last
        else {
            next(context)
            return
        }

        guard let combined = combine(String(previous), text) else {
            next(context)
            return
        }

        // Replace the consumed base character, then forward the combined result.
        deleteBackward()
        var transformed = context
        transformed.action = .commitText(combined)
        next(transformed)
    }
}
