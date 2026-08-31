//
//  KeyboardSizePositionSettingsView.swift
//  wurstfinger
//
//  Created by Claas Flint on 29.10.25.
//

import SwiftUI

struct KeyboardSizePositionSettingsView: View {
    /// Keyboard width wish in points (the persisted value). The slider and
    /// text field display it as a percentage of the device-class default.
    @Binding var width: Double
    @Binding var position: Double

    @AppStorage(SettingsKey.keyAspectRatio.rawValue, store: SharedDefaults.store)
    private var keyAspectRatio = DeviceLayout.defaultKeyAspectRatio

    /// Slider range as percent of the device default (270 pt on iPhone):
    /// 35 % ≈ 95 pt keeps the old 25 %-of-screen minimum reachable, 145 %
    /// ≈ 392 pt covers a full iPhone width. Round values on purpose.
    private static let minPercent: Double = 35
    private static let maxPercent: Double = 145

    /// Percent view onto the point-based wish width.
    private var sizePercent: Binding<Double> {
        Binding(
            get: { width / DeviceLayout.defaultKeyboardWidth * 100 },
            set: { width = $0 / 100 * DeviceLayout.defaultKeyboardWidth }
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            // Keyboard Preview
            InteractiveKeyboardPreview(aspectRatio: $keyAspectRatio, width: $width, position: $position)
                .padding(.horizontal, 16)

            // The controls scroll below the pinned preview, like the other
            // preview screens (Style, Haptics). The preview's height follows the
            // configured keyboard size, so with a large keyboard, a wordy
            // translation or a large Dynamic Type size the sliders and their
            // explanations stop fitting: in a plain VStack SwiftUI compressed
            // them instead, and the size explainer below was silently cut to a
            // single truncated line in every language. Keeping the preview
            // *outside* the ScrollView also keeps its typing gestures from
            // competing with the scroll gesture.
            ScrollView {
                VStack(spacing: 20) {
                    sizeControls
                    positionControls
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 20)
        .navigationTitle("Size & Position")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    width = DeviceLayout.defaultKeyboardWidth
                    position = DeviceLayout.defaultKeyboardPosition
                }
            }
        }
    }

    // MARK: - Controls

    private var sizeControls: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Keyboard Size")
                    .font(.headline)
                Spacer()
                Spacer()
                TextField(
                    "Value",
                    value: sizePercent,
                    formatter: NumberFormatter.decimalFormatter(
                        minimum: Self.minPercent, maximum: Self.maxPercent
                    )
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
            }

            VStack(spacing: 8) {
                Slider(value: sizePercent, in: Self.minPercent ... Self.maxPercent, step: 1)

                HStack {
                    Text("35%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("145%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Size relative to the standard keyboard. It stays the same in every orientation; if it does not fit, it shrinks to the screen.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Take the full wrapped height even when the proposal is
                // tight, so the sentence can never be cut to one line again.
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
    }

    private var positionControls: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Horizontal Position")
                    .font(.headline)
                Spacer()
                TextField("Value", value: $position, formatter: NumberFormatter.decimalFormatter(minimum: 0.0, maximum: 1.0))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }

            VStack(spacing: 8) {
                Slider(value: $position, in: 0.0 ... 1.0, step: 0.01)

                HStack {
                    Text("Left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Center")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Adjust the horizontal position of the keyboard when it is narrower than the screen.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Shorter than the size explainer, so it still fitted — but
                // it wraps to two lines in the longer languages and sits in
                // the same tight stack, so it gets the same guarantee.
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    NavigationStack {
        KeyboardSizePositionSettingsView(width: .constant(270), position: .constant(0.5))
    }
}
