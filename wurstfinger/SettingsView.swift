//
//  SettingsView.swift
//  wurstfinger
//
//  Created by Claas Flint on 26.10.25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("utilityColumnLeading", store: UserDefaults(suiteName: "group.com.wurstfinger.shared"))
    private var utilityColumnLeading = false

    @AppStorage("keyAspectRatio", store: UserDefaults(suiteName: "group.com.wurstfinger.shared"))
    private var keyAspectRatio = 1.5

    @AppStorage("keyboardScale", store: UserDefaults(suiteName: "group.com.wurstfinger.shared"))
    private var keyboardScale = 1.0

    @AppStorage("keyboardHorizontalPosition", store: UserDefaults(suiteName: "group.com.wurstfinger.shared"))
    private var keyboardHorizontalPosition = 0.5

    private let licenseURL = URL(string: "https://github.com/cl445/wurstfinger/blob/main/LICENSE")!

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $utilityColumnLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Utility Keys on Left")
                                .font(.body)

                            Text("Places globe, symbols, delete and return on the left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink(destination: AspectRatioSettingsView(aspectRatio: $keyAspectRatio)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Key Aspect Ratio")
                                .font(.body)

                            Text("Current: \(String(format: "%.2f", keyAspectRatio)):1")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink(destination: KeyboardSizePositionSettingsView(scale: $keyboardScale, position: $keyboardHorizontalPosition)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Keyboard Size & Position")
                                .font(.body)

                            Text("Scale: \(Int(keyboardScale * 100))%, Position: \(positionLabel(for: keyboardHorizontalPosition))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Layout")
                } footer: {
                    Text("Adjust the shape, size, and position of the keyboard.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Layout")
                        Spacer()
                        Text("German (MessagEase)")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: licenseURL) {
                        HStack {
                            Text("License")
                            Spacer()
                            Text("MIT")
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink(destination: ImprintView()) {
                        Text("Imprint")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func positionLabel(for value: Double) -> String {
        if value < 0.25 {
            return "Left"
        } else if value > 0.75 {
            return "Right"
        } else {
            return "Center"
        }
    }
}

#Preview {
    SettingsView()
}
