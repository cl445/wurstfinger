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
    private var selectionActive = false
    private var selectionOffset = 0
    private var heightConstraint: NSLayoutConstraint?

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
    }

    private func updateKeyboardHeight() {
        // Calculate keyboard height including both aspect ratio and scale
        let keyHeight = KeyboardConstants.KeyDimensions.height * (1.5 / viewModel.keyAspectRatio)
        let baseHeight = (keyHeight * 4) +
                         (KeyboardConstants.Layout.gridVerticalSpacing * 3) +
                         (KeyboardConstants.Layout.verticalPadding * 2)
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
        case .deleteBackward:
            textDocumentProxy.deleteBackward()
        case .advanceToNextInputMode:
            advanceToNextInputMode()
        case .space:
            textDocumentProxy.insertText(" ")
        case .newline:
            textDocumentProxy.insertText("\n")
        case .dismissKeyboard:
            dismissKeyboard()
        case .capitalizeWord(let style):
            capitalizeCurrentWord(style: style)
        case .moveCursor(let offset):
            textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        case .startSelection:
            beginSelection()
        case .updateSelection(let offset):
            updateSelection(by: offset)
        case .endSelection:
            endSelection()
        case .compose(let trigger):
            handleCompose(trigger: trigger)
        case .cycleAccents:
            handleCycleAccents()
        case .deleteWord:
            deleteWordBeforeCursor()
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
        let locale = Locale(identifier: "de_DE")
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

    private func beginSelection() {
        selectionActive = true
        selectionOffset = 0
        textDocumentProxy.unmarkText()
    }

    private func updateSelection(by delta: Int) {
        guard selectionActive, delta != 0 else { return }
        applySelection(targetOffset: selectionOffset + delta)
    }

    private func applySelection(targetOffset: Int) {
        guard selectionActive else { return }

        textDocumentProxy.unmarkText()

        selectionOffset = targetOffset

        if selectionOffset == 0 {
            return
        }

        if selectionOffset < 0 {
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            let available = before.count
            let requested = min(available, -selectionOffset)
            guard requested > 0 else {
                selectionOffset = 0
                return
            }
            let selectionText = String(before.suffix(requested))
            let actualCount = selectionText.count
            textDocumentProxy.adjustTextPosition(byCharacterOffset: -actualCount)
            textDocumentProxy.setMarkedText(selectionText, selectedRange: NSRange(location: actualCount, length: 0))
            selectionOffset = -actualCount
        } else {
            let after = textDocumentProxy.documentContextAfterInput ?? ""
            let available = after.count
            let requested = min(available, selectionOffset)
            guard requested > 0 else {
                selectionOffset = 0
                return
            }
            let selectionText = String(after.prefix(requested))
            let actualCount = selectionText.count
            textDocumentProxy.setMarkedText(selectionText, selectedRange: NSRange(location: 0, length: actualCount))
            selectionOffset = actualCount
        }
    }

    private func endSelection() {
        guard selectionActive else { return }
        selectionActive = false
        selectionOffset = 0
        textDocumentProxy.unmarkText()
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

    private func deleteWordBeforeCursor() {
        guard let before = textDocumentProxy.documentContextBeforeInput, !before.isEmpty else {
            textDocumentProxy.deleteBackward()
            return
        }

        let characters = before
        var deleteCount = 0
        var index = characters.endIndex

        // Remove trailing whitespace first
        while index > characters.startIndex {
            let previous = characters.index(before: index)
            if characters[previous].isWhitespace {
                deleteCount += 1
                index = previous
            } else {
                break
            }
        }

        // Remove word characters (letters/numbers/underscore)
        let wordSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_'’"))
        while index > characters.startIndex {
            let previous = characters.index(before: index)
            let charScalars = characters[previous].unicodeScalars
            if charScalars.allSatisfy({ wordSet.contains($0) }) {
                deleteCount += 1
                index = previous
            } else {
                break
            }
        }

        if deleteCount == 0 {
            textDocumentProxy.deleteBackward()
            return
        }

        for _ in 0..<deleteCount {
            textDocumentProxy.deleteBackward()
        }
    }
}
