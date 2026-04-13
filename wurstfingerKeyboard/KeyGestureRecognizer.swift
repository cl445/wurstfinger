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

/// Reusable gesture recognition logic shared between `KeyView` (data-driven
/// path) and potentially `KeyboardButton` (legacy path).
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
                    .onEnded { _ in
                        defer {
                            positions.removeAll()
                            isActive = false
                        }
                        let classification = Self.classify(
                            positions: positions.elements,
                            aspectRatio: aspectRatio
                        )
                        onGestureRecognized(classification)
                    }
            )
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
