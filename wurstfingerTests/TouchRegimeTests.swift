//
//  TouchRegimeTests.swift
//  WurstfingerTests
//
//  Tests for derivePosture partition + hysteresis (spec §3.1).
//

import Foundation
import Testing
@testable import WurstfingerApp

struct TouchRegimeTests {
    private let t = PostureThresholds.default // narrowScale 0.55, offsetMargin 0.18, hysteresis 0.05

    // MARK: - Nominal partition (no hysteresis)

    @Test func wideCenteredIsTwoThumb() {
        #expect(PostureResolver.derivePosture(scale: 0.70, position: 0.5) == .twoThumb)
    }

    @Test func narrowLeftIsOneThumbLeft() {
        #expect(PostureResolver.derivePosture(scale: 0.40, position: 0.25) == .oneThumbLeft)
    }

    @Test func narrowRightIsOneThumbRight() {
        #expect(PostureResolver.derivePosture(scale: 0.40, position: 0.75) == .oneThumbRight)
    }

    @Test func narrowCenteredDefaultsToTwoThumb() {
        // The "schmal & mittig" case: Default to twoThumb (hand unknown).
        #expect(PostureResolver.derivePosture(scale: 0.40, position: 0.5) == .twoThumb)
    }

    // MARK: - Hysteresis

    @Test func hysteresisKeepsCurrentSideNearBoundary() {
        // pos 0.34 is just right of the nominal left boundary (0.32) → nominally
        // twoThumb, but staying in oneThumbLeft keeps it left (boundary 0.37).
        #expect(PostureResolver.derivePosture(scale: 0.40, position: 0.34) == .twoThumb)
        #expect(PostureResolver.derivePosture(scale: 0.40, position: 0.34, previous: .oneThumbLeft) == .oneThumbLeft)
    }

    @Test func hysteresisFlipsOncePastBand() {
        // pos 0.40 is past the sticky left boundary (0.37) → flips to twoThumb.
        #expect(PostureResolver.derivePosture(scale: 0.40, position: 0.40, previous: .oneThumbLeft) == .twoThumb)
    }

    @Test func hysteresisResistsEnteringFromTwoThumb() {
        // pos 0.30 nominally left (< 0.32), but from twoThumb entering requires
        // clearly past the tightened boundary (0.27) → stays twoThumb.
        #expect(PostureResolver.derivePosture(scale: 0.40, position: 0.30) == .oneThumbLeft)
        #expect(PostureResolver.derivePosture(scale: 0.40, position: 0.30, previous: .twoThumb) == .twoThumb)
    }

    // MARK: - Regime key

    @Test func regimeKeyIsStable() {
        let r = TouchRegime(orientation: .portrait, posture: .oneThumbRight)
        #expect(r.key == "portrait.oneThumbRight")
    }
}
