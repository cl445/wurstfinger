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
    /// Posts the notification UserDefaults would emit for an in-process write,
    /// then drains the main runloop so observer blocks enqueued on `.main`
    /// are delivered before asserting.
    private func postDidChange(for defaults: UserDefaults) {
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }

    @Test("Persisting view model reloads settings on didChange (control)")
    func persistingViewModelReloadsOnDidChange() {
        let defaults = InMemoryUserDefaults()
        defaults.set(0.5, forKey: SettingsKey.keyboardScale.rawValue)
        let vm = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: true)
        #expect(vm.keyboardScale == 0.5)

        defaults.set(0.8, forKey: SettingsKey.keyboardScale.rawValue)
        postDidChange(for: defaults)

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

        // The forced scale must survive; a reload would revert it to 0.5.
        #expect(vm.keyboardScale == 1.0)
    }
}
