//
//  Vector2D.swift
//  Wurstfinger
//
//  A type-safe 2D vector for geometric calculations.
//  Improves readability over using CGPoint for vector math.
//

import CoreGraphics

/// A 2D vector for geometric calculations.
/// Unlike CGPoint, Vector2D is semantically a vector (direction + magnitude),
/// making code more readable and self-documenting.
struct Vector2D: Equatable {
    let x: CGFloat
    let y: CGFloat

    // MARK: - Initializers

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    /// Creates a vector from one point to another
    init(from start: CGPoint, to end: CGPoint) {
        self.x = end.x - start.x
        self.y = end.y - start.y
    }

    /// Creates a vector from a point relative to an origin (default: .zero)
    init(point: CGPoint, relativeTo origin: CGPoint = .zero) {
        self.x = point.x - origin.x
        self.y = point.y - origin.y
    }

    // MARK: - Static Vectors

    static let zero = Vector2D(x: 0, y: 0)

    // MARK: - Magnitude & Normalization

    /// The length (magnitude) of the vector
    var magnitude: CGFloat {
        sqrt(x * x + y * y)
    }

    /// The squared magnitude (avoids sqrt for performance in comparisons)
    var magnitudeSquared: CGFloat {
        x * x + y * y
    }

    /// Returns a unit vector (magnitude = 1) in the same direction.
    /// Returns zero vector if magnitude is zero.
    var normalized: Vector2D {
        let mag = magnitude
        guard mag > 0 else { return .zero }
        return Vector2D(x: x / mag, y: y / mag)
    }

    // MARK: - Angle

    /// The angle of the vector in radians (from positive x-axis, counterclockwise)
    var angle: CGFloat {
        atan2(y, x)
    }

    // MARK: - Vector Operations

    /// Dot product with another vector
    /// Dot product = |a||b|cos(θ), useful for finding angle between vectors
    func dot(_ other: Vector2D) -> CGFloat {
        x * other.x + y * other.y
    }

    /// Cross product (z-component of 3D cross product where z=0)
    /// Positive = other is counterclockwise from self
    /// Negative = other is clockwise from self
    /// Magnitude = |a||b|sin(θ), useful for finding signed area
    func cross(_ other: Vector2D) -> CGFloat {
        x * other.y - y * other.x
    }

    /// Angle to another vector in radians (signed, positive = counterclockwise)
    func angle(to other: Vector2D) -> CGFloat {
        atan2(cross(other), dot(other))
    }

    /// Distance to another vector (treating both as position vectors)
    func distance(to other: Vector2D) -> CGFloat {
        let dx = other.x - x
        let dy = other.y - y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Transformations

    /// Rotates the vector by the given angle (in radians)
    func rotated(by angle: CGFloat) -> Vector2D {
        let cos = CoreGraphics.cos(angle)
        let sin = CoreGraphics.sin(angle)
        return Vector2D(
            x: x * cos - y * sin,
            y: x * sin + y * cos
        )
    }

    /// Projects this vector onto another vector
    func projected(onto other: Vector2D) -> Vector2D {
        let dotProduct = dot(other)
        let otherMagSq = other.magnitudeSquared
        guard otherMagSq > 0 else { return .zero }
        let scalar = dotProduct / otherMagSq
        return Vector2D(x: other.x * scalar, y: other.y * scalar)
    }

    /// Returns the component of this vector perpendicular to another vector
    func perpendicular(to other: Vector2D) -> Vector2D {
        let proj = projected(onto: other)
        return Vector2D(x: x - proj.x, y: y - proj.y)
    }

    // MARK: - Conversion

    /// Converts to CGPoint (for use with UIKit/CoreGraphics APIs)
    var asCGPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - Operators

extension Vector2D {
    static func + (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        Vector2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        Vector2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: Vector2D, rhs: CGFloat) -> Vector2D {
        Vector2D(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func * (lhs: CGFloat, rhs: Vector2D) -> Vector2D {
        Vector2D(x: lhs * rhs.x, y: lhs * rhs.y)
    }

    static func / (lhs: Vector2D, rhs: CGFloat) -> Vector2D {
        Vector2D(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    static prefix func - (vector: Vector2D) -> Vector2D {
        Vector2D(x: -vector.x, y: -vector.y)
    }
}

// Note: CGPoint extensions (asVector, vector(to:)) are now in GeometryUtils.swift

// MARK: - CustomStringConvertible

extension Vector2D: CustomStringConvertible {
    var description: String {
        "Vector2D(x: \(String(format: "%.2f", x)), y: \(String(format: "%.2f", y)))"
    }
}
