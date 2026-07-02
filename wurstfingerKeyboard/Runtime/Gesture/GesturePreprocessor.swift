//
//  GesturePreprocessor.swift
//  Wurstfinger
//
//  Gesture Recognition Pipeline
//  ============================
//
//  This module implements gesture preprocessing and feature extraction for
//  distinguishing between taps, swipes, return-swipes, and circular gestures.
//
//  ## Data Flow
//
//  ```
//  Touch Events (KeyboardButton)
//       │
//       ▼
//  Raw CGPoint[] ──► GesturePreprocessor.preprocess()
//       │                    │
//       │              ┌─────┴─────┐
//       │              ▼           ▼
//       │         filterJitter  filterOutliers
//       │              │           │
//       │              ▼           ▼
//       │         normalizeAspectRatio
//       │              │
//       │              ▼
//       │         smoothSavitzkyGolay
//       │              │
//       ▼              ▼
//  Cleaned CGPoint[] ──► GestureFeatures.extract()
//       │
//       ▼
//  GestureFeatures { pathLength, maxDisplacement, angularSpan, ... }
//       │
//       ▼
//  Classification: isTap, isReturn, isCircular, direction
//  ```
//
//  ## Preprocessing Steps
//
//  1. **Jitter Filter**: Removes points too close together (< jitterThreshold)
//     - Prevents noise from finger micro-movements
//
//  2. **Outlier Filter**: Removes impossible jumps (> maxJumpDistance)
//     - Handles touch glitches and multitouch interference
//
//  3. **Aspect Ratio Normalization**: Divides X by aspect ratio
//     - Makes horizontal and vertical movements comparable on non-square keys
//
//  4. **Savitzky-Golay Smoothing**: Polynomial smoothing filter
//     - Preserves gesture shape while reducing noise
//     - Uses pre-computed coefficients for efficiency
//
//  ## Feature Extraction
//
//  Geometric features extracted from the cleaned path:
//  - `pathLength`: Total distance traveled
//  - `chordLength`: Direct distance from start to end
//  - `maxDisplacement`: Furthest point from start
//  - `maxDisplacementProgress`: Where in path (0-1) max occurred
//  - `returnRatio`: chordLength / pathLength (low = returned to start)
//  - `angularSpan`: Total angle swept around centroid (radians)
//  - `circularity`: How uniform the radii are (0-1)
//  - `pathSeparation`: Distance between mirrored points (early vs late)
//
//  ## Classification Logic
//
//  - **Tap**: maxDisplacement < minSwipeLength (~55% key height)
//  - **Return-swipe**: returnRatio < 0.5 AND maxDisplacement in middle of path
//  - **Circular**: angularSpan > 270° AND pathSeparation > 0.5 (spiral, not return)
//  - **Swipe**: Everything else, direction from maxDisplacementAngle
//
//  Note: Default key height is 54pt, so minSwipeLength (30pt) ≈ 55% of key height.
//
//  ## Key Insight: Spiral vs Return-Swipe
//
//  Both can have high angularSpan, but:
//  - Spiral: Early points (start) far from late points (end) → high pathSeparation
//  - Return: Path comes back, early ≈ late points → low pathSeparation
//

import CoreGraphics
import Foundation

// MARK: - Configuration

struct GesturePreprocessorConfig {
    /// Minimum distance between consecutive points (jitter threshold)
    let jitterThreshold: CGFloat
    /// Maximum jump distance to consider valid (outlier threshold)
    let maxJumpDistance: CGFloat
    /// Window size for Savitzky-Golay filter (must be odd)
    let smoothingWindow: Int
    /// Polynomial order for Savitzky-Golay filter
    let smoothingOrder: Int
    /// Aspect ratio of the key (width/height) for normalizing coordinates
    let aspectRatio: CGFloat

    // MARK: - Default Values

    static let defaultJitterThreshold: CGFloat = 3.0
    static let defaultMaxJumpDistance: CGFloat = 50.0
    static let defaultSmoothingWindow: Int = 5

    // MARK: - UserDefaults Keys

    static let jitterThresholdKey = "gesture.jitterThreshold"
    static let maxJumpDistanceKey = "gesture.maxJumpDistance"
    static let smoothingWindowKey = "gesture.smoothingWindow"

    static let `default` = GesturePreprocessorConfig(
        jitterThreshold: defaultJitterThreshold,
        maxJumpDistance: defaultMaxJumpDistance,
        smoothingWindow: defaultSmoothingWindow,
        smoothingOrder: 2,
        aspectRatio: 1.0
    )

