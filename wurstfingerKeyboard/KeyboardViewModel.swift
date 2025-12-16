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

struct DeviceLayoutUtils {
    /// Calculates the default keyboard scale to achieve a target width of ~270pt
    /// (which corresponds to ~67% of an iPhone 17 Pro width).
    static var defaultKeyboardScale: Double {
        let targetWidth: CGFloat = 270.0
        let screenWidth = UIScreen.main.bounds.width
        
        // Avoid division by zero
        guard screenWidth > 0 else { return 1.0 }
        
        // Calculate scale required to hit target width
        let calculatedScale = targetWidth / screenWidth
        
        // Clamp between reasonable min/max (e.g., 0.26 to 1.0)
        // 0.26 is roughly iPad width (1024pt) -> 270/1024 = 0.26
        return min(1.0, max(0.25, calculatedScale))
    }
    
    static let defaultKeyAspectRatio: Double = 1.0
    static let defaultKeyboardPosition: Double = 0.5
}

final class KeyboardViewModel: ObservableObject {
    static let hapticTapIntensityKey = "hapticIntensityTap"
    static let hapticModifierIntensityKey = "hapticIntensityModifier"
    static let hapticDragIntensityKey = "hapticIntensityDrag"
    static let numpadStyleKey = "numpadStyle"
    static let defaultTapIntensity: CGFloat = 0.5
    static let defaultModifierIntensity: CGFloat = 0.5
    static let defaultDragIntensity: CGFloat = 0.5

    @Published private(set) var activeLayer: KeyboardLayer = .lower
    @Published private(set) var isCapsLockActive: Bool = false
    private var locale: Locale
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
    @Published var hapticEnabled: Bool {
        didSet {
            if shouldPersistSettings {
                sharedDefaults.set(hapticEnabled, forKey: "hapticEnabled")
            }
        }
    }

    private var layout: KeyboardLayout
    private let sharedDefaults: UserDefaults
    private let shouldPersistSettings: Bool
    private var actionHandler: ((KeyboardAction) -> Void)?
    private var isSpaceDragging = false
    private var spaceDragResidual: CGFloat = 0
    private var isDeleteDragging = false
    private var deleteDragResidual: CGFloat = 0
    private var userDefaultsObserver: NSObjectProtocol?

