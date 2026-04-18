//
//  GeometryUtils.swift
//  Wurstfinger
//
//  Central location for CGPoint and geometry-related extensions.
//  Consolidates extensions that were previously scattered across multiple files.
//

import CoreGraphics

// MARK: - CGPoint Extensions

extension CGPoint {
    /// Distance to another point using Euclidean distance formula
    func distance(to other: CGPoint) -> CGFloat {
        let dx = other.x - x
        let dy = other.y - y
        return sqrt(dx * dx + dy * dy)
    }

    /// Magnitude (distance from origin)
    func magnitude() -> CGFloat {
        sqrt(x * x + y * y)
    }

    /// Creates a Vector2D from this point (relative to origin)
    var asVector: Vector2D {
        Vector2D(x: x, y: y)
    }

    /// Creates a vector from this point to another point
    func vector(to other: CGPoint) -> Vector2D {
        Vector2D(from: self, to: other)
    }
}

// MARK: - CGSize Extensions

extension CGSize {
    /// Aspect ratio (width / height)
    var aspectRatio: CGFloat {
        guard height > 0 else { return 1 }
        return width / height
    }
}

// MARK: - CGRect Extensions

extension CGRect {
    /// Center point of the rectangle
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    /// Aspect ratio of the rectangle (width / height)
    var aspectRatio: CGFloat {
        guard height > 0 else { return 1 }
        return width / height
    }
}
