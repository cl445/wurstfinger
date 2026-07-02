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

    /// Signature of the definition currently loaded into the pipeline. Used to
    /// skip the expensive rebuild (two resolver chains + 8 middlewares) on every
    /// `viewWillAppear` when nothing that affects the definition changed.
    private var loadedDefinitionSignature: String?

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
        KeyboardMemoryLog.record("viewDidLoad.start")

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
        KeyboardMemoryLog.record("viewDidLoad.end")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Persist Full Access status so the host app can show/hide haptic settings
        SharedDefaults.store.set(hasFullAccess, forKey: SettingsKey.keyboardFullAccess.rawValue)
        // Reload settings every time keyboard appears
        viewModel.reloadSettings()
        // Reload definition only if language (or numpad style) changed while the
        // keyboard was backgrounded — avoids rebuilding the pipeline every time.
        loadDefinitionIfNeeded()
        updateKeyboardHeight()
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
        ) ?? ""
        let signature = "\(languageId)|\(numpadStyle)"
        guard signature != loadedDefinitionSignature else { return }
        // Cache the signature only after a successful load so a failed lookup
        // does not suppress future reload attempts.
        viewModel.loadDefinition(for: languageId)
        loadedDefinitionSignature = signature
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        KeyboardMemoryLog.record("didReceiveMemoryWarning")
        // Free cached layouts for languages other than the active one. The
        // active definition stays resident (the view model holds a strong
        // reference) and remains cached for fast reuse.
        KeyboardRegistry.evictAll(except: selectedLanguageId)
    }

    private func updateKeyboardHeight() {
        // Calculate keyboard height including both aspect ratio and scale
        let baseHeight = KeyboardConstants.Calculations.baseHeight(aspectRatio: viewModel.keyAspectRatio)
        // Apply scale to match the visual size from scaleEffect
        let finalHeight = baseHeight * viewModel.keyboardScale

        if let constraint = heightConstraint {
            constraint.constant = finalHeight
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
