import SwiftUI

struct HapticSettingsView: View {
    @AppStorage(KeyboardViewModel.hapticTapIntensityKey, store: SharedDefaults.store)
    private var tapIntensity = Double(KeyboardViewModel.defaultTapIntensity)

    @AppStorage(KeyboardViewModel.hapticModifierIntensityKey, store: SharedDefaults.store)
    private var modifierIntensity = Double(KeyboardViewModel.defaultModifierIntensity)

    @AppStorage(KeyboardViewModel.hapticDragIntensityKey, store: SharedDefaults.store)
    private var dragIntensity = Double(KeyboardViewModel.defaultDragIntensity)

    @AppStorage("hapticEnabled", store: SharedDefaults.store)
    private var hapticEnabled = true

    @AppStorage("keyAspectRatio", store: SharedDefaults.store)
    private var previewAspectRatio = 1.0

    @AppStorage("keyboardScale", store: SharedDefaults.store)
    private var previewScale = 1.0

    @AppStorage("keyboardHorizontalPosition", store: SharedDefaults.store)
    private var previewPosition = 0.5

    var body: some View {
        VStack(spacing: 20) {
            // Keyboard Preview
            InteractiveKeyboardPreview(aspectRatio: $previewAspectRatio, scale: $previewScale, position: $previewPosition)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 24) {
                    // Global Toggle
                    VStack(spacing: 8) {
                        Toggle("Haptic Feedback", isOn: $hapticEnabled)
                            .font(.headline)
                        
                        Text("Enable or disable all haptic feedback vibrations.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)

                    if hapticEnabled {
                        Divider()
                            .padding(.horizontal, 16)

                        // Sliders
                        VStack(spacing: 24) {
                            hapticControl(title: "Tap Feedback",
                                          value: $tapIntensity,
                                          description: "Applies when you press letters or utility buttons.")

                            hapticControl(title: "Modifier Feedback",
                                          value: $modifierIntensity,
                                          description: "Applies when you press Shift, Symbols, or other modifier keys.")

                            hapticControl(title: "Drag Feedback",
                                          value: $dragIntensity,
                                          description: "Applies when you drag the Space or Delete key to move the cursor or delete text.")
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 20)
        .navigationTitle("Haptics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    tapIntensity = Double(KeyboardViewModel.defaultTapIntensity)
                    modifierIntensity = Double(KeyboardViewModel.defaultModifierIntensity)
                    dragIntensity = Double(KeyboardViewModel.defaultDragIntensity)
                    hapticEnabled = true
                }
            }
        }
    }

    private let sliderRange: ClosedRange<Double> = 0...1
    private let sliderStep: Double = 0.05

    @ViewBuilder
    private func hapticControl(title: String,
                               value: Binding<Double>,
                               description: String) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                TextField("Value", value: value, formatter: NumberFormatter.decimalFormatter)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }

            VStack(spacing: 8) {
                Slider(value: value, in: sliderRange, step: sliderStep) { editing in
                    if !editing {
                        // Trigger feedback when user releases the slider
                        let generator = UIImpactFeedbackGenerator(style: .rigid)
                        generator.prepare()
                        generator.impactOccurred(intensity: value.wrappedValue)
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
}


