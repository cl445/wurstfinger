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

        // 2. Compose
        middlewares.append(ComposeMiddleware(
            compose: { previous, trigger in
                ComposeEngine.compose(previous: previous, trigger: trigger)
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

        let chain = isReturn ? returnSwipeResolverChain : resolverChain
        guard let binding = chain?.resolve(keyId: keyId, gesture: gesture, in: mode) else { return }

        if case let .switchMode(targetMode) = binding.action {
            handleSwitchMode(targetMode)
            return
        }

        lastSwitchModeTime = nil
        lastSwitchModeTarget = nil

        let context = ActionContext(
            action: binding.action,
            binding: binding,
            mode: activeModeName
        )
        pipeline?.process(context)
    }

    /// Handles `.switchMode` actions with double-tap → capsLock detection.
    func handleSwitchMode(_ targetMode: String) {
        let now = Date()
        let doubleTapInterval: TimeInterval = 0.4

        if let lastTime = lastSwitchModeTime,
           let lastTarget = lastSwitchModeTarget,
           lastTarget == targetMode,
           now.timeIntervalSince(lastTime) < doubleTapInterval {
            if let dtMode = currentDefinition?.mode(targetMode)?.doubleTapMode {
                switchToMode(dtMode)
                lastSwitchModeTime = nil
                lastSwitchModeTarget = nil
                return
            }
        }

        lastSwitchModeTime = now
        lastSwitchModeTarget = targetMode
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
