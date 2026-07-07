//
//  GridTypeTests.swift
//  WurstfingerTests
//
//  Tests for KeyPlacement, GridArrangement, and ArrangementContext.
//

import Foundation
import Testing
@testable import WurstfingerApp

// MARK: - KeyPlacement Tests

struct KeyPlacementTests {
    @Test func defaultMultipliers() {
        let placement = KeyPlacement(keyId: "topLeft")
        #expect(placement.widthMultiplier == 1)
        #expect(placement.heightMultiplier == 1)
    }

    @Test func customMultipliers() {
        let placement = KeyPlacement(keyId: "space", widthMultiplier: 3, heightMultiplier: 1)
        #expect(placement.widthMultiplier == 3)
        #expect(placement.heightMultiplier == 1)
    }

    @Test func heightMultiplier() {
        let placement = KeyPlacement(keyId: "return", widthMultiplier: 1, heightMultiplier: 2)
        #expect(placement.heightMultiplier == 2)
    }

    @Test func codableRoundtrip() throws {
        let placement = KeyPlacement(keyId: "center", widthMultiplier: 2, heightMultiplier: 3)
        let data = try JSONEncoder().encode(placement)
        let decoded = try JSONDecoder().decode(KeyPlacement.self, from: data)
        #expect(decoded == placement)
    }

    @Test func equatable() {
        let a = KeyPlacement(keyId: "topLeft")
        let b = KeyPlacement(keyId: "topLeft")
        let c = KeyPlacement(keyId: "topRight")
        #expect(a == b)
        #expect(a != c)
    }

    @Test func decodingRejectsZeroWidthMultiplier() {
        let json = #"{"keyId":"a","widthMultiplier":0,"heightMultiplier":1}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(KeyPlacement.self, from: Data(json.utf8))
        }
    }

    @Test func decodingRejectsNegativeHeightMultiplier() {
        let json = #"{"keyId":"a","widthMultiplier":1,"heightMultiplier":-1}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(KeyPlacement.self, from: Data(json.utf8))
        }
    }
}

// MARK: - GridArrangement Tests

struct GridArrangementTests {
    // A standard 4-column portrait arrangement for testing
    static let portrait = GridArrangement(
        columns: 4,
        rows: [
            [.init(keyId: "topLeft"), .init(keyId: "topCenter"), .init(keyId: "topRight"), .init(keyId: "globe")],
            [.init(keyId: "midLeft"), .init(keyId: "center"), .init(keyId: "midRight"), .init(keyId: "symbols")],
            [.init(keyId: "bottomLeft"), .init(keyId: "bottomCenter"), .init(keyId: "bottomRight"), .init(keyId: "delete")],
            [.init(keyId: "space", widthMultiplier: 3), .init(keyId: "return")],
        ]
    )

    static let utilityKeys: Set<String> = ["globe", "symbols", "delete", "return"]

    @Test func movingToLeadingMovesOnlyUtilityKeys() {
        let moved = Self.portrait.movingToLeading(keyIds: Self.utilityKeys)

        #expect(moved.columns == 4)
        #expect(moved.rows.count == 4)

        // Utility key leads each row; letters keep their original order.
        #expect(moved.rows[0].map(\.keyId) == ["globe", "topLeft", "topCenter", "topRight"])
        #expect(moved.rows[1].map(\.keyId) == ["symbols", "midLeft", "center", "midRight"])
        #expect(moved.rows[2].map(\.keyId) == ["delete", "bottomLeft", "bottomCenter", "bottomRight"])
        #expect(moved.rows[3].map(\.keyId) == ["return", "space"])
    }

    @Test func movingToLeadingPreservesMultipliers() throws {
        let moved = Self.portrait.movingToLeading(keyIds: Self.utilityKeys)
        // Space should keep its widthMultiplier
        let spacePlacement = try #require(moved.rows[3].first { $0.keyId == "space" })
        #expect(spacePlacement.widthMultiplier == 3)
    }

