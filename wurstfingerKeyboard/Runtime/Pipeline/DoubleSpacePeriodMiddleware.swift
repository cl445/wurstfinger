//
//  DoubleSpacePeriodMiddleware.swift
//  Wurstfinger
//
//  Rewrites a second consecutive space into the script's sentence terminator,
//  matching the iOS system keyboard's "." Shortcut.
//

import Foundation

/// Turns two consecutive spaces into a sentence terminator when the character
/// before the pending space is a letter or digit, matching the iOS system
/// keyboard's "." Shortcut and MessagEase's Auto Period-Space.
///
/// Both halves of "double space" are enforced:
/// - *double*: the pending space must have been typed on this keyboard less
///   than `KeyboardConstants.TextInput.doubleSpacePeriodWindow` ago, with no
///   other action in between. Without that window a lone space behind an
///   existing "word + space" is rewritten no matter how much later, and a
///   deliberate double space cannot be typed at all while the setting is on.
/// - *space*: the document context must end in a letter or digit followed by a
///   single space (see `shouldSubstitute`).
///
/// What gets committed comes from the definition's locale via
/// `AutoCapitalization.sentenceTerminator(for:)`, so Hindi gets a danda and
/// Japanese the full-width stop instead of a Western period.
///
/// Rewriting to `.commitText` keeps auto-capitalization working for free:
/// `AutoCapitalizationMiddleware.affectsCapitalization` already covers
/// `.commitText`, and every terminator's mark is a member of
/// `AutoCapitalization.sentenceEnders`, so the letter after it is capitalized
/// when auto-capitalization is enabled.
///
/// Inert unless `isEnabled` returns `true` (off by default, like
/// auto-capitalization), so existing users' typing does not change until they
/// opt in.
///
/// A reference type, unlike its sibling middlewares: the timestamp of the
/// pending space is state, and the pipeline holds its middlewares as an array
/// of existentials it cannot mutate in place.
final class DoubleSpacePeriodMiddleware: ActionMiddleware {
    /// Whether the double-space substitution is enabled.
    private let isEnabled: () -> Bool

    /// Returns the document context immediately before the cursor. Only the
    /// last two characters are inspected.
    private let documentContextBefore: () -> String?

    /// Returns the currently selected text, if any. With an active selection
    /// the substitution must not fire: `deleteBackward` would delete the
    /// selection instead of the pending space, so a space press has to keep
    /// its plain replace-selection-with-space semantics.
    private let selectedText: () -> String?

    /// Deletes the pending trailing space before the rewritten commit.
    private let deleteBackward: () -> Void

    /// What the double space is replaced with: the script's sentence-ending
    /// mark plus the trailing space it is written with.
    private let sentenceTerminator: String

    /// Clock for the double-space window, injected so tests can drive it.
    private let now: () -> TimeInterval

    /// When the pending space was pressed, or nil when the previous action was
    /// not a space.
    private var lastSpace: TimeInterval?

    init(
        isEnabled: @escaping () -> Bool,
        documentContextBefore: @escaping () -> String?,
        selectedText: @escaping () -> String?,
        deleteBackward: @escaping () -> Void,
        sentenceTerminator: String = AutoCapitalization.defaultSentenceTerminator,
        now: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }
    ) {
        self.isEnabled = isEnabled
        self.documentContextBefore = documentContextBefore
        self.selectedText = selectedText
        self.deleteBackward = deleteBackward
        self.sentenceTerminator = sentenceTerminator
        self.now = now
    }

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        guard isEnabled() else {
            next(context)
            return
        }
        guard case .space = context.action else {
            // Only two *consecutive* space presses substitute: a letter, a
            // delete or a cursor move in between disarms the window.
            lastSpace = nil
            next(context)
            return
        }

        let pressed = now()
        let window = KeyboardConstants.TextInput.doubleSpacePeriodWindow
        // A range check rather than a plain difference: a clock stepped
        // backwards by the system must not read as an instant second press.
        let isSecondPress = lastSpace.map { (0 ... window).contains(pressed - $0) } ?? false
        lastSpace = pressed

        guard isSecondPress,
              selectedText()?.isEmpty != false,
              let text = documentContextBefore(),
              Self.shouldSubstitute(before: text)
        else {
            next(context)
            return
        }
        // The pair is consumed; a following space starts a new one.
        lastSpace = nil
        deleteBackward()
        var rewritten = context
        rewritten.action = .commitText(sentenceTerminator)
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
