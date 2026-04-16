//
//  DocumentProxyTarget.swift
//  Wurstfinger
//
//  Thin wrapper conforming to TextInputTarget that delegates to a
//  UITextDocumentProxy. Bridges UIKit's document proxy into the
//  middleware pipeline's protocol-based abstraction.
//

import UIKit

/// Adapts a `UITextDocumentProxy` to the `TextInputTarget` protocol used
/// by the middleware pipeline.
///
/// Holds a weak reference to the owning `UIInputViewController` so it can
/// access `textDocumentProxy` (which may change between input fields) and
/// `hasFullAccess` without extending the controller's lifetime.
final class DocumentProxyTarget: TextInputTarget {
    private weak var controller: UIInputViewController?

    init(controller: UIInputViewController) {
        self.controller = controller
    }

    private var proxy: UITextDocumentProxy? {
        controller?.textDocumentProxy
    }

    func insertText(_ text: String) {
        proxy?.insertText(text)
    }

    func deleteBackward() {
        proxy?.deleteBackward()
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        proxy?.adjustTextPosition(byCharacterOffset: offset)
    }

    var documentContextBeforeInput: String? {
        proxy?.documentContextBeforeInput
    }

    var documentContextAfterInput: String? {
        proxy?.documentContextAfterInput
    }

    var selectedText: String? {
        proxy?.selectedText
    }

    var hasFullAccess: Bool {
        controller?.hasFullAccess ?? false
    }
}
