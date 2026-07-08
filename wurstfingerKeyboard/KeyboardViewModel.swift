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
    /// Layer/language changes and system actions (globe, dismiss, clipboard)
    case stateChange

    /// Feedback for an action flowing through the pipeline, or `nil` for
    /// silence. Text actions are silent here: their haptic already fired on
    /// touch-down, and firing again on dispatch would double every keystroke.
    /// Only actions that change keyboard or system state get a distinct
    /// confirmation tick. Clipboard actions are silent here too: whether
    /// copy/cut/paste actually does anything is only known inside
    /// `AdvancedTextMiddleware` (full access, non-empty selection or
    /// pasteboard), so their tick fires from its success paths instead.
    static func forPipelineAction(_ action: KeyAction) -> KeyboardHapticEvent? {
        switch action {
        case .switchMode, .switchToNextLanguage, .advanceToNextInputMode,
             .dismissKeyboard:
            .stateChange
        default:
            nil
        }
    }
}

struct DeviceLayoutUtils {
    /// Returns screen bounds for layout calculations.
    /// UIScreen.main is deprecated in iOS 16+ but UIApplication.shared is unavailable in app extensions,
    /// so UIScreen.main remains the pragmatic choice for keyboard extensions.
    static var screenBounds: CGRect {
        UIScreen.main.bounds
    }

