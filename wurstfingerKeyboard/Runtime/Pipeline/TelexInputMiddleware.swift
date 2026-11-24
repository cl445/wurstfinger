//
//  TelexInputMiddleware.swift
//  Wurstfinger
//

import Foundation

/// `w` and `uw` both display `ư`, but repeating the key must restore `w`
/// and `uw` respectively. Only the standalone shortcut needs keystroke state.
final class TelexInputMiddleware: ActionMiddleware {
    private let target: () -> TextInputTarget?
    private let composition: SequentialCompositionMiddleware
    private var pending: (key: String, cursor: Cursor)?

    /// Check that the next press still follows our insertion, not an unrelated
    /// `ư` after a field switch or caret move. Keep only a small cursor window.
    private struct Cursor: Equatable {
        let document: UUID?
        let before: String
        let after: String

        init(_ target: TextInputTarget, inserting text: String = "") {
            document = target.documentIdentifier
            let window = 8
            let prefix = target.documentContextBeforeInput?.suffix(window) ?? ""
            before = String((prefix + text).suffix(window))
            after = String(target.documentContextAfterInput?.prefix(window) ?? "")
        }
    }

    init(target: @escaping () -> TextInputTarget?) {
        self.target = target
        composition = SequentialCompositionMiddleware(
            isActive: { true },
            documentContextBefore: { target()?.documentContextBeforeInput },
            deleteBackward: { target()?.deleteBackward() },
            selectedText: { target()?.selectedText },
            composeSuffix: ComposeEngine.composeTelexSyllable,
            composeSingle: ComposeEngine.composeTelex
        )
    }

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        let previous = pending
        pending = nil
        guard case let .commitText(key) = context.action, key == "w" || key == "W",
              let target = target(), target.selectedText?.isEmpty != false
        else {
            composition.process(context, next: next)
            return
        }

        var rewritten = context
        if let previous, previous.cursor == Cursor(target) {
            target.deleteBackward()
            rewritten.action = .commitText(previous.key)
            next(rewritten)
            return
        }

        // Shape (or undo) the preceding vowel first: aw, ow, uw and uow.
        // Only an unconsumed w starts a shortcut, including at an empty caret.
        composition.process(context) { resolved in
            guard resolved.action == context.action else {
                next(resolved)
                return
            }
            let vowel = key == "w" ? "ư" : "Ư"
            pending = (key, Cursor(target, inserting: vowel))
            rewritten.action = .commitText(vowel)
            next(rewritten)
        }
    }
}
