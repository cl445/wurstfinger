import SwiftUI

struct HapticSettingsView: View {
    @Environment(\.openURL) private var openURL

    @State private var showResetConfirmation = false

    @AppStorage(SettingsKey.hapticIntensityTap.rawValue, store: SharedDefaults.store)
    private var tapIntensity = Double(HapticSettings.defaultTapIntensity)

    @AppStorage(SettingsKey.hapticIntensityDrag.rawValue, store: SharedDefaults.store)
    private var dragIntensity = Double(HapticSettings.defaultDragIntensity)

    @AppStorage(SettingsKey.keyboardFullAccess.rawValue, store: SharedDefaults.store)
    private var hasFullAccess = false

    /// Whether the keyboard extension has synced its Full Access status at least once.
    /// Prevents treating "unset" as "denied" on fresh installs.
    private var hasSyncedFullAccess: Bool {
        SharedDefaults.store.object(forKey: SettingsKey.keyboardFullAccess.rawValue) != nil
    }

    @AppStorage(SettingsKey.keyAspectRatio.rawValue, store: SharedDefaults.store)
    private var previewAspectRatio = DeviceLayoutUtils.defaultKeyAspectRatio

    @AppStorage(SettingsKey.keyboardScale.rawValue, store: SharedDefaults.store)
    private var previewScale = DeviceLayoutUtils.defaultKeyboardScale

    @AppStorage(SettingsKey.keyboardHorizontalPosition.rawValue, store: SharedDefaults.store)
    private var previewPosition = DeviceLayoutUtils.defaultKeyboardPosition

    var body: some View {
        VStack(spacing: 16) {
            InteractiveKeyboardPreview(aspectRatio: $previewAspectRatio, scale: $previewScale, position: $previewPosition)
                .padding(.horizontal, 16)
                .padding(.top, 20)

            Form {
                if !hasSyncedFullAccess || hasFullAccess {
                    // Full Access granted or not yet synced — show full UI.
                    // No master toggle: each slider's "Off" level disables
                    // its feedback.
                    hapticSection(
                        title: "Tap Feedback",
                        value: $tapIntensity,
                        description: "Applies when you touch any key."
                    )

                    hapticSection(
                        title: "Drag Feedback",
                        value: $dragIntensity,
                        description: "Applies when you drag the Space or Delete key to move the cursor or delete text."
                    )

                    if !hasSyncedFullAccess {
                        Section {} footer: {
                            Text("Open the keyboard once to sync Full Access status.")
                        }
                    }
                } else {
                    // Full Access explicitly denied
                    Section {
                        Button {
                            openURL(URL(string: "app-settings:")!)
                        } label: {
                            HStack {
                                Image(systemName: "gear")
                                Text("Allow Full Access in Settings")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    } header: {
                        Label {
                            Text("Haptic feedback requires Full Access for the Wurstfinger keyboard.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                        .textCase(nil)
                    }
                }
            }
        }
        .navigationTitle("Haptics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    showResetConfirmation = true
                }
            }
        }
        .confirmationDialog(
            "Reset haptic feedback to its defaults?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                tapIntensity = Double(HapticSettings.defaultTapIntensity)
                dragIntensity = Double(HapticSettings.defaultDragIntensity)
            }
        }
    }

    /// The keyboard can only produce the pulses in `HapticIntensityLevel`,
    /// so the slider snaps to those levels instead of offering a continuous
    /// range that mostly changes nothing.
    private func hapticSection(
        title: LocalizedStringKey,
        value: Binding<Double>,
        description: LocalizedStringKey
    ) -> some View {
        Section {
            VStack(spacing: 8) {
                HapticLevelSlider(
                    levelIndex: levelIndexBinding(for: value),
                    levelCount: HapticIntensityLevel.allCases.count
                )
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text(HapticIntensityLevel(storedIntensity: value.wrappedValue).displayName))

                HStack {
                    Text("Off")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Max")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                Text(HapticIntensityLevel(storedIntensity: value.wrappedValue).displayName)
            }
        } footer: {
            Text(description)
        }
    }

    /// Bridges the stored 0...1 intensity to a discrete level index. Writing
    /// stores the level's canonical intensity, so legacy in-between values
    /// snap to a level the moment the slider is touched.
    ///
    /// Each snap onto a new level plays that level's pulse, so every level
    /// can be felt while sliding across the detents (off stays silent).
    private func levelIndexBinding(for value: Binding<Double>) -> Binding<Int> {
        Binding(
            get: { HapticIntensityLevel(storedIntensity: value.wrappedValue).rawValue },
            set: { index in
                let level = HapticIntensityLevel(rawValue: index) ?? .off
                let previous = HapticIntensityLevel(storedIntensity: value.wrappedValue)
                value.wrappedValue = Double(level.storedIntensity)
                if level != previous {
                    previewFeedback(intensity: Double(level.storedIntensity))
                }
            }
        )
    }

    /// Plays the same pulse the keyboard will emit at this intensity.
    private func previewFeedback(intensity: Double) {
        guard intensity > 0 else { return }
        switch HapticPulse.pulse(for: intensity) {
        case .selectionTick:
            UISelectionFeedbackGenerator().selectionChanged()
        case let .impact(style):
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
}

extension HapticIntensityLevel {
    /// User-facing level name. Lives in the host app target because the
    /// keyboard extension has no string catalog.
    var displayName: String {
        switch self {
        case .off: String(localized: "Off")
        case .tick: String(localized: "Minimal")
        case .soft: String(localized: "Soft")
        case .light: String(localized: "Light")
        case .medium: String(localized: "Medium")
        case .heavy: String(localized: "Strong")
        }
    }
}

/// Discrete slider with one detent per haptic level.
///
/// Custom instead of SwiftUI's `Slider` because the system control plays its
/// own (non-suppressible) haptic when the thumb hits the range bounds — which
/// made even the "Off" end vibrate. Here the only feedback is the level-snap
/// pulse played by the binding.
private struct HapticLevelSlider: View {
    @Binding var levelIndex: Int
    let levelCount: Int

    private let thumbDiameter: CGFloat = 27
    private let tickDiameter: CGFloat = 6
    private let trackHeight: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let stepWidth = (geometry.size.width - thumbDiameter) / CGFloat(levelCount - 1)
            let thumbOffset = stepWidth * CGFloat(levelIndex)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemFill))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: thumbOffset + thumbDiameter / 2, height: trackHeight)

                ForEach(0 ..< levelCount, id: \.self) { index in
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: tickDiameter, height: tickDiameter)
                        .offset(x: thumbDiameter / 2 + stepWidth * CGFloat(index) - tickDiameter / 2)
                }

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .offset(x: thumbOffset)
            }
            .frame(maxHeight: .infinity)
            .animation(.snappy(duration: 0.15), value: levelIndex)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let position = (gesture.location.x - thumbDiameter / 2) / stepWidth
                        let index = min(max(Int(position.rounded()), 0), levelCount - 1)
                        if index != levelIndex {
                            levelIndex = index
                        }
                    }
            )
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                levelIndex = min(levelIndex + 1, levelCount - 1)
            case .decrement:
                levelIndex = max(levelIndex - 1, 0)
            @unknown default:
                break
            }
        }
    }
}
