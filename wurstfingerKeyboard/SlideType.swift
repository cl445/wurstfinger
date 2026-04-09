//
//  SlideType.swift
//  Wurstfinger
//
//  Special drag behavior for held keys.
//

import Foundation

/// Special behavior when dragging over a key.
enum SlideType: String, Codable {
    case none // No slide behavior (default)
    case moveCursor // Move cursor (space key)
    case delete // Progressive deletion (delete key)
}
