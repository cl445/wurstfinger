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
            // Entries marked "shouldTranslate": false stay in the source
            // language everywhere (e.g. proper names like "Dark Gold").
            if entry["shouldTranslate"] as? Bool == false {
                continue
            }
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

/// Source directories scanned for localizable strings, mapped to the catalogs
/// a key used there must exist in.
///
/// `wurstfingerKeyboard/` compiles into *both* products — the app renders the
/// real keyboard in its previews and showcase — so a string used there is
/// looked up in whichever bundle is running and must exist in both catalogs.
/// A host-only string needs the host catalog only; the extension's catalog
/// deliberately carries just the strings the keyboard itself displays.
private let catalogsRequiredBySourceDir: [String: [String]] = [
    "wurstfinger": ["wurstfinger/Localizable.xcstrings"],
    "wurstfingerKeyboard": localizationCatalogs,
]

/// A localizable string usage discovered in the source tree.
private struct LocalizedUsage: Hashable {
    let key: String
    /// Source directory the file was scanned under, i.e. the key into
    /// `catalogsRequiredBySourceDir`.
    let dir: String
    /// Path relative to the repo root, so a failure names a file that exists.
    let file: String
    let line: Int
}

/// Repo-relative path of a scanned source file.
private func repoRelativePath(of url: URL) -> String {
    let root = projectDir().standardizedFileURL.path + "/"
    let path = url.standardizedFileURL.path
    return path.hasPrefix(root) ? String(path.dropFirst(root.count)) : path
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

    for dir in catalogsRequiredBySourceDir.keys.sorted() {
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
                        dir: dir,
                        file: repoRelativePath(of: url),
                        line: line
                    )
                )
            }
        }
    }
    return usages
}

/// Catalog keys per catalog path, so a usage can be checked against exactly the
/// catalogs its source directory ships into.
private func catalogKeysByPath() throws -> [String: Set<String>] {
    var keysByCatalog: [String: Set<String>] = [:]
    for relativePath in localizationCatalogs {
        keysByCatalog[relativePath] = try Set(loadCatalog(relativePath).strings.keys)
    }
    return keysByCatalog
}

/// One `file:line  "key" absent from <catalog>` line per gap, sorted by source
/// position so the report reads like a compiler's.
private func missingUsageReport(
    _ usages: [LocalizedUsage],
    keysByCatalog: [String: Set<String>]
) -> [String] {
    usages
        .sorted { ($0.file, $0.line, $0.key) < ($1.file, $1.line, $1.key) }
        .flatMap { usage in
            (catalogsRequiredBySourceDir[usage.dir] ?? [])
                .filter { keysByCatalog[$0]?.contains(usage.key) != true }
                .map { "\(usage.file):\(usage.line)  \"\(usage.key)\" absent from \($0)" }
        }
}

/// Guards the *other* direction from `LocalizationCompletenessTests`: that every
/// string the code asks for actually exists in a catalog. The completeness tests
/// work from the catalog outwards and cannot see a key that was never added, so a
/// `String(localized: "…")` whose key is missing renders as the raw key in every
/// language (as happened in #261) without failing any existing test.
///
/// Scope: this covers the explicit `String(localized:)` API only. Bare
/// `LocalizedStringKey` literals passed to a view initializer are covered by
/// `LocalizedViewLiteralTests` below.
struct LocalizationUsageTests {
    @Test("Every String(localized:) key exists in the catalogs of the targets that compile it")
    func everyLocalizedKeyExistsInCatalog() throws {
        let keysByCatalog = try catalogKeysByPath()

        let usages = scanLocalizedUsages()
        #expect(!usages.isEmpty, "Found no String(localized:) usages to check — has the source layout moved?")

        let missing = missingUsageReport(usages, keysByCatalog: keysByCatalog)
        let detail = missing.joined(separator: "\n")
        #expect(
            missing.isEmpty,
            "\(missing.count) localized string(s) used in code but absent from a catalog of a target that compiles them:\n\(detail)"
        )
    }
}

// MARK: - View literal → catalog coverage

/// Screens shipped in English only, with the reason. A file listed here is
/// skipped below; everything else must have every user-visible literal in a
/// catalog, so adding an English-only screen forces an entry here — and a line
/// in `docs/localization.md`.
private let englishOnlyViewFiles: [String: String] = [
    "wurstfinger/ExpertSettingsView.swift":
        "Gesture-tuning vocabulary nobody on the team can review in 22 translations; diagnostic tool behind an acknowledgement gate.",
    "wurstfinger/GesturePlaygroundView.swift":
        "Reachable only from the Expert screen and shares its vocabulary.",
    "wurstfinger/KeyboardHealthView.swift":
        "Reachable only from the Expert screen; renders raw on-device diagnostics.",
    "wurstfinger/ImprintView.swift":
        "Legal notice kept in a single authoritative wording.",
    "wurstfinger/AppStoreScreenshotView.swift":
        "Marketing screenshot chrome, not app UI.",
]

