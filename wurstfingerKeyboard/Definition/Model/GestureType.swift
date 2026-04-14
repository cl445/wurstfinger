//
//  GestureType.swift
//  Wurstfinger
//
//  All gestures that can be recognized on a key.
//

import Foundation

/// All gestures that can be recognized on a key.
enum GestureType: String, Codable, CaseIterable {
    // Tap
    case tap

    // 8 directions
    case swipeUp, swipeDown, swipeLeft, swipeRight
    case swipeUpLeft, swipeUpRight, swipeDownLeft, swipeDownRight

    // Circular gestures
    case circularClockwise, circularCounterclockwise

    // Long press
    case longPress

    /// Whether this gesture is a directional swipe.
    var isSwipe: Bool {
        switch self {
        case .swipeUp, .swipeDown, .swipeLeft, .swipeRight,
             .swipeUpLeft, .swipeUpRight, .swipeDownLeft, .swipeDownRight:
            true
        default:
            false
        }
    }
}
