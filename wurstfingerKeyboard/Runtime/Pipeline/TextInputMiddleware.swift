//
//  TextInputMiddleware.swift
//  Wurstfinger
//
//  Executes text-input actions against an injected TextInputTarget.
//

import Foundation

/// Applies text-mutating actions (`.commitText`, `.deleteBackward`,
/// `.space`, `.newline`, `.moveCursor`) to the injected target.
///
/// Non-text actions (mode switches, haptics, capitalization) pass through
/// unchanged so later middlewares can react to them.
///
/// Advanced actions (delete-forward, word-cursor movement, copy/paste,
/// capitalize-word) are handled by `AdvancedTextMiddleware`.
struct TextInputMiddleware: ActionMiddleware {
    /// Host-provided text input target resolver.
    ///
    /// The closure itself is strongly retained by the middleware, so *callers*
    /// are responsible for capturing the owning object (typically the keyboard
    /// view controller) weakly when constructing it. The standard pattern is
    /// `{ [weak controller] in controller?.textInputTarget }`, which keeps the
    /// middleware from extending the controller's lifetime.
    private let targetProvider: () -> TextInputTarget?

    init(target: @escaping () -> TextInputTarget?) {
        targetProvider = target
    }

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        if let target = targetProvider() {
            apply(action: context.action, to: target)
        }
        next(context)
    }

    private func apply(action: KeyAction, to target: TextInputTarget) {
        switch action {
        case let .commitText(text):
            target.insertText(text)
        case .deleteBackward:
            target.deleteBackward()
        case .space:
            target.insertText(" ")
        case .newline:
            target.insertText("\n")
        case let .moveCursor(offset):
            target.adjustTextPosition(byCharacterOffset: offset)
        case .compose, .cycleAccents, .switchMode, .capitalizeWord,
             .advanceToNextInputMode, .dismissKeyboard, .deleteForward,
             .copy, .paste, .cut, .cutAll, .none, .switchToNextLanguage:
            break
        }
    }
}
