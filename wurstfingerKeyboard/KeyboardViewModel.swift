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
    case deleteForward
    case space
    case newline
    case advanceToNextInputMode
    case dismissKeyboard
    case capitalizeWord(CapitalizationStyle)
    case moveCursor(offset: Int)
    case moveCursorByWord(forward: Bool)
    case compose(trigger: String)
    case cycleAccents
    // Text editing actions (clipboard)
    case copy
    case paste
    case cut
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
    case drag
}

struct DeviceLayoutUtils {
    /// Returns screen bounds for layout calculations.
    /// UIScreen.main is deprecated in iOS 16+ but UIApplication.shared is unavailable in app extensions,
    /// so UIScreen.main remains the pragmatic choice for keyboard extensions.
    static var screenBounds: CGRect {
        UIScreen.main.bounds
    }

    /// Calculates the default keyboard scale to achieve a target width of ~270pt
    /// (which corresponds to ~67% of an iPhone 17 Pro width).
    static var defaultKeyboardScale: Double {
        let targetWidth: CGFloat = 270.0
        let screenWidth = screenBounds.width

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
    // MARK: - Settings Keys (kept for backward compatibility)

    static let hapticTapIntensityKey = SettingsKey.hapticIntensityTap.rawValue
    static let hapticDragIntensityKey = SettingsKey.hapticIntensityDrag.rawValue
    static let numpadStyleKey = SettingsKey.numpadStyle.rawValue
    static let defaultTapIntensity: CGFloat = HapticSettings.defaultTapIntensity
    static let defaultDragIntensity: CGFloat = HapticSettings.defaultDragIntensity

    // MARK: - State

    @Published private(set) var activeLayer: KeyboardLayer = .lower
    @Published private(set) var isCapsLockActive: Bool = false
    @Published private(set) var isManualShift: Bool = false
    /// Current width of the keyboard's containing view.
    /// Updated by the controller in `viewWillLayoutSubviews()` so that
    /// SwiftUI re-evaluates layout after orientation changes (Bug #92).
    @Published private(set) var viewWidth: CGFloat = UIScreen.main.bounds.width
    private var locale: Locale

    // MARK: - Settings (delegated to extracted classes)

    let hapticSettings: HapticSettings
    let layoutSettings: LayoutSettings
    private let hapticManager: HapticFeedbackManager

    // MARK: - Computed Properties for Backward Compatibility

    var hapticIntensityTap: CGFloat {
        get { hapticSettings.tapIntensity }
        set { hapticSettings.tapIntensity = newValue }
    }

    var hapticIntensityDrag: CGFloat {
        get { hapticSettings.dragIntensity }
        set { hapticSettings.dragIntensity = newValue }
    }

    var hapticEnabled: Bool {
        get { hapticSettings.enabled }
        set { hapticSettings.enabled = newValue }
    }

    var utilityColumnLeading: Bool {
        get { layoutSettings.utilityColumnLeading }
        set { layoutSettings.utilityColumnLeading = newValue }
    }

    var keyAspectRatio: Double {
        get { layoutSettings.keyAspectRatio }
        set { layoutSettings.keyAspectRatio = newValue }
    }

    var keyboardScale: Double {
        get { layoutSettings.keyboardScale }
        set { layoutSettings.keyboardScale = newValue }
    }

    var keyboardHorizontalPosition: Double {
        get { layoutSettings.keyboardHorizontalPosition }
        set { layoutSettings.keyboardHorizontalPosition = newValue }
    }

    // MARK: - Private State

    private var layout: KeyboardLayout
    private let sharedDefaults: UserDefaults
    private let shouldPersistSettings: Bool
    private var actionHandler: ((KeyboardAction) -> Void)?
    private var isSpaceDragging = false
    private var spaceDragResidual: CGFloat = 0
    private var isDeleteDragging = false
    private var deleteDragResidual: CGFloat = 0
    private var userDefaultsObserver: NSObjectProtocol?
    private var settingsCancellables = Set<AnyCancellable>()

    init(
        layout: KeyboardLayout? = nil,
        userDefaults: UserDefaults? = nil,
        shouldPersistSettings: Bool = true
    ) {
        // Initialize UserDefaults once
        let defaults = userDefaults ?? SharedDefaults.store
        sharedDefaults = defaults
        self.shouldPersistSettings = shouldPersistSettings

        // Initialize extracted settings classes
        hapticSettings = HapticSettings(defaults: defaults, shouldPersist: shouldPersistSettings)
        layoutSettings = LayoutSettings(defaults: defaults, shouldPersist: shouldPersistSettings)
        hapticManager = HapticFeedbackManager(settings: hapticSettings)

        // Load layout based on selected language or use provided layout
        if let providedLayout = layout {
            self.layout = providedLayout
            // If a specific layout is provided, use German locale as default
            // (This is mainly for testing)
            locale = Locale(identifier: "de_DE")
        } else {
            let selectedLanguage = LanguageSettings.shared.selectedLanguage
            // Read numpad style from UserDefaults (default to phone style)
            let numpadStyleRaw = defaults.string(forKey: Self.numpadStyleKey) ?? NumpadStyle.phone.rawValue
            let numpadStyle = NumpadStyle(rawValue: numpadStyleRaw) ?? .phone
            self.layout = KeyboardLayout.layout(for: selectedLanguage, numpadStyle: numpadStyle)
            locale = selectedLanguage.locale
        }

        // Forward settings changes to trigger objectWillChange on this ViewModel
        hapticSettings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &settingsCancellables)
        layoutSettings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &settingsCancellables)

