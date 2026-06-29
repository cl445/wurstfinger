//
//  LocalizationCompletenessTests.swift
//  WurstfingerTests
//
//  Guards the String Catalogs against incomplete localization: every string
//  must be translated into every supported language, with no empty values,
//  no stale/needs-review states, and no stray languages. Reads the .xcstrings
//  files straight from the source tree (like InfoPlistLanguageTests), so a
//  forgotten translation fails the build instead of silently shipping English.
//

import Foundation
import Testing

/// Languages every `Localizable.xcstrings` must fully cover, besides the `en` source.
/// Keep in sync with `knownRegions` in the Xcode project.
private let requiredLanguages: Set<String> = [
    "de", "fr", "es", "it", "ru", "pl", "sv", "fi", "hr", "he", "vi", "fil",
]

/// All String Catalogs in the repo, relative to the project root.
private let localizationCatalogs: [String] = [
    "wurstfinger/Localizable.xcstrings",
    "wurstfingerKeyboard/Localizable.xcstrings",
]

private enum LocalizationTestError: Error {
    case unreadableCatalog(String)
}

/// Repo root: this file lives in `wurstfingerTests/`, so go up two levels.
private func projectDir(file: String = #filePath) -> URL {
    URL(fileURLWithPath: file)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func loadCatalog(_ relativePath: String) throws -> (source: String, strings: [String: [String: Any]]) {
    let url = projectDir().appendingPathComponent(relativePath)
    let data = try Data(contentsOf: url)
    guard
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let source = json["sourceLanguage"] as? String,
        let strings = json["strings"] as? [String: [String: Any]]
    else {
        throw LocalizationTestError.unreadableCatalog(relativePath)
    }
    return (source, strings)
}

struct LocalizationCompletenessTests {
    @Test("Catalog source language is English", arguments: localizationCatalogs)
    func sourceLanguageIsEnglish(_ relativePath: String) throws {
        let catalog = try loadCatalog(relativePath)
        #expect(catalog.source == "en", "\(relativePath): sourceLanguage should be 'en'")
    }

    @Test("Every string is fully translated in all required languages", arguments: localizationCatalogs)
    func everyStringFullyTranslated(_ relativePath: String) throws {
        let catalog = try loadCatalog(relativePath)
        var problems: [String] = []

        for (key, entry) in catalog.strings {
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            let present = Set(localizations.keys)

            for lang in requiredLanguages.subtracting(present).sorted() {
                problems.append("[\(lang)] missing: \"\(key)\"")
            }

            for lang in requiredLanguages.intersection(present).sorted() {
                guard let loc = localizations[lang] as? [String: Any] else { continue }
                // Plural/device "variations" are an accepted shape; only validate plain string units.
                guard let unit = loc["stringUnit"] as? [String: Any] else {
                    if loc["variations"] == nil {
                        problems.append("[\(lang)] malformed entry: \"\(key)\"")
                    }
                    continue
                }
                let value = (unit["value"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let state = unit["state"] as? String ?? ""
                if value.isEmpty {
                    problems.append("[\(lang)] empty value: \"\(key)\"")
                }
                if state != "translated" {
                    problems.append("[\(lang)] state '\(state)' (expected 'translated'): \"\(key)\"")
                }
            }
        }

        let detail = problems.sorted().joined(separator: "\n")
        #expect(
            problems.isEmpty,
            "\(relativePath) has \(problems.count) localization gap(s):\n\(detail)"
        )
    }

    @Test("Catalog contains no languages outside the supported set", arguments: localizationCatalogs)
    func noUnexpectedLanguages(_ relativePath: String) throws {
        let catalog = try loadCatalog(relativePath)
        let allowed = requiredLanguages.union(["en"])
        var unexpected: Set<String> = []
        for (_, entry) in catalog.strings {
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            unexpected.formUnion(Set(localizations.keys).subtracting(allowed))
        }
        #expect(
            unexpected.isEmpty,
            "\(relativePath): unexpected language(s) \(unexpected.sorted()) — add them to requiredLanguages or remove them"
        )
    }
}
