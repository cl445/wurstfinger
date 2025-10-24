//
//  KeyboardViewModel.swift
//  wurstfingerKeyboard
//
//  Created by Claas Flint on 24.10.25.
//

import Combine
import Foundation

enum KeyboardAction {
    case insert(String)
    case deleteBackward
    case space
    case newline
    case advanceToNextInputMode
    case dismissKeyboard
    case capitalizeWord(CapitalizationStyle)
}

enum CapitalizationStyle {
    case uppercased
    case lowercased
}

final class KeyboardViewModel: ObservableObject {
    @Published private(set) var activeLayer: KeyboardLayer = .lower

    private let layout: KeyboardLayout
    private var actionHandler: ((KeyboardAction) -> Void)?

    init(layout: KeyboardLayout = .germanDefault) {
        self.layout = layout
    }

    var rows: [[MessagEaseKey]] {
        layout.rows
    }

    func bindActionHandler(_ handler: @escaping (KeyboardAction) -> Void) {
        actionHandler = handler
    }

    func displayText(for key: MessagEaseKey) -> String {
        switch activeLayer {
        case .lower:
            return key.center.lowercased()
        case .upper:
            return key.center.uppercased()
        case .symbols:
            return key.center
        }
    }

    func handleKeyTap(_ key: MessagEaseKey) {
        guard let output = key.character(for: .center, on: activeLayer) else { return }
        insertText(output)
    }

    func handleKeySwipe(_ key: MessagEaseKey, direction: KeyboardDirection) {
        if direction == .center {
            handleKeyTap(key)
            return
        }

        guard let output = key.output(for: direction) else {
            handleKeyTap(key)
            return
        }

        perform(output)
    }

    func handleKeySwipeReturn(_ key: MessagEaseKey, direction: KeyboardDirection) {
        guard direction != .center else {
            handleKeyTap(key)
            return
        }

        if let output = key.output(for: direction, returning: true) {
            perform(output)
        } else if let fallback = key.output(for: direction) {
            perform(fallback)
        } else {
            handleKeyTap(key)
        }
    }

    func handleCircularGesture(for key: MessagEaseKey, direction: KeyboardCircularDirection) {
        switch direction {
        case .clockwise:
            insertText(uppercaseGerman(key.center))
        case .counterclockwise:
            toggleSymbols()
        }
    }

    func handleSpace() {
        actionHandler?(.space)
    }

    func handleDelete() {
        actionHandler?(.deleteBackward)
    }

    func handleReturn() {
        actionHandler?(.newline)
    }

    func handleAdvanceToNextInputMode() {
        actionHandler?(.advanceToNextInputMode)
    }

    func handleDismissKeyboard() {
        actionHandler?(.dismissKeyboard)
    }

    func toggleShift() {
        switch activeLayer {
        case .lower:
            activeLayer = .upper
        case .upper:
            activeLayer = .lower
        case .symbols:
            activeLayer = .upper
        }
    }

    func toggleSymbols() {
        activeLayer = activeLayer == .symbols ? .lower : .symbols
    }

    private func resolvedText(_ value: String) -> String {
        switch activeLayer {
        case .upper:
            return value.uppercased(with: Locale(identifier: "de_DE"))
        default:
            return value
        }
    }

    private func insertText(_ value: String) {
        actionHandler?(.insert(resolvedText(value)))
        if activeLayer == .upper {
            activeLayer = .lower
        }
    }

    private func perform(_ output: MessagEaseOutput) {
        switch output {
        case .text(let value):
            insertText(value)
        case .toggleShift(let on):
            activeLayer = on ? .upper : .lower
        case .toggleSymbols:
            toggleSymbols()
        case .capitalizeWord(let uppercased):
            actionHandler?(.capitalizeWord(uppercased ? .uppercased : .lowercased))
        }
    }

    private func uppercaseGerman(_ value: String) -> String {
        value.uppercased(with: Locale(identifier: "de_DE"))
    }
}
