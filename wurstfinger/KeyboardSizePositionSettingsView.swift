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
    @StateObject private var previewViewModel = KeyboardViewModel(shouldPersistSettings: false)

    var body: some View {
        // Calculate preview height based on scale
        let keyHeight = 54.0 * (1.5 / previewViewModel.keyAspectRatio)
        let baseHeight = (keyHeight * 4) + (8 * 3) + (10 * 2)
        let scaledHeight = baseHeight * scale
        let previewHeight = min(400, max(100, scaledHeight))

        VStack(spacing: 20) {
            // Keyboard Preview
            VStack(spacing: 12) {
                Text("Preview")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GeometryReader { geometry in
                    ZStack(alignment: .top) {
                        Color(.systemGray6)

                        KeyboardRootView(viewModel: previewViewModel, scaleAnchor: .top, frameAlignment: .top, overrideWidth: geometry.size.width)
                            .id("\(previewViewModel.keyboardScale)-\(previewViewModel.keyboardHorizontalPosition)")
                            .onChange(of: scale) { oldValue, newValue in
                                previewViewModel.keyboardScale = newValue
                            }
                            .onChange(of: position) { oldValue, newValue in
                                previewViewModel.keyboardHorizontalPosition = newValue
                            }
                            .onAppear {
                                previewViewModel.keyboardScale = scale
                                previewViewModel.keyboardHorizontalPosition = position
                            }
                    }
                }
                .frame(height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .animation(.easeInOut(duration: 0.2), value: scale)
                .animation(.easeInOut(duration: 0.2), value: position)
            }
            .padding(.horizontal, 16)

            // Scale Slider
            VStack(spacing: 16) {
                HStack {
                    Text("Keyboard Scale")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(scale * 100))%")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
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
                    Text(positionLabel(for: position))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
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
}

#Preview {
    NavigationStack {
        KeyboardSizePositionSettingsView(scale: .constant(0.7), position: .constant(0.5))
    }
}