/// User-visible literals that read the same in every language.
private let untranslatedProperNouns: Set<String> = ["GitHub", "MIT", "Wurstfinger"]

/// First-argument literal of the SwiftUI initializers and modifiers whose
/// parameter is a `LocalizedStringKey`. These are the strings
/// `LocalizationUsageTests` cannot see: a bare literal carries no
/// `String(localized:)` marker.
private let viewLiteralRegex: NSRegularExpression = {
    // `ColorPicker` is listed separately: `\bPicker\(` cannot match inside the
    // word, so without its own alternative every color-well label in the theme
    // editor would be invisible to this test.
    let inits = "Text|Button|Toggle|TextField|Section|Label|ColorPicker|Picker|Link|Stepper|NavigationLink"
    let modifiers = "navigationTitle|accessibilityLabel|accessibilityHint|alert|confirmationDialog"
    let pattern = #"(?:\b(?:"# + inits + #")\(|\.(?:"# + modifiers + #")\()\s*"(?!"")((?:[^"\\]|\\.)*)""#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        preconditionFailure("Invalid viewLiteralRegex pattern")
    }
    return regex
}()

/// `title:` / `description:` arguments of the app's own row components
/// (`SettingsRow`, `SetupStepView`, `hapticControl`), which take
/// `LocalizedStringKey`. Host-only on purpose: the same labels under
/// `wurstfingerKeyboard/` name layout data (`LanguageDescriptor(title:)`),
/// not UI strings.
private let hostRowLabelRegex: NSRegularExpression = {
    guard let regex = try? NSRegularExpression(
        pattern: #"\b(?:title|description):\s*"(?!"")((?:[^"\\]|\\.)*)""#
    ) else {
        preconditionFailure("Invalid hostRowLabelRegex pattern")
    }
    return regex
}()

/// Every literal a view hands to a `LocalizedStringKey` parameter, minus the
/// English-only screens, the proper nouns, and literals without letters
/// (slider tick marks like "35%" or "1.62", identical in every language).
private func scanViewLiterals() -> [LocalizedUsage] {
    let root = projectDir()
    var usages: [LocalizedUsage] = []
    let fileManager = FileManager.default

    for dir in catalogsRequiredBySourceDir.keys.sorted() {
        let base = root.appendingPathComponent(dir)
        guard let enumerator = fileManager.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let file = repoRelativePath(of: url)
            guard englishOnlyViewFiles[file] == nil,
                  let source = try? String(contentsOf: url, encoding: .utf8)
            else { continue }
            let ns = source as NSString
            let fullRange = NSRange(location: 0, length: ns.length)
            let regexes = dir == "wurstfinger" ? [viewLiteralRegex, hostRowLabelRegex] : [viewLiteralRegex]
            for regex in regexes {
                for match in regex.matches(in: source, range: fullRange) {
                    let literal = ns.substring(with: match.range(at: 1))
                    // Interpolated labels become format strings, proper nouns read
                    // the same everywhere, and a literal without letters is not a
                    // phrase (slider tick marks like "35%").
                    if literal.contains("\\(") { continue }
                    let key = unescapeSwiftLiteral(literal)
                    if untranslatedProperNouns.contains(key) || !key.contains(where: \.isLetter) {
                        continue
                    }
                    let line = ns.substring(to: match.range.location)
                        .reduce(1) { $0 + ($1 == "\n" ? 1 : 0) }
                    usages.append(LocalizedUsage(key: key, dir: dir, file: file, line: line))
                }
            }
        }
    }
    return usages
}

/// Covers the blind spot `LocalizationUsageTests` documents: a bare literal
/// passed to a `LocalizedStringKey` parameter (`Text("Keyboard Size")`) is a
/// localizable string with no marker in the source, so a missing catalog entry
/// renders as English in all 22 translations and no other test notices.
struct LocalizedViewLiteralTests {
    @Test("Every user-visible view literal exists in a catalog")
    func everyViewLiteralExistsInCatalog() throws {
        let keysByCatalog = try catalogKeysByPath()

        let usages = scanViewLiterals()
        #expect(!usages.isEmpty, "Found no view literals to check — has the source layout moved?")

        let missing = missingUsageReport(usages, keysByCatalog: keysByCatalog)
        let detail = missing.joined(separator: "\n")
        let hint = "add the key to the catalog, or list the file in `englishOnlyViewFiles`"
            + " with a reason and record it in docs/localization.md"
        #expect(
            missing.isEmpty,
            "\(missing.count) view literal(s) render untranslated — \(hint):\n\(detail)"
        )
    }

    @Test("The English-only allowlist has no stale entries")
    func englishOnlyAllowlistIsCurrent() {
        let root = projectDir()
        for (file, reason) in englishOnlyViewFiles.sorted(by: { $0.key < $1.key }) {
            #expect(
                FileManager.default.fileExists(atPath: root.appendingPathComponent(file).path),
                "\(file) is allowlisted as English-only but no longer exists — drop the entry"
            )
            #expect(!reason.isEmpty, "\(file) needs a reason for being English-only")
        }
    }
}
