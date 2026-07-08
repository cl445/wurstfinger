//
//  KeyboardHealthLogTests.swift
//  wurstfingerTests
//
//  Tests for the release-safe keyboard health log.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct KeyboardHealthLogTests {
    /// Isolated file URL per test so parallel tests cannot interfere.
    private func makeTestFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("health-log-test-\(UUID().uuidString).json")
    }

    @Test func recordAppendsEntryWithLabelAndFootprint() {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url)

        log.record("viewDidLoad.start")

        let entries = log.entries()
        #expect(entries.count == 1)
        #expect(entries[0].label == "viewDidLoad.start")
        #expect(entries[0].usedMB > 0)
    }

    @Test func entriesAreOrderedOldestFirst() {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url)

        log.record("first")
        log.record("second")

        #expect(log.entries().map(\.label) == ["first", "second"])
    }

    @Test func recordTrimsOldestEntriesBeyondMax() {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url, maxEntries: 3)

        for index in 0 ..< 5 {
            log.record("event-\(index)")
        }

        #expect(log.entries().map(\.label) == ["event-2", "event-3", "event-4"])
    }

    @Test func clearRemovesAllEntries() {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url)

        log.record("event")
        log.clear()

        #expect(log.entries().isEmpty)
    }

    @Test func entriesAreEmptyWhenFileIsMissing() {
        let log = KeyboardHealthLog(fileURL: makeTestFileURL())

        #expect(log.entries().isEmpty)
    }

    @Test func corruptFileIsDiscardedAndOverwritten() throws {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        let log = KeyboardHealthLog(fileURL: url)

        #expect(log.entries().isEmpty)

        log.record("after-corruption")
        #expect(log.entries().map(\.label) == ["after-corruption"])
    }

    @Test func nilFileURLIsANoOp() {
        let log = KeyboardHealthLog(fileURL: nil)

        log.record("event")

        #expect(log.entries().isEmpty)
    }

    @Test func entriesSurviveAcrossInstances() {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        KeyboardHealthLog(fileURL: url).record("cold-start")
        let entries = KeyboardHealthLog(fileURL: url).entries()

        #expect(entries.map(\.label) == ["cold-start"])
    }
}
