//
//  ScriptPunctuation.swift
//  Wurstfinger
//
//  Punctuation shared by every layout of one writing system.
//

import Foundation

/// Punctuation a whole writing system shares. One table per script, shared by
/// every layout of that script, so those layouts cannot drift apart.
enum ScriptPunctuation {
    /// Arabic-script punctuation (؟ ، ؛ ٭) at its MessagEase reference
    /// positions, merged into a layout's own directional overrides — the
    /// layout wins for the same slot and gesture, so a language can still
    /// deviate. Used by the Arabic, Persian, and Urdu layouts.
    ///
    /// The Latin `? , ; *` render with the wrong directionality and spacing
    /// inside right-to-left text. They stay one return swipe away (see
    /// `arabicScriptReturns`) and keep their positions on the numeric layer.
    static func arabicScript(
        adding own: [String: [GestureType: String]]
    ) -> [String: [GestureType: String]] {
        merging(arabicPunctuation, into: own)
    }

    /// The Latin marks `arabicScript` displaces, on the same gestures' return
    /// swipes. `؛ → ;` is the reference's own pairing; the other three follow it.
    static func arabicScriptReturns(
        adding own: [String: [GestureType: String]]
    ) -> [String: [GestureType: String]] {
        merging(arabicPunctuationReturns, into: own)
    }

    private static let arabicPunctuation: [String: [GestureType: String]] = [
        GridSlot.topRight: [.swipeLeft: "؟"],
        GridSlot.bottomLeft: [.swipeRight: "٭"],
        GridSlot.bottomCenter: [.swipeDownLeft: "،"],
        GridSlot.bottomRight: [.swipeDownLeft: "؛"],
    ]

    private static let arabicPunctuationReturns: [String: [GestureType: String]] = [
        GridSlot.topRight: [.swipeLeft: "?"],
        GridSlot.bottomLeft: [.swipeRight: "*"],
        GridSlot.bottomCenter: [.swipeDownLeft: ","],
        GridSlot.bottomRight: [.swipeDownLeft: ";"],
    ]

    private static func merging(
        _ shared: [String: [GestureType: String]],
        into own: [String: [GestureType: String]]
    ) -> [String: [GestureType: String]] {
        shared.merging(own) { sharedSlot, ownSlot in
            sharedSlot.merging(ownSlot) { _, ownText in ownText }
        }
    }
}
