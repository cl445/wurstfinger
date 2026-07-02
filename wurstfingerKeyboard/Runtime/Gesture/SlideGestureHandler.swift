//
//  SlideGestureHandler.swift
//  Wurstfinger
//
//  Gesture handler for keys with slide behavior (space, delete).
//  Reports continuous drag deltas during the gesture, and classifies
//  taps/swipes at the end.
//

import SwiftUI

/// Phase of a slide gesture lifecycle.
enum SlidePhase: Equatable {
    /// First drag movement detected beyond activation threshold.
    case began
    /// Continuous drag update with horizontal delta since last report.
    case changed(deltaX: CGFloat)
    /// Drag ended while sliding.
    case ended
    /// Drag ended without exceeding the slide activation threshold → tap.
    case tap
    /// Touch sequence was cancelled by the system (incoming call, edge
    /// swipe, keyboard dismissal mid-drag). Consumers must discard drag
    /// state without committing any input.
    case cancelled
}

/// State machine backing `SlideGestureHandler`.
///
/// Extracted as a pure value type so tap/slide classification and
/// cancellation recovery can be unit-tested without rendering SwiftUI views.
struct SlideGestureState {
    private(set) var dragStarted = false
    private(set) var isSliding = false
    private(set) var lastTranslationX: CGFloat = 0

    /// Events produced by a single drag update.
    struct Update: Equatable {
        var isTouchDown = false
        var phases: [SlidePhase] = []
    }

    /// Processes one `onChanged` sample.
    mutating func handleChanged(translation: CGSize, activationThreshold: CGFloat) -> Update {
        var update = Update()
        if !dragStarted {
            dragStarted = true
            update.isTouchDown = true
        }

        let currentX = translation.width

        if !isSliding, abs(currentX) >= activationThreshold {
            isSliding = true
            // Anchor at the threshold crossing (not the full translation) so
            // the travel beyond the threshold is reported on the same tick
            // instead of being dropped — otherwise the first `threshold`
            // points are a dead zone.
            lastTranslationX = currentX < 0 ? -activationThreshold : activationThreshold
            update.phases.append(.began)
        }

        if isSliding {
            let deltaX = currentX - lastTranslationX
            if deltaX != 0 {
                lastTranslationX = currentX
                update.phases.append(.changed(deltaX: deltaX))
            }
        }

        return update
    }

    /// Processes `onEnded`. Returns the phase to report, or nil when the
    /// gesture qualifies as neither a slide nor a tap.
    mutating func handleEnded(translation: CGSize, activationThreshold: CGFloat) -> SlidePhase? {
        defer { reset() }
        if isSliding { return .ended }
        // A tap must stay near its origin on *both* axes. Gating on
        // horizontal travel alone would classify a vertical flick (e.g.
        // 80 pt up on the space bar) as a tap and commit its center action.
        let displacement = hypot(translation.width, translation.height)
        return displacement < activationThreshold ? .tap : nil
    }

    /// Processes a system cancellation of the touch sequence (`onEnded` is
    /// never called for cancelled gestures). Resets all state so the next
    /// touch starts a fresh sequence instead of computing deltas against a
    /// stale anchor; returns `.cancelled` when a drag was in flight.
    mutating func handleCancelled() -> SlidePhase? {
        defer { reset() }
        return dragStarted ? .cancelled : nil
    }

    private mutating func reset() {
        dragStarted = false
        isSliding = false
        lastTranslationX = 0
    }
}

/// Gesture handler for keys with `slideType != .none`.
///
/// Unlike `KeyGestureRecognizer` (which classifies the full gesture at the
/// end), this modifier reports continuous drag deltas for cursor movement
/// and progressive deletion. If the drag never exceeds the activation
/// threshold, the gesture is classified as a tap.
struct SlideGestureHandler: ViewModifier {
    let slideType: SlideType
    let onSlide: (SlidePhase) -> Void
    let onTouchDown: () -> Void
    @Binding var isActive: Bool

    @State private var state = SlideGestureState()

    /// True while a touch sequence is in flight. Unlike `@State`, SwiftUI
    /// guarantees `@GestureState` is reset when the system cancels the
    /// touches (incoming call, edge swipe, keyboard dismissal), where
    /// `onEnded` is never called — the reset is our cancellation signal.
    @GestureState private var sequenceInFlight = false

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($sequenceInFlight) { _, inFlight, _ in
                        inFlight = true
                    }
                    .onChanged { value in
                        let update = state.handleChanged(
                            translation: value.translation,
                            activationThreshold: activationThreshold
                        )
                        if update.isTouchDown {
                            onTouchDown()
                        }
                        for phase in update.phases {
                            onSlide(phase)
                        }
                        isActive = true
                    }
                    .onEnded { value in
                        if let phase = state.handleEnded(
                            translation: value.translation,
                            activationThreshold: activationThreshold
                        ) {
                            onSlide(phase)
                        }
                        isActive = false
                    }
            )
            .onChange(of: sequenceInFlight) { _, inFlight in
                // A normal end already reset the state machine in `onEnded`;
                // if the sequence stops while a drag is still marked as in
                // flight, the system cancelled the touches.
                guard !inFlight else { return }
                if let phase = state.handleCancelled() {
                    onSlide(phase)
                }
                isActive = false
            }
    }

    private var activationThreshold: CGFloat {
        switch slideType {
        case .moveCursor:
            KeyboardConstants.SpaceGestures.dragActivationThreshold
        case .delete:
            KeyboardConstants.DeleteGestures.slideActivationThreshold
        case .none:
            .infinity
        }
    }
}
