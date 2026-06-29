//
//  ActionPipelineTests.swift
//  WurstfingerTests
//
//  Tests for ActionContext, ActionPipeline, and the middleware suite
//  (HapticMiddleware, ComposeMiddleware, TextInputMiddleware,
//  AutoCapitalizationMiddleware, ModeTransitionMiddleware).
//

import Foundation
import Testing
@testable import WurstfingerApp

// MARK: - Helpers

private enum PipelineFixtures {
    static func context(
        action: KeyAction,
        binding: KeyBinding? = nil,
        mode: String = "main"
    ) -> ActionContext {
        ActionContext(action: action, binding: binding, mode: mode)
    }

    static func binding(
        label: String = "x",
        action: KeyAction,
        category: KeyCategory? = nil
    ) -> KeyBinding {
        KeyBinding(
            label: label,
            action: action,
            category: category,
            returnAction: nil,
            accessibilityLabel: nil
        )
    }

    static func key(
        id: String,
        bindings: [GestureType: KeyBinding]
    ) -> KeyConfig {
        KeyConfig(
            id: id,
            bindings: bindings,
            swipeMode: .eightWay,
            slideType: .none,
            style: .primary,
            tapCycleActions: nil
        )
    }

    static func mode(
        name: String,
        autoTransitions: [KeyCategory: String] = [:],
        keys: [KeyConfig] = []
    ) -> KeyboardMode {
        let keyMap = Dictionary(uniqueKeysWithValues: keys.map { ($0.id, $0) })
        return KeyboardMode(
            name: name,
            keys: keyMap,
            arrangements: [
                .portrait: GridArrangement(
                    columns: 1,
                    rows: [[KeyPlacement(keyId: keys.first?.id ?? "x")]]
                ),
            ],
            autoTransitions: autoTransitions,
            doubleTapMode: nil
        )
    }

    static func definition(modes: [KeyboardMode]) -> KeyboardDefinition {
        let modeMap = Dictionary(uniqueKeysWithValues: modes.map { ($0.name, $0) })
        return KeyboardDefinition(
            title: "Fixture",
            id: "fixture",
            localeIdentifier: "en_US",
            modes: modeMap,
            defaultMode: modes.first?.name ?? "main",
            settings: KeyboardDefinitionSettings(
                autoCapitalize: true,
                autoCapitalizers: [],
                composeRuleOverrides: nil
            )
        )
    }
}

/// Shared event log used to assert execution order across multiple
/// `RecordingMiddleware` instances in the same pipeline.
private final class OrderLog {
    var events: [String] = []
}

/// A recording middleware that captures the context it received and
/// forwards it unchanged. Used to verify pipeline ordering and
/// short-circuit behavior.
///
/// Optionally also appends `name` to a shared `OrderLog` when invoked,
/// so multi-middleware tests can assert the exact execution order
/// rather than just reachability.
private final class RecordingMiddleware: ActionMiddleware {
    var received: [ActionContext] = []
    private let shouldForward: Bool
    private let name: String?
    private let orderLog: OrderLog?

    init(forwards: Bool = true, name: String? = nil, orderLog: OrderLog? = nil) {
        shouldForward = forwards
        self.name = name
        self.orderLog = orderLog
    }

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        received.append(context)
        if let name {
            orderLog?.events.append(name)
        }
        if shouldForward {
            next(context)
        }
    }
}

/// A middleware that rewrites the action before forwarding.
private final class RewritingMiddleware: ActionMiddleware {
    private let rewrite: (KeyAction) -> KeyAction

    init(rewrite: @escaping (KeyAction) -> KeyAction) {
        self.rewrite = rewrite
    }

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        var transformed = context
        transformed.action = rewrite(context.action)
        next(transformed)
    }
}

// MARK: - ActionPipeline

struct ActionPipelineTests {
    @Test func runsMiddlewaresInOrder() {
        let log = OrderLog()
        let a = RecordingMiddleware(name: "A", orderLog: log)
        let b = RecordingMiddleware(name: "B", orderLog: log)
        let c = RecordingMiddleware(name: "C", orderLog: log)
        let pipeline = ActionPipeline(middlewares: [a, b, c])

        pipeline.process(PipelineFixtures.context(action: .commitText("a")))

        #expect(log.events == ["A", "B", "C"])
        #expect(a.received.count == 1)
        #expect(b.received.count == 1)
        #expect(c.received.count == 1)
    }

