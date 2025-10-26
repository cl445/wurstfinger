//
//  OnboardingView.swift
//  wurstfinger
//
//  Created by Claas Flint on 26.10.25.
//

import SwiftUI

struct OnboardingView: View {
    @State private var keyboardInstalled = false
    @State private var fullAccessEnabled = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Setup Instructions
                    VStack(alignment: .leading, spacing: 20) {

                        SetupStepView(
                            number: 1,
                            title: "Enable keyboard",
                            description: "Open iOS Settings and activate Wurstfinger keyboard",
                            isCompleted: $keyboardInstalled
                        )

                        Button(action: openKeyboardSettings) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open Settings")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.leading, 40)

                        SetupStepView(
                            number: 2,
                            title: "Allow full access",
                            description: "Enable 'Full Access' for cursor movement and text selection",
                            isCompleted: $fullAccessEnabled
                        )

                        SetupStepView(
                            number: 3,
                            title: "Test keyboard",
                            description: "Switch to the Test tab and try the keyboard",
                            isCompleted: .constant(false)
                        )
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func openKeyboardSettings() {
        #if !APPEX
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

struct SetupStepView: View {
    let number: Int
    let title: String
    let description: String
    @Binding var isCompleted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number circle
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color.accentColor)
                    .frame(width: 32, height: 32)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                } else {
                    Text("\(number)")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Checkbox
            Button(action: { isCompleted.toggle() }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isCompleted ? .green : .gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    OnboardingView()
}
