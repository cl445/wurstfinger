//
//  KeyboardButton.swift
//  Wurstfinger
//
//  Generic keyboard button with gesture recognition for swipes, taps, and circular gestures
//

import SwiftUI

/// Recognition mode for gesture detection
enum GestureRecognitionMode {
    case legacy           // Original implementation
    case featureBased     // New preprocessing + feature extraction
    case advancedDTW      // DTW-based template matching
}

/// Default preprocessor config (defined outside generic type)
private let defaultPreprocessorConfig = GesturePreprocessorConfig.default

/// Main keyboard button component with comprehensive gesture recognition
struct KeyboardButton<Label: View, Overlay: View>: View {
    let height: CGFloat
    let aspectRatio: CGFloat
    let label: Label
    let overlay: Overlay
    let config: KeyboardButtonConfig
    let callbacks: KeyboardButtonCallbacks

    /// Optional key index for cross-key gesture resolution
    var keyIndex: KeyIndex?

    /// Optional registry for cross-key gesture resolution
    var positionRegistry: KeyPositionRegistry?

    /// Which recognition mode to use
    var recognitionMode: GestureRecognitionMode = .featureBased

    @State private var isActive = false
    @State private var timestampedPositions: [TimestampedPoint] = []
    @State private var absoluteStartPosition: CGPoint = .zero
    @State private var gestureStartTime: Date = .now

    /// Advanced gesture recognizer instance (for DTW mode)
    private let advancedRecognizer = AdvancedGestureRecognizer()

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
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if timestampedPositions.isEmpty {
                        gestureStartTime = .now
                        timestampedPositions = [TimestampedPoint(.zero, at: 0)]
                        absoluteStartPosition = value.startLocation  // Capture absolute start
                    }

                    let point = CGPoint(x: value.translation.width, y: value.translation.height)
                    let timestamp = Date.now.timeIntervalSince(gestureStartTime)
                    timestampedPositions.append(TimestampedPoint(point, at: timestamp))

                    // Buffer limit
                    if timestampedPositions.count > KeyboardConstants.Gesture.positionBufferSize {
                        timestampedPositions.removeFirst(timestampedPositions.count - KeyboardConstants.Gesture.positionBufferSize)
                    }

