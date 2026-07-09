//
//  TestHelpers.swift
//  WurstfingerTests
//
//  Shared test helpers for the data-driven pipeline tests.
//  MockTextTarget and makeViewModel are used across multiple test files.
//

import Foundation
import Testing
@testable import WurstfingerApp

/// Mock implementation of TextInputTarget for pipeline tests.
final class MockTextTarget: TextInputTarget {
    enum Event: Equatable {
        case insertText(String)
        case deleteBackward
        case adjustCursor(Int)
    }

    var events: [Event] = []
    var documentContextBeforeInput: String?
    var documentContextAfterInput: String?
    var selectedText: String?
    var hasFullAccess: Bool = false

    func insertText(_ text: String) {
        events.append(.insertText(text))
        documentContextBeforeInput = (documentContextBeforeInput ?? "") + text
    }

    func deleteBackward() {
        events.append(.deleteBackward)
        if let ctx = documentContextBeforeInput, !ctx.isEmpty {
            documentContextBeforeInput = String(ctx.dropLast())
        }
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        events.append(.adjustCursor(offset))
        // Mirror UIKit: `adjustTextPosition(byCharacterOffset:)` moves by
        // UTF-16 code units, so apply the offset over the UTF-16 view of the
        // buffer. Landing inside a surrogate pair produces U+FFFD replacement
        // characters, which makes unit mismatches visible in test assertions.
        var before = Array((documentContextBeforeInput ?? "").utf16)
        var after = Array((documentContextAfterInput ?? "").utf16)
        if offset > 0 {
            let moved = min(offset, after.count)
            before.append(contentsOf: after.prefix(moved))
            after.removeFirst(moved)
        } else if offset < 0 {
            let moved = min(-offset, before.count)
            after.insert(contentsOf: before.suffix(moved), at: 0)
            before.removeLast(moved)
        }
        documentContextBeforeInput = String(decoding: before, as: UTF16.self)
        documentContextAfterInput = String(decoding: after, as: UTF16.self)
    }
}

/// Isolated, in-memory `UserDefaults` for tests.
///
/// Replaces the previous `UserDefaults(suiteName: "test.<UUID>")!` pattern,
/// which created a fresh on-disk suite per call. Under parallel test
/// execution that spammed the prefs directory and could return `nil`,
/// crashing on the force-unwrap. This backing store never touches disk,
/// never returns `nil`, and is fully isolated per instance.
///
/// `KeyboardSettings` reads/writes the injected store only via
/// `object(forKey:)` / `set(_:forKey:)` / `removeObject(forKey:)`; the typed
/// accessors are overridden too as a safety net.
final class InMemoryUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]
    private let lock = NSLock()

    convenience init() {
        // suiteName nil backs `super` with the standard domain, but every
        // accessor below is overridden so that domain is never consulted.
        self.init(suiteName: nil)!
    }

    override func object(forKey defaultName: String) -> Any? {
        lock.lock(); defer { lock.unlock() }
        return storage[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        lock.lock(); defer { lock.unlock() }
        storage[defaultName] = value
    }

    // Typed setters route into the in-memory storage as well: without these
    // overrides, a statically-typed call like `set(0.3, forKey:)` resolves to
    // the non-overridden `set(Double,forKey:)` and silently writes to the real
    // standard domain instead.
    override func set(_ value: Double, forKey defaultName: String) {
        set(value as NSNumber, forKey: defaultName)
    }

    override func set(_ value: Float, forKey defaultName: String) {
        set(value as NSNumber, forKey: defaultName)
    }

    override func set(_ value: Int, forKey defaultName: String) {
        set(value as NSNumber, forKey: defaultName)
    }

    override func set(_ value: Bool, forKey defaultName: String) {
        set(value as NSNumber, forKey: defaultName)
    }

    override func removeObject(forKey defaultName: String) {
        lock.lock(); defer { lock.unlock() }
        storage[defaultName] = nil
    }

    override func string(forKey defaultName: String) -> String? {
        object(forKey: defaultName) as? String
    }

    override func bool(forKey defaultName: String) -> Bool {
        (object(forKey: defaultName) as? NSNumber)?.boolValue ?? false
    }

    override func integer(forKey defaultName: String) -> Int {
        (object(forKey: defaultName) as? NSNumber)?.intValue ?? 0
    }

    override func double(forKey defaultName: String) -> Double {
        (object(forKey: defaultName) as? NSNumber)?.doubleValue ?? 0
    }

    override func float(forKey defaultName: String) -> Float {
        (object(forKey: defaultName) as? NSNumber)?.floatValue ?? 0
    }
}

/// Language ids whose script is caseless. These layouts have no shift
/// affordance (no shifted/capsLock modes, no shift binding) and
/// auto-capitalization disabled in their definition settings.
enum CaselessLanguages {
    static let ids: Set<String> = ["he_IL", "ar", "fa_IR", "ur", "th_TH", "hi_IN"]
}

/// Creates a KeyboardViewModel wired to a MockTextTarget for testing.
func makeViewModel(
    languageId: String = "de_DE",
    advanceToNextInputMode: @escaping () -> Void = {},
    dismissKeyboard: @escaping () -> Void = {}
) -> (KeyboardViewModel, MockTextTarget) {
    let defaults = InMemoryUserDefaults()
    let vm = KeyboardViewModel(userDefaults: defaults, shouldPersistSettings: false)
    let target = MockTextTarget()
    vm.bindTextInputTarget(target)
    vm.bindViewControllerActions(
        advanceToNextInputMode: advanceToNextInputMode,
        dismissKeyboard: dismissKeyboard
    )
    vm.loadDefinition(for: languageId)
    return (vm, target)
}
