//
//  KeyboardHealthLog.swift
//  Wurstfinger
//
//  Release-safe lifecycle and memory telemetry for the keyboard extension.
//

import Foundation
import os

/// Records keyboard-extension lifecycle events together with the process's
/// memory footprint into a file in the shared app group — in Release builds
/// too, where `Logger` output is only reachable with a Mac.
///
/// Keyboard extensions run under a tight (~48–66 MB) memory budget and are
/// spawned into memory- and time-critical host contexts (SpringBoard hosts
/// the home-screen search field). When iOS declines to spawn the extension or
/// jetsams it, the user silently gets the system keyboard and no crash report
/// is written. This log answers two questions on-device after such an
/// incident: did the extension process run at that moment at all, and how
/// close to the memory budget was it? The host app renders the log in the
/// expert settings (`KeyboardHealthView`).
///
/// The log is persisted as a file rather than in `SharedDefaults`: every
/// defaults write fires the in-process `didChangeNotification`, which would
/// trigger a redundant settings reload on each keyboard appearance.
///
/// `record` captures the footprint synchronously at the call site (so the
/// measurement is attributed to the right lifecycle point) but persists on a
/// serial utility queue — file I/O must not sit in the keyboard's launch
/// path. The suspension path uses `recordAndFlush` instead: there the write
/// must land before the process is frozen, and latency does not matter.
/// `recordDeferred` covers the one case neither serves — a figure that is
/// only correct some time *after* the call site — and is allowed to go
/// missing: the caller can cancel it, and a sample that arrives long after
/// its deadline is discarded rather than logged (see there). A host-app clear
/// racing an extension write can lose one side — acceptable for diagnostics,
/// and the file stays bounded by `maxEntries` either way.
struct KeyboardHealthLog {
    struct Entry: Codable, Equatable, Identifiable {
        let id: UUID
        /// Wall-clock time of the event, for correlating with incidents where
        /// the system keyboard appeared instead of Wurstfinger.
        let date: Date
        /// Lifecycle point, e.g. "viewDidLoad.start" or "didReceiveMemoryWarning".
        let label: String
        /// Physical footprint — the figure iOS compares against the jetsam limit.
        let usedMB: Double
        /// Memory still grantable before jetsam, per `os_proc_available_memory`.
        /// Zero outside the extension process, where the API is unsupported.
        let availableMB: Double
    }

    /// Bounds the log file (~50 KB). A cold start records four entries, and a
    /// cleanly closed open→close cycle up to four — `viewWillAppear`,
    /// `viewDidAppear`, the suspension entry that closes it, and the deferred
    /// `postShedSettled` sample that follows it (see
    /// `KeyboardViewController.shedMemoryBeforeSuspension`) — so this holds
    /// roughly seventy cycles: still days of typical usage.
    ///
    /// "Cleanly closed" is not guaranteed. When the host app is killed
    /// outright while the keyboard is on screen, iOS calls nothing back: no
    /// closing entry is written and no shedding runs, so the log jumps from
    /// `viewDidAppear` straight to the next launch's `viewDidLoad.start`. That
    /// gap is a legible signature, not a defect of the log — it is the one
    /// path on which the extension idles at its full pre-shed weight until the
    /// system reaps it. No callback exists to close the cycle at the source.
    static let defaultMaxEntries = 300

    static let fileName = "keyboard-health-log.json"

    /// Label of the tombstone entry `clear()` leaves behind — see there for
    /// why a cleared log is not simply an empty one. Consumers key off this
    /// constant rather than the literal: `KeyboardHealthView` folds the
    /// tombstone away while it is the only entry, and keeps it out of the
    /// summary figures.
    static let clearedLabel = "logCleared"

