//
//  SharedDefaultsIsolationTests.swift
//  wurstfingerTests
//
//  Tests for the launch-argument contract between SharedDefaults and the UI tests
//

import Foundation
import Testing
@testable import WurstfingerApp

struct SharedDefaultsIsolationTests {
    /// The UI test target cannot import the app module, so
    /// `UITestApp.isolatedDefaultsArgument` repeats this literal. Renaming the
    /// argument without updating that copy would point every UI test launch
    /// back at the real app-group store, silently.
    @Test func isolationArgumentLiteralIsStable() {
        #expect(SharedDefaults.isolatedStoreArgument == "ISOLATED_DEFAULTS")
    }

    @Test func isolationArgumentSelectsThrowawaySuite() {
        let resolved = SharedDefaults.resolvedSuiteName(
            arguments: ["ISOLATED_DEFAULTS", "-AppleLanguages", "(en)"]
        )
        #expect(resolved == SharedDefaults.isolatedSuiteName)
    }

    @Test func plainLaunchKeepsTheAppGroupSuite() {
        #expect(SharedDefaults.resolvedSuiteName(arguments: []) == SharedDefaults.suiteName)
        #expect(SharedDefaults.resolvedSuiteName(arguments: ["SCREENSHOT_MODE"]) == SharedDefaults.suiteName)
    }

    /// The isolated suite must not be an app group (the extension would then
    /// share it) and must not be the host bundle id, which
    /// `UserDefaults(suiteName:)` rejects.
    @Test func isolatedSuiteIsAppLocal() {
        #expect(!SharedDefaults.isolatedSuiteName.hasPrefix("group."))
        #expect(SharedDefaults.isolatedSuiteName != SharedDefaults.suiteName)
        #expect(SharedDefaults.isolatedSuiteName != Bundle.main.bundleIdentifier)
    }
}
