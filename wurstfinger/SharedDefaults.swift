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

    /// The shared UserDefaults instance.
    /// Falls back to standard UserDefaults if the app group is unavailable — this
    /// must never happen in production (app and extension would stop sharing
    /// settings silently), so flag it loudly in debug builds.
    static let store: UserDefaults = {
        guard let shared = UserDefaults(suiteName: suiteName) else {
            assertionFailure("App group '\(suiteName)' unavailable — settings will not sync between app and keyboard extension")
            return .standard
        }
        return shared
    }()
}