    /// Loads config from SharedDefaults with fallback to defaults.
    /// Non-finite values (NaN, Inf) are replaced with defaults.
    /// Custom values only apply while expert mode is enabled; when it is off,
    /// the defaults are returned. The stored values are kept so they survive
    /// toggling expert mode off and on again.
    static func fromUserDefaults(store: UserDefaults = SharedDefaults.store) -> GesturePreprocessorConfig {
        guard store.bool(forKey: SettingsKey.expertModeEnabled.rawValue) else { return .default }
        let jitter = finiteCGFloat(from: store, key: jitterThresholdKey, default: defaultJitterThreshold)
        let maxJump = finiteCGFloat(from: store, key: maxJumpDistanceKey, default: defaultMaxJumpDistance)
        return GesturePreprocessorConfig(
            jitterThreshold: jitter,
            maxJumpDistance: maxJump,
            smoothingWindow: validSmoothingWindow(from: store),
            smoothingOrder: 2,
            aspectRatio: 1.0
        )
    }

    /// Reads smoothingWindow from defaults, ensuring it's a positive odd integer.
    private static func validSmoothingWindow(from store: UserDefaults) -> Int {
        let raw = store.object(forKey: smoothingWindowKey) as? Int ?? defaultSmoothingWindow
        let clamped = max(3, raw)
        return clamped.isMultiple(of: 2) ? clamped + 1 : clamped
    }

    private static func finiteCGFloat(from store: UserDefaults, key: String, default defaultValue: CGFloat) -> CGFloat {
        guard store.object(forKey: key) != nil else { return defaultValue }
        let value = CGFloat(store.double(forKey: key))
        return value.isFinite ? value : defaultValue
    }

    /// Creates a config with custom aspect ratio
    func with(aspectRatio: CGFloat) -> GesturePreprocessorConfig {
        GesturePreprocessorConfig(
            jitterThreshold: jitterThreshold,
            maxJumpDistance: maxJumpDistance,
            smoothingWindow: smoothingWindow,
            smoothingOrder: smoothingOrder,
            aspectRatio: aspectRatio
        )
    }
}

// MARK: - Gesture Preprocessor

struct GesturePreprocessor {
    let config: GesturePreprocessorConfig

    init(config: GesturePreprocessorConfig = .default) {
        self.config = config
    }

    /// Main preprocessing pipeline
    func preprocess(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        // Step 1: Jitter filter
        let dejittered = filterJitter(points)

        // Step 2: Outlier filter
        let cleaned = filterOutliers(dejittered)

        // Step 3: Aspect ratio correction (normalize horizontal movement)
        let normalized = normalizeAspectRatio(cleaned)

        // Step 4: Savitzky-Golay smoothing
        return smoothSavitzkyGolay(normalized)
    }

    // MARK: - Step 1: Jitter Filter

    /// Removes points that are too close to the previous point
    func filterJitter(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        var filtered: [CGPoint] = [points[0]]

        for i in 1 ..< points.count {
            // Safe: filtered always has at least one element (initialized with points[0])
            guard let last = filtered.last else { continue }
            let current = points[i]

            if current.distance(to: last) >= config.jitterThreshold {
                filtered.append(current)
            }
        }

        // Always include the last point if different from current last
        if let lastInput = points.last,
           let lastFiltered = filtered.last,
           lastInput.distance(to: lastFiltered) >= 0.1 {
            filtered.append(lastInput)
        }

        return filtered
    }

    // MARK: - Step 2: Outlier Filter

    /// Removes points with physically impossible jumps
    func filterOutliers(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        var filtered: [CGPoint] = [points[0]]

        for i in 1 ..< points.count {
            // Safe: filtered always has at least one element (initialized with points[0])
            guard let prev = filtered.last else { continue }
            let current = points[i]

            let distance = current.distance(to: prev)

            if distance <= config.maxJumpDistance {
                filtered.append(current)
            }
            // Outlier: skip this point
        }

        return filtered
    }

    // MARK: - Step 3: Aspect Ratio Normalization

    /// Normalizes points for non-square aspect ratio
    /// Divides X by aspect ratio so horizontal movement equals vertical movement
    func normalizeAspectRatio(_ points: [CGPoint]) -> [CGPoint] {
        guard config.aspectRatio != 1.0 else { return points }
        return points.map { point in
            CGPoint(x: point.x / config.aspectRatio, y: point.y)
        }
    }

    // MARK: - Step 4: Savitzky-Golay Smoothing

