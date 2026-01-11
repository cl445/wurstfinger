//
//  KeyBuilder.swift
//  Wurstfinger
//
//  A fluent builder pattern for defining MessagEase keys.
//  Reduces boilerplate and improves readability of key definitions.
//
//  Usage:
//  ```swift
//  let key = KeyBuilder("a")
//      .swipe(.up, "ä")
//      .swipe(.right, "-")
//      .compose(.upLeft, trigger: "^", display: "â")
//      .returning(.up, uppercase: true)
//      .circular(.clockwise, .toggleShift(on: true))
//      .build(locale: germanLocale)
//  ```
//

import Foundation

/// A fluent builder for constructing MessagEaseKey instances.
/// Provides a more readable alternative to the large dictionary literals
/// currently used in KeyboardLayout.swift.
final class KeyBuilder {
    private let center: String
    private var textMap: [KeyboardDirection: String] = [:]
    private var composeMap: [KeyboardDirection: (display: String?, trigger: String)] = [:]
    private var additionalOutputs: [KeyboardDirection: MessagEaseOutput] = [:]
    private var returnOverrides: [KeyboardDirection: MessagEaseOutput] = [:]
    private var circularOverrides: [KeyboardCircularDirection: MessagEaseOutput] = [:]

    // MARK: - Initialization

    /// Creates a new key builder with the given center character
    init(_ center: String) {
        self.center = center
    }

    // MARK: - Swipe Configuration

    /// Adds a text output for a swipe direction
    @discardableResult
    func swipe(_ direction: KeyboardDirection, _ text: String) -> KeyBuilder {
        textMap[direction] = text
        return self
    }

    /// Adds multiple swipe outputs at once
    @discardableResult
    func swipes(_ mappings: [KeyboardDirection: String]) -> KeyBuilder {
        for (direction, text) in mappings {
            textMap[direction] = text
        }
        return self
    }

    // MARK: - Compose Configuration

    /// Adds a compose trigger for a direction
    /// - Parameters:
    ///   - direction: The swipe direction
    ///   - trigger: The compose trigger character (e.g., "^" for circumflex)
    ///   - display: Optional display character (defaults to trigger)
    @discardableResult
    func compose(_ direction: KeyboardDirection, trigger: String, display: String? = nil) -> KeyBuilder {
        composeMap[direction] = (display: display, trigger: trigger)
        return self
    }

    // MARK: - Additional Outputs

    /// Adds a custom output for a direction (for non-text actions)
    @discardableResult
    func output(_ direction: KeyboardDirection, _ output: MessagEaseOutput) -> KeyBuilder {
        additionalOutputs[direction] = output
        return self
    }

    /// Adds a toggle shift action for a direction
    @discardableResult
    func toggleShift(_ direction: KeyboardDirection, on: Bool) -> KeyBuilder {
        additionalOutputs[direction] = .toggleShift(on: on)
        return self
    }

    /// Adds a capitalize word action for a direction
    @discardableResult
    func capitalizeWord(_ direction: KeyboardDirection, uppercase: Bool) -> KeyBuilder {
        additionalOutputs[direction] = .capitalizeWord(uppercased: uppercase)
        return self
    }

    /// Adds a cycle accents action for a direction
    @discardableResult
    func cycleAccents(_ direction: KeyboardDirection) -> KeyBuilder {
        additionalOutputs[direction] = .cycleAccents
        return self
    }

    // MARK: - Return Overrides

    /// Adds a return override (swipe out and back) with uppercase text
    @discardableResult
    func returning(_ direction: KeyboardDirection, text: String) -> KeyBuilder {
        returnOverrides[direction] = .text(text)
        return self
    }

    /// Adds a return override that uppercases the swipe text
    @discardableResult
    func returningUppercase(_ direction: KeyboardDirection, locale: Locale) -> KeyBuilder {
        if let text = textMap[direction] {
            returnOverrides[direction] = .text(text.uppercased(with: locale))
        }
        return self
    }

    /// Adds a return override with a custom output
    @discardableResult
    func returning(_ direction: KeyboardDirection, output: MessagEaseOutput) -> KeyBuilder {
        returnOverrides[direction] = output
        return self
    }

    /// Adds uppercase return overrides for all defined swipe directions
    @discardableResult
    func allReturnsUppercase(locale: Locale) -> KeyBuilder {
        for (direction, text) in textMap {
            returnOverrides[direction] = .text(text.uppercased(with: locale))
        }
        return self
    }

    // MARK: - Circular Overrides

