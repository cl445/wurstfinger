# v1-Implementierungsplan: Lernende Touch-Offset-Korrektur

> Begleitdokument zu `touch-offset-correction.md` (Rev. 7). Setzt **nur v1** um. Abschnitts-
> verweise (§) zeigen auf die Spezifikation.

## Leitprinzipien

- **Default-aus & gegated** (§6.1): Das Feature ist hinter einem Toggle; es kann **inkrementell
  gemerged** werden, ohne Nutzer zu beeinflussen, bis es aktiviert wird.
- **Inside-out:** erst der reine, testbare Kern (Modell/Regime/Persistenz), dann Plumbing, dann
  Lernen, dann Anwendung, zuletzt UI.
- **Jede Phase ist grün-testbar und für sich mergebar.**
- **Worktree-Konvention:** alle Code-Änderungen in eigenem Worktree, Basis **`origin/develop`**.
- **Bestehende Tests bleiben grün** — besonders bei Eingriffen in Gesten-/Layout-Code.

## Worktree-Setup (Schritt 0)

```bash
# Basis aktualisieren und Worktree anlegen (Basis: origin/develop)
git fetch origin
git worktree add worktrees/touch-offset -b feature/touch-offset-correction origin/develop
```

Neues Verzeichnis für die Komponenten: `wurstfingerKeyboard/Runtime/TouchModel/`.
SwiftFormat/SwiftLint `--strict` lint-clean halten.

## Komponenten-Inventar

**Neu** (`wurstfingerKeyboard/Runtime/TouchModel/`):
| Datei | Inhalt | Spec |
|---|---|---|
| `TouchRegime.swift` | Regime-Typ + `derivePosture(scale, position)` + Orientierung | §3.1 |
| `ReachSurface.swift` | Ridge-WLS-Fit (bilinear/linear), Auswertung, Rang-Guard | §3.2, §4.2-S2 |
| `TouchOffsetModel.swift` | Per-Taste `{m_k,n_k,s_k}`, Update (Huber/Running-Mean/EW-MAD), Shrinkage+Clamp → Offset | §4.2 |
| `TouchOffsetStore.swift` | Codable-Schema, `SharedDefaults`-Persistenz, Versionierung, Reset, debounced write | §7 |
| `AcceptanceTracker.swift` | Ring-Puffer committeter Taps, Burst-Veto, Span-Alignment | §4.1 |
| `GestureTelemetryModel.swift` | Per-`(Regime,Klasse[,Richtung])` Welford-Stats + Korrektur-Zähler + Histogramme | §13 |
| `TouchLearningMiddleware.swift` | Pipeline-Sink: Acceptance + Offset-Sampling + Telemetrie | §5, §4.1, §13 |

**Geändert:**
| Datei | Änderung | Spec |
|---|---|---|
| `Runtime/Gesture/KeyGestureRecognizer.swift` | `startLocation` erfassen; Feature-Vektor mitliefern | §5, §13 |
| `Runtime/Gesture/GesturePreprocessor.swift` | Features in `GestureClassification` exponieren | §13 |
| `Runtime/View/KeyView.swift` | `onGesture`-Signatur (+ Touchdown) | §5 |
| `Runtime/View/KeyboardGridLayout.swift` | `cellFrames` offset-bewusst (Grenzverschiebung) | §5.4 |
| `Runtime/View/KeyboardGridView.swift` | asymmetrischer `visualInset`; Offsets injizieren | §5.5 |
| `Runtime/Pipeline/KeyboardViewModel+Pipeline.swift` | `handleGesture`-Signatur; Middleware verdrahten | §5 |
| `Settings/KeyboardSettings.swift` | `SettingsKey`: Toggle + Schema-Version | §6.1, §7 |
| Host-App (`wurstfinger/`) | Settings-Unterseite (Toggle, Viz, Debug) | §6 |

## Abhängigkeitsgraph

```
P1 Regime ─┐
P2 Modell ─┼─→ P5 Lern-Middleware ─→ P7 Resizing-Anwendung ─→ P8 UI ─→ P9 Validierung
P3 Persist ┘        ↑                        ↑
P4 Plumbing ────────┴────────────────────────┘
P6 Telemetrie ──────┘
```
P1–P3 (reiner Kern) sind unabhängig von P4 (Plumbing) → parallelisierbar. P5 braucht P2/P3/P4.
P7 braucht P2/P4. P6 braucht P4.

---

## Phasen

### P0 — Scaffolding (S)
Worktree, Verzeichnis, `SettingsKey.touchOffsetEnabled` + `touchModelSchemaVersion`, leere
Modul-Dateien mit Doc-Headern. **Exit:** Build grün, Toggle-Key existiert (noch ohne Wirkung).

