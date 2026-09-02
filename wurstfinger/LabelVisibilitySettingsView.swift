//
//  LabelVisibilitySettingsView.swift
//  wurstfinger
//
//  Lets the user hide categories of key labels to practice the keyboard layout
//  from memory.
//

import SwiftUI

struct LabelVisibilitySettingsView: View {
    @AppStorage(SettingsKey.areLetterLabelsHidden.rawValue, store: SharedDefaults.store)
    private var areLetterLabelsHidden = false

    @AppStorage(SettingsKey.areStandardSymbolLabelsHidden.rawValue, store: SharedDefaults.store)
    private var areStandardSymbolLabelsHidden = false

    @AppStorage(SettingsKey.areExtraSymbolLabelsHidden.rawValue, store: SharedDefaults.store)
    private var areExtraSymbolLabelsHidden = false

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

            Form {
                Section {
                    Toggle("Show Letters", isOn: Binding(
                        get: { !areLetterLabelsHidden },
                        set: { areLetterLabelsHidden = !$0 }
                    ))

                    Toggle("Show Standard Symbols", isOn: Binding(
                        get: { !areStandardSymbolLabelsHidden },
                        set: { areStandardSymbolLabelsHidden = !$0 }
                    ))

                    Toggle("Show Extra Symbols", isOn: Binding(
                        get: { !areExtraSymbolLabelsHidden },
                        set: { areExtraSymbolLabelsHidden = !$0 }
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
