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
    private var previewAspectRatio = DeviceLayout.defaultKeyAspectRatio

    @AppStorage(SettingsKey.keyboardWidthPoints.rawValue, store: SharedDefaults.store)
    private var previewWidth = DeviceLayout.defaultKeyboardWidth

    @AppStorage(SettingsKey.keyboardHorizontalPosition.rawValue, store: SharedDefaults.store)
    private var previewPosition = DeviceLayout.defaultKeyboardPosition

    var body: some View {
        VStack(spacing: 16) {
            InteractiveKeyboardPreview(aspectRatio: $previewAspectRatio, width: $previewWidth, position: $previewPosition)
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
                            Text("Liquid Glass is designed for iOS 26 and later. On earlier versions a simplified translucent style is used.")
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

extension KeyboardStyle {
    /// User-facing style name. Lives in the host app target: the extension's
    /// own catalog carries only the strings the keyboard itself displays, so a
    /// settings-only name must not be looked up from extension code.
    var displayName: String {
        switch self {
        case .classic: String(localized: "Classic")
        case .liquidGlass: String(localized: "Liquid Glass")
        }
    }

    /// One-line explanation shown under the style name.
    var description: String {
        switch self {
        case .classic: String(localized: "Traditional opaque keys")
        case .liquidGlass: String(localized: "Transparent glass effect (iOS 26+)")
        }
    }
}

#Preview {
    NavigationStack {
        StyleSettingsView()
    }
}
