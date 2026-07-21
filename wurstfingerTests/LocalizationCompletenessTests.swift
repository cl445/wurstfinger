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
    "el", "pt", "uk", "ar", "fa", "ur", "th", "hi", "ja", "ko",
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

/// Collects every `stringUnit` reachable from a single localization value,
/// descending through `variations` (plural / device, possibly nested), so that
/// variation-based translations are validated like plain string units.
private func stringUnits(in localization: [String: Any]) -> [[String: Any]] {
    if let unit = localization["stringUnit"] as? [String: Any] {
        return [unit]
    }
    guard let variations = localization["variations"] as? [String: Any] else {
        return []
    }
    var units: [[String: Any]] = []
    for case let category as [String: Any] in variations.values {
        for case let nested as [String: Any] in category.values {
            units.append(contentsOf: stringUnits(in: nested))
        }
    }
    return units
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
                // Collect every string unit, descending into plural/device
                // "variations" so nested translations are validated too.
                let units = stringUnits(in: loc)
                if units.isEmpty {
                    problems.append("[\(lang)] malformed entry: \"\(key)\"")
                    continue
                }
                for unit in units {
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

// MARK: - Usage → catalog coverage

/// Source directories whose Swift files are scanned for localizable string usage.
private let localizedSourceDirs: [String] = ["wurstfinger", "wurstfingerKeyboard"]

/// A `String(localized:)` usage discovered in the source tree.
private struct LocalizedUsage: Hashable {
    let key: String
    let file: String
    let line: Int
}

/// Matches `String(localized: "…")` and captures the literal, honouring escaped
/// characters inside the string so `\"` does not end the match early.
private let localizedCallRegex: NSRegularExpression = {
    // The pattern is a compile-time constant, so construction cannot fail.
    guard let regex = try? NSRegularExpression(pattern: #"String\(localized:\s*"((?:[^"\\]|\\.)*)""#) else {
        preconditionFailure("Invalid localizedCallRegex pattern")
    }
    return regex
}()

/// Turns a Swift string-literal body back into its runtime value for the escapes
/// that can legally appear in a catalog key (`\"` and `\\`).
private func unescapeSwiftLiteral(_ raw: String) -> String {
    raw.replacingOccurrences(of: "\\\"", with: "\"")
        .replacingOccurrences(of: "\\\\", with: "\\")
}

/// Every non-interpolated `String(localized:)` literal used under the product
/// source directories, with its file and line for actionable failures.
///
/// Interpolated calls (`String(localized: "Enable \(name)")`) are skipped on
/// purpose: Xcode rewrites their catalog key to a format string (`Enable %@`),
/// so the source literal is not the key to look up.
private func scanLocalizedUsages() -> [LocalizedUsage] {
    let root = projectDir()
    var usages: [LocalizedUsage] = []
    let fileManager = FileManager.default

    for dir in localizedSourceDirs {
        let base = root.appendingPathComponent(dir)
        guard let enumerator = fileManager.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            guard let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (index, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let text = String(line)
                let range = NSRange(text.startIndex..., in: text)
                for match in localizedCallRegex.matches(in: text, range: range) {
                    guard let literalRange = Range(match.range(at: 1), in: text) else { continue }
                    let literal = String(text[literalRange])
                    // Skip interpolated calls: Xcode rewrites their key to a format string.
                    if literal.contains("\\(") {
                        continue
                    }
                    usages.append(
                        LocalizedUsage(
                            key: unescapeSwiftLiteral(literal),
                            file: "\(dir)/\(url.lastPathComponent)",
                            line: index + 1
                        )
                    )
                }
            }
        }
    }
    return usages
}

/// Guards the *other* direction from `LocalizationCompletenessTests`: that every
/// string the code asks for actually exists in a catalog. The completeness tests
/// work from the catalog outwards and cannot see a key that was never added, so a
/// `String(localized: "…")` whose key is missing renders as the raw key in every
/// language (as happened in #261) without failing any existing test.
///
/// Scope: this covers the explicit `String(localized:)` API only. Bare
/// `LocalizedStringKey` literals passed to a view initializer (e.g.
/// `SettingsRow(title: "…")`) are not statically detectable without type
/// information and remain outside this guard.
struct LocalizationUsageTests {
    @Test("Every String(localized:) key exists in a catalog")
    func everyLocalizedKeyExistsInCatalog() throws {
        var catalogKeys: Set<String> = []
        for relativePath in localizationCatalogs {
            try catalogKeys.formUnion(loadCatalog(relativePath).strings.keys)
        }

        let usages = scanLocalizedUsages()
        #expect(!usages.isEmpty, "Found no String(localized:) usages to check — has the source layout moved?")

        let missing = usages.filter { !catalogKeys.contains($0.key) }
        let detail = missing
            .sorted { ($0.file, $0.line) < ($1.file, $1.line) }
            .map { "\($0.file):\($0.line)  \"\($0.key)\"" }
            .joined(separator: "\n")
        #expect(
            missing.isEmpty,
            "\(missing.count) localized string(s) used in code but absent from every catalog:\n\(detail)"
        )
    }
}
