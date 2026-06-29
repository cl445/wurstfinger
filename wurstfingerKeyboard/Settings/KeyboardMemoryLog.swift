//
//  KeyboardMemoryLog.swift
//  Wurstfinger
//
//  Debug-only memory diagnostics for the keyboard extension.
//

import Foundation
import os

/// Lightweight, debug-only memory logging for the keyboard extension.
///
/// Keyboard extensions run under a tight (~48–66 MB) memory budget. Exceeding it
/// makes iOS terminate (jetsam) the extension, which users experience as the
/// system keyboard appearing instead of Wurstfinger — intermittently, in
/// memory-hungry host apps. This records the memory still available before
/// termination at key lifecycle points so regressions are observable on-device
/// via Console.app, while compiling to nothing in release builds.
enum KeyboardMemoryLog {
    #if DEBUG
        private static let logger = Logger(subsystem: "de.akator.wurstfinger", category: "memory")

        private static let bytesPerMB = 1024.0 * 1024.0

        /// The extension's current physical memory footprint in bytes — the
        /// figure iOS compares against the jetsam limit. Returns 0 if the
        /// kernel query fails.
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
    #endif

    /// Logs the extension's current footprint and the memory still available
    /// before iOS would jetsam it. No-op in release builds.
    static func record(_ label: String) {
        #if DEBUG
            let usedMB = Double(physFootprintBytes()) / bytesPerMB
            let availableMB = Double(os_proc_available_memory()) / bytesPerMB
            let used = String(format: "%.1f", usedMB)
            let available = String(format: "%.1f", availableMB)
            let message = "[\(label)] used: \(used) MB, available: \(available) MB"
            logger.log("\(message, privacy: .public)")
        #endif
    }
}
