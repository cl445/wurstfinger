//
//  SmartTouchResolver.swift
//  Wurstfinger
//
//  Probabilistic key selection and touch correction for improved accuracy
//  when keys are not hit cleanly.
//

import CoreGraphics
import Foundation

// MARK: - Key Hit Candidate

/// Represents a candidate key with its probability score
struct KeyHitCandidate {
    let row: Int
    let column: Int
    let probability: Double
    let distanceToCenter: CGFloat
}

// MARK: - Smart Touch Resolver

/// Resolves ambiguous touch inputs using probabilistic key selection
/// and movement-based correction
struct SmartTouchResolver {

    // MARK: - Configuration

    struct Config {
        /// Base vertical offset correction (users tend to hit above their target)
        let verticalOffset: CGFloat
        /// Standard deviation for Gaussian probability (relative to key size)
        let gaussianSigmaRatio: CGFloat
        /// How much to weight gesture direction in key selection (0-1)
        let gestureDirectionWeight: Double
        /// Minimum probability to consider a key as candidate
        let minProbability: Double
        /// Enable adaptive learning of user's touch patterns
        let enableAdaptiveLearning: Bool

        static let `default` = Config(
            verticalOffset: 6,
            gaussianSigmaRatio: 0.4,
            gestureDirectionWeight: 0.3,
            minProbability: 0.1,
            enableAdaptiveLearning: true
        )
    }

    private let config: Config
    private var userOffsets: [String: CGPoint] = [:]  // Per-key learned offsets

    init(config: Config = .default) {
        self.config = config
    }

    // MARK: - Main Resolution Method

    /// Resolves which key was intended based on touch location and gesture
    /// - Parameters:
    ///   - touchPoint: The raw touch location relative to keyboard
    ///   - keyGrid: 2D array of key frames (rows x columns)
    ///   - gestureDirection: The detected swipe direction (if any)
    ///   - gestureConfidence: Confidence in the gesture detection (0-1)
    /// - Returns: The most likely intended key position (row, column)
    func resolveKey(
        touchPoint: CGPoint,
        keyGrid: [[CGRect]],
        gestureDirection: KeyboardDirection? = nil,
        gestureConfidence: Double = 1.0
    ) -> (row: Int, column: Int)? {
        // Apply base offset correction
        let correctedPoint = applyBaseOffset(touchPoint)

        // Find all candidate keys with their probabilities
        var candidates: [KeyHitCandidate] = []

        for (rowIndex, row) in keyGrid.enumerated() {
            for (colIndex, keyFrame) in row.enumerated() {
                let probability = calculateKeyProbability(
                    point: correctedPoint,
                    keyFrame: keyFrame,
                    row: rowIndex,
                    column: colIndex
                )

                if probability >= config.minProbability {
                    let center = CGPoint(
                        x: keyFrame.midX,
                        y: keyFrame.midY
                    )
                    candidates.append(KeyHitCandidate(
                        row: rowIndex,
                        column: colIndex,
                        probability: probability,
                        distanceToCenter: correctedPoint.distance(to: center)
                    ))
                }
            }
        }

        guard !candidates.isEmpty else { return nil }

        // If we have gesture information, adjust probabilities
        if let direction = gestureDirection, direction != .center {
            candidates = adjustProbabilitiesForGesture(
                candidates: candidates,
                gestureDirection: direction,
                gestureConfidence: gestureConfidence,
                keyGrid: keyGrid
            )
        }

        // Return the candidate with highest probability
        let best = candidates.max(by: { $0.probability < $1.probability })
        return best.map { ($0.row, $0.column) }
    }

    // MARK: - Probability Calculation

    /// Calculates the probability that a touch was intended for a specific key
    private func calculateKeyProbability(
        point: CGPoint,
        keyFrame: CGRect,
        row: Int,
        column: Int
    ) -> Double {
        let center = CGPoint(x: keyFrame.midX, y: keyFrame.midY)

        // Apply any learned offset for this key
        let keyId = "\(row)_\(column)"
        var adjustedPoint = point
        if let offset = userOffsets[keyId] {
            adjustedPoint = CGPoint(
                x: point.x - offset.x,
                y: point.y - offset.y
            )
        }

        // Calculate distance to key center
        let distance = adjustedPoint.distance(to: center)

        // Gaussian probability based on distance
        let sigma = min(keyFrame.width, keyFrame.height) * config.gaussianSigmaRatio
        let probability = exp(-(distance * distance) / (2 * sigma * sigma))

        // Bonus if touch is inside the key frame
        let insideBonus: Double = keyFrame.contains(adjustedPoint) ? 1.2 : 1.0

        return min(1.0, probability * insideBonus)
    }