    @Test func movingToLeadingIsIdempotent() {
        let once = Self.portrait.movingToLeading(keyIds: Self.utilityKeys)
        let twice = once.movingToLeading(keyIds: Self.utilityKeys)
        #expect(twice == once)
    }

    @Test func movingToLeadingWithNoMatchesIsIdentity() {
        let moved = Self.portrait.movingToLeading(keyIds: ["nonexistent"])
        #expect(moved == Self.portrait)
    }

    @Test func resizedAdjustsTargetKey() throws {
        // Resize space from width 3 to width 4, total columns 4 → 5
        let resized = Self.portrait.resized(columns: 5, adjusting: "space", toWidth: 4)

        #expect(resized.columns == 5)
        let spacePlacement = try #require(resized.rows[3].first { $0.keyId == "space" })
        #expect(spacePlacement.widthMultiplier == 4)
    }

    @Test func resizedLeavesOtherKeysUntouched() throws {
        let resized = Self.portrait.resized(columns: 5, adjusting: "space", toWidth: 4)

        // topLeft should still have width 1
        let topLeft = try #require(resized.rows[0].first { $0.keyId == "topLeft" })
        #expect(topLeft.widthMultiplier == 1)
    }

    @Test func resizedPreservesHeightMultiplier() throws {
        let withHeight = GridArrangement(
            columns: 4,
            rows: [
                [.init(keyId: "a"), .init(keyId: "b", widthMultiplier: 2, heightMultiplier: 2), .init(keyId: "c")],
            ]
        )
        let resized = withHeight.resized(columns: 5, adjusting: "b", toWidth: 3)
        let b = try #require(resized.rows[0].first { $0.keyId == "b" })
        #expect(b.widthMultiplier == 3)
        #expect(b.heightMultiplier == 2)
    }

    @Test func removingDeletesFromAllRows() {
        let removed = Self.portrait.removing(keyId: "globe")

        // Globe was in row 0 — should be gone
        let row0Ids = removed.rows[0].map(\.keyId)
        #expect(!row0Ids.contains("globe"))
        #expect(row0Ids == ["topLeft", "topCenter", "topRight"])

        // Other rows should be untouched
        #expect(removed.rows[1].count == 4)
        #expect(removed.rows[3].count == 2)
    }

    @Test func removingKeyNotPresentIsNoOp() {
        let removed = Self.portrait.removing(keyId: "nonexistent")
        #expect(removed == Self.portrait)
    }

    @Test func removingPreservesColumns() {
        let removed = Self.portrait.removing(keyId: "globe")
        #expect(removed.columns == 4)
    }

    @Test func codableRoundtrip() throws {
        let data = try JSONEncoder().encode(Self.portrait)
        let decoded = try JSONDecoder().decode(GridArrangement.self, from: data)
        #expect(decoded == Self.portrait)
    }

    @Test func emptyGrid() {
        let empty = GridArrangement(columns: 0, rows: [])
        #expect(empty.rows.isEmpty)
        #expect(empty.columns == 0)
    }

    @Test func singleCellGrid() {
        let single = GridArrangement(
            columns: 1,
            rows: [[KeyPlacement(keyId: "only")]]
        )
        #expect(single.rows.count == 1)
        #expect(single.rows[0].count == 1)
        #expect(single.rows[0][0].keyId == "only")
    }
}

// MARK: - ArrangementContext Tests

struct ArrangementContextTests {
    @Test func caseIterable() {
        #expect(ArrangementContext.allCases.count == 4)
    }

    @Test func codableRoundtrip() throws {
        for context in ArrangementContext.allCases {
            let data = try JSONEncoder().encode(context)
            let decoded = try JSONDecoder().decode(ArrangementContext.self, from: data)
            #expect(decoded == context)
        }
    }

    @Test func rawValues() {
        #expect(ArrangementContext.portrait.rawValue == "portrait")
        #expect(ArrangementContext.portraitUtilityLeft.rawValue == "portraitUtilityLeft")
        #expect(ArrangementContext.landscape.rawValue == "landscape")
        #expect(ArrangementContext.landscapeUtilityLeft.rawValue == "landscapeUtilityLeft")
    }
}
