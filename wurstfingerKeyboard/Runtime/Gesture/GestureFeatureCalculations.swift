//
//  GestureFeatureCalculations.swift
//  Wurstfinger
//
//  Helper functions for gesture feature extraction.
//  Extracted from GestureFeatures.extract() to improve readability and testability.
//

import CoreGraphics

// MARK: - Gesture Feature Calculation Helpers

/// Namespace for gesture feature calculation functions.
/// These are pure functions that take input and return a result,
/// making them easy to test in isolation.
enum GestureCalculations {
    // MARK: - Path Metrics

    /// Calculates the total path length (sum of distances between consecutive points)
    static func pathLength(of points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }

        var length: CGFloat = 0
        for i in 1 ..< points.count {
            length += points[i - 1].distance(to: points[i])
        }
        return length
    }

    /// Calculates the chord length (direct distance from start to end)
    static func chordLength(of points: [CGPoint]) -> CGFloat {
        guard let first = points.first, let last = points.last else { return 0 }
        return first.distance(to: last)
    }

    /// Finds the bounding box of a set of points
    static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }

        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y

        for point in points.dropFirst() {
            if point.x < minX { minX = point.x } else if point.x > maxX { maxX = point.x }
            if point.y < minY { minY = point.y } else if point.y > maxY { maxY = point.y }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Calculates the centroid (geometric center) of a set of points
    static func centroid(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }

        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }

        return CGPoint(
            x: sumX / CGFloat(points.count),
            y: sumY / CGFloat(points.count)
        )
    }

    // MARK: - Displacement Analysis

    /// Result of max displacement calculation
    struct MaxDisplacementResult {
        let distance: CGFloat
        let point: CGPoint
        let index: Int
        /// Progress (0.0-1.0) indicating where in the path the max occurred
        let progress: CGFloat
    }

    /// Finds the point with maximum displacement from the start
    static func maxDisplacement(in points: [CGPoint]) -> MaxDisplacementResult {
        guard let start = points.first, points.count >= 2 else {
            return MaxDisplacementResult(distance: 0, point: .zero, index: 0, progress: 0)
        }

        var maxDist: CGFloat = 0
        var maxPoint = start
        var maxIndex = 0

        for (index, point) in points.enumerated() {
            let dist = start.distance(to: point)
            if dist > maxDist {
                maxDist = dist
                maxPoint = point
                maxIndex = index
            }
        }

        let progress = CGFloat(maxIndex) / CGFloat(points.count - 1)

        return MaxDisplacementResult(
            distance: maxDist,
            point: maxPoint,
            index: maxIndex,
            progress: progress
        )
    }

    // MARK: - Angular Analysis

    /// Calculates the total angular span around the centroid
    /// Positive = clockwise, Negative = counterclockwise
    static func angularSpan(of points: [CGPoint], around centroid: CGPoint) -> CGFloat {
        guard points.count >= 2 else { return 0 }

        var totalAngle: CGFloat = 0

        for i in 1 ..< points.count {
            let prev = Vector2D(point: points[i - 1], relativeTo: centroid)
            let curr = Vector2D(point: points[i], relativeTo: centroid)
            totalAngle += prev.angle(to: curr)
        }

        return totalAngle
    }

    // MARK: - Circularity Analysis

    /// Calculates how circular a path is (0-1, where 1 = perfect circle)
    /// Based on coefficient of variation of radii from centroid
    static func circularity(of points: [CGPoint], centroid: CGPoint) -> CGFloat {
        guard !points.isEmpty else { return 0 }

        let radii = points.map { $0.distance(to: centroid) }
        let meanRadius = radii.reduce(0, +) / CGFloat(radii.count)

        guard meanRadius > 0 else { return 0 }

        var varianceSum: CGFloat = 0
        for r in radii {
            let diff = r - meanRadius
            varianceSum += diff * diff
        }

        let stdDev = sqrt(varianceSum / CGFloat(radii.count))
        let coefficientOfVariation = stdDev / meanRadius

        // Invert and clamp to 0-1 range
        return max(0, min(1, 1 - coefficientOfVariation))
    }

    /// Calculates path separation (how far apart mirrored points are)
    /// High value = spiral, Low value = return swipe
    static func pathSeparation(of points: [CGPoint], maxDisplacement: CGFloat) -> CGFloat {
        guard points.count >= 2, maxDisplacement > 0 else { return 0 }

        let comparisons = min(points.count / 2, 10)
        guard comparisons > 0 else { return 0 }

        var mirrorDistanceSum: CGFloat = 0
        for i in 0 ..< comparisons {
            let earlyPoint = points[i]
            let latePoint = points[points.count - 1 - i]
            mirrorDistanceSum += earlyPoint.distance(to: latePoint)
        }

        let avgMirrorDistance = mirrorDistanceSum / CGFloat(comparisons)
        return avgMirrorDistance / maxDisplacement
    }

    /// Calculates turn consistency (how consistently the path turns in one direction)
    /// 1.0 = all turns same direction (circle), ~0.5 = mixed directions (return swipe)
    ///
    /// `turnThreshold` is the minimum turn **angle** in radians (default ~8.6°)
    /// for a segment pair to count as a turn. Using the angle keeps the cutoff
    /// scale-invariant; a raw cross product has magnitude `|v1||v2|sin θ` (px²),
    /// so a fixed cross threshold would make the effective angle depend on
    /// segment length (large gestures count nearly every wobble, tiny ones none).
    static func turnConsistency(of points: [CGPoint], turnThreshold: CGFloat = 0.15) -> CGFloat {
        guard points.count >= 3 else { return 1.0 }

        var cwCount = 0
        var ccwCount = 0

        for i in 1 ..< (points.count - 1) {
            let v1 = Vector2D(from: points[i - 1], to: points[i])
            let v2 = Vector2D(from: points[i], to: points[i + 1])
            // Skip degenerate segments — turn angle is undefined for zero length.
            guard v1.magnitudeSquared > 0, v2.magnitudeSquared > 0 else { continue }
            let turn = v1.angle(to: v2) // signed radians: + = CCW, - = CW

            if turn > turnThreshold {
                ccwCount += 1
            } else if turn < -turnThreshold {
                cwCount += 1
            }
        }

        let totalTurns = cwCount + ccwCount
        guard totalTurns > 0 else { return 1.0 }

        return CGFloat(max(cwCount, ccwCount)) / CGFloat(totalTurns)
    }

    /// Calculates oriented compactness (width/length along principal axis)
    /// 1.0 = square, 0 = narrow line
    static func orientedCompactness(of points: [CGPoint], principalAngle: CGFloat) -> CGFloat {
        guard let start = points.first else { return 0 }

        let cosA = cos(principalAngle)
        let sinA = sin(principalAngle)

        var minPara: CGFloat = 0, maxPara: CGFloat = 0
        var minPerp: CGFloat = 0, maxPerp: CGFloat = 0

        for p in points {
            let dx = p.x - start.x
            let dy = p.y - start.y

            // Project onto principal axis (parallel) and perpendicular axis
            let para = dx * cosA + dy * sinA
            let perp = -dx * sinA + dy * cosA

            minPara = min(minPara, para)
            maxPara = max(maxPara, para)
            minPerp = min(minPerp, perp)
            maxPerp = max(maxPerp, perp)
        }

        let axisLength = maxPara - minPara
        let axisWidth = maxPerp - minPerp

        guard axisLength > 0 else { return 0 }
        return axisWidth / axisLength
    }
}

// Note: CGPoint extensions (distance, magnitude, asVector) are defined in GeometryUtils.swift
// Note: Vector2D type is defined in Vector2D.swift
