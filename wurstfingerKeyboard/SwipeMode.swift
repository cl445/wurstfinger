//
//  SwipeMode.swift
//  Wurstfinger
//
//  Allowed swipe directions per key.
//

import Foundation

/// Restriction of allowed swipe directions per key.
enum SwipeMode: String, Codable {
    case eightWay // All 8 directions (default for letter keys)
    case fourWayCross // Cross only (↑↓←→)
    case fourWayDiagonal // Diagonals only
    case twoWayHorizontal // Only ←→ (e.g. delete key)
    case twoWayVertical // Only ↑↓
    case none // No swipes (e.g. globe key)

    /// Checks whether a given gesture is allowed in this mode.
    func allows(_ gesture: GestureType) -> Bool {
        switch self {
        case .eightWay:
            gesture.isSwipe
        case .fourWayCross:
            [.swipeUp, .swipeDown, .swipeLeft, .swipeRight].contains(gesture)
        case .fourWayDiagonal:
            [.swipeUpLeft, .swipeUpRight, .swipeDownLeft, .swipeDownRight].contains(gesture)
        case .twoWayHorizontal:
            [.swipeLeft, .swipeRight].contains(gesture)
        case .twoWayVertical:
            [.swipeUp, .swipeDown].contains(gesture)
        case .none:
            false
        }
    }
}