    init(
        layout: KeyboardLayout? = nil,
        userDefaults: UserDefaults? = nil,
        shouldPersistSettings: Bool = true
    ) {
        // Initialize UserDefaults once
        let defaults = userDefaults ?? SharedDefaults.store
        self.sharedDefaults = defaults

        // Load layout based on selected language or use provided layout
        if let providedLayout = layout {
            self.layout = providedLayout
            // If a specific layout is provided, use German locale as default
            // (This is mainly for testing)
            self.locale = Locale(identifier: "de_DE")
        } else {
            let selectedLanguage = LanguageSettings.shared.selectedLanguage
            // Read numpad style from UserDefaults (default to phone style)
            let numpadStyleRaw = defaults.string(forKey: Self.numpadStyleKey) ?? NumpadStyle.phone.rawValue
            let numpadStyle = NumpadStyle(rawValue: numpadStyleRaw) ?? .phone
            self.layout = KeyboardLayout.layout(for: selectedLanguage, numpadStyle: numpadStyle)
            self.locale = selectedLanguage.locale
        }

        self.shouldPersistSettings = shouldPersistSettings

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
        // Default 1.0 (Square)
        let savedRatio = defaults.object(forKey: "keyAspectRatio") as? Double ?? DeviceLayoutUtils.defaultKeyAspectRatio
        // Ensure aspect ratio is within valid range
        self.keyAspectRatio = min(1.62, max(1.0, savedRatio))
        // Default dynamic scale based on device width
        let savedScale = defaults.object(forKey: "keyboardScale") as? Double ?? DeviceLayoutUtils.defaultKeyboardScale
        self.keyboardScale = min(1.0, max(0.25, savedScale))
        // Default 0.5 = centered
        let savedPosition = defaults.object(forKey: "keyboardHorizontalPosition") as? Double ?? DeviceLayoutUtils.defaultKeyboardPosition
        self.keyboardHorizontalPosition = min(1.0, max(0.0, savedPosition))
        
        self.hapticEnabled = defaults.object(forKey: "hapticEnabled") as? Bool ?? true

        // Observe UserDefaults changes for language updates (works both within
        // same process and across processes via App Group)
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadSettings()
        }
    }

    deinit {
        if let observer = userDefaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
        
        let newHapticEnabled = sharedDefaults.object(forKey: "hapticEnabled") as? Bool ?? true
        if hapticEnabled != newHapticEnabled {
            hapticEnabled = newHapticEnabled
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

        // Reload language if it changed
        reloadLanguage()
    }

    private func reloadLanguage() {
        // Read language ID directly from UserDefaults to catch changes from host app
        let languageId = sharedDefaults.string(forKey: "selectedLanguageId") ?? LanguageSettings.detectSystemLanguage()

        if languageId != locale.identifier {
            // Notify SwiftUI that we're about to change the model
            objectWillChange.send()

            if let newLanguage = LanguageConfig.language(withId: languageId) {
                // Read numpad style from UserDefaults (default to phone style)
                let numpadStyleRaw = sharedDefaults.string(forKey: Self.numpadStyleKey) ?? NumpadStyle.phone.rawValue
                let numpadStyle = NumpadStyle(rawValue: numpadStyleRaw) ?? .phone
                layout = KeyboardLayout.layout(for: newLanguage, numpadStyle: numpadStyle)
                locale = newLanguage.locale
                // Reset to lower layer when language changes
                activeLayer = .lower
                isCapsLockActive = false
            }
        }
    }

    var rows: [[MessagEaseKey]] {
        layout.rows(for: activeLayer)
    }

    var symbolToggleLabel: String {
        switch activeLayer {
        case .lower, .upper:
            return "123"
        case .numbers, .symbols:
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
            activeLayer = .lower
        }
    }

    func toggleSymbols() {
        feedbackModifier()
        switch activeLayer {
        case .lower, .upper:
            activeLayer = .numbers
        case .numbers, .symbols:
            activeLayer = .lower
        }
    }

    func setLayer(_ layer: KeyboardLayer) {
        activeLayer = layer
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
            return value.uppercased(with: locale)
        default:
            return value
        }
    }

    /// Returns the locale for the current keyboard language
    func currentLocale() -> Locale {
        return locale
    }

    private func triggerHapticFeedback(_ event: KeyboardHapticEvent = .tap) {
        guard hapticEnabled else { return }
        let resolvedIntensity = clampIntensity(intensity(for: event))
        guard resolvedIntensity > 0 else { return }

        let performFeedback = {
            // Create a new generator for each event to ensure reliability
            // This matches the behavior in HapticSettingsView which is confirmed to work
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            generator.impactOccurred(intensity: resolvedIntensity)
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
        performTextInsertion(value)
    }

    /// For testing: simulates the text insertion flow without haptic feedback
    func simulateTextInsertion(_ value: String) {
        performTextInsertion(value)
    }

    private func performTextInsertion(_ value: String) {
        // Capture layer state BEFORE the action handler (which may change it)
        let wasUpper = activeLayer == .upper
        actionHandler?(.insert(resolvedText(value)))
        // Only deactivate shift if it was already upper before insert and not caps-lock
        if wasUpper && !isCapsLockActive {
            activeLayer = .lower
        }
    }


    private func intensity(for event: KeyboardHapticEvent) -> CGFloat {
        let rawValue: CGFloat
        switch event {
        case .tap:
            rawValue = hapticIntensityTap
        case .modifier:
            rawValue = hapticIntensityModifier
        case .drag:
            rawValue = hapticIntensityDrag
        }
        // Return raw value directly (linear)
        return rawValue
    }

    private func feedbackStyle(for intensity: CGFloat) -> UIImpactFeedbackGenerator.FeedbackStyle {
        // Use a constant style to avoid jarring jumps between styles (soft -> light -> medium)
        // .rigid provides a crisp, responsive feel that scales well with intensity
        return .rigid
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