    /// Adds a circular gesture output
    @discardableResult
    func circular(_ direction: KeyboardCircularDirection, _ output: MessagEaseOutput) -> KeyBuilder {
        circularOverrides[direction] = output
        return self
    }

    /// Adds clockwise uppercase toggle
    @discardableResult
    func clockwiseUppercase() -> KeyBuilder {
        circularOverrides[.clockwise] = .toggleShift(on: true)
        return self
    }

    /// Adds counterclockwise lowercase toggle
    @discardableResult
    func counterclockwiseLowercase() -> KeyBuilder {
        circularOverrides[.counterclockwise] = .toggleShift(on: false)
        return self
    }

    /// Adds both circular directions for shift toggle (common pattern)
    @discardableResult
    func circularShiftToggle() -> KeyBuilder {
        circularOverrides[.clockwise] = .toggleShift(on: true)
        circularOverrides[.counterclockwise] = .toggleShift(on: false)
        return self
    }

    // MARK: - Build

    /// Builds the final MessagEaseKey
    func build(locale: Locale) -> MessagEaseKey {
        // Build outputs dictionary
        var outputs: [KeyboardDirection: MessagEaseOutput] = [:]

        // Add text outputs
        for (direction, text) in textMap {
            outputs[direction] = .text(text)
        }

        // Add compose outputs (these override text outputs)
        for (direction, compose) in composeMap {
            outputs[direction] = .compose(trigger: compose.trigger, display: compose.display)
        }

        // Add additional outputs (these override everything)
        for (direction, output) in additionalOutputs {
            outputs[direction] = output
        }

        // Auto-generate uppercase returns if not explicitly set
        var finalReturnOverrides = returnOverrides
        for (direction, text) in textMap where finalReturnOverrides[direction] == nil {
            // Only auto-uppercase for letter keys
            if text.count == 1, text.first?.isLetter == true {
                finalReturnOverrides[direction] = .text(text.uppercased(with: locale))
            }
        }

        return MessagEaseKey(
            center: center,
            outputs: outputs,
            returningOutputs: finalReturnOverrides,
            circularOutputs: circularOverrides
        )
    }
}

// MARK: - Convenience Extensions

extension KeyBuilder {
    /// Creates a standard letter key with circular shift toggle
    static func letterKey(_ center: String, locale: Locale) -> KeyBuilder {
        KeyBuilder(center)
            .circularShiftToggle()
    }

    /// Creates a number key (no circular gestures)
    static func numberKey(_ center: String) -> KeyBuilder {
        KeyBuilder(center)
    }

    /// Creates a symbol key (no circular gestures)
    static func symbolKey(_ center: String) -> KeyBuilder {
        KeyBuilder(center)
    }
}

// MARK: - Example Usage Documentation

/*
 BEFORE (current style in KeyboardLayout.swift):

 Self.makeKey(
     center: centers[0][0],
     locale: config.locale,
     textMap: [
         .up: config.specialCharacters["0_0_up"] ?? "",
         .right: "-",
         .downRight: config.specialCharacters["0_0_downRight"] ?? "v",
         .down: "w",
         .downLeft: config.specialCharacters["0_0_downLeft"] ?? "",
         .left: config.specialCharacters["0_0_left"] ?? "x",
         .upLeft: config.specialCharacters["0_0_upLeft"] ?? "",
         .upRight: config.specialCharacters["0_0_upRight"] ?? "",
     ],
     additionalOutputs: [
         .upLeft: .cycleAccents
     ],
     returnOverrides: [
         .upLeft: .cycleAccents,
         .up: .text((config.specialCharacters["0_0_up"] ?? "").uppercased(with: config.locale)),
         // ... 8 more directions
     ]
 )

 AFTER (with KeyBuilder):

 KeyBuilder(centers[0][0])
     .swipes([
         .up: config.char("0_0_up"),
         .right: "-",
         .downRight: config.char("0_0_downRight", default: "v"),
         .down: "w",
         .downLeft: config.char("0_0_downLeft"),
         .left: config.char("0_0_left", default: "x"),
         .upLeft: config.char("0_0_upLeft"),
         .upRight: config.char("0_0_upRight"),
     ])
     .cycleAccents(.upLeft)
     .allReturnsUppercase(locale: config.locale)
     .circularShiftToggle()
     .build(locale: config.locale)

 Benefits:
 - More readable and self-documenting
 - Less repetition (allReturnsUppercase vs 8 individual return overrides)
 - Type-safe (no string keys like "0_0_up")
 - Easier to maintain and modify
 - Clear separation of concerns (swipes, returns, circular)
*/
