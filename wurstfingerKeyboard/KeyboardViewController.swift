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

    /// Reports the active keyboard language to iOS (shown in Settings > Keyboards).
    /// Reads directly from SharedDefaults to pick up language changes made in the host app,
    /// since the LanguageSettings singleton may hold a stale value from its init.
    override var primaryLanguage: String? {
        get {
            let languageId = SharedDefaults.store.string(forKey: SettingsKey.selectedLanguageId.rawValue)
            let config = languageId.flatMap { LanguageConfig.language(withId: $0) } ?? .english
            return config.locale.identifier
        }
        set {
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
            constraint.priority = .defaultHigh
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
        case let .insert(text):
            insertText(text)
        case .deleteBackward:
            textDocumentProxy.deleteBackward()
            updateAutoCapitalization()
        case .deleteForward:
            if deleteForward() {
                updateAutoCapitalization()
            }
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
        case let .capitalizeWord(style):
            capitalizeCurrentWord(style: style)
        case let .moveCursor(offset):
            textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        case let .compose(trigger):
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

    private func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
        // Spanish sentence-opening punctuation triggers immediate capitalization
        if AutoCapitalization.shouldCapitalizeImmediately(after: text),
           SharedDefaults.store.bool(forKey: SettingsKey.autoCapitalizeEnabled.rawValue) {
            viewModel.setLayer(.upper)
        }
    }

    /// Delete one character after cursor. Returns `true` if a character was deleted.
    @discardableResult
    private func deleteForward() -> Bool {
        guard let after = textDocumentProxy.documentContextAfterInput, !after.isEmpty else {
            return false
        }
        textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
        textDocumentProxy.deleteBackward()
        return true
    }

    /// Copy selected text to clipboard (requires Full Access)
    private func handleCopy() {
        guard hasFullAccess else { return }
        if let selectedText = textDocumentProxy.selectedText, !selectedText.isEmpty {
            UIPasteboard.general.string = selectedText
        }
    }

    /// Paste text from clipboard (requires Full Access)
    private func handlePaste() {
        guard hasFullAccess else { return }
        if let text = UIPasteboard.general.string, !text.isEmpty {
            textDocumentProxy.insertText(text)
            updateAutoCapitalization()
        }
    }

    /// Cut selected text (copy + delete, requires Full Access)
    private func handleCut() {
        guard hasFullAccess else { return }
        if let selectedText = textDocumentProxy.selectedText, !selectedText.isEmpty {
            UIPasteboard.general.string = selectedText
            textDocumentProxy.deleteBackward()
            updateAutoCapitalization()
        }
    }

    private func checkAutoCapitalization() {
        // Check if auto-capitalize is enabled
        guard SharedDefaults.store.bool(forKey: SettingsKey.autoCapitalizeEnabled.rawValue) else { return }

        if AutoCapitalization.shouldCapitalize(context: textDocumentProxy.documentContextBeforeInput) {
            viewModel.setLayer(.upper)
        }
    }

    /// Re-evaluates auto-capitalization after text changes (e.g. delete).
    /// Enables uppercase if at sentence start, disables it if no longer at sentence start.
    private func updateAutoCapitalization() {
        guard SharedDefaults.store.bool(forKey: SettingsKey.autoCapitalizeEnabled.rawValue) else { return }

        let shouldCapitalize = AutoCapitalization.shouldCapitalize(context: textDocumentProxy.documentContextBeforeInput)
        if shouldCapitalize {
            viewModel.setLayer(.upper)
        } else if viewModel.activeLayer == .upper && !viewModel.isCapsLockActive {
            viewModel.setLayer(.lower)
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
        let transformed: String = switch style {
        case .uppercased:
            word.uppercased(with: locale)
        case .lowercased:
            word.lowercased(with: locale)
        }

        for _ in 0 ..< word.count {
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
