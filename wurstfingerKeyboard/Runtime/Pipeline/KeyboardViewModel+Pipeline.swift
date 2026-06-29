//
//  KeyboardViewModel+Pipeline.swift
//  Wurstfinger
//
//  Extension that handles the data-driven gesture pipeline:
//  definition loading, resolver chain, pipeline assembly,
//  gesture dispatch, mode switching, and slide handling.
//

import Foundation

extension KeyboardViewModel {
    // MARK: - Data-Driven Loading & Pipeline

    /// Loads a keyboard definition by ID from the registry and sets up the
    /// resolver chain and action pipeline.
    func loadDefinition(for id: String) {
        guard let base = KeyboardRegistry.load(id: id) else { return }
        let definition = applyNumpadStyle(to: base)
        currentDefinition = definition
        activeModeName = definition.defaultMode
        pipelineLocale = definition.locale
        currentMode = definition.mode(activeModeName)
        rebuildResolverChain()
        rebuildPipeline()
    }

    /// Swaps the numeric layer to the classic (7-8-9) ordering when the user
    /// selected it. The registry caches the phone-style definition, so this
    /// always derives from the canonical phone layout and never mutates the cache.
    private func applyNumpadStyle(to definition: KeyboardDefinition) -> KeyboardDefinition {
        let raw = sharedDefaults.string(forKey: SettingsKey.numpadStyle.rawValue)
        let style = raw.flatMap(NumpadStyle.init(rawValue:)) ?? .phone
        guard style == .classic else { return definition }
        let classicNumeric = NumericLayouts.classic(
            backToAlphaLabel: definition.numericBackToAlphaLabel
        )
        return definition.replacingMode(ModeNames.numeric, with: classicNumeric)
    }

    /// Injects the text input target (typically a `DocumentProxyTarget`).
    func bindTextInputTarget(_ target: TextInputTarget) {
        textInputTarget = target
        rebuildPipeline()
    }

    /// Injects VC-specific action closures (globe key, dismiss).
    func bindViewControllerActions(
        advanceToNextInputMode: @escaping () -> Void,
        dismissKeyboard: @escaping () -> Void
    ) {
        onAdvanceToNextInputMode = advanceToNextInputMode
        onDismissKeyboard = dismissKeyboard
        rebuildPipeline()
    }

    /// Standard chain: primary → ghost (numeric fallback).
    /// Return-swipe chain: returnSwipe → primary → ghost.
    func rebuildResolverChain() {
        guard let definition = currentDefinition else {
            resolverChain = nil
            returnSwipeResolverChain = nil
            return
        }
        var baseResolvers: [GestureResolver] = [PrimaryResolver()]
        if let numericMode = definition.mode(ModeNames.numeric) {
            baseResolvers.append(GhostKeyResolver(fallbackMode: numericMode))
        }
        resolverChain = GestureResolverChain(resolvers: baseResolvers)
        returnSwipeResolverChain = GestureResolverChain(
            resolvers: [ReturnSwipeResolver()] + baseResolvers
        )
    }

    /// Assembles the full action pipeline with all middlewares.
    func rebuildPipeline() {
        guard let definition = currentDefinition else {
            pipeline = nil
            return
        }
        var middlewares: [ActionMiddleware] = []

        // 1. Haptic feedback
        middlewares.append(HapticMiddleware(trigger: { [weak self] _ in
            self?.triggerHapticTap()
        }))

        // 2. Compose + Cycle Accents
        middlewares.append(ComposeMiddleware(
            compose: { previous, trigger in
                ComposeEngine.compose(previous: previous, trigger: trigger)
            },
            cycleAccent: { character in
                ComposeEngine.cycleAccent(for: character)
            },
            previousCharacter: { [weak self] in
                self?.textInputTarget?.documentContextBeforeInput?.last.map(String.init) ?? ""
            },
            deletePreviousCharacter: { [weak self] in
                self?.textInputTarget?.deleteBackward()
            }
        ))

        // 3. Telex (only active for Telex languages)
        let inputMethod = definition.settings.inputMethod
        middlewares.append(TelexMiddleware(
            isActive: { inputMethod == .telex },
            documentContextBefore: { [weak self] in
                self?.textInputTarget?.documentContextBeforeInput
            },
            deleteBackward: { [weak self] in
                self?.textInputTarget?.deleteBackward()
            },
            composeDigraph: { prev2, prev1, trigger in
                ComposeEngine.composeTelexDigraph(prev2: prev2, prev1: prev1, trigger: trigger)
            },
            composeSingle: { previous, trigger in
                ComposeEngine.composeTelex(previous: previous, trigger: trigger)
            }
        ))

        // 4. Advanced text (delete-forward, capitalize, clipboard)
        middlewares.append(AdvancedTextMiddleware(
            target: { [weak self] in self?.textInputTarget },
            locale: { [weak self] in self?.pipelineLocale ?? Locale.current }
        ))

        // 5. Basic text input (commitText, deleteBackward, space, newline, moveCursor)
        middlewares.append(TextInputMiddleware(
            target: { [weak self] in self?.textInputTarget }
        ))

        // 6. View controller actions (globe, dismiss)
        middlewares.append(ViewControllerActionMiddleware(
            onAdvanceToNextInputMode: { [weak self] in self?.onAdvanceToNextInputMode?() },
            onDismissKeyboard: { [weak self] in self?.onDismissKeyboard?() }
        ))

        // 7. Auto-capitalization
        middlewares.append(AutoCapitalizationMiddleware(
            evaluate: { [weak self] in
                guard let self,
                      sharedDefaults.bool(forKey: SettingsKey.autoCapitalizeEnabled.rawValue)
                else { return nil }
                return AutoCapitalization.shouldCapitalize(
                    context: textInputTarget?.documentContextBeforeInput
                )
            },
            onCapitalize: { [weak self] in
                self?.switchToMode(ModeNames.shifted)
            },
            onReleaseCapitalize: { [weak self] in
                guard let self else { return }
                if activeModeName == ModeNames.shifted {
                    switchToMode(ModeNames.main)
                }
            }
        ))

        // 8. Mode transitions (auto-transitions from key category)
        middlewares.append(ModeTransitionMiddleware(
            definition: definition,
            onModeChange: { [weak self] newMode in
                self?.switchToMode(newMode)
            }
        ))

        pipeline = ActionPipeline(middlewares: middlewares)
    }

