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
/// characters inside the string so `\"` does not end the match early. `\s*` after
/// the paren and the colon tolerates a call whose arguments wrap onto new lines.
///
/// The `(?!"")` after the opening quote skips multiline string literals
/// (`String(localized: """…""")`): the opening `"""` would otherwise read as an
/// empty `""` and report a bogus missing key. Reconstructing a multiline literal's
/// key means replaying Swift's indentation stripping and `\`-continuations, so
/// those keys stay out of scope here and are covered catalog-side by
/// `LocalizationCompletenessTests` instead.
private let localizedCallRegex: NSRegularExpression = {
    // The pattern is a compile-time constant, so construction cannot fail.
    guard let regex = try? NSRegularExpression(pattern: #"String\(\s*localized:\s*"(?!"")((?:[^"\\]|\\.)*)""#) else {
        preconditionFailure("Invalid localizedCallRegex pattern")
    }
    return regex
}()

/// Decodes a Swift single-line string-literal body to its runtime value, so the
/// key we look up matches the one Xcode derives from the same literal.
///
/// A single left-to-right pass, not chained `replacingOccurrences`: the latter
/// would misread `\\n` (an escaped backslash followed by `n`) as a newline. An
/// unrecognised escape keeps the character after the backslash, which is what
/// Swift does for the escapes that do not appear in catalog keys.
private func unescapeSwiftLiteral(_ raw: String) -> String {
    var result = ""
    result.reserveCapacity(raw.count)
    var iterator = raw.makeIterator()
    while let ch = iterator.next() {
        guard ch == "\\", let escaped = iterator.next() else {
            result.append(ch)
            continue
        }
        switch escaped {
        case "n": result.append("\n")
        case "t": result.append("\t")
        case "r": result.append("\r")
        case "0": result.append("\0")
        default: result.append(escaped)
        }
    }
    return result
}

/// Every non-interpolated `String(localized:)` literal used under the product
/// source directories, with its file and line for actionable failures.
///
/// Interpolated calls (`String(localized: "Enable \(name)")`) are skipped on
/// purpose: Xcode rewrites their catalog key to a format string (`Enable %@`),
/// so the source literal is not the key to look up. Multiline literals
/// (`String(localized: """…""")`) are likewise skipped — see `localizedCallRegex`.
private func scanLocalizedUsages() -> [LocalizedUsage] {
    let root = projectDir()
    var usages: [LocalizedUsage] = []
    let fileManager = FileManager.default

    for dir in localizedSourceDirs {
        let base = root.appendingPathComponent(dir)
        guard let enumerator = fileManager.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            guard let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
            // Scan the whole file rather than line by line: a call whose arguments
            // wrap (`String(\n    localized: "…"\n)`) keeps its literal intact this
            // way, and the line number is recovered from the match's offset.
            let ns = source as NSString
            let fullRange = NSRange(location: 0, length: ns.length)
            for match in localizedCallRegex.matches(in: source, range: fullRange) {
                let literal = ns.substring(with: match.range(at: 1))
                // Skip interpolated calls: Xcode rewrites their key to a format string.
                if literal.contains("\\(") {
                    continue
                }
                let line = ns.substring(to: match.range.location)
                    .reduce(1) { $0 + ($1 == "\n" ? 1 : 0) }
                usages.append(
                    LocalizedUsage(
                        key: unescapeSwiftLiteral(literal),
                        file: "\(dir)/\(url.lastPathComponent)",
                        line: line
                    )
                )
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
