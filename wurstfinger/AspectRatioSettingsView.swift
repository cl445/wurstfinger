//
//  AspectRatioSettingsView.swift
//  wurstfinger
//
//  Created by Claas Flint on 28.10.25.
//

import SwiftUI

struct AspectRatioSettingsView: View {
    @Binding var aspectRatio: Double
    @StateObject private var previewViewModel: KeyboardViewModel = {
        let vm = KeyboardViewModel()
        vm.keyAspectRatio = 1.5
        return vm
    }()

    var body: some View {
        // Calculate preview height based on aspect ratio
        // Same formula as in KeyboardRootView
        let keyHeight = 54.0 * (1.5 / aspectRatio)
        let totalKeyboardHeight = (keyHeight * 4) + (8 * 3) + (10 * 2) // 4 rows, 3 spacings, 2 paddings
        let previewHeight = min(400, max(200, totalKeyboardHeight))

        VStack(spacing: 20) {
            // Keyboard Preview
            VStack(spacing: 12) {
                Text("Preview")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Color(.systemGray6)

                    KeyboardRootView(viewModel: previewViewModel, scaleAnchor: .center, frameAlignment: .center)
                        .id(previewViewModel.keyAspectRatio)
                        .onChange(of: aspectRatio) { oldValue, newValue in
                            previewViewModel.keyAspectRatio = newValue
                        }
                        .onAppear {
                            previewViewModel.keyAspectRatio = aspectRatio
                        }
                }
                .frame(height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .animation(.easeInOut(duration: 0.2), value: aspectRatio)
            }
            .padding(.horizontal, 16)

            // Slider Section
            VStack(spacing: 16) {
                HStack {
                    Text("Aspect Ratio")
                        .font(.headline)
                    Spacer()
                    Text("\(String(format: "%.2f", aspectRatio)):1")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 8) {
                    Slider(value: $aspectRatio, in: 1.0...1.62, step: 0.01)

                    HStack {
                        Text("1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("1.5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Default")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("1.62")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Golden")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Adjust the width-to-height ratio of the keys. 1.0 creates square keys, 1.5 is the default appearance, and 1.62 is the golden ratio (widest).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.vertical, 20)
        .navigationTitle("Key Aspect Ratio")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AspectRatioSettingsView(aspectRatio: .constant(1.5))
    }
}
