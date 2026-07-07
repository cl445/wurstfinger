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
/// path. A host-app clear racing an extension write can lose one side —
/// acceptable for diagnostics, and the file stays bounded by `maxEntries`
/// either way.
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

    /// Bounds the log file (~50 KB): a cold start records three entries, a
    /// warm re-appearance one, so this covers days of typical usage.
    static let defaultMaxEntries = 300

    static let fileName = "keyboard-health-log.json"

    /// Shared instance persisting into the app group container.
    static let shared = KeyboardHealthLog(
        fileURL: FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.suiteName)?
            .appendingPathComponent(fileName)
    )

    private let fileURL: URL?
    private let maxEntries: Int

    /// Serializes all file access across instances. `record` hops onto it
    /// asynchronously; `entries()`/`clear()` sync through it, so reads always
    /// observe every previously recorded entry.
    private static let ioQueue = DispatchQueue(
        label: "de.akator.wurstfinger.keyboard-health-log",
        qos: .utility
    )

    #if DEBUG
        private static let logger = Logger(subsystem: "de.akator.wurstfinger", category: "memory")
    #endif

    init(fileURL: URL?, maxEntries: Int = KeyboardHealthLog.defaultMaxEntries) {
        self.fileURL = fileURL
        self.maxEntries = maxEntries
    }

    /// Records the current footprint under the given lifecycle label.
    func record(_ label: String) {
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
        Self.ioQueue.async {
            var all = readEntries()
            all.append(entry)
            if all.count > maxEntries {
                all.removeFirst(all.count - maxEntries)
            }
            write(all)
        }
    }

    /// All recorded entries, oldest first. Empty when the file is missing or
    /// unreadable (corruption is silently discarded — this is diagnostics,
    /// it must never take the keyboard down).
    func entries() -> [Entry] {
        Self.ioQueue.sync { readEntries() }
    }

    /// Removes all recorded entries.
    func clear() {
        guard let fileURL else { return }
        Self.ioQueue.sync {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Private

    /// Raw read; must only run on `ioQueue`.
    private func readEntries() -> [Entry] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private func write(_ entries: [Entry]) {
        guard let fileURL, let data = try? JSONEncoder().encode(entries) else { return }
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
