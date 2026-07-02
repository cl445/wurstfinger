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
        KeyboardRegistry.evictAll()
        let definition = KeyboardRegistry.load(id: LanguageDefinitions.german.id)
        #expect(definition != nil)
        #expect(definition?.id == LanguageDefinitions.german.id)
        #expect(definition?.title == LanguageDefinitions.german.title)
    }

    @Test func loadCachesResult() {
        KeyboardRegistry.evictAll()
        #expect(!KeyboardRegistry.isCached(id: LanguageDefinitions.german.id))
        let first = KeyboardRegistry.load(id: LanguageDefinitions.german.id)
        #expect(first != nil)
        #expect(KeyboardRegistry.isCached(id: LanguageDefinitions.german.id))
        let second = KeyboardRegistry.load(id: LanguageDefinitions.german.id)
        #expect(first == second)
    }

    @Test func loadNonexistentReturnsNil() {
        #expect(KeyboardRegistry.load(id: "nonexistent_layout") == nil)
    }

    @Test func evictRemovesFromCache() {
        KeyboardRegistry.evictAll()
        _ = KeyboardRegistry.load(id: LanguageDefinitions.german.id)
        #expect(KeyboardRegistry.isCached(id: LanguageDefinitions.german.id))
        KeyboardRegistry.evict(id: LanguageDefinitions.german.id)
        #expect(!KeyboardRegistry.isCached(id: LanguageDefinitions.german.id))
        // After evict, load should still work (rebuilds from LanguageDefinitions)
        let reloaded = KeyboardRegistry.load(id: LanguageDefinitions.german.id)
        #expect(reloaded != nil)
    }

    /// Regression test: the registry cache used to be an unsynchronized
    /// `static var` dictionary, which crashed with SIGSEGV in
    /// `Dictionary._Variant.setValue` when parallel test suites called
    /// `load(id:)` concurrently. Hammering the cache from multiple tasks
    /// documents the thread-safety contract (and trips TSan without the lock).
    @Test func concurrentLoadEvictAndQueryDoesNotCrash() async {
        KeyboardRegistry.evictAll()
        let ids = KeyboardRegistry.available.map(\.id)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 4 {
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

    @Test func evictAllClearsCache() {
        // Load a few definitions
        _ = KeyboardRegistry.load(id: LanguageDefinitions.german.id)
        _ = KeyboardRegistry.load(id: LanguageDefinitions.english.id)
        #expect(KeyboardRegistry.isCached(id: LanguageDefinitions.german.id))
        #expect(KeyboardRegistry.isCached(id: LanguageDefinitions.english.id))
        KeyboardRegistry.evictAll()
        #expect(!KeyboardRegistry.isCached(id: LanguageDefinitions.german.id))
        #expect(!KeyboardRegistry.isCached(id: LanguageDefinitions.english.id))
    }
}
