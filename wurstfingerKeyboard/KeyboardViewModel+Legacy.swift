//
//  KeyboardViewModel+Legacy.swift
//  Wurstfinger
//
//  Extension containing the legacy gesture handling and action dispatch
//  path (MessagEaseKey → MessagEaseOutput → KeyboardAction → actionHandler).
//  Will be removed in PR 13 when the old path is fully replaced by the
//  data-driven pipeline.
//

import Foundation

extension KeyboardViewModel {
    // MARK: - Legacy Gesture Handling

    func displayText(for key: MessagEaseKey) -> String {
        switch activeLayer {
        case .lower:
            key.center.lowercased()
        case .upper:
            key.center.uppercased()
        case .numbers, .symbols:
            key.center
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
            // No output defined for this direction - do nothing
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
        }
        // No output defined - do nothing
    }

    func handleCircularGesture(for key: MessagEaseKey, direction: KeyboardCircularDirection) {
        // Try to get circular output from the key
        // First tries requested direction, then opposite direction
        // If neither is defined, does nothing
        if let output = key.circularOutput(for: direction) {
            perform(output)
        }
        // If no output is defined, do nothing (no fallback to tap)
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

    func handleGlobeSwipe(direction: KeyboardDirection) {
        switch direction {
        case .left:
            handleAdvanceToNextInputMode()
        case .down:
            handleDismissKeyboard()
        default:
            // Center and other directions reserved for future use (e.g., emoji)
            break
        }
    }

    func toggleShift() {
        switch activeLayer {
        case .lower:
            setShiftState(active: true)
        case .upper:
            setShiftState(active: false)
        case .numbers, .symbols:
            setLayer(.lower)
        }
    }

    func toggleSymbols() {
        switch activeLayer {
        case .lower, .upper:
            setLayer(.numbers)
        case .numbers, .symbols:
            setLayer(.lower)
        }
    }

    /// Handle swipe gestures on the symbols toggle key (123/ABC)
    /// - Up: Copy
    /// - Up-Right: Cut
    /// - Down: Paste
    /// - Other directions: Toggle symbols
    func handleSymbolsKeySwipe(_ direction: KeyboardDirection) {
        switch direction {
        case .up:
            actionHandler?(.copy)
        case .upRight:
            actionHandler?(.cut)
        case .down:
            actionHandler?(.paste)
        default:
            toggleSymbols()
        }
    }

    func setLayer(_ layer: KeyboardLayer) {
        activeLayer = layer
        if layer != .upper {
            isManualShift = false
        }
    }

    func setShiftState(active: Bool) {
        if active {
            // If shift is already active, activate caps-lock
            if activeLayer == .upper && !isCapsLockActive {
                isCapsLockActive = true
                isManualShift = false
            } else {
                // First activation - temporary shift
                isCapsLockActive = false
                activeLayer = .upper
                isManualShift = true
            }
        } else {
            // Deactivate shift/caps-lock
            isCapsLockActive = false
            isManualShift = false
            activeLayer = .lower
        }
    }

    func resolvedText(_ value: String) -> String {
        switch activeLayer {
        case .upper:
            value.uppercased(with: locale)
        default:
            value
        }
    }

    /// Returns the locale for the current keyboard language
    func currentLocale() -> Locale {
        locale
    }

    /// Vietnamese Telex input is active when the selected language is Vietnamese
    var isTelexActive: Bool {
        locale.language.languageCode?.identifier == "vi"
    }

    func insertText(_ value: String) {
        performTextInsertion(value)
    }

    /// For testing: simulates the text insertion flow without haptic feedback
    func simulateTextInsertion(_ value: String) {
        performTextInsertion(value)
    }

    func performTextInsertion(_ value: String) {
        let resolvedValue = resolvedText(value)
        // Deactivate one-shot shift BEFORE the handler, so auto-cap reactivation
        // by the handler (e.g. after ¿/¡) is not stomped
        if activeLayer == .upper && !isCapsLockActive {
            setLayer(.lower)
        }
        actionHandler?(.insert(resolvedValue))
    }

    func perform(_ output: MessagEaseOutput) {
        switch output {
        case let .text(value):
            insertText(value)
        case let .toggleShift(on):
            setShiftState(active: on)
        case .toggleSymbols:
            toggleSymbols()
        case let .capitalizeWord(uppercased):
            actionHandler?(.capitalizeWord(uppercased ? .uppercased : .lowercased))
        case let .compose(trigger, _):
            actionHandler?(.compose(trigger: trigger))
        case .cycleAccents:
            actionHandler?(.cycleAccents)
        }
    }

    func toggleUtilityColumnPosition() {
        utilityColumnLeading.toggle()
        if shouldPersistSettings {
            sharedDefaults.set(utilityColumnLeading, forKey: SettingsKey.utilityColumnLeading.rawValue)
        }
    }

    func handleUtilityCircularGesture(_ key: UtilityKey, direction _: KeyboardCircularDirection) {
        switch key {
        case .globe:
            toggleUtilityColumnPosition()
        default:
            break
        }
    }

    // MARK: - Legacy Drag Handling

    func beginSpaceDrag() {
        isSpaceDragging = true
        spaceDragResidual = 0
    }

    func updateSpaceDrag(deltaX: CGFloat) {
        guard isSpaceDragging, deltaX != 0 else { return }

        spaceDragResidual += deltaX

        while spaceDragResidual <= -KeyboardConstants.SpaceGestures.dragStep {
            actionHandler?(.moveCursor(offset: -1))
            feedbackDrag()
            spaceDragResidual += KeyboardConstants.SpaceGestures.dragStep
        }

        while spaceDragResidual >= KeyboardConstants.SpaceGestures.dragStep {
            actionHandler?(.moveCursor(offset: 1))
            feedbackDrag()
            spaceDragResidual -= KeyboardConstants.SpaceGestures.dragStep
        }
    }

    func endSpaceDrag() {
        isSpaceDragging = false
        spaceDragResidual = 0
    }

    // MARK: - Discrete Cursor Movement

    func handleDiscreteSpaceSwipe(forward: Bool) {
        actionHandler?(.moveCursor(offset: forward ? 1 : -1))
        feedbackDrag()
    }

    func handleDiscreteSpaceReturnSwipe(forward: Bool) {
        actionHandler?(.moveCursorByWord(forward: forward))
        feedbackDrag()
    }

    var cursorMovementStyle: CursorMovementStyle {
        let raw = sharedDefaults.string(forKey: SettingsKey.cursorMovementStyle.rawValue)
            ?? CursorMovementStyle.continuous.rawValue
        return CursorMovementStyle(rawValue: raw) ?? .continuous
    }

    func beginDeleteDrag() {
        isDeleteDragging = true
        deleteDragResidual = 0
    }

    func updateDeleteDrag(deltaX: CGFloat) {
        guard isDeleteDragging, deltaX != 0 else { return }

        deleteDragResidual += deltaX

        // Drag left = delete backward
        while deleteDragResidual <= -KeyboardConstants.SpaceGestures.dragStep {
            actionHandler?(.deleteBackward)
            feedbackDrag()
            deleteDragResidual += KeyboardConstants.SpaceGestures.dragStep
        }

        // Drag right = delete forward
        while deleteDragResidual >= KeyboardConstants.SpaceGestures.dragStep {
            actionHandler?(.deleteForward)
            feedbackDrag()
            deleteDragResidual -= KeyboardConstants.SpaceGestures.dragStep
        }
    }

    func endDeleteDrag() {
        isDeleteDragging = false
        deleteDragResidual = 0
    }
}
