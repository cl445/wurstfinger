//
//  AppStoreScreenshotView.swift
//  wurstfinger
//
//  Screenshot view for App Store showing keyboard with sample text
//

import SwiftUI

struct AppStoreScreenshotView: View {
    @StateObject private var viewModel = KeyboardViewModel(shouldPersistSettings: false)
    @StateObject private var languageSettings = LanguageSettings.shared
    @State private var colorScheme: ColorScheme?

    // Sample text to display - can be overridden via environment
    @State private var displayText: String = "Hello Wurstfinger!"

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Text display area (simulated text field)
                textDisplayArea
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height * 0.35)

                Spacer()

                // Keyboard
                KeyboardRootView(viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("screenshotKeyboard")
            }
        }
        .background(Color(.systemBackground))
        .preferredColorScheme(colorScheme)
        .statusBarHidden(true)
        .onAppear {
            configureFromEnvironment()
        }
    }

    private var textDisplayArea: some View {
        VStack(spacing: 0) {
            // App header bar (simulated)
            HStack {
                Text("Messages")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Chat-style message display
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Received message
                    HStack(alignment: .bottom, spacing: 8) {
                        receivedMessageBubble("Hey! How's the new keyboard?")
                        Spacer(minLength: 60)
                    }

                    // Sent message (our text)
                    HStack(alignment: .bottom, spacing: 8) {
                        Spacer(minLength: 60)
                        sentMessageBubble(displayText)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider()

            // Text input area (simulated, shows cursor)
            HStack(spacing: 12) {
                HStack {
                    Text(viewModel.activeLayer == .numbers || viewModel.activeLayer == .symbols ? "123" : "Aa")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 20)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)

                Spacer()

                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func receivedMessageBubble(_ text: String) -> some View {
        Text(text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(18)
    }

    private func sentMessageBubble(_ text: String) -> some View {
        Text(text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(18)
    }

    private func configureFromEnvironment() {
        let env = ProcessInfo.processInfo.environment

        // Set language
        if let forcedLanguage = env["FORCE_LANGUAGE"] {
            languageSettings.selectedLanguageId = forcedLanguage
        }

        // Set keyboard layer
        if let forcedLayer = env["FORCE_LAYER"] {
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

        // Set appearance
        if let forcedAppearance = env["FORCE_APPEARANCE"] {
            switch forcedAppearance {
            case "dark":
                colorScheme = .dark
            case "light":
                colorScheme = .light
            default:
                colorScheme = nil
            }
        }

        // Set display text
        if let forcedText = env["FORCE_TEXT"] {
            displayText = forcedText
        }
    }
}

#Preview("Light - Letters") {
    AppStoreScreenshotView()
        .preferredColorScheme(.light)
}

#Preview("Dark - Letters") {
    AppStoreScreenshotView()
        .preferredColorScheme(.dark)
}
