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
    private var keyAspectRatio = 1.0

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

    @AppStorage("keyboardStyle", store: SharedDefaults.store)
    private var keyboardStyleRaw = KeyboardStyle.classic.rawValue

    @AppStorage("autoCapitalizeEnabled", store: SharedDefaults.store)
    private var autoCapitalizeEnabled = false

    private let licenseURL = URL(string: "https://github.com/cl445/wurstfinger/blob/main/LICENSE")!

    @AppStorage("expertModeEnabled", store: SharedDefaults.store)
    private var expertModeEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                generalSection
                appearanceSection
                feedbackSection
                expertSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section {
            NavigationLink(destination: LanguageSelectionView()) {
                SettingsRow(icon: "globe", color: .blue, title: "Language", subtitle: languageSettings.selectedLanguage.name)
            }

            Toggle(isOn: $utilityColumnLeading) {
                SettingsRow(icon: "keyboard.badge.ellipsis", color: .indigo, title: "Utility Keys on Left", subtitle: "Places globe, symbols, delete and return on the left")
            }

            Toggle(isOn: $autoCapitalizeEnabled) {
                SettingsRow(icon: "textformat.size.larger", color: .teal, title: "Auto-Capitalize", subtitle: "Capitalize after sentence-ending punctuation")
            }
        } header: {
            Text("General")
        }
    }

    private var appearanceSection: some View {
        Section {
            NavigationLink(destination: StyleSettingsView()) {
                SettingsRow(icon: "paintbrush", color: .cyan, title: "Style", subtitle: keyboardStyleDescription)
            }

            NavigationLink(destination: AspectRatioSettingsView(aspectRatio: $keyAspectRatio)) {
                SettingsRow(icon: "square.resize", color: .orange, title: "Key Aspect Ratio", subtitle: "Current: \(String(format: "%.2f", keyAspectRatio)):1")
            }

            NavigationLink(destination: KeyboardSizePositionSettingsView(scale: $keyboardScale, position: $keyboardHorizontalPosition)) {
                SettingsRow(icon: "arrow.up.left.and.arrow.down.right", color: .green, title: "Size & Position", subtitle: "Scale: \(Int(keyboardScale * 100))%, Position: \(positionLabel(for: keyboardHorizontalPosition))")
            }

            Picker(selection: $numpadStyleRaw) {
                Text("Phone (1-2-3)").tag(NumpadStyle.phone.rawValue)
                Text("Classic (7-8-9)").tag(NumpadStyle.classic.rawValue)
            } label: {
                SettingsRow(icon: "number.square", color: .purple, title: "Numpad Style", subtitle: numpadStyleDescription)
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Customize the look and feel of your keyboard.")
        }
    }

    private var feedbackSection: some View {
        Section {
            NavigationLink(destination: HapticSettingsView()) {
                SettingsRow(icon: "hand.tap", color: .red, title: "Haptic Feedback", subtitle: hapticModeDescription())
            }
        } header: {
            Text("Feedback")
        }
    }

    private var expertSection: some View {
        Section {
            NavigationLink(destination: ExpertSettingsView()) {
                SettingsRow(
                    icon: "slider.horizontal.3",
                    color: .orange,
                    title: "Expert",
                    subtitle: expertModeEnabled ? "Gesture tuning enabled" : "Advanced gesture settings"
                )
            }
        } header: {
            Text("Advanced")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Label {
                    Text("Version")
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.gray)
                }
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            Link(destination: licenseURL) {
                HStack {
                    Label {
                        Text("License")
                    } icon: {
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text("MIT")
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            NavigationLink(destination: ImprintView()) {
                Label {
                    Text("Imprint")
                } icon: {
                    Image(systemName: "building.2")
                        .foregroundColor(.gray)
                }
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Helpers

    private var keyboardStyleDescription: String {
        let style = KeyboardStyle(rawValue: keyboardStyleRaw) ?? .classic
        return style.displayName
    }

    private var numpadStyleDescription: String {
        let style = NumpadStyle(rawValue: numpadStyleRaw) ?? .phone
        switch style {
        case .phone:
            return "Phone layout (1-2-3)"
        case .classic:
            return "Classic layout (7-8-9)"
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

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String?

    init(icon: String, color: Color, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.color = color
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
