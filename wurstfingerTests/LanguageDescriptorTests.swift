//
//  LanguageDescriptorTests.swift
//  WurstfingerTests
//
//  Tests for LanguageDescriptor's lazy-build contract.
//

import Foundation
import Testing
@testable import WurstfingerApp

struct LanguageDescriptorTests {
    /// Records whether a descriptor's builder ran. `@unchecked Sendable` so it
    /// can be captured by the `@Sendable` builder closure.
    private final class BuildFlag: @unchecked Sendable {
        var didBuild = false
    }

    /// Reading a descriptor's metadata — including via `KeyboardInfo` — must not
    /// trigger the builder. This is the property that keeps keyboard-extension
    /// launch cheap: the registry can list and resolve languages without
    /// materialising any layout.
    @Test func readingMetadataDoesNotBuildDefinition() {
        let flag = BuildFlag()
        let descriptor = LanguageDescriptor(
            id: "xx_XX",
            title: "Test",
            localeIdentifier: "xx_XX"
        ) { meta in
            flag.didBuild = true
            return GridKeyboardFactory.layout(
                id: meta.id,
                title: meta.title,
                localeIdentifier: meta.localeIdentifier,
                centerCharacters: [
                    ["a", "n", "i"],
                    ["h", "o", "r"],
                    ["t", "e", "s"],
                ],
                directionalOverrides: [:]
            )
        }

        _ = descriptor.id
        _ = descriptor.title
        _ = descriptor.localeIdentifier
        _ = KeyboardInfo(from: descriptor)
        #expect(flag.didBuild == false, "Reading metadata must not build the definition")

        _ = descriptor.makeDefinition()
        #expect(flag.didBuild == true, "makeDefinition() must build the definition")
    }

    /// The whole registry path must stay metadata-only: `KeyboardRegistry.available`
    /// is derived from descriptors and must list every language without building
    /// any of them.
    @Test func registryAvailableExposesEveryDescriptor() {
        let descriptors = LanguageDefinitions.all
        let available = KeyboardRegistry.available
        let descriptorIDs = Set(descriptors.map(\.id))
        let availableIDs = Set(available.map(\.id))
        #expect(availableIDs == descriptorIDs)
        // Counts must equal the unique-id counts: a duplicate id would be
        // silently collapsed by the registry (indexed by id) and masked by the
        // Set comparison above.
        #expect(descriptors.count == descriptorIDs.count, "duplicate descriptor id")
        #expect(available.count == availableIDs.count, "duplicate registry id")
        #expect(available.count == descriptors.count)
    }

    /// Each built definition must carry exactly the metadata declared on its
    /// descriptor. Guards against a builder hardcoding a different id/title/locale
    /// instead of threading `meta`, which would silently desync the registry.
    @Test(arguments: LanguageDefinitions.all)
    func builtDefinitionMatchesDescriptorMetadata(descriptor: LanguageDescriptor) {
        let definition = descriptor.makeDefinition()
        #expect(definition.id == descriptor.id)
        #expect(definition.title == descriptor.title)
        #expect(definition.localeIdentifier == descriptor.localeIdentifier)
    }
}
