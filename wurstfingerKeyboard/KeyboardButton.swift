//
//  KeyboardButton.swift
//  Wurstfinger
//
//  Generic keyboard button with gesture recognition for swipes, taps, and circular gestures
//

import SwiftUI

/// Main keyboard button component with comprehensive gesture recognition
struct KeyboardButton<Label: View, Overlay: View>: View {
    let height: CGFloat
    let aspectRatio: CGFloat
    let label: Label
    let overlay: Overlay
    let config: KeyboardButtonConfig
    let callbacks: KeyboardButtonCallbacks

    @State private var isActive = false
    @State private var positions = RingBuffer<CGPoint>(capacity: KeyboardConstants.Gesture.positionBufferSize)

    /// Extra touch area extension to cover margins between keys
    private var touchPadding: CGFloat {
        // Extend touch area by half the grid spacing on each side
        // This ensures the entire margin area is covered by adjacent keys
        KeyboardConstants.Layout.gridHorizontalSpacing / 2 + 2
    }

    var body: some View {
        KeyCap(
            height: height,
            aspectRatio: aspectRatio,
            background: isActive ? config.activeBackground : config.inactiveBackground,
            highlighted: config.highlighted,
            fontSize: config.fontSize
        ) {
            label
        }
        .overlay(overlay)
        .if(config.accessibilityLabel != nil) { view in
            view.accessibilityLabel(config.accessibilityLabel!)
        }
        .if(config.accessibilityIdentifier != nil) { view in
            view.accessibilityIdentifier(config.accessibilityIdentifier!)
        }
        .accessibilityAddTraits(.isButton)
        // Extend the touch area beyond the visual bounds to cover margins
        .contentShape(Rectangle().inset(by: -touchPadding))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if positions.isEmpty {
                        // Reset if starting new gesture (though onEnded should handle this)
                        positions.removeAll()
                        positions.append(.zero)
                    }

                    let point = CGPoint(x: value.translation.width, y: value.translation.height)
                    positions.append(point)
                    
                    isActive = true
                }
                .onEnded { _ in
                    defer { resetGestureState() }

                    handleFeatureBasedRecognition()
                }
        )
    }

    // MARK: - Feature-Based Recognition

    private func handleFeatureBasedRecognition() {
        // Load config from UserDefaults (for Expert Settings) and apply aspect ratio
        let config = GesturePreprocessorConfig.fromUserDefaults().with(aspectRatio: aspectRatio)
        let preprocessor = GesturePreprocessor(config: config)

        // Load classification thresholds from UserDefaults
        GestureFeatures.thresholds = GestureClassificationThresholds.fromUserDefaults()

        // Preprocess: jitter filter, outlier filter, aspect normalization, smoothing
        // Convert RingBuffer to Array for processing
        let processed = preprocessor.preprocess(positions.elements)

        // Extract features
        let features = GestureFeatures.extract(from: processed)

        // Determine swipe direction
        let direction = angleToDirection(features.maxDisplacementAngle)
        let isCircular = features.isCircular
        let circularDir: KeyboardCircularDirection? = isCircular ? (features.isClockwise ? .clockwise : .counterclockwise) : nil

        // Handle tap
        if features.isTap {
            handleTap()
            return
        }

        // Handle circular gesture
        if isCircular, let onCircular = callbacks.onCircular, let dir = circularDir {
            onCircular(dir)
            return
        }

        // Handle return-swipe
        if features.isReturn {
            if let onSwipeReturn = callbacks.onSwipeReturn {
                onSwipeReturn(direction)
            } else if let onSwipe = callbacks.onSwipe {
                onSwipe(direction)
            } else {
                handleTap()
            }
        } else {
            // Handle regular swipe
            if let onSwipe = callbacks.onSwipe {
                onSwipe(direction)
            } else {
                handleTap()
            }
        }
    }

    /// Converts angle (radians) to KeyboardDirection
    private func angleToDirection(_ angle: CGFloat) -> KeyboardDirection {
        // Normalize to 0...2π
        let normalized = angle < 0 ? angle + 2 * .pi : angle

        // Convert to degrees for easier sector math
        let degrees = normalized * 180 / .pi

        // 8 sectors of 45° each, starting from right (0°)
        switch degrees {
        case 337.5...360, 0..<22.5:
            return .right
        case 22.5..<67.5:
            return .downRight
        case 67.5..<112.5:
            return .down
        case 112.5..<157.5:
            return .downLeft
        case 157.5..<202.5:
            return .left
        case 202.5..<247.5:
            return .upLeft
        case 247.5..<292.5:
            return .up
        case 292.5..<337.5:
            return .upRight
        default:
            return .center
        }
    }

    private func handleTap() {
        if let onTap = callbacks.onTap {
            onTap()
        } else if let onSwipe = callbacks.onSwipe {
            onSwipe(.center)
        }
    }

    private func resetGestureState() {
        positions.removeAll()
        isActive = false
    }
}
