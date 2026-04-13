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

    @Published var activeLayer: KeyboardLayer = .lower
    @Published var isCapsLockActive: Bool = false
    @Published var isManualShift: Bool = false
    /// Current width of the keyboard's containing view.
    /// Updated by the controller in `viewWillLayoutSubviews()` so that
    /// SwiftUI re-evaluates layout after orientation changes (Bug #92).
    @Published private(set) var viewWidth: CGFloat = UIScreen.main.bounds.width
    /// Whether the device is currently in a landscape orientation.
    /// Driven by the controller via `updateOrientation(isLandscape:)`, since
    /// the keyboard's own bounds are always shorter than tall and cannot
    /// reliably distinguish portrait from landscape on their own.
    @Published private(set) var isLandscape: Bool = false
    /// The currently active data-driven keyboard mode (PR 9+).
    @Published var currentMode: KeyboardMode?
    /// Name of the currently active mode in the data-driven definition.
    @Published var activeModeName: String = ModeNames.main
    var locale: Locale

    // MARK: - Data-Driven Pipeline State (internal for extension access)

    var currentDefinition: KeyboardDefinition?
    var resolverChain: GestureResolverChain?
    var returnSwipeResolverChain: GestureResolverChain?
    var pipeline: ActionPipeline?
    weak var textInputTarget: TextInputTarget?
    var onAdvanceToNextInputMode: (() -> Void)?
    var onDismissKeyboard: (() -> Void)?
    var lastSwitchModeTime: Date?
    var lastSwitchModeTarget: String?
    /// Locale used by the pipeline (set from definition, separate from legacy locale).
    var pipelineLocale: Locale?

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
    let sharedDefaults: UserDefaults
    let shouldPersistSettings: Bool
    var actionHandler: ((KeyboardAction) -> Void)?
    var isSpaceDragging = false
    var spaceDragResidual: CGFloat = 0
    var isDeleteDragging = false
    var deleteDragResidual: CGFloat = 0
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

    /// Updates the tracked orientation. Called by the controller from
    /// `viewWillLayoutSubviews()` (which inspects its `traitCollection`) so
    /// `currentContext` can pick portrait/landscape arrangements correctly.
    func updateOrientation(isLandscape: Bool) {
        guard isLandscape != self.isLandscape else { return }
        self.isLandscape = isLandscape
    }

    // MARK: - Data-Driven Arrangement Selection (PR 9)

    /// Determines the active arrangement context based on orientation and
    /// the user's utility-column preference.
    var currentContext: ArrangementContext {
        let utilityLeft = layoutSettings.utilityColumnLeading
        switch (isLandscape, utilityLeft) {
        case (false, false): return .portrait
        case (false, true): return .portraitUtilityLeft
        case (true, false): return .landscape
        case (true, true): return .landscapeUtilityLeft
        }
    }

    /// The grid arrangement for `currentMode` and `currentContext`.
    /// Returns `nil` while the legacy layout path is still in use.
    var currentArrangement: GridArrangement? {
        currentMode?.arrangement(for: currentContext)
    }

    /// The active mode resolved from the current definition and mode name.
    var activeModeFromDefinition: KeyboardMode? {
        currentDefinition?.mode(activeModeName)
    }

    /// Exposes haptic tap to the pipeline extension.
    func triggerHapticTap() {
        hapticManager.tap()
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

    // MARK: - Haptic Feedback (delegated to HapticFeedbackManager)

    /// Haptic feedback for key touch-down — called by button views on first contact
    func feedbackTap() {
        hapticManager.tap()
    }

    func feedbackDrag() {
        hapticManager.drag()
    }
}
