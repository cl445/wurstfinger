//
//  MarketingMetadataTests.swift
//  wurstfingerTests
//
//  The App Store copy and the README state the number of keyboard layouts by
//  hand. Reads them from the repo (like LocalizationCompletenessTests) and
//  checks the number against the registry, so a new layout cannot ship with
//  stale marketing copy.
//

import Foundation
import Testing
@testable import WurstfingerApp

private enum MarketingMetadataError: Error {
    case unreadableFile(String)
}

/// Repo root: this file lives in `wurstfingerTests/`, so go up two levels.
private func repoRoot(file: String = #filePath) -> URL {
    URL(fileURLWithPath: file)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

struct MarketingMetadataTests {
    /// Only the count is checked: the lists themselves are prose and stay a
    /// manual review item.
    @Test(arguments: [
        (path: "fastlane/metadata/en-US/description.txt", noun: "Keyboard Layouts"),
        (path: "fastlane/metadata/de-DE/description.txt", noun: "Tastaturlayouts"),
        (path: "README.md", noun: "keyboard layouts"),
    ])
    func statedLayoutCountMatchesTheRegistry(file: (path: String, noun: String)) throws {
        let url = repoRoot().appendingPathComponent(file.path)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw MarketingMetadataError.unreadableFile(file.path)
        }

        let pattern = #"(\d+)\s+"# + NSRegularExpression.escapedPattern(for: file.noun)
        let regex = try NSRegularExpression(pattern: pattern)
        let ns = text as NSString
        let match = try #require(
            regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
            "\(file.path) no longer states a number of \"\(file.noun)\""
        )
        let stated = try #require(Int(ns.substring(with: match.range(at: 1))))
        let shipped = KeyboardRegistry.available.count

        #expect(stated == shipped, "\(file.path) claims \(stated) \(file.noun), but \(shipped) layouts ship")
    }
}
