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

        // Configure hosting synchronously so the SwiftUI view exists
        // before viewWillAppear sets the height constraint. Deferring via
        // DispatchQueue.main.async caused a race in WebView-based apps where
        // viewWillAppear ran before configureHosting, leaving the extension
        // with a height constraint but no content.
        configureHosting()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Persist Full Access status so the host app can show/hide haptic settings
        SharedDefaults.store.set(hasFullAccess, forKey: SettingsKey.keyboardFullAccess.rawValue)
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
        // Update viewModel with current width so SwiftUI re-renders after
        // orientation changes that happen while the keyboard is backgrounded (Bug #92).
        viewModel.updateViewWidth(view.bounds.width)
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
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
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
        case .moveCursor, .moveCursorByWord:
            performCursorAction(action)
        case let .compose(trigger):
            handleCompose(trigger: trigger)
        case .cycleAccents:
            handleCycleAccents()
        case .copy, .paste, .cut:
            performClipboardAction(action)
        }
    }

    private func performCursorAction(_ action: KeyboardAction) {
        switch action {
        case let .moveCursor(offset):
            textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        case let .moveCursorByWord(forward):
            moveCursorByWord(forward: forward)
        default:
            break
        }
    }

    private func performClipboardAction(_ action: KeyboardAction) {
        switch action {
        case .copy:
            handleCopy()
        case .paste:
            handlePaste()
        case .cut:
            handleCut()
        default:
            break
        }
    }

    private func insertText(_ text: String) {
        if viewModel.isTelexActive, text.count == 1,
           let context = textDocumentProxy.documentContextBeforeInput, !context.isEmpty {
            let chars = Array(context.suffix(2))
            // Try digraph first: "uo" + "w" -> "ươ"
            if chars.count >= 2,
               let (replacement, deleteCount) = ComposeEngine.composeTelexDigraph(
                   prev2: String(chars[chars.count - 2]),
                   prev1: String(chars[chars.count - 1]),
                   trigger: text
               ) {
                for _ in 0 ..< deleteCount {
                    textDocumentProxy.deleteBackward()
                }
                textDocumentProxy.insertText(replacement)
                checkAutoCapitalizationAfterInsert(text)
                return
            }
            // Then single-char compose
            if let composed = ComposeEngine.composeTelex(
                previous: String(chars.last!), trigger: text
            ) {
                textDocumentProxy.deleteBackward()
                textDocumentProxy.insertText(composed)
                checkAutoCapitalizationAfterInsert(text)
                return
            }
        }
        textDocumentProxy.insertText(text)
        checkAutoCapitalizationAfterInsert(text)
    }

    private func checkAutoCapitalizationAfterInsert(_ text: String) {
        if AutoCapitalization.shouldCapitalizeImmediately(after: text),
           SharedDefaults.store.bool(forKey: SettingsKey.autoCapitalizeEnabled.rawValue) {
            viewModel.setLayer(.upper)
        }
    }

    /// Move cursor forward or backward by one word.
    private func moveCursorByWord(forward: Bool) {
        if forward {
            guard let after = textDocumentProxy.documentContextAfterInput, !after.isEmpty else { return }
            let offset = Self.nextWordBoundaryOffset(in: after)
            textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        } else {
            guard let before = textDocumentProxy.documentContextBeforeInput, !before.isEmpty else { return }
            let offset = Self.previousWordBoundaryOffset(in: before)
            textDocumentProxy.adjustTextPosition(byCharacterOffset: -offset)
        }
    }

    /// Returns the character offset to the next word boundary from the start of the string.
    static func nextWordBoundaryOffset(in text: String) -> Int {
        // Skip leading whitespace, then skip word characters
        var index = text.startIndex
        // Skip whitespace
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
        // Skip word characters (non-whitespace)
        while index < text.endIndex, !text[index].isWhitespace {
            index = text.index(after: index)
        }
        return text.distance(from: text.startIndex, to: index)
    }

    /// Returns the character offset from the end of the string to the previous word boundary.
    static func previousWordBoundaryOffset(in text: String) -> Int {
        var index = text.endIndex
        // Skip trailing whitespace
        while index > text.startIndex {
            let prev = text.index(before: index)
            guard text[prev].isWhitespace else { break }
            index = prev
        }
        // Skip word characters (non-whitespace)
        while index > text.startIndex {
            let prev = text.index(before: index)
            guard !text[prev].isWhitespace else { break }
            index = prev
        }
        return text.distance(from: index, to: text.endIndex)
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
        } else if viewModel.activeLayer == .upper && !viewModel.isCapsLockActive && !viewModel.isManualShift {
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
