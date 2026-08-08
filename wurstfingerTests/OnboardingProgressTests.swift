//
//  OnboardingProgressTests.swift
//  WurstfingerTests
//
//  The onboarding checklist is app-only state: it must leave the shared
//  app-group suite without resetting an updating user's ticked steps.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct OnboardingProgressTests {
    @Test func migrationMovesTickedStepsOutOfTheSharedStore() {
        let shared = InMemoryUserDefaults()
        let local = InMemoryUserDefaults()
        shared.set(true, forKey: AppSettingsKey.onboardingKeyboardInstalled.rawValue)
        shared.set(true, forKey: AppSettingsKey.onboardingPracticed.rawValue)

        OnboardingProgress.migrateFromSharedStoreIfNeeded(from: shared, to: local)

        #expect(local.bool(forKey: AppSettingsKey.onboardingKeyboardInstalled.rawValue))
        #expect(local.bool(forKey: AppSettingsKey.onboardingPracticed.rawValue))
        for key in AppSettingsKey.allCases {
            #expect(shared.object(forKey: key.rawValue) == nil, "\(key.rawValue) left behind in the shared store")
        }
    }

    @Test func migrationDoesNotOverwriteLocalState() {
        let shared = InMemoryUserDefaults()
        let local = InMemoryUserDefaults()
        shared.set(false, forKey: AppSettingsKey.onboardingPracticed.rawValue)
        local.set(true, forKey: AppSettingsKey.onboardingPracticed.rawValue)

        OnboardingProgress.migrateFromSharedStoreIfNeeded(from: shared, to: local)

        #expect(local.bool(forKey: AppSettingsKey.onboardingPracticed.rawValue))
    }

    @Test func migrationIsIdempotent() {
        let shared = InMemoryUserDefaults()
        let local = InMemoryUserDefaults()
        shared.set(true, forKey: AppSettingsKey.onboardingFullAccessEnabled.rawValue)

        OnboardingProgress.migrateFromSharedStoreIfNeeded(from: shared, to: local)
        local.set(false, forKey: AppSettingsKey.onboardingFullAccessEnabled.rawValue)
        OnboardingProgress.migrateFromSharedStoreIfNeeded(from: shared, to: local)

        #expect(!local.bool(forKey: AppSettingsKey.onboardingFullAccessEnabled.rawValue))
    }

    /// A key owned by both enums would be written to the app's own defaults by
    /// the host and read from the app group by the keyboard, which is the split
    /// this store move removes.
    @Test func appSettingsKeysDoNotCollideWithSharedKeys() {
        let shared = Set(SettingsKey.allCases.map(\.rawValue))
        let appOnly = Set(AppSettingsKey.allCases.map(\.rawValue))
        #expect(appOnly.isDisjoint(with: shared), "overlapping keys: \(appOnly.intersection(shared))")
    }
}
