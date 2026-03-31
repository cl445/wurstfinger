//
//  StyleSettingsView.swift
//  wurstfinger
//
//  Visual style settings for the keyboard appearance
//

import SwiftUI

struct StyleSettingsView: View {
    @AppStorage(SettingsKey.keyboardStyle.rawValue, store: SharedDefaults.store)
    private var keyboardStyleRaw = KeyboardStyle.classic.rawValue

    @AppStorage(SettingsKey.keyAspectRatio.rawValue, store: SharedDefaults.store)
    private var previewAspectRatio = DeviceLayoutUtils.defaultKeyAspectRatio

    @AppStorage(SettingsKey.keyboardScale.rawValue, store: SharedDefaults.store)
    private var previewScale = DeviceLayoutUtils.defaultKeyboardScale

    @AppStorage(SettingsKey.keyboardHorizontalPosition.rawValue, store: SharedDefaults.store)
    private var previewPosition = DeviceLayoutUtils.defaultKeyboardPosition

    private var keyboardStyle: KeyboardStyle {
        get { KeyboardStyle(rawValue: keyboardStyleRaw) ?? .classic }
        set { keyboardStyleRaw = newValue.rawValue }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Keyboard Preview
            InteractiveKeyboardPreview(aspectRatio: $previewAspectRatio, scale: $previewScale, position: $previewPosition)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 24) {
                    // Style Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Visual Style")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        ForEach(KeyboardStyle.allCases, id: \.self) { style in
                            styleOption(style)
                        }

                        if keyboardStyleRaw == KeyboardStyle.liquidGlass.rawValue {
                            if #unavailable(iOS 26.0) {
                                Text("Liquid Glass requires iOS 26 or later. The classic style will be used on this device.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 20)
        .navigationTitle("Style")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func styleOption(_ style: KeyboardStyle) -> some View {
        Button {
            keyboardStyleRaw = style.rawValue
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.displayName)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(style.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if keyboardStyleRaw == style.rawValue {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(keyboardStyleRaw == style.rawValue ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

#Preview {
    NavigationStack {
        StyleSettingsView()
    }
}
