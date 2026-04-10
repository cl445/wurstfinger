//
//  GestureResolverTests.swift
//  WurstfingerTests
//
//  Tests for PR 10: PrimaryResolver, ReturnSwipeResolver, GhostKeyResolver,
//  and GestureResolverChain composition.
//

import Foundation
import Testing
@testable import WurstfingerApp

// MARK: - Helpers

private enum Fixtures {
    /// Builds a key with the given bindings; defaults swipeMode to .eightWay.
    static func key(
        id: String,
        bindings: [GestureType: KeyBinding],
        swipeMode: SwipeMode = .eightWay,
        style: KeyStyle = .primary
    ) -> KeyConfig {
        KeyConfig(
            id: id,
            bindings: bindings,
            swipeMode: swipeMode,
            slideType: .none,
            style: style,
            tapCycleActions: nil
        )
    }

    /// Builds a single-mode KeyboardMode from a list of keys.
    static func mode(name: String = "main", keys: [KeyConfig]) -> KeyboardMode {
        KeyboardMode(
            name: name,
            keys: Dictionary(uniqueKeysWithValues: keys.map { ($0.id, $0) }),
            arrangements: [.portrait: GridArrangement(columns: 1, rows: [[KeyPlacement(keyId: keys.first?.id ?? "x")]])],
            autoTransitions: [:],
            doubleTapMode: nil
        )
    }

    static func binding(
        label: String = "x",
        action: KeyAction,
        returnAction: KeyAction? = nil
    ) -> KeyBinding {
        KeyBinding(
            label: label,
            action: action,
            category: nil,
            returnAction: returnAction,
            accessibilityLabel: nil
        )
    }
}

// MARK: - PrimaryResolver

struct PrimaryResolverTests {
    @Test func returnsBindingForDeclaredGesture() {
        let mode = Fixtures.mode(keys: [
            Fixtures.key(id: "a", bindings: [
                .tap: Fixtures.binding(label: "a", action: .commitText("a")),
                .swipeUp: Fixtures.binding(label: "1", action: .commitText("1")),
            ]),
        ])
        let resolver = PrimaryResolver()
        #expect(resolver.resolve(keyId: "a", gesture: .tap, in: mode)?.action == .commitText("a"))
        #expect(resolver.resolve(keyId: "a", gesture: .swipeUp, in: mode)?.action == .commitText("1"))
    }

    @Test func returnsNilForUndeclaredGesture() {
        let mode = Fixtures.mode(keys: [
            Fixtures.key(id: "a", bindings: [.tap: Fixtures.binding(action: .commitText("a"))]),
        ])
        #expect(PrimaryResolver().resolve(keyId: "a", gesture: .swipeDown, in: mode) == nil)
    }

    @Test func returnsNilForMissingKey() {
        let mode = Fixtures.mode(keys: [
            Fixtures.key(id: "a", bindings: [.tap: Fixtures.binding(action: .commitText("a"))]),
        ])
        #expect(PrimaryResolver().resolve(keyId: "missing", gesture: .tap, in: mode) == nil)
    }

    @Test func swipeModeBlocksDisallowedSwipe() {
        // twoWayHorizontal allows only swipeLeft / swipeRight.
        let mode = Fixtures.mode(keys: [
            Fixtures.key(
                id: "delete",
                bindings: [
                    .tap: Fixtures.binding(action: .deleteBackward),
                    .swipeUp: Fixtures.binding(action: .commitText("blocked")),
                    .swipeLeft: Fixtures.binding(action: .commitText("ok")),
                ],
                swipeMode: .twoWayHorizontal
            ),
        ])
        let resolver = PrimaryResolver()
        #expect(resolver.resolve(keyId: "delete", gesture: .swipeUp, in: mode) == nil)
        #expect(resolver.resolve(keyId: "delete", gesture: .swipeLeft, in: mode)?.action == .commitText("ok"))
    }

    @Test func swipeModeDoesNotBlockNonSwipeGestures() {
        // .none disallows every swipe but must still pass through .tap.
        let mode = Fixtures.mode(keys: [
            Fixtures.key(
                id: "globe",
                bindings: [.tap: Fixtures.binding(action: .advanceToNextInputMode)],
                swipeMode: .none
            ),
        ])
        #expect(PrimaryResolver().resolve(keyId: "globe", gesture: .tap, in: mode)?.action == .advanceToNextInputMode)
    }

