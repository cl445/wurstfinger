//
//  TextInputTarget.swift
//  Wurstfinger
//
//  Protocol abstracting text-input operations for the middleware pipeline.
//

import Foundation

/// Minimal protocol for the text-input operations the middleware pipeline
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

    /// Moves the cursor by `offset` **UTF-16 code units**, matching the
    /// observed behavior of `UITextDocumentProxy.adjustTextPosition` (despite
    /// its parameter name). Callers must convert grapheme-cluster counts to
    /// UTF-16 widths (`Character.utf16.count`) before calling.
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
