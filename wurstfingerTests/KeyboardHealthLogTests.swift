//
//  KeyboardHealthLogTests.swift
//  wurstfingerTests
//
//  Tests for the release-safe keyboard health log.
//

import Foundation
import Testing
@testable import WurstfingerApp

/// Serialized: every instance shares one static serial io queue, and the
/// deferred-sample cases below both assert on wall-clock timing and (in
/// `staleDeferredSampleIsDiscarded`) deliberately park in that queue. Running
/// them against each other would make one test's blockage the other's missing
/// entry.
///
/// **Invariant this suite rests on: nothing outside it touches
/// `KeyboardHealthLog`.** The queue it parks is process-wide — one
/// `KeyboardHealthLog.ioQueue` for every log instance in the process — while
/// `.serialized` only orders this suite against itself, not against the rest
/// of the run. A test in another suite that recorded, read or cleared a health
/// log, directly or by driving a `KeyboardViewController` path that does,
/// could therefore be scheduled straight into the park below and inherit the
/// stall: ~0.5 s normally, up to the 5 s its watchdog allows. It would show up
/// as a slow suite rather than as this, which is why the invariant is written
/// down instead of merely holding. Before adding such a test, put it in this
/// suite or give the parking case a queue of its own.
@Suite(.serialized)
struct KeyboardHealthLogTests {
    /// Isolated file URL per test so parallel tests cannot interfere.
    private func makeTestFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("health-log-test-\(UUID().uuidString).json")
    }

    /// Fire delay for the deferred-sample cases that have to *observe* the
    /// entry they queue.
    ///
    /// `recordDeferred` derives its discard window from the fire delay
    /// (`discardAfter = deadline + delay`), so the delay is also the budget a
    /// loaded runner has for getting the utility-QoS block onto the io queue.
    /// A 200 ms delay therefore leaves 200 ms of budget, and a runner that far
    /// behind turns a correct implementation red — never green, the direction
    /// is safe, but `recordDeferredWithoutAFileIsANoOp` has flaked that way on
    /// CI. One second buys a full second of slack for one second of runtime
    /// per test.
    ///
    /// Raising the delay is deliberately preferred over handing
    /// `recordDeferred` an explicit discard-window parameter: the window is
    /// production behavior *derived* from the delay, and a parameter existing
    /// only for these three call sites would widen the production surface
    /// while stopping the tests from exercising the derivation they are here
    /// for. `staleDeferredSampleIsDiscarded` pins the other end of it.
    private static let deferredFireDelay: TimeInterval = 1

    /// When those cases read the log: one discard window past the fire delay,
    /// so a sample the runner held back by up to `deferredFireDelay` has still
    /// landed before the assertion looks — the same slack the discard guard
    /// gets, on the observation side.
    private static let deferredObservationDelay = Duration.seconds(2)

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

    /// A clear empties the log down to its tombstone and nothing else — the
    /// marker takes the place of what it removed. Everything downstream keys
    /// off that being the whole content of a freshly cleared log:
    /// `KeyboardHealthView` folds a tombstone-only log back into its empty
    /// state.
    @Test func clearReplacesAllEntriesWithATombstone() throws {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url)

        log.record("event")
        log.clear()

        let entries = log.entries()
        #expect(entries.map(\.label) == [KeyboardHealthLog.clearedLabel])
        let tombstone = try #require(entries.first)
        // Stamped in the host app: its footprint is not the extension's, and
        // a number here would be read against the extension's jetsam budget
        // and counted into the peak.
        #expect(tombstone.usedMB == 0)
        #expect(tombstone.availableMB == 0)
    }

    /// The case the tombstone exists for. `clear()` runs in the host app while
    /// the extension process may already have a `postShedSettled` sample
    /// queued from a dismissal seconds earlier, and nothing crosses between
    /// the two, so the freshly emptied log does grow that entry. Ordering it
    /// behind the tombstone is what makes it read as the first event *after*
    /// the clear rather than as a clear that did not take.
    @Test func anEntryArrivingAfterAClearIsOrderedBehindTheTombstone() {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url)

        log.record("viewDidDisappear")
        log.clear()
        log.record("postShedSettled")

        #expect(log.entries().map(\.label) == [KeyboardHealthLog.clearedLabel, "postShedSettled"])
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

    /// A handle failure on an *existing* file must not replace the history:
    /// the entries already on disk are the resume-jetsam forensics the log
    /// exists for, and the container can be unwritable exactly when the
    /// keyboard is being suspended.
    @Test func unwritableExistingFileKeepsPriorEntries() throws {
        let url = makeTestFileURL()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: url)
        }
        let log = KeyboardHealthLog(fileURL: url)
        log.recordAndFlush("before-lock")

        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        log.recordAndFlush("while-locked")

        #expect(log.entries().map(\.label) == ["before-lock"])
    }

    /// Compaction must not rewrite a file it could not read either: an
    /// oversized log whose read fails decodes to nothing, and writing that
    /// back would empty the very file the append guard just protected.
    @Test func compactionKeepsAnUnreadableFileIntact() throws {
        let url = makeTestFileURL()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: url)
        }
        let encoder = JSONEncoder()
        var seeded = Data()
        for index in 0 ..< 40 {
            try seeded.append(encoder.encode(KeyboardHealthLog.Entry(
                id: UUID(), date: Date(), label: "seed-\(index)", usedMB: 1, availableMB: 1
            )))
            seeded.append(0x0A)
        }
        try seeded.write(to: url)
        // Writable but unreadable, so the append itself still succeeds and
        // only compaction's read-then-rewrite can destroy the seeded history.
        try FileManager.default.setAttributes([.posixPermissions: 0o222], ofItemAtPath: url.path)

        KeyboardHealthLog(fileURL: url, maxEntries: 2).recordAndFlush("while-unreadable")

        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        let persisted = try Data(contentsOf: url)
        #expect(persisted.prefix(seeded.count) == seeded)
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

    /// `recordAndFlush` must not return before its entry is on disk: it
    /// exists for the suspension path, where the process may be frozen (and
    /// later jetsam-killed on resume) before an async queue hop would run.
    /// The raw file is read directly — going through `entries()` would drain
    /// a still-pending async write via its `ioQueue.sync` and mask a
    /// regression to fire-and-forget behavior.
    @Test func recordAndFlushPersistsBeforeReturning() throws {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url)

        log.recordAndFlush("viewDidDisappear")

        let decoder = JSONDecoder()
        let persisted = try Data(contentsOf: url).split(separator: 0x0A)
            .compactMap { try? decoder.decode(KeyboardHealthLog.Entry.self, from: Data($0)) }
        let entry = try #require(persisted.first)
        #expect(persisted.count == 1)
        #expect(entry.label == "viewDidDisappear")
        #expect(entry.usedMB > 0)
    }

    /// Flushing also drains earlier fire-and-forget records (the serial queue
    /// preserves order), so the appearance entries from the same session hit
    /// the disk before the process is frozen too.
    @Test func recordAndFlushDrainsPriorAsyncRecords() throws {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url)

        log.record("viewWillAppear")
        log.recordAndFlush("hostDidEnterBackground")

        let decoder = JSONDecoder()
        let perLine = try Data(contentsOf: url).split(separator: 0x0A)
            .compactMap { try? decoder.decode(KeyboardHealthLog.Entry.self, from: Data($0)) }
        #expect(perLine.map(\.label) == ["viewWillAppear", "hostDidEnterBackground"])
    }

    /// The deferred sample rides on the suspension path, so it must cost the
    /// caller nothing and must genuinely read the footprint *late*: sampling
    /// at the call site like `record`/`recordAndFlush` would defeat its whole
    /// purpose (the reclaim it waits for is what the entry is about). The
    /// entry's own `date` is the witness — it is stamped in the same step as
    /// the footprint, so a call-site sample would carry the call time.
    @Test func recordDeferredWritesLateWithoutBlockingTheCaller() async throws {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url)

        let started = Date()
        log.recordDeferred("postShedSettled", after: Self.deferredFireDelay)
        let elapsed = Date().timeIntervalSince(started)

        // A quarter of the delay, so it still witnesses "the call did not
        // wait for the sample" while leaving a descheduled test thread room to
        // be late.
        #expect(elapsed < 0.25)
        // `entries()` syncs through the same serial queue, so an entry written
        // as part of the call would already be visible here.
        #expect(log.entries().isEmpty)

        try await Task.sleep(for: Self.deferredObservationDelay)
        let entries = log.entries()
        #expect(entries.map(\.label) == ["postShedSettled"])
        let entry = try #require(entries.first)
        #expect(entry.usedMB > 0)
        // Half the delay, not a hair under it: the timer never fires early,
        // but this compares wall clock against dispatch's uptime clock, which
        // are not the same ruler. The gap only has to separate a late sample
        // from a call-site one, and a call-site sample would read ~0.
        #expect(entry.date.timeIntervalSince(started) > Self.deferredFireDelay / 2)
    }

    /// The suspension path writes both entries for the same event — the
    /// guaranteed flushed one and the settled one 2 s later — and forensics
    /// reads them as a pair, so the deferred entry must land *after* the
    /// flushed one even though it was queued while that write was in flight.
    /// The delay doubles as the discard window (see `recordDeferred` and
    /// `deferredFireDelay`), so it is kept a full second above the scheduling
    /// jitter of a loaded test machine.
    @Test func deferredSampleAppendsAfterTheFlushedSuspensionEntry() async throws {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url)

        log.recordAndFlush("viewDidDisappear")
        log.recordDeferred("postShedSettled", after: Self.deferredFireDelay)

        try await Task.sleep(for: Self.deferredObservationDelay)
        #expect(log.entries().map(\.label) == ["viewDidDisappear", "postShedSettled"])
    }

    /// A frozen process does not lose a pending deferred sample — libdispatch
    /// runs the overdue block as soon as the process is scheduled again, and
    /// the extension process is reused across host cycles, so the sample can
    /// arrive against a keyboard that has nothing to do with its label. It has
    /// to be discarded instead. Modelled by parking in the shared io queue
    /// past the discard window: from the block's side that is the same
    /// situation — enqueued on time, given CPU far too late.
    ///
    /// This is the one case that keeps the short delay the positive cases gave
    /// up (see `deferredFireDelay`), and it needs no margin: a slower machine
    /// only releases the block later, i.e. further past the discard window, so
    /// load pushes this test towards passing for the right reason. Keeping it
    /// short also keeps the park — the whole suite's blocking cost, see the
    /// suite header — down to ~0.5 s. Together with the positive cases it is
    /// what pins the production window at `deadline + delay`: on-time samples
    /// are written, samples more than their own delay overdue are not.
    @Test func staleDeferredSampleIsDiscarded() async throws {
        let url = makeTestFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let log = KeyboardHealthLog(fileURL: url)

        // A second instance parks in the one io queue every instance shares:
        // its provider is called on that queue and does not return.
        let parked = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let blocker = KeyboardHealthLog(fileURLProvider: {
            parked.signal()
            release.wait()
            return nil
        })
        blocker.record("occupies the io queue")
        // Also releases when an expectation below fails early: an io queue
        // left parked would hang every later test in this process.
        defer { release.signal() }
        if case .timedOut = parked.wait(timeout: .now() + 5) {
            Issue.record("the io queue never picked up the blocking record")
            return
        }

        log.recordDeferred("postShedSettled", after: 0.1)
        // Past the deadline plus the delay again — from there on the sample no
        // longer describes the moment its label names.
        try await Task.sleep(for: .milliseconds(400))
        release.signal()

        // `entries()` syncs through the same queue behind the released blocker
        // and behind the overdue sample, so this reads the outcome, not a race.
        #expect(log.entries().isEmpty)
    }

    /// Without a container there is nowhere to write, and the deferred sample
    /// must neither trap nor find somewhere else to put itself. An empty
    /// `entries()` cannot witness that alone — a nil provider returns `[]`
    /// whatever the block did — so the provider counts its calls: the timer
    /// has to have fired, asked where to write, and then written nothing.
    @Test func recordDeferredWithoutAFileIsANoOp() async throws {
        let consulted = CallCounter()
        let log = KeyboardHealthLog(fileURLProvider: {
            consulted.increment()
            return nil
        })

        log.recordDeferred("postShedSettled", after: Self.deferredFireDelay)

        try await Task.sleep(for: Self.deferredObservationDelay)
        // Snapshot before `entries()`, which consults the provider itself.
        let consultedByTheSample = consulted.count
        #expect(log.entries().isEmpty)
        #expect(consultedByTheSample >= 1)
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

    /// Counts provider calls made on the io queue and read from the test
    /// thread, so the increment is not the data race a captured `var` would be.
    private final class CallCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var calls = 0

        func increment() {
            lock.lock()
            calls += 1
            lock.unlock()
        }

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return calls
        }
    }
}