        // Observe in-process UserDefaults changes (e.g. utility column toggle).
        // Note: didChangeNotification only fires within the same process.
        // Cross-process updates from the host app are handled by
        // KeyboardViewController.viewWillAppear → reloadSettings().
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: sharedDefaults,
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

    /// Updates the tracked view width. Called by the controller in
    /// `viewWillLayoutSubviews()` so SwiftUI re-renders after orientation changes.
    func updateViewWidth(_ width: CGFloat) {
        guard width != viewWidth else { return }
        viewWidth = width
    }

    func reloadSettings() {
        // Delegate to extracted settings classes - eliminates duplicate code
        hapticSettings.reload()
        layoutSettings.reload()

        // Reload language if it changed
        reloadLanguage()
    }

    private func reloadLanguage() {
        // Read language ID directly from UserDefaults to catch changes from host app
        let languageId = sharedDefaults.string(forKey: SettingsKey.selectedLanguageId.rawValue) ?? LanguageSettings.detectSystemLanguage()

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
                isManualShift = false
            }
        }
    }

    var rows: [[MessagEaseKey]] {
        layout.rows(for: activeLayer)
    }

    var symbolToggleLabel: String {
        switch activeLayer {
        case .lower, .upper:
            "123"
        case .numbers, .symbols:
            "ABC"
        }
    }

    var isSymbolsToggleActive: Bool {
        switch activeLayer {
        case .numbers, .symbols:
            true
        default:
            false
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

    private func setShiftState(active: Bool) {
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

    private func resolvedText(_ value: String) -> String {
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

    // MARK: - Haptic Feedback (delegated to HapticFeedbackManager)

    /// Haptic feedback for key touch-down — called by button views on first contact
    func feedbackTap() {
        hapticManager.tap()
    }

    private func feedbackDrag() {
        hapticManager.drag()
    }

    private func insertText(_ value: String) {
        performTextInsertion(value)
    }

    /// For testing: simulates the text insertion flow without haptic feedback
    func simulateTextInsertion(_ value: String) {
        performTextInsertion(value)
    }

    private func performTextInsertion(_ value: String) {
        let resolvedValue = resolvedText(value)
        // Deactivate one-shot shift BEFORE the handler, so auto-cap reactivation
        // by the handler (e.g. after ¿/¡) is not stomped
        if activeLayer == .upper && !isCapsLockActive {
            setLayer(.lower)
        }
        actionHandler?(.insert(resolvedValue))
    }

    private func perform(_ output: MessagEaseOutput) {
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
