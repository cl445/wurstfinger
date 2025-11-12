import SwiftUI

struct HapticSettingsView: View {
    @AppStorage(KeyboardViewModel.hapticTapIntensityKey, store: SharedDefaults.store)
    private var tapIntensity = Double(KeyboardViewModel.defaultTapIntensity)

    @AppStorage(KeyboardViewModel.hapticModifierIntensityKey, store: SharedDefaults.store)
    private var modifierIntensity = Double(KeyboardViewModel.defaultModifierIntensity)

    @AppStorage(KeyboardViewModel.hapticDragIntensityKey, store: SharedDefaults.store)
    private var dragIntensity = Double(KeyboardViewModel.defaultDragIntensity)

    private let sliderRange: ClosedRange<Double> = 0...1
    private let sliderStep: Double = 0.01

    var body: some View {
        Form {
            hapticSection(title: "Tap Feedback",
                          value: $tapIntensity,
                          description: "Applies when you press letters or utility buttons.")

            hapticSection(title: "Modifier Feedback",
                          value: $modifierIntensity,
                          description: "Used for shift, globe, return, compose and other mode changes.")

            hapticSection(title: "Drag Feedback",
                          value: $dragIntensity,
                          description: "Controls the strength while dragging space or delete.",
                          footer: "Drag feedback is naturally a bit more pronounced so cursor and delete drags remain easy to feel.")
        }
        .navigationTitle("Haptics")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func hapticSection(title: String,
                               value: Binding<Double>,
                               description: String,
                               footer: String? = nil) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(spacing: 6) {
                    Slider(value: value, in: sliderRange, step: sliderStep)

                    HStack {
                        Text("Off")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formattedIntensity(value.wrappedValue))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text(title)
        } footer: {
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Slide to 0% to turn this feedback off.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formattedIntensity(_ value: Double) -> String {
        value <= 0.001 ? "Off" : "\(Int(round(value * 100)))%"
    }
}
