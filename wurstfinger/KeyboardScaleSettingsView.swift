//
//  KeyboardScaleSettingsView.swift
//  wurstfinger
//
//  Created by Claas Flint on 28.10.25.
//

import SwiftUI

struct KeyboardScaleSettingsView: View {
    @Binding var scale: Double
    @StateObject private var previewViewModel = KeyboardViewModel(shouldPersistSettings: false)

    var body: some View {
        // Calculate preview height based on aspect ratio and scale
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

                ZStack {
                    Color(.systemGray6)

                    KeyboardRootView(viewModel: previewViewModel, scaleAnchor: .center, frameAlignment: .center)
                        .id(previewViewModel.keyboardScale)
                        .onChange(of: scale) { oldValue, newValue in
                            previewViewModel.keyboardScale = newValue
                        }
                        .onAppear {
                            previewViewModel.keyboardScale = scale
                        }
                }
                .frame(height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .animation(.easeInOut(duration: 0.2), value: scale)
            }
            .padding(.horizontal, 16)

            // Slider Section
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

            Spacer()
        }
        .padding(.vertical, 20)
        .navigationTitle("Keyboard Scale")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        KeyboardScaleSettingsView(scale: .constant(1.0))
    }
}