    // MARK: - Gesture Dispatch

    /// Central entry point for the data-driven gesture path.
    func handleGesture(_ gesture: GestureType, keyId: String, isReturn: Bool) {
        guard let mode = activeModeFromDefinition else { return }

        // Circular gestures: try requested direction, fall back to opposite.
        if gesture == .circularClockwise || gesture == .circularCounterclockwise {
            handleCircular(keyId: keyId, in: mode, gesture: gesture)
            return
        }

        let chain = isReturn ? returnSwipeResolverChain : resolverChain
        guard let binding = chain?.resolve(keyId: keyId, gesture: gesture, in: mode) else { return }

        if case let .switchMode(targetMode) = binding.action {
            handleSwitchMode(targetMode)
            return
        }

        let context = ActionContext(
            action: binding.action,
            binding: binding,
            mode: activeModeName
        )
        pipeline?.process(context)
    }

    /// Handles a circular gesture. Checks for an explicit binding first
    /// (e.g. superscripts on the numeric layer), then falls back to
    /// inserting the uppercase center character, then tries the opposite
    /// direction's binding.
    private func handleCircular(keyId: String, in mode: KeyboardMode, gesture: GestureType) {
        guard let key = mode.key(for: keyId) else { return }
        let opposite: GestureType = gesture == .circularClockwise
            ? .circularCounterclockwise : .circularClockwise

        // 1. Explicit binding for this direction
        if let binding = key.bindings[gesture] {
            dispatchBinding(binding)
            return
        }
        // 2. Uppercase of center character (letter keys)
        if tryCircularUppercase(key: key) { return }
        // 3. Fallback to opposite direction's binding
        if let binding = key.bindings[opposite] {
            dispatchBinding(binding)
        }
    }

    /// Tries to insert the uppercase center character.
    @discardableResult
    private func tryCircularUppercase(key: KeyConfig) -> Bool {
        guard let tapBinding = key.bindings[.tap],
              case let .commitText(text) = tapBinding.action,
              text.first?.isLetter == true
        else { return false }
        let locale = pipelineLocale ?? Locale.current
        let uppercased = text.uppercased(with: locale)
        dispatchAction(.commitText(uppercased))
        return true
    }

    /// Handles `.switchMode` actions.
    func handleSwitchMode(_ targetMode: String) {
        switchToMode(targetMode)
    }

    /// Switches to a named mode, updating published state.
    func switchToMode(_ modeName: String) {
        guard modeName != activeModeName,
              let definition = currentDefinition,
              definition.mode(modeName) != nil
        else { return }
        activeModeName = modeName
        currentMode = definition.mode(modeName)
    }

    // MARK: - Slide Gesture Handling

    /// Handles slide events from keys with `slideType != .none`.
    func handleSlide(_ key: KeyConfig, phase: SlidePhase) {
        switch key.slideType {
        case .moveCursor:
            handleSpaceSlide(phase: phase, key: key)
        case .delete:
            handleDeleteSlide(phase: phase, key: key)
        case .none:
            break
        }
    }

    /// Cursor-movement style for the space-bar drag. Read per gesture (stable
    /// for the duration of a drag); defaults to `.continuous`.
    var cursorMovementStyle: CursorMovementStyle {
        let raw = sharedDefaults.string(forKey: SettingsKey.cursorMovementStyle.rawValue)
        return raw.flatMap(CursorMovementStyle.init(rawValue:)) ?? .continuous
    }