    /// Adjusts probabilities based on gesture direction
    private func adjustProbabilitiesForGesture(
        candidates: [KeyHitCandidate],
        gestureDirection: KeyboardDirection,
        gestureConfidence: Double,
        keyGrid: [[CGRect]]
    ) -> [KeyHitCandidate] {
        // The gesture direction tells us something about the intended key:
        // If swiping right, the user likely didn't mean the rightmost key
        // (because there would be no room to swipe)

        let oppositeDirection = opposite(of: gestureDirection)

        return candidates.map { candidate in
            var adjustedProbability = candidate.probability

            // Check if this key has a neighbor in the swipe direction
            let hasNeighborInSwipeDir = hasNeighbor(
                row: candidate.row,
                column: candidate.column,
                direction: gestureDirection,
                gridSize: (rows: keyGrid.count, columns: keyGrid[0].count)
            )

            // If the key doesn't have a neighbor in the swipe direction,
            // it's less likely to be the intended key for that swipe
            if !hasNeighborInSwipeDir {
                adjustedProbability *= (1 - config.gestureDirectionWeight * gestureConfidence)
            }

            // Conversely, if touch was near the edge opposite to swipe direction,
            // the actual target might be the neighbor
            let hasNeighborOpposite = hasNeighbor(
                row: candidate.row,
                column: candidate.column,
                direction: oppositeDirection,
                gridSize: (rows: keyGrid.count, columns: keyGrid[0].count)
            )

            if hasNeighborOpposite && candidate.distanceToCenter > 20 {
                // Touch was off-center, might have meant the neighbor
                adjustedProbability *= 0.9
            }

            return KeyHitCandidate(
                row: candidate.row,
                column: candidate.column,
                probability: adjustedProbability,
                distanceToCenter: candidate.distanceToCenter
            )
        }
    }

    // MARK: - Offset Correction

    /// Applies the base vertical offset correction
    private func applyBaseOffset(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x,
            y: point.y + config.verticalOffset
        )
    }

    // MARK: - Adaptive Learning

    /// Records a confirmed key hit for adaptive learning
    mutating func recordConfirmedHit(
        touchPoint: CGPoint,
        confirmedKey: (row: Int, column: Int),
        keyFrame: CGRect
    ) {
        guard config.enableAdaptiveLearning else { return }

        let keyId = "\(confirmedKey.row)_\(confirmedKey.column)"
        let center = CGPoint(x: keyFrame.midX, y: keyFrame.midY)
        let correctedPoint = applyBaseOffset(touchPoint)

        let error = CGPoint(
            x: correctedPoint.x - center.x,
            y: correctedPoint.y - center.y
        )

        // Running average of errors
        let alpha: CGFloat = 0.1  // Learning rate
        if let existing = userOffsets[keyId] {
            userOffsets[keyId] = CGPoint(
                x: existing.x * (1 - alpha) + error.x * alpha,
                y: existing.y * (1 - alpha) + error.y * alpha
            )
        } else {
            userOffsets[keyId] = CGPoint(
                x: error.x * alpha,
                y: error.y * alpha
            )
        }
    }

    /// Resets learned offsets
    mutating func resetLearning() {
        userOffsets.removeAll()
    }

    // MARK: - Helper Methods

    private func hasNeighbor(
        row: Int,
        column: Int,
        direction: KeyboardDirection,
        gridSize: (rows: Int, columns: Int)
    ) -> Bool {
        let (dr, dc) = directionOffset(direction)
        let newRow = row + dr
        let newCol = column + dc

        return newRow >= 0 && newRow < gridSize.rows &&
               newCol >= 0 && newCol < gridSize.columns
    }

    private func directionOffset(_ direction: KeyboardDirection) -> (row: Int, col: Int) {
        switch direction {
        case .center: return (0, 0)
        case .up: return (-1, 0)
        case .down: return (1, 0)
        case .left: return (0, -1)
        case .right: return (0, 1)
        case .upLeft: return (-1, -1)
        case .upRight: return (-1, 1)
        case .downLeft: return (1, -1)
        case .downRight: return (1, 1)
        }
    }

    private func opposite(of direction: KeyboardDirection) -> KeyboardDirection {
        switch direction {
        case .center: return .center
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        case .upLeft: return .downRight
        case .upRight: return .downLeft
        case .downLeft: return .upRight
        case .downRight: return .upLeft
        }
    }
}

