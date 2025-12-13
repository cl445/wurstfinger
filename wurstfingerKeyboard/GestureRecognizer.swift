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
            dtwBandWidth: 5,
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

        // Classify gesture type
        let gestureType = classifyGestureType(filtered)

        // Normalize for aspect ratio
        let normalized = normalizeForAspectRatio(filtered, aspectRatio: aspectRatio)

        // Resample to fixed number of points
        let resampled = resample(normalized, count: config.resampleCount)

        // Match against templates based on gesture type
        switch gestureType {
        case .circular:
            return recognizeCircular(resampled, original: filtered)
        case .swipeReturn:
            return recognizeSwipeReturn(resampled)
        case .swipe, .tap:
            return recognizeSwipe(resampled)
        }
    }

    // MARK: - Gesture Type Classification

    private func classifyGestureType(_ positions: [CGPoint]) -> GestureRecognitionResult.GestureType {
        guard let first = positions.first, let last = positions.last else {
            return .tap
        }

        let maxOffset = positions.max(by: { $0.magnitude() < $1.magnitude() }) ?? .zero
        let maxMagnitude = maxOffset.magnitude()
        let finalMagnitude = last.magnitude()

        // Calculate enclosed area (for circular detection)
        let signedArea = calculateSignedArea(positions)
        let areaThreshold = config.minSwipeLength * config.minSwipeLength * 0.5

        // Check for circular gesture
        if abs(signedArea) > areaThreshold && maxMagnitude > config.minSwipeLength {
            // Verify it's actually circular by checking if it closes
            let distanceToStart = last.distance(to: first)
            if distanceToStart < maxMagnitude * 0.5 {
                return .circular
            }
        }

        // Check for return swipe (finger returned close to start)
        let returnThreshold = config.minSwipeLength * 0.7
        if finalMagnitude < returnThreshold && maxMagnitude >= config.minSwipeLength {
            return .swipeReturn
        }

        // Otherwise it's a regular swipe
        if maxMagnitude >= config.minSwipeLength {
            return .swipe
        }

        return .tap
    }

    // MARK: - Swipe Recognition

    private func recognizeSwipe(_ positions: [CGPoint]) -> GestureRecognitionResult {
        var bestDirection: KeyboardDirection = .center
        var bestScore: Double = .infinity

        for direction in KeyboardDirection.allCases where direction != .center {
            let template = templates.swipeTemplate(for: direction)
            let score = dtw(positions, template)

            if score < bestScore {
                bestScore = score
                bestDirection = direction
            }
        }

        // Also try dominant direction approach for comparison
        let dominantDir = dominantDirection(positions)
        let dominantTemplate = templates.swipeTemplate(for: dominantDir)
        let dominantScore = dtw(positions, dominantTemplate)

        // Use whichever is more confident
        if dominantScore < bestScore * 0.9 {
            bestDirection = dominantDir
            bestScore = dominantScore
        }

        let confidence = scoreToConfidence(bestScore)

        return GestureRecognitionResult(
            gestureType: .swipe,
            direction: bestDirection,
            circularDirection: nil,
            confidence: confidence
        )
    }

    // MARK: - Swipe Return Recognition

    private func recognizeSwipeReturn(_ positions: [CGPoint]) -> GestureRecognitionResult {
        var bestDirection: KeyboardDirection = .center
        var bestScore: Double = .infinity

        for direction in KeyboardDirection.allCases where direction != .center {
            let template = templates.swipeReturnTemplate(for: direction)
            let score = dtw(positions, template)

            if score < bestScore {
                bestScore = score
                bestDirection = direction
            }
        }

        // Use peak direction as fallback validation
        let peakDir = peakDirection(positions)
        if peakDir != bestDirection {
            // If DTW and peak disagree, trust peak more for return gestures
            let peakTemplate = templates.swipeReturnTemplate(for: peakDir)
            let peakScore = dtw(positions, peakTemplate)
            if peakScore < bestScore * 1.2 {
                bestDirection = peakDir
                bestScore = peakScore
            }
        }

        let confidence = scoreToConfidence(bestScore)

        return GestureRecognitionResult(
            gestureType: .swipeReturn,
            direction: bestDirection,
            circularDirection: nil,
            confidence: confidence
        )
    }

    // MARK: - Circular Recognition

    private func recognizeCircular(_ positions: [CGPoint], original: [CGPoint]) -> GestureRecognitionResult {
        // Use existing circular detection as it's already robust
        if let circDir = KeyboardGestureRecognizer.circularDirection(
            positions: original,
            circleCompletionTolerance: KeyboardConstants.Gesture.circleCompletionTolerance,
            minSwipeLength: config.minSwipeLength
        ) {
            return GestureRecognitionResult(
                gestureType: .circular,
                direction: .center,
                circularDirection: circDir,
                confidence: 0.9
            )
        }

        // DTW fallback for incomplete circles
        let cwTemplate = templates.circularTemplate(clockwise: true)
        let ccwTemplate = templates.circularTemplate(clockwise: false)

        let cwScore = dtw(positions, cwTemplate)
        let ccwScore = dtw(positions, ccwTemplate)

        let isClockwise = cwScore < ccwScore
        let bestScore = min(cwScore, ccwScore)
        let confidence = scoreToConfidence(bestScore)

        // If confidence is too low, fall back to swipe
        if confidence < config.minConfidence {
            return recognizeSwipe(positions)
        }

        return GestureRecognitionResult(
            gestureType: .circular,
            direction: .center,
            circularDirection: isClockwise ? .clockwise : .counterclockwise,
            confidence: confidence
        )
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

    /// Calculates the signed area enclosed by a path (for circular detection)
    private func calculateSignedArea(_ positions: [CGPoint]) -> CGFloat {
        guard positions.count >= 3 else { return 0 }

        var area: CGFloat = 0
        for i in 0..<positions.count {
            let j = (i + 1) % positions.count
            area += positions[i].x * positions[j].y
            area -= positions[j].x * positions[i].y
        }
        return area / 2
    }

    /// Determines the dominant direction using weighted segments
    private func dominantDirection(_ positions: [CGPoint]) -> KeyboardDirection {
        guard positions.count >= 2 else { return .center }

        // Weight later points more heavily
        var weightedX: CGFloat = 0
        var weightedY: CGFloat = 0
        var totalWeight: CGFloat = 0

        for i in 1..<positions.count {
            let weight = CGFloat(i) / CGFloat(positions.count)
            let dx = positions[i].x - positions[i - 1].x
            let dy = positions[i].y - positions[i - 1].y

            weightedX += dx * weight
            weightedY += dy * weight
            totalWeight += weight
        }

        let avgX = weightedX / totalWeight
        let avgY = weightedY / totalWeight

        return KeyboardDirection.direction(
            for: CGSize(width: avgX * CGFloat(positions.count), height: avgY * CGFloat(positions.count)),
            tolerance: 0
        )
    }

    /// Determines direction at peak displacement (for return gestures)
    private func peakDirection(_ positions: [CGPoint]) -> KeyboardDirection {
        let peak = positions.max(by: { $0.magnitude() < $1.magnitude() }) ?? .zero
        return KeyboardDirection.direction(
            for: CGSize(width: peak.x, height: peak.y),
            tolerance: 0
        )
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

/// Pre-computed templates for gesture matching
struct GestureTemplates {
    private let resampleCount: Int

    init(resampleCount: Int) {
        self.resampleCount = resampleCount
    }

    /// Generates a linear swipe template for a direction
    func swipeTemplate(for direction: KeyboardDirection) -> [CGPoint] {
        let vector = unitVector(for: direction)
        return (0..<resampleCount).map { i in
            let t = CGFloat(i) / CGFloat(resampleCount - 1)
            return CGPoint(x: vector.x * t * 50, y: vector.y * t * 50)
        }
    }

    /// Generates a return swipe template (out and back)
    func swipeReturnTemplate(for direction: KeyboardDirection) -> [CGPoint] {
        let vector = unitVector(for: direction)
        let halfCount = resampleCount / 2

        var points: [CGPoint] = []

        // Out phase
        for i in 0..<halfCount {
            let t = CGFloat(i) / CGFloat(halfCount - 1)
            points.append(CGPoint(x: vector.x * t * 50, y: vector.y * t * 50))
        }

        // Return phase
        for i in 0..<(resampleCount - halfCount) {
            let t = 1.0 - CGFloat(i) / CGFloat(resampleCount - halfCount - 1)
            points.append(CGPoint(x: vector.x * t * 50, y: vector.y * t * 50))
        }

        return points
    }

    /// Generates a circular template
    func circularTemplate(clockwise: Bool) -> [CGPoint] {
        let radius: CGFloat = 30
        let direction: CGFloat = clockwise ? 1 : -1

        return (0..<resampleCount).map { i in
            let angle = direction * 2 * .pi * CGFloat(i) / CGFloat(resampleCount - 1)
            return CGPoint(
                x: radius * sin(angle),
                y: radius * (1 - cos(angle))
            )
        }
    }

    /// Returns unit vector for a direction
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
