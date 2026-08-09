//
//  GesturePreprocessorSweepTests.swift
//  WurstfingerTests
//
//  Property sweep over generated touch paths, pinning the two guarantees the
//  velocity-aware outlier filter has to keep in balance: a genuine gesture is
//  never demoted (a fast flick stays a swipe, an ordinary swipe keeps its
//  sector), and a glitch is never promoted (a teleport sample changes no
//  classification, in whatever direction it points).
//
//  The parameters of the velocity rule were originally chosen against an
//  ad-hoc sweep of ~600k synthetic paths that compared three compiled
//  variants of the filter; that harness was never part of the repo, so its
//  "zero regressions" figure could not be re-checked. This file is the
//  repo-resident replacement: a few thousand deterministic paths spanning the
//  same regimes, asserted as properties on every CI run. The individually
//  interesting boundary cases keep their own named tests in
//  `GesturePreprocessorTests` / `GesturePreprocessorRobustnessTests`; this
//  sweep is about the space between them.
//
//  Every family stays deliberately clear of the documented ambiguity bands
//  (steps at jitter scale count as dwell, glitches start beyond
//  maxJumpDistance, flick steps stay under 3x maxJumpDistance): inside those
//  bands the filter's choice is a judgement call the named tests own, and a
//  sweep asserting exact outcomes there would pin coincidences, not intent.
//

import CoreGraphics
import Foundation
import Testing
@testable import WurstfingerApp

struct GesturePreprocessorSweepTests {
    /// Sector-center angles plus offsets safely inside each 45° sector, in
    /// degrees (`atan2` convention: 0 = right, 90 = down). Boundary angles are
    /// pinned exactly by `AngleToGestureTypeTests`; the sweep keeps 12.5° of
    /// margin so it can never flake on the half-open boundaries.
    private static let sectorSafeAngles: [CGFloat] = {
        let centers: [CGFloat] = [0, 45, 90, 135, 180, 225, 270, 315]
        var angles: [CGFloat] = []
        for center in centers {
            let low: CGFloat = center - 10
            angles.append(low < 0 ? low + 360 : low)
            angles.append(center)
            angles.append(center + 10)
        }
        return angles
    }()

    private func classify(_ points: [CGPoint]) -> GestureType {
        KeyGestureRecognizer.classify(positions: points, config: .default, thresholds: .default).gesture
    }

    private func unit(_ degrees: CGFloat) -> CGVector {
        let radians = degrees * .pi / 180
        return CGVector(dx: cos(radians), dy: sin(radians))
    }

    private func straightPath(
        from origin: CGPoint = .zero,
        degrees: CGFloat,
        step: CGFloat,
        samples: Int
    ) -> [CGPoint] {
        let direction = unit(degrees)
        return (0 ..< samples).map {
            CGPoint(
                x: origin.x + direction.dx * step * CGFloat($0),
                y: origin.y + direction.dy * step * CGFloat($0)
            )
        }
    }

