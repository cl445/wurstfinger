//
//  SettingsReloadObserverTests.swift
//  wurstfingerTests
//
//  The view model syncs in-process settings changes via
//  UserDefaults.didChangeNotification — but only when it persists settings.
//  Non-persisting view models (previews, showcases, App Store screenshots)
//  are configured programmatically; an observer reloading from the store
//  would revert forced values (e.g. the full-size screenshot scale) as soon
//  as any same-process defaults write lands.
//

import Foundation
import Testing
@testable import WurstfingerApp

@MainActor
struct SettingsReloadObserverTests {
    /// Posts the notification UserDefaults would emit for an in-process write.
    private func postDidChange(for defaults: UserDefaults) {
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
    }

    /// Drains the main runloop in short slices until `condition` holds or the
    /// deadline passes. Fast when the observer fires promptly, tolerant when a
    /// loaded CI runner delays `.main`-queue delivery.
    private func drainRunLoop(
        deadline: TimeInterval = 1.0, until condition: () -> Bool = { false }
    ) {
        let end = Date().addingTimeInterval(deadline)
        while !condition(), Date() < end {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    @Test("Persisting view model reloads settings on didChange (control)")
    func persistingViewModelReloadsOnDidChange() {
        let defaults = InMemoryUserDefaults()
        defaults.set(0.5, forKey: SettingsKey.keyboardScale.rawValue)
        let vm = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: true)
        #expect(vm.keyboardScale == 0.5)

        defaults.set(0.8, forKey: SettingsKey.keyboardScale.rawValue)
        postDidChange(for: defaults)
        drainRunLoop(until: { vm.keyboardScale == 0.8 })

        #expect(vm.keyboardScale == 0.8)
    }

    @Test("Non-persisting view model keeps forced values across didChange")
    func nonPersistingViewModelIgnoresDidChange() {
        let defaults = InMemoryUserDefaults()
        defaults.set(0.5, forKey: SettingsKey.keyboardScale.rawValue)
        let vm = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)

        // Screenshot/showcase views force a full-size keyboard…
        vm.keyboardScale = 1.0
        // …then a same-process defaults write lands (e.g. selecting the
        // screenshot language) and the change notification fires.
        defaults.set("en_US", forKey: SettingsKey.selectedLanguageId.rawValue)
        postDidChange(for: defaults)
        // Give a (buggy) observer ample time to fire before asserting that
        // nothing changed — a fixed short drain could false-pass under load.
        drainRunLoop(deadline: 0.1)

        // The forced scale must survive; a reload would revert it to 0.5.
        #expect(vm.keyboardScale == 1.0)
    }
}
