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

    @AppStorage(SettingsKey.keyboardWidthPoints.rawValue, store: SharedDefaults.store)
    private var keyboardWidth = DeviceLayoutUtils.defaultKeyboardWidth

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

    @AppStorage(SettingsKey.selectedThemeLight.rawValue, store: SharedDefaults.store)
    private var selectedThemeLight = BuiltInThemes.classic.id

    @AppStorage(SettingsKey.autoCapitalizeEnabled.rawValue, store: SharedDefaults.store)
    private var autoCapitalizeEnabled = false

    @AppStorage(SettingsKey.longPressNumbersEnabled.rawValue, store: SharedDefaults.store)
    private var longPressNumbersEnabled = false

    @AppStorage(SettingsKey.doubleSpacePeriodEnabled.rawValue, store: SharedDefaults.store)
    private var doubleSpacePeriodEnabled = false

    @AppStorage(SettingsKey.cutAllEnabled.rawValue, store: SharedDefaults.store)
    private var cutAllEnabled = false

    @AppStorage(SettingsKey.keyboardFullAccess.rawValue, store: SharedDefaults.store)
    private var hasFullAccess = false

    /// Mirrors `HapticSettingsView`: an unset key means the keyboard has not
    /// reported its Full Access status yet, which must not read as "denied".
    private var hasSyncedFullAccess: Bool {
        SharedDefaults.store.object(forKey: SettingsKey.keyboardFullAccess.rawValue) != nil
    }

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
                gesturesSection
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

            Toggle(isOn: $doubleSpacePeriodEnabled) {
                SettingsRow(
                    icon: "space", color: .mint,
                    title: "Double-Space Period",
                    subtitle: String(localized: "Type two spaces to insert a period")
                )
            }

            Toggle(isOn: $longPressNumbersEnabled) {
                SettingsRow(
                    icon: "123.rectangle", color: .pink,
                    title: "Type Numbers by Holding",
                    subtitle: String(localized: "Hold a letter key to type its digit")
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

    private var gesturesSection: some View {
        Section {
            Toggle(isOn: $cutAllEnabled) {
                SettingsRow(icon: "scissors", color: .red, title: "Cut All by Circling")
            }
            .disabled(isFullAccessDenied)
        } header: {
            Text("Gestures")
        } footer: {
            // The explanation lives here rather than as a row subtitle: a
            // Toggle caps the height of its label, which clips the text in
            // languages whose title wraps. A footer is free to wrap.
            Text(cutAllFooter)
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

            NavigationLink(destination: KeyboardSizePositionSettingsView(width: $keyboardWidth, position: $keyboardHorizontalPosition)) {
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
        // Percent relative to the device-class default width (the wish is
        // stored in points; 100 % == DeviceLayoutUtils.defaultKeyboardWidth).
        let percent = Int((keyboardWidth / DeviceLayoutUtils.defaultKeyboardWidth * 100).rounded())
        let scale = "\(percent)%"
        return String(localized: "Scale: \(scale), Position: \(positionLabel(for: keyboardHorizontalPosition))")
    }

    private var keyboardStyleDescription: String {
        let theme = ThemeStore.theme(id: selectedThemeLight) ?? BuiltInThemes.classic
        return theme.displayName
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

    /// Full Access is known to be missing — as opposed to not yet reported,
    /// which happens before the keyboard has been opened once.
    private var isFullAccessDenied: Bool {
        hasSyncedFullAccess && !hasFullAccess
    }

    private var cutAllFooter: String {
        if isFullAccessDenied {
            return String(localized: "Cutting to the clipboard requires Full Access")
        }
        // The key keeps its clipboard gestures in both modes, so the text names
        // it by the label it carries in the letter mode, where the gesture is
        // found, and then says it survives the switch. Naming the numeric-mode
        // label instead is not possible: it is per language (abc, абв, かな).
        return String(localized: """
        Circle the 123 key to cut the text around the cursor. \
        Swipe down on the same key to paste it back. \
        Both gestures stay on the key after it switches the keyboard to numbers.
        """)
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
