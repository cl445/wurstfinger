//
//  DeleteKeyButton.swift
//  Wurstfinger
//
//  Delete key button with progressive deletion, word swipes, and repeating deletion
//

import SwiftUI

/// Delete key button with specialized gestures for character/word deletion
struct DeleteKeyButton: View {
    let viewModel: KeyboardViewModel
    let keyHeight: CGFloat

    @State private var isActive = false
    @State private var dragStarted = false
    @State private var hasDragged = false
    @State private var isSliding = false
    @State private var lastTranslation: CGSize = .zero
    @State private var totalTranslation: CGSize = .zero
    @State private var isRepeating = false
    @State private var repeatTimer: Timer?
    @State private var repeatTriggered = false

    var body: some View {
        KeyCap(
            height: keyHeight,
            background: isActive ? Color(.tertiarySystemFill) : Color(.secondarySystemBackground),
            fontSize: KeyboardConstants.FontSizes.keyLabel
        ) {
            Image(systemName: "delete.left")
        }
        .accessibilityLabel(Text("Delete"))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if isRepeating {
                        stopRepeat()
                    }

                    if !dragStarted {
                        dragStarted = true
                    }

                    totalTranslation = value.translation

                    if !isSliding,
                       abs(totalTranslation.width) >= KeyboardConstants.DeleteGestures.slideActivationThreshold,
                       abs(totalTranslation.height) <= KeyboardConstants.DeleteGestures.verticalTolerance {
                        isSliding = true
                        hasDragged = true
                        viewModel.beginDeleteDrag()
                        lastTranslation = totalTranslation
                        return
                    }

                    if isSliding {
                        let deltaX = totalTranslation.width - lastTranslation.width
                        viewModel.updateDeleteDrag(deltaX: deltaX)
                        lastTranslation = totalTranslation
                    } else {
                        if abs(totalTranslation.width) >= KeyboardConstants.DeleteGestures.wordSwipeThreshold {
                            hasDragged = true
                        } else if abs(totalTranslation.width) >= KeyboardConstants.DeleteGestures.dragActivationThreshold {
                            hasDragged = true
                        }
                    }

                    lastTranslation = value.translation
                    isActive = true
                }
                .onEnded { _ in
                    stopRepeat()

                    if isSliding {
                        viewModel.endDeleteDrag()
                    } else {
                        let translation = totalTranslation
                        let isWordSwipe = translation.width <= -KeyboardConstants.DeleteGestures.wordSwipeThreshold &&
                            abs(translation.height) <= KeyboardConstants.DeleteGestures.verticalTolerance

                        if isWordSwipe {
                            viewModel.handleDeleteWord()
                        } else if !repeatTriggered && !hasDragged {
                            viewModel.handleDelete()
                        }
                    }

                    resetGestureState()
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: KeyboardConstants.DeleteGestures.repeatDelay)
                .onEnded { _ in
                    if !isSliding {
                        startRepeat()
                    }
                }
        )
        .onDisappear {
            stopRepeat()
        }
    }

    private func startRepeat() {
        guard !isRepeating else { return }
        isRepeating = true
        repeatTriggered = false
        viewModel.handleDelete()
        repeatTriggered = true
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: KeyboardConstants.DeleteGestures.repeatInterval, repeats: true) { _ in
            repeatTriggered = true
            viewModel.handleDelete()
        }
    }

    private func stopRepeat() {
        if isRepeating {
            repeatTimer?.invalidate()
            repeatTimer = nil
        }
        isRepeating = false
    }

    private func resetGestureState() {
        stopRepeat()
        isActive = false
        dragStarted = false
        hasDragged = false
        isSliding = false
        lastTranslation = .zero
        totalTranslation = .zero
        repeatTriggered = false
    }
}
