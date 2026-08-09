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
    /// Vertical up-swipe ended while the horizontal slide never activated.
    /// `isReturn` is true when the finger came back toward its origin
    /// (MessagEase: up toggles extra-symbol labels, return-up toggles
    /// letter + standard-symbol labels).
    case swipeUp(isReturn: Bool)
    /// Touch sequence was cancelled by the system (incoming call, edge
    /// swipe, keyboard dismissal mid-drag). Consumers must discard drag
    /// state without committing any input.
    case cancelled
}

/// Thresholds a slide key classifies against.
///
/// Bundled per key rather than passed as loose arguments: the delete key has
/// no up-swipe binding (`KeyboardViewModel.handleDeleteSlide` ignores
/// `.swipeUp`), so handing it the space bar's up-swipe threshold makes a
/// diagonal delete drag latch no slide and end as an up-swipe nobody
/// consumes — deleting nothing at all.
struct SlideGestureConfiguration: Equatable {
    /// Horizontal travel that latches the continuous slide.
    let activationThreshold: CGFloat

    /// Upward travel that classifies a vertical swipe, or nil for keys
    /// without an up-swipe binding — those never let the vertical axis block
    /// the latch and never report `.swipeUp`. An up-and-return flick on such
    /// a key ends near its origin and therefore classifies as a tap — on
    /// delete that deletes one character. Deliberate: the alternative, a
    /// gesture that produces nothing at all, reads as a dropped input.
    let swipeUpThreshold: CGFloat?

    static let moveCursor = SlideGestureConfiguration(
        activationThreshold: KeyboardConstants.SpaceGestures.dragActivationThreshold,
        swipeUpThreshold: KeyboardConstants.SpaceGestures.swipeUpActivationThreshold
    )

    static let delete = SlideGestureConfiguration(
        activationThreshold: KeyboardConstants.DeleteGestures.slideActivationThreshold,
        swipeUpThreshold: nil
    )

    /// A key without slide behavior: nothing can latch.
    static let inactive = SlideGestureConfiguration(
        activationThreshold: .infinity,
        swipeUpThreshold: nil
    )

    static func `for`(_ slideType: SlideType) -> SlideGestureConfiguration {
        switch slideType {
        case .moveCursor: .moveCursor
        case .delete: .delete
        case .none: .inactive
        }
    }
}

/// State machine backing `SlideGestureHandler`.
///
/// Extracted as a pure value type so tap/slide classification and
/// cancellation recovery can be unit-tested without rendering SwiftUI views.
struct SlideGestureState {
    private(set) var dragStarted = false
    private(set) var isSliding = false
    private(set) var lastTranslationX: CGFloat = 0
    /// Most-negative vertical translation seen this gesture (SwiftUI's y axis
    /// points down, so upward travel is negative). Peak of the up-swipe.
    private(set) var upwardPeakY: CGFloat = 0
    /// Largest distance from the touch-down origin seen so far. Mirrors
    /// `KeyGestureSequence.maxDisplacement`; used to cancel a pending long
    /// press once the finger has clearly left its resting position.
    private(set) var maxDisplacement: CGFloat = 0

    /// Events produced by a single drag update.
    struct Update: Equatable {
        var isTouchDown = false
        var phases: [SlidePhase] = []
    }

