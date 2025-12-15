//
//  SharedDefaults.swift
//  Wurstfinger
//
//  Shared UserDefaults utility for app group communication
//

import Foundation

/// Provides centralized access to shared UserDefaults for communication
/// between the main app and keyboard extension
enum SharedDefaults {
    /// The app group identifier shared between the main app and keyboard extension
    static let suiteName = "group.de.akator.wurstfinger.shared"

    /// The shared UserDefaults instance
    /// Falls back to standard UserDefaults if app group is not available (should never happen in production)
    static var store: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    /// Key for gesture debug log
    static let gestureLogKey = "gestureDebugLog"

    /// Key for gesture path visualization
    static let gesturePathKey = "gestureDebugPath"

    /// Maximum number of log entries to keep
    static let maxLogEntries = 50
}

/// Debug logging for gesture recognition (uses file in shared container for reliability)
enum GestureDebugLog {
    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.suiteName)
    }

    private static var logFileURL: URL? {
        containerURL?.appendingPathComponent("gesture_log.txt")
    }

    private static var pathFileURL: URL? {
        containerURL?.appendingPathComponent("gesture_path.json")
    }

    /// Appends a log entry to the shared gesture log
    static func log(_ message: String) {
        guard let url = logFileURL else { return }

        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))
        let entry = "[\(timestamp)] \(message)\n"

        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                if let data = entry.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            }
        } else {
            try? entry.write(to: url, atomically: true, encoding: .utf8)
        }

        // Trim if too large (keep last 50 lines)
        trimLogIfNeeded()
    }

    private static func trimLogIfNeeded() {
        guard let url = logFileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        let lines = content.components(separatedBy: "\n")
        if lines.count > SharedDefaults.maxLogEntries {
            let trimmed = lines.suffix(SharedDefaults.maxLogEntries).joined(separator: "\n")
            try? trimmed.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Saves the gesture path for visualization
    static func savePath(_ positions: [CGPoint]) {
        guard let url = pathFileURL else { return }

        let encoded = positions.map { ["x": $0.x, "y": $0.y] }
        if let data = try? JSONSerialization.data(withJSONObject: encoded) {
            try? data.write(to: url)
        }
    }

    /// Gets the saved gesture path
    static func getPath() -> [CGPoint] {
        guard let url = pathFileURL,
              let data = try? Data(contentsOf: url),
              let encoded = try? JSONSerialization.jsonObject(with: data) as? [[String: CGFloat]] else {
            return []
        }
        return encoded.compactMap { dict in
            guard let x = dict["x"], let y = dict["y"] else { return nil }
            return CGPoint(x: x, y: y)
        }
    }

    /// Clears the gesture log
    static func clear() {
        if let logURL = logFileURL {
            try? FileManager.default.removeItem(at: logURL)
        }
        if let pathURL = pathFileURL {
            try? FileManager.default.removeItem(at: pathURL)
        }
    }

    /// Gets all log entries
    static func getAll() -> [String] {
        guard let url = logFileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return content.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
}
