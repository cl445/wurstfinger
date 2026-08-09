//
//  SharedDefaults.swift
//  Wurstfinger
//
//  Shared UserDefaults utility for app group communication
//

import Foundation

/// Provides centralized access to shared UserDefaults for communication
/// between the main app and keyboard extension
enum SharedDefaults {
    /// The app group identifier shared between the main app and keyboard extension
    static let suiteName = "group.de.akator.wurstfinger.shared"

    /// Launch argument that swaps `store` for a throwaway suite. UI tests pass
    /// it (see `UITestApp`) so a setting they flip — or fail to flip back after
    /// an aborted assertion — never reaches the store the user's own keyboard
    /// reads. Keep the literal in sync with `UITestApp.isolatedDefaultsArgument`.
    static let isolatedStoreArgument = "ISOLATED_DEFAULTS"

    /// Backing suite for `isolatedStoreArgument`. Deliberately not an app group:
    /// it lives in the launched app's own preferences, where the extension —
    /// which never sees the host's launch arguments — cannot pick it up.
    ///
    /// Debug builds wipe it on every isolated launch (see `store`), so each UI
    /// test starts from factory defaults instead of inheriting whatever the
    /// previous run left behind.
    static let isolatedSuiteName = "de.akator.wurstfinger.isolated"

    /// The suite `store` binds to for a given process argument list.
    static func resolvedSuiteName(arguments: [String]) -> String {
        arguments.contains(isolatedStoreArgument) ? isolatedSuiteName : suiteName
    }

    /// Whether the suite bound at launch is the throwaway one and may therefore
    /// be emptied. The second conjunct is a structural stop, not a redundant
    /// one: `removePersistentDomain` has no undo, and were the two constants
    /// above ever to converge, an ordinary launch of app *and* extension would
    /// resolve to that name and delete the user's settings. Written this way,
    /// convergence switches the wipe off instead of aiming it at the app group.
    static func isWipeableSuite(
        _ name: String, appGroup: String = suiteName, isolated: String = isolatedSuiteName
    ) -> Bool {
        name == isolated && name != appGroup
    }

    /// The shared UserDefaults instance.
    /// Falls back to standard UserDefaults if the suite is unavailable — this
    /// must never happen in production (app and extension would stop sharing
    /// settings silently), so flag it loudly in debug builds.
    static let store: UserDefaults = {
        let name = resolvedSuiteName(arguments: ProcessInfo.processInfo.arguments)
        guard let shared = UserDefaults(suiteName: name) else {
            assertionFailure("Defaults suite '\(name)' unavailable — settings will not sync between app and keyboard extension")
            return .standard
        }
        #if DEBUG
            // Start every isolated launch from an empty suite. The wipe has to
            // happen here, in the app under test: the UI test runner is its own
            // sandboxed process, so a `removePersistentDomain` on its side would
            // clear its own copy of the suite and leave the app's untouched.
            // Wiping before the first read also means it can never race a
            // `@AppStorage` view — `store` is resolved lazily, exactly once.
            // Debug-only so that no shipped binary carries a destructive call at
            // all; a UI-test run built for Release keeps the redirect but loses
            // the wipe, and says so through
            // `testLaunchArgumentIsolatesDefaultsFromTheRealStore`.
            if isWipeableSuite(name) {
                shared.removePersistentDomain(forName: name)
            }
        #endif
        return shared
    }()
}
