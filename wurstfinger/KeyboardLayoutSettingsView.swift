//
//  KeyboardLayoutSettingsView.swift
//  wurstfinger
//
//  Combined page for key shape, keyboard width and horizontal position —
//  the three values that together define the keyboard geometry. Replaces
//  the former separate Aspect Ratio and Size & Position pages.
//

import SwiftUI

struct KeyboardLayoutSettingsView: View {
    @Binding var aspectRatio: Double
    @Binding var scale: Double
    @Binding var position: Double

    @State private var showResetConfirmation = false

    private var isFullWidth: Bool {
        scale >= 0.995
    }

    var body: some View {
        VStack(spacing: 16) {
            InteractiveKeyboardPreview(aspectRatio: $aspectRatio, scale: $scale, position: $position)
                .padding(.horizontal, 16)
                .padding(.top, 20)

            Form {
                keyShapeSection
                widthSection
                if !isFullWidth {
                    positionSection
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isFullWidth)
        }
        .navigationTitle("Size & Layout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    showResetConfirmation = true
                }
            }
        }
        .confirmationDialog(
            "Reset size and layout to their defaults?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                aspectRatio = DeviceLayoutUtils.defaultKeyAspectRatio
                scale = DeviceLayoutUtils.defaultKeyboardScale
                position = DeviceLayoutUtils.defaultKeyboardPosition
            }
        }
    }

    // MARK: - Key Shape

    /// Named aspect-ratio presets so most users never deal with raw numbers.
    private struct ShapePreset: Identifiable {
        let name: LocalizedStringKey
        let value: Double
        var id: Double {
            value
        }
    }

    private let shapePresets: [ShapePreset] = [
        ShapePreset(name: "Square", value: 1.0),
        ShapePreset(name: "Wide", value: 1.5),
        ShapePreset(name: "Golden", value: 1.62),
    ]

    private var keyShapeSection: some View {
        Section {
            HStack(spacing: 8) {
                ForEach(shapePresets) { preset in
                    presetChip(preset)
                }
            }
            .padding(.vertical, 4)

            VStack(spacing: 8) {
                Slider(value: $aspectRatio, in: 1.0 ... 1.62, step: 0.01)

                HStack {
                    Text("Square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Wider")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            HStack {
                Text("Key Shape")
                Spacer()
                Text(verbatim: "\(String(format: "%.2f", aspectRatio)):1")
                    .monospacedDigit()
            }
        } footer: {
            Text("Choose a preset or fine-tune the width-to-height ratio of the keys.")
        }
    }

    private func presetChip(_ preset: ShapePreset) -> some View {
        let isSelected = abs(aspectRatio - preset.value) < 0.005
        return Button {
            aspectRatio = preset.value
        } label: {
            Text(preset.name)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Width

    private var widthSection: some View {
        Section {
            VStack(spacing: 8) {
                Slider(value: $scale, in: 0.25 ... 1.0, step: 0.01)
                    .onChange(of: scale) { oldValue, newValue in
                        // Re-center when the keyboard becomes full width, so a
                        // stale offset cannot survive invisibly.
                        if newValue >= 1.0 && oldValue < 1.0 {
                            position = 0.5
                        }
                    }

                HStack {
                    Text("Compact")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Full Width")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            HStack {
                Text("Width")
                Spacer()
                Text(verbatim: "\(Int(scale * 100)) %")
                    .monospacedDigit()
            }
        } footer: {
            if isFullWidth {
                Text("Make the keyboard narrower to unlock horizontal positioning.")
            } else {
                Text("A narrower keyboard is easier to reach one-handed.")
            }
        }
    }

    // MARK: - Position

    private var positionSection: some View {
        Section {
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
        } header: {
            Text("Position")
        } footer: {
            Text("Move the keyboard toward one edge for one-handed typing.")
        }
    }
}

#Preview {
    NavigationStack {
        KeyboardLayoutSettingsView(
            aspectRatio: .constant(1.0),
            scale: .constant(0.7),
            position: .constant(0.5)
        )
    }
}