    @Test func eightWayAllowsDiagonals() {
        let mode = Fixtures.mode(keys: [
            Fixtures.key(
                id: "a",
                bindings: [.swipeUpLeft: Fixtures.binding(action: .commitText("ul"))],
                swipeMode: .eightWay
            ),
        ])
        #expect(PrimaryResolver().resolve(keyId: "a", gesture: .swipeUpLeft, in: mode)?.action == .commitText("ul"))
    }

    @Test func fourWayCrossBlocksDiagonals() {
        let mode = Fixtures.mode(keys: [
            Fixtures.key(
                id: "a",
                bindings: [.swipeUpLeft: Fixtures.binding(action: .commitText("ul"))],
                swipeMode: .fourWayCross
            ),
        ])
        #expect(PrimaryResolver().resolve(keyId: "a", gesture: .swipeUpLeft, in: mode) == nil)
    }
}

// MARK: - ReturnSwipeResolver

struct ReturnSwipeResolverTests {
    @Test func returnsReturnActionWhenPresent() {
        let mode = Fixtures.mode(keys: [
            Fixtures.key(id: "a", bindings: [
                .swipeUp: Fixtures.binding(
                    label: "1",
                    action: .commitText("1"),
                    returnAction: .commitText("!")
                ),
            ]),
        ])
        let resolved = ReturnSwipeResolver().resolve(keyId: "a", gesture: .swipeUp, in: mode)
        #expect(resolved?.action == .commitText("!"))
        // The synthetic binding must clear returnAction so it can't loop.
        #expect(resolved?.returnAction == nil)
    }

    @Test func returnsNilWhenNoReturnAction() {
        let mode = Fixtures.mode(keys: [
            Fixtures.key(id: "a", bindings: [
                .swipeUp: Fixtures.binding(action: .commitText("1")),
            ]),
        ])
        #expect(ReturnSwipeResolver().resolve(keyId: "a", gesture: .swipeUp, in: mode) == nil)
    }

    @Test func returnsNilForNonSwipeGesture() {
        let mode = Fixtures.mode(keys: [
            Fixtures.key(id: "a", bindings: [
                .tap: Fixtures.binding(
                    action: .commitText("a"),
                    returnAction: .commitText("A")
                ),
            ]),
        ])
        // Return swipes only apply to actual swipe gestures.
        #expect(ReturnSwipeResolver().resolve(keyId: "a", gesture: .tap, in: mode) == nil)
    }

    @Test func returnsNilWhenSwipeBlockedByMode() {
        let mode = Fixtures.mode(keys: [
            Fixtures.key(
                id: "a",
                bindings: [
                    .swipeUp: Fixtures.binding(
                        action: .commitText("1"),
                        returnAction: .commitText("!")
                    ),
                ],
                swipeMode: .twoWayHorizontal
            ),
        ])
        #expect(ReturnSwipeResolver().resolve(keyId: "a", gesture: .swipeUp, in: mode) == nil)
    }

    @Test func returnsNilForMissingKey() {
        let mode = Fixtures.mode(keys: [
            Fixtures.key(id: "a", bindings: [:]),
        ])
        #expect(ReturnSwipeResolver().resolve(keyId: "missing", gesture: .swipeUp, in: mode) == nil)
    }
}

// MARK: - GhostKeyResolver

struct GhostKeyResolverTests {
    @Test func resolvesFromFallbackWhenPrimaryMisses() {
        let primary = Fixtures.mode(name: "main", keys: [
            Fixtures.key(id: "a", bindings: [.tap: Fixtures.binding(action: .commitText("a"))]),
        ])
        let fallback = Fixtures.mode(name: "numeric", keys: [
            Fixtures.key(id: "a", bindings: [.swipeUp: Fixtures.binding(action: .commitText("1"))]),
        ])
        let resolver = GhostKeyResolver(fallbackMode: fallback)
        // Primary has tap but no swipeUp → fall back to numeric.
        #expect(resolver.resolve(keyId: "a", gesture: .swipeUp, in: primary)?.action == .commitText("1"))
    }

    @Test func returnsNilWhenPrimaryAlreadyHasBinding() {
        let primary = Fixtures.mode(name: "main", keys: [
            Fixtures.key(id: "a", bindings: [.swipeUp: Fixtures.binding(action: .commitText("primary"))]),
        ])
        let fallback = Fixtures.mode(name: "numeric", keys: [
            Fixtures.key(id: "a", bindings: [.swipeUp: Fixtures.binding(action: .commitText("ghost"))]),
        ])
        // Primary owns the gesture → ghost stays out of the way.
        #expect(GhostKeyResolver(fallbackMode: fallback).resolve(keyId: "a", gesture: .swipeUp, in: primary) == nil)
    }

