//
//  SettingsView.swift
//  wurstfinger
//
//  Created by Claas Flint on 26.10.25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var languageSettings = LanguageSettings.shared

    @AppStorage("utilityColumnLeading", store: SharedDefaults.store)
    private var utilityColumnLeading = false

    @AppStorage("keyAspectRatio", store: SharedDefaults.store)
    private var keyAspectRatio = 1.5

    @AppStorage("keyboardScale", store: SharedDefaults.store)
    private var keyboardScale = 1.0

    @AppStorage("keyboardHorizontalPosition", store: SharedDefaults.store)
    private var keyboardHorizontalPosition = 0.5

    @AppStorage(KeyboardViewModel.hapticTapIntensityKey, store: SharedDefaults.store)
    private var hapticTapIntensity = Double(KeyboardViewModel.defaultTapIntensity)

    @AppStorage(KeyboardViewModel.hapticModifierIntensityKey, store: SharedDefaults.store)
    private var hapticModifierIntensity = Double(KeyboardViewModel.defaultModifierIntensity)

    @AppStorage(KeyboardViewModel.hapticDragIntensityKey, store: SharedDefaults.store)
    private var hapticDragIntensity = Double(KeyboardViewModel.defaultDragIntensity)

    @AppStorage(KeyboardViewModel.numpadStyleKey, store: SharedDefaults.store)
    private var numpadStyleRaw = NumpadStyle.phone.rawValue

    private let licenseURL = URL(string: "https://github.com/cl445/wurstfinger/blob/main/LICENSE")!

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: LanguageSelectionView()) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Language")
                                .font(.body)

                            Text(languageSettings.selectedLanguage.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: $utilityColumnLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Utility Keys on Left")
                                .font(.body)

                            Text("Places globe, symbols, delete and return on the left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Picker(selection: $numpadStyleRaw) {
                        Text("Phone (1-2-3)").tag(NumpadStyle.phone.rawValue)
                        Text("Classic (7-8-9)").tag(NumpadStyle.classic.rawValue)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Numpad Style")
                                .font(.body)

                            Text(numpadStyleDescription)
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
                    Text("Adjust the language, shape, size, and position of the keyboard.")
                }

                Section {
                    NavigationLink(destination: HapticSettingsView()) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Haptic Feedback")
                                .font(.body)

                            Text(hapticModeDescription())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Choose how strong the keyboard should feel.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
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

    private var numpadStyleDescription: String {
        let style = NumpadStyle(rawValue: numpadStyleRaw) ?? .phone
        switch style {
        case .phone:
            return "Phone layout with numbers starting at 1-2-3 on top"
        case .classic:
            return "Classic calculator layout with 7-8-9 on top"
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

    private func hapticModeDescription() -> String {
        let tap = formatIntensity(hapticTapIntensity)
        let modifier = formatIntensity(hapticModifierIntensity)
        let drag = formatIntensity(hapticDragIntensity)
        return "Tap: \(tap) • Modifiers: \(modifier) • Drags: \(drag)"
    }

    private func formatIntensity(_ value: Double) -> String {
        if value <= 0.001 {
            return "Off"
        }
        return "\(Int(round(value * 100)))%"
    }
}

#Preview {
    SettingsView()
}
