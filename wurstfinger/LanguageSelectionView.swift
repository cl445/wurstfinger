//
//  LanguageSelectionView.swift
//  Wurstfinger
//
//  Created by Claas Flint on 06.11.25.
//

import SwiftUI

struct LanguageSelectionView: View {
    @StateObject private var languageSettings = LanguageSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(LanguageConfig.allLanguages) { language in
            Button {
                languageSettings.selectLanguage(language)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(language.name)
                            .font(.body)
                            .foregroundColor(.primary)

                        Text("MessagEase Layout")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if languageSettings.selectedLanguageId == language.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .navigationTitle("Keyboard Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LanguageSelectionView()
    }
}