    /// Shared instance persisting into the app group container. The
    /// `containerURL(...)` lookup is out-of-process IPC; it is deferred into a
    /// provider closure so it runs lazily inside the `ioQueue` on first file
    /// access, never synchronously on the main thread during the latency-
    /// critical extension spawn.
    static let shared = KeyboardHealthLog(fileURLProvider: {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.suiteName)?
            .appendingPathComponent(fileName)
    })

    private let fileURLProvider: () -> URL?
    private let maxEntries: Int

    /// Approximate encoded size of one entry, used to size the compaction
    /// threshold. Only needs to be within an order of magnitude.
    private static let approxBytesPerEntry = 160

    /// Compaction fires once the file grows past this many bytes, i.e. roughly
    /// once every `maxEntries` appends — keeping the append hot path O(1)
    /// amortized while bounding the file to ~`2 * maxEntries` entries on disk.
    private var trimThresholdBytes: Int {
        2 * maxEntries * Self.approxBytesPerEntry
    }

    /// Serializes all file access across instances. `record` hops onto it
    /// asynchronously; `entries()`/`clear()` sync through it, so reads always
    /// observe every previously recorded entry.
    private static let ioQueue = DispatchQueue(
        label: "de.akator.wurstfinger.keyboard-health-log",
        qos: .utility
    )

    private static let logger = Logger(subsystem: "de.akator.wurstfinger", category: "memory")

    init(fileURL: URL?, maxEntries: Int = KeyboardHealthLog.defaultMaxEntries) {
        self.init(fileURLProvider: { fileURL }, maxEntries: maxEntries)
    }

    init(fileURLProvider: @escaping () -> URL?, maxEntries: Int = KeyboardHealthLog.defaultMaxEntries) {
        self.fileURLProvider = fileURLProvider
        self.maxEntries = maxEntries
    }

    /// Records the current footprint under the given lifecycle label.
    func record(_ label: String) {
        let entry = makeEntry(label)
        Self.ioQueue.async { appendEntry(entry) }
    }

    /// Records like `record(_:)`, but returns only once the entry is on disk.
    /// For the suspension path: a suspended process may never get CPU time
    /// again — a resume-jetsam kills it on wake before queued writes run —
    /// and the post-shedding footprint entry is exactly what those incidents
    /// need. The serial queue also drains any earlier async records first.
    /// Not for the launch path, where file I/O must stay off the main thread.
    func recordAndFlush(_ label: String) {
        let entry = makeEntry(label)
        Self.ioQueue.sync { appendEntry(entry) }
    }

    /// Records an entry whose footprint is sampled `delay` seconds from now,
    /// on a strictly best-effort basis, and hands back the pending work item
    /// so the caller can void it once the premise it was queued under stops
    /// holding.
    ///
    /// The inverse of the other two: they sample at the call site precisely so
    /// the figure belongs to that lifecycle point, while this one deliberately
    /// samples *late*, for the case where the interesting number only becomes
    /// true after something the call site cannot wait for has settled (the
    /// kernel reclaiming a torn-down view graph takes another 1–2 s). Queued,
    /// never awaited, so it cannot delay the caller.
    ///
    /// Nothing is promised, and the two ways the entry can go missing are both
    /// deliberate. A process that dies before the timer fires loses it — hence
    /// callers must treat this as a refinement of an already-recorded
    /// guaranteed entry, never as the record itself. A process that is merely
    /// *frozen* does not lose it: libdispatch has no drop-on-overdue policy,
    /// so the block runs as soon as the process is scheduled again — possibly
    /// minutes later and inside the next host cycle, since the extension
    /// process is reused. That sample would describe the resumed process while
    /// carrying the label of the earlier one, so a block that starts more than
    /// its own delay late writes nothing.
    ///
    /// One clock caveat bounds that guard rather than breaking it: the
    /// comparison reads `DispatchTime` — mach time, which pauses while the
    /// *device* sleeps — so a sample delayed across a sleep window can look
    /// punctual and slip through. The caller's cancellation covers the case
    /// that matters (a rebuilt keyboard voids the pending sample); what the
    /// clock caveat can cost is a single stale-but-plausible diagnostics
    /// entry, which the log's consumers tolerate by design.
    @discardableResult
    func recordDeferred(_ label: String, after delay: TimeInterval) -> DispatchWorkItem {
        let deadline = DispatchTime.now() + delay
        // Overdue by more than the wait itself: no process that kept running
        // is that far behind, so whatever the sample would read now belongs to
        // a different situation than the label names.
        let discardAfter = deadline + delay
        let item = DispatchWorkItem {
            guard DispatchTime.now() < discardAfter else { return }
            appendEntry(makeEntry(label))
        }
        Self.ioQueue.asyncAfter(deadline: deadline, execute: item)
        return item
    }

    /// Captures the footprint synchronously at the call site, so the
    /// measurement is attributed to the right lifecycle point no matter when
    /// the entry is persisted.
    private func makeEntry(_ label: String) -> Entry {
        let entry = Entry(
            id: UUID(),
            date: Date(),
            label: label,
            usedMB: Double(Self.physFootprintBytes()) / Self.bytesPerMB,
            availableMB: Double(os_proc_available_memory()) / Self.bytesPerMB
        )
        #if DEBUG
            let used = String(format: "%.1f", entry.usedMB)
            let available = String(format: "%.1f", entry.availableMB)
            let message = "[\(label)] used: \(used) MB, available: \(available) MB"
            Self.logger.log("\(message, privacy: .public)")
        #endif
        return entry
    }

    /// The tombstone `clear()` leaves behind: the clear's own timestamp, no
    /// footprint. Deliberately not `makeEntry`, which would sample the host
    /// app's memory here — a figure that belongs to no keyboard cycle and
    /// would still be compared against the extension's budget by every
    /// consumer of this log.
    private func makeClearedEntry() -> Entry {
        Entry(id: UUID(), date: Date(), label: Self.clearedLabel, usedMB: 0, availableMB: 0)
    }

    /// All recorded entries, oldest first, capped at `maxEntries`. Empty when
    /// the file is missing or unreadable (corruption is silently discarded —
    /// this is diagnostics, it must never take the keyboard down).
    ///
    /// The `suffix(maxEntries)` cap keeps the read bound even when the on-disk
    /// file has grown past `maxEntries` between physical compactions.
    func entries() -> [Entry] {
        Self.ioQueue.sync {
            guard let fileURL = fileURLProvider() else { return [] }
            return Array(readEntries(fileURL).suffix(maxEntries))
        }
    }

    /// Removes all recorded entries and stamps a tombstone in their place, so
    /// that an entry arriving afterwards reads as the first event *after* the
    /// clear instead of as a clear that did not take.
    ///
    /// The tombstone is not bookkeeping for its own sake. `clear()` is invoked
    /// from the **host app**, while the deferred `postShedSettled` sample is
    /// queued in the **extension process** two seconds before it writes (see
    /// `KeyboardViewController.shedMemoryBeforeSuspension`). Clearing the log
    /// shortly after a dismissal therefore reliably grows one entry in the
    /// file that was just emptied, and no cancellation can prevent it: the
    /// pending work item lives in another process, and the log has no channel
    /// to reach across. Marking where the clear happened is the honest fix;
    /// cancelling in-process would only look like one.
    ///
    /// The tombstone deliberately carries no memory figures. It is stamped by
    /// the host app, whose footprint says nothing about the extension's jetsam
    /// budget, and a host-sized number in that column would skew the peak.
    /// `KeyboardHealthView` folds it away while it is the only entry, so a
    /// cleared log still reads as empty.
    func clear() {
        Self.ioQueue.sync {
            guard let fileURL = fileURLProvider() else { return }
            try? FileManager.default.removeItem(at: fileURL)
            appendEntry(makeClearedEntry())
        }
    }

    // MARK: - Private

    /// Appends a single entry to the newline-delimited JSON (JSONL) file with
    /// a `seekToEnd` + `write` — O(1), no full-file read on the hot path.
    /// Must only run on `ioQueue`.
    private func appendEntry(_ entry: Entry) {
        guard let fileURL = fileURLProvider() else {
            Self.recordFailure("no container URL")
            return
        }
        guard let encoded = try? JSONEncoder().encode(entry) else {
            Self.recordFailure("encode failed")
            return
        }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            let end = (try? handle.seekToEnd()) ?? 0
            var payload = Data()
            // Separate the new line from a prior line or legacy array bytes.
            if end > 0 { payload.append(0x0A) }
            payload.append(encoded)
            do {
                try handle.write(contentsOf: payload)
            } catch {
                Self.recordFailure("append: \(error)")
            }
        } else if !FileManager.default.fileExists(atPath: fileURL.path) {
            // First write only. A handle can also fail on an *existing* file
            // (an unwritable container while the device is locked), and
            // overwriting then would discard exactly the history a
            // resume-jetsam investigation needs — drop the entry instead.
            do {
                try encoded.write(to: fileURL, options: .atomic)
            } catch {
                Self.recordFailure("create: \(error)")
            }
        } else {
            // The file exists but could not be opened for writing. Silent
            // before; counted now, because this is the branch that quietly
            // turned the log off for six weeks.
            Self.recordFailure("unwritable existing file")
        }
        compactIfNeeded(fileURL)
    }

    /// Why the log stopped writing, kept where a person can actually see it.
    ///
    /// Every write path above used to be a `try?`. The result was a diagnostic
    /// tool that failed silently and stayed failed: on 2026-08-30 the device
    /// carried no `keyboard-health-log.json` at all while `record` was
    /// demonstrably being called — six weeks of incidents with no telemetry,
    /// and no way to tell that apart from "nothing happened". A failure
    /// counter is the minimum a self-reporting instrument owes its reader.
    ///
    /// Deliberately in `SharedDefaults` rather than in the log file: the file
    /// is exactly what is unavailable when this matters.
    private static func recordFailure(_ reason: String) {
        let store = SharedDefaults.store
        store.set(store.integer(forKey: failureCountKey) + 1, forKey: failureCountKey)
        store.set(reason, forKey: lastFailureKey)
        #if DEBUG
            logger.error("health log write failed: \(reason, privacy: .public)")
        #endif
    }

    static let failureCountKey = "healthLog.writeFailureCount"
    static let lastFailureKey = "healthLog.lastWriteFailure"

    /// Number of writes that never reached disk, and why the last one failed,
    /// so an empty log is distinguishable from a broken one.
    static var writeFailures: (count: Int, lastReason: String?) {
        let store = SharedDefaults.store
        return (store.integer(forKey: failureCountKey), store.string(forKey: lastFailureKey))
    }

    /// Physically rewrites the file to the last `maxEntries` entries once it
    /// grows past `trimThresholdBytes`. Gated on a cheap `stat` (no content
    /// read), so a full read+rewrite happens only ~once per `maxEntries`
    /// appends — O(1) amortized per event. Must only run on `ioQueue`.
    private func compactIfNeeded(_ fileURL: URL) {
        let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.size] as? Int ?? 0
        // A file the process cannot read is history, not garbage: rewriting it
        // from an empty decode would replace the log with nothing.
        guard size > trimThresholdBytes, let data = try? Data(contentsOf: fileURL) else { return }
        write(Array(decodeEntries(from: data).suffix(maxEntries)), to: fileURL)
    }

    /// Raw JSONL read; must only run on `ioQueue`.
    private func readEntries(_ fileURL: URL) -> [Entry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return decodeEntries(from: data)
    }

    /// `split(separator:)` omits empty subsequences, so leading/double newlines
    /// and undecodable legacy segments are tolerated (corruption-discard
    /// contract preserved).
    private func decodeEntries(from data: Data) -> [Entry] {
        let decoder = JSONDecoder()
        return data.split(separator: 0x0A).compactMap { try? decoder.decode(Entry.self, from: Data($0)) }
    }

    /// Atomically rewrites the whole file as newline-delimited JSON. Only used
    /// by compaction — never on the append hot path.
    private func write(_ entries: [Entry], to fileURL: URL) {
        let encoder = JSONEncoder()
        var data = Data()
        for entry in entries {
            guard let line = try? encoder.encode(entry) else { continue }
            data.append(line)
            data.append(0x0A)
        }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static let bytesPerMB = 1024.0 * 1024.0

    /// The process's current physical memory footprint in bytes — the figure
    /// iOS compares against the jetsam limit. Returns 0 if the kernel query
    /// fails.
    private static func physFootprintBytes() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }
}
