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
                        isActive: languageSettings.selectedLanguageId == language.id,
                        onTap: {
                            if languageSettings.isLanguageEnabled(language) {
                                languageSettings.selectLanguage(language)
                            } else {
                                languageSettings.toggleLanguage(language)
                                languageSettings.selectLanguage(language)
                            }
                        },
                        onToggle: {
                            if !languageSettings.toggleLanguage(language) {
                                showLastLanguageAlert = true
                            }
                        }
                    )
                }
            } footer: {
                if languageSettings.hasMultipleLanguages {
                    Text("Swipe right on the globe key to switch languages.")
                }
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
    let isActive: Bool
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Button(action: onToggle) {
                    Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isEnabled ? .accentColor : .secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(language.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text("MessagEase Layout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isActive {
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .fontWeight(.medium)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSelectionView()
    }
}
