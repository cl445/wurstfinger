//
//  TextInputMiddleware.swift
//  Wurstfinger
//
//  Executes text-input actions against an injected TextInputTarget.
//

import Foundation

/// Minimal protocol for the text-input operations `TextInputMiddleware`
/// performs. A thin wrapper around `UITextDocumentProxy` (declared in the
/// keyboard extension target where UIKit is available) conforms to this
/// protocol at pipeline construction time.
///
/// Using a dedicated protocol keeps the middleware testable without the
/// full `UITextDocumentProxy` contract (which has dozens of required
/// members from `UIKeyInput` and `UITextInputTraits`).
protocol TextInputTarget: AnyObject {
    func insertText(_ text: String)
    func deleteBackward()
    func adjustTextPosition(byCharacterOffset offset: Int)

    /// Text immediately before the cursor (up to the current paragraph start).
    /// Required for lookback-based composition (e.g. Vietnamese Telex digraphs).
    /// `nil` when no context is available yet.
    var documentContextBeforeInput: String? { get }

    /// Text immediately after the cursor (up to the current paragraph end).
    /// Required for delete-forward and word-boundary movement.
    var documentContextAfterInput: String? { get }

    /// Currently selected text, if any.
    var selectedText: String? { get }

    /// Whether Full Access (Open Access) is enabled for the keyboard.
    /// Clipboard operations require this.
    var hasFullAccess: Bool { get }
}

/// Applies text-mutating actions (`.commitText`, `.deleteBackward`,
/// `.space`, `.newline`, `.moveCursor`) to the injected target.
///
/// Non-text actions (mode switches, haptics, capitalization) pass through
/// unchanged so later middlewares can react to them.
///
/// Actions that require more than a direct target call (delete-forward,
/// word-cursor movement, copy/paste, capitalize-word) are intentionally
/// left to the view controller in PR 11 — they will migrate in PR 12 when
/// the pipeline is wired end-to-end.
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
             .copy, .paste, .cut, .none:
            break
        }
    }
}
