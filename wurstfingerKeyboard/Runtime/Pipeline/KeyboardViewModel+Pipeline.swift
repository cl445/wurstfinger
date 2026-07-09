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
        // Fall back to English if the requested language can't be resolved (e.g.
        // a stale stored id for a language removed in a later version) so the
        // keyboard always renders a layout instead of coming up blank.
        guard let base = KeyboardRegistry.load(id: id)
            ?? KeyboardRegistry.load(id: LanguageConfig.english.id)
        else { return }
        let definition = applyNumpadStyle(to: base)
        currentDefinition = definition
        // Record the signature of what was actually loaded (the id may differ
        // from the requested one after the English fallback) so the controller
        // can skip redundant rebuilds on the next appearance.
        loadedDefinitionSignature = Self.definitionSignature(
            languageId: definition.id,
            numpadStyle: sharedDefaults.string(forKey: SettingsKey.numpadStyle.rawValue)
        )
        activeModeName = definition.defaultMode
        pipelineLocale = definition.locale
        currentMode = definition.mode(activeModeName)
        rebuildResolverChain()
        rebuildPipeline()
    }

    /// Signature of the inputs that determine a loaded definition (language +
    /// numpad style). Pure so the desync-free comparison between the
    /// controller's desired inputs and the view model's loaded state can be
    /// unit-tested without a UIKit lifecycle.
    static func definitionSignature(languageId: String, numpadStyle: String?) -> String {
        "\(languageId)|\(numpadStyle ?? "")"
    }

    /// Swaps the numeric layer to the classic (7-8-9) ordering when the user
    /// selected it. The registry caches the phone-style definition, so this
    /// always derives from the canonical phone layout and never mutates the cache.
    private func applyNumpadStyle(to definition: KeyboardDefinition) -> KeyboardDefinition {
        let raw = sharedDefaults.string(forKey: SettingsKey.numpadStyle.rawValue)
        let style = raw.flatMap(NumpadStyle.init(rawValue:)) ?? .phone
        guard style == .classic else { return definition }
        let classicNumeric = NumericLayouts.classic(
            digits: definition.numericDigits,
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

        // 1. Haptic feedback — confirmation ticks for state-changing actions
        //    only. The per-keystroke tap haptic fires once at touch-down in
        //    the view layer (`feedbackTap`) and slide steps trigger their own
        //    drag haptic, so text actions MUST stay silent here: a per-action
        //    haptic buzzed every key press and slide step a second time.
        middlewares.append(HapticMiddleware(trigger: { [weak self] action in
            self?.triggerHaptic(for: action)
        }))

        // 2. Compose + Cycle Accents — per-definition engine so language-specific
        // compose rule overrides are honored (rebuilt on every definition load).
        let composeEngine = definition.settings.composeRuleOverrides
            .map { ComposeEngine.withGlobalRules(overrides: $0) } ?? .shared
        middlewares.append(ComposeMiddleware(
            compose: { previous, trigger in
                composeEngine.compose(previous: previous, trigger: trigger)
            },
            cycleAccent: { character in
                composeEngine.cycleAccent(for: character)
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

        // 4. Advanced text (delete-forward, capitalize, clipboard). The
        //    clipboard confirmation tick fires from the middleware's success
        //    paths (not upfront in the haptic middleware) so guarded no-ops
        //    stay silent.
        middlewares.append(AdvancedTextMiddleware(
            target: { [weak self] in self?.textInputTarget },
            locale: { [weak self] in self?.pipelineLocale ?? Locale.current },
            onClipboardSuccess: { [weak self] in self?.feedbackStateChange() }
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
            evaluate: { [weak self] in self?.evaluateAutoCapitalization() },
            onCapitalize: { [weak self] in self?.engageAutoCapitalization() },
            onReleaseCapitalize: { [weak self] in
                // Mirror `refreshAutoCapitalization`: only an *auto-engaged*
                // shift may be released when the context stops calling for
                // capitalization. A manually tapped shift is one-shot and is
                // consumed exclusively by letters (via the shifted mode's
                // auto-transition) — never dropped by delete, symbols,
                // paste, or cut — matching iOS system shift behavior.
                guard let self, shiftEngagedByAutoCapitalization else { return }
                releaseAutoCapitalization()
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

    // MARK: - Auto-Capitalization

    /// Re-evaluates auto-capitalization outside the key-action pipeline.
    /// Called from `KeyboardViewController` when the host text changes
    /// (keyboard appearance, field switch, caret relocation) so the shift
    /// state matches the new context. Idempotent: `switchToMode` ignores
    /// same-mode switches, so overlapping calls (e.g. `viewWillAppear` and
    /// `textDidChange` both firing on appearance) are harmless.
    func refreshAutoCapitalization() {
        switch evaluateAutoCapitalization() {
        case .some(true):
            engageAutoCapitalization()
        case .some(false):
            // Outside the key pipeline only an *auto-engaged* shift may be
            // released — a manually tapped shift must survive textDidChange
            // firing for caret moves or field switches.
            if shiftEngagedByAutoCapitalization {
                releaseAutoCapitalization()
            }
        case .none:
            break
        }
    }

    /// Returns whether the next key should be capitalized, or `nil` when
    /// auto-capitalization is inactive — either the definition does not
    /// support it for this language or the user disabled it in settings.
    func evaluateAutoCapitalization() -> Bool? {
        guard currentDefinition?.settings.autoCapitalize == true,
              sharedDefaults.bool(forKey: SettingsKey.autoCapitalizeEnabled.rawValue)
        else { return nil }
        let context = textInputTarget?.documentContextBeforeInput
        // Sentence-opening punctuation (Spanish ¿/¡) capitalizes the letter
        // that immediately follows it, matching iOS system keyboards.
        if let last = context?.last,
           AutoCapitalization.shouldCapitalizeImmediately(after: String(last)) {
            return true
        }
        return AutoCapitalization.shouldCapitalize(context: context)
    }

    /// Engages the shifted layer for the next key. Only fires from `main`:
    /// caps lock must survive sentence enders, and the numeric/symbol
    /// layers must not be hijacked into the letter layers.
    func engageAutoCapitalization() {
        guard activeModeName == ModeNames.main else { return }
        switchToMode(ModeNames.shifted)
        shiftEngagedByAutoCapitalization = activeModeName == ModeNames.shifted
    }

    /// Releases a pending auto-shift. Only fires from `shifted` so caps
    /// lock and non-letter layers are never demoted.
    func releaseAutoCapitalization() {
        guard activeModeName == ModeNames.shifted else { return }
        switchToMode(ModeNames.main)
    }

    // MARK: - Gesture Dispatch

    /// Central entry point for the data-driven gesture path.
    ///
    /// Returns whether the gesture resolved to a binding and was dispatched.
    /// The long-press path uses this to decide whether the touch is consumed:
    /// a key without a long-press binding (e.g. return, globe) must keep its
    /// normal tap on release instead of being swallowed by the failed hold.
    @discardableResult
    func handleGesture(_ gesture: GestureType, keyId: String, isReturn: Bool) -> Bool {
        guard let mode = activeModeFromDefinition else { return false }

        // Circular gestures: try requested direction, fall back to opposite.
        if gesture == .circularClockwise || gesture == .circularCounterclockwise {
            handleCircular(keyId: keyId, in: mode, gesture: gesture)
            return true
        }

        let chain = isReturn ? returnSwipeResolverChain : resolverChain
        guard let binding = chain?.resolve(keyId: keyId, gesture: gesture, in: mode) else { return false }

        // Mode and language switches bypass the pipeline, so their
        // confirmation tick fires here instead of in the haptic middleware —
        // but only when the switch actually changed something (same-mode
        // taps and single-language globe swipes are silent no-ops).
        if case let .switchMode(targetMode) = binding.action {
            let previousMode = activeModeName
            handleSwitchMode(targetMode)
            if activeModeName != previousMode {
                feedbackStateChange()
            }
            return true
        }

        if case .switchToNextLanguage = binding.action {
            let previousLanguage = currentDefinition?.id
            switchToNextLanguage()
            if currentDefinition?.id != previousLanguage {
                feedbackStateChange()
            }
            return true
        }

        let context = ActionContext(
            action: binding.action,
            binding: binding,
            mode: activeModeName
        )
        pipeline?.process(context)
        return true
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
        // keyboardUppercased (not plain uppercased) keeps ß → ẞ as a single
        // character, matching the shifted-layer generation in the definition
        // layer — a layout with ß on a tap position must not expand to "SS".
        let uppercased = text.keyboardUppercased(with: locale)
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
        // Any mode change invalidates a pending auto-shift; the auto-cap
        // engage path re-sets the flag right after switching.
        shiftEngagedByAutoCapitalization = false
    }

    /// Resets the active mode to the definition's default. Called by the
    /// controller on appearance so a keyboard hidden on the numeric or
    /// shifted layer reopens on letters. No-op (and publish-free) when the
    /// default mode is already active.
    func resetToDefaultMode() {
        guard let definition = currentDefinition else { return }
        switchToMode(definition.defaultMode)
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
        case .cancelled:
            // System cancelled the touches mid-drag: discard the drag state
            // without committing a discrete move or a tap.
            isSpaceDragging = false
            spaceDragResidual = 0
            spaceDragPeak = 0
        case .tap:
            handleGesture(.tap, keyId: key.id, isReturn: false)
        case let .swipeUp(isReturn):
            // Only reported when the horizontal slide never activated, so
            // this cannot interfere with cursor movement in either style.
            toggleLabelVisibility(grouped: isReturn)
        }
    }

    /// MessagEase space-bar label toggles. A plain up-swipe flips the
    /// extra-symbol labels; a return-up swipe (`grouped`) toggles letter and
    /// standard-symbol labels together: only when both are hidden does it
    /// show them again, otherwise it hides both.
    private func toggleLabelVisibility(grouped: Bool) {
        if grouped {
            let hidden = sharedDefaults.bool(forKey: SettingsKey.hideLetters.rawValue)
                && sharedDefaults.bool(forKey: SettingsKey.hideStandardSymbols.rawValue)
            sharedDefaults.set(!hidden, forKey: SettingsKey.hideLetters.rawValue)
            sharedDefaults.set(!hidden, forKey: SettingsKey.hideStandardSymbols.rawValue)
        } else {
            let hidden = sharedDefaults.bool(forKey: SettingsKey.hideExtraSymbols.rawValue)
            sharedDefaults.set(!hidden, forKey: SettingsKey.hideExtraSymbols.rawValue)
        }
        // Confirmation tick, not a second tap impact: the touch-down already
        // fired the tap haptic, and the toggle is a state change like a
        // mode switch.
        feedbackStateChange()
    }

    /// Continuous (joystick) mode: emit one character move per `dragStep` of
    /// accumulated travel.
    private func stepContinuousCursor() {
        while spaceDragResidual <= -KeyboardConstants.SpaceGestures.dragStep {
            dispatchAction(.moveCursor(offset: singleGraphemeOffset(direction: -1)))
            feedbackDrag()
            spaceDragResidual += KeyboardConstants.SpaceGestures.dragStep
        }
        while spaceDragResidual >= KeyboardConstants.SpaceGestures.dragStep {
            dispatchAction(.moveCursor(offset: singleGraphemeOffset(direction: 1)))
            feedbackDrag()
            spaceDragResidual -= KeyboardConstants.SpaceGestures.dragStep
        }
    }

    /// UTF-16 offset that moves the cursor across exactly one grapheme cluster
    /// in `direction` (+1 forward, -1 backward).
    ///
    /// `adjustTextPosition(byCharacterOffset:)` moves by UTF-16 code units, so
    /// multi-unit clusters (emoji, surrogate pairs, ZWJ sequences) need their
    /// full UTF-16 width; otherwise the caret lands inside the cluster. Falls
    /// back to 1 when no document context is available.
    private func singleGraphemeOffset(direction: Int) -> Int {
        let cluster: Character? = direction > 0
            ? textInputTarget?.documentContextAfterInput?.first
            : textInputTarget?.documentContextBeforeInput?.last
        return direction * (cluster?.utf16.count ?? 1)
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
            dispatchAction(.moveCursor(offset: singleGraphemeOffset(direction: direction)))
        }
        feedbackDrag()
    }

    /// Moves the cursor by one word in `direction` (+1 forward, -1 backward)
    /// by computing the UTF-16 offset to the nearest word boundary from the
    /// surrounding document context.
    private func moveCursorByWord(direction: Int) {
        let offset: Int = direction > 0
            ? Self.forwardWordOffset(in: textInputTarget?.documentContextAfterInput ?? "")
            : -Self.backwardWordOffset(in: textInputTarget?.documentContextBeforeInput ?? "")
        guard offset != 0 else { return }
        dispatchAction(.moveCursor(offset: offset))
    }

    /// UTF-16 code units from the cursor to the end of the next word: skip
    /// leading whitespace, then the word itself. Iterates graphemes but sums
    /// their UTF-16 widths, matching `adjustTextPosition`'s unit.
    static func forwardWordOffset(in text: String) -> Int {
        var count = 0
        var seenWord = false
        for char in text {
            if char.isWhitespace {
                if seenWord { break }
            } else {
                seenWord = true
            }
            count += char.utf16.count
        }
        return count
    }

    /// UTF-16 code units from the cursor back to the start of the previous
    /// word: skip trailing whitespace, then the word itself. Iterates graphemes
    /// but sums their UTF-16 widths, matching `adjustTextPosition`'s unit.
    static func backwardWordOffset(in text: String) -> Int {
        var count = 0
        var seenWord = false
        for char in text.reversed() {
            if char.isWhitespace {
                if seenWord { break }
            } else {
                seenWord = true
            }
            count += char.utf16.count
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
            let step = KeyboardConstants.DeleteGestures.dragStep
            while deleteDragResidual <= -step {
                dispatchAction(.deleteBackward)
                feedbackDrag()
                deleteDragResidual += step
            }
            while deleteDragResidual >= step {
                dispatchAction(.deleteForward)
                feedbackDrag()
                deleteDragResidual -= step
            }
        case .ended, .cancelled:
            isDeleteDragging = false
            deleteDragResidual = 0
        case .tap:
            handleGesture(.tap, keyId: key.id, isReturn: false)
        case .swipeUp:
            // The delete key has no vertical gestures; label toggles are a
            // space-bar feature. Vertical flicks stay ignored.
            break
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
