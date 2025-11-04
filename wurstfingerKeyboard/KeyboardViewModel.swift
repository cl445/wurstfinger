//
//  KeyboardViewModel.swift
//  Wurstfinger
//
//  Created by Claas Flint on 24.10.25.
//

import Combine
import CoreGraphics
import Foundation
import UIKit

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
    case cycleAccents
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

enum KeyboardHapticEvent {
    case tap
    case modifier
    case drag
}

final class KeyboardViewModel: ObservableObject {
    static let hapticTapIntensityKey = "hapticIntensityTap"
    static let hapticModifierIntensityKey = "hapticIntensityModifier"
    static let hapticDragIntensityKey = "hapticIntensityDrag"
    static let defaultTapIntensity: CGFloat = 0.5
    static let defaultModifierIntensity: CGFloat = 0.5
    static let defaultDragIntensity: CGFloat = 0.5

    @Published private(set) var activeLayer: KeyboardLayer = .lower
    @Published private(set) var isCapsLockActive: Bool = false
    @Published var hapticIntensityTap: CGFloat {
        didSet {
            let clamped = clampIntensity(hapticIntensityTap)
            if clamped != hapticIntensityTap {
                hapticIntensityTap = clamped
                return
            }
            if shouldPersistSettings {
                sharedDefaults.set(Double(clamped), forKey: Self.hapticTapIntensityKey)
            }
            updateImpactGenerator(for: .tap)
        }
    }
    @Published var hapticIntensityModifier: CGFloat {
        didSet {
            let clamped = clampIntensity(hapticIntensityModifier)
            if clamped != hapticIntensityModifier {
                hapticIntensityModifier = clamped
                return
            }
            if shouldPersistSettings {
                sharedDefaults.set(Double(clamped), forKey: Self.hapticModifierIntensityKey)
            }
            updateImpactGenerator(for: .modifier)
        }
    }
    @Published var hapticIntensityDrag: CGFloat {
        didSet {
            let clamped = clampIntensity(hapticIntensityDrag)
            if clamped != hapticIntensityDrag {
                hapticIntensityDrag = clamped
                return
            }
            if shouldPersistSettings {
                sharedDefaults.set(Double(clamped), forKey: Self.hapticDragIntensityKey)
            }
            updateImpactGenerator(for: .drag)
        }
    }
    @Published var utilityColumnLeading: Bool {
        didSet {
            if shouldPersistSettings {
                sharedDefaults.set(utilityColumnLeading, forKey: "utilityColumnLeading")
            }
        }
    }
    @Published var keyAspectRatio: Double {
        didSet {
            if shouldPersistSettings {
                sharedDefaults.set(keyAspectRatio, forKey: "keyAspectRatio")
            }
        }
    }
    @Published var keyboardScale: Double {
        didSet {
            if shouldPersistSettings {
                sharedDefaults.set(keyboardScale, forKey: "keyboardScale")
            }
        }
    }
    @Published var keyboardHorizontalPosition: Double {
        didSet {
            if shouldPersistSettings {
                sharedDefaults.set(keyboardHorizontalPosition, forKey: "keyboardHorizontalPosition")
            }
        }
    }

    private let layout: KeyboardLayout
    private let sharedDefaults: UserDefaults
    private let shouldPersistSettings: Bool
    private var actionHandler: ((KeyboardAction) -> Void)?
    private var isSpaceDragging = false
    private var spaceDragResidual: CGFloat = 0
    private var isSpaceSelecting = false
    private var spaceSelectionResidual: CGFloat = 0
    private var isDeleteDragging = false
    private var deleteDragResidual: CGFloat = 0
    private var impactGenerators: [KeyboardHapticEvent: UIImpactFeedbackGenerator] = [:]

