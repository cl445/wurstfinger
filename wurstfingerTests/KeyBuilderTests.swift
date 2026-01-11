//
//  KeyBuilderTests.swift
//  wurstfingerTests
//
//  Tests for KeyBuilder fluent API
//

import Foundation
import Testing
@testable import WurstfingerApp

struct KeyBuilderTests {

    let germanLocale = Locale(identifier: "de_DE")

    // MARK: - Basic Building Tests

    @Test func buildBasicKey() {
        let key = KeyBuilder("a")
            .build(locale: germanLocale)

        #expect(key.center == "a")
    }

    @Test func buildKeyWithSwipes() {
        let key = KeyBuilder("a")
            .swipe(.up, "ä")
            .swipe(.right, "-")
            .swipe(.down, "w")
            .build(locale: germanLocale)

        #expect(key.center == "a")

        // Check swipe outputs
        if case .text(let text) = key.output(for: .up) {
            #expect(text == "ä")
        } else {
            #expect(Bool(false), "Expected text output for .up")
        }

        if case .text(let text) = key.output(for: .right) {
            #expect(text == "-")
        } else {
            #expect(Bool(false), "Expected text output for .right")
        }
    }

    @Test func buildKeyWithMultipleSwipes() {
        let key = KeyBuilder("n")
            .swipes([
                .up: "ö",
                .right: "l",
                .down: "g",
                .left: "j"
            ])
            .build(locale: germanLocale)

        if case .text(let text) = key.output(for: .up) {
            #expect(text == "ö")
        } else {
            #expect(Bool(false), "Expected text output")
        }

        if case .text(let text) = key.output(for: .left) {
            #expect(text == "j")
        } else {
            #expect(Bool(false), "Expected text output")
        }
    }

    // MARK: - Compose Tests

    @Test func buildKeyWithCompose() {
        let key = KeyBuilder("a")
            .compose(.upLeft, trigger: "^", display: "â")
            .build(locale: germanLocale)

        if case .compose(let trigger, let display) = key.output(for: .upLeft) {
            #expect(trigger == "^")
            #expect(display == "â")
        } else {
            #expect(Bool(false), "Expected compose output for .upLeft")
        }
    }

    @Test func composeOverridesSwipe() {
        let key = KeyBuilder("a")
            .swipe(.up, "x")  // First set swipe
            .compose(.up, trigger: "^")  // Then override with compose
            .build(locale: germanLocale)

        // Compose should take precedence
        if case .compose(let trigger, _) = key.output(for: .up) {
            #expect(trigger == "^")
        } else {
            #expect(Bool(false), "Expected compose to override swipe")
        }
    }

    // MARK: - Additional Output Tests

    @Test func buildKeyWithToggleShift() {
        let key = KeyBuilder("a")
            .toggleShift(.upRight, on: true)
            .build(locale: germanLocale)

        if case .toggleShift(let on) = key.output(for: .upRight) {
            #expect(on == true)
        } else {
            #expect(Bool(false), "Expected toggleShift output")
        }
    }

    @Test func buildKeyWithCapitalizeWord() {
        let key = KeyBuilder("a")
            .capitalizeWord(.downLeft, uppercase: true)
            .build(locale: germanLocale)

        if case .capitalizeWord(let uppercased) = key.output(for: .downLeft) {
            #expect(uppercased == true)
        } else {
            #expect(Bool(false), "Expected capitalizeWord output")
        }
    }

    @Test func buildKeyWithCycleAccents() {
        let key = KeyBuilder("a")
            .cycleAccents(.upLeft)
            .build(locale: germanLocale)

        if case .cycleAccents = key.output(for: .upLeft) {
            // Success
        } else {
            #expect(Bool(false), "Expected cycleAccents output")
        }
    }

    // MARK: - Return Override Tests

    @Test func buildKeyWithReturningText() {
        let key = KeyBuilder("a")
            .swipe(.up, "ä")
            .returning(.up, text: "Ä")
            .build(locale: germanLocale)

        // Normal swipe
        if case .text(let text) = key.output(for: .up, returning: false) {
            #expect(text == "ä")
        } else {
            #expect(Bool(false), "Expected text output for normal swipe")
        }

        // Return swipe
        if case .text(let text) = key.output(for: .up, returning: true) {
            #expect(text == "Ä")
        } else {
            #expect(Bool(false), "Expected text output for return swipe")
        }
    }

    @Test func buildKeyWithAutoUppercaseReturns() {
        let key = KeyBuilder("a")
            .swipe(.up, "b")
            .swipe(.right, "c")
            .build(locale: germanLocale)

        // Auto-generated uppercase returns for letter keys
        if case .text(let text) = key.output(for: .up, returning: true) {
            #expect(text == "B")
        } else {
            #expect(Bool(false), "Expected auto-uppercase return")
        }
    }

    // MARK: - Circular Gesture Tests

    @Test func buildKeyWithCircularShiftToggle() {
        let key = KeyBuilder("a")
            .circularShiftToggle()
            .build(locale: germanLocale)

        if case .toggleShift(let on) = key.circularOutput(for: .clockwise) {
            #expect(on == true)
        } else {
            #expect(Bool(false), "Expected toggleShift for clockwise")
        }

        if case .toggleShift(let on) = key.circularOutput(for: .counterclockwise) {
            #expect(on == false)
        } else {
            #expect(Bool(false), "Expected toggleShift for counterclockwise")
        }
    }

    @Test func buildKeyWithCustomCircular() {
        let key = KeyBuilder("a")
            .circular(.clockwise, .text("X"))
            .build(locale: germanLocale)

        if case .text(let text) = key.circularOutput(for: .clockwise) {
            #expect(text == "X")
        } else {
            #expect(Bool(false), "Expected custom circular output")
        }
    }

    // MARK: - Convenience Factory Tests

    @Test func letterKeyFactoryAddsCircularToggle() {
        let key = KeyBuilder.letterKey("a", locale: germanLocale)
            .build(locale: germanLocale)

        // Should have circular shift toggle
        #expect(key.circularOutput(for: .clockwise) != nil)
        #expect(key.circularOutput(for: .counterclockwise) != nil)
    }

    // MARK: - Chaining Tests

    @Test func methodsAreChainable() {
        // This test verifies the fluent API works
        let key = KeyBuilder("t")
            .swipe(.up, "y")
            .swipe(.right, "u")
            .swipe(.down, "e")
            .compose(.upLeft, trigger: "^")
            .toggleShift(.upRight, on: true)
            .returning(.up, text: "Y")
            .circularShiftToggle()
            .build(locale: germanLocale)

        #expect(key.center == "t")

        // Verify all configurations were applied
        #expect(key.output(for: .up) != nil)
        #expect(key.output(for: .right) != nil)
        #expect(key.output(for: .down) != nil)
        #expect(key.output(for: .upLeft) != nil)
        #expect(key.output(for: .upRight) != nil)
        #expect(key.output(for: .up, returning: true) != nil)
        #expect(key.circularOutput(for: .clockwise) != nil)
    }
}
