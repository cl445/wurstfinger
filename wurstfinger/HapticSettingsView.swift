import SwiftUI

struct HapticSettingsView: View {
    @AppStorage(SettingsKey.hapticIntensityTap.rawValue, store: SharedDefaults.store)
    private var tapIntensity = Double(HapticSettings.defaultTapIntensity)

    @AppStorage(SettingsKey.hapticIntensityDrag.rawValue, store: SharedDefaults.store)
    private var dragIntensity = Double(HapticSettings.defaultDragIntensity)

    @AppStorage(SettingsKey.hapticEnabled.rawValue, store: SharedDefaults.store)
    private var hapticEnabled = true

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
        VStack(spacing: 20) {
            // Keyboard Preview
            InteractiveKeyboardPreview(aspectRatio: $previewAspectRatio, scale: $previewScale, position: $previewPosition)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 24) {
                    if !hasSyncedFullAccess || hasFullAccess {
                        // Full Access granted or not yet synced — show full UI
                        VStack(spacing: 8) {
                            Toggle("Haptic Feedback", isOn: $hapticEnabled)
                                .font(.headline)

                            Text("Enable or disable all haptic feedback vibrations.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if !hasSyncedFullAccess {
                                Text("Open the keyboard once to sync Full Access status.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 16)

                        if hapticEnabled {
                            Divider()
                                .padding(.horizontal, 16)

                            VStack(spacing: 24) {
                                hapticControl(
                                    title: "Tap Feedback",
                                    value: $tapIntensity,
                                    description: "Applies when you touch any key."
                                )

                                // Drag steps use a fixed selection tick (no
                                // intensity), so this is a plain on/off toggle.
                                VStack(spacing: 8) {
                                    Toggle("Drag Feedback", isOn: dragFeedbackEnabled)
                                        .font(.headline)

                                    Text("Applies when you drag the Space or Delete key to move the cursor or delete text.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    } else {
                        // Full Access explicitly denied
                        VStack(spacing: 12) {
                            Toggle("Haptic Feedback", isOn: .constant(false))
                                .font(.headline)
                                .disabled(true)

                            Label {
                                Text(
                                    // swiftlint:disable:next line_length
                                    "Haptic feedback requires Full Access. Enable it in **Settings › Wurstfinger › Keyboards › Wurstfinger › Allow Full Access**."
                                )
                                .font(.caption)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 20)
        .navigationTitle("Haptics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !hasSyncedFullAccess || hasFullAccess {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        tapIntensity = Double(HapticSettings.defaultTapIntensity)
                        dragIntensity = Double(HapticSettings.defaultDragIntensity)
                        hapticEnabled = true
                    }
                }
            }
        }
    }

    /// The drag tick has no intensity; the stored value only gates on/off.
    private var dragFeedbackEnabled: Binding<Bool> {
        Binding(
            get: { dragIntensity > 0 },
            set: { dragIntensity = $0 ? Double(HapticSettings.defaultDragIntensity) : 0 }
        )
    }

    private let sliderRange: ClosedRange<Double> = 0 ... 1
    private let sliderStep: Double = 0.05

    private func hapticControl(
        title: LocalizedStringKey,
        value: Binding<Double>,
        description: LocalizedStringKey
    ) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                TextField("Value", value: value, formatter: NumberFormatter.decimalFormatter(minimum: 0, maximum: 1))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }

            VStack(spacing: 8) {
                Slider(value: value, in: sliderRange, step: sliderStep) { editing in
                    if !editing {
                        // Preview feedback when the user releases the slider
                        previewFeedback(intensity: value.wrappedValue)
                    }
                }

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

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
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