    init(
        layout: KeyboardLayout = .germanDefault,
        userDefaults: UserDefaults? = nil,
        shouldPersistSettings: Bool = true
    ) {
        self.layout = layout
        self.shouldPersistSettings = shouldPersistSettings

        // Initialize UserDefaults once
        let defaults = userDefaults ?? UserDefaults(suiteName: "group.de.akator.wurstfinger.shared") ?? .standard
        self.sharedDefaults = defaults

        let storedTap = defaults.object(forKey: Self.hapticTapIntensityKey) as? NSNumber
        let storedModifier = defaults.object(forKey: Self.hapticModifierIntensityKey) as? NSNumber
        let storedDrag = defaults.object(forKey: Self.hapticDragIntensityKey) as? NSNumber

        let initialTap = storedTap.map { CGFloat(min(max($0.doubleValue, 0), 1)) } ?? Self.defaultTapIntensity
        let initialModifier = storedModifier.map { CGFloat(min(max($0.doubleValue, 0), 1)) } ?? Self.defaultModifierIntensity
        let initialDrag = storedDrag.map { CGFloat(min(max($0.doubleValue, 0), 1)) } ?? Self.defaultDragIntensity

        if shouldPersistSettings {
            sharedDefaults.register(defaults: [
                Self.hapticTapIntensityKey: Double(initialTap),
                Self.hapticModifierIntensityKey: Double(initialModifier),
                Self.hapticDragIntensityKey: Double(initialDrag)
            ])
        }

        self.hapticIntensityTap = initialTap
        self.hapticIntensityModifier = initialModifier
        self.hapticIntensityDrag = initialDrag

        // Read settings with default values
        self.utilityColumnLeading = defaults.object(forKey: "utilityColumnLeading") as? Bool ?? false
        // Default 1.5 maintains roughly the original key proportions on most devices
        let savedRatio = defaults.object(forKey: "keyAspectRatio") as? Double ?? 1.5
        // Ensure aspect ratio is within valid range
        self.keyAspectRatio = min(1.62, max(1.0, savedRatio))
        // Default 1.0 = full width
        let savedScale = defaults.object(forKey: "keyboardScale") as? Double ?? 1.0
        self.keyboardScale = min(1.0, max(0.3, savedScale))
        // Default 0.5 = centered
        let savedPosition = defaults.object(forKey: "keyboardHorizontalPosition") as? Double ?? 0.5
        self.keyboardHorizontalPosition = min(1.0, max(0.0, savedPosition))

        refreshImpactGenerators()
    }

    func reloadSettings() {
        let newUtilityValue = sharedDefaults.object(forKey: "utilityColumnLeading") as? Bool ?? false
        if utilityColumnLeading != newUtilityValue {
            utilityColumnLeading = newUtilityValue
        }

        let savedRatio = sharedDefaults.object(forKey: "keyAspectRatio") as? Double ?? 1.5
        let newAspectRatio = min(1.62, max(1.0, savedRatio))
        if keyAspectRatio != newAspectRatio {
            keyAspectRatio = newAspectRatio
        }

        let savedScale = sharedDefaults.object(forKey: "keyboardScale") as? Double ?? 1.0
        let newScale = min(1.0, max(0.3, savedScale))
        if keyboardScale != newScale {
            keyboardScale = newScale
        }

        let savedPosition = sharedDefaults.object(forKey: "keyboardHorizontalPosition") as? Double ?? 0.5
        let newPosition = min(1.0, max(0.0, savedPosition))
        if keyboardHorizontalPosition != newPosition {
            keyboardHorizontalPosition = newPosition
        }

        let newTapIntensity = (sharedDefaults.object(forKey: Self.hapticTapIntensityKey) as? NSNumber).map { CGFloat(min(max($0.doubleValue, 0), 1)) } ?? Self.defaultTapIntensity
        if abs(hapticIntensityTap - newTapIntensity) > 0.0001 {
            hapticIntensityTap = newTapIntensity
        }

        let newModifierIntensity = (sharedDefaults.object(forKey: Self.hapticModifierIntensityKey) as? NSNumber).map { CGFloat(min(max($0.doubleValue, 0), 1)) } ?? Self.defaultModifierIntensity
        if abs(hapticIntensityModifier - newModifierIntensity) > 0.0001 {
            hapticIntensityModifier = newModifierIntensity
        }

        let newDragIntensity = (sharedDefaults.object(forKey: Self.hapticDragIntensityKey) as? NSNumber).map { CGFloat(min(max($0.doubleValue, 0), 1)) } ?? Self.defaultDragIntensity
        if abs(hapticIntensityDrag - newDragIntensity) > 0.0001 {
            hapticIntensityDrag = newDragIntensity
        }

        refreshImpactGenerators()
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
        feedbackTap()
        actionHandler?(.space)
    }

    func handleDelete() {
        feedbackTap()
        actionHandler?(.deleteBackward)
    }

    func handleDeleteWord() {
        feedbackModifier()
        actionHandler?(.deleteWord)
    }

    func handleReturn() {
        feedbackModifier()
        actionHandler?(.newline)
    }

    func handleAdvanceToNextInputMode() {
        feedbackModifier()
        actionHandler?(.advanceToNextInputMode)
    }

    func handleDismissKeyboard() {
        feedbackModifier()
        actionHandler?(.dismissKeyboard)
    }

    func toggleShift() {
        switch activeLayer {
        case .lower:
            setShiftState(active: true)
        case .upper:
            setShiftState(active: false)
        case .numbers, .symbols:
            setShiftState(active: true)
        }
    }

    func toggleSymbols() {
        feedbackModifier()
        switch activeLayer {
        case .lower, .upper:
            activeLayer = .numbers
        case .numbers:
            activeLayer = .symbols
        case .symbols:
            activeLayer = .lower
        }
    }

