//
//  ReachSurfaceTests.swift
//  WurstfingerTests
//
//  Tests for the ridge-WLS reach-surface fit + linear solver (spec §4.2 Step 2).
//

import Foundation
import Testing
@testable import WurstfingerApp

struct ReachSurfaceTests {
    @Test func solvesKnownLinearSystem() {
        // [2 1; 1 3] x = [5; 10] → x = [1; 3]
        let x = ReachSurfaceFitter.solve([[2, 1], [1, 3]], [5, 10])
        #expect(x != nil)
        #expect(abs((x?[0] ?? 0) - 1.0) < 1e-9)
        #expect(abs((x?[1] ?? 0) - 3.0) < 1e-9)
    }

    @Test func recoversLinearPlaneWithSmallRidge() {
        // target = 0.20 + 0.10·u − 0.05·v
        let pts = [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0), (0.5, 0.5)].map {
            SurfacePoint(u: $0.0, v: $0.1, target: 0.20 + 0.10 * $0.0 - 0.05 * $0.1, weight: 100)
        }
        let s = ReachSurfaceFitter.fit(points: pts, basis: .linear, lambda: 0.001)
        #expect(abs(s.evaluate(u: 0.0, v: 0.0) - 0.20) < 0.01)
        #expect(abs(s.evaluate(u: 1.0, v: 0.0) - 0.30) < 0.01)
        #expect(abs(s.evaluate(u: 0.0, v: 1.0) - 0.15) < 0.01)
    }

    @Test func zeroPointsGivesFlatZeroSurface() {
        let s = ReachSurfaceFitter.fit(points: [], basis: .bilinear, lambda: 8)
        #expect(abs(s.evaluate(u: 0.3, v: 0.7)) < 1e-9)
    }

    @Test func ridgeShrinksTowardZeroWithSparseData() {
        // A single point with strong ridge → prediction pulled well below target.
        let pts = [SurfacePoint(u: 0.5, v: 0.5, target: 1.0, weight: 1)]
        let s = ReachSurfaceFitter.fit(points: pts, basis: .bilinear, lambda: 8)
        #expect(s.evaluate(u: 0.5, v: 0.5) < 0.5)
    }

    @Test func largeWeightOverridesRidge() {
        // With weight ≫ lambda the surface follows the data.
        let pts = [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)].map {
            SurfacePoint(u: $0.0, v: $0.1, target: 0.25, weight: 10000)
        }
        let s = ReachSurfaceFitter.fit(points: pts, basis: .bilinear, lambda: 8)
        #expect(abs(s.evaluate(u: 0.5, v: 0.5) - 0.25) < 0.02)
    }
}
