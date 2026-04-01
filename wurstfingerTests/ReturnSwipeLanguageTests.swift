//
//  ReturnSwipeLanguageTests.swift
//  wurstfingerTests
//
//  Tests that return swipe overrides on the center key produce the correct
//  uppercased variant for every language, not hardcoded English values.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct ReturnSwipeLanguageTests {
    /// Bug #94: French layout return swipe up on center key (O) should produce "H",
    /// because the French up-swipe character is "h" — not "U" (the English default).
    @Test func frenchReturnSwipeUpOnCenterKeyProducesH() throws {
        let frenchLayout = KeyboardLayout.layout(for: .french)
        let viewModel = KeyboardViewModel(layout: frenchLayout, shouldPersistSettings: false)
        var inserted: [String] = []

        viewModel.bindActionHandler { action in
            if case let .insert(value) = action {
                inserted.append(value)
            }
        }

        let centerKey = try #require(viewModel.rows[1][1])
        viewModel.handleKeySwipeReturn(centerKey, direction: .up)

        #expect(
            inserted.last == "H",
            "French return swipe up on center key should produce H, got \(inserted.last ?? "nil")"
        )
    }

    /// Regression guard: for every language, the center key's return swipe overrides
    /// should match the uppercased version of the regular swipe output.
    @Test func centerKeyReturnSwipeMatchesUppercasedSwipeForAllLanguages() throws {
        for config in LanguageConfig.allLanguages {
            let layout = KeyboardLayout.layout(for: config)
            let viewModel = KeyboardViewModel(layout: layout, shouldPersistSettings: false)
            viewModel.bindActionHandler { _ in }

            let centerKey = try #require(viewModel.rows[1][1])

            for direction in KeyboardDirection.allCases where direction != .center {
                // Get the regular swipe output
                guard case let .text(swipeText)? = centerKey.output(for: direction) else { continue }
                // Get the return swipe output
                guard case let .text(returnText)? = centerKey.output(for: direction, returning: true) else { continue }
                // Only check letter outputs
                guard swipeText.first?.isLetter == true else { continue }

                let expected = swipeText.uppercased(with: config.locale)
                #expect(
                    returnText == expected,
                    "[\(config.id)] center key return swipe \(direction): expected '\(expected)', got '\(returnText)'"
                )
            }
        }
    }
}
