//
//  InteractiveKeyboardPreview.swift
//  wurstfinger
//
//  Created by Claas Flint on 19.11.25.
//

import Combine
import SwiftUI

/// A simple in-memory text target that captures pipeline output
/// for the interactive preview.
private class PreviewTextTarget: TextInputTarget, ObservableObject {
    @Published var text: String = ""
    var documentContextBeforeInput: String? {
        text
    }

    var documentContextAfterInput: String? {
        nil
    }

    var selectedText: String? {
        nil
    }

    var hasFullAccess: Bool {
        false
    }

    func deleteBackward() {
        if !text.isEmpty {
            text.removeLast()
        }
    }

    func insertText(_ text: String) {
        self.text += text
    }

    func adjustTextPosition(byCharacterOffset _: Int) {}
}

struct InteractiveKeyboardPreview: View {
    @Binding var aspectRatio: Double
    @Binding var scale: Double
    @Binding var position: Double

    @StateObject private var previewViewModel = KeyboardViewModel(shouldPersistSettings: false)
    @StateObject private var previewTarget = PreviewTextTarget()

    init(
        aspectRatio: Binding<Double> = .constant(1.5),
        scale: Binding<Double> = .constant(1.0),
        position: Binding<Double> = .constant(0.5)
    ) {
        _aspectRatio = aspectRatio
        _scale = scale
        _position = position
    }

    private var previewHeight: CGFloat {
        // Calculate preview height based on aspect ratio and scale
        let baseHeight = KeyboardConstants.Calculations.baseHeight(aspectRatio: previewViewModel.keyAspectRatio)
        let scaledHeight = baseHeight * scale

        // Determine height constraints based on usage
        if scale < 0.99 {
            return min(KeyboardConstants.Preview.maxHeight, max(KeyboardConstants.Preview.minHeight, scaledHeight))
        } else {
            let keyHeight = 54.0 * (1.5 / aspectRatio)
            let totalHeight = (keyHeight * 4) + (8 * 3) + (10 * 2)
            return min(400, max(200, totalHeight))
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
                if !previewTarget.text.isEmpty {
                    Button("Clear") {
                        previewTarget.text = ""
                    }
                    .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !previewTarget.text.isEmpty {
                Text(previewTarget.text)
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            } else {
                Text("Type on the keyboard below")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }

            GeometryReader { _ in
                ZStack(alignment: .top) {
                    Color(.systemGray6)

                    DataDrivenKeyboardRootView(viewModel: previewViewModel)

                        .onChange(of: aspectRatio) { _, newValue in
                            previewViewModel.keyAspectRatio = newValue
                        }
                        .onChange(of: scale) { _, newValue in
                            previewViewModel.keyboardScale = newValue
                        }
                        .onChange(of: position) { _, newValue in
                            previewViewModel.keyboardHorizontalPosition = newValue
                        }
                        .onAppear {
                            previewViewModel.keyAspectRatio = aspectRatio
                            previewViewModel.keyboardScale = scale
                            previewViewModel.keyboardHorizontalPosition = position

                            // Wire up preview text target and load definition
                            previewViewModel.bindTextInputTarget(previewTarget)
                            let languageId = SharedDefaults.store.string(
                                forKey: SettingsKey.selectedLanguageId.rawValue
                            ) ?? LanguageSettings.detectSystemLanguage()
                            previewViewModel.loadDefinition(for: languageId)
                        }
                }
            }
            .frame(height: previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 0.2), value: aspectRatio)
            .animation(.easeInOut(duration: 0.2), value: scale)
            .animation(.easeInOut(duration: 0.2), value: position)
        }
    }
}

#Preview {
    InteractiveKeyboardPreview()
        .padding()
}
