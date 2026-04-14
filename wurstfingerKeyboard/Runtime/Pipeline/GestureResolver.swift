//
//  GestureResolver.swift
//  Wurstfinger
//
//  Resolves a gesture on a key into the binding that should fire.
//

import Foundation

/// Resolves a gesture on a key into the `KeyBinding` that should fire.
///
/// Resolvers are composed into a `GestureResolverChain`. Each resolver in
/// the chain is asked in order; the first one to return a non-nil binding
/// wins. Returning `nil` means "I don't know" — the chain falls through to
/// the next resolver.
///
/// Concrete resolvers live in their own files (PrimaryResolver,
/// ReturnSwipeResolver, GhostKeyResolver) and are intentionally tiny so the
/// resolution policy is composable rather than hardcoded.
protocol GestureResolver {
    /// Tries to resolve `gesture` on the key with `keyId` in `mode`.
    /// Returns the binding to fire, or `nil` to delegate to the next resolver.
    func resolve(keyId: String, gesture: GestureType, in mode: KeyboardMode) -> KeyBinding?
}