    @Test func shortCircuitsWhenMiddlewareSkipsNext() {
        let a = RecordingMiddleware()
        let stopper = RecordingMiddleware(forwards: false)
        let c = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [a, stopper, c])

        pipeline.process(PipelineFixtures.context(action: .commitText("a")))

        #expect(a.received.count == 1)
        #expect(stopper.received.count == 1)
        #expect(c.received.isEmpty, "Downstream middleware must not run when next is skipped")
    }

    @Test func middlewareCanTransformAction() {
        let rewriter = RewritingMiddleware { _ in .commitText("Y") }
        let sink = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [rewriter, sink])

        pipeline.process(PipelineFixtures.context(action: .commitText("x")))

        #expect(sink.received.first?.action == .commitText("Y"))
    }

    @Test func emptyPipelineIsNoop() {
        let pipeline = ActionPipeline(middlewares: [])
        // Should not crash.
        pipeline.process(PipelineFixtures.context(action: .commitText("a")))
    }
}

// MARK: - HapticMiddleware

struct HapticMiddlewareTests {
    @Test func triggersFeedbackForAction() {
        var triggered: [KeyAction] = []
        let middleware = HapticMiddleware(trigger: { triggered.append($0) })
        let sink = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [middleware, sink])

        pipeline.process(PipelineFixtures.context(action: .commitText("a")))

        #expect(triggered == [.commitText("a")])
        #expect(sink.received.first?.action == .commitText("a"))
    }

    @Test func forwardsContextUnchanged() {
        let middleware = HapticMiddleware(trigger: { _ in })
        let sink = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [middleware, sink])

        let original = PipelineFixtures.context(
            action: .deleteBackward,
            binding: PipelineFixtures.binding(action: .deleteBackward),
            mode: "shifted"
        )
        pipeline.process(original)

        #expect(sink.received.first?.action == .deleteBackward)
        #expect(sink.received.first?.mode == "shifted")
    }
}

// MARK: - ComposeMiddleware

struct ComposeMiddlewareTests {
    @Test func composesWhenRuleMatches() {
        var deleted = 0
        let middleware = ComposeMiddleware(
            compose: { previous, trigger in
                (previous == "a" && trigger == "¨") ? "ä" : nil
            },
            cycleAccent: { _ in nil },
            previousCharacter: { "a" },
            deletePreviousCharacter: { deleted += 1 }
        )
        let sink = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [middleware, sink])

        pipeline.process(PipelineFixtures.context(action: .compose(trigger: "¨")))

