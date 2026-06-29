//
//  KeyboardShowcaseView.swift
//  wurstfinger
//
//  Keyboard showcase view for automated screenshots
//

import SwiftUI

/// Counts pipeline actions for dead zone testing.
private class ActionCountTarget: TextInputTarget, ObservableObject {
    @Published var count: Int = 0
    var documentContextBeforeInput: String? {
        nil
    }

    var documentContextAfterInput: String? {
        nil
    }

    var selectedText: String? {
        nil
    }

    var hasFullAccess: Bool {
        false
    }

    func insertText(_: String) {
        count += 1
    }

    func deleteBackward() {
        count += 1
    }

    func adjustTextPosition(byCharacterOffset _: Int) {
        count += 1
    }
}

struct KeyboardShowcaseView: View {
    @StateObject private var viewModel = KeyboardViewModel(shouldPersistSettings: false)
    @StateObject private var languageSettings = LanguageSettings.shared
    @StateObject private var actionTarget = ActionCountTarget()
    @State private var colorScheme: ColorScheme?

    private let isDeadZoneTest = ProcessInfo.processInfo.environment["DEAD_ZONE_TEST"] != nil

    var body: some View {
        VStack(spacing: 0) {
            DataDrivenKeyboardRootView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                // `.contain` promotes the per-key accessibilityIdentifiers into
                // a queryable container so UI tests can find keys by slot id.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("showcaseKeyboard")
                .padding(.vertical, 8)

            if isDeadZoneTest {
                Text("\(actionTarget.count)")
                    .accessibilityIdentifier("actionCount")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .background(Color(.systemBackground))
        .preferredColorScheme(colorScheme)
        .statusBar(hidden: true)
        .onAppear {
            // Set language from environment if specified (for UI tests)
            if let forcedLanguage = ProcessInfo.processInfo.environment["FORCE_LANGUAGE"] {
                languageSettings.selectedLanguageId = forcedLanguage
            }

            // Wire up dead zone counter
            if isDeadZoneTest {
                viewModel.bindTextInputTarget(actionTarget)
            }

            // Load definition
            viewModel.loadDefinition(for: languageSettings.selectedLanguageId)

            // Set keyboard mode from environment if specified (for UI tests)
            if let forcedLayer = ProcessInfo.processInfo.environment["FORCE_LAYER"] {
                switch forcedLayer {
                case "numbers":
                    viewModel.switchToMode(ModeNames.numeric)
                case "symbols":
                    viewModel.switchToMode(ModeNames.symbols)
                case "upper":
                    viewModel.switchToMode(ModeNames.shifted)
                case "lower":
                    viewModel.switchToMode(ModeNames.main)
                default:
                    break
                }
            }

            // Set appearance from environment if specified (for UI tests)
            if let forcedAppearance = ProcessInfo.processInfo.environment["FORCE_APPEARANCE"] {
                switch forcedAppearance {
                case "dark":
                    colorScheme = .dark
                case "light":
                    colorScheme = .light
                default:
                    colorScheme = nil
                }
            }
        }
    }
}

#Preview {
    KeyboardShowcaseView()
}