    private func setShiftState(active: Bool) {
        feedbackModifier()

        if active {
            // If shift is already active, activate caps-lock
            if activeLayer == .upper && !isCapsLockActive {
                isCapsLockActive = true
            } else {
                // First activation - temporary shift
                isCapsLockActive = false
                activeLayer = .upper
            }
        } else {
            // Deactivate shift/caps-lock
            isCapsLockActive = false
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

    private func triggerHapticFeedback(_ event: KeyboardHapticEvent = .tap) {
        let resolvedIntensity = clampIntensity(intensity(for: event))
        guard resolvedIntensity > 0 else { return }

        let generator: UIImpactFeedbackGenerator
        if let existing = impactGenerators[event] {
            generator = existing
        } else {
            let newGenerator = makeImpactGenerator(for: event, overrideIntensity: resolvedIntensity)
            impactGenerators[event] = newGenerator
            generator = newGenerator
        }

        let performFeedback = {
            generator.impactOccurred(intensity: resolvedIntensity)
            generator.prepare()
        }

        if Thread.isMainThread {
            performFeedback()
        } else {
            DispatchQueue.main.async(execute: performFeedback)
        }
    }

    private func feedbackTap() {
        triggerHapticFeedback(.tap)
    }

    private func feedbackModifier() {
        triggerHapticFeedback(.modifier)
    }

    private func feedbackDrag() {
        triggerHapticFeedback(.drag)
    }

    private func insertText(_ value: String) {
        feedbackTap()
        actionHandler?(.insert(resolvedText(value)))
        // Only deactivate shift if it's temporary (not caps-lock)
        if activeLayer == .upper && !isCapsLockActive {
            activeLayer = .lower
        }
    }

    private func refreshImpactGenerators() {
        updateImpactGenerator(for: .tap)
        updateImpactGenerator(for: .modifier)
        updateImpactGenerator(for: .drag)
    }

    private func intensity(for event: KeyboardHapticEvent) -> CGFloat {
        switch event {
        case .tap:
            return hapticIntensityTap
        case .modifier:
            return hapticIntensityModifier
        case .drag:
            return hapticIntensityDrag
        }
    }

    private func updateImpactGenerator(for event: KeyboardHapticEvent) {
        let current = clampIntensity(intensity(for: event))
        if current <= 0 {
            impactGenerators[event] = nil
            return
        }
        impactGenerators[event] = makeImpactGenerator(for: event, overrideIntensity: current)
    }

    private func makeImpactGenerator(for event: KeyboardHapticEvent, overrideIntensity: CGFloat? = nil) -> UIImpactFeedbackGenerator {
        let resolved = clampIntensity(overrideIntensity ?? intensity(for: event))
        let generator = UIImpactFeedbackGenerator(style: feedbackStyle(for: resolved))
        generator.prepare()
        return generator
    }

    private func feedbackStyle(for intensity: CGFloat) -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch intensity {
        case ..<0.3:
            return .soft
        case ..<0.65:
            return .light
        default:
            return .medium
        }
    }

    private func clampIntensity(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    private func perform(_ output: MessagEaseOutput) {
        switch output {
        case .text(let value):
            insertText(value)
        case .toggleShift(let on):
            setShiftState(active: on)
        case .toggleSymbols:
            toggleSymbols()
        case .capitalizeWord(let uppercased):
            feedbackModifier()
            actionHandler?(.capitalizeWord(uppercased ? .uppercased : .lowercased))
        case .compose(let trigger, _):
            feedbackModifier()
            actionHandler?(.compose(trigger: trigger))
        case .cycleAccents:
            feedbackModifier()
            actionHandler?(.cycleAccents)
        }
    }

    func toggleUtilityColumnPosition() {
        feedbackModifier()
        utilityColumnLeading.toggle()
        if shouldPersistSettings {
            sharedDefaults.set(utilityColumnLeading, forKey: "utilityColumnLeading")
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

        while spaceSelectionResidual <= -KeyboardConstants.SpaceGestures.dragStep {
            actionHandler?(.updateSelection(offset: -1))
            feedbackDrag()
            spaceSelectionResidual += KeyboardConstants.SpaceGestures.dragStep
        }

        while spaceSelectionResidual >= KeyboardConstants.SpaceGestures.dragStep {
            actionHandler?(.updateSelection(offset: 1))
            feedbackDrag()
            spaceSelectionResidual -= KeyboardConstants.SpaceGestures.dragStep
        }
    }

    func beginDeleteDrag() {
        isDeleteDragging = true
        deleteDragResidual = 0
    }

    func updateDeleteDrag(deltaX: CGFloat) {
        guard isDeleteDragging, deltaX != 0 else { return }

        deleteDragResidual += deltaX

        while deleteDragResidual <= -KeyboardConstants.SpaceGestures.dragStep {
            actionHandler?(.deleteBackward)
            feedbackDrag()
            deleteDragResidual += KeyboardConstants.SpaceGestures.dragStep
        }

        if deleteDragResidual > 0 {
            deleteDragResidual = min(deleteDragResidual, KeyboardConstants.SpaceGestures.dragStep)
        }
    }

    func endDeleteDrag() {
        isDeleteDragging = false
        deleteDragResidual = 0
    }
}
