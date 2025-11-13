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

    /// The shared UserDefaults instance
    /// Falls back to standard UserDefaults if app group is not available (should never happen in production)
    static var store: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
