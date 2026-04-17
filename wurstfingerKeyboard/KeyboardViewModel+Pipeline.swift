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
        guard let definition = KeyboardRegistry.load(id: id) else { return }
        currentDefinition = definition
        activeModeName = definition.defaultMode
        pipelineLocale = definition.locale
        currentMode = definition.mode(activeModeName)
        rebuildResolverChain()
        rebuildPipeline()
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
            dispatchAction(binding.action)
            return
        }
        // 2. Uppercase of center character (letter keys)
        if tryCircularUppercase(key: key) { return }
        // 3. Fallback to opposite direction's binding
        if let binding = key.bindings[opposite] {
            dispatchAction(binding.action)
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

    func handleSpaceSlide(phase: SlidePhase, key: KeyConfig) {
        switch phase {
        case .began:
            isSpaceDragging = true
            spaceDragResidual = 0
        case let .changed(deltaX):
            guard isSpaceDragging, deltaX != 0 else { return }
            spaceDragResidual += deltaX
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
        case .ended:
            isSpaceDragging = false
            spaceDragResidual = 0
        case .tap:
            handleGesture(.tap, keyId: key.id, isReturn: false)
        }
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

    /// Dispatches a raw action through the pipeline.
    func dispatchAction(_ action: KeyAction) {
        let context = ActionContext(action: action, binding: nil, mode: activeModeName)
        pipeline?.process(context)
    }
}