    /// Applies Savitzky-Golay filter to smooth the path while preserving shape
    func smoothSavitzkyGolay(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= config.smoothingWindow else { return points }

        let coefficients = savitzkyGolayCoefficients(
            windowSize: config.smoothingWindow,
            polyOrder: config.smoothingOrder
        )

        let halfWindow = config.smoothingWindow / 2
        var smoothed: [CGPoint] = []

        for i in 0 ..< points.count {
            var sumX: CGFloat = 0
            var sumY: CGFloat = 0

            for j in 0 ..< config.smoothingWindow {
                let idx = i - halfWindow + j
                let clampedIdx = max(0, min(points.count - 1, idx))
                sumX += coefficients[j] * points[clampedIdx].x
                sumY += coefficients[j] * points[clampedIdx].y
            }

            smoothed.append(CGPoint(x: sumX, y: sumY))
        }

        return smoothed
    }

    /// Calculates Savitzky-Golay convolution coefficients
    private func savitzkyGolayCoefficients(windowSize: Int, polyOrder: Int) -> [CGFloat] {
        // Pre-computed coefficients for common cases
        // Window=5, Order=2: [-3, 12, 17, 12, -3] / 35
        // Window=7, Order=2: [-2, 3, 6, 7, 6, 3, -2] / 21

        if windowSize == 5 && polyOrder <= 3 {
            return [-3, 12, 17, 12, -3].map { CGFloat($0) / 35.0 }
        } else if windowSize == 7 && polyOrder <= 3 {
            return [-2, 3, 6, 7, 6, 3, -2].map { CGFloat($0) / 21.0 }
        } else if windowSize == 9 && polyOrder <= 3 {
            return [-21, 14, 39, 54, 59, 54, 39, 14, -21].map { CGFloat($0) / 231.0 }
        } else if windowSize == 11 && polyOrder <= 3 {
            return [-36, 9, 44, 69, 84, 89, 84, 69, 44, 9, -36].map { CGFloat($0) / 429.0 }
        }

        // Fallback: uniform weights (simple moving average)
        return Array(repeating: CGFloat(1.0 / Double(windowSize)), count: windowSize)
    }
}

// MARK: - Classification Thresholds

struct GestureClassificationThresholds {
    /// Minimum path length to be considered a swipe (not a tap)
    let minSwipeLength: CGFloat
    /// Maximum return ratio to be considered a return-swipe
    let maxReturnRatio: CGFloat
    /// Range where maxDisplacement should occur for return-swipe (as % of path)
    let returnDisplacementRange: ClosedRange<CGFloat>
    /// Minimum circularity score to be considered circular
    let minCircularity: CGFloat
    /// Minimum angular span (radians) to be considered circular
    let minAngularSpan: CGFloat
    /// Minimum path separation to distinguish spiral from return-swipe
    let minPathSeparation: CGFloat
    /// Minimum turn consistency to be considered circular (1.0 = all same direction)
    let minTurnConsistency: CGFloat
    /// Minimum oriented compactness (width/length) to be considered circular (1.0 = square, 0 = line)
    let minOrientedCompactness: CGFloat

    // MARK: - Default Values

    static let defaultMinSwipeLength: CGFloat = 20
    static let defaultMaxReturnRatio: CGFloat = 0.5
    static let defaultReturnDisplacementStart: CGFloat = 0.2
    static let defaultReturnDisplacementEnd: CGFloat = 0.8
    static let defaultMinCircularity: CGFloat = 0.3
    static let defaultMinAngularSpan: CGFloat = .pi * 1.5 // 270°
    static let defaultMinPathSeparation: CGFloat = 0.5
    static let defaultMinTurnConsistency: CGFloat = 0.8 // 80% turns in same direction
    static let defaultMinOrientedCompactness: CGFloat = 0.4 // width must be at least 40% of length

    // MARK: - UserDefaults Keys

    static let minSwipeLengthKey = "gesture.minSwipeLength"
    static let maxReturnRatioKey = "gesture.maxReturnRatio"
    static let returnDisplacementStartKey = "gesture.returnDisplacementStart"
    static let returnDisplacementEndKey = "gesture.returnDisplacementEnd"
    static let minCircularityKey = "gesture.minCircularity"
    static let minAngularSpanKey = "gesture.minAngularSpan"
    static let minPathSeparationKey = "gesture.minPathSeparation"
    static let minTurnConsistencyKey = "gesture.minTurnConsistency"
    static let minOrientedCompactnessKey = "gesture.minOrientedCompactness"

