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

    static let `default` = GesturePreprocessorConfig(
        jitterThreshold: 3.0,
        maxJumpDistance: 50.0,  // Points jumping more than this are outliers
        smoothingWindow: 5,
        smoothingOrder: 2,
        aspectRatio: 1.0
    )

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
        let smoothed = smoothSavitzkyGolay(normalized)

        return smoothed
    }

    // MARK: - Step 1: Jitter Filter

    /// Removes points that are too close to the previous point
    func filterJitter(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        var filtered: [CGPoint] = [points[0]]

        for i in 1..<points.count {
            let last = filtered.last!
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

        for i in 1..<points.count {
            let prev = filtered.last!
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

        for i in 0..<points.count {
            var sumX: CGFloat = 0
            var sumY: CGFloat = 0

            for j in 0..<config.smoothingWindow {
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

    static let `default` = GestureClassificationThresholds(
        minSwipeLength: 30,
        maxReturnRatio: 0.5,
        returnDisplacementRange: 0.2...0.8,
        minCircularity: 0.3,  // Lower threshold to accommodate spirals (varying radii)
        minAngularSpan: .pi * 1.5  // 270°
    )
}

// MARK: - Gesture Features

struct GestureFeatures {
    /// Thresholds used for classification
    static var thresholds = GestureClassificationThresholds.default

    // Geometric features
    let pathLength: CGFloat
    let chordLength: CGFloat
    let boundingBox: CGRect
    let maxDisplacement: CGFloat
    let maxDisplacementPoint: CGPoint
    let maxDisplacementProgress: CGFloat  // 0.0-1.0: where in the path maxDisplacement occurs
    let centroid: CGPoint

    // Ratio features
    let returnRatio: CGFloat  // chordLength / pathLength (low = returned to start)
    let aspectRatio: CGFloat  // boundingBox width / height

    // Direction features
    let dominantAngle: CGFloat      // angle from start to end
    let maxDisplacementAngle: CGFloat  // angle from start to max displacement

    // Circularity features
    let angularSpan: CGFloat    // total angle traversed (positive = CW, negative = CCW)
    let circularity: CGFloat    // how circular (0-1, 1 = perfect circle)
    let pathSeparation: CGFloat // how separated are mirrored points (spiral > 0.5, return < 0.3)

    // Derived classifications (using configurable thresholds)
    var isTap: Bool { maxDisplacement < Self.thresholds.minSwipeLength }

    /// Return-swipe: maxDisplacement in the middle of the path (not at the end) AND finger returned to start
    var isReturn: Bool {
        let t = Self.thresholds
        // Must have significant movement
        guard maxDisplacement > t.minSwipeLength else { return false }
        // Must have returned close to start (low chord/path ratio)
        guard returnRatio < t.maxReturnRatio else { return false }
        // maxDisplacement should be in the middle of the path, not at the very end
        return t.returnDisplacementRange.contains(maxDisplacementProgress)
    }

    var isCircular: Bool {
        let t = Self.thresholds
        // Require minimum size (2x swipe length) to avoid small wiggles being detected as circles
        // Also require high path separation to distinguish from return swipes
        // (spiral: mirrored points far apart, return: mirrored points close together)
        return pathLength > t.minSwipeLength * 2 &&
               circularity > t.minCircularity &&
               abs(angularSpan) > t.minAngularSpan &&
               pathSeparation > 0.5  // mirrored points must be far apart (not a return swipe)
    }

    var isClockwise: Bool { angularSpan > 0 }

    /// Extracts features from preprocessed points
    static func extract(from points: [CGPoint]) -> GestureFeatures {
        guard points.count >= 2 else {
            return GestureFeatures.empty
        }

        let start = points[0]
        let end = points[points.count - 1]

        // Path length
        var pathLen: CGFloat = 0
        for i in 1..<points.count {
            pathLen += points[i - 1].distance(to: points[i])
        }

        // Chord length
        let chordLen = start.distance(to: end)

        // Bounding box
        let xs = points.map { $0.x }
        let ys = points.map { $0.y }
        let minX = xs.min()!
        let maxX = xs.max()!
        let minY = ys.min()!
        let maxY = ys.max()!
        let bbox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // Max displacement from start (and where in the path it occurs)
        var maxDisp: CGFloat = 0
        var maxDispPoint = start
        var maxDispIndex = 0
        for (index, point) in points.enumerated() {
            let dist = start.distance(to: point)
            if dist > maxDisp {
                maxDisp = dist
                maxDispPoint = point
                maxDispIndex = index
            }
        }
        // Progress: 0.0 = start, 1.0 = end
        let maxDispProgress = points.count > 1 ? CGFloat(maxDispIndex) / CGFloat(points.count - 1) : 0

        // Centroid
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        let centroid = CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))

        // Angles
        let dominantAngle = atan2(end.y - start.y, end.x - start.x)
        let maxDispAngle = atan2(maxDispPoint.y - start.y, maxDispPoint.x - start.x)

        // Angular span (sum of angle changes)
        var angularSpan: CGFloat = 0
        for i in 1..<points.count {
            let prev = CGPoint(x: points[i-1].x - centroid.x, y: points[i-1].y - centroid.y)
            let curr = CGPoint(x: points[i].x - centroid.x, y: points[i].y - centroid.y)

            let cross = prev.x * curr.y - prev.y * curr.x
            let dot = prev.x * curr.x + prev.y * curr.y
            angularSpan += atan2(cross, dot)
        }

        // Circularity: based on variance of radii from centroid
        // Perfect circle = all points equidistant from center = low variance
        let radii = points.map { $0.distance(to: centroid) }
        let meanRadius = radii.reduce(0, +) / CGFloat(radii.count)

        var varianceSum: CGFloat = 0
        for r in radii {
            let diff = r - meanRadius
            varianceSum += diff * diff
        }
        let stdDev = sqrt(varianceSum / CGFloat(radii.count))

        // Circularity: 1.0 = perfect circle, 0.0 = very non-circular
        // Using coefficient of variation (stdDev / mean), inverted and clamped
        let coefficientOfVariation = meanRadius > 0 ? stdDev / meanRadius : 1
        let circularity = max(0, min(1, 1 - coefficientOfVariation))

        // Path separation: compare "mirrored" points (early vs late in sequence)
        // Return swipe: early and late points are close (path comes back)
        // Spiral: early and late points are far apart (path doesn't come back)
        let comparisons = min(points.count / 2, 10)
        var mirrorDistanceSum: CGFloat = 0
        if comparisons > 0 {
            for i in 0..<comparisons {
                let earlyPoint = points[i]
                let latePoint = points[points.count - 1 - i]
                mirrorDistanceSum += earlyPoint.distance(to: latePoint)
            }
        }
        let avgMirrorDistance = comparisons > 0 ? mirrorDistanceSum / CGFloat(comparisons) : 0
        let pathSeparation = maxDisp > 0 ? avgMirrorDistance / maxDisp : 0

        // Ratios
        let returnRatio = pathLen > 0 ? chordLen / pathLen : 1
        let bboxAspect = bbox.height > 0 ? bbox.width / bbox.height : 1

        return GestureFeatures(
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
            pathSeparation: pathSeparation
        )
    }

    static let empty = GestureFeatures(
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
        pathSeparation: 0
    )
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
          isTap: \(isTap), isReturn: \(isReturn), isCircular: \(isCircular)
        """
    }
}
