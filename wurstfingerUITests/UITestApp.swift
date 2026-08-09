//
//  UITestApp.swift
//  wurstfingerUITests
//
//  Builds the app under test with the launch arguments every UI test needs.
//

import XCTest

enum UITestApp {
    /// Redirects the defaults the app writes to a throwaway suite that the app
    /// wipes on every isolated launch. Every UI launch must carry it: the
    /// settings screens write straight through to the app group the user's own
    /// keyboard reads, and `continueAfterFailure = false` means a mid-test
    /// failure never reaches whatever restore step the test had planned.
    ///
    /// Two things worth knowing before relying on it:
    ///
    /// - It covers `SharedDefaults.store` and, through the same argument, the
    ///   app-private `OnboardingProgress.store` — the checklist tapped in
    ///   `testOnboardingCheckboxesAreToggleable`. Anything that reaches
    ///   `UserDefaults.standard` by a third route is still the tester's own.
    /// - Wiping is the app's job, not the runner's. The runner is its own
    ///   sandboxed process, so the suite it would reach under this name is a
    ///   different file from the app's.
    ///
    /// Mirrors `SharedDefaults.isolatedStoreArgument`. The UI test target cannot
    /// import the app module, so the literal is duplicated here: the app-side
    /// spelling is pinned by `SharedDefaultsIsolationTests`, and that this copy
    /// still *reaches* the app is proven at runtime by
    /// `testLaunchArgumentIsolatesDefaultsFromTheRealStore` — a rename here
    /// compiles and runs, it just silently stops isolating anything.
    static let isolatedDefaultsArgument = "ISOLATED_DEFAULTS"

    /// Pins the app to English regardless of the simulator's locale, for suites
    /// that query localized display text ("Settings", "Language", …).
    static let englishLocaleArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]

    /// Environment variable that opts a run into screenshot generation.
    /// `scripts/lib/simulator-capture.sh` sets it via xcodebuild's
    /// `TEST_RUNNER_` prefix, which xcodebuild forwards to the test runner
    /// with the prefix stripped.
    static let screenshotGenerationVariable = "GENERATE_SCREENSHOTS"

    /// An unlaunched app configured with the isolated store plus `arguments`.
    /// The isolation flag goes first so it can never land between an
    /// `-AppleLanguages` key and its value.
    static func make(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [isolatedDefaultsArgument] + arguments
        return app
    }

    /// Skips the caller unless screenshot generation was requested.
    static func skipUnlessGeneratingScreenshots(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[screenshotGenerationVariable] == "1",
            "Screenshot generation is opt-in — pass TEST_RUNNER_\(screenshotGenerationVariable)=1 (see scripts/README.md)",
            file: file,
            line: line
        )
    }
}
