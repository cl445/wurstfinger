//
//  GestureRecognizer.swift
//  Wurstfinger
//
//  Advanced gesture recognition using DTW (Dynamic Time Warping)
//  for robust detection of swipes, return-swipes, and circular gestures.
//

import CoreGraphics
import Foundation

// MARK: - Gesture Recognition Result

/// Result of gesture recognition with confidence score
struct GestureRecognitionResult {
    let gestureType: GestureType
    let direction: KeyboardDirection
    let circularDirection: KeyboardCircularDirection?
    let confidence: Double

    enum GestureType {
        case tap
        case swipe
        case swipeReturn
        case circular
    }
}

// MARK: - Advanced Gesture Recognizer

/// DTW-based gesture recognizer for robust recognition of all gesture types
struct AdvancedGestureRecognizer {

    // MARK: - Configuration

    struct Config {
        /// Number of points to resample gestures to
        let resampleCount: Int
        /// Minimum confidence threshold to accept a gesture
        let minConfidence: Double
        /// Minimum movement to consider as non-tap
        let minSwipeLength: CGFloat
        /// Weight for temporal consistency in DTW
        let temporalWeight: Double
        /// Sakoe-Chiba band width for DTW optimization
        let dtwBandWidth: Int
        /// Jitter filter threshold
        let jitterThreshold: CGFloat

        static let `default` = Config(
            resampleCount: 32,
            minConfidence: 0.6,
            minSwipeLength: 30,
            temporalWeight: 0.3,
            dtwBandWidth: 32,  // Full flexibility - no band restriction
            jitterThreshold: 3
        )
    }

    private let config: Config
    private let templates: GestureTemplates

    init(config: Config = .default) {
        self.config = config
        self.templates = GestureTemplates(resampleCount: config.resampleCount)
    }

    // MARK: - Main Recognition Method

    /// Recognizes a gesture from a sequence of points
    func recognize(
        positions: [CGPoint],
        aspectRatio: CGFloat = 1.0
    ) -> GestureRecognitionResult {
        // Filter jitter
        let filtered = filterJitter(positions, threshold: config.jitterThreshold)

        guard filtered.count >= 2 else {
            return GestureRecognitionResult(
                gestureType: .tap,
                direction: .center,
                circularDirection: nil,
                confidence: 1.0
            )
        }

        let maxMagnitude = filtered.map { $0.magnitude() }.max() ?? 0

        // Check if it's a tap
        if maxMagnitude < config.minSwipeLength {
            return GestureRecognitionResult(
                gestureType: .tap,
                direction: .center,
                circularDirection: nil,
                confidence: 1.0
            )
        }

        // Normalize for aspect ratio
        let aspectNormalized = normalizeForAspectRatio(filtered, aspectRatio: aspectRatio)

        // Normalize to unit size (max magnitude = 1.0) for fair template comparison
        let unitNormalized = normalizeToUnitSize(aspectNormalized)

        // Resample to fixed number of points
        let resampled = resample(unitNormalized, count: config.resampleCount)

        // Pure DTW: match against ALL templates, best score wins
        return recognizeWithDTW(resampled)
    }

    // MARK: - Pure DTW Recognition

