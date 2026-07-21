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

    /// Recording a second entry must not rewrite the bytes of the first: the
    /// hot path is an O(1) append, not a full read-decode-encode-rewrite of a
    /// JSON array.
    @Test func recordWritesAppendOnlyDoesNotRewritePriorBytes() throws {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url, maxEntries: 100)

        log.record("first")
        _ = log.entries() // drain the async append
        let data1 = try Data(contentsOf: url)
        log.record("second")
        _ = log.entries()
        let data2 = try Data(contentsOf: url)

        #expect(data2.count > data1.count)
        #expect(data2.prefix(data1.count) == data1)
        // Not a JSON array: an append-only JSONL file never opens with `[` (0x5B).
        #expect(data1.first != 0x5B)

        let decoder = JSONDecoder()
        let perLine = data2.split(separator: 0x0A)
            .compactMap { try? decoder.decode(KeyboardHealthLog.Entry.self, from: Data($0)) }
        #expect(perLine.map(\.label) == ["first", "second"])
    }

    /// The on-disk file is physically compacted once it grows past the
    /// size threshold, so it never accumulates one line per lifetime event,
    /// while `entries()` still returns only the last `maxEntries`.
    @Test func appendOnlyFileIsPhysicallyCompactedWhileEntriesReturnsLastMax() throws {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url, maxEntries: 3)

        for index in 0 ..< 100 {
            log.record("event-\(index)")
        }
        _ = log.entries() // drain

        #expect(log.entries().map(\.label) == ["event-97", "event-98", "event-99"])

        let decoder = JSONDecoder()
        let perLine = try Data(contentsOf: url).split(separator: 0x0A)
            .compactMap { try? decoder.decode(KeyboardHealthLog.Entry.self, from: Data($0)) }
        #expect(perLine.count >= 1)
        #expect(perLine.count <= 2 * 3 + 2)
    }

    /// The file URL provider must not be invoked at construction — that is
    /// what keeps the shared instance's `containerURL(...)` IPC off the
    /// main/spawn thread. It is resolved lazily on first file access.
    @Test func fileURLProviderIsNotResolvedAtInit() {
        var resolveCount = 0
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURLProvider: {
            resolveCount += 1
            return url
        })

        #expect(resolveCount == 0)

        log.record("e")
        _ = log.entries() // ioQueue.sync — any deferred resolution has completed

        #expect(resolveCount >= 1)
    }
}
