//
//  KeyboardViewController.swift
//  Wurstfinger
//
//  Created by Claas Flint on 24.10.25.
//

import Foundation
import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<KeyboardRootView>?
    private lazy var viewModel = KeyboardViewModel()
    private var heightConstraint: NSLayoutConstraint?

    /// Tells iOS which language this keyboard is typing in for spell-check and autocorrect
    override var primaryLanguage: String? {
        get {
            return LanguageSettings.shared.selectedLanguageId
        }
        set {
            // iOS may try to set this, but we ignore it and use our settings
            super.primaryLanguage = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set background immediately to avoid flash
        view.backgroundColor = .clear

        // Bind action handler first
        viewModel.bindActionHandler { [weak self] action in
            self?.perform(action: action)
        }

        // Configure UI on next run loop to allow faster initial display
        DispatchQueue.main.async { [weak self] in
            self?.configureHosting()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload settings every time keyboard appears
        viewModel.reloadSettings()
        updateKeyboardHeight()
        checkAutoCapitalization()
    }

    private func updateKeyboardHeight() {
        // Calculate keyboard height including both aspect ratio and scale
        let baseHeight = KeyboardConstants.Calculations.baseHeight(aspectRatio: viewModel.keyAspectRatio)
        // Apply scale to match the visual size from scaleEffect
        let finalHeight = baseHeight * viewModel.keyboardScale

        if let constraint = heightConstraint {
            constraint.constant = finalHeight
        } else {
            let constraint = view.heightAnchor.constraint(equalToConstant: finalHeight)
            constraint.priority = .required
            constraint.isActive = true
            heightConstraint = constraint
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        view.backgroundColor = .clear
    }

    override var needsInputModeSwitchKey: Bool {
        true
    }

    private func configureHosting() {
        let rootView = KeyboardRootView(viewModel: viewModel)
        let controller = UIHostingController(rootView: rootView)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear

        addChild(controller)
        view.addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        controller.didMove(toParent: self)
        hostingController = controller
    }

    private func perform(action: KeyboardAction) {
        switch action {
        case .insert(let text):
            textDocumentProxy.insertText(text)
            // Spanish sentence-opening punctuation triggers immediate capitalization
            if AutoCapitalization.shouldCapitalizeImmediately(after: text) &&
               SharedDefaults.store.bool(forKey: "autoCapitalizeEnabled") {
                viewModel.setLayer(.upper)
            }
        case .deleteBackward:
            textDocumentProxy.deleteBackward()
        case .deleteForward:
            deleteForward()
        case .advanceToNextInputMode:
            advanceToNextInputMode()
        case .space:
            textDocumentProxy.insertText(" ")
            checkAutoCapitalization()
        case .newline:
            textDocumentProxy.insertText("\n")
            checkAutoCapitalization()
        case .dismissKeyboard:
            dismissKeyboard()
        case .capitalizeWord(let style):
            capitalizeCurrentWord(style: style)
        case .moveCursor(let offset):
            textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        case .compose(let trigger):
            handleCompose(trigger: trigger)
        case .cycleAccents:
            handleCycleAccents()
        case .copy:
            handleCopy()
        case .paste:
            handlePaste()
        case .cut:
            handleCut()
        }
    }

    /// Delete one character after cursor
    private func deleteForward() {
        // Only delete if there's text after the cursor
        guard let after = textDocumentProxy.documentContextAfterInput, !after.isEmpty else {
            return
        }
        textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
        textDocumentProxy.deleteBackward()
    }

    /// Copy selected text to clipboard
    private func handleCopy() {
        if let selectedText = textDocumentProxy.selectedText, !selectedText.isEmpty {
            UIPasteboard.general.string = selectedText
        }
    }

    /// Paste text from clipboard
    private func handlePaste() {
        if let text = UIPasteboard.general.string, !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
    }

    /// Cut selected text (copy + delete)
    private func handleCut() {
        if let selectedText = textDocumentProxy.selectedText, !selectedText.isEmpty {
            UIPasteboard.general.string = selectedText
            for _ in selectedText {
                textDocumentProxy.deleteBackward()
            }
        }
    }

    private func checkAutoCapitalization() {
        // Check if auto-capitalize is enabled
        guard SharedDefaults.store.bool(forKey: "autoCapitalizeEnabled") else { return }

        if AutoCapitalization.shouldCapitalize(context: textDocumentProxy.documentContextBeforeInput) {
            viewModel.setLayer(.upper)
        }
    }

    private func capitalizeCurrentWord(style: CapitalizationStyle) {
        guard let context = textDocumentProxy.documentContextBeforeInput, !context.isEmpty else { return }

        var characters: [Character] = []
        for character in context.reversed() {
            if character.isLetter {
                characters.append(character)
            } else {
                break
            }
        }

        guard !characters.isEmpty else { return }

        let word = String(characters.reversed())
        let locale = viewModel.currentLocale()
        let transformed: String
        switch style {
        case .uppercased:
            transformed = word.uppercased(with: locale)
        case .lowercased:
            transformed = word.lowercased(with: locale)
        }

        for _ in 0..<word.count {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(transformed)
    }

    private func handleCompose(trigger: String) {
        guard let previous = textDocumentProxy.documentContextBeforeInput?.last else {
            textDocumentProxy.insertText(trigger)
            return
        }

        if let replacement = ComposeEngine.compose(previous: String(previous), trigger: trigger) {
            textDocumentProxy.deleteBackward()
            textDocumentProxy.insertText(replacement)
        } else {
            textDocumentProxy.insertText(trigger)
        }
    }

    private func handleCycleAccents() {
        guard let previous = textDocumentProxy.documentContextBeforeInput?.last else {
            return
        }

        if let replacement = ComposeEngine.cycleAccent(for: String(previous)) {
            textDocumentProxy.deleteBackward()
            textDocumentProxy.insertText(replacement)
        }
    }
}
