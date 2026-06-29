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

    /// Reports the active keyboard language to iOS (shown in Settings > Keyboards).
    /// Reads directly from SharedDefaults to pick up language changes made in the host app,
    /// since the LanguageSettings singleton may hold a stale value from its init.
    override var primaryLanguage: String? {
        get {
            // `resolvedLanguage` reads lightweight registry/config metadata only
            // (it never builds a layout), so it is safe for iOS to query eagerly.
            resolvedLanguage.locale.identifier
        }
        set {
            super.primaryLanguage = newValue
        }
    }

    /// The active language, resolved identically for both `primaryLanguage`
    /// (reported to iOS) and definition loading. Reads the selected id, falls
    /// back to the detected system language, then to English for an unknown id —
    /// so the rendered layout and the locale shown by iOS never diverge.
    private var resolvedLanguage: LanguageConfig {
        let requestedId = SharedDefaults.store.string(
            forKey: SettingsKey.selectedLanguageId.rawValue
        ) ?? LanguageSettings.detectSystemLanguage()
        return LanguageConfig.language(withId: requestedId) ?? .english
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
        let languageId = resolvedLanguage.id
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
        KeyboardRegistry.evictAll(except: resolvedLanguage.id)
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
        viewModel.updateOrientation(isLandscape: detectIsLandscape())
    }

    /// Determines whether the host app is currently in a landscape orientation.
    ///
    /// On iPhone, `verticalSizeClass == .compact` is the canonical signal.
    /// On iPad, `verticalSizeClass` stays `.regular` in both orientations,
    /// so we fall back to the window scene's `interfaceOrientation`. The
    /// keyboard's own bounds are always shorter than tall and cannot be
    /// used as a substitute.
    private func detectIsLandscape() -> Bool {
        if traitCollection.userInterfaceIdiom == .pad {
            return view.window?.windowScene?.interfaceOrientation.isLandscape ?? false
        }
        return traitCollection.verticalSizeClass == .compact
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