    /// Matches against all templates and returns the best match
    private func recognizeWithDTW(_ resampled: [CGPoint]) -> GestureRecognitionResult {
        var bestResult = GestureRecognitionResult(
            gestureType: .tap,
            direction: .center,
            circularDirection: nil,
            confidence: 0
        )
        var bestScore: Double = .infinity
        var bestType = ""

        // Collect all scores for debugging
        var allScores: [(String, Double)] = []

        // Test all 8 swipe directions
        for direction in KeyboardDirection.allCases where direction != .center {
            let template = templates.swipeTemplate(for: direction)
            let score = dtw(resampled, template)
            allScores.append(("S-\(direction)", score))

            if score < bestScore {
                bestScore = score
                bestType = "swipe-\(direction)"
                bestResult = GestureRecognitionResult(
                    gestureType: .swipe,
                    direction: direction,
                    circularDirection: nil,
                    confidence: scoreToConfidence(score)
                )
            }
        }

        // Test all 8 swipe-return directions
        for direction in KeyboardDirection.allCases where direction != .center {
            let template = templates.swipeReturnTemplate(for: direction)
            let score = dtw(resampled, template)
            allScores.append(("R-\(direction)", score))

            if score < bestScore {
                bestScore = score
                bestType = "return-\(direction)"
                bestResult = GestureRecognitionResult(
                    gestureType: .swipeReturn,
                    direction: direction,
                    circularDirection: nil,
                    confidence: scoreToConfidence(score)
                )
            }
        }

        // Test circular (clockwise and counter-clockwise)
        let cwTemplate = templates.circularTemplate(clockwise: true)
        let cwScore = dtw(resampled, cwTemplate)
        allScores.append(("CW", cwScore))
        if cwScore < bestScore {
            bestScore = cwScore
            bestType = "circular-CW"
            bestResult = GestureRecognitionResult(
                gestureType: .circular,
                direction: .center,
                circularDirection: .clockwise,
                confidence: scoreToConfidence(cwScore)
            )
        }

        let ccwTemplate = templates.circularTemplate(clockwise: false)
        let ccwScore = dtw(resampled, ccwTemplate)
        allScores.append(("CCW", ccwScore))
        if ccwScore < bestScore {
            bestScore = ccwScore
            bestType = "circular-CCW"
            bestResult = GestureRecognitionResult(
                gestureType: .circular,
                direction: .center,
                circularDirection: .counterclockwise,
                confidence: scoreToConfidence(ccwScore)
            )
        }

        // Log top 3 scores for debugging
        let sorted = allScores.sorted { $0.1 < $1.1 }
        let top3 = sorted.prefix(3).map { "\($0.0):\(String(format: "%.1f", $0.1))" }.joined(separator: " ")
        GestureDebugLog.log("→ \(bestType) | \(top3)")
        GestureDebugLog.savePath(resampled)

        return bestResult
    }

    // MARK: - DTW Algorithm

    /// Dynamic Time Warping with Sakoe-Chiba band optimization
    private func dtw(_ s: [CGPoint], _ t: [CGPoint]) -> Double {
        let n = s.count
        let m = t.count
        let band = config.dtwBandWidth

        var dp = Array(repeating: Array(repeating: Double.infinity, count: m + 1), count: n + 1)
        dp[0][0] = 0

        for i in 1...n {
            let jStart = max(1, i - band)
            let jEnd = min(m, i + band)

            for j in jStart...jEnd {
                let cost = s[i - 1].distance(to: t[j - 1])
                dp[i][j] = cost + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
            }
        }

        return dp[n][m]
    }

    // MARK: - Helper Methods

    /// Filters out small jittery movements
    private func filterJitter(_ positions: [CGPoint], threshold: CGFloat) -> [CGPoint] {
        guard positions.count > 2 else { return positions }

        var filtered: [CGPoint] = [positions[0]]

        for i in 1..<positions.count {
            let last = filtered.last!
            let current = positions[i]

            if current.distance(to: last) >= threshold {
                filtered.append(current)
            }
        }

        // Always include the last point
        if let last = positions.last, filtered.last != last {
            filtered.append(last)
        }

        return filtered
    }

    /// Normalizes points for non-square aspect ratio
    private func normalizeForAspectRatio(_ positions: [CGPoint], aspectRatio: CGFloat) -> [CGPoint] {
        positions.map { point in
            CGPoint(x: point.x / aspectRatio, y: point.y)
        }
    }

    /// Normalizes points so max magnitude = 1.0 (for fair template comparison)
    private func normalizeToUnitSize(_ positions: [CGPoint]) -> [CGPoint] {
        let maxMag = positions.map { $0.magnitude() }.max() ?? 1.0
        guard maxMag > 0 else { return positions }

        return positions.map { point in
            CGPoint(x: point.x / maxMag, y: point.y / maxMag)
        }
    }

