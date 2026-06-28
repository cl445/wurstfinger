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

    @State private var positions = RingBuffer<CGPoint>(
        capacity: KeyboardConstants.Gesture.positionBufferSize
    )
    @Binding var isActive: Bool

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if positions.isEmpty {
                            onTouchDown()
                            positions.append(.zero)
                        }
                        let point = CGPoint(
                            x: value.translation.width,
                            y: value.translation.height
                        )
                        positions.append(point)
                        isActive = true
                    }
                    .onEnded { value in
                        defer {
                            positions.removeAll()
                            isActive = false
                        }
                        if positions.isEmpty {
                            positions.append(.zero)
                        }
                        positions.append(
                            CGPoint(
                                x: value.translation.width,
                                y: value.translation.height
                            )
                        )
                        let classification = Self.classify(
                            positions: Self.anchoringOrigin(positions.elements),
                            aspectRatio: aspectRatio
                        )
                        onGestureRecognized(classification)
                    }
            )
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
