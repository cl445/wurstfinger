//
//  SequentialCompositionMiddleware.swift
//  Wurstfinger
//

import Foundation

/// Rewrites one committed key using text immediately before the cursor.
/// Telex can replace a syllable suffix; table-based combiners and Hangul
/// only replace the last character. Both must leave active selections alone.
struct SequentialCompositionMiddleware: ActionMiddleware {
    let isActive: () -> Bool
    let documentContextBefore: () -> String?
    let deleteBackward: () -> Void
    var selectedText: () -> String? = { nil }

    /// Optional longer lookback, returning (replacement, graphemes to delete).
    var composeSuffix: ((_ context: String, _ trigger: String) -> (String, Int)?)?
    let composeSingle: (_ previous: String, _ trigger: String) -> String?

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        guard isActive(),
              case let .commitText(text) = context.action,
              text.count == 1,
              selectedText()?.isEmpty ?? true,
              let document = documentContextBefore(), let last = document.last
        else {
            next(context)
            return
        }

        let edit = composeSuffix?(document, text) ?? composeSingle(String(last), text).map { ($0, 1) }
        guard let (replacement, count) = edit else {
            next(context)
            return
        }
        guard count > 0, document.suffix(count).count == count else {
            assertionFailure("Composition tried to delete outside the visible context")
            next(context)
            return
        }
        for _ in 0 ..< count {
            deleteBackward()
        }
        var transformed = context
        transformed.action = .commitText(replacement)
        next(transformed)
    }
}
