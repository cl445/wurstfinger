//
//  InteractiveKeyboardPreview.swift
//  wurstfinger
//
//  Created by Claas Flint on 19.11.25.
//

import SwiftUI

struct InteractiveKeyboardPreview: View {
    @Binding var aspectRatio: Double
    @Binding var scale: Double
    @Binding var position: Double
    
    @StateObject private var previewViewModel = KeyboardViewModel(shouldPersistSettings: false)
    @State private var previewText = ""

    init(aspectRatio: Binding<Double> = .constant(1.5),
         scale: Binding<Double> = .constant(1.0),
         position: Binding<Double> = .constant(0.5)) {
        self._aspectRatio = aspectRatio
        self._scale = scale
        self._position = position
    }

    private var previewHeight: CGFloat {
        // Calculate preview height based on aspect ratio and scale
        let baseHeight = KeyboardConstants.Calculations.baseHeight(aspectRatio: previewViewModel.keyAspectRatio)
        let scaledHeight = baseHeight * scale
        
        // Determine height constraints based on usage
        // If scaling is involved (size settings), we clamp between min/max
        // If only aspect ratio changes (aspect settings), we allow it to grow naturally but cap it
        if scale < 0.99 {
             return min(KeyboardConstants.Preview.maxHeight, max(KeyboardConstants.Preview.minHeight, scaledHeight))
        } else {
            // For aspect ratio view, we want to show the full height relative to width
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
                if !previewText.isEmpty {
                    Button("Clear") {
                        previewText = ""
                    }
                    .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !previewText.isEmpty {
                Text(previewText)
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

            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    Color(.systemGray6)

                    KeyboardRootView(
                        viewModel: previewViewModel,
                        scaleAnchor: scale < 0.99 ? .top : .center,
                        frameAlignment: scale < 0.99 ? .top : .center,
                        overrideWidth: geometry.size.width
                    )

                    .onChange(of: aspectRatio) { oldValue, newValue in
                        previewViewModel.keyAspectRatio = newValue
                    }
                    .onChange(of: scale) { oldValue, newValue in
                        previewViewModel.keyboardScale = newValue
                    }
                    .onChange(of: position) { oldValue, newValue in
                        previewViewModel.keyboardHorizontalPosition = newValue
                    }
                    .onAppear {
                        previewViewModel.keyAspectRatio = aspectRatio
                        previewViewModel.keyboardScale = scale
                        previewViewModel.keyboardHorizontalPosition = position
                        
                        previewViewModel.bindActionHandler { action in
                            switch action {
                            case .insert(let text):
                                previewText += text
                            case .deleteBackward:
                                if !previewText.isEmpty {
                                    previewText.removeLast()
                                }
                            case .space:
                                previewText += " "
                            case .newline:
                                previewText += "\n"
                            default:
                                break
                            }
                        }
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
