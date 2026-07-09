//
//  KeyboardRegistryTests.swift
//  WurstfingerTests
//
//  Tests for KeyboardInfo and KeyboardRegistry.
//

import Foundation
import Testing
@testable import WurstfingerApp

// MARK: - KeyboardInfo

struct KeyboardInfoTests {
    @Test func initFromDescriptor() {
        let descriptor = LanguageDefinitions.german
        let info = KeyboardInfo(from: descriptor)
        #expect(info.id == descriptor.id)
        #expect(info.title == descriptor.title)
        #expect(info.localeIdentifier == descriptor.localeIdentifier)
    }

    @Test func identifiable() {
        let info = KeyboardInfo(id: "test", title: "Test", localeIdentifier: "en_US")
        #expect(info.id == "test")
    }
}

// MARK: - KeyboardRegistry

/// `KeyboardRegistry.cache` is a process-global static shared with every other
/// suite in the test run (~11 suites load the same ids in parallel).
/// `.serialized` only orders tests *within* this suite, so these tests must
/// never assert that an id is globally *absent* from the cache after an evict:
/// any concurrent `load(id:)` re-caches it and flips the assertion (the
/// documented cause of the intermittent `loadCachesResult` failures, review
/// H5). Presence is safe to assert — no other suite evicts.
///
/// Tests below therefore only assert presence and load/evict/reload round-trip
/// behavior. Residual risk: "evict actually removes the entry" is only
/// observable via global absence and stays untested until the registry becomes
/// injectable (owner decision deferred, see the 2026-07-07 review, H5).
@Suite(.serialized)
struct KeyboardRegistryTests {
    @Test func availableContainsAllLanguages() {
        let expectedIDs = Set(LanguageDefinitions.all.map(\.id))
        let actualIDs = Set(KeyboardRegistry.available.map(\.id))
        #expect(actualIDs == expectedIDs)
    }

    @Test func availableContainsGerman() {
        let german = KeyboardRegistry.available.first { $0.id == LanguageDefinitions.german.id }
        #expect(german != nil)
        #expect(german?.title == LanguageDefinitions.german.title)
        #expect(german?.localeIdentifier == LanguageDefinitions.german.localeIdentifier)
    }

    @Test func loadReturnsCorrectDefinition() {
        let definition = KeyboardRegistry.load(id: LanguageDefinitions.german.id)
        #expect(definition != nil)
        #expect(definition?.id == LanguageDefinitions.german.id)
        #expect(definition?.title == LanguageDefinitions.german.title)
    }

    @Test func loadCachesResult() {
        // Presence-only round trip: after a load the id is cached and repeated
        // loads return an equal definition. (Asserting absence after evictAll
        // here raced with parallel suites loading German — see suite comment.)
        let first = KeyboardRegistry.load(id: LanguageDefinitions.german.id)
        #expect(first != nil)
        #expect(KeyboardRegistry.isCached(id: LanguageDefinitions.german.id))
        let second = KeyboardRegistry.load(id: LanguageDefinitions.german.id)
        #expect(first == second)
    }

    @Test func loadNonexistentReturnsNil() {
        #expect(KeyboardRegistry.load(id: "nonexistent_layout") == nil)
        // Stable absence assertion: an unknown id can never be cached, so no
        // parallel suite can flip this.
        #expect(!KeyboardRegistry.isCached(id: "nonexistent_layout"))
    }

    @Test func evictedDefinitionReloads() {
        // The evict → absent transition is unobservable race-free (a parallel
        // load may re-cache immediately); what we can pin is that evicting
        // never breaks the registry: a subsequent load rebuilds an equal
        // definition from the descriptor.
        let before = KeyboardRegistry.load(id: LanguageDefinitions.german.id)
        KeyboardRegistry.evict(id: LanguageDefinitions.german.id)
        let reloaded = KeyboardRegistry.load(id: LanguageDefinitions.german.id)
        #expect(reloaded != nil)
        #expect(reloaded == before)
        #expect(KeyboardRegistry.isCached(id: LanguageDefinitions.german.id))
    }

    /// Regression test: the registry cache used to be an unsynchronized
    /// `static var` dictionary, which crashed with SIGSEGV in
    /// `Dictionary._Variant.setValue` when parallel test suites called
    /// `load(id:)` concurrently. Hammering the cache from multiple tasks
    /// documents the thread-safety contract (and trips TSan without the lock).
    ///
    /// The hammer is limited to two rarely-loaded ids: evicting German/English
    /// (or all languages) in a tight loop forced every concurrent suite into
    /// repeated full definition rebuilds — a contributor to the known
    /// `LanguageDefinitionValidationTests` timeout flakiness under full
    /// parallelism + coverage (review H5). Two ids still exercise every code
    /// path the lock guards (hit, miss+build, evict, query).
    @Test func concurrentLoadEvictAndQueryDoesNotCrash() async {
        let ids = [LanguageDefinitions.hebrew.id, LanguageDefinitions.tagalog.id]
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 16 {
                for id in ids {
                    group.addTask {
                        _ = KeyboardRegistry.load(id: id)
                        _ = KeyboardRegistry.isCached(id: id)
                    }
                    group.addTask {
                        KeyboardRegistry.evict(id: id)
                    }
                }
            }
        }
        for id in ids {
            #expect(KeyboardRegistry.load(id: id) != nil, "Failed to load \(id) after concurrent access")
        }
    }

    @Test func evictAllKeepsRegistryFunctional() {
        // See suite comment: post-evictAll absence cannot be asserted against
        // the shared static cache. Pin the behavioral contract instead —
        // evictAll never breaks subsequent loads, and loading re-caches.
        _ = KeyboardRegistry.load(id: LanguageDefinitions.german.id)
        _ = KeyboardRegistry.load(id: LanguageDefinitions.english.id)
        KeyboardRegistry.evictAll()
        #expect(KeyboardRegistry.load(id: LanguageDefinitions.german.id) != nil)
        #expect(KeyboardRegistry.load(id: LanguageDefinitions.english.id) != nil)
        #expect(KeyboardRegistry.isCached(id: LanguageDefinitions.german.id))
        #expect(KeyboardRegistry.isCached(id: LanguageDefinitions.english.id))
    }
}
