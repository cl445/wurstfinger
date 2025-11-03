//
//  KeyboardPositionSettingsView.swift
//  wurstfinger
//
//  Created by Claas Flint on 29.10.25.
//

import SwiftUI

struct KeyboardPositionSettingsView: View {
    @Binding var position: Double
    @StateObject private var previewViewModel = KeyboardViewModel(shouldPersistSettings: false)

    var body: some View {
        // Calculate preview height based on scale (70%)
        let keyHeight = 54.0 * (1.5 / previewViewModel.keyAspectRatio)
        let baseHeight = (keyHeight * 4) + (8 * 3) + (10 * 2)
        let scaledHeight = baseHeight * previewViewModel.keyboardScale
        let previewHeight = min(300, max(150, scaledHeight))

        VStack(spacing: 20) {
            // Keyboard Preview
            VStack(spacing: 12) {
                Text("Preview")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack(alignment: .bottom) {
                    Color(.systemGray6)

                    KeyboardRootView(viewModel: previewViewModel, scaleAnchor: .bottom, frameAlignment: .bottom)
                        .id(previewViewModel.keyboardHorizontalPosition)
                        .onChange(of: position) { oldValue, newValue in
                            previewViewModel.keyboardHorizontalPosition = newValue
                        }
                        .onAppear {
                            previewViewModel.keyboardScale = 0.7 // Keep preview narrow for clarity
                            previewViewModel.keyboardHorizontalPosition = position
                        }
                }
                .frame(height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .animation(.easeInOut(duration: 0.2), value: position)
            }
            .padding(.horizontal, 16)

            // Slider Section
            VStack(spacing: 16) {
                HStack {
                    Text("Horizontal Position")
                        .font(.headline)
                    Spacer()
                    Text(positionLabel(for: position))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 8) {
                    Slider(value: $position, in: 0.0...1.0, step: 0.01)

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

                Text("Adjust the horizontal position of the keyboard. Works best with keyboard scale below 100%.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.vertical, 20)
        .navigationTitle("Keyboard Position")
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
        KeyboardPositionSettingsView(position: .constant(0.5))
    }
}
