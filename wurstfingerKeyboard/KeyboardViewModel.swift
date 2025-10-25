//
//  KeyboardViewModel.swift
//  Wurstfinger
//
//  Created by Claas Flint on 24.10.25.
//

import Combine
import CoreGraphics
import Foundation

enum KeyboardAction {
    case insert(String)
    case deleteBackward
    case space
    case newline
    case advanceToNextInputMode
    case dismissKeyboard
    case capitalizeWord(CapitalizationStyle)
    case moveCursor(offset: Int)
    case compose(trigger: String)
    case deleteWord
    case startSelection
    case updateSelection(offset: Int)
    case endSelection
}

enum CapitalizationStyle {
    case uppercased
    case lowercased
}

enum UtilityKey {
    case globe
    case symbols
    case delete
    case `return`
}

final class KeyboardViewModel: ObservableObject {
    @Published private(set) var activeLayer: KeyboardLayer = .lower
    @Published private(set) var utilityColumnLeading = false

    private let layout: KeyboardLayout
    private var actionHandler: ((KeyboardAction) -> Void)?
    private var isSpaceDragging = false
    private var spaceDragResidual: CGFloat = 0
    private let spaceDragStep: CGFloat = 14
    private var isSpaceSelecting = false
    private var spaceSelectionResidual: CGFloat = 0
    private var isDeleteDragging = false
    private var deleteDragResidual: CGFloat = 0

    init(layout: KeyboardLayout = .germanDefault) {
        self.layout = layout
    }

    var rows: [[MessagEaseKey]] {
        layout.rows(for: activeLayer)
    }

    var symbolToggleLabel: String {
        switch activeLayer {
        case .lower, .upper:
            return "123"
        case .numbers:
            return "#+="
        case .symbols:
            return "ABC"
        }
    }

    var isSymbolsToggleActive: Bool {
        switch activeLayer {
        case .numbers, .symbols:
            return true
        default:
            return false
        }
    }

    var spaceColumnSpan: Int {
        activeLayer == .numbers ? 2 : 3
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
        case .numbers, .symbols:
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
        insertText(uppercaseGerman(key.center))
    }

    func handleSpace() {
        actionHandler?(.space)
    }

    func handleDelete() {
        actionHandler?(.deleteBackward)
    }

    func handleDeleteWord() {
        actionHandler?(.deleteWord)
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
        case .numbers, .symbols:
            activeLayer = .upper
        }
    }

    func toggleSymbols() {
        switch activeLayer {
        case .lower, .upper:
            activeLayer = .numbers
        case .numbers:
            activeLayer = .symbols
        case .symbols:
            activeLayer = .lower
        }
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
        case .compose(let trigger, _):
            actionHandler?(.compose(trigger: trigger))
        }
    }

    func toggleUtilityColumnPosition() {
        utilityColumnLeading.toggle()
    }

    func handleUtilityCircularGesture(_ key: UtilityKey, direction _: KeyboardCircularDirection) {
        switch key {
        case .globe:
            toggleUtilityColumnPosition()
        default:
            break
        }
    }

    func beginSpaceDrag() {
        isSpaceDragging = true
        isSpaceSelecting = false
        spaceDragResidual = 0
        spaceSelectionResidual = 0
    }

    func updateSpaceDrag(deltaX: CGFloat) {
        guard isSpaceDragging, deltaX != 0 else { return }

        if isSpaceSelecting {
            updateSpaceSelection(deltaX: deltaX)
            return
        }

        spaceDragResidual += deltaX

        while spaceDragResidual <= -spaceDragStep {
            actionHandler?(.moveCursor(offset: -1))
            spaceDragResidual += spaceDragStep
        }

        while spaceDragResidual >= spaceDragStep {
            actionHandler?(.moveCursor(offset: 1))
            spaceDragResidual -= spaceDragStep
        }
    }

    func endSpaceDrag() {
        if isSpaceSelecting {
            actionHandler?(.endSelection)
        }
        isSpaceDragging = false
        isSpaceSelecting = false
        spaceDragResidual = 0
        spaceSelectionResidual = 0
    }

    func beginSpaceSelection() {
        guard isSpaceDragging else { return }
        if !isSpaceSelecting {
            isSpaceSelecting = true
            spaceSelectionResidual = 0
            actionHandler?(.startSelection)
        }
    }

    private func updateSpaceSelection(deltaX: CGFloat) {
        guard isSpaceDragging, isSpaceSelecting, deltaX != 0 else { return }

        spaceSelectionResidual += deltaX

        while spaceSelectionResidual <= -spaceDragStep {
            actionHandler?(.updateSelection(offset: -1))
            spaceSelectionResidual += spaceDragStep
        }

        while spaceSelectionResidual >= spaceDragStep {
            actionHandler?(.updateSelection(offset: 1))
            spaceSelectionResidual -= spaceDragStep
        }
    }

    func beginDeleteDrag() {
        isDeleteDragging = true
        deleteDragResidual = 0
    }

    func updateDeleteDrag(deltaX: CGFloat) {
        guard isDeleteDragging, deltaX != 0 else { return }

        deleteDragResidual += deltaX

        while deleteDragResidual <= -spaceDragStep {
            actionHandler?(.deleteBackward)
            deleteDragResidual += spaceDragStep
        }

        if deleteDragResidual > 0 {
            deleteDragResidual = min(deleteDragResidual, spaceDragStep)
        }
    }

    func endDeleteDrag() {
        isDeleteDragging = false
        deleteDragResidual = 0
    }

    private func uppercaseGerman(_ value: String) -> String {
        value.uppercased(with: Locale(identifier: "de_DE"))
    }
}
