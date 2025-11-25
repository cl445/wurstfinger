//
//  SpaceKeyButton.swift
//  Wurstfinger
//
//  Space key button with drag gestures for cursor movement and text selection
//

import SwiftUI

/// Space bar button with specialized drag gesture handling for cursor movement
struct SpaceKeyButton: View {
    let viewModel: KeyboardViewModel
    let keyHeight: CGFloat
    let aspectRatio: CGFloat

    @State private var isActive = false
    @State private var dragStarted = false
    @State private var hasDragged = false
    @State private var lastTranslation: CGSize = .zero

    var body: some View {
        KeyCap(
            height: keyHeight,
            aspectRatio: aspectRatio,
            background: isActive ? Color(.tertiarySystemFill) : Color(.secondarySystemBackground),
            fontSize: KeyboardConstants.FontSizes.keyLabel
        ) {
            Color.clear
        }
        .accessibilityLabel(Text("Space"))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !dragStarted {
                        dragStarted = true
                        viewModel.beginSpaceDrag()
                    }

                    let deltaX = value.translation.width - lastTranslation.width
                    viewModel.updateSpaceDrag(deltaX: deltaX)

                    lastTranslation = value.translation

                    if !hasDragged, abs(value.translation.width) >= KeyboardConstants.SpaceGestures.dragActivationThreshold {
                        hasDragged = true
                    }

                    isActive = true
                }
                .onEnded { _ in
                    if dragStarted {
                        viewModel.endSpaceDrag()
                    }

                    if !hasDragged {
                        viewModel.handleSpace()
                    }

                    resetGestureState()
                }
        )
    }

    private func resetGestureState() {
        isActive = false
        dragStarted = false
        hasDragged = false
        lastTranslation = .zero
    }
}
