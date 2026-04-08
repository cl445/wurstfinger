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

    @State private var isActive = false
    @State private var dragStarted = false
    @State private var hasDragged = false
    @State private var lastTranslation: CGSize = .zero
    // Discrete mode: track peak displacement and final position
    @State private var maxDisplacementX: CGFloat = 0
    @State private var maxDisplacementSign: Int = 0

    var body: some View {
        KeyCap(
            height: keyHeight,
            // Don't apply aspectRatio to space bar - it spans multiple grid columns
            // and should fill the available width from .gridCellColumns()
            aspectRatio: nil,
            background: isActive ? Color(.tertiarySystemFill) : Color(.secondarySystemBackground),
            fontSize: KeyboardConstants.FontSizes.keyLabel
        ) {
            Color.clear
        }
        .contentShape(Rectangle().inset(by: -KeyboardTouchArea.padding))
        .accessibilityLabel(Text("Space"))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !dragStarted {
                        dragStarted = true
                        viewModel.feedbackTap()
                        viewModel.beginSpaceDrag()
                    }

                    let currentX = value.translation.width

                    if viewModel.cursorMovementStyle == .continuous {
                        let deltaX = currentX - lastTranslation.width
                        viewModel.updateSpaceDrag(deltaX: deltaX)
                    }

                    // Track peak displacement for discrete mode
                    if abs(currentX) > abs(maxDisplacementX) {
                        maxDisplacementX = currentX
                        maxDisplacementSign = currentX > 0 ? 1 : -1
                    }

                    lastTranslation = value.translation

                    if !hasDragged, abs(currentX) >= KeyboardConstants.SpaceGestures.dragActivationThreshold {
                        hasDragged = true
                    }

                    isActive = true
                }
                .onEnded { value in
                    if dragStarted {
                        viewModel.endSpaceDrag()
                    }

                    if !hasDragged {
                        viewModel.handleSpace()
                    } else if viewModel.cursorMovementStyle == .discrete {
                        classifyDiscreteGesture(finalX: value.translation.width)
                    }

                    resetGestureState()
                }
        )
    }

    private func classifyDiscreteGesture(finalX: CGFloat) {
        let forward = maxDisplacementSign > 0
        let returnRatio = abs(maxDisplacementX) > 0
            ? abs(finalX) / abs(maxDisplacementX)
            : 1.0

        if returnRatio < KeyboardConstants.SpaceGestures.returnSwipeThreshold {
            // Finger returned near start → word movement
            viewModel.handleDiscreteSpaceReturnSwipe(forward: forward)
        } else {
            // Finger stayed away → character movement
            viewModel.handleDiscreteSpaceSwipe(forward: forward)
        }
    }

    private func resetGestureState() {
        isActive = false
        dragStarted = false
        hasDragged = false
        lastTranslation = .zero
        maxDisplacementX = 0
        maxDisplacementSign = 0
    }
}