// MARK: - Touch Correction Helpers

extension SmartTouchResolver {

    /// Determines if a touch is near the edge of a key
    static func isNearEdge(
        point: CGPoint,
        keyFrame: CGRect,
        threshold: CGFloat = 10
    ) -> (edge: KeyboardDirection, distance: CGFloat)? {
        let center = CGPoint(x: keyFrame.midX, y: keyFrame.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y

        let halfWidth = keyFrame.width / 2
        let halfHeight = keyFrame.height / 2

        // Check which edge is closest
        var closestEdge: KeyboardDirection = .center
        var minDistance: CGFloat = .greatestFiniteMagnitude

        // Right edge
        let rightDist = halfWidth - dx
        if rightDist < minDistance && rightDist >= 0 {
            minDistance = rightDist
            closestEdge = .right
        }

        // Left edge
        let leftDist = halfWidth + dx
        if leftDist < minDistance && leftDist >= 0 {
            minDistance = leftDist
            closestEdge = .left
        }

        // Bottom edge
        let bottomDist = halfHeight - dy
        if bottomDist < minDistance && bottomDist >= 0 {
            minDistance = bottomDist
            closestEdge = .down
        }

        // Top edge
        let topDist = halfHeight + dy
        if topDist < minDistance && topDist >= 0 {
            minDistance = topDist
            closestEdge = .up
        }

        if minDistance < threshold {
            return (closestEdge, minDistance)
        }

        return nil
    }

    /// Suggests a corrected key based on touch location and swipe direction
    static func suggestKeyCorrection(
        originalKey: (row: Int, column: Int),
        touchPoint: CGPoint,
        keyFrame: CGRect,
        swipeDirection: KeyboardDirection,
        gridSize: (rows: Int, columns: Int)
    ) -> (row: Int, column: Int)? {
        // If touch is near edge and swipe goes away from that edge,
        // the user might have meant the adjacent key

        guard let (edge, _) = isNearEdge(point: touchPoint, keyFrame: keyFrame) else {
            return nil
        }

        // Check if swipe direction is opposite to the edge
        let oppositeEdge: KeyboardDirection
        switch edge {
        case .up: oppositeEdge = .down
        case .down: oppositeEdge = .up
        case .left: oppositeEdge = .right
        case .right: oppositeEdge = .left
        default: return nil
        }

        // If swiping away from the edge, suggest the neighbor key
        if swipeDirection == oppositeEdge ||
           isAdjacentDirection(swipeDirection, to: oppositeEdge) {
            let (dr, dc) = directionOffsetStatic(edge)
            let newRow = originalKey.row + dr
            let newCol = originalKey.column + dc

            if newRow >= 0 && newRow < gridSize.rows &&
               newCol >= 0 && newCol < gridSize.columns {
                return (newRow, newCol)
            }
        }

        return nil
    }

    private static func isAdjacentDirection(
        _ dir1: KeyboardDirection,
        to dir2: KeyboardDirection
    ) -> Bool {
        let adjacent: [KeyboardDirection: Set<KeyboardDirection>] = [
            .up: [.upLeft, .upRight],
            .down: [.downLeft, .downRight],
            .left: [.upLeft, .downLeft],
            .right: [.upRight, .downRight],
            .upLeft: [.up, .left],
            .upRight: [.up, .right],
            .downLeft: [.down, .left],
            .downRight: [.down, .right],
            .center: []
        ]
        return adjacent[dir1]?.contains(dir2) ?? false
    }

    private static func directionOffsetStatic(_ direction: KeyboardDirection) -> (row: Int, col: Int) {
        switch direction {
        case .center: return (0, 0)
        case .up: return (-1, 0)
        case .down: return (1, 0)
        case .left: return (0, -1)
        case .right: return (0, 1)
        case .upLeft: return (-1, -1)
        case .upRight: return (-1, 1)
        case .downLeft: return (1, -1)
        case .downRight: return (1, 1)
        }
    }
}