    static let `default` = GestureClassificationThresholds(
        minSwipeLength: defaultMinSwipeLength,
        maxReturnRatio: defaultMaxReturnRatio,
        returnDisplacementRange: defaultReturnDisplacementStart ... defaultReturnDisplacementEnd,
        minCircularity: defaultMinCircularity,
        minAngularSpan: defaultMinAngularSpan,
        minPathSeparation: defaultMinPathSeparation,
        minTurnConsistency: defaultMinTurnConsistency,
        minOrientedCompactness: defaultMinOrientedCompactness
    )

    /// Loads a finite CGFloat from UserDefaults, falling back to the default
    /// if the key is missing or the stored value is NaN/Inf.
    private static func loadCGFloat(from store: UserDefaults, key: String, default defaultValue: CGFloat) -> CGFloat {
        guard store.object(forKey: key) != nil else { return defaultValue }
        let value = CGFloat(store.double(forKey: key))
        return value.isFinite ? value : defaultValue
    }

    /// Loads thresholds from SharedDefaults with fallback to defaults.
    /// Custom values only apply while expert mode is enabled; when it is off,
    /// the defaults are returned. The stored values are kept so they survive
    /// toggling expert mode off and on again.
    static func fromUserDefaults(store: UserDefaults = SharedDefaults.store) -> GestureClassificationThresholds {
        guard store.bool(forKey: SettingsKey.expertModeEnabled.rawValue) else { return .default }
        let start = loadCGFloat(from: store, key: returnDisplacementStartKey, default: defaultReturnDisplacementStart)
        let end = loadCGFloat(from: store, key: returnDisplacementEndKey, default: defaultReturnDisplacementEnd)
        return GestureClassificationThresholds(
            minSwipeLength: loadCGFloat(from: store, key: minSwipeLengthKey, default: defaultMinSwipeLength),
            maxReturnRatio: loadCGFloat(from: store, key: maxReturnRatioKey, default: defaultMaxReturnRatio),
            returnDisplacementRange: min(start, end) ... max(start, end),
            minCircularity: loadCGFloat(from: store, key: minCircularityKey, default: defaultMinCircularity),
            minAngularSpan: loadCGFloat(from: store, key: minAngularSpanKey, default: defaultMinAngularSpan),
            minPathSeparation: loadCGFloat(from: store, key: minPathSeparationKey, default: defaultMinPathSeparation),
            minTurnConsistency: loadCGFloat(from: store, key: minTurnConsistencyKey, default: defaultMinTurnConsistency),
            minOrientedCompactness: loadCGFloat(from: store, key: minOrientedCompactnessKey, default: defaultMinOrientedCompactness)
        )
    }
}

// MARK: - Gesture Features

struct GestureFeatures {
    /// Thresholds used for classification
    let thresholds: GestureClassificationThresholds

    // Geometric features
    let pathLength: CGFloat
    let chordLength: CGFloat
    let boundingBox: CGRect
    let maxDisplacement: CGFloat
    let maxDisplacementPoint: CGPoint
    let maxDisplacementProgress: CGFloat // 0.0-1.0: where in the path maxDisplacement occurs
    let centroid: CGPoint

    // Ratio features
    let returnRatio: CGFloat // chordLength / pathLength (low = returned to start)
    let aspectRatio: CGFloat // boundingBox width / height

    // Direction features
    let dominantAngle: CGFloat // angle from start to end
    let maxDisplacementAngle: CGFloat // angle from start to max displacement

    // Circularity features
    let angularSpan: CGFloat // total angle traversed (positive = CW, negative = CCW)
    let circularity: CGFloat // how circular (0-1, 1 = perfect circle)
    let pathSeparation: CGFloat // how separated are mirrored points (spiral > 0.5, return < 0.3)
    let turnConsistency: CGFloat // how consistent turn direction is (1.0 = all same direction, 0.5 = half each)
    let orientedCompactness: CGFloat // width/length along principal axis (1.0 = square, 0 = line)

    // Derived classifications (using configurable thresholds)
    var isTap: Bool {
        maxDisplacement < thresholds.minSwipeLength
    }

    /// Return-swipe: maxDisplacement in the middle of the path (not at the end) AND finger returned to start
    var isReturn: Bool {
        let t = thresholds
        // Must have significant movement
        guard maxDisplacement > t.minSwipeLength else { return false }
        // Must have returned close to start (low chord/path ratio)
        guard returnRatio < t.maxReturnRatio else { return false }
        // maxDisplacement should be in the middle of the path, not at the very end
        return t.returnDisplacementRange.contains(maxDisplacementProgress)
    }

