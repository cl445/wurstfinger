//
//  TextShowcaseView.swift
//  wurstfinger
//
//  Showcase view with demo text for screenshots
//

import SwiftUI

struct TextShowcaseView: View {
    @StateObject private var viewModel = KeyboardViewModel(shouldPersistSettings: false)
    @StateObject private var languageSettings = LanguageSettings.shared
    @State private var colorScheme: ColorScheme?
    @State private var testText: String = "hello Wurstfinger!"

    var body: some View {
        VStack(spacing: 0) {
            // Text display area
            VStack(alignment: .leading, spacing: 0) {
                Text(testText)
                    .font(.system(size: 17))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .accessibilityIdentifier("textEditor")

            // Wurstfinger keyboard
            KeyboardRootView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))
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
    TextShowcaseView()
}
