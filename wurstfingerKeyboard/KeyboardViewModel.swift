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

    /// Current width of the keyboard's containing view.
    /// Updated by the controller in `viewWillLayoutSubviews()` so that
    /// SwiftUI re-evaluates layout after orientation changes.
    @Published private(set) var viewWidth: CGFloat = UIScreen.main.bounds.width
    /// Whether the device is currently in a landscape orientation.
    /// Driven by the controller via `updateOrientation(isLandscape:)`, since
    /// the keyboard's own bounds are always shorter than tall and cannot
    /// reliably distinguish portrait from landscape on their own.
    @Published private(set) var isLandscape: Bool = false
    /// The currently active keyboard mode.
    @Published var currentMode: KeyboardMode?
    /// Name of the currently active mode in the data-driven definition.
    @Published var activeModeName: String = ModeNames.main

    // MARK: - Data-Driven Pipeline State (internal for extension access)

    var currentDefinition: KeyboardDefinition?
    var resolverChain: GestureResolverChain?
    var returnSwipeResolverChain: GestureResolverChain?
    var pipeline: ActionPipeline?
    weak var textInputTarget: TextInputTarget?
    var onAdvanceToNextInputMode: (() -> Void)?
    var onDismissKeyboard: (() -> Void)?
    /// Locale used by the pipeline (set from the keyboard definition).
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

    let sharedDefaults: UserDefaults
    let shouldPersistSettings: Bool
    var isSpaceDragging = false
    var spaceDragResidual: CGFloat = 0
    /// Peak signed displacement during the current space drag. Used by the
    /// discrete cursor-movement mode to classify regular vs. return swipes.
    var spaceDragPeak: CGFloat = 0
    /// Cursor-movement style captured at the start of the current space drag, so
    /// a mid-drag settings change cannot switch classification mode mid-gesture.
    var spaceDragCursorStyle: CursorMovementStyle = .continuous
    var isDeleteDragging = false
    var deleteDragResidual: CGFloat = 0
    private var userDefaultsObserver: NSObjectProtocol?
    private var settingsCancellables = Set<AnyCancellable>()

    init(
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

    // MARK: - Arrangement Selection

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
    /// Returns `nil` if no definition is loaded.
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