    /// A fling whose every inter-sample distance exceeds `maxJumpDistance`
    /// (50pt) must classify as a swipe in the direction it travelled — the
    /// review-2026-08-09 finding-3 regime, across speeds up to just under the
    /// 3x admission ceiling and around the full circle. Three samples is the
    /// floor: a two-point path is the documented origin-jump ambiguity and
    /// deliberately stays a tap.
    @Test func everyStraightFlickAboveTheJumpThresholdKeepsItsSector() {
        var mismatches: [String] = []
        for degrees in Self.sectorSafeAngles {
            let expected = KeyGestureRecognizer.gestureType(forDegrees: degrees)
            for step: CGFloat in [51, 60, 75, 90, 110, 130, 145] {
                for samples in 3 ... 6 {
                    let points = straightPath(degrees: degrees, step: step, samples: samples)
                    let actual = classify(points)
                    if actual != expected {
                        mismatches.append("\(Int(degrees))° step \(Int(step)) n\(samples): \(actual) ≠ \(expected)")
                    }
                }
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.count) of 672 flicks misclassified: \(mismatches.prefix(5))")
    }

    /// An ordinary swipe (steps well under `maxJumpDistance`) must keep its
    /// sector — the regime every real gesture lives in, and the one the first
    /// attempt at the velocity rule regressed. The outlier filter should be a
    /// spectator here; this pins that adding the rescue did not change it.
    @Test func everyOrdinarySwipeKeepsItsSector() {
        var mismatches: [String] = []
        for degrees in Self.sectorSafeAngles {
            let expected = KeyGestureRecognizer.gestureType(forDegrees: degrees)
            for step: CGFloat in [8, 14, 20] {
                for samples in [5, 9] {
                    let points = straightPath(degrees: degrees, step: step, samples: samples)
                    let actual = classify(points)
                    if actual != expected {
                        mismatches.append("\(Int(degrees))° step \(Int(step)) n\(samples): \(actual) ≠ \(expected)")
                    }
                }
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.count) of 144 swipes misclassified: \(mismatches.prefix(5))")
    }

    /// A trailing glitch beyond `maxJumpDistance` must never change what a
    /// path classifies as — neither a dwell (which must stay a tap, whatever
    /// direction the glitch points) nor an ordinary swipe (which must keep its
    /// sector, the shape that flipped under the first, half-plane version of
    /// the velocity rule). The established steps stay at jitter/swipe scale so
    /// the glitch is always outside the 3x-step admission budget; a jump
    /// *inside* that budget is treated as acceleration by design and belongs
    /// to the flick family above.
    @Test func aTrailingGlitchNeverChangesTheClassification() {
        var mismatches: [String] = []
        var count = 0
        // Dwell prefixes along +x (0, 1 or 2 sub-swipe steps), then a glitch.
        for prefixStep: CGFloat in [0, 4, 8] {
            for prefixMoves in 0 ... 2 {
                let prefix = [CGPoint.zero] + straightPath(
                    degrees: 0, step: prefixStep, samples: prefixMoves + 1
                ).dropFirst()
                // Swipe prefixes: a clean rightward swipe before the glitch.
                let bases = [prefix, straightPath(degrees: 0, step: 14, samples: 6)]
                for base in bases {
                    let expected = classify(base)
                    guard let last = base.last else { continue }
                    for glitchDistance: CGFloat in [55, 80, 120, 200] {
                        for degrees in stride(from: CGFloat(0), to: 360, by: 45) {
                            let glitch = CGPoint(
                                x: last.x + unit(degrees).dx * glitchDistance,
                                y: last.y + unit(degrees).dy * glitchDistance
                            )
                            count += 1
                            let actual = classify(base + [glitch])
                            if actual != expected {
                                let shape = "prefixStep \(Int(prefixStep)) moves \(prefixMoves)"
                                let jump = "glitch \(Int(glitchDistance))@\(Int(degrees))°"
                                mismatches.append("\(shape) \(jump): \(actual) ≠ \(expected)")
                            }
                        }
                    }
                }
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.count) of \(count) glitched paths reclassified: \(mismatches.prefix(5))")
    }

    /// A teleport sample in the middle of an ordinary swipe — interference
    /// landing far off the path for one frame — must not change the sector the
    /// swipe classifies into. The teleport is rejected on distance (beyond the
    /// 3x-step budget of a 12pt gait) and the path continues from the sample
    /// before it.
    @Test func aMidPathTeleportNeverChangesTheSector() {
        var mismatches: [String] = []
        var count = 0
        for degrees in stride(from: CGFloat(0), to: 360, by: 45) {
            let base = straightPath(degrees: degrees, step: 12, samples: 8)
            let expected = classify(base)
            for teleportDistance: CGFloat in [60, 120] {
                for relativeDegrees: CGFloat in [90, 180, 315] {
                    let anchor = base[3]
                    let teleport = CGPoint(
                        x: anchor.x + unit(degrees + relativeDegrees).dx * teleportDistance,
                        y: anchor.y + unit(degrees + relativeDegrees).dy * teleportDistance
                    )
                    var points = base
                    points.insert(teleport, at: 4)
                    count += 1
                    let actual = classify(points)
                    if actual != expected {
                        mismatches.append(
                            "\(Int(degrees))° teleport \(Int(teleportDistance))@+\(Int(relativeDegrees))°: \(actual) ≠ \(expected)"
                        )
                    }
                }
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.count) of \(count) teleported swipes reclassified: \(mismatches.prefix(5))")
    }
}
