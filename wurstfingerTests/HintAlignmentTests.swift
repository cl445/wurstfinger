//
//  HintAlignmentTests.swift
//  WurstfingerTests
//
//  Regression guards for the RTL fix (finding #4). The keyboard's render
//  tree is pinned to physical `.leftToRight`, so the directional hint tables
//  map each swipe direction to its PHYSICAL edge. These tests lock that
//  mapping so a mistaken "RTL fix" that mirrors the tables (swapping
//  leading/trailing) is caught in CI — mirroring would place a hint glyph on
//  the opposite edge from the swipe that produces it.
//
//  Note: the actual RTL flip is a rendering effect of SwiftUI's layout engine
//  under an RTL locale and is verified manually/UI (hints are not
//  accessibility-queryable). See the PR description.
//

import SwiftUI
import Testing
@testable import WurstfingerApp

@Suite(.serialized)
struct HintAlignmentTests {
    @Test func hintAlignmentsMapDirectionsToPhysicalEdges() {
        #expect(KeyView.hintAlignments[.swipeUp] == .top)
        #expect(KeyView.hintAlignments[.swipeDown] == .bottom)
        #expect(KeyView.hintAlignments[.swipeLeft] == .leading)
        #expect(KeyView.hintAlignments[.swipeRight] == .trailing)
        #expect(KeyView.hintAlignments[.swipeUpLeft] == .topLeading)
        #expect(KeyView.hintAlignments[.swipeUpRight] == .topTrailing)
        #expect(KeyView.hintAlignments[.swipeDownLeft] == .bottomLeading)
        #expect(KeyView.hintAlignments[.swipeDownRight] == .bottomTrailing)
    }

    @Test func hintEdgePaddingAppliesInsetOnlyOnTheAlignedPhysicalEdge() {
        let left = KeyView.hintEdgePadding(for: .swipeLeft, horizontal: 4, vertical: 3)
        #expect(left.leading == 4)
        #expect(left.trailing == 0)
        #expect(left.top == 0)
        #expect(left.bottom == 0)

        let right = KeyView.hintEdgePadding(for: .swipeRight, horizontal: 4, vertical: 3)
        #expect(right.trailing == 4)
        #expect(right.leading == 0)
        #expect(right.top == 0)
        #expect(right.bottom == 0)

        let up = KeyView.hintEdgePadding(for: .swipeUp, horizontal: 4, vertical: 3)
        #expect(up.top == 3)
        #expect(up.bottom == 0)
        #expect(up.leading == 0)
        #expect(up.trailing == 0)

        let down = KeyView.hintEdgePadding(for: .swipeDown, horizontal: 4, vertical: 3)
        #expect(down.bottom == 3)
        #expect(down.top == 0)

        let upLeft = KeyView.hintEdgePadding(for: .swipeUpLeft, horizontal: 4, vertical: 3)
        #expect(upLeft.top == 3)
        #expect(upLeft.leading == 4)
        #expect(upLeft.bottom == 0)
        #expect(upLeft.trailing == 0)

        let downRight = KeyView.hintEdgePadding(for: .swipeDownRight, horizontal: 4, vertical: 3)
        #expect(downRight.bottom == 3)
        #expect(downRight.trailing == 4)
        #expect(downRight.top == 0)
        #expect(downRight.leading == 0)
    }
}
