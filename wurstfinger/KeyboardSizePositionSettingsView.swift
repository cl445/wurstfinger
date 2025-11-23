//
//  KeyboardSizePositionSettingsView.swift
//  wurstfinger
//
//  Created by Claas Flint on 29.10.25.
//

import SwiftUI

struct KeyboardSizePositionSettingsView: View {
    @Binding var scale: Double
    @Binding var position: Double
    
    @AppStorage("keyAspectRatio", store: SharedDefaults.store)
    private var keyAspectRatio = 1.0

    var body: some View {
        VStack(spacing: 20) {
            // Keyboard Preview
            InteractiveKeyboardPreview(aspectRatio: $keyAspectRatio, scale: $scale, position: $position)
                .padding(.horizontal, 16)

            // Scale Slider
            VStack(spacing: 16) {
                HStack {
                    Text("Keyboard Scale")
                        .font(.headline)
                    Spacer()
                    Spacer()
                    TextField("Value", value: $scale, formatter: NumberFormatter.decimalFormatter)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                VStack(spacing: 8) {
                    Slider(value: $scale, in: 0.3...1.0, step: 0.01)
                        .onChange(of: scale) { oldValue, newValue in
                            // Reset position to center when scale reaches 100%
                            if newValue >= 1.0 && oldValue < 1.0 {
                                position = 0.5
                            }
                        }

                    HStack {
                        Text("30%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Compact")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Full Width")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Scale the keyboard to make it smaller. At 100% it fills the full width, at 30% it's much more compact.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)

            // Position Slider (only enabled when scale < 1.0)
            VStack(spacing: 16) {
                HStack {
                    Text("Horizontal Position")
                        .font(.headline)
                        .foregroundColor(scale < 1.0 ? .primary : .secondary)
                    Spacer()
                    TextField("Value", value: $position, formatter: NumberFormatter.decimalFormatter)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .disabled(scale >= 1.0)
                }

                VStack(spacing: 8) {
                    Slider(value: $position, in: 0.0...1.0, step: 0.01)
                        .disabled(scale >= 1.0)

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

                if scale >= 1.0 {
                    Text("Position is only available when scale is below 100%.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Adjust the horizontal position of the keyboard when it's scaled below 100%.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.2), value: scale >= 1.0)

            Spacer()
        }
        .padding(.vertical, 20)
        .navigationTitle("Size & Position")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    scale = DeviceLayoutUtils.defaultKeyboardScale
                    position = DeviceLayoutUtils.defaultKeyboardPosition
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        KeyboardSizePositionSettingsView(scale: .constant(0.7), position: .constant(0.5))
    }
}