                    isActive = true
                }
                .onEnded { value in
                    defer { resetGestureState() }

                    let finalPoint = CGPoint(x: value.translation.width, y: value.translation.height)
                    let timestamp = Date.now.timeIntervalSince(gestureStartTime)
                    timestampedPositions.append(TimestampedPoint(finalPoint, at: timestamp))

                    switch recognitionMode {
                    case .legacy:
                        handleLegacyRecognition(value: value, finalPoint: finalPoint)
                    case .featureBased:
                        handleFeatureBasedRecognition()
                    case .advancedDTW:
                        handleAdvancedRecognition()
                    }
                }
        )
    }

    // MARK: - Feature-Based Recognition (new preprocessing pipeline)

    private func handleFeatureBasedRecognition() {
        // Create preprocessor with correct aspect ratio
        let config = defaultPreprocessorConfig.with(aspectRatio: aspectRatio)
        let preprocessor = GesturePreprocessor(config: config)

        // Preprocess: jitter filter, outlier filter, aspect normalization, smoothing, resampling
        let processed = preprocessor.preprocess(timestampedPositions)

        // Extract features
        let features = GestureFeatures.extract(from: processed)

        // Save for debug visualization
        GestureDebugLog.savePath(processed)
        GestureDebugLog.log("FEATURES: path=\(Int(features.pathLength)) maxDisp=\(Int(features.maxDisplacement))@\(Int(features.maxDisplacementProgress * 100))% return=\(String(format: "%.2f", features.returnRatio)) angular=\(Int(features.angularSpan * 180 / .pi))°")

        // Determine swipe direction (needed for both cross-key and normal handling)
        let direction = angleToDirection(features.maxDisplacementAngle)
        let isCircular = features.isCircular
        let circularDir: KeyboardCircularDirection? = isCircular ? (features.isClockwise ? .clockwise : .counterclockwise) : nil

        // Cross-key gesture resolution (only for swipes, not taps or circles)
        if let registry = positionRegistry,
           let currentKey = keyIndex,
           let onCrossKey = callbacks.onCrossKeyGesture,
           !features.isTap,
           !isCircular {  // Exclude circular gestures

            // Calculate initial movement direction from raw positions
            let rawPoints = timestampedPositions.map { $0.point }
            let (initialDir, magnitude) = CrossKeyGestureResolver.calculateInitialDirection(from: rawPoints)

            // Only try cross-key resolution if there was significant movement
            if magnitude >= 20 {
                let resolver = CrossKeyGestureResolver(registry: registry)
                let gestureInfo = GestureInfo(
                    registeredKey: currentKey,
                    absoluteStartPosition: absoluteStartPosition,
                    initialDirection: initialDir,
                    initialMovementMagnitude: magnitude,
                    features: features
                )

                let resolvedKey = resolver.resolveOriginKey(for: gestureInfo)

                // If the gesture belongs to a different key, redirect it
                if resolvedKey != currentKey {
                    GestureDebugLog.log("→ CROSS-KEY: \(currentKey) → \(resolvedKey)")
                    let result = CrossKeyGestureResult(
                        targetKey: resolvedKey,
                        direction: direction,
                        isReturn: features.isReturn,
                        isCircular: isCircular,
                        circularDirection: circularDir
                    )
                    onCrossKey(result)
                    return
                }
            }
        }

        // Normal gesture handling
        if features.isTap {
            GestureDebugLog.log("→ TAP")
            handleTap()
            return
        }

        if isCircular, let onCircular = callbacks.onCircular, let dir = circularDir {
            GestureDebugLog.log("→ CIRCULAR \(dir)")
            onCircular(dir)
            return
        }

        if features.isReturn {
            GestureDebugLog.log("→ RETURN \(direction)")
            if let onSwipeReturn = callbacks.onSwipeReturn {
                onSwipeReturn(direction)
            } else if let onSwipe = callbacks.onSwipe {
                onSwipe(direction)
            } else {
                handleTap()
            }
        } else {
            GestureDebugLog.log("→ SWIPE \(direction)")
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

    // MARK: - Advanced Recognition (DTW-based)

    private func handleAdvancedRecognition() {
        let positions = timestampedPositions.map { $0.point }
        let result = advancedRecognizer.recognize(
            positions: positions,
            aspectRatio: aspectRatio
        )

        switch result.gestureType {
        case .tap:
            handleTap()

        case .circular:
            if let circularDir = result.circularDirection,
               let onCircular = callbacks.onCircular {
                onCircular(circularDir)
            } else {
                callbacks.onTap?()
            }

        case .swipeReturn:
            if result.direction != KeyboardDirection.center {
                if let onSwipeReturn = callbacks.onSwipeReturn {
                    onSwipeReturn(result.direction)
                } else if let onSwipe = callbacks.onSwipe {
                    onSwipe(result.direction)
                } else {
                    callbacks.onTap?()
                }
            } else {
                callbacks.onTap?()
            }

        case .swipe:
            if result.direction != KeyboardDirection.center {
                if let onSwipe = callbacks.onSwipe {
                    onSwipe(result.direction)
                } else {
                    callbacks.onTap?()
                }
            } else {
                callbacks.onTap?()
            }
        }
    }

    // MARK: - Legacy Recognition (original implementation)

    private func handleLegacyRecognition(value: DragGesture.Value, finalPoint: CGPoint) {
        let positions = timestampedPositions.map { $0.point }

        // Calculate maxOffset from positions
        var maxOffset: CGPoint = .zero
        for point in positions {
            if point.magnitude() > maxOffset.magnitude() {
                maxOffset = point
            }
        }

        let maxDistance = maxOffset.magnitude()
        let finalDistance = finalPoint.magnitude()

        // Save path for visualization
        GestureDebugLog.savePath(positions)

        // Check for circular gesture first
        if let onCircular = callbacks.onCircular,
           maxDistance >= KeyboardConstants.Gesture.minSwipeLength,
           let circle = KeyboardGestureRecognizer.circularDirection(
               positions: positions,
               circleCompletionTolerance: KeyboardConstants.Gesture.circleCompletionTolerance,
               minSwipeLength: KeyboardConstants.Gesture.minSwipeLength
           ) {
            GestureDebugLog.log("LEGACY: circular \(circle)")
            onCircular(circle)
            return
        }

        // Swipe gestures
        let finalOffsetThreshold = KeyboardConstants.Gesture.minSwipeLength * KeyboardConstants.Gesture.finalOffsetMultiplier
        let maxDirection = KeyboardDirection.direction(
            for: CGSize(width: maxOffset.x, height: maxOffset.y),
            tolerance: 0,
            aspectRatio: aspectRatio
        )
        let finalDirection = KeyboardDirection.direction(
            for: value.translation,
            tolerance: KeyboardConstants.Gesture.minSwipeLength,
            aspectRatio: aspectRatio
        )

        let finalOffsetSmallEnough = finalDistance <= finalOffsetThreshold || finalDirection != maxDirection

        if maxDistance >= KeyboardConstants.Gesture.minSwipeLength, finalOffsetSmallEnough {
            // Return swipe
            GestureDebugLog.log("LEGACY: return \(maxDirection) (max=\(Int(maxDistance)) final=\(Int(finalDistance)))")
            if maxDirection != .center {
                if let onSwipeReturn = callbacks.onSwipeReturn {
                    onSwipeReturn(maxDirection)
                } else if let onSwipe = callbacks.onSwipe {
                    onSwipe(finalDirection)
                } else if finalDirection == .center {
                    callbacks.onTap?()
                }
            } else {
                handleDirectionalInput(direction: finalDirection)
            }
        } else {
            GestureDebugLog.log("LEGACY: swipe \(finalDirection) (max=\(Int(maxDistance)) final=\(Int(finalDistance)))")
            handleDirectionalInput(direction: finalDirection)
        }
    }

    private func handleDirectionalInput(direction: KeyboardDirection) {
        if let onSwipe = callbacks.onSwipe {
            onSwipe(direction)
        } else if direction == .center {
            callbacks.onTap?()
        } else if let onSwipeReturn = callbacks.onSwipeReturn {
            onSwipeReturn(direction)
        } else {
            callbacks.onTap?()
        }
    }

    private func resetGestureState() {
        timestampedPositions.removeAll(keepingCapacity: false)
        absoluteStartPosition = .zero
        isActive = false
    }
}
