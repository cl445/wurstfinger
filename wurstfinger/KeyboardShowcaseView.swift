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

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            KeyboardRootView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .accessibilityIdentifier("showcaseKeyboard")

            Spacer()
                .frame(height: 20)
        }
        .background(Color(.systemGray6))
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            // Set language from environment if specified (for UI tests)
            if let forcedLanguage = ProcessInfo.processInfo.environment["FORCE_LANGUAGE"] {
                languageSettings.selectedLanguageId = forcedLanguage
            }
        }
    }
}

#Preview {
    KeyboardShowcaseView()
}