    var isCircular: Bool {
        let t = thresholds
        // Require minimum size (2x swipe length) to avoid small wiggles being detected as circles
        // Also require high turn consistency and compactness to distinguish from return swipes
        // (circle: turns consistently one direction AND is not a narrow arc)
        return pathLength > t.minSwipeLength * 2 &&
            circularity > t.minCircularity &&
            abs(angularSpan) > t.minAngularSpan &&
            turnConsistency > t.minTurnConsistency &&
            orientedCompactness > t.minOrientedCompactness
    }

    var isClockwise: Bool {
        angularSpan > 0
    }

    /// Extracts features from preprocessed points.
    /// Uses GestureCalculations helper functions for cleaner, testable code.
    static func extract(from points: [CGPoint], thresholds: GestureClassificationThresholds = .default) -> GestureFeatures {
        guard points.count >= 2 else {
            return GestureFeatures.empty(thresholds: thresholds)
        }

        let start = points[0]
        let end = points[points.count - 1]

        // Use helper functions from GestureCalculations
        let pathLen = GestureCalculations.pathLength(of: points)
        let chordLen = GestureCalculations.chordLength(of: points)
        let bbox = GestureCalculations.boundingBox(of: points)
        let centroid = GestureCalculations.centroid(of: points)

        // Max displacement analysis
        let maxDispResult = GestureCalculations.maxDisplacement(in: points)
        let maxDisp = maxDispResult.distance
        let maxDispPoint = maxDispResult.point
        let maxDispProgress = maxDispResult.progress

        // Angles (simple calculations, kept inline)
        let dominantAngle = atan2(end.y - start.y, end.x - start.x)
        let maxDispAngle = atan2(maxDispPoint.y - start.y, maxDispPoint.x - start.x)

        // Circularity features using helpers
        let angularSpan = GestureCalculations.angularSpan(of: points, around: centroid)
        let circularity = GestureCalculations.circularity(of: points, centroid: centroid)
        let pathSeparation = GestureCalculations.pathSeparation(of: points, maxDisplacement: maxDisp)
        let turnConsistency = GestureCalculations.turnConsistency(of: points)
        let orientedCompactness = GestureCalculations.orientedCompactness(of: points, principalAngle: maxDispAngle)

        // Derived ratios
        let returnRatio = pathLen > 0 ? chordLen / pathLen : 1
        let bboxAspect = bbox.height > 0 ? bbox.width / bbox.height : 1

        return GestureFeatures(
            thresholds: thresholds,
            pathLength: pathLen,
            chordLength: chordLen,
            boundingBox: bbox,
            maxDisplacement: maxDisp,
            maxDisplacementPoint: maxDispPoint,
            maxDisplacementProgress: maxDispProgress,
            centroid: centroid,
            returnRatio: returnRatio,
            aspectRatio: bboxAspect,
            dominantAngle: dominantAngle,
            maxDisplacementAngle: maxDispAngle,
            angularSpan: angularSpan,
            circularity: circularity,
            pathSeparation: pathSeparation,
            turnConsistency: turnConsistency,
            orientedCompactness: orientedCompactness
        )
    }

    static func empty(thresholds: GestureClassificationThresholds = .default) -> GestureFeatures {
        GestureFeatures(
            thresholds: thresholds,
            pathLength: 0,
            chordLength: 0,
            boundingBox: .zero,
            maxDisplacement: 0,
            maxDisplacementPoint: .zero,
            maxDisplacementProgress: 0,
            centroid: .zero,
            returnRatio: 1,
            aspectRatio: 1,
            dominantAngle: 0,
            maxDisplacementAngle: 0,
            angularSpan: 0,
            circularity: 0,
            pathSeparation: 0,
            turnConsistency: 1,
            orientedCompactness: 0
        )
    }
}

// MARK: - Debug Logging

extension GestureFeatures: CustomStringConvertible {
    var description: String {
        """
        GestureFeatures:
          pathLength: \(String(format: "%.1f", pathLength))
          chordLength: \(String(format: "%.1f", chordLength))
          maxDisplacement: \(String(format: "%.1f", maxDisplacement)) @ \(String(format: "%.0f%%", maxDisplacementProgress * 100))
          returnRatio: \(String(format: "%.2f", returnRatio))
          angularSpan: \(String(format: "%.1f°", angularSpan * 180 / .pi))
          circularity: \(String(format: "%.2f", circularity))
          pathSeparation: \(String(format: "%.2f", pathSeparation))
          turnConsistency: \(String(format: "%.2f", turnConsistency))
          orientedCompactness: \(String(format: "%.2f", orientedCompactness))
          isTap: \(isTap), isReturn: \(isReturn), isCircular: \(isCircular)
        """
    }
}