        #expect(sink.received.first?.action == .commitText("ä"))
        #expect(deleted == 1, "Previous character must be consumed when compose succeeds")
    }

    @Test func insertsTriggerWhenNoRuleMatches() {
        var deleted = 0
        let middleware = ComposeMiddleware(
            compose: { _, _ in nil },
            cycleAccent: { _ in nil },
            previousCharacter: { "x" },
            deletePreviousCharacter: { deleted += 1 }
        )
        let sink = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [middleware, sink])

        pipeline.process(PipelineFixtures.context(action: .compose(trigger: "¨")))

        #expect(sink.received.first?.action == .commitText("¨"))
        #expect(deleted == 0, "No rule → no previous-character deletion")
    }

    @Test func insertsTriggerWhenNoPreviousCharacter() {
        let middleware = ComposeMiddleware(
            compose: { _, _ in "should not run" },
            cycleAccent: { _ in nil },
            previousCharacter: { "" },
            deletePreviousCharacter: { Issue.record("Must not delete without previous char") }
        )
        let sink = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [middleware, sink])

        pipeline.process(PipelineFixtures.context(action: .compose(trigger: "'")))

        #expect(sink.received.first?.action == .commitText("'"))
    }

    @Test func passesThroughNonTextActions() {
        let middleware = ComposeMiddleware(
            compose: { _, _ in Issue.record("compose must not run for non-text actions"); return nil },
            cycleAccent: { _ in nil },
            previousCharacter: { "a" },
            deletePreviousCharacter: { Issue.record("delete must not run for non-text actions") }
        )
        let sink = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [middleware, sink])

        pipeline.process(PipelineFixtures.context(action: .deleteBackward))

        #expect(sink.received.first?.action == .deleteBackward)
    }

    @Test func composeTriggerProducesComposedCharacter() {
        var deleted = 0
        let middleware = ComposeMiddleware(
            compose: { previous, trigger in
                (previous == "a" && trigger == "°") ? "å" : nil
            },
            cycleAccent: { _ in nil },
            previousCharacter: { "a" },
            deletePreviousCharacter: { deleted += 1 }
        )
        let sink = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [middleware, sink])

        pipeline.process(PipelineFixtures.context(action: .compose(trigger: "°")))

        #expect(sink.received.first?.action == .commitText("å"))
        #expect(deleted == 1)
    }

    @Test func passesThroughCommitTextWithoutComposeCheck() {
        let middleware = ComposeMiddleware(
            compose: { _, _ in Issue.record("compose must not run for commitText"); return nil },
            cycleAccent: { _ in nil },
            previousCharacter: { "a" },
            deletePreviousCharacter: { Issue.record("Must not delete for commitText") }
        )
        let sink = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [middleware, sink])

        pipeline.process(PipelineFixtures.context(action: .commitText("!")))

        #expect(sink.received.first?.action == .commitText("!"))
    }

    // MARK: - cycleAccents

    @Test func cyclesAccentWhenCycleExists() {
        var deleted = 0
        let middleware = ComposeMiddleware(
            compose: { _, _ in Issue.record("compose must not run for cycleAccents"); return nil },
            cycleAccent: { $0 == "ä" ? "â" : nil },
            previousCharacter: { "ä" },
            deletePreviousCharacter: { deleted += 1 }
        )
        let sink = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [middleware, sink])

        pipeline.process(PipelineFixtures.context(action: .cycleAccents))

        #expect(sink.received.first?.action == .commitText("â"))
        #expect(deleted == 1, "Previous character must be consumed when a cycle exists")
    }

    @Test func cycleAccentsPassesThroughWhenNoPreviousCharacter() {
        let middleware = ComposeMiddleware(
            compose: { _, _ in nil },
            cycleAccent: { _ in Issue.record("cycleAccent must not run without a previous char"); return nil },
            previousCharacter: { "" },
            deletePreviousCharacter: { Issue.record("Must not delete without previous char") }
        )
        let sink = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [middleware, sink])

        pipeline.process(PipelineFixtures.context(action: .cycleAccents))

        // No previous character → action forwarded unchanged.
        #expect(sink.received.first?.action == .cycleAccents)
    }

    @Test func cycleAccentsPassesThroughWhenNoCycleExists() {
        let middleware = ComposeMiddleware(
            compose: { _, _ in nil },
            cycleAccent: { _ in nil }, // no cycle for this character
            previousCharacter: { "x" },
            deletePreviousCharacter: { Issue.record("Must not delete when no cycle exists") }
        )
        let sink = RecordingMiddleware()
        let pipeline = ActionPipeline(middlewares: [middleware, sink])

        pipeline.process(PipelineFixtures.context(action: .cycleAccents))

        #expect(sink.received.first?.action == .cycleAccents)
    }
}

// MARK: - TextInputMiddleware

private final class MockTextInputTarget: TextInputTarget {
    enum Event: Equatable {
        case insertText(String)
        case deleteBackward
        case adjustCursor(Int)
    }

    var events: [Event] = []
    var documentContextBeforeInput: String?
    var documentContextAfterInput: String?
    var selectedText: String?
    var hasFullAccess: Bool = false

    func insertText(_ text: String) {
        events.append(.insertText(text))
    }

    func deleteBackward() {
        events.append(.deleteBackward)
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        events.append(.adjustCursor(offset))
    }
}

struct TextInputMiddlewareTests {
    private func pipeline(target: MockTextInputTarget) -> ActionPipeline {
        let middleware = TextInputMiddleware(target: { target })
        return ActionPipeline(middlewares: [middleware])
    }

    @Test func commitTextInsertsText() {
        let target = MockTextInputTarget()
        pipeline(target: target).process(PipelineFixtures.context(action: .commitText("hi")))
        #expect(target.events == [.insertText("hi")])
    }

    @Test func deleteBackwardDeletes() {
        let target = MockTextInputTarget()
        pipeline(target: target).process(PipelineFixtures.context(action: .deleteBackward))
        #expect(target.events == [.deleteBackward])
    }

    @Test func spaceInsertsSpaceCharacter() {
        let target = MockTextInputTarget()
        pipeline(target: target).process(PipelineFixtures.context(action: .space))
        #expect(target.events == [.insertText(" ")])
    }

