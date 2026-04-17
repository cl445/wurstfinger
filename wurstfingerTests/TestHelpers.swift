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
    }
}

/// Creates a KeyboardViewModel wired to a MockTextTarget for testing.
func makeViewModel(
    languageId: String = "de_DE",
    advanceToNextInputMode: @escaping () -> Void = {},
    dismissKeyboard: @escaping () -> Void = {}
) -> (KeyboardViewModel, MockTextTarget) {
    let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
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