    /// Default keyboard width wish per device class, in points.
    ///
    /// Points are the density-independent unit, so the default deliberately
    /// never consults screen bounds: the previous screen-relative default
    /// was orientation-dependent and halved the keyboard on a fresh install
    /// opened in landscape (review finding H1).
    static var defaultKeyboardWidth: Double {
        // 320 pt on iPad is a provisional constant pending real iPad tuning.
        UIDevice.current.userInterfaceIdiom == .pad ? 320.0 : 270.0
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
    /// Width cap for the keyboard so it keeps its portrait width in
    /// landscape and follows narrow panes (Slide Over, Stage Manager).
    /// Derived from the hosting window's *width* — the keyboard's own window
    /// is only as tall as the keyboard itself, so its height carries no
    /// container information — bounded by the screen's shortest side, which
    /// keeps landscape at the portrait width. Falls back to the screen until
    /// a window is attached.
    @Published private(set) var keyboardWidthCap: CGFloat = min(
        DeviceLayoutUtils.screenBounds.width, DeviceLayoutUtils.screenBounds.height
    )
    /// The currently active keyboard mode.
    @Published var currentMode: KeyboardMode?
    /// Name of the currently active mode in the data-driven definition.
    @Published var activeModeName: String = ModeNames.main

    // MARK: - Data-Driven Pipeline State (internal for extension access)

    var currentDefinition: KeyboardDefinition?
    /// Signature of the inputs that produced `currentDefinition` (see
    /// `definitionSignature(languageId:numpadStyle:)`). Kept on the view model
    /// — not the controller — so in-keyboard language switches, which load a
    /// new definition directly, keep it in sync.
    var loadedDefinitionSignature: String?
    var resolverChain: GestureResolverChain?
    var returnSwipeResolverChain: GestureResolverChain?
    var pipeline: ActionPipeline?
    /// Whether the current `shifted` mode was engaged by auto-capitalization
    /// (as opposed to a manual shift tap). Only auto-engaged shift may be
    /// released by `refreshAutoCapitalization()`; cleared on any mode change.
    var shiftEngagedByAutoCapitalization = false
    weak var textInputTarget: TextInputTarget?
    var onAdvanceToNextInputMode: (() -> Void)?
    var onDismissKeyboard: (() -> Void)?
    /// Locale used by the pipeline (set from the keyboard definition).
    var pipelineLocale: Locale?
    /// Published so the globe hint (`hasMultipleLanguages`) re-renders when the
    /// enabled-language set changes in Settings without the active language
    /// changing. `private(set)` keeps the normalisation invariants intact.
    @Published private(set) var enabledLanguageIds: [String] = []

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

    var utilityColumnLeading: Bool {
        get { layoutSettings.utilityColumnLeading }
        set { layoutSettings.utilityColumnLeading = newValue }
    }

    var keyAspectRatio: Double {
        get { layoutSettings.keyAspectRatio }
        set { layoutSettings.keyAspectRatio = newValue }
    }

    var keyboardWidth: Double {
        get { layoutSettings.keyboardWidth }
        set { layoutSettings.keyboardWidth = newValue }
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

    /// Learns and (P7) applies per-key touch-offset correction (spec §4.1, §5)
    /// and per-sector swipe bias (§14). Each track is inert unless its feature
    /// toggle is on. Lazy so its closures can capture `self` after
    /// initialization.
    lazy var touchLearning: TouchLearningController = .init(
        store: TouchOffsetStore(defaults: sharedDefaults),
        swipeStore: SwipeBiasStore(defaults: sharedDefaults),
        isEnabled: { [weak self] in self?.isTouchOffsetEnabled ?? false },
        isSwipeBiasEnabled: { [weak self] in self?.isSwipeBiasEnabled ?? false },
        currentRegime: { [weak self] in
            self?.currentTouchRegime ?? TouchRegime(orientation: .portrait, posture: .twoThumb)
        },
        keyPosition: { [weak self] in self?.normalizedKeyPosition($0) }
    )

    /// Collects gesture telemetry (§13) and the A/B proxy metric (§8). Lazy so
    /// its closures can capture `self`.
    lazy var telemetry: TelemetryController = .init(
        store: GestureTelemetryStore(defaults: sharedDefaults),
        isFeatureEnabled: { [weak self] in self?.isTouchOffsetEnabled ?? false },
        currentRegime: { [weak self] in
            self?.currentTouchRegime ?? TouchRegime(orientation: .portrait, posture: .twoThumb)
        }
    )

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

        enabledLanguageIds = LanguageSettings.normalizedEnabledLanguageIds(from: defaults)

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
        // Non-persisting view models (previews, showcases, screenshots) are
        // configured programmatically; reloading everything from the store
        // would revert forced values (e.g. the full-size screenshot scale) on
        // the next runloop pass — but haptic settings are never forced, and
        // the settings screen's preview keyboard should play slider changes
        // live, so non-persisting view models follow the store for haptics only.
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: sharedDefaults,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if shouldPersistSettings {
                reloadSettings()
            } else {
                hapticSettings.reload()
            }
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

    /// Updates the tracked window bounds. Called by the controller in
    /// `viewWillLayoutSubviews()` with the hosting window's bounds; a nil
    /// window (not yet attached) falls back to the device screen.
    ///
    /// Only the window's *width* is meaningful: the keyboard extension's
    /// window is merely keyboard-sized, so `min(width, height)` would return
    /// the keyboard height (~300 pt) and squeeze the keys horizontally while
    /// the height constraint stays — visibly breaking the key aspect ratio.
    func updateWindowBounds(_ bounds: CGRect?) {
        let screenShortestSide = min(
            DeviceLayoutUtils.screenBounds.width, DeviceLayoutUtils.screenBounds.height
        )
        let cap = bounds.map { min($0.width, screenShortestSide) } ?? screenShortestSide
        guard cap > 0, cap != keyboardWidthCap else { return }
        keyboardWidthCap = cap
    }

    // MARK: - Arrangement Selection

    /// Determines the active arrangement context from the user's utility-column
    /// preference.
    ///
    /// The keyboard intentionally keeps the portrait arrangement in **all**
    /// orientations so the key positions stay constant when the device rotates
    /// (muscle memory). The data model still defines dedicated `.landscape`
    /// arrangements, but the runtime does not select them.
    var currentContext: ArrangementContext {
        layoutSettings.utilityColumnLeading ? .portraitUtilityLeft : .portrait
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

    // MARK: - Layout Metrics

    /// Resolved layout metrics for the tracked view width — the single
    /// geometry source for the grid, key fonts, gesture classification, and
    /// the controller's height constraint. Recomputed whenever settings
    /// reload or `viewWidth`/`keyboardWidthCap` change (all `@Published`).
    var layoutMetrics: KeyboardLayoutMetrics {
        layoutMetrics(forContainerWidth: viewWidth)
    }

    /// Metrics resolved against an explicit container width, for preview and
    /// screenshot surfaces that render at a width other than the tracked
    /// view width. The height guard reads the *screen* bounds — the
    /// extension's own window is only keyboard-sized and carries no usable
    /// height information (see `updateWindowBounds`).
    func layoutMetrics(forContainerWidth width: CGFloat) -> KeyboardLayoutMetrics {
        layoutSettings.resolveMetrics(
            columns: currentArrangement?.columns ?? 4,
            rows: currentArrangement?.rows.count ?? KeyboardConstants.KeyDimensions.totalRows,
            availableWidth: width > 0 ? min(width, keyboardWidthCap) : keyboardWidthCap,
            screenHeight: DeviceLayoutUtils.screenBounds.height
        )
    }

    /// Pipeline hook: fires a confirmation tick for state-changing actions.
    /// Text actions stay silent — their haptic fires on touch-down.
    func triggerHaptic(for action: KeyAction) {
        guard let event = KeyboardHapticEvent.forPipelineAction(action) else { return }
        hapticManager.trigger(event)
    }

    func reloadSettings() {
        // Delegate to extracted settings classes - eliminates duplicate code
        hapticSettings.reload()
        layoutSettings.reload()

        // Equality-guarded: this runs on every in-process defaults write (via
        // the didChangeNotification observer), and an unguarded assignment to
        // a @Published property re-renders the whole keyboard each time.
        let newEnabledLanguageIds = LanguageSettings.normalizedEnabledLanguageIds(from: sharedDefaults)
        if enabledLanguageIds != newEnabledLanguageIds {
            enabledLanguageIds = newEnabledLanguageIds
        }
    }

    func switchToNextLanguage() {
        guard enabledLanguageIds.count > 1 else { return }

        // Cycle from the layout that is actually on screen. Startup can load a
        // pinned language whose id differs from the stored selection, so the
        // active definition — not shared defaults — is the source of truth;
        // otherwise the first swipe would just reload the current layout.
        let currentId = currentDefinition?.id
            ?? sharedDefaults.string(forKey: SettingsKey.selectedLanguageId.rawValue)
            ?? "en_US"
        // Static lookup on the already-normalized enabled list: constructing
        // a throwaway LanguageSettings here would re-run init normalization
        // (an app-group read/write cycle) on every globe swipe.
        let nextId = LanguageSettings.nextLanguageId(after: currentId, in: enabledLanguageIds)

        if nextId != currentId {
            sharedDefaults.set(nextId, forKey: SettingsKey.selectedLanguageId.rawValue)
            loadDefinition(for: nextId)
        }
    }

    var hasMultipleLanguages: Bool {
        enabledLanguageIds.count > 1
    }

    var currentLanguageLabel: String {
        guard let locale = pipelineLocale else { return "" }
        return LanguageSettings.label(for: locale)
    }

    // MARK: - Haptic Feedback (delegated to HapticFeedbackManager)

    /// Haptic feedback for key touch-down — called by button views on first contact
    func feedbackTap() {
        hapticManager.tap()
    }

    func feedbackDrag() {
        hapticManager.drag()
    }

    /// Confirmation tick for explicit layer/language switches.
    func feedbackStateChange() {
        hapticManager.stateChange()
    }
}
