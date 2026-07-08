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
    private var hostingController: UIHostingController<AnyView>?
    private lazy var viewModel = KeyboardViewModel()
    private var heightConstraint: NSLayoutConstraint?
    private var documentProxyTarget: DocumentProxyTarget?
    private var hostLifecycleObservers: [NSObjectProtocol] = []

    /// The language selected in the host app, normalised to an id that is
    /// guaranteed to exist in the registry (falling back to the system language,
    /// then English). Determines which definition is loaded.
    private var selectedLanguageId: String {
        LanguageSettings.resolvedLanguageId(
            SharedDefaults.store.string(forKey: SettingsKey.selectedLanguageId.rawValue)
        )
    }

    /// Reports the active keyboard language to iOS (shown in Settings > Keyboards).
    /// Reads directly from SharedDefaults to pick up language changes made in the host app,
    /// since the LanguageSettings singleton may hold a stale value from its init.
    override var primaryLanguage: String? {
        get {
            // Resolve the locale from lightweight registry metadata only. iOS may
            // query this eagerly/repeatedly, so it must never build a layout.
            let id = selectedLanguageId
            return (KeyboardRegistry.available.first { $0.id == id }?.localeIdentifier)
                ?? LanguageConfig.english.locale.identifier
        }
        set {
            super.primaryLanguage = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardHealthLog.shared.record("viewDidLoad.start")

        // Set background immediately to avoid flash
        view.backgroundColor = .clear

        // Wire up the data-driven pipeline
        let target = DocumentProxyTarget(controller: self)
        documentProxyTarget = target
        viewModel.bindTextInputTarget(target)
        viewModel.bindViewControllerActions(
            advanceToNextInputMode: { [weak self] in self?.advanceToNextInputMode() },
            dismissKeyboard: { [weak self] in self?.dismissKeyboard() }
        )

        // Honor a pinned startup language on cold start so the keyboard always
        // opens with it. In-keyboard cycling afterwards updates the selection
        // normally (subsequent reloads follow selectedLanguageId, not the pin).
        LanguageSettings(userDefaults: SharedDefaults.store).applyStartupLanguage()

        // Load the keyboard definition for the selected language
        loadDefinitionIfNeeded()

        // Configure hosting synchronously so the SwiftUI view exists
        // before viewWillAppear sets the height constraint. Deferring via
        // DispatchQueue.main.async caused a race in WebView-based apps where
        // viewWillAppear ran before configureHosting, leaving the extension
        // with a height constraint but no content.
        configureHosting()
        observeHostLifecycle()
        KeyboardHealthLog.shared.record("viewDidLoad.end")
    }

    deinit {
        hostLifecycleObservers.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Heartbeat: one entry per keyboard appearance. Its absence at the time
        // of a "system keyboard showed instead" incident proves iOS never
        // launched the extension (as opposed to the extension failing).
        KeyboardHealthLog.shared.record("viewWillAppear")
        // Persist Full Access status so the host app can show/hide haptic
        // settings. Write only on change: every shared-defaults write fires the
        // in-process didChangeNotification observer, which would run a second,
        // redundant reloadSettings on every appearance.
        let fullAccessKey = SettingsKey.keyboardFullAccess.rawValue
        if SharedDefaults.store.bool(forKey: fullAccessKey) != hasFullAccess {
            SharedDefaults.store.set(hasFullAccess, forKey: fullAccessKey)
        }
        // Reload settings every time keyboard appears
        viewModel.reloadSettings()
        // Reload definition only if language (or numpad style) changed while the
        // keyboard was backgrounded — avoids rebuilding the pipeline every time.
        loadDefinitionIfNeeded()
        // Reopen on the default (letters) layer: a keyboard dismissed on the
        // numeric or shifted layer must not resurface there.
        viewModel.resetToDefaultMode()
        updateKeyboardHeight()
        // Engage/release shift for the field's current context (e.g. start
        // uppercase in an empty compose field). `textDidChange` usually also
        // fires on appearance, but that is not guaranteed in every host app;
        // the refresh is idempotent, so evaluating in both paths is safe.
        viewModel.refreshAutoCapitalization()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Fires when the host text or caret position changes outside our own
        // key actions (field switch, caret relocation, external edits) — and
        // on keyboard appearance. Re-evaluate so stale shift state is
        // corrected (e.g. caret moved from a sentence start into a word).
        viewModel.refreshAutoCapitalization()
    }

    /// Loads the keyboard definition only when the inputs that determine it
    /// (selected language, numpad style) have changed since the last load.
    private func loadDefinitionIfNeeded() {
        // Resolve via the shared helper so a stale/invalid persisted id falls
        // back the same way `primaryLanguage` does (system language, then
        // English) instead of leaving loadDefinition a no-op.
        let languageId = selectedLanguageId
        let numpadStyle = SharedDefaults.store.string(
            forKey: SettingsKey.numpadStyle.rawValue
        )
        let signature = KeyboardViewModel.definitionSignature(
            languageId: languageId,
            numpadStyle: numpadStyle
        )
        // Compare against the view model's record of what it actually loaded —
        // a controller-side cache desyncs when the user cycles languages via
        // the globe key (the view model loads directly), forcing a needless
        // pipeline rebuild (two resolver chains + the full middleware stack)
        // on the next appearance.
        guard signature != viewModel.loadedDefinitionSignature else { return }
        viewModel.loadDefinition(for: languageId)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        shedMemoryBeforeSuspension("viewDidDisappear")
    }

    /// Sheds weight before the process gets suspended: iOS enforces the
    /// per-process memory limit again when a suspended keyboard extension is
    /// resumed by the next host. A device log capture (2026-07-07) showed
    /// exactly this — resume by Spotlight, immediate `jetsam
    /// per-process-limit` kill, silent system-keyboard fallback. Suspending
    /// small is what makes the next resume survive; a memory warning never
    /// fires on suspension, so this cannot wait for didReceiveMemoryWarning.
    private func shedMemoryBeforeSuspension(_ event: String) {
        KeyboardRegistry.evictAll(except: selectedLanguageId)
        KeyboardHealthLog.shared.record(event)
    }

    /// The keyboard can be suspended without `viewDidDisappear` ever firing:
    /// when the host app itself backgrounds while the keyboard is on screen
    /// (home gesture, app switch, tapping a Spotlight result), the view stays
    /// in the hierarchy and only the host lifecycle notifications fire — so
    /// the pre-suspension shedding must hook them too. The foreground record
    /// documents survived resumes in the health log.
    private func observeHostLifecycle() {
        let center = NotificationCenter.default
        hostLifecycleObservers.append(center.addObserver(
            forName: NSNotification.Name.NSExtensionHostDidEnterBackground,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.shedMemoryBeforeSuspension("hostDidEnterBackground")
        })
        hostLifecycleObservers.append(center.addObserver(
            forName: NSNotification.Name.NSExtensionHostWillEnterForeground,
            object: nil,
            queue: .main
        ) { _ in
            KeyboardHealthLog.shared.record("hostWillEnterForeground")
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        KeyboardHealthLog.shared.record("didReceiveMemoryWarning")
        // Free cached layouts for languages other than the active one. The
        // active definition stays resident (the view model holds a strong
        // reference) and remains cached for fast reuse.
        KeyboardRegistry.evictAll(except: selectedLanguageId)
    }

    private func updateKeyboardHeight() {
        // Constraint height ≡ content height by construction: the metrics
        // are the same source the SwiftUI grid renders from, so the fixed
        // paddings/spacing are no longer scaled by the constraint while the
        // content keeps them constant (review finding M7).
        let finalHeight = viewModel.layoutMetrics.totalHeight

        if let constraint = heightConstraint {
            if constraint.constant != finalHeight {
                constraint.constant = finalHeight
            }
        } else {
            let constraint = view.heightAnchor.constraint(equalToConstant: finalHeight)
            constraint.priority = .defaultHigh
            constraint.isActive = true
            heightConstraint = constraint
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        view.backgroundColor = .clear
        // Update viewModel with current width so SwiftUI re-renders after
        // orientation changes that happen while the keyboard is backgrounded.
        viewModel.updateViewWidth(view.bounds.width)
        // Window (not screen) bounds keep sizing correct in Split View and
        // Stage Manager; UIApplication.shared is unavailable in extensions,
        // so the window is reached through the view hierarchy.
        viewModel.updateWindowBounds(view.window?.bounds)
        // The resolved metrics depend on the container width and the
        // current-orientation screen height (fit-clamps), so the height
        // constraint must follow layout passes, not just viewWillAppear —
        // rotation with the keyboard open never calls viewWillAppear.
        // No-op when the height is unchanged.
        updateKeyboardHeight()
    }

    override var needsInputModeSwitchKey: Bool {
        true
    }

    private func configureHosting() {
        let rootView = DataDrivenKeyboardRootView(viewModel: viewModel)
        let controller = UIHostingController(rootView: AnyView(rootView))
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear

        addChild(controller)
        view.addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        controller.didMove(toParent: self)
        hostingController = controller
    }
}
