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

    /// Reports the active keyboard language to iOS (shown in Settings > Keyboards).
    /// Reads directly from SharedDefaults to pick up language changes made in the host app,
    /// since the LanguageSettings singleton may hold a stale value from its init.
    override var primaryLanguage: String? {
        get {
            let languageId = SharedDefaults.store.string(forKey: SettingsKey.selectedLanguageId.rawValue)
            let config = languageId.flatMap { LanguageConfig.language(withId: $0) } ?? .english
            return config.locale.identifier
        }
        set {
            super.primaryLanguage = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

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
        let languageId = SharedDefaults.store.string(
            forKey: SettingsKey.selectedLanguageId.rawValue
        ) ?? LanguageSettings.detectSystemLanguage()
        viewModel.loadDefinition(for: languageId)

        // Configure hosting synchronously so the SwiftUI view exists
        // before viewWillAppear sets the height constraint. Deferring via
        // DispatchQueue.main.async caused a race in WebView-based apps where
        // viewWillAppear ran before configureHosting, leaving the extension
        // with a height constraint but no content.
        configureHosting()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Persist Full Access status so the host app can show/hide haptic settings
        SharedDefaults.store.set(hasFullAccess, forKey: SettingsKey.keyboardFullAccess.rawValue)
        // Reload settings every time keyboard appears
        viewModel.reloadSettings()
        // Reload definition if language changed while keyboard was backgrounded
        let languageId = SharedDefaults.store.string(
            forKey: SettingsKey.selectedLanguageId.rawValue
        ) ?? LanguageSettings.detectSystemLanguage()
        viewModel.loadDefinition(for: languageId)
        updateKeyboardHeight()
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
        // orientation changes that happen while the keyboard is backgrounded (Bug #92).
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
