//
//  KeyboardViewController.swift
//  Wurstfinger
//
//  Created by Claas Flint on 24.10.25.
//

import Foundation
import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<DataDrivenKeyboardRootView>?
    private lazy var viewModel = KeyboardViewModel()
    private var heightConstraint: NSLayoutConstraint?
    private var documentProxyTarget: DocumentProxyTarget?
    private var hostLifecycleObservers: [NSObjectProtocol] = []
    /// Render-server snapshot standing in for the torn-down hosting view
    /// while the host app is backgrounded (see `installSuspensionPlaceholder`).
    private var suspensionPlaceholder: UIView?
    /// System-keyboard backdrop behind the SwiftUI content
    /// (see `installBackdropIfNeeded`). Outlives hosting teardowns.
    private var backdropView: UIInputView?

    /// The language selected in the host app, normalised to an id that is
    /// guaranteed to exist in the registry (falling back to the system language,
    /// then English). Determines which definition is loaded.
    private var selectedLanguageId: String {
        LanguageSettings.resolvedLanguageId(
            SharedDefaults.store.string(forKey: SettingsKey.selectedLanguageId.rawValue)
        )
    }

    /// Reports the active keyboard language to iOS (shown in Settings > Keyboards).
    /// Reads directly from SharedDefaults to pick up language changes made in the host app,
    /// since the LanguageSettings singleton may hold a stale value from its init.
    override var primaryLanguage: String? {
        get {
            // Resolve the locale from lightweight registry metadata only. iOS may
            // query this eagerly/repeatedly, so it must never build a layout.
            let id = selectedLanguageId
            return (KeyboardRegistry.available.first { $0.id == id }?.localeIdentifier)
                ?? LanguageConfig.english.locale.identifier
        }
        set {
            super.primaryLanguage = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardHealthLog.shared.record("viewDidLoad.start")

        // Set background immediately to avoid flash
        view.backgroundColor = .clear

        // Migrate the legacy style selection to the theme assignment before
        // the root view reads it. Idempotent; the host app runs it too.
        ThemeStore.migrateIfNeeded()

        // Wire up the data-driven pipeline
        let target = DocumentProxyTarget(controller: self)
        documentProxyTarget = target
        viewModel.bindTextInputTarget(target)
        viewModel.bindViewControllerActions(
            advanceToNextInputMode: { [weak self] in self?.advanceToNextInputMode() },
            dismissKeyboard: { [weak self] in self?.dismissKeyboard() }
        )

        // Honor a pinned startup language on cold start so the keyboard always
        // opens with it. In-keyboard cycling afterwards updates the selection
        // normally (subsequent reloads follow selectedLanguageId, not the pin).
        LanguageSettings(userDefaults: SharedDefaults.store).applyStartupLanguage()

        // Load the keyboard definition for the selected language
        loadDefinitionIfNeeded()

        // Configure hosting synchronously so the SwiftUI view exists
        // before viewWillAppear sets the height constraint. Deferring via
        // DispatchQueue.main.async caused a race in WebView-based apps where
        // viewWillAppear ran before configureHosting, leaving the extension
        // with a height constraint but no content.
        configureHosting()
        observeHostLifecycle()
        KeyboardHealthLog.shared.record("viewDidLoad.end")
    }

    deinit {
        hostLifecycleObservers.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Heartbeat: one entry per keyboard appearance. Its absence at the time
        // of a "system keyboard showed instead" incident proves iOS never
        // launched the extension (as opposed to the extension failing).
        KeyboardHealthLog.shared.record("viewWillAppear")
        // Reopen in the default (letters) mode: a keyboard dismissed in
        // numeric or shifted mode must not resurface there.
        refreshForAppearance(resettingMode: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Pairs with the `viewWillAppear` entry: the timestamp delta bounds
        // what an appearance actually costs. The suspension teardown makes
        // every re-appearance rebuild the hosting graph, so a latency
        // regression in that rebuild shows up in the health log on-device,
        // without a Mac attached.
        KeyboardHealthLog.shared.record("viewDidAppear")
    }

    /// The complete refresh an appearance owes the keyboard, in the order the
    /// steps depend on each other: shared state first (it can swap the whole
    /// definition), then the mode, then the height — `layoutMetrics` reads
    /// the *active* mode's arrangement — then the shift state.
    ///
    /// Both paths that resurface a keyboard — `viewWillAppear` and the
    /// host-foreground return — go through here, so neither can drift out of
    /// sync with the other and resurface on stale state. `resettingMode` is
    /// the single deliberate difference: an appearance reopens on letters, a
    /// foreground return keeps the mode because the user comes back to the
    /// same field mid-typing.
    private func refreshForAppearance(resettingMode: Bool) {
        refreshFromSharedState()
        // Rebuild the SwiftUI host if it was torn down before suspension (see
        // `shedMemoryBeforeSuspension`). Idempotent, so the first appearance —
        // where `viewDidLoad` already built it — is a no-op. Rebuild before the
        // height constraint update below so the content exists first.
        configureHosting()
        if resettingMode {
            viewModel.resetToDefaultMode()
        }
        updateKeyboardHeight()
        // Engage/release shift for the field's current context (e.g. start
        // uppercase in an empty compose field). `textDidChange` usually also
        // fires on appearance, but that is not guaranteed in every host app;
        // the refresh is idempotent, so evaluating in both paths is safe.
        viewModel.refreshAutoCapitalization()
    }

    /// Picks up state that may have changed outside this process while the
    /// keyboard was off screen: settings edited in the host app, a language
    /// or numpad-style switch, granted/revoked Full Access. Cross-process
    /// defaults writes fire no in-process `didChangeNotification` (see the
    /// observer note in `KeyboardViewModel.init`), so this explicit reload is
    /// the only way they reach the view model.
    private func refreshFromSharedState() {
        // Persist Full Access status so the host app can show/hide haptic
        // settings. Write only on change: every shared-defaults write fires the
        // in-process didChangeNotification observer, which would run a second,
        // redundant reloadSettings on every appearance.
        let fullAccessKey = SettingsKey.keyboardFullAccess.rawValue
        if SharedDefaults.store.bool(forKey: fullAccessKey) != hasFullAccess {
            SharedDefaults.store.set(hasFullAccess, forKey: fullAccessKey)
        }
        viewModel.reloadSettings()
        // Reload definition only if language (or numpad style) changed while the
        // keyboard was backgrounded — avoids rebuilding the pipeline every time.
        loadDefinitionIfNeeded()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Fires when the host text or caret position changes outside our own
        // key actions (field switch, caret relocation, external edits) — and
        // on keyboard appearance. Re-evaluate so stale shift state is
        // corrected (e.g. caret moved from a sentence start into a word).
        viewModel.refreshAutoCapitalization()
    }

    /// Loads the keyboard definition only when the inputs that determine it
    /// (selected language, numpad style) have changed since the last load.
    private func loadDefinitionIfNeeded() {
        // Resolve via the shared helper so a stale/invalid persisted id falls
        // back the same way `primaryLanguage` does (system language, then
        // English) instead of leaving loadDefinition a no-op.
        let languageId = selectedLanguageId
        let numpadType = SharedDefaults.store.string(
            forKey: SettingsKey.numpadStyle.rawValue
        )
        let signature = KeyboardViewModel.definitionSignature(
            languageId: languageId,
            numpadType: numpadType
        )
        // Compare against the view model's record of what it actually loaded —
        // a controller-side cache desyncs when the user cycles languages via
        // the globe key (the view model loads directly), forcing a needless
        // pipeline rebuild (two resolver chains + the full middleware stack)
        // on the next appearance.
        guard signature != viewModel.loadedDefinitionSignature else { return }
        viewModel.loadDefinition(for: languageId)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        shedMemoryBeforeSuspension("viewDidDisappear")
    }

    /// Sheds weight before the process gets suspended: iOS enforces the
    /// per-process memory limit again when a suspended keyboard extension is
    /// resumed by the next host, and a keyboard that suspended large is killed
    /// on resume (`jetsam per-process-limit`, with a silent fallback to the
    /// system keyboard). Suspending small is what makes the next resume
    /// survive; a memory warning never fires on suspension, so this cannot
    /// wait for `didReceiveMemoryWarning`.
    ///
    /// The definition caches account for only a few MB of a suspended
    /// keyboard's footprint — the bulk of it is the *SwiftUI hosting graph*,
    /// not any app data structure — so the hosting controller is torn down
    /// here too and rebuilt in `viewWillAppear`. The shedding runs inside an
    /// autorelease pool so UIKit's teardown temporaries are gone before the
    /// health-log entry samples `phys_footprint`; the sample is still an upper
    /// bound on what survives to suspension, since the allocator need not have
    /// returned every freed page to the kernel by then — which is why the
    /// guaranteed entry is paired with a deferred second one below.
    private func shedMemoryBeforeSuspension(_ event: String) {
        autoreleasepool {
            KeyboardRegistry.evictAll(except: selectedLanguageId)
            // The memoized grid layouts hold arrangement storage shared with the
            // definitions just evicted, so dropping them is part of the same
            // shedding step. The next appearance re-solves in microseconds.
            GridLayoutSolver.evictAll()
            installSuspensionPlaceholder()
            teardownHosting()
        }
        // Flushed, not queued: the suspended process may never run again — a
        // resume-jetsam kills it on wake before an async write would get CPU
        // time — and this entry is the closest guaranteed record of the
        // footprint that survives to suspension. Unlike launch, this path is
        // not latency-critical.
        KeyboardHealthLog.shared.recordAndFlush(event)
        // The guaranteed entry is measurably too pessimistic, though: reclaim
        // of the torn-down hosting graph only completes 1–2 s after
        // `teardownHosting()`, so it read 1.3–3.3 MB (2.8–7.3 %) above the
        // externally sampled floor in every measured dismissal — exactly the
        // direction that misleads a resume-jetsam post-mortem into
        // over-crediting headroom near the per-process limit. Hence a second,
        // late sample of the same event. It is best effort by construction:
        // queued and never awaited, so it cannot delay suspension, and
        // captured on the shared log alone, so the graph just released stays
        // released.
        //
        // Best effort is not the same as harmless, though: a frozen process
        // does not drop the pending block — libdispatch runs an overdue timer
        // as soon as the process is scheduled again, which for a reused
        // extension can be a host cycle later, against a keyboard rebuilt in
        // the meantime. Two guards keep the label honest: the item is
        // cancelled once a hosting graph exists again (`configureHosting`),
        // and `recordDeferred` discards a sample that starts more than its own
        // delay late. A second shed supersedes a still-pending one here for
        // the same reason — the token holds one item, and one it no longer
        // points to is one nothing can cancel. Either way the pessimistic
        // entry above stands, and the next launch's `viewDidLoad.start`
        // remains the fallback truth — the one sample a frozen process cannot
        // miss.
        Self.pendingSettledSample?.cancel()
        Self.pendingSettledSample = KeyboardHealthLog.shared.recordDeferred(
            "postShedSettled",
            after: Self.postShedSettleDelay
        )
    }

    /// How long the deferred post-shedding sample waits before reading the
    /// footprint again: long enough to be past the measured 1–2 s reclaim of
    /// the hosting graph, short enough to stay inside the window in which a
    /// just-backgrounded extension still gets CPU (measured: it lands).
    private static let postShedSettleDelay: TimeInterval = 2

    /// The post-shedding sample still waiting to fire, if any.
    ///
    /// Static, not per instance: a host foreground return builds a *new*
    /// controller in the same extension process (see `observeHostLifecycle`),
    /// so the instance that queued the sample is usually gone by the time the
    /// keyboard that invalidates it is rebuilt. The token has to outlive it to
    /// be reachable from there at all. Only ever touched from the shedding and
    /// hosting paths, both of which are main-thread-only.
    private static var pendingSettledSample: DispatchWorkItem?

    /// Covers the hole the hosting teardown would leave in the host app's
    /// app-switcher card: iOS takes that snapshot *after* the host
    /// backgrounds, i.e. after `shedMemoryBeforeSuspension` ran. A
    /// `snapshotView` references the already-rendered surface owned by the
    /// render server, so it keeps the keyboard visible in the card without
    /// meaningfully adding to the suspended process's footprint. Skipped when
    /// the view is not in a window (keyboard dismissed): nothing is on screen
    /// to preserve. Removed when `configureHosting` rebuilds the live view.
    private func installSuspensionPlaceholder() {
        guard suspensionPlaceholder == nil,
              let hostingView = hostingController?.view,
              hostingView.window != nil,
              let snapshot = hostingView.snapshotView(afterScreenUpdates: false)
        else { return }
        snapshot.frame = view.bounds
        snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // The stand-in covers the whole keyboard with nothing live behind it,
        // and it stays up until the rebuild — which the foreground handler
        // skips for an off-screen keyboard, so possibly until the next
        // appearance. A frozen image must never swallow a touch or reach
        // VoiceOver, whatever it happens to outlive.
        snapshot.isUserInteractionEnabled = false
        snapshot.accessibilityElementsHidden = true
        view.addSubview(snapshot)
        suspensionPlaceholder = snapshot
    }

    /// Removes the SwiftUI hosting controller and releases its view graph.
    /// The view model (and thus all keyboard state) is retained by `self`, so
    /// a rebuild in `viewWillAppear` restores the same keyboard without
    /// reloading the definition. No-op if hosting is already gone.
    private func teardownHosting() {
        guard let controller = hostingController else { return }
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        hostingController = nil
    }

    /// Covers the case where the host app itself backgrounds while the
    /// keyboard is on screen (home gesture, app switch, tapping a Spotlight
    /// result): the view is expected to stay in the hierarchy, so
    /// `viewDidDisappear` would never fire and only these notifications would
    /// announce the coming suspension — the pre-suspension shedding has to
    /// hook them too. The foreground record documents survived resumes in the
    /// health log.
    ///
    /// Measured on the iOS 26 *simulator*, the opposite happens, and the
    /// observers are kept anyway. In 3/3 host-background cycles with the
    /// keyboard up, iOS delivered `viewDidDisappear` and no `NSExtensionHost*`
    /// notification at all (zero entries in the health log and in the unified
    /// log, while every view-lifecycle event appeared in both), and every
    /// foreground return rebuilt the entire controller — `viewDidLoad` →
    /// `viewWillAppear` → `viewDidAppear`, a new instance in the same
    /// extension process. Three consequences worth knowing before reading a
    /// log or changing this code:
    ///
    /// - Shedding is covered either way; there the `viewDidDisappear` path
    ///   does it, so nothing leaks by these blocks not running.
    /// - The one deliberate difference of the foreground path — keeping the
    ///   active mode (`resettingMode: false`) because the user comes back to
    ///   the same field mid-typing — never takes effect there: the rebuild
    ///   goes through `viewWillAppear` and reopens on the default mode.
    /// - No `hostDidEnterBackground`/`hostWillEnterForeground` entry appeared
    ///   in any measured simulator cycle, so their absence from a simulator
    ///   log is the expected reading and proves nothing about this code. The
    ///   same absence on a device would be evidence — see below.
    ///
    /// Whether a physical device delivers the notifications, and whether the
    /// keep-the-mode path therefore engages at all, is unverified (open
    /// on-device item from #277) — which is precisely why these observers stay
    /// until someone has measured it on real hardware.
    private func observeHostLifecycle() {
        let center = NotificationCenter.default
        hostLifecycleObservers.append(center.addObserver(
            forName: NSNotification.Name.NSExtensionHostDidEnterBackground,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.shedMemoryBeforeSuspension("hostDidEnterBackground")
        })
        hostLifecycleObservers.append(center.addObserver(
            forName: NSNotification.Name.NSExtensionHostWillEnterForeground,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // Foreground return after a host-background suspension does not
            // fire `viewWillAppear` (the view stayed in the hierarchy), so
            // everything appearance normally refreshes must happen here too:
            // the hosting graph torn down in `shedMemoryBeforeSuspension` —
            // otherwise the keyboard returns blank — and any settings or
            // language change made in the host app while this process was
            // suspended, which no in-process defaults notification reports.
            // Gated on being on screen: waking without a window (keyboard
            // dismissed before the host backgrounded) must not pay the
            // hosting rebuild — the biggest allocation — in the resume
            // moment, where the jetsam limit is enforced; `viewWillAppear`
            // covers that case when the keyboard is next shown. The active
            // mode is deliberately kept: the user returns to the same field
            // mid-typing. (A definition reload inside the refresh still
            // resets it — a new language's layout cannot keep the old mode.)
            if viewIfLoaded?.window != nil {
                refreshForAppearance(resettingMode: false)
            }
            KeyboardHealthLog.shared.record("hostWillEnterForeground")
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        KeyboardHealthLog.shared.record("didReceiveMemoryWarning")
        // Free cached layouts for languages other than the active one. The
        // active definition stays resident (the view model holds a strong
        // reference) and remains cached for fast reuse.
        KeyboardRegistry.evictAll(except: selectedLanguageId)
        // Same for the memoized grid layouts: they pin the arrangement storage
        // of the definitions evicted above and cost microseconds to rebuild,
        // including the active one on the next render.
        GridLayoutSolver.evictAll()
    }

    private func updateKeyboardHeight() {
        // Constraint height ≡ content height by construction: the metrics
        // are the same source the SwiftUI grid renders from, so the fixed
        // paddings/spacing are never scaled by the constraint while the
        // content keeps them constant.
        let finalHeight = viewModel.layoutMetrics.totalHeight

        if let constraint = heightConstraint {
            if constraint.constant != finalHeight {
                constraint.constant = finalHeight
            }
        } else {
            let constraint = view.heightAnchor.constraint(equalToConstant: finalHeight)
            constraint.priority = .defaultHigh
            constraint.isActive = true
            heightConstraint = constraint
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        view.backgroundColor = .clear
        // Update viewModel with current width so SwiftUI re-renders after
        // orientation changes that happen while the keyboard is backgrounded.
        viewModel.updateViewWidth(view.bounds.width)
        // Window (not screen) bounds keep sizing correct in Split View and
        // Stage Manager; UIApplication.shared is unavailable in extensions,
        // so the window is reached through the view hierarchy.
        viewModel.updateWindowBounds(view.window?.bounds)
        // The resolved metrics depend on the container width and the
        // current-orientation screen height (fit-clamps), so the height
        // constraint must follow layout passes, not just viewWillAppear —
        // rotation with the keyboard open never calls viewWillAppear.
        // No-op when the height is unchanged.
        updateKeyboardHeight()
    }

    /// Builds the SwiftUI hosting controller and installs it as a child.
    /// Idempotent: a no-op if hosting already exists, so `viewWillAppear` can
    /// call it to rebuild after a suspension teardown without double-adding.
    ///
    /// The root view is hosted concretely (no `AnyView`) so SwiftUI keeps the
    /// view's structural identity and does not pay the type-erased
    /// AttributeGraph overhead — every byte matters under the extension's
    /// jetsam budget.
    private func configureHosting() {
        // A live hosting graph voids a pending post-shedding sample: it would
        // weigh the rebuilt keyboard under a label forensics reads as the
        // suspension floor. Cancelling an item that has not started keeps it
        // from ever running; the residual window — the rebuild landing while
        // the sample is already executing on the log's queue — is microseconds
        // wide and costs one over-reported diagnostics entry.
        Self.pendingSettledSample?.cancel()
        Self.pendingSettledSample = nil
        guard hostingController == nil else { return }
        installBackdropIfNeeded()

        let rootView = DataDrivenKeyboardRootView(viewModel: viewModel)
        let controller = UIHostingController(rootView: rootView)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear

        addChild(controller)
        view.addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        controller.didMove(toParent: self)
        hostingController = controller
        // The live view is back — drop the app-switcher stand-in. It was
        // added below the fresh hosting view (addSubview appends on top) and
        // both changes commit in the same CA transaction, so no blank frame
        // can slip in between.
        suspensionPlaceholder?.removeFromSuperview()
        suspensionPlaceholder = nil
    }

    /// Installs the system-keyboard backdrop behind the SwiftUI content.
    ///
    /// A `.keyboard`-style input view renders the real system-keyboard backdrop
    /// (blur + adaptive tint) behind the SwiftUI content, so a theme with a
    /// near-transparent board (Liquid Glass) shows through to a background that
    /// matches the system keyboard row. This is purely the *look*: touch
    /// delivery for the inter-key gaps comes from the SwiftUI board fill,
    /// because a keyboard extension delivers touches over SwiftUI-rendered
    /// pixels, not over this UIKit backdrop behind them (see
    /// `ResolvedTheme.boardBackground` /
    /// `KeyboardThemeDefinition.minimumBoardOpacity` + #198). It is left
    /// interactive only so it never swallows a stray touch itself; the SwiftUI
    /// content above always wins the hit-test.
    ///
    /// Installed once and kept across hosting teardowns: the suspension shedding
    /// releases only the SwiftUI view graph, so rebuilding hosting must not
    /// stack a second input view behind the keys on every resume.
    private func installBackdropIfNeeded() {
        guard backdropView == nil else { return }
        let backdrop = UIInputView(frame: .zero, inputViewStyle: .keyboard)
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        backdropView = backdrop
    }
}
