//
//  KeyboardShowcaseView.swift
//  wurstfinger
//
//  Keyboard showcase view for automated screenshots
//

import SwiftUI

struct KeyboardShowcaseView: View {
    @StateObject private var viewModel = KeyboardViewModel(shouldPersistSettings: false)
    @StateObject private var languageSettings = LanguageSettings.shared
    @State private var colorScheme: ColorScheme?

    var body: some View {
        VStack(spacing: 0) {
            KeyboardRootView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .accessibilityIdentifier("showcaseKeyboard")
                .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .preferredColorScheme(colorScheme)
        .statusBar(hidden: true)
        .onAppear {
            // Set language from environment if specified (for UI tests)
            if let forcedLanguage = ProcessInfo.processInfo.environment["FORCE_LANGUAGE"] {
                languageSettings.selectedLanguageId = forcedLanguage
            }

            // Set keyboard layer from environment if specified (for UI tests)
            if let forcedLayer = ProcessInfo.processInfo.environment["FORCE_LAYER"] {
                switch forcedLayer {
                case "numbers":
                    viewModel.setLayer(.numbers)
                case "symbols":
                    viewModel.setLayer(.symbols)
                case "upper":
                    viewModel.setLayer(.upper)
                case "lower":
                    viewModel.setLayer(.lower)
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
