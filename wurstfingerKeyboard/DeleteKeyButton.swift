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
    let aspectRatio: CGFloat

    /// Consolidated gesture state to reduce @State property count
    private struct GestureState {
        var isActive = false
        var dragStarted = false
        var hasDragged = false
        var isSliding = false
        var lastTranslation: CGSize = .zero
        var totalTranslation: CGSize = .zero
        var isRepeating = false
        var repeatTriggered = false

        mutating func reset() {
            isActive = false
            dragStarted = false
            hasDragged = false
            isSliding = false
            lastTranslation = .zero
            totalTranslation = .zero
            repeatTriggered = false
        }
    }

    @State private var gesture = GestureState()
    /// Timer must be separate @State since it's a reference type not suitable for value-type struct
    @State private var repeatTimer: Timer?

    var body: some View {
        KeyCap(
            height: keyHeight,
            aspectRatio: aspectRatio,
            background: gesture.isActive ? Color(.tertiarySystemFill) : Color(.secondarySystemBackground),
            fontSize: KeyboardConstants.FontSizes.keyLabel
        ) {
            Image(systemName: "delete.left")
        }
        .accessibilityLabel(Text("Delete"))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if gesture.isRepeating {
                        stopRepeat()
                    }

                    if !gesture.dragStarted {
                        gesture.dragStarted = true
                    }

                    gesture.totalTranslation = value.translation

                    if !gesture.isSliding,
                       abs(gesture.totalTranslation.width) >= KeyboardConstants.DeleteGestures.slideActivationThreshold,
                       abs(gesture.totalTranslation.height) <= KeyboardConstants.DeleteGestures.verticalTolerance {
                        gesture.isSliding = true
                        gesture.hasDragged = true
                        viewModel.beginDeleteDrag()
                        gesture.lastTranslation = gesture.totalTranslation
                        return
                    }

                    if gesture.isSliding {
                        let deltaX = gesture.totalTranslation.width - gesture.lastTranslation.width
                        viewModel.updateDeleteDrag(deltaX: deltaX)
                        gesture.lastTranslation = gesture.totalTranslation
                    } else if abs(gesture.totalTranslation.width) >= KeyboardConstants.DeleteGestures.dragActivationThreshold {
                        gesture.hasDragged = true
                    }

                    gesture.lastTranslation = value.translation
                    gesture.isActive = true
                }
                .onEnded { _ in
                    if !gesture.isSliding && !gesture.repeatTriggered && !gesture.hasDragged {
                        viewModel.handleDelete()
                    }

                    resetGestureState()
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: KeyboardConstants.DeleteGestures.repeatDelay)
                .onEnded { _ in
                    if !gesture.hasDragged {
                        startRepeat()
                    }
                }
        )
        .onDisappear {
            resetGestureState()
        }
    }

    /// Starts repeating deletion on long press.
    /// Note: Uses Timer.scheduledTimer which requires the main run loop. This is safe for a keyboard
    /// extension since gestures always fire on the main thread, but the timer closure captures `self`
    /// implicitly through `gesture` and `viewModel`. The timer is always invalidated in `stopRepeat()`
    /// which is called from `onEnded`, `onDisappear`, and `resetGestureState`.
    private func startRepeat() {
        guard !gesture.isRepeating else { return }
        gesture.isRepeating = true
        gesture.repeatTriggered = false
        viewModel.handleDelete()
        gesture.repeatTriggered = true
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: KeyboardConstants.DeleteGestures.repeatInterval, repeats: true) { _ in
            gesture.repeatTriggered = true
            viewModel.handleDelete()
        }
    }

    private func stopRepeat() {
        if gesture.isRepeating {
            repeatTimer?.invalidate()
            repeatTimer = nil
        }
        gesture.isRepeating = false
    }

    private func resetGestureState() {
        stopRepeat()
        if gesture.isSliding {
            viewModel.endDeleteDrag()
        }
        gesture.reset()
    }
}