    /// Processes one `onChanged` sample.
    mutating func handleChanged(
        translation: CGSize,
        configuration: SlideGestureConfiguration
    ) -> Update {
        var update = Update()
        if !dragStarted {
            dragStarted = true
            update.isTouchDown = true
        }

        let currentX = translation.width
        upwardPeakY = min(upwardPeakY, translation.height)
        maxDisplacement = max(maxDisplacement, hypot(translation.width, translation.height))

        // Activate only while the horizontal axis dominates: crossing the
        // (small) horizontal threshold during a mostly-vertical movement must
        // not latch the slide, or an upward label-toggle swipe with a few
        // points of sideways drift turns into a cursor slide and the vertical
        // classification in `handleEnded` becomes unreachable. Once latched,
        // the slide stays tolerant of vertical drift as before.
        //
        // Instantaneous dominance alone is not enough: on the return leg of a
        // return-up swipe the vertical translation shrinks through ~0 while
        // sideways drift stays, so a lift-off sample like (10, -6) would
        // latch the slide even though the peak committed the up-swipe long
        // ago. Once the upward peak crossed the up-swipe threshold, the
        // gesture belongs to `handleEnded`'s vertical classification and must
        // never latch — *unless* the finger then makes a clearly dominant
        // horizontal move.
        //
        // Re-arm (finding #11): the committed up-peak latch never decayed, so
        // an incidental up-flick followed by a genuine sideways drag stayed
        // stuck as an up-swipe and the cursor never moved. Re-allow latching
        // only when the current horizontal travel is both large in absolute
        // terms (≥ the 30 pt up-swipe threshold) and strongly horizontal
        // (> 2× the vertical). Return-leg drift (~10 pt sideways) stays well
        // below the 30 pt floor, so this does not re-introduce the return-up
        // mis-latch the peak guard was added to fix. A key without an up-swipe
        // binding has no threshold at all, so neither guard applies to it.
        let upSwipeCommitted = configuration.swipeUpThreshold.map { -upwardPeakY >= $0 } ?? false
        let dominantHorizontalSlide = configuration.swipeUpThreshold.map {
            abs(currentX) >= $0 && abs(currentX) > abs(translation.height) * 2
        } ?? false
        if !isSliding,
           abs(currentX) >= configuration.activationThreshold,
           abs(currentX) > abs(translation.height),
           !upSwipeCommitted || dominantHorizontalSlide {
            isSliding = true
            // Anchor at the threshold crossing (not the full translation) so
            // the travel beyond the threshold is reported on the same tick
            // instead of being dropped — otherwise the first `threshold`
            // points are a dead zone.
            lastTranslationX = currentX < 0
                ? -configuration.activationThreshold
                : configuration.activationThreshold
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
    /// gesture qualifies as neither a slide, an up-swipe, nor a tap.
    mutating func handleEnded(
        translation: CGSize,
        configuration: SlideGestureConfiguration
    ) -> SlidePhase? {
        defer { reset() }
        if isSliding { return .ended }
        // Vertical classification runs only when the horizontal slide never
        // activated, so cursor drags with vertical drift are unaffected. It
        // must precede the tap check: a return-up swipe ends near its origin
        // and would otherwise be classified as a tap.
        if let swipeUpThreshold = configuration.swipeUpThreshold, -upwardPeakY >= swipeUpThreshold {
            // The finger "returned" when it came back at least
            // (1 - returnSwipeThreshold) of the way from the peak toward the
            // origin. Compared signed (peak is negative, y grows downward) so
            // overshooting past the origin still counts as a return — fast
            // return swipes routinely end below their starting point, and an
            // absolute-distance ratio would misread them as plain up-swipes.
            // Downward peaks are never tracked, so down-swipes still fall
            // through and stay ignored.
            let returnBoundary = upwardPeakY * KeyboardConstants.SpaceGestures.returnSwipeThreshold
            return .swipeUp(isReturn: translation.height >= returnBoundary)
        }
        // A tap must stay near its origin on *both* axes. Gating on
        // horizontal travel alone would classify a vertical flick (e.g.
        // 80 pt up on the space bar) as a tap and commit its center action.
        let displacement = hypot(translation.width, translation.height)
        return displacement < configuration.activationThreshold ? .tap : nil
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
        upwardPeakY = 0
        maxDisplacement = 0
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
    /// Same contract as `KeyGestureRecognizer.onLongPress`: fires after the
    /// finger has rested for `KeyboardConstants.LongPress.duration` without
    /// sliding or moving beyond the tolerance; returns whether it was
    /// handled. A handled long press consumes the touch (no tap, no slide
    /// on release). `nil` disables detection.
    var onLongPress: (() -> Bool)?

    /// Collects the touch path for the swipe trail overlay. Nil disables the
    /// feed entirely (previews and tests); when set, the recorder itself
    /// decides whether the user has the trail turned on.
    var trail: GestureTrailRecorder?

    @Binding var isActive: Bool

    @State private var state = SlideGestureState()
    @State private var longPress = LongPressScheduler()
    /// Identifies this key's touch sequence to the shared trail recorder.
    @StateObject private var trailToken = GestureTrailToken()

    /// True while a touch sequence is in flight. Unlike `@State`, SwiftUI
    /// guarantees `@GestureState` is reset when the system cancels the
    /// touches (incoming call, edge swipe, keyboard dismissal), where
    /// `onEnded` is never called — the reset is our cancellation signal.
    @GestureState private var sequenceInFlight = false

    func body(content: Content) -> some View {
        content
            .gesture(
                // The coordinate space affects only `value.location`, which the
                // trail records. `value.translation` is a delta, so the slide
                // state machine reads the same values in any space.
                DragGesture(minimumDistance: 0, coordinateSpace: GestureTrailRecorder.coordinateSpace)
                    .updating($sequenceInFlight) { _, inFlight, _ in
                        inFlight = true
                    }
                    .onChanged { value in
                        // A fired long press owns the rest of this touch:
                        // don't feed the state machine, or the movement would
                        // start a cursor slide after the digit was typed.
                        if longPress.consumedTouch {
                            // The digit is already typed, so stop drawing a
                            // gesture that will never be dispatched.
                            trail?.cancel(from: trailToken)
                            isActive = true
                            return
                        }
                        let update = state.handleChanged(
                            translation: value.translation,
                            configuration: configuration
                        )
                        if update.isTouchDown {
                            trail?.begin(
                                at: value.location, from: trailToken,
                                activationDistance: configuration.activationThreshold
                            )
                            onTouchDown()
                            scheduleLongPress()
                        } else {
                            trail?.extend(to: value.location, from: trailToken)
                            if longPress.isScheduled,
                               state.isSliding
                               || state.maxDisplacement > KeyboardConstants.LongPress.movementTolerance {
                                longPress.cancel()
                            }
                        }
                        for phase in update.phases {
                            onSlide(phase)
                        }
                        isActive = true
                    }
                    .onEnded { value in
                        longPress.cancel()
                        if longPress.consumedTouch {
                            // Reset silently: no phase is reported, so the
                            // release produces neither a tap nor a slide end.
                            longPress.clearConsumed()
                            _ = state.handleCancelled()
                            trail?.cancel(from: trailToken)
                            isActive = false
                            return
                        }
                        if let phase = state.handleEnded(
                            translation: value.translation,
                            configuration: configuration
                        ) {
                            onSlide(phase)
                        }
                        trail?.finish(from: trailToken)
                        isActive = false
                    }
            )
            .onChange(of: sequenceInFlight) { _, inFlight in
                // A normal end already reset the state machine in `onEnded`;
                // if the sequence stops while a drag is still marked as in
                // flight, the system cancelled the touches.
                guard !inFlight else { return }
                if let phase = abandonSequence() { onSlide(phase) }
                isActive = false
            }
            // A key removed mid-gesture reaches neither `onEnded` nor the
            // cancel path, so it hands its touch back here — trail included,
            // and before the armed long press can fire into the next mode. No
            // phase is reported: the consumer's drag flags are re-initialized
            // by the next `.began`, exactly like the consumed-long-press branch.
            .onDisappear {
                _ = abandonSequence()
            }
    }

    /// Drops everything the in-flight touch owns: the armed long press, the
    /// drag state, and the trail. Returns the phase the consumer must hear
    /// about (`.cancelled` while a drag was in flight), or nil.
    private func abandonSequence() -> SlidePhase? {
        longPress.abandon()
        let phase = state.handleCancelled()
        trail?.cancel(from: trailToken)
        return phase
    }

    // MARK: - Long Press

    /// Arms the shared scheduler with this handler's fire guard. The guard
    /// reads live `@State` (`state`) at fire time through the property wrapper
    /// — identical to the previous `fireLongPress()` semantics. The
    /// `!state.isSliding` axis is preserved: it is the one guard that
    /// legitimately differs from `KeyGestureRecognizer` (which has no sliding
    /// concept).
    private func scheduleLongPress() {
        guard onLongPress != nil else { return }
        longPress.schedule {
            state.dragStarted
                && !state.isSliding
                && state.maxDisplacement <= KeyboardConstants.LongPress.movementTolerance
                && onLongPress?() == true
        }
    }

    private var configuration: SlideGestureConfiguration {
        .for(slideType)
    }

    // MARK: - Activation Threshold

    /// Travel below which this key's touch is dispatched as a tap. `internal`
    /// and static so the trail-threshold guard test can pin it.
    static func activationThreshold(for slideType: SlideType) -> CGFloat {
        SlideGestureConfiguration.for(slideType).activationThreshold
    }
}
