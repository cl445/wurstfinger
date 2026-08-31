//
//  LanguageSelectionView.swift
//  Wurstfinger
//
//  Created by Claas Flint on 06.11.25.
//

import SwiftUI

struct LanguageSelectionView: View {
    @StateObject private var languageSettings = LanguageSettings.shared
    @State private var showLastLanguageAlert = false

    var body: some View {
        List {
            Section {
                ForEach(LanguageConfig.allLanguages) { language in
                    LanguageRow(
                        language: language,
                        isEnabled: languageSettings.isLanguageEnabled(language),
                        isDefault: languageSettings.pinnedLanguageId == language.id,
                        onToggle: {
                            if !languageSettings.toggleLanguage(language) {
                                showLastLanguageAlert = true
                            }
                        },
                        onMakeDefault: {
                            languageSettings.pinLanguage(language)
                        }
                    )
                }
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "Tap a language to enable or disable it. Tap the star to choose the language the keyboard starts with. Swipe right on the globe key to switch languages while typing."
                )
            }
        }
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cannot Disable", isPresented: $showLastLanguageAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("At least one language must be enabled.")
        }
    }
}

private struct LanguageRow: View {
    let language: LanguageConfig
    let isEnabled: Bool
    let isDefault: Bool
    let onToggle: () -> Void
    let onMakeDefault: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isEnabled ? .accentColor : .secondary)
                        .imageScale(.large)

                    Text(language.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isEnabled
                    ? String(localized: "Disable \(language.name)")
                    : String(localized: "Enable \(language.name)")
            )
            .accessibilityValue(isEnabled ? String(localized: "Enabled") : String(localized: "Disabled"))

            if isEnabled {
                Button(action: onMakeDefault) {
                    Image(systemName: isDefault ? "star.fill" : "star")
                        .foregroundColor(isDefault ? .yellow : .secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Make \(language.name) the default language"))
                .accessibilityAddTraits(isDefault ? [.isSelected] : [])
            }
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSelectionView()
    }
}
