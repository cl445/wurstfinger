//
//  DoubleSpacePeriodMiddleware.swift
//  Wurstfinger
//
//  Rewrites a second consecutive space into a period + space,
//  matching the iOS system keyboard's "." Shortcut.
//

import Foundation

/// Turns a double space into `". "` when the character before the pending
/// space is a letter or digit, matching the iOS system keyboard's "." Shortcut
/// and MessagEase's Auto Period-Space.
///
/// The middleware is stateless: on a `.space` action it inspects the document
/// context immediately before the cursor and, when the text already ends in a
/// letter or digit followed by a single space, deletes that pending space and
/// rewrites the action to `.commitText(". ")`. Everything else passes through
/// untouched, so keys other than the space bar are unaffected and the feature
/// costs a single settings read plus a two-character lookback per space press.
///
/// Rewriting to `.commitText` keeps auto-capitalization working for free:
/// `AutoCapitalizationMiddleware.affectsCapitalization` already covers
/// `.commitText`, so the letter after the inserted period is capitalized when
/// auto-capitalization is enabled.
///
/// Inert unless `isEnabled` returns `true` (off by default, like
/// auto-capitalization), so existing users' typing does not change until they
/// opt in.
struct DoubleSpacePeriodMiddleware: ActionMiddleware {
    /// Whether the double-space-to-period substitution is enabled.
    let isEnabled: () -> Bool

    /// Returns the document context immediately before the cursor. Only the
    /// last two characters are inspected.
    let documentContextBefore: () -> String?

    /// Returns the currently selected text, if any. With an active selection
    /// the substitution must not fire: `deleteBackward` would delete the
    /// selection instead of the pending space, so a space press has to keep
    /// its plain replace-selection-with-space semantics.
    let selectedText: () -> String?

    /// Deletes the pending trailing space before the rewritten commit.
    let deleteBackward: () -> Void

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        guard isEnabled(),
              case .space = context.action,
              selectedText()?.isEmpty != false,
              let text = documentContextBefore(),
              Self.shouldSubstitute(before: text)
        else {
            next(context)
            return
        }
        deleteBackward()
        var rewritten = context
        rewritten.action = .commitText(". ")
        next(rewritten)
    }

    /// The substitution rule: the context must end with a single space whose
    /// preceding character is a letter or digit.
    ///
    /// This deliberately excludes:
    /// - an empty field or a leading space (no preceding character),
    /// - a space after punctuation such as `"hello. "` (the preceding
    ///   character is not a letter or digit),
    /// - runs of two or more spaces (the character before the pending space is
    ///   then itself a space), which also keeps a triple space from collapsing.
    static func shouldSubstitute(before context: String) -> Bool {
        let lastTwo = Array(context.suffix(2))
        guard lastTwo.count == 2, lastTwo[1] == " " else { return false }
        let preceding = lastTwo[0]
        return preceding.isLetter || preceding.isNumber
    }
}
