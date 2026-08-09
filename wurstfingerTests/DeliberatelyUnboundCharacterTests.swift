//
//  DeliberatelyUnboundCharacterTests.swift
//  WurstfingerTests
//
//  The mirror image of `LanguageAlphabetCoverageTests`: that file pins the
//  characters every layout must be able to produce, this one pins the handful
//  that no layout is supposed to produce any more. A character that was dropped
//  on purpose looks exactly like one that was lost by accident when somebody
//  reads the layout tables a year later, so the reason is written down here and
//  the decision is held in place until someone deliberately revisits it.
//

import Foundation
import Testing
@testable import WurstfingerApp

/// A character deliberately left unbound, with the reason it went away.
private struct UnboundCharacter {
    let scalar: Unicode.Scalar
    let name: String
    let reason: String

    var codePoint: String {
        String(format: "U+%04X", scalar.value)
    }
}

struct DeliberatelyUnboundCharacterTests {
    /// One entry so far. Until #285 the `^` key's return swipe committed the
    /// stand-alone modifier circumflex; that was Wurstfinger's own addition,
    /// which the layout Wurstfinger is modelled on never had, and #285 gave the
    /// return swipe to the caron dead key instead — one gesture to č ď ě ň ř š ť ž
    /// where before there was only the accent cycle. The ASCII `^` stayed on the
    /// same key, so nothing a keyboard is normally asked for was lost.
    ///
    /// This is a record, not a ban: if a layout ever wants the character back,
    /// bind it, drop the entry here, and say so in the CHANGELOG — the only
    /// thing being ruled out is losing it a second time without noticing.
    private static let cuts = [
        UnboundCharacter(
            scalar: "\u{02C6}",
            name: "modifier circumflex",
            reason: "given up by the ^ key's return swipe in favour of the caron dead key (#285)"
        ),
    ]

    @Test(arguments: LanguageDefinitions.all)
    func noLayoutProducesADeliberatelyUnboundCharacter(descriptor: LanguageDescriptor) {
        let producible = Self.producibleText(of: descriptor.makeDefinition())
        for cut in Self.cuts {
            #expect(
                !producible.contains(String(cut.scalar)),
                """
                [\(descriptor.id)] can produce the \(cut.name) \(cut.codePoint) again — \
                it was \(cut.reason). If that is intended, remove it from `cuts` and \
                record the change in the CHANGELOG.
                """
            )
        }
    }

    /// The routes by which this definition puts text into the document: every
    /// `commitText` (primary and return swipe, all modes), the space and newline
    /// actions, every compose trigger a key binds — `ComposeMiddleware` commits
    /// an unmatched trigger verbatim, which is the only way ASCII `^` reaches
    /// the document at all — every output of a bound trigger's rules, every
    /// sequential-combine result, and the accent-cycle closure over all of
    /// those. Not modelled, because the characters do not come from the
    /// definition's own tables: a paste, case mapping of text already in the
    /// document, and the algorithmic input methods (Hangul, Telex).
    ///
    /// Derived the same way `LanguageAlphabetCoverageTests` derives it but
    /// deliberately duplicated rather than shared. The coverage test asks "is
    /// this reachable?", this one asks "is this unreachable?", which flips which
    /// way an incomplete model is safe: a route it misses costs the coverage
    /// test a false alarm and costs this one the finding. So the two have to be
    /// free to diverge here — and a cut that one of the unmodelled routes could
    /// reinstate needs a pin of its own rather than this one.
    private static func producibleText(of definition: KeyboardDefinition) -> Set<String> {
        var direct: Set<String> = []
        var composeTriggers: Set<String> = []
        for mode in definition.modes.values {
            for key in mode.keys.values {
                for binding in key.bindings.values {
                    collect(binding.action, into: &direct, triggers: &composeTriggers)
                    if let returnAction = binding.returnAction {
                        collect(returnAction, into: &direct, triggers: &composeTriggers)
                    }
                }
            }
        }

        let engine = definition.settings.composeRuleOverrides
            .map { ComposeEngine.withGlobalRules(overrides: $0) } ?? ComposeEngine.shared
        for trigger in composeTriggers {
            if let outputs = engine.ruleSet.rules[trigger]?.values {
                direct.formUnion(outputs)
            }
        }
        if let combine = definition.settings.combineRuleSet {
            for map in combine.rules.values {
                direct.formUnion(map.values)
            }
        }
        return cycleClosure(of: direct, engine: engine)
    }

    private static func collect(
        _ action: KeyAction, into direct: inout Set<String>, triggers: inout Set<String>
    ) {
        switch action {
        case let .commitText(text): direct.insert(text)
        case let .compose(trigger):
            // A bound trigger is producible text in its own right, not just a
            // key into the rule table: `ComposeMiddleware` commits it verbatim
            // whenever no rule matches the preceding character. Without this,
            // reinstating a cut character as a dead key would leave the test
            // green — and ASCII `^`, which reaches the document by no other
            // route, would be reported as unproducible.
            triggers.insert(trigger)
            direct.insert(trigger)
        case .space: direct.insert(" ")
        case .newline: direct.insert("\n")
        default: break
        }
    }

    /// The 🅒 key cycles the character before the cursor through its accent
    /// variants, so everything on a reachable character's cycle is reachable too
    /// — and a cut character sitting on such a cycle would not be cut at all.
    private static func cycleClosure(of seeds: Set<String>, engine: ComposeEngine) -> Set<String> {
        var result = seeds
        var pending = Array(seeds)
        while let character = pending.popLast() {
            guard let next = engine.cycleAccent(for: character),
                  result.insert(next).inserted
            else { continue }
            pending.append(next)
        }
        return result
    }
}
