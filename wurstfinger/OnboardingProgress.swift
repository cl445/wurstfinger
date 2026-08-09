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
    /// The store the checklist binds to for a given process argument list.
    ///
    /// An ordinary launch keeps it in the app's own defaults: the checklist
    /// records what the user ticked off in this app, the keyboard never reads
    /// it, and every write into the shared app-group suite would cost the
    /// extension a change notification on its next appearance.
    ///
    /// Under the UI-test isolation argument it follows `SharedDefaults.store`
    /// into the throwaway suite instead. The checklist is the one screen a UI
    /// test drives by tapping persisted state (`OnboardingView` binds the three
    /// steps straight to these keys), and `continueAfterFailure = false` means
    /// a failure between the tick and the untick never reaches a restore step —
    /// so without the redirect the tester keeps a ticked checkbox in their real
    /// app defaults.
    static func resolvedStore(arguments: [String]) -> UserDefaults {
        arguments.contains(SharedDefaults.isolatedStoreArgument) ? SharedDefaults.store : .standard
    }

    /// The app's own defaults, or the isolated suite under a UI test.
    static let store: UserDefaults = resolvedStore(arguments: ProcessInfo.processInfo.arguments)

    /// Moves checklist state written by earlier versions out of the shared
    /// app-group container — without it, an updating user's ticked steps would
    /// come back unticked. Idempotent: the shared keys are removed after the
    /// copy, so a later run finds nothing to move.
    ///
    /// The identity guard is what stops the migration destroying the state it
    /// exists to rescue when both parameters are the same store: the copy would
    /// be skipped (the value is already under that key) and `removeObject` would
    /// then delete the only copy there is. That is not hypothetical — an
    /// isolated UI-test launch resolves `store` to `SharedDefaults.store`, so
    /// the two really are one object.
    ///
    /// It compares instance identity, not domain identity, and
    /// `UserDefaults(suiteName:)` hands out a fresh object per call: two objects
    /// addressing one domain would slip past it. If either store ever becomes
    /// such an instance, re-derive the argument rather than trusting the guard.
    static func migrateFromSharedStoreIfNeeded(
        from shared: UserDefaults = SharedDefaults.store,
        to local: UserDefaults = store
    ) {
        guard shared !== local else { return }
        for key in AppSettingsKey.allCases {
            guard let value = shared.object(forKey: key.rawValue) else { continue }
            if local.object(forKey: key.rawValue) == nil {
                local.set(value, forKey: key.rawValue)
            }
            shared.removeObject(forKey: key.rawValue)
        }
    }
}
