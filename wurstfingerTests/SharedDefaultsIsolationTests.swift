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
    ///
    /// This pins one side of that pair. A rename on the *other* side compiles
    /// and runs happily, which is why the UI target additionally proves the
    /// argument arrives at runtime (`testLaunchArgumentIsolatesDefaultsFromTheRealStore`).
    @Test func isolationArgumentLiteralIsStable() {
        #expect(SharedDefaults.isolatedStoreArgument == "ISOLATED_DEFAULTS")
    }

    /// `SharedDefaults.store` feeds the *resolved* name to `isWipeableSuite`, so
    /// this equality is also what points the launch wipe at the throwaway suite.
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
    /// `UserDefaults(suiteName:)` rejects. An overlap with the app group costs
    /// no data — `isWipeableSuite` refuses that name — but it would silently
    /// stop isolating anything, which is what this pins.
    @Test func isolatedSuiteIsAppLocal() {
        #expect(!SharedDefaults.isolatedSuiteName.hasPrefix("group."))
        #expect(SharedDefaults.isolatedSuiteName != SharedDefaults.suiteName)
        #expect(SharedDefaults.isolatedSuiteName != Bundle.main.bundleIdentifier)
    }

    /// The launch wipe is a `removePersistentDomain` with no undo, compiled into
    /// the app *and* the extension, so it must not depend on two constants
    /// staying different. Converged names have to switch it off rather than aim
    /// it at the user's app group — that is the case the last expectation drives,
    /// since the shipped constants cannot express it.
    @Test func onlyTheThrowawaySuiteIsEverWiped() {
        #expect(SharedDefaults.isWipeableSuite(SharedDefaults.isolatedSuiteName))
        #expect(!SharedDefaults.isWipeableSuite(SharedDefaults.suiteName))
        #expect(!SharedDefaults.isWipeableSuite("group.same", appGroup: "group.same", isolated: "group.same"))
    }

    /// The onboarding checklist is app-private state the UI tests tap directly,
    /// so the same argument has to move it too — and to the very store the
    /// launch wipes, not to some third suite nothing cleans up.
    @Test func isolationArgumentMovesTheOnboardingChecklistToo() {
        let isolated = OnboardingProgress.resolvedStore(arguments: [SharedDefaults.isolatedStoreArgument])
        #expect(isolated === SharedDefaults.store)

        let plain = OnboardingProgress.resolvedStore(arguments: ["-AppleLanguages", "(en)"])
        #expect(plain === UserDefaults.standard)
    }
}
