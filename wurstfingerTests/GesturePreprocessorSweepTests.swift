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
//  Both halves of the admission rule are swept, because they fail
//  independently. The glitch families whose jumps are large sweep the
//  magnitude ceiling: they would be rejected on length alone, so they pass
//  under a direction test of any width — including the half-plane the 45°
//  cone replaced. `aDirectionAdversarialGlitchNeverChangesTheClassification`
//  is the family that needs the cone: its glitches stay inside the velocity
//  budget and are rejected only because they turn too far, so weakening
//  `isSameMovement` back towards a half-plane or a magnitude-only test fails
//  it (measured: 29 and 48 of its 768 shapes reclassify) while every other
//  family here stays green.
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

    /// A glitch that stays *inside* the velocity budget and is rejected only
    /// because it turns too far — the property the direction cone exists for,
    /// and the one no other family here sweeps.
    ///
    /// The base swipes travel 40 or 50 pt per sample, so the budget is 120 or
    /// 150 pt (three times the reference step, itself capped at
    /// `maxJumpDistance`); every glitch is 60–110 pt, i.e. beyond
    /// `maxJumpDistance` — so it reaches the velocity rule at all — and inside
    /// that budget. What has to reject it is the 45° cone, at turns from 50°
    /// (just outside it) to 300°. Swept in both positions, because the
    /// reference differs: a trailing glitch is judged against the step the
    /// accepted path established, a mid-path one against the longer of that
    /// and the raw step leading back to the path.
    ///
    /// Two assertions, because the classification alone is the weaker one: a
    /// glitch can be admitted and still leave the sector intact. The sweep
    /// therefore also requires the filter to *drop* the sample, which is the
    /// cone's property directly.
    ///
    /// A mid-path glitch only reaches the cone while both its raw neighbours
    /// are farther than `maxJumpDistance`. Closer than that, `filterOutliers`
    /// admits it through `nearRawNext` before direction is ever consulted —
    /// a different rule, deliberately, and one the dropped-frame families
    /// sweep. Those shapes would pin nothing here, so they are skipped by
    /// construction rather than silently passing; `skipped` counts them and
    /// the expectations name the number.
    @Test func aDirectionAdversarialGlitchNeverChangesTheClassification() {
        let maxJump = GesturePreprocessorConfig.default.maxJumpDistance
        let preprocessor = GesturePreprocessor(config: .default)
        var mismatches: [String] = []
        var survivors: [String] = []
        var count = 0
        var skipped = 0
        for degrees in stride(from: CGFloat(0), to: 360, by: 45) {
            let expected = KeyGestureRecognizer.gestureType(forDegrees: degrees)
            for gait: CGFloat in [40, 50] {
                let base = straightPath(degrees: degrees, step: gait, samples: 5)
                for jump: CGFloat in [60, 90, 110] {
                    for turn: CGFloat in [50, 60, 75, 90, 120, 180, 240, 300] {
                        let offset = unit(degrees + turn)
                        let displaced = { (anchor: CGPoint) in
                            CGPoint(x: anchor.x + offset.dx * jump, y: anchor.y + offset.dy * jump)
                        }
                        let midGlitch = displaced(base[2])
                        var shapes = [("trailing", base + [displaced(base[4])], displaced(base[4]))]
                        // Only the cone can reject this one; see the doc above.
                        if hypot(midGlitch.x - base[3].x, midGlitch.y - base[3].y) > maxJump {
                            var midPath = base
                            midPath.insert(midGlitch, at: 3)
                            shapes.append(("mid-path", midPath, midGlitch))
                        } else {
                            skipped += 1
                        }
                        for (position, points, glitch) in shapes {
                            count += 1
                            let shape = "\(Int(degrees))° gait \(Int(gait)) \(position) "
                                + "\(Int(jump))pt@+\(Int(turn))°"
                            let actual = classify(points)
                            if actual != expected {
                                mismatches.append("\(shape): \(actual) ≠ \(expected)")
                            }
                            if preprocessor.filterOutliers(points).contains(glitch) {
                                survivors.append(shape)
                            }
                        }
                    }
                }
            }
        }
        #expect(
            mismatches.isEmpty,
            "\(mismatches.count) of \(count) in-budget turns reclassified: \(mismatches.prefix(5))"
        )
        #expect(
            survivors.isEmpty,
            "\(survivors.count) of \(count) in-budget turns survived the filter: \(survivors.prefix(5))"
        )
        #expect(skipped == 16, "\(skipped) mid-path shapes are raw-neighbor admissible, expected 16")
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
