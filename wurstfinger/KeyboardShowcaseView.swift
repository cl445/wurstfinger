//
//  KeyboardShowcaseView.swift
//  wurstfinger
//
//  Keyboard showcase view for automated screenshots
//

import SwiftUI

/// Captures pipeline actions for UI testing.
///
/// Always counts actions (for dead-zone testing). When `capturesText` is set
/// it additionally accumulates the produced text into `typedText` and exposes
/// it as `documentContextBeforeInput`, so typing UI tests can assert the
/// actual output (and context-dependent actions like compose / capitalize
/// behave realistically).
private class ActionCountTarget: TextInputTarget, ObservableObject {
    @Published var count: Int = 0
    @Published var typedText: String = ""

    private let capturesText: Bool

    init(capturesText: Bool = false) {
        self.capturesText = capturesText
    }

    var documentContextBeforeInput: String? {
        capturesText ? typedText : nil
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

    func insertText(_ text: String) {
        count += 1
        if capturesText { typedText += text }
    }

    func deleteBackward() {
        count += 1
        if capturesText, !typedText.isEmpty { typedText.removeLast() }
    }

    func adjustTextPosition(byCharacterOffset _: Int) {
        count += 1
    }
}

struct KeyboardShowcaseView: View {
    @StateObject private var viewModel = KeyboardViewModel(shouldPersistSettings: false)
    @StateObject private var languageSettings = LanguageSettings.shared
    @StateObject private var actionTarget = ActionCountTarget(
        capturesText: ProcessInfo.processInfo.environment["TYPING_TEST"] != nil
    )
    @State private var colorScheme: ColorScheme?

    private let isDeadZoneTest = ProcessInfo.processInfo.environment["DEAD_ZONE_TEST"] != nil
    private let isTypingTest = ProcessInfo.processInfo.environment["TYPING_TEST"] != nil

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

            if isTypingTest {
                // Visible placeholder keeps the element present when empty;
                // the exact text (incl. empty / trailing spaces) is exposed
                // via accessibilityValue and read by tests as `.value`.
                Text(actionTarget.typedText.isEmpty ? "—" : actionTarget.typedText)
                    .accessibilityIdentifier("typedText")
                    .accessibilityValue(actionTarget.typedText)
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

            // Wire up the capturing target for dead-zone and typing tests
            if isDeadZoneTest || isTypingTest {
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
