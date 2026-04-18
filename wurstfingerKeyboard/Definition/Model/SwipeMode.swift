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

    private static let fourWayCrossGestures: Set<GestureType> = [.swipeUp, .swipeDown, .swipeLeft, .swipeRight]
    private static let fourWayDiagonalGestures: Set<GestureType> = [.swipeUpLeft, .swipeUpRight, .swipeDownLeft, .swipeDownRight]
    private static let twoWayHorizontalGestures: Set<GestureType> = [.swipeLeft, .swipeRight]
    private static let twoWayVerticalGestures: Set<GestureType> = [.swipeUp, .swipeDown]

    /// Checks whether a given gesture is allowed in this mode.
    func allows(_ gesture: GestureType) -> Bool {
        switch self {
        case .eightWay:
            gesture.isSwipe
        case .fourWayCross:
            Self.fourWayCrossGestures.contains(gesture)
        case .fourWayDiagonal:
            Self.fourWayDiagonalGestures.contains(gesture)
        case .twoWayHorizontal:
            Self.twoWayHorizontalGestures.contains(gesture)
        case .twoWayVertical:
            Self.twoWayVerticalGestures.contains(gesture)
        case .none:
            false
        }
    }
}