### P1 — Regime-Auflösung (S, rein)
`TouchRegime` + `derivePosture` exakt nach der Partition §3.1 (inkl. „schmal & mittig → twoThumb",
Floating = keine v1-Klasse). Hysterese-Hook (Schwellen als Parameter).
**Tests:** Partition an allen Ecken + Schwellen-Grenzfällen; Hysterese verhindert Flackern.
**Exit:** `(orientation, scale, position) → Regime` deterministisch, 100 % getestet.

### P2 — TouchOffsetModel-Kern (L, rein) — *algorithmisches Herz*
- State + Initialzustand (`m=0,n=0,s=s_prior≈0,10`, §4.2).
- Update: absolutes Dwell-Gate-Hook, Outlier-Gate (nach `warmup`), **Huber-Clip**, Running-Mean,
  EW-MAD, `n_max`-Deckel (§4.2-S1).
- `ReachSurface`: Ridge-WLS, Basis **je Regime** (bilinear Einhand / linear twoThumb-Hälfte),
  **Cache + Invalidierung**, Rang-Guard, Konstanten-Term = global (§4.2-S2).
- Anwendung: `prior_k + (m_k−prior_k)·n_k/(n_k+κ)`, euklidischer **Clamp** ≤ 0,35 Pitch (§4.2-S3).
**Tests (umfangreich):** unverzerrte Konvergenz auf konstanten Bias; Huber kappt Ausreißer;
`n_max`-Plastizität überschreibt Altzustand; Shrinkage zieht sparse Tasten zur Fläche;
Rang-Guard (<3 Tasten → Fläche≈0); Zwei-Hälften-Split; Clamp; **Feedback-Schleife driftet nicht**.
**Exit:** Modell rein, deterministisch, alle Robustheits-Szenarien grün.

### P3 — Persistenz (M)
`Codable`-Schema, `SharedDefaults` (App-Group), Schema-Version + **partielle Invalidierung** bei
Layout-Änderung (stabile `keyId`s), Reset (alles / pro Regime), **debounced/periodischer Write**.
**Tests:** Round-Trip; Version-Bump invalidiert; partielle Invalidierung erhält gültige Keys;
Reset nullt korrekt.
**Exit:** Modell überlebt Neustart; Reset + Migration getestet.

### P3.5 — De-Risking-Slice (S) — *früh, optional aber empfohlen*
Dünner vertikaler Schnitt **vor** dem vollen Lernen: ein **hartkodierter** Konstant-Offset für eine
Taste → durch `cellFrames`-Resizing (Vorgriff auf P7) → am **Gerät** verifizieren, dass sich die
Tastenauswahl an der Grenze messbar verschiebt und der sichtbare Key stehen bleibt. Bestätigt den
§11.6-Redirect (Key-Target-Resizing) praktisch, bevor viel gebaut wird. Danach zurückbauen.

### P4 — Touchdown- & Feature-Plumbing (M) — *Eingriff in Bestandscode*
- `KeyGestureRecognizer`: `value.startLocation` erfassen → key-lokaler Touchdown → an `onGesture`.
- `GestureClassification` um optionalen **Feature-Vektor** erweitern (native Einheit, §13-A).
- `onGesture`-/`handleGesture`-Signatur erweitern (Touchdown + Features); `ActionContext` bzw.
  separater Lern-Sink trägt `keyId` + Touchdown (§5).
**Tests:** Gesten-Klassifikation **unverändert** (Regressionsschutz); Touchdown korrekt in
Keyboard-Koordinaten; Features korrekt durchgereicht.
**Exit:** bestehende Gesten-Tests grün; neue Daten kommen an, noch ohne Konsument.

### P5 — Lern-Middleware (M)
- `AcceptanceTracker`: Ring-Puffer (Tap → `keyId`, Touchdown, Zeichen-Span), **Burst-Veto über
  alle gelöschten Taps**, **Span-Alignment** (nicht 1:1), Trigger auf `.deleteBackward`-**Action**
  (nicht Target!), Slide-Delete abdecken (§4.1).
- Middleware am Pipeline-Ende: akzeptierte **interiore** Taps (`m_interior` gegen wahre Geometrie)
  → `TouchOffsetModel`; akzeptierte Gesten **aller Klassen** → `GestureTelemetryModel`.
- Verdrahtung in `rebuildPipeline()`; nur aktiv bei Toggle an.
**Tests (Mock-Target):** Veto-Logik (immediate + delayed Burst); Compose/Telex-interne Deletes
zählen **nicht**; Interior-Gate; Anti-Drift (Lernen nur interior).
**Exit:** Modell + Telemetrie füllen sich aus echten Pipeline-Events.