    /// Resamples a path to a fixed number of equally-spaced points
    private func resample(_ positions: [CGPoint], count: Int) -> [CGPoint] {
        guard positions.count >= 2 else { return positions }

        let totalLength = pathLength(positions)
        let interval = totalLength / Double(count - 1)

        var resampled: [CGPoint] = [positions[0]]
        var accumulatedDistance: Double = 0
        var currentIndex = 1

        while resampled.count < count && currentIndex < positions.count {
            let prev = positions[currentIndex - 1]
            let curr = positions[currentIndex]
            let segmentLength = prev.distance(to: curr)

            if accumulatedDistance + segmentLength >= interval {
                let ratio = (interval - accumulatedDistance) / segmentLength
                let newPoint = CGPoint(
                    x: prev.x + ratio * (curr.x - prev.x),
                    y: prev.y + ratio * (curr.y - prev.y)
                )
                resampled.append(newPoint)
                accumulatedDistance = 0
            } else {
                accumulatedDistance += segmentLength
                currentIndex += 1
            }
        }

        // Ensure we have exactly count points
        while resampled.count < count {
            resampled.append(positions.last!)
        }

        return resampled
    }

    /// Calculates the total length of a path
    private func pathLength(_ positions: [CGPoint]) -> Double {
        var length: Double = 0
        for i in 1..<positions.count {
            length += positions[i - 1].distance(to: positions[i])
        }
        return length
    }

    /// Converts DTW score to confidence value (0-1)
    private func scoreToConfidence(_ score: Double) -> Double {
        // Lower score = better match = higher confidence
        // Using exponential decay
        let normalizedScore = score / Double(config.resampleCount * 10)
        return exp(-normalizedScore)
    }
}

// MARK: - Gesture Templates

/// Pre-computed templates for gesture matching (all normalized to unit size)
struct GestureTemplates {
    private let resampleCount: Int

    init(resampleCount: Int) {
        self.resampleCount = resampleCount
    }

    /// Generates a linear swipe template for a direction (normalized: max magnitude = 1.0)
    func swipeTemplate(for direction: KeyboardDirection) -> [CGPoint] {
        let vector = unitVector(for: direction)
        // Goes from (0,0) to direction vector (magnitude 1.0)
        return (0..<resampleCount).map { i in
            let t = CGFloat(i) / CGFloat(resampleCount - 1)
            return CGPoint(x: vector.x * t, y: vector.y * t)
        }
    }

    /// Generates a return swipe template (out and back, normalized: max magnitude = 1.0)
    func swipeReturnTemplate(for direction: KeyboardDirection) -> [CGPoint] {
        let vector = unitVector(for: direction)
        let halfCount = resampleCount / 2

        var points: [CGPoint] = []

        // Out phase: (0,0) to direction vector
        for i in 0..<halfCount {
            let t = CGFloat(i) / CGFloat(halfCount - 1)
            points.append(CGPoint(x: vector.x * t, y: vector.y * t))
        }

        // Return phase: direction vector back to (0,0)
        for i in 0..<(resampleCount - halfCount) {
            let t = 1.0 - CGFloat(i) / CGFloat(resampleCount - halfCount - 1)
            points.append(CGPoint(x: vector.x * t, y: vector.y * t))
        }

        return points
    }

    /// Generates a circular template (normalized: max magnitude = 1.0)
    func circularTemplate(clockwise: Bool) -> [CGPoint] {
        let direction: CGFloat = clockwise ? 1 : -1

        // Circle starting at origin, going in specified direction
        // Max magnitude is 1.0 (at the far point of the circle)
        let points = (0..<resampleCount).map { i -> CGPoint in
            let angle = direction * 2 * .pi * CGFloat(i) / CGFloat(resampleCount - 1)
            return CGPoint(
                x: 0.5 * sin(angle),
                y: 0.5 * (1 - cos(angle))
            )
        }

        // Normalize to unit size
        let maxMag = points.map { sqrt($0.x * $0.x + $0.y * $0.y) }.max() ?? 1.0
        return points.map { CGPoint(x: $0.x / maxMag, y: $0.y / maxMag) }
    }

    /// Returns unit vector for a direction (magnitude = 1.0)
    private func unitVector(for direction: KeyboardDirection) -> CGPoint {
        switch direction {
        case .center: return .zero
        case .up: return CGPoint(x: 0, y: -1)
        case .down: return CGPoint(x: 0, y: 1)
        case .left: return CGPoint(x: -1, y: 0)
        case .right: return CGPoint(x: 1, y: 0)
        case .upLeft: return CGPoint(x: -0.707, y: -0.707)
        case .upRight: return CGPoint(x: 0.707, y: -0.707)
        case .downLeft: return CGPoint(x: -0.707, y: 0.707)
        case .downRight: return CGPoint(x: 0.707, y: 0.707)
        }
    }
}