    @Test func newlineInsertsLineBreak() {
        let target = MockTextInputTarget()
        pipeline(target: target).process(PipelineFixtures.context(action: .newline))
        #expect(target.events == [.insertText("\n")])
    }

    @Test func moveCursorAdjustsPosition() {
        let target = MockTextInputTarget()
        pipeline(target: target).process(PipelineFixtures.context(action: .moveCursor(offset: -3)))
        #expect(target.events == [.adjustCursor(-3)])
    }

    @Test func nonTextActionsAreIgnored() {
        let target = MockTextInputTarget()
        let sink = RecordingMiddleware()
        let middleware = TextInputMiddleware(target: { target })
        let pipe = ActionPipeline(middlewares: [middleware, sink])

        let actions: [KeyAction] = [
            .advanceToNextInputMode,
            .switchMode("numeric"),
            .dismissKeyboard,
            .copy,
        ]
        for action in actions {
            pipe.process(PipelineFixtures.context(action: action))
        }

        #expect(target.events.isEmpty)
        // Pipeline contract: no-op branches must still forward unchanged.
        #expect(sink.received.map(\.action) == actions)
    }

    @Test func missingTargetIsToleratedAndForwardsContext() {
        let middleware = TextInputMiddleware(target: { nil })
        let sink = RecordingMiddleware()
        let pipe = ActionPipeline(middlewares: [middleware, sink])

        pipe.process(PipelineFixtures.context(action: .commitText("x")))

        #expect(sink.received.count == 1, "Pipeline must continue even without a target")
    }
}

// MARK: - TelexMiddleware

struct TelexMiddlewareTests {
    /// Shared spy capturing deleteBackward calls and exposing a mutable
    /// documentContextBefore. Tests configure the context, dispatch through
    /// the pipeline, and then inspect what the middleware forwarded.
    private final class Spy {
        var deletes = 0
        var context: String?
        func deleteBackward() {
            deletes += 1
        }
    }

    private func pipeline(
        spy: Spy,
        isActive: @escaping () -> Bool = { true },
        digraph: @escaping (String, String, String) -> (String, Int)? = { _, _, _ in nil },
        single: @escaping (String, String) -> String? = { _, _ in nil }
    ) -> (ActionPipeline, RecordingMiddleware) {
        let telex = TelexMiddleware(
            isActive: isActive,
            documentContextBefore: { spy.context },
            deleteBackward: { spy.deleteBackward() },
            composeDigraph: digraph,
            composeSingle: single
        )
        let sink = RecordingMiddleware()
        return (ActionPipeline(middlewares: [telex, sink]), sink)
    }

    @Test func inactiveMiddlewarePassesThroughUnchanged() {
        let spy = Spy()
        spy.context = "a"
        let (pipe, sink) = pipeline(
            spy: spy,
            isActive: { false },
            single: { _, _ in "á" }
        )
        pipe.process(PipelineFixtures.context(action: .commitText("s")))
        #expect(sink.received.count == 1)
        #expect(sink.received.first?.action == .commitText("s"))
        #expect(spy.deletes == 0)
    }

    @Test func singleCharComposeReplacesAction() {
        let spy = Spy()
        spy.context = "a"
        let (pipe, sink) = pipeline(
            spy: spy,
            single: { prev, trig in prev == "a" && trig == "s" ? "á" : nil }
        )
        pipe.process(PipelineFixtures.context(action: .commitText("s")))
        #expect(sink.received.first?.action == .commitText("á"))
        #expect(spy.deletes == 1)
    }

    @Test func digraphComposePrefersTwoCharLookback() {
        let spy = Spy()
        spy.context = "uo"
        // Both would match — the middleware must prefer the digraph.
        let (pipe, sink) = pipeline(
            spy: spy,
            digraph: { p2, p1, t in p2 == "u" && p1 == "o" && t == "w" ? ("ươ", 2) : nil },
            single: { _, _ in "should-not-win" }
        )
        pipe.process(PipelineFixtures.context(action: .commitText("w")))
        #expect(sink.received.first?.action == .commitText("ươ"))
        #expect(spy.deletes == 2)
    }

    @Test func nonMatchingTriggerIsForwardedUnchanged() {
        let spy = Spy()
        spy.context = "x"
        let (pipe, sink) = pipeline(spy: spy)
        pipe.process(PipelineFixtures.context(action: .commitText("q")))
        #expect(sink.received.first?.action == .commitText("q"))
        #expect(spy.deletes == 0)
    }