    func handleSpaceSlide(phase: SlidePhase, key: KeyConfig) {
        switch phase {
        case .began:
            isSpaceDragging = true
            spaceDragResidual = 0
            spaceDragPeak = 0
            // Snapshot the style once so a mid-drag settings change can't switch
            // this gesture between discrete and continuous classification.
            spaceDragCursorStyle = cursorMovementStyle
        case let .changed(deltaX):
            guard isSpaceDragging, deltaX != 0 else { return }
            spaceDragResidual += deltaX
            if spaceDragCursorStyle == .discrete {
                // Track the peak; movement is deferred to `.ended` so the whole
                // swipe counts as a single discrete step.
                if abs(spaceDragResidual) > abs(spaceDragPeak) {
                    spaceDragPeak = spaceDragResidual
                }
            } else {
                stepContinuousCursor()
            }
        case .ended:
            if spaceDragCursorStyle == .discrete {
                finishDiscreteSpaceSlide()
            }
            isSpaceDragging = false
            spaceDragResidual = 0
            spaceDragPeak = 0
        case .tap:
            handleGesture(.tap, keyId: key.id, isReturn: false)
        }
    }

    /// Continuous (joystick) mode: emit one character move per `dragStep` of
    /// accumulated travel.
    private func stepContinuousCursor() {
        while spaceDragResidual <= -KeyboardConstants.SpaceGestures.dragStep {
            dispatchAction(.moveCursor(offset: -1))
            feedbackDrag()
            spaceDragResidual += KeyboardConstants.SpaceGestures.dragStep
        }
        while spaceDragResidual >= KeyboardConstants.SpaceGestures.dragStep {
            dispatchAction(.moveCursor(offset: 1))
            feedbackDrag()
            spaceDragResidual -= KeyboardConstants.SpaceGestures.dragStep
        }
    }

    /// Discrete (MessagEase) mode: classify the completed swipe.
    /// A regular swipe moves one character; a return swipe (finger returns
    /// toward the origin) moves one whole word in the swipe's direction.
    private func finishDiscreteSpaceSlide() {
        let peak = spaceDragPeak
        let finalX = spaceDragResidual
        // Ignore taps / tiny jitters that never travelled a full step.
        guard abs(peak) >= KeyboardConstants.SpaceGestures.dragStep else { return }

        let direction = peak < 0 ? -1 : 1
        let ratio = abs(finalX) / abs(peak)
        if ratio < KeyboardConstants.SpaceGestures.returnSwipeThreshold {
            moveCursorByWord(direction: direction)
        } else {
            dispatchAction(.moveCursor(offset: direction))
        }
        feedbackDrag()
    }

    /// Moves the cursor by one word in `direction` (+1 forward, -1 backward)
    /// by computing the character offset to the nearest word boundary from the
    /// surrounding document context.
    private func moveCursorByWord(direction: Int) {
        let offset: Int = direction > 0
            ? Self.forwardWordOffset(in: textInputTarget?.documentContextAfterInput ?? "")
            : -Self.backwardWordOffset(in: textInputTarget?.documentContextBeforeInput ?? "")
        guard offset != 0 else { return }
        dispatchAction(.moveCursor(offset: offset))
    }

    /// Characters from the cursor to the end of the next word: skip leading
    /// whitespace, then the word itself.
    static func forwardWordOffset(in text: String) -> Int {
        var count = 0
        var seenWord = false
        for char in text {
            if char.isWhitespace {
                if seenWord { break }
            } else {
                seenWord = true
            }
            count += 1
        }
        return count
    }

    /// Characters from the cursor back to the start of the previous word: skip
    /// trailing whitespace, then the word itself.
    static func backwardWordOffset(in text: String) -> Int {
        var count = 0
        var seenWord = false
        for char in text.reversed() {
            if char.isWhitespace {
                if seenWord { break }
            } else {
                seenWord = true
            }
            count += 1
        }
        return count
    }

    func handleDeleteSlide(phase: SlidePhase, key: KeyConfig) {
        switch phase {
        case .began:
            isDeleteDragging = true
            deleteDragResidual = 0
        case let .changed(deltaX):
            guard isDeleteDragging, deltaX != 0 else { return }
            deleteDragResidual += deltaX
            while deleteDragResidual <= -KeyboardConstants.SpaceGestures.dragStep {
                dispatchAction(.deleteBackward)
                feedbackDrag()
                deleteDragResidual += KeyboardConstants.SpaceGestures.dragStep
            }
            while deleteDragResidual >= KeyboardConstants.SpaceGestures.dragStep {
                dispatchAction(.deleteForward)
                feedbackDrag()
                deleteDragResidual -= KeyboardConstants.SpaceGestures.dragStep
            }
        case .ended:
            isDeleteDragging = false
            deleteDragResidual = 0
        case .tap:
            handleGesture(.tap, keyId: key.id, isReturn: false)
        }
    }

    /// Dispatches a raw action through the pipeline (no binding context).
    func dispatchAction(_ action: KeyAction) {
        let context = ActionContext(action: action, binding: nil, mode: activeModeName)
        pipeline?.process(context)
    }

    /// Dispatches a binding through the pipeline, preserving its category context.
    private func dispatchBinding(_ binding: KeyBinding) {
        let context = ActionContext(action: binding.action, binding: binding, mode: activeModeName)
        pipeline?.process(context)
    }
}
