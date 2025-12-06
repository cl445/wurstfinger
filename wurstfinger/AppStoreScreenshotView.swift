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
    @State private var displayText: String = "I love it!"
    @State private var receivedText: String = "How do you like the new keyboard?"

    var body: some View {
        VStack(spacing: 0) {
            // iPhone status bar - at the very top
            statusBar

            // Chat area - takes remaining space
            chatArea

            // Text input bar directly above keyboard
            textInputBar

            // Keyboard at the bottom
            KeyboardRootView(viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("screenshotKeyboard")
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .background(Color(.systemBackground))
        .preferredColorScheme(colorScheme)
        .statusBarHidden(true)
        .onAppear {
            configureFromEnvironment()
        }
    }

    private var statusBar: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "cellularbars")
                    .font(.system(size: 14))
                Image(systemName: "wifi")
                    .font(.system(size: 14))
                Image(systemName: "battery.100")
                    .font(.system(size: 18))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var chatArea: some View {
        VStack(spacing: 0) {
            // App header bar (simulated)
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentColor)

                Spacer()

                VStack(spacing: 2) {
                    Text("Sarah")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("online")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "video")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Chat-style message display
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Received message
                    HStack(alignment: .bottom, spacing: 8) {
                        receivedMessageBubble(receivedText)
                        Spacer(minLength: 50)
                    }

                    // Sent message (our text)
                    HStack(alignment: .bottom, spacing: 8) {
                        Spacer(minLength: 50)
                        sentMessageBubble(displayText)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }

    private var textInputBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 20))
                .foregroundColor(.secondary)

            // Text field simulation
            HStack {
                Text("Message")
                    .foregroundColor(Color(.placeholderText))
                    .font(.system(size: 16))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(18)

            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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

        // Default to English for App Store screenshots
        languageSettings.selectedLanguageId = "en_US"

        // Use full-size keyboard for screenshots (no scaling)
        viewModel.keyboardScale = 1.0

        // Override language if specified
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

        // Set display text (sent message)
        if let forcedText = env["FORCE_TEXT"] {
            displayText = forcedText
        }

        // Set received message text
        if let forcedReceived = env["FORCE_RECEIVED_TEXT"] {
            receivedText = forcedReceived
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