### P6 — GestureTelemetryModel (M)
Welford-Stats je `(Regime, Klasse[, Richtung])` (Richtung nur Swipe/Circle, §13-C), Korrektur-
Zähler, grobe Histogramme (Bins um Default-Schwelle), Persistenz (§13), Gating (§13-D).
**Tests:** Stats korrekt; Richtungs-Keying; Korrektur-Zähler; Round-Trip.
**Exit:** Telemetrie erhoben + persistiert (noch ohne Anzeige).

### P7 — Key-Target-Resizing-Anwendung (M) — *der „es wirkt"-Schritt*
- `KeyboardGridLayout.cellFrames` offset-bewusst: geteilte Grenzen verschieben nach §5.4 (innere
  V/H-Kanten `+= (o_A+o_B)/2`, Rand fix, eine-Kante-ein-Wert, Nicht-Degeneriertheit per Clamp).
- `KeyboardGridView`: **asymmetrischer** `visualInset` kompensiert → sichtbarer Key unverändert (§5.5).
- Offsets pro **aktivem Regime** aus `TouchOffsetModel` injizieren; **Apply-Gate** (Regime-Reife:
  Flächen-Rang ∧ Σ`n_k` ≥ `apply_on`) + Hysterese (§4.4).
**Tests:** `KeyboardGridLayoutTouchCoverageTests` erweitern → nach Resizing **vollständige, disjunkte**
Überdeckung; nicht-degeneriert; sichtbare Frames unverändert; #198-Kachelung intakt.
**Exit:** Korrektur wirkt auf die Tastenauswahl; Layout bleibt valide.

### P8 — UI (L)
- **Toggle** + Datenschutz-Hinweis + Status (§6.1).
- **Settings-Viz** (`SharedDefaults`-Snapshot): Tastatur-Rendering wiederverwenden, Offset-**Pfeile**
  (wahres Zentrum → gelernt) + Konfidenz-Deckkraft; **Regime-Selektor** (§6.2/6.3).
- **Reset** (alles / pro Regime) (§6.4).
- **Debug-View**: Sample-Streufeld, Reach-Vektorfeld, **Gesten-Diagnose** (Cluster-Kerne/Randdichte/
  Korrekturraten je Klasse, §6.5/§13).
**Tests:** UI-Tests (Toggle, Reset, Regime-Selektor via stabile Identifier); Snapshot-Render.
**Exit:** Nutzer kann aktivieren, sehen, zurücksetzen; Autor kann debuggen.

### P9 — Validierung & Abnahme (M)
Lokale Proxy-Metrik (Backspace-/Korrektur-Rate) + **A/B-Toggle-Mechanismus** (§8). Abnahme:
messbare Senkung **ohne** Anstieg in irgendeinem Regime → erst dann ggf. Default-an erwägen.
**Exit:** Belegbarer Nutzen (oder dokumentierter Nicht-Nutzen) → Datengrundlage für die
Default-Entscheidung.

---

## Test-Strategie (quer)
Apple `Testing`-Framework, co-loziert. Schwerpunkt **reine Unit-Tests** ohne Simulator (P1/P2/P3/P5/P6
mit Mock-`TextInputTarget`). Layout-Coverage-Tests für P7. UI-Tests (stabile Slot-Ids) für P8.
Robustheits-Szenarien (Wasser, Feedback-Schleife, Zensierungs-Bias) als explizite Tests (§12).

## Reihenfolge-Empfehlung (solo)
`P0 → P1 ∥ P2 ∥ P3 → P3.5 (Spike) → P4 → P5 → P6 → P7 → P8 → P9`.
Mergebare Schnitte: nach P3 (Kern), nach P5 (Lernen), nach P7 (Anwendung), nach P8 (UI). Jeder
Schnitt ist hinter dem Toggle inert, also gefahrlos in `develop` integrierbar.

## Risiken / Checkpoints
- **P3.5-Spike** klärt das einzige verbliebene praktische Risiko (Resizing am Gerät) früh.
- **P4** ist der Bestandscode-Eingriff → Regressionsschutz der Gesten-Tests ist Pflicht.
- **P7** muss die lückenlose Kachelung (#198) wahren → Coverage-Tests sind das Sicherheitsnetz.
- **Kalibrierung** (κ, n_max, m_interior, derivePosture-/Dwell-Schwellen, Histogramm-Bins) erfolgt
  in P5–P9 am Gerät, nicht vorab (§10).

## Nicht in v1 (Verweise)
Per-Geste-*räumliches* Residuum, stetige Größen/Aspect-Interpolation, Live-Extension-Overlay,
Gegenhand-Spiegelung, quadratische Fläche (alle **v2**); Negativ-Signal/Relabeln (**v3**, §9);
**Adaption** der Gestenparameter (separater Track — v1 nur Erhebung, §13).
