//
//  OnboardingProgress.swift
//  wurstfinger
//
//  Storage for the app-only onboarding checklist.
//

import Foundation

/// UserDefaults keys owned by the host app alone — the counterpart to
/// `SettingsKey`, which holds the keys the keyboard extension shares.
enum AppSettingsKey: String, CaseIterable {
    case onboardingKeyboardInstalled = "onboarding.keyboardInstalled"
    case onboardingFullAccessEnabled = "onboarding.fullAccessEnabled"
    case onboardingPracticed = "onboarding.practiced"
}

enum OnboardingProgress {
    /// The app's own defaults. The checklist records what the user ticked off
    /// in this app; the keyboard never reads it, and every write into the
    /// shared app-group suite fires a change notification the extension pays
    /// for on its next appearance.
    static let store: UserDefaults = .standard

    /// Moves checklist state written by earlier versions out of the shared
    /// app-group container — without it, an updating user's ticked steps would
    /// come back unticked. Idempotent: the shared keys are removed after the
    /// copy, so a later run finds nothing to move.
    static func migrateFromSharedStoreIfNeeded(
        from shared: UserDefaults = SharedDefaults.store,
        to local: UserDefaults = store
    ) {
        for key in AppSettingsKey.allCases {
            guard let value = shared.object(forKey: key.rawValue) else { continue }
            if local.object(forKey: key.rawValue) == nil {
                local.set(value, forKey: key.rawValue)
            }
            shared.removeObject(forKey: key.rawValue)
        }
    }
}
