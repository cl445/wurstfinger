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

    @State private var showResetAllConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                typingSection
                layoutSection
                appearanceSection
                feedbackSection
                advancedSection
                aboutSection
                resetSection
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset all keyboard settings to their defaults?",
                isPresented: $showResetAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset All Settings", role: .destructive) {
                    resetAllSettings()
                }
            } message: {
                Text("This restores every keyboard setting, including languages and expert gesture tuning.")
            }
        }
    }

    // MARK: - Sections

    private var typingSection: some View {
        Section {
            NavigationLink(destination: LanguageSelectionView()) {
                SettingsRow(icon: "globe", color: .blue, title: "Languages", subtitle: enabledLanguagesSummary)
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
            Text("Typing")
        }
    }

    private var layoutSection: some View {
        Section {
            NavigationLink(
                destination: KeyboardLayoutSettingsView(
                    aspectRatio: $keyAspectRatio,
                    scale: $keyboardScale,
                    position: $keyboardHorizontalPosition
                )
            ) {
                SettingsRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    color: .orange,
                    title: "Size & Layout",
                    subtitle: sizeLayoutDescription
                )
            }

            Toggle(isOn: $utilityColumnLeading) {
                SettingsRow(
                    icon: "keyboard.badge.ellipsis", color: .indigo,
                    title: "Utility Keys on Left",
                    subtitle: String(localized: "Places globe, symbols, delete and return on the left")
                )
            }

            Picker(selection: $numpadStyleRaw) {
                Text("Phone (1-2-3)").tag(NumpadStyle.phone.rawValue)
                Text("Classic (7-8-9)").tag(NumpadStyle.classic.rawValue)
            } label: {
                SettingsRow(icon: "number.square", color: .purple, title: "Numpad Style", subtitle: numpadStyleDescription)
            }
        } header: {
            Text("Layout")
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
        } header: {
            Text("Appearance")
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

    private var advancedSection: some View {
        Section {
            NavigationLink(destination: GesturePlaygroundView()) {
                SettingsRow(
                    icon: "scribble.variable",
                    color: .mint,
                    title: "Gesture Playground",
                    subtitle: String(localized: "See how your gestures are recognized")
                )
            }

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

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetAllConfirmation = true
            } label: {
                Text("Reset All Settings")
                    .frame(maxWidth: .infinity)
            }
        } footer: {
            Text("Restores all keyboard settings to their defaults.")
        }
    }

    // MARK: - Reset

    /// Removes every stored keyboard setting so all values fall back to
    /// their defaults. The synced Full Access status is kept — it mirrors a
    /// system permission, not a user preference.
    private func resetAllSettings() {
        let store = SharedDefaults.store

        for key in SettingsKey.allCases where key != .keyboardFullAccess {
            store.removeObject(forKey: key.rawValue)
        }

        let gestureTuningKeys = [
            GesturePreprocessorConfig.jitterThresholdKey,
            GesturePreprocessorConfig.maxJumpDistanceKey,
            GesturePreprocessorConfig.smoothingWindowKey,
            GestureClassificationThresholds.minSwipeLengthKey,
            GestureClassificationThresholds.maxReturnRatioKey,
            GestureClassificationThresholds.returnDisplacementStartKey,
            GestureClassificationThresholds.returnDisplacementEndKey,
            GestureClassificationThresholds.minCircularityKey,
            GestureClassificationThresholds.minAngularSpanKey,
            GestureClassificationThresholds.minTurnConsistencyKey,
            GestureClassificationThresholds.minOrientedCompactnessKey,
        ]
        for key in gestureTuningKeys {
            store.removeObject(forKey: key)
        }

        // The long-lived language singleton caches its state in memory.
        languageSettings.reloadFromStore()
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

    private var sizeLayoutDescription: String {
        let width = "\(Int(keyboardScale * 100))%"
        let ratio = String(format: "%.2f", keyAspectRatio)
        return String(localized: "Width: \(width), Keys: \(ratio):1")
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

    private func hapticModeDescription() -> String {
        let tap: String = HapticIntensityLevel(storedIntensity: hapticTapIntensity).displayName
        let drag: String = HapticIntensityLevel(storedIntensity: hapticDragIntensity).displayName
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
