//
//  AutoCapitalizationMiddleware.swift
//  Wurstfinger
//
//  Re-evaluates auto-capitalization after text-input actions.
//

import Foundation

/// Runs after the text-mutating middlewares and asks the host whether the
/// next character should be capitalized.
///
/// The actual capitalization decision is delegated to an injected closure
/// so this file stays independent of the `AutoCapitalization` type (which
/// is excluded from the `WurstfingerApp` target).
struct AutoCapitalizationMiddleware: ActionMiddleware {
    /// Returns `true` when auto-capitalization should engage for the next
    /// key, `false` when it should disengage, `nil` when no change should
    /// be made (e.g. auto-capitalization is disabled in settings).
    let evaluate: () -> Bool?

    /// Invoked when auto-capitalization should engage for the next key.
    let onCapitalize: () -> Void

    /// Invoked when auto-capitalization should disengage.
    let onReleaseCapitalize: () -> Void

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        next(context)
        guard Self.affectsCapitalization(context.action) else { return }
        switch evaluate() {
        case .some(true): onCapitalize()
        case .some(false): onReleaseCapitalize()
        case .none: break
        }
    }

    /// Actions whose result may change whether the next key should be
    /// auto-capitalized. Kept static so tests can verify the policy
    /// without constructing a middleware instance.
    static func affectsCapitalization(_ action: KeyAction) -> Bool {
        switch action {
        case .commitText, .space, .newline, .deleteBackward, .deleteForward,
             .compose, .cycleAccents, .paste, .cut:
            true
        case .moveCursor, .switchMode, .capitalizeWord, .advanceToNextInputMode,
             .dismissKeyboard, .copy, .none:
            false
        }
    }
}
