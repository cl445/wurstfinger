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
    static let isolatedSuiteName = "de.akator.wurstfinger.isolated"

    /// The suite `store` binds to for a given process argument list.
    static func resolvedSuiteName(arguments: [String]) -> String {
        arguments.contains(isolatedStoreArgument) ? isolatedSuiteName : suiteName
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
        return shared
    }()
}
