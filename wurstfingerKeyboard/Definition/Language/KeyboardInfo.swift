//
//  KeyboardInfo.swift
//  Wurstfinger
//
//  Lightweight keyboard metadata for UI and selection.
//

import Foundation

/// Lightweight metadata for a keyboard layout.
/// Used by the language selection UI without loading the full definition.
struct KeyboardInfo: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let localeIdentifier: String

    init(id: String, title: String, localeIdentifier: String) {
        self.id = id
        self.title = title
        self.localeIdentifier = localeIdentifier
    }

    init(from definition: KeyboardDefinition) {
        id = definition.id
        title = definition.title
        localeIdentifier = definition.localeIdentifier
    }
}