    @Test func multiCharCommitIsNotComposed() {
        let spy = Spy()
        spy.context = "a"
        let (pipe, sink) = pipeline(
            spy: spy,
            single: { _, _ in "á" }
        )
        pipe.process(PipelineFixtures.context(action: .commitText("ss")))
        #expect(sink.received.first?.action == .commitText("ss"))
        #expect(spy.deletes == 0)
    }

    @Test func nilDocumentContextPassesThrough() {
        let spy = Spy()
        spy.context = nil
        let (pipe, sink) = pipeline(
            spy: spy,
            single: { _, _ in "á" }
        )
        pipe.process(PipelineFixtures.context(action: .commitText("s")))
        #expect(sink.received.first?.action == .commitText("s"))
        #expect(spy.deletes == 0)
    }

    @Test func nonCommitTextActionsAreForwardedUnchanged() {
        let spy = Spy()
        spy.context = "a"
        let (pipe, sink) = pipeline(spy: spy)
        pipe.process(PipelineFixtures.context(action: .deleteBackward))
        pipe.process(PipelineFixtures.context(action: .space))
        #expect(sink.received.map(\.action) == [.deleteBackward, .space])
        #expect(spy.deletes == 0)
    }
}

// MARK: - AutoCapitalizationMiddleware

struct AutoCapitalizationMiddlewareTests {
    @Test func engagesCapitalizationWhenEvaluateReturnsTrue() {
        var capitalized = 0
        var released = 0
        let middleware = AutoCapitalizationMiddleware(
            evaluate: { true },
            onCapitalize: { capitalized += 1 },
            onReleaseCapitalize: { released += 1 }
        )
        let pipe = ActionPipeline(middlewares: [middleware])

        pipe.process(PipelineFixtures.context(action: .commitText(".")))
        pipe.process(PipelineFixtures.context(action: .space))

        #expect(capitalized == 2)
        #expect(released == 0)
    }

    @Test func releasesCapitalizationWhenEvaluateReturnsFalse() {
        var capitalized = 0
        var released = 0
        let middleware = AutoCapitalizationMiddleware(
            evaluate: { false },
            onCapitalize: { capitalized += 1 },
            onReleaseCapitalize: { released += 1 }
        )
        let pipe = ActionPipeline(middlewares: [middleware])

        pipe.process(PipelineFixtures.context(action: .deleteBackward))

        #expect(capitalized == 0)
        #expect(released == 1)
    }

    @Test func skipsWhenEvaluateReturnsNil() {
        // nil means "auto-capitalization disabled in settings".
        var capitalized = 0
        var released = 0
        let middleware = AutoCapitalizationMiddleware(
            evaluate: { nil },
            onCapitalize: { capitalized += 1 },
            onReleaseCapitalize: { released += 1 }
        )
        let pipe = ActionPipeline(middlewares: [middleware])

        pipe.process(PipelineFixtures.context(action: .commitText("a")))

        #expect(capitalized == 0)
        #expect(released == 0)
    }

    @Test func ignoresActionsThatDoNotAffectCapitalization() {
        var evaluated = 0
        let middleware = AutoCapitalizationMiddleware(
            evaluate: { evaluated += 1; return true },
            onCapitalize: {},
            onReleaseCapitalize: {}
        )
        let sink = RecordingMiddleware()
        let pipe = ActionPipeline(middlewares: [middleware, sink])

        let actions: [KeyAction] = [
            .moveCursor(offset: 1),
            .copy,
            .advanceToNextInputMode,
        ]
        for action in actions {
            pipe.process(PipelineFixtures.context(action: action))
        }

        #expect(evaluated == 0, "Cursor moves and clipboard-only actions don't affect caps")
        // Pipeline contract: skipped branch must still forward downstream.
        #expect(sink.received.map(\.action) == actions)
    }

    @Test func affectsCapitalizationPolicyIsStable() {
        // Sanity check the static policy so future additions to KeyAction
        // force a deliberate decision here.
        #expect(AutoCapitalizationMiddleware.affectsCapitalization(.commitText("a")))
        #expect(AutoCapitalizationMiddleware.affectsCapitalization(.space))
        #expect(AutoCapitalizationMiddleware.affectsCapitalization(.newline))
        #expect(AutoCapitalizationMiddleware.affectsCapitalization(.deleteBackward))
        #expect(AutoCapitalizationMiddleware.affectsCapitalization(.paste))
        #expect(!AutoCapitalizationMiddleware.affectsCapitalization(.moveCursor(offset: 1)))
        #expect(!AutoCapitalizationMiddleware.affectsCapitalization(.switchMode("main")))
        #expect(!AutoCapitalizationMiddleware.affectsCapitalization(.copy))
    }

