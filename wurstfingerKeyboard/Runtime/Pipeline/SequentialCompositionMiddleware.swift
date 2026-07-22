//
//  SequentialCompositionMiddleware.swift
//  Wurstfinger
//
//  Shared "type base, then following character" composition middleware.
//  Rewrites a single-character `.commitText` action into a composed result
//  when it follows a matching preceding character (sequential A+B→C).
//

import Foundation

/// Applies sequential character composition: when the just-typed character
/// (the trigger) follows matching preceding character(s) in the document, the
/// consumed characters are deleted and replaced by a single composed result.
///
/// This is the "type base, then modifier/following character" pattern shared by
/// two input styles that differ only in how much lookback they inspect:
///
/// - **Sequential combine** (`combineRuleSet` / Korean Hangul): one lookback
///   character. Devanagari vowel lengthening (इ + इ → ई), Japanese kana voicing
///   (か + ゛ → が), Hangul jamo → syllable (한 + ㅏ → 하나).
/// - **Vietnamese Telex**: an optional two-character digraph lookback first
///   (uo + w → ươ), falling back to the single-character lookback (a + s → á).
///
/// Both share the same skeleton — `isActive` guard, selection skip, single-char
/// `.commitText` check, `documentContextBefore` lookback, delete-then-rewrite —
/// so they are configured as one type parameterized by the two lookup closures.
/// It differs from `ComposeMiddleware`, which reacts to an explicit `.compose`
/// dead-key action; here both characters are ordinary committed letters.
///
/// The middleware is inert when `isActive` returns `false`, so non-composing
/// layouts pay no runtime cost beyond a single closure call. Injected closures
/// keep this file independent of the definition/data layer and `ComposeEngine`.
struct SequentialCompositionMiddleware: ActionMiddleware {
    /// Whether composition should be applied. Bound either to the active input
    /// method (Telex) or to a constant when the middleware is only appended for
    /// definitions that opt into a combiner.
    let isActive: () -> Bool

    /// Returns the document context immediately before the cursor. Only the
    /// last one or two characters are inspected.
    let documentContextBefore: () -> String?

    /// Deletes one character from the document. Called 1–2 times when a
    /// composition consumes preceding characters.
    let deleteBackward: () -> Void

    /// Returns the currently selected text, or nil/empty when there is no
    /// selection. When a selection is active the trigger must replace the
    /// selection verbatim, so composition (which deletes lookback characters)
    /// is skipped entirely. Defaults to "no selection" so call sites that never
    /// surface a selection (and the existing unit tests) need not thread it
    /// through.
    var selectedText: () -> String? = { nil }

    /// Optional two-char digraph lookback (Telex). Returns
    /// `(replacement, charsToDelete)` or `nil`. `nil` for single-lookback
    /// combine configurations, which skip the digraph branch entirely.
    var composeDigraph: ((_ prev2: String, _ prev1: String, _ trigger: String) -> (String, Int)?)?

    /// Single-char lookback: `(previous, trigger) -> result?`. For combine this
    /// is a rule-table lookup or the Hangul automaton; for Telex it is the
    /// single-character tone/vowel composition.
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

        // Try the two-char digraph lookback first (e.g. "uo" + "w" → "ươ")
        // when the configuration supplies one.
        if let composeDigraph, chars.count >= 2,
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
                assertionFailure("Digraph returned invalid deleteCount=\(deleteCount) for lookback size \(chars.count)")
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

        // Fall back to single-char composition (e.g. "a" + "s" → "á",
        // か + ゛ → が, 한 + ㅏ → 하나).
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
