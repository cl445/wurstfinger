//
//  GestureTrailGeometry.swift
//  Wurstfinger
//
//  Turns recorded touch positions into the tapered ribbon the swipe trail
//  is drawn as. Pure functions, no view state.
//

import CoreGraphics
import Foundation
import SwiftUI

/// Path construction for the swipe trail.
///
/// The trail is built as a single closed outline rather than as a stroked
/// polyline: a translucent stroke made of overlapping round-capped segments
/// accumulates alpha at every joint and at every place the path crosses
/// itself, which shows up as dark blotches exactly where the finger changed
/// direction. One filled contour has uniform alpha everywhere.
enum GestureTrailGeometry {
    /// Resamples `points` through a uniform Catmull-Rom spline.
    ///
    /// A fast flick only produces a handful of drag samples, and drawing those
    /// directly renders as a visible polyline. The spline passes through every
    /// original sample, so this rounds the corners without moving the trail
    /// off the path the finger actually took.
    static func smoothed(
        _ points: [CGPoint],
        subdivisions: Int = KeyboardConstants.GestureTrail.smoothingSubdivisions
    ) -> [CGPoint] {
        guard points.count > 2, subdivisions > 1 else { return points }
        let last = points.count - 1
        var result: [CGPoint] = []
        result.reserveCapacity(last * subdivisions + 1)
        for index in 0 ..< last {
            // Duplicate the endpoints so the first and last segment get the
            // control points the spline needs without extrapolating past them.
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, last)]
            for step in 0 ..< subdivisions {
                let t = CGFloat(step) / CGFloat(subdivisions)
                result.append(interpolate(p0, p1, p2, p3, t: t))
            }
        }
        result.append(points[last])
        return result
    }

    /// Half the ribbon width at `progress`, which runs 0 at the tail to 1 at
    /// the point where the taper is complete.
    ///
    /// The exponent is below 1, so the ribbon reaches nearly full width early
    /// and thins only near its very end. That is what makes it read as a
    /// stroke trailing the finger rather than as a wedge.
    static func halfWidth(
        atProgress progress: CGFloat,
        headWidth: CGFloat,
        taperExponent: CGFloat = KeyboardConstants.GestureTrail.taperExponent
    ) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        return headWidth / 2 * pow(clamped, taperExponent)
    }

    /// Builds the closed, tapered outline through `points`, pointed at the
    /// tail and rounded at the finger. Returns an empty path for anything too
    /// short or too thin to draw.
    ///
    /// The taper is measured **along the path**, over at most
    /// `headWidth * taperLengthFactor`. Tapering by index fraction instead
    /// would stretch the wedge across the whole trail, so a long cursor slide
    /// would render as one thin spike rather than as a stroke with a short
    /// tail — the opposite of how the system trail behaves.
    static func ribbon(
        through points: [CGPoint],
        headWidth: CGFloat,
        taperExponent: CGFloat = KeyboardConstants.GestureTrail.taperExponent,
        taperLengthFactor: CGFloat = KeyboardConstants.GestureTrail.taperLengthFactor
    ) -> Path {
        var path = Path()
        guard points.count >= 2, headWidth > 0 else { return path }

        let last = points.count - 1
        let distances = cumulativeDistances(along: points)
        // A path shorter than the nominal taper simply tapers across all of
        // itself, so a quick flick still reaches full width at the finger.
        let taperSpan = min(headWidth * taperLengthFactor, distances[last])

        var leftEdge: [CGPoint] = []
        var rightEdge: [CGPoint] = []
        leftEdge.reserveCapacity(points.count)
        rightEdge.reserveCapacity(points.count)

        // Carried forward so a degenerate segment (two coincident points, which
        // the spline can produce) reuses the last known orientation instead of
        // collapsing the ribbon to zero width there.
        var normal = CGVector(dx: 0, dy: 0)
        for (index, point) in points.enumerated() {
            if let tangent = unitTangent(at: index, in: points) {
                normal = CGVector(dx: -tangent.dy, dy: tangent.dx)
            }
            let progress = taperSpan > 0 ? distances[index] / taperSpan : 1
            let half = halfWidth(
                atProgress: progress,
                headWidth: headWidth,
                taperExponent: taperExponent
            )
            leftEdge.append(CGPoint(x: point.x + normal.dx * half, y: point.y + normal.dy * half))
            rightEdge.append(CGPoint(x: point.x - normal.dx * half, y: point.y - normal.dy * half))
        }

        path.move(to: leftEdge[0])
        for point in leftEdge.dropFirst() {
            path.addLine(to: point)
        }
        appendHeadCap(to: &path, head: points[last], normal: normal, radius: headWidth / 2)
        for point in rightEdge.reversed() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    /// Arc length from the tail to each point, in the same order.
    static func cumulativeDistances(along points: [CGPoint]) -> [CGFloat] {
        var distances: [CGFloat] = [0]
        distances.reserveCapacity(points.count)
        for index in 1 ..< max(points.count, 1) {
            let previous = points[index - 1]
            let point = points[index]
            distances.append(distances[index - 1] + hypot(point.x - previous.x, point.y - previous.y))
        }
        return distances
    }

    // MARK: - Private

    /// Closes the ribbon around the finger with a semicircle.
    ///
    /// Drawn as explicit segments rather than `Path.addArc`, which needs the
    /// caller to reason about sweep direction in a y-down coordinate system —
    /// getting that backwards produces a cap on the wrong side of the head.
    /// Kept as part of the one closed contour so there is no second subpath
    /// whose winding could punch a hole through the ribbon under a non-zero
    /// fill.
    private static func appendHeadCap(
        to path: inout Path,
        head: CGPoint,
        normal: CGVector,
        radius: CGFloat,
        segments: Int = 8
    ) {
        guard radius > 0, normal.dx != 0 || normal.dy != 0 else { return }
        // The normal is the tangent rotated by +90°, so sweeping from its angle
        // by -180° passes through the direction the finger is moving in — i.e.
        // the cap bulges ahead of the head, not back over the ribbon.
        let start = atan2(normal.dy, normal.dx)
        for step in 1 ..< segments {
            let angle = start - .pi * CGFloat(step) / CGFloat(segments)
            path.addLine(to: CGPoint(
                x: head.x + cos(angle) * radius,
                y: head.y + sin(angle) * radius
            ))
        }
    }

    /// Unit direction of travel at `index`, from its neighbours. Nil when the
    /// neighbours coincide and no direction can be derived.
    private static func unitTangent(at index: Int, in points: [CGPoint]) -> CGVector? {
        let previous = points[max(index - 1, 0)]
        let next = points[min(index + 1, points.count - 1)]
        let dx = next.x - previous.x
        let dy = next.y - previous.y
        let length = hypot(dx, dy)
        guard length > .ulpOfOne else { return nil }
        return CGVector(dx: dx / length, dy: dy / length)
    }

    /// Uniform Catmull-Rom evaluation between `p1` and `p2`.
    private static func interpolate(
        _ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, t: CGFloat
    ) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t
        func axis(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
            0.5 * (2 * b
                + (-a + c) * t
                + (2 * a - 5 * b + 4 * c - d) * t2
                + (-a + 3 * b - 3 * c + d) * t3)
        }
        return CGPoint(
            x: axis(p0.x, p1.x, p2.x, p3.x),
            y: axis(p0.y, p1.y, p2.y, p3.y)
        )
    }
}