    @Test func evaluateRunsAfterDownstreamMiddlewares() {
        // AutoCap must call next first, then re-evaluate the proxy state
        // (which downstream middlewares may have changed).
        var evaluationOrder: [String] = []
        let autoCap = AutoCapitalizationMiddleware(
            evaluate: { evaluationOrder.append("evaluate"); return nil },
            onCapitalize: {},
            onReleaseCapitalize: {}
        )
        let rewriter = RewritingMiddleware { action in
            evaluationOrder.append("downstream")
            return action
        }
        let pipe = ActionPipeline(middlewares: [autoCap, rewriter])

        pipe.process(PipelineFixtures.context(action: .commitText("x")))

        #expect(evaluationOrder == ["downstream", "evaluate"])
    }
}

// MARK: - ModeTransitionMiddleware

private func modeTransitionDefinition(
    shiftedAutoTransitions: [KeyCategory: String]
) -> KeyboardDefinition {
    let main = PipelineFixtures.mode(
        name: "main",
        keys: [PipelineFixtures.key(id: "a", bindings: [:])]
    )
    let shifted = PipelineFixtures.mode(
        name: "shifted",
        autoTransitions: shiftedAutoTransitions,
        keys: [PipelineFixtures.key(id: "a", bindings: [:])]
    )
    let capsLock = PipelineFixtures.mode(
        name: "capsLock",
        keys: [PipelineFixtures.key(id: "a", bindings: [:])]
    )
    return PipelineFixtures.definition(modes: [main, shifted, capsLock])
}

struct ModeTransitionMiddlewareTests {
    @Test func shiftedLetterReturnsToMain() {
        var changes: [String] = []
        let middleware = ModeTransitionMiddleware(
            definition: modeTransitionDefinition(shiftedAutoTransitions: [.letter: "main"]),
            onModeChange: { changes.append($0) }
        )
        let pipe = ActionPipeline(middlewares: [middleware])

        let binding = PipelineFixtures.binding(action: .commitText("A"), category: .letter)
        pipe.process(ActionContext(action: .commitText("A"), binding: binding, mode: "shifted"))

        #expect(changes == ["main"])
    }

    @Test func capsLockDoesNotTransition() {
        var changes: [String] = []
        let middleware = ModeTransitionMiddleware(
            definition: modeTransitionDefinition(shiftedAutoTransitions: [.letter: "main"]),
            onModeChange: { changes.append($0) }
        )
        let sink = RecordingMiddleware()
        let pipe = ActionPipeline(middlewares: [middleware, sink])

        let binding = PipelineFixtures.binding(action: .commitText("A"), category: .letter)
        pipe.process(ActionContext(action: .commitText("A"), binding: binding, mode: "capsLock"))

        #expect(changes.isEmpty)
        // Pipeline contract: no transition still forwards downstream.
        #expect(sink.received.map(\.action) == [.commitText("A")])
    }

    @Test func unknownModeIsIgnored() {
        var changes: [String] = []
        let middleware = ModeTransitionMiddleware(
            definition: modeTransitionDefinition(shiftedAutoTransitions: [.letter: "main"]),
            onModeChange: { changes.append($0) }
        )
        let sink = RecordingMiddleware()
        let pipe = ActionPipeline(middlewares: [middleware, sink])

        let binding = PipelineFixtures.binding(action: .commitText("A"), category: .letter)
        pipe.process(ActionContext(action: .commitText("A"), binding: binding, mode: "ghost"))

        #expect(changes.isEmpty)
        // Pipeline contract: unknown mode still forwards downstream.
        #expect(sink.received.map(\.action) == [.commitText("A")])
    }

    @Test func fallsBackToInferredCategoryWhenBindingMissing() {
        // No explicit binding → category derived from action (.commitText("a") → .letter).
        var changes: [String] = []
        let middleware = ModeTransitionMiddleware(
            definition: modeTransitionDefinition(shiftedAutoTransitions: [.letter: "main"]),
            onModeChange: { changes.append($0) }
        )
        let pipe = ActionPipeline(middlewares: [middleware])

        pipe.process(ActionContext(action: .commitText("a"), binding: nil, mode: "shifted"))

        #expect(changes == ["main"])
    }