    @Test func returnsNilWhenFallbackHasNoKey() {
        let primary = Fixtures.mode(name: "main", keys: [
            Fixtures.key(id: "a", bindings: [:]),
        ])
        let fallback = Fixtures.mode(name: "numeric", keys: [
            Fixtures.key(id: "b", bindings: [.tap: Fixtures.binding(action: .commitText("b"))]),
        ])
        #expect(GhostKeyResolver(fallbackMode: fallback).resolve(keyId: "a", gesture: .tap, in: primary) == nil)
    }

    @Test func respectsFallbackSwipeMode() {
        let primary = Fixtures.mode(name: "main", keys: [
            Fixtures.key(id: "a", bindings: [:]),
        ])
        let fallback = Fixtures.mode(name: "numeric", keys: [
            Fixtures.key(
                id: "a",
                bindings: [.swipeUpLeft: Fixtures.binding(action: .commitText("ul"))],
                swipeMode: .fourWayCross
            ),
        ])
        // fourWayCross blocks diagonals even in the fallback mode.
        #expect(GhostKeyResolver(fallbackMode: fallback).resolve(keyId: "a", gesture: .swipeUpLeft, in: primary) == nil)
    }
}

// MARK: - GestureResolverChain

struct GestureResolverChainTests {
    @Test func chainPriorityFirstHitWins() {
        let mode = Fixtures.mode(keys: [
            Fixtures.key(id: "a", bindings: [
                .swipeUp: Fixtures.binding(
                    action: .commitText("primary"),
                    returnAction: .commitText("return")
                ),
            ]),
        ])
        // ReturnSwipeResolver runs first → its result wins over PrimaryResolver.
        let chain = GestureResolverChain(resolvers: [ReturnSwipeResolver(), PrimaryResolver()])
        #expect(chain.resolveAction(keyId: "a", gesture: .swipeUp, in: mode) == .commitText("return"))
    }

    @Test func chainFallsThroughToPrimary() {
        let mode = Fixtures.mode(keys: [
            // No returnAction → ReturnSwipeResolver returns nil → PrimaryResolver wins.
            Fixtures.key(id: "a", bindings: [
                .swipeUp: Fixtures.binding(action: .commitText("primary")),
            ]),
        ])
        let chain = GestureResolverChain(resolvers: [ReturnSwipeResolver(), PrimaryResolver()])
        #expect(chain.resolveAction(keyId: "a", gesture: .swipeUp, in: mode) == .commitText("primary"))
    }

    @Test func chainReturnsNoneWhenAllResolversMiss() {
        let mode = Fixtures.mode(keys: [
            Fixtures.key(id: "a", bindings: [:]),
        ])
        let chain = GestureResolverChain(resolvers: [PrimaryResolver(), ReturnSwipeResolver()])
        #expect(chain.resolveAction(keyId: "a", gesture: .swipeUp, in: mode) == .none)
    }

    @Test func chainWithGhostKeysFallsBackToOtherMode() {
        let primary = Fixtures.mode(name: "main", keys: [
            Fixtures.key(id: "a", bindings: [.tap: Fixtures.binding(action: .commitText("a"))]),
        ])
        let numeric = Fixtures.mode(name: "numeric", keys: [
            Fixtures.key(id: "a", bindings: [.swipeUp: Fixtures.binding(action: .commitText("1"))]),
        ])
        let chain = GestureResolverChain(resolvers: [
            PrimaryResolver(),
            GhostKeyResolver(fallbackMode: numeric),
        ])
        #expect(chain.resolveAction(keyId: "a", gesture: .swipeUp, in: primary) == .commitText("1"))
        // Primary still owns its own gestures.
        #expect(chain.resolveAction(keyId: "a", gesture: .tap, in: primary) == .commitText("a"))
    }

    @Test func chainResolveReturnsBindingNotJustAction() {
        // The non-action variant exposes the full binding so PR 11 middleware
        // can read category / accessibility metadata.
        let mode = Fixtures.mode(keys: [
            Fixtures.key(id: "a", bindings: [
                .tap: KeyBinding(
                    label: "a",
                    action: .commitText("a"),
                    category: .letter,
                    returnAction: nil,
                    accessibilityLabel: nil
                ),
            ]),
        ])
        let chain = GestureResolverChain(resolvers: [PrimaryResolver()])
        let resolved = chain.resolve(keyId: "a", gesture: .tap, in: mode)
        #expect(resolved?.label == "a")
        #expect(resolved?.resolvedCategory == .letter)
    }
}
