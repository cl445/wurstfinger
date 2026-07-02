//
//  KeyGestureRecognizer.swift
//  Wurstfinger
//
//  Reusable gesture recognition ViewModifier that classifies touch
//  sequences into GestureType values using the existing preprocessing
//  and feature-extraction pipeline.
//

import CoreGraphics
import SwiftUI

/// Result of classifying a completed gesture.
struct GestureClassification {
    let gesture: GestureType
    let isReturn: Bool
}

/// Touch-sequence state backing `KeyGestureRecognizer`.
///
/// Extracted as a pure value type so sequence tracking and cancellation
/// recovery can be unit-tested without rendering SwiftUI views.
struct KeyGestureSequence {
    private var positions: RingBuffer<CGPoint>

    init(capacity: Int = KeyboardConstants.Gesture.positionBufferSize) {
        positions = RingBuffer<CGPoint>(capacity: capacity)
    }

    /// Whether a touch sequence is currently being recorded.
    var isTracking: Bool {
        !positions.isEmpty
    }

    /// Records one `onChanged` sample. Returns true when this sample is the
    /// first contact of a new sequence (touch down).
    mutating func handleChanged(translation: CGSize) -> Bool {
        let isTouchDown = positions.isEmpty
        if isTouchDown {
            positions.append(.zero)
        }
        positions.append(CGPoint(x: translation.width, y: translation.height))
        return isTouchDown
    }

    /// Records the final sample and classifies the completed sequence.
    mutating func handleEnded(translation: CGSize, aspectRatio: CGFloat) -> GestureClassification {
        defer { positions.removeAll() }
        if positions.isEmpty {
            positions.append(.zero)
        }
        positions.append(CGPoint(x: translation.width, y: translation.height))
        return KeyGestureRecognizer.classify(
            positions: KeyGestureRecognizer.anchoringOrigin(positions.elements),
            aspectRatio: aspectRatio
        )
    }

    /// Discards the partial sequence after the system cancelled the touches
    /// (`onEnded` is never called for cancelled gestures). Without this, the
    /// next touch would skip touch-down handling and append onto the stale
    /// path, misclassifying a tap as the previous gesture's swipe.
    mutating func handleCancelled() {
        positions.removeAll()
    }
}

/// Reusable gesture recognition logic used by `KeyView`.
///
/// Wraps the existing `GesturePreprocessor` + `GestureFeatures` pipeline and
/// produces `GestureType` values instead of `KeyboardDirection`.
struct KeyGestureRecognizer: ViewModifier {
    /// Called once per completed gesture with the classified result.
    let onGestureRecognized: (GestureClassification) -> Void

    /// Called on first touch contact (for haptic feedback).
    let onTouchDown: () -> Void

    /// Key aspect ratio forwarded to the preprocessor for normalization.
    let aspectRatio: CGFloat

    @State private var sequence = KeyGestureSequence()
    @Binding var isActive: Bool

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
                        if sequence.handleChanged(translation: value.translation) {
                            onTouchDown()
                        }
                        isActive = true
                    }
                    .onEnded { value in
                        let classification = sequence.handleEnded(
                            translation: value.translation,
                            aspectRatio: aspectRatio
                        )
                        isActive = false
                        onGestureRecognized(classification)
                    }
            )
            .onChange(of: sequenceInFlight) { _, inFlight in
                // A normal end already cleared the sequence in `onEnded`; if
                // the sequence stops while samples remain, the system
                // cancelled the touches. Discard the partial gesture without
                // classifying it.
                guard !inFlight, sequence.isTracking else { return }
                sequence.handleCancelled()
                isActive = false
            }
    }

    /// Guarantees the touch-down origin `(0,0)` is the first sample.
    ///
    /// Every recorded point is a translation relative to touch-down, so the
    /// true gesture origin is always `(0,0)` — appended first in `onChanged`.
    /// On a long gesture (more samples than the position buffer's capacity)
    /// the ring buffer evicts that origin, leaving a mid-gesture point as
    /// `elements[0]`. Since all start-relative features (maxDisplacement,
    /// returnRatio, dominant angle, circularity) measure from `points.first`,
    /// a lost origin mis-classifies the gesture. When the origin was evicted
    /// (`elements[0] != .zero`), re-anchor it.
    static func anchoringOrigin(_ points: [CGPoint]) -> [CGPoint] {
        guard let first = points.first, first != .zero else { return points }
        return [.zero] + points
    }

    // MARK: - Classification (Pure Function)

    /// Classifies a sequence of touch positions into a `GestureType`.
    ///
    /// This is a pure function so it can be unit-tested without rendering
    /// any SwiftUI views.
    static func classify(
        positions: [CGPoint],
        aspectRatio: CGFloat = 1.0
    ) -> GestureClassification {
        let config = GesturePreprocessorConfig.fromUserDefaults()
            .with(aspectRatio: aspectRatio)
        let preprocessor = GesturePreprocessor(config: config)
        let thresholds = GestureClassificationThresholds.fromUserDefaults()
        let processed = preprocessor.preprocess(positions)
        let features = GestureFeatures.extract(from: processed, thresholds: thresholds)

        return classify(features: features)
    }

    /// Classifies already-extracted features. Useful for testing with
    /// synthetic feature vectors.
    static func classify(features: GestureFeatures) -> GestureClassification {
        // Tap
        if features.isTap {
            return GestureClassification(gesture: .tap, isReturn: false)
        }

        // Circular
        if features.isCircular {
            let gesture: GestureType = features.isClockwise
                ? .circularClockwise
                : .circularCounterclockwise
            return GestureClassification(gesture: gesture, isReturn: false)
        }

        // Directional (swipe or return-swipe)
        let gesture = angleToGestureType(features.maxDisplacementAngle)
        return GestureClassification(
            gesture: gesture,
            isReturn: features.isReturn
        )
    }

    /// Maps an angle (radians, from `atan2`) to the corresponding swipe
    /// `GestureType`. Sector boundaries match `KeyboardButton.angleToDirection`.
    static func angleToGestureType(_ angle: CGFloat) -> GestureType {
        let normalized = angle < 0 ? angle + 2 * .pi : angle
        let degrees = normalized * 180 / .pi

        switch degrees {
        case 337.5 ... 360, 0 ..< 22.5:
            return .swipeRight
        case 22.5 ..< 67.5:
            return .swipeDownRight
        case 67.5 ..< 112.5:
            return .swipeDown
        case 112.5 ..< 157.5:
            return .swipeDownLeft
        case 157.5 ..< 202.5:
            return .swipeLeft
        case 202.5 ..< 247.5:
            return .swipeUpLeft
        case 247.5 ..< 292.5:
            return .swipeUp
        case 292.5 ..< 337.5:
            return .swipeUpRight
        default:
            return .swipeRight
        }
    }
}