    @Test func doesNotFireForSameModeTransition() {
        // Guard against infinite loops if a transition maps to itself.
        var changes: [String] = []
        let middleware = ModeTransitionMiddleware(
            definition: modeTransitionDefinition(shiftedAutoTransitions: [.letter: "shifted"]),
            onModeChange: { changes.append($0) }
        )
        let sink = RecordingMiddleware()
        let pipe = ActionPipeline(middlewares: [middleware, sink])

        let binding = PipelineFixtures.binding(action: .commitText("A"), category: .letter)
        pipe.process(ActionContext(action: .commitText("A"), binding: binding, mode: "shifted"))

        #expect(changes.isEmpty)
        // Pipeline contract: suppressed transition still forwards downstream.
        #expect(sink.received.map(\.action) == [.commitText("A")])
    }

    @Test func runsAfterDownstreamMiddlewares() {
        var order: [String] = []
        let downstream = RewritingMiddleware { action in
            order.append("downstream")
            return action
        }
        let transition = ModeTransitionMiddleware(
            definition: modeTransitionDefinition(shiftedAutoTransitions: [.letter: "main"]),
            onModeChange: { _ in order.append("transition") }
        )
        let pipe = ActionPipeline(middlewares: [transition, downstream])

        let binding = PipelineFixtures.binding(action: .commitText("A"), category: .letter)
        pipe.process(ActionContext(action: .commitText("A"), binding: binding, mode: "shifted"))

        #expect(order == ["downstream", "transition"])
    }
}

// MARK: - Pipeline Integration

struct PipelineIntegrationTests {
    @Test func composeThenTextInputProducesCommittedCharacter() {
        // ComposeMiddleware rewrites the action; TextInputMiddleware then
        // inserts the rewritten text into the target.
        let target = MockTextInputTarget()
        var deleted = 0
        let compose = ComposeMiddleware(
            compose: { prev, trig in (prev == "a" && trig == "¨") ? "ä" : nil },
            cycleAccent: { _ in nil },
            previousCharacter: { "a" },
            deletePreviousCharacter: { deleted += 1 }
        )
        let input = TextInputMiddleware(target: { target })
        let pipe = ActionPipeline(middlewares: [compose, input])

        pipe.process(PipelineFixtures.context(action: .compose(trigger: "¨")))

        #expect(deleted == 1)
        #expect(target.events == [.insertText("ä")])
    }

    @Test func hapticsFireBeforeTextInput() {
        var order: [String] = []
        let target = MockTextInputTarget()
        let haptic = HapticMiddleware(trigger: { _ in order.append("haptic") })
        let input = TextInputMiddleware(target: { () -> TextInputTarget? in
            order.append("input")
            return target
        })
        let pipe = ActionPipeline(middlewares: [haptic, input])

        pipe.process(PipelineFixtures.context(action: .commitText("x")))

        #expect(order == ["haptic", "input"])
    }

    @Test func fullPipelineRunsAllMiddlewaresInOrder() {
        var steps: [String] = []
        let target = MockTextInputTarget()
        let haptic = HapticMiddleware(trigger: { _ in steps.append("haptic") })
        let compose = ComposeMiddleware(
            compose: { _, _ in nil },
            cycleAccent: { _ in nil },
            previousCharacter: { "" },
            deletePreviousCharacter: {}
        )
        let input = TextInputMiddleware(target: {
            steps.append("input")
            return target
        })
        let autoCap = AutoCapitalizationMiddleware(
            evaluate: { steps.append("evaluate"); return nil },
            onCapitalize: {},
            onReleaseCapitalize: {}
        )
        let transition = ModeTransitionMiddleware(
            definition: modeTransitionDefinition(
                shiftedAutoTransitions: [.letter: "main"]
            ),
            onModeChange: { _ in steps.append("transition") }
        )
        let pipe = ActionPipeline(middlewares: [haptic, compose, input, autoCap, transition])

        let binding = PipelineFixtures.binding(action: .commitText("a"), category: .letter)
        pipe.process(ActionContext(action: .commitText("a"), binding: binding, mode: "shifted"))

        // autoCap and transition both run post-`next`, so they unwind in
        // reverse order: transition (deepest) fires before autoCap.evaluate.
        #expect(steps == ["haptic", "input", "transition", "evaluate"])
        #expect(target.events == [.insertText("a")])
    }
}
