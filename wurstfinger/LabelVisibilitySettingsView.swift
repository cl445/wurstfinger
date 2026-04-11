//
//  LabelVisibilitySettingsView.swift
//  wurstfinger
//
//  Lets the user hide categories of key labels to practice the
//  keyboard layout from memory.
//

import SwiftUI

struct LabelVisibilitySettingsView: View {
    @AppStorage(SettingsKey.hideLetters.rawValue, store: SharedDefaults.store)
    private var hideLetters = false

    @AppStorage(SettingsKey.hideStandardSymbols.rawValue, store: SharedDefaults.store)
    private var hideStandardSymbols = false

    @AppStorage(SettingsKey.hideExtraSymbols.rawValue, store: SharedDefaults.store)
    private var hideExtraSymbols = false

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

            Form {
                Section {
                    Toggle("Show Letters", isOn: Binding(
                        get: { !hideLetters },
                        set: { hideLetters = !$0 }
                    ))

                    Toggle("Show Standard Symbols", isOn: Binding(
                        get: { !hideStandardSymbols },
                        set: { hideStandardSymbols = !$0 }
                    ))

                    Toggle("Show Extra Symbols", isOn: Binding(
                        get: { !hideExtraSymbols },
                        set: { hideExtraSymbols = !$0 }
                    ))
                } footer: {
                    Text("Hide labels to practice the layout from memory. Numbers and control keys are always visible.")
                }
            }
        }
        .navigationTitle("Label Visibility")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LabelVisibilitySettingsView()
    }
}
