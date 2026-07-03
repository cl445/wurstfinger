//
//  SettingsView.swift
//  wurstfinger
//
//  Created by Claas Flint on 26.10.25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var languageSettings = LanguageSettings.shared

    @AppStorage(SettingsKey.utilityColumnLeading.rawValue, store: SharedDefaults.store)
    private var utilityColumnLeading = false

    @AppStorage(SettingsKey.keyAspectRatio.rawValue, store: SharedDefaults.store)
    private var keyAspectRatio = DeviceLayoutUtils.defaultKeyAspectRatio

    @AppStorage(SettingsKey.keyboardScale.rawValue, store: SharedDefaults.store)
    private var keyboardScale = DeviceLayoutUtils.defaultKeyboardScale

    @AppStorage(SettingsKey.keyboardHorizontalPosition.rawValue, store: SharedDefaults.store)
    private var keyboardHorizontalPosition = DeviceLayoutUtils.defaultKeyboardPosition

    @AppStorage(SettingsKey.hapticIntensityTap.rawValue, store: SharedDefaults.store)
    private var hapticTapIntensity = Double(HapticSettings.defaultTapIntensity)

    @AppStorage(SettingsKey.hapticIntensityDrag.rawValue, store: SharedDefaults.store)
    private var hapticDragIntensity = Double(HapticSettings.defaultDragIntensity)

    @AppStorage(SettingsKey.numpadStyle.rawValue, store: SharedDefaults.store)
    private var numpadStyleRaw = NumpadStyle.phone.rawValue

    @AppStorage(SettingsKey.cursorMovementStyle.rawValue, store: SharedDefaults.store)
    private var cursorMovementStyleRaw = CursorMovementStyle.continuous.rawValue

    @AppStorage(SettingsKey.keyboardStyle.rawValue, store: SharedDefaults.store)
    private var keyboardStyleRaw = KeyboardStyle.classic.rawValue

    @AppStorage(SettingsKey.autoCapitalizeEnabled.rawValue, store: SharedDefaults.store)
    private var autoCapitalizeEnabled = false

    private let licenseURL = URL(string: "https://github.com/cl445/wurstfinger/blob/main/LICENSE")!

    @AppStorage(SettingsKey.expertModeEnabled.rawValue, store: SharedDefaults.store)
    private var expertModeEnabled = false

    @AppStorage(SettingsKey.hideLetters.rawValue, store: SharedDefaults.store)
    private var hideLetters = false

    @AppStorage(SettingsKey.hideStandardSymbols.rawValue, store: SharedDefaults.store)
    private var hideStandardSymbols = false

    @AppStorage(SettingsKey.hideExtraSymbols.rawValue, store: SharedDefaults.store)
    private var hideExtraSymbols = false

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
                SettingsRow(icon: "globe", color: .blue, title: "Languages", subtitle: enabledLanguagesSummary)
            }

            Toggle(isOn: $utilityColumnLeading) {
                SettingsRow(
                    icon: "keyboard.badge.ellipsis", color: .indigo,
                    title: "Utility Keys on Left",
                    subtitle: String(localized: "Places globe, symbols, delete and return on the left")
                )
            }

            Toggle(isOn: $autoCapitalizeEnabled) {
                SettingsRow(
                    icon: "textformat.size.larger", color: .teal,
                    title: "Auto-Capitalize",
                    subtitle: String(localized: "Capitalize after sentence-ending punctuation")
                )
            }

            Picker(selection: $cursorMovementStyleRaw) {
                Text("Continuous").tag(CursorMovementStyle.continuous.rawValue)
                Text("Step-by-step").tag(CursorMovementStyle.discrete.rawValue)
            } label: {
                SettingsRow(
                    icon: "cursor.rays", color: .green,
                    title: "Cursor Movement",
                    subtitle: cursorMovementStyleDescription
                )
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

            NavigationLink(destination: LabelVisibilitySettingsView()) {
                SettingsRow(
                    icon: "eye.slash", color: .indigo,
                    title: "Label Visibility",
                    subtitle: labelVisibilityDescription
                )
            }

            NavigationLink(destination: AspectRatioSettingsView(aspectRatio: $keyAspectRatio)) {
                SettingsRow(
                    icon: "square.resize", color: .orange,
                    title: "Key Aspect Ratio",
                    subtitle: String(localized: "Current: \(String(format: "%.2f", keyAspectRatio)):1")
                )
            }

            NavigationLink(destination: KeyboardSizePositionSettingsView(scale: $keyboardScale, position: $keyboardHorizontalPosition)) {
                SettingsRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    color: .green,
                    title: "Size & Position",
                    subtitle: sizePositionDescription
                )
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
                    subtitle: expertModeEnabled
                        ? String(localized: "Gesture tuning enabled")
                        : String(localized: "Advanced gesture settings")
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
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
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

    private var enabledLanguagesSummary: String {
        let names = languageSettings.enabledLanguages.map(\.name)
        let list = if names.count <= 2 {
            names.joined(separator: ", ")
        } else {
            String(localized: "\(names[0]) + \(names.count - 1) more")
        }
        if let pinned = languageSettings.pinnedLanguage {
            return String(localized: "\(list) (default: \(pinned.name))")
        }
        return list
    }

    private var sizePositionDescription: String {
        let scale = "\(Int(keyboardScale * 100))%"
        return String(localized: "Scale: \(scale), Position: \(positionLabel(for: keyboardHorizontalPosition))")
    }

    private var keyboardStyleDescription: String {
        let style = KeyboardStyle(rawValue: keyboardStyleRaw) ?? .classic
        return style.displayName
    }

    private var labelVisibilityDescription: String {
        let hidden = [
            hideLetters ? String(localized: "letters") : nil,
            hideStandardSymbols ? String(localized: "standard symbols") : nil,
            hideExtraSymbols ? String(localized: "extra symbols") : nil,
        ].compactMap(\.self)
        if hidden.isEmpty {
            return String(localized: "All labels visible")
        }
        return String(localized: "Hiding \(hidden.joined(separator: ", "))")
    }

    private var cursorMovementStyleDescription: String {
        let style = CursorMovementStyle(rawValue: cursorMovementStyleRaw) ?? .continuous
        switch style {
        case .continuous:
            return String(localized: "Drag to move cursor")
        case .discrete:
            return String(localized: "Swipe per character, return-swipe per word")
        }
    }

    private var numpadStyleDescription: String {
        let style = NumpadStyle(rawValue: numpadStyleRaw) ?? .phone
        switch style {
        case .phone:
            return String(localized: "Phone layout (1-2-3)")
        case .classic:
            return String(localized: "Classic layout (7-8-9)")
        }
    }

    private func positionLabel(for value: Double) -> String {
        if value < 0.25 {
            String(localized: "Left")
        } else if value > 0.75 {
            String(localized: "Right")
        } else {
            String(localized: "Center")
        }
    }

    private func hapticModeDescription() -> String {
        let tap: String = HapticIntensityLevel(storedIntensity: hapticTapIntensity).displayName
        // Drag feedback is a fixed tick, so its stored intensity is just on/off.
        let drag: String = hapticDragIntensity <= 0.001
            ? String(localized: "Off")
            : String(localized: "On")
        return String(localized: "Tap: \(tap) • Drag: \(drag)")
    }
}

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let subtitle: String?

    init(icon: String, color: Color, title: LocalizedStringKey, subtitle: String? = nil) {
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

                if let subtitle {
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
