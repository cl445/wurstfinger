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

    var body: some View {
        VStack(spacing: 16) {
            InteractiveKeyboardPreview(aspectRatio: $previewAspectRatio, scale: $previewScale, position: $previewPosition)
                .padding(.horizontal, 16)
                .padding(.top, 20)

            Form {
                Section {
                    ForEach(KeyboardStyle.allCases, id: \.self) { style in
                        styleOption(style)
                    }
                } header: {
                    Text("Visual Style")
                } footer: {
                    if keyboardStyleRaw == KeyboardStyle.liquidGlass.rawValue {
                        if #unavailable(iOS 26.0) {
                            Text("Liquid Glass requires iOS 26 or later. The classic style will be used on this device.")
                        }
                    }
                }
            }
        }
        .navigationTitle("Style")
        .navigationBarTitleDisplayMode(.inline)
    }

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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(keyboardStyleRaw == style.rawValue ? [.isSelected] : [])
    }
}

#Preview {
    NavigationStack {
        StyleSettingsView()
    }
}
