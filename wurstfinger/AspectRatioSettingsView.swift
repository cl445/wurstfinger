//
//  AspectRatioSettingsView.swift
//  wurstfinger
//
//  Created by Claas Flint on 28.10.25.
//

import SwiftUI

struct AspectRatioSettingsView: View {
    @Binding var aspectRatio: Double
    
    @AppStorage("keyboardScale", store: SharedDefaults.store)
    private var keyboardScale = 1.0

    @AppStorage("keyboardHorizontalPosition", store: SharedDefaults.store)
    private var keyboardHorizontalPosition = 0.5

    var body: some View {
        VStack(spacing: 20) {
            // Keyboard Preview
            InteractiveKeyboardPreview(aspectRatio: $aspectRatio, scale: $keyboardScale, position: $keyboardHorizontalPosition)
                .padding(.horizontal, 16)

            // Slider Section
            VStack(spacing: 16) {
                HStack {
                    Text("Aspect Ratio")
                        .font(.headline)
                    Spacer()
                    TextField("Value", value: $aspectRatio, formatter: NumberFormatter.decimalFormatter)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    aspectRatio = DeviceLayoutUtils.defaultKeyAspectRatio
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AspectRatioSettingsView(aspectRatio: .constant(1.5))
    }
}
