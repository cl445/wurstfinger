//
//  TouchRegimeTests.swift
//  WurstfingerTests
//
//  Tests for the explicit posture setting mapping + regime key (spec §3.1/§6.3).
//

import Foundation
import Testing
@testable import WurstfingerApp

struct TouchRegimeTests {
    // MARK: - Explicit posture from the stored setting

    @Test func missingSettingFallsBackToDefault() {
        #expect(PostureClass(settingValue: nil) == .oneThumbRight)
        #expect(PostureClass.defaultDeclared == .oneThumbRight)
    }

    @Test func unknownSettingFallsBackToDefault() {
        #expect(PostureClass(settingValue: "garbage") == .oneThumbRight)
    }

    @Test func storedValueRoundTrips() {
        for posture in PostureClass.allCases {
            #expect(PostureClass(settingValue: posture.rawValue) == posture)
        }
    }

    // MARK: - Split-surface flag (§3.2)

    @Test func onlyTwoThumbUsesSplitSurface() {
        #expect(PostureClass.twoThumb.usesSplitSurface)
        #expect(!PostureClass.oneThumbLeft.usesSplitSurface)
        #expect(!PostureClass.oneThumbRight.usesSplitSurface)
    }

    // MARK: - Regime key

    @Test func regimeKeyIsStable() {
        let r = TouchRegime(orientation: .portrait, posture: .oneThumbRight)
        #expect(r.key == "portrait.oneThumbRight")
    }
}
