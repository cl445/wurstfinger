//
//  OnboardingView.swift
//  wurstfinger
//
//  Created by Claas Flint on 26.10.25.
//

import SwiftUI

#if os(iOS)
    /// Tab-root wrapper that provides its own navigation context. Views that
    /// are already inside a `NavigationStack` (e.g. Home) must push
    /// `OnboardingContentView` instead — nesting stacks is unsupported.
    struct OnboardingView: View {
        var body: some View {
            NavigationStack {
                OnboardingContentView()
            }
        }
    }

    struct OnboardingContentView: View {
        @Environment(\.openURL) private var openURL

        @AppStorage("onboarding.keyboardInstalled", store: SharedDefaults.store)
        private var keyboardInstalled = false

        @AppStorage("onboarding.fullAccessEnabled", store: SharedDefaults.store)
        private var fullAccessEnabled = false

        @AppStorage("onboarding.practiced", store: SharedDefaults.store)
        private var practiced = false

        private let settingsURL = URL(string: "app-settings:")!

        var body: some View {
            List {
                Section("Setup") {
                    SetupStepView(
                        number: 1,
                        title: "Enable keyboard",
                        description: "Open iOS Settings → General → Keyboard → Keyboards and add Wurstfinger.",
                        isCompleted: $keyboardInstalled
                    )

                    Button {
                        openURL(settingsURL)
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    SetupStepView(
                        number: 2,
                        title: "Allow full access",
                        description: "Activate \"Allow Full Access\" so cursor control and deletion gestures work.",
                        isCompleted: $fullAccessEnabled
                    )

                    SetupStepView(
                        number: 3,
                        title: "Try the keyboard",
                        description: "Switch to the Test tab and experiment with gestures.",
                        isCompleted: $practiced
                    )
                }
            }
            .navigationTitle("Setup")
        }
    }

    private struct SetupStepView: View {
        let number: Int
        let title: LocalizedStringKey
        let description: LocalizedStringKey
        @Binding var isCompleted: Bool

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green : Color.accentColor)
                        .frame(width: 32, height: 32)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                            .fontWeight(.bold)
                    } else {
                        Text("\(number)")
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle(isOn: $isCompleted) {
                    EmptyView()
                }
                .labelsHidden()
            }
            .padding(.vertical, 8)
        }
    }
#endif

#if os(iOS)
    #Preview {
        OnboardingView()
    }
#endif
