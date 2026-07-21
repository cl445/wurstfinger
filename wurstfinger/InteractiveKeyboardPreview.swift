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
    /// Keyboard width wish in points (mirrors the persisted setting).
    @Binding var width: Double
    @Binding var position: Double

    @StateObject private var previewViewModel = KeyboardViewModel(shouldPersistSettings: false)
    @StateObject private var previewTarget = PreviewTextTarget()

    init(
        aspectRatio: Binding<Double> = .constant(1.0),
        width: Binding<Double> = .constant(DeviceLayoutUtils.defaultKeyboardWidth),
        position: Binding<Double> = .constant(0.5)
    ) {
        _aspectRatio = aspectRatio
        _width = width
        _position = position
    }

    private var previewHeight: CGFloat {
        // Same metrics the keyboard itself renders from, resolved against
        // the preview's container (the parents inset it 16 pt per side), so
        // the frame height always matches the rendered content height.
        let containerWidth = DeviceLayoutUtils.screenBounds.width - 32
        let metrics = previewViewModel.layoutMetrics(forContainerWidth: containerWidth)
        return KeyboardConstants.Preview.frameHeight(forContentHeight: metrics.totalHeight)
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

            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    Color(.systemGray6)

                    // The proxy width makes the preview lay out against its
                    // real container instead of the full screen width, so the
                    // fit-clamp and horizontal position match the extension.
                    DataDrivenKeyboardRootView(viewModel: previewViewModel, overrideWidth: proxy.size.width)
                        .onChange(of: aspectRatio) { _, newValue in
                            previewViewModel.keyAspectRatio = newValue
                        }
                        .onChange(of: width) { _, newValue in
                            previewViewModel.keyboardWidth = newValue
                        }
                        .onChange(of: position) { _, newValue in
                            previewViewModel.keyboardHorizontalPosition = newValue
                        }
                        .onAppear {
                            previewViewModel.keyAspectRatio = aspectRatio
                            previewViewModel.keyboardWidth = width
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
            .animation(.easeInOut(duration: 0.2), value: width)
            .animation(.easeInOut(duration: 0.2), value: position)
        }
    }
}

#Preview {
    InteractiveKeyboardPreview()
        .padding()
}
