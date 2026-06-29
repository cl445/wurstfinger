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
    #endif

    /// Logs the memory currently available to the extension before iOS would
    /// jetsam it. No-op in release builds.
    static func record(_ label: String) {
        #if DEBUG
            let availableMB = Double(os_proc_available_memory()) / (1024 * 1024)
            logger.log("[\(label, privacy: .public)] available: \(availableMB, format: .fixed(precision: 1)) MB")
        #endif
    }
}
