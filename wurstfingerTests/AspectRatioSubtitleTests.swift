//
//  AspectRatioSubtitleTests.swift
//  wurstfingerTests
//
//  The key-aspect-ratio subtitle is the one place in the app where a value and
//  a literal have to stay glued together across scripts: `Current: 1.00:1`. It
//  used to interpolate only the number into the localized string, and because
//  Foundation isolates interpolated arguments in right-to-left localizations,
//  the trailing `:1` reordered — Arabic and Hebrew showed `1:1.00`. These tests
//  pin both halves of the fix: the composed value, and the contract the fix
//  places on the translations.
//
//  The composed value has to be checked against a right-to-left bundle. Under
//  the English test localization Foundation inserts no isolate, so the old and
//  the new implementation return the same bytes there and an English-only check
//  would pass either way.
//

import Foundation
import Testing
@testable import WurstfingerApp

/// The catalog key the subtitle is looked up under. Changing the format string
/// in `SettingsView` means renaming this key in the String Catalog and adapting
/// all translations. `sourceStringGluesTheRatioTogether` ties this constant to
/// the lookup in `SettingsView` so that a rename fails here: String Catalog
/// entries are `manual`, so Xcode never prunes the old one, and the translation
/// guard below would otherwise keep validating an entry nothing renders.
private let aspectRatioKey = "Current: %@:1"

/// Repo root: this file lives in `wurstfingerTests/`, so go up two levels.
///
/// Two of the tests below read `Localizable.xcstrings` and `SettingsView.swift`
/// as source files rather than as bundled resources, because the contract they
/// pin (a translation glues `:1` to the placeholder; `SettingsView` looks the
/// subtitle up under this key) exists in the checkout, not in the built product.
/// `#filePath` is baked in at compile time, so this assumes the tests run from
/// the tree they were compiled in — true for `xcodebuild test`, the only
/// supported path; re-running built products against a moved or absent source
/// tree fails these two with a file-not-found error, loudly and in the safe
/// direction.
private func projectDir(file: String = #filePath) -> URL {
    URL(fileURLWithPath: file)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

/// Every localized value of `aspectRatioKey`, keyed by language.
private func aspectRatioTranslations() throws -> [String: String] {
    let url = projectDir().appendingPathComponent("wurstfinger/Localizable.xcstrings")
    let data = try Data(contentsOf: url)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let strings = json?["strings"] as? [String: Any]
    let entry = strings?[aspectRatioKey] as? [String: Any]
    let localizations = entry?["localizations"] as? [String: Any] ?? [:]
    var values: [String: String] = [:]
    for (language, localization) in localizations {
        guard
            let unit = (localization as? [String: Any])?["stringUnit"] as? [String: Any],
            let value = unit["value"] as? String
        else {
            continue
        }
        values[language] = value
    }
    return values
}

struct AspectRatioSubtitleTests {
    /// The ratio ends the subtitle and its decimals are fixed at two places (it
    /// is a display value, not a measurement). This resolves in whatever
    /// localization the test host runs under — English by default, where no
    /// isolate is inserted, so the bidi half is pinned in the test below.
    @Test(arguments: [
        (ratio: 1.0, expected: "1.00:1"),
        (ratio: 1.62, expected: "1.62:1"),
        (ratio: 0.7, expected: "0.70:1"),
    ])
    func composesTheRatioWithTwoDecimals(config: (ratio: Double, expected: String)) {
        let subtitle = SettingsView.keyAspectRatioSubtitle(for: config.ratio)
        #expect(subtitle.hasSuffix(config.expected), "subtitle was \(subtitle)")
    }

    /// The reordering exists only once the resolved localization is right-to-left,
    /// so resolve the template against the app's Arabic bundle rather than the
    /// test locale. Reverting to `String(localized: "Current: \(number):1")` puts
    /// U+2068/U+2069 around the number here and fails both expectations.
    @Test func keepsTheRatioAsOneRunInRightToLeftLocalizations() throws {
        let path = try #require(
            Bundle.main.path(forResource: "ar", ofType: "lproj"),
            "the app bundle no longer ships Arabic — resolve against another right-to-left localization"
        )
        let arabic = try #require(Bundle(path: path))
        let subtitle = SettingsView.keyAspectRatioSubtitle(for: 1.0, bundle: arabic)
        #expect(subtitle.hasSuffix("1.00:1"), "subtitle was \(subtitle.debugDescription)")

        let isolates: Set<Unicode.Scalar> = ["\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}"]
        let hasIsolate = subtitle.unicodeScalars.contains { isolates.contains($0) }
        #expect(!hasIsolate, "the ratio must not be split by a bidi isolate: \(subtitle.debugDescription)")
    }

    /// The English source string is the fallback whenever a language is missing,
    /// so it has to satisfy the same contract as the translations. The first
    /// expectation is what makes the second one more than a literal compared
    /// against a substring of itself: it pins `aspectRatioKey` to the key
    /// `SettingsView` actually looks the subtitle up under.
    @Test func sourceStringGluesTheRatioTogether() throws {
        let url = projectDir().appendingPathComponent("wurstfinger/SettingsView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(
            source.contains("String(localized: \"\(aspectRatioKey)\""),
            "SettingsView no longer looks the subtitle up under '\(aspectRatioKey)' — update the key here and in the catalog"
        )
        #expect(aspectRatioKey.hasSuffix("%@:1"))
    }

    /// In every translation the `:1` must follow the placeholder directly. A
    /// separator (a space, a right-to-left mark, a reordered suffix) would break
    /// the number run apart and bring the `1:1.00` rendering back in Arabic,
    /// Hebrew, Persian and Urdu.
    @Test func everyTranslationGluesTheRatioToThePlaceholder() throws {
        let translations = try aspectRatioTranslations()
        #expect(!translations.isEmpty, "\(aspectRatioKey) is missing from wurstfinger/Localizable.xcstrings")

        for (language, value) in translations.sorted(by: { $0.key < $1.key }) {
            guard let placeholder = value.range(of: "%@") else {
                Issue.record("\(language): '\(value)' has no %@ placeholder")
                continue
            }
            let suffix = Array(value[placeholder.upperBound...])
            #expect(suffix.first == ":", "\(language): '\(value)' must continue with ':' right after %@")
            // The `1` is a literal, not a localizable digit, and it stays ASCII
            // in all 22 translations — which is what the fix restored. `%@`
            // always receives ASCII digits (`String(format: "%.2f")`), and the
            // bidi algorithm only folds the `:` between them into one number
            // run while both sides resolve to the same numeric class (rule W4).
            // A local digit shape does not: U+06F1 (۱) is class EN but resolves
            // to AN beside Arabic-script letters (rule W2), U+0661 (١) is AN
            // outright — and the mismatch splits the ratio apart again into the
            // `1:1.00` rendering. Not a blanket ban on local digits: the Persian
            // numpad-type labels in Settings (`تلفن (⁦۱-۲-۳⁩)`) carry them
            // legitimately, because they wrap the digit run in LRI/PDI — an
            // isolate this subtitle cannot use without splitting the very run
            // it exists to glue.
            #expect(suffix.dropFirst().first == "1", "\(language): '\(value)' must end in the ASCII ':1'")
        }
    }
}
