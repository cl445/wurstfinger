# Feature-Spezifikation: Lernende Touch-Offset-Korrektur

> Status: Entwurf (Rev. 7, + Gestenparameter-Telemetrie §13) · Sprache: Deutsch · Scope: Keyboard-Extension
> + Host-App-Settings · Forschungsbelege & -korrekturen: `touch-offset-correction-research.md`

## 1. Motivation & Ziel

Menschen treffen Tasten nicht mittig. Es gibt einen **systematischen Versatz** (Offset)
zwischen dem beabsichtigten Tastenzentrum und dem tatsächlichen Touchdown-Punkt — abhängig
von Nutzer, Taste, Geste, Handhaltung und Tastaturgeometrie. Dieses Feature **lernt diesen
Versatz während der Benutzung** und korrigiert den Touchdown-Punkt, bevor die Geste
klassifiziert wird, sodass die beabsichtigte Taste/Geste zuverlässiger erkannt wird.

Das Verfahren ist ein etabliertes HCI-Muster (Touch-Model-Personalisierung /
Key-Target-Resizing, vgl. Gunawardana/Paek/Meek 2010; Apple System-Keyboard). Mentales
Modell: das **effektive Tastenzentrum** wird dorthin verschoben, wo der Nutzer tatsächlich
systematisch hintippt; die Voronoi-Grenzen zwischen Tasten verschieben sich entsprechend mit.

### Erwartungshaltung

Bei einem 3×3-Grid mit großen Tasten ist reine Tasten-Verwechslung seltener als bei
QWERTY. Der Nutzen liegt schwerpunktmäßig bei **Tastengrenzen** und dem **Gesten-Startpunkt**
(der Touchdown bestimmt, welche Taste eine Geste „besitzt", inkl. Richtungs- und
Return-Swipes). **Quantifizierte Erwartung aus der Literatur** (siehe
`touch-offset-correction-research.md`): personalisierte Offset-Korrektur bringt **~5–13 %
relative Fehlerreduktion** gegenüber einer nicht-adaptiven Baseline (Gboard −13,2 %; Weir GPType
−5 bis −7,6 %), aber nur **~1 %** gegenüber dem besten kommerziellen Keyboard. Wurstfinger ist
heute nicht-adaptiv, spielt also im 5–13 %-Regime — **sofern es sich auf Gesten-Grids überträgt
(nicht empirisch belegt, 11.3).** Reale, aber moderate Verbesserung; zusätzlich gibt es einen
**irreduziblen Streu-Boden** (FFitts `σ_a ≈ 1,5 mm`), der selbst bei perfekter Korrektur bleibt.

### Grundhaltung: Unterkorrektur ist der sichere Fehlermodus

Eine Leitentscheidung, die das ganze Design prägt: **lieber zu wenig als zu viel korrigieren.**
Unterkorrektur verschlechtert die Erkennung sanft (Status quo ohne Feature); Überkorrektur macht
die Tastatur aktiv schlechter und untergräbt das Vertrauen. Mehrere Designentscheidungen
(Self-Labeling auf konfidenten Taps, Shrinkage, Clamp) tendieren bewusst zur Unterkorrektur.

> **Wichtige Präzisierung (aus Literatur-Review):** Die Unterkorrektur wird **ausschließlich**
> mit dem **Zensierungs-Bias** des Self-Labelings begründet (Mittel-Offset, 4.1) — **nicht** mit
> dem Streu-Boden `σ_a`. `σ_a` betrifft die **Varianz** (rechtfertigt die Reach-/Toleranzfläche),
> nicht den systematischen Mittel-Offset; beides ist sauber zu trennen. Der Streu-Boden ist *kein*
> Argument fürs Unterkorrigieren, sondern erklärt nur, warum der Nutzen moderat bleibt.

## 2. Ziele / Nicht-Ziele

**Ziele**
- Opt-in-Feature, das den Touchdown-Punkt vor der Klassifikation korrigiert.
- Lernen aus der laufenden Nutzung, ohne expliziten Kalibrierungsmodus.
- Robust gegen Degeneration (Feedback-Schleifen) und gegen Ausreißer (Wasser auf dem
  Display, versehentliche Touches, Gerät weitergereicht).
- Selbstheilend: ein verkorkster Zustand wird über das Plastizitäts-Fenster (4.2) + Reset geheilt.
- Unabhängiges Lernen pro biomechanischem Regime.
- Visualisierung in den Settings zur Vertrauensbildung und zum Debuggen.

**Nicht-Ziele (v1)**
- Kein expliziter Kalibrierungs-/Trainingsbildschirm.
- Keine sprachmodell-basierte Intent-Inferenz.
- Keine Korrektur-Attribution über Backspace-Erkennung (Negativ-Signal) — v3.
- **Keine stetige Anpassung an Tastaturgröße/Aspect** (normalisierte Einheiten, Interpolation
  über Größen) — auf v2 verschoben (Begründung 3.5).
- Keine Per-Geste-Ebene — v2.
- Keine Cloud-/Cross-Device-Synchronisation. **Alle Daten bleiben lokal auf dem Gerät.**

## 3. Modell-Design

Die zentrale Designentscheidung: **diskrete Regime** (echte, separate Modelle) sauber von
**stetiger Geometrie** (parametrisch, gepoolt) trennen. Das Tupel
`(Orientierung, Größe, Aspect, Position)` als Modellschlüssel zu verwenden ist die zu
vermeidende Falle — es sprengt den Konfigurationsraum und zerstört die Datendichte, von der
das hierarchische Shrinkage lebt.

### 3.1 Diskrete Regime (separate Modelle)

Nur dort getrennt lernen, wo sich die *Biomechanik* sprunghaft ändert. Beide Achsen sind zur
Laufzeit **ohne Detektion** bekannt (siehe geklärtes Risiko 11.1):

- **Orientierung:** Portrait / Landscape — zuverlässig vom Controller geliefert
  (`detectIsLandscape()` via `windowScene.interfaceOrientation` → `viewModel.isLandscape`; die
  Keyboard-Bounds selbst taugen dafür *nicht*, da immer höher als breit).
- **Posture-Klasse:** **explizit vom Nutzer gewählt** (Einstellung `touchOffsetPosture`), nicht
  detektiert. iOS bietet Dritt-Tastaturen keinen Einhand-/Floating-State. Eine frühere Ableitung
  aus `keyboardScale`/`keyboardHorizontalPosition` war unzuverlässig: ein rechts-einhändiger
  Nutzer mit mittig-breiter Tastatur wurde als „zwei Daumen" klassifiziert — genau der Fall, in
  dem das Two-Thumb-**Split**-Modell die kontralaterale Hälfte mit einem falschen zweiten Pivot
  fittet (3.2) und damit **aktiv falsch** korrigiert (nicht nur Pooling-Effizienz kostet). Weil
  die Fehlklassifikation den Nutzen dort zerstört, wo Einhand-Reach ihn am dringendsten bräuchte,
  ist die Wahl eine **bewusste Entscheidung**:

  ```
  postureClass ∈ {
    oneThumbRight   (eine Fläche, Pivot rechts)   — Default: Einhand ist der Normalfall,
                                                     rechts die häufigste Hand
    oneThumbLeft    (eine Fläche, Pivot links, 3.2)
    twoThumb        (Split-Fläche links/rechts, 3.2)
  }
  ```
  UI-Reihenfolge: **rechts → links → beide** (§6.3). **Floating (iPad)** ist in v1 **keine eigene
  Klasse**. Die Wahl liegt in `SharedDefaults`; die Extension liest sie **pro Geste frisch**
  (`currentTouchRegime`), ein Handwechsel in der App wirkt also ab dem nächsten Tap ohne
  Keyboard-Neustart. `keyAspectRatio` fließt in v1 nicht ein (Aspect-Handling ist v2, 3.5).

Regime-Schlüssel = `(Orientierung, postureClass)`. Kein State zu erraten, kein Spike nötig.

### 3.2 Stetige Geometrie: die Reach-Fläche

Der Reach-Bias (Daumen trifft Richtung ferner Tasten systematisch daneben) hängt am Abstand
der Taste zum **Daumen-Drehpunkt**. Modelliert als glatte, niederdimensionale Fläche über die
**Tastenposition innerhalb der Tastatur** (auf `[0,1]²` normiert, siehe Koordinaten 5.2).

**Zwei-Daumen-Korrektur (wichtig, aus Review):** Bei *einem* Daumen (Einhand) gibt es
*einen* Pivot — eine einzelne bilineare Fläche ist eine brauchbare Näherung. Beim
**twoThumb-Regime (Standard-Posture) tippen die meisten mit zwei Daumen** → *zwei* Pivots, das
Bias-Feld hat zwei Zentren und ist über die Breite nicht-monoton. Eine einzelne Fläche kann das
nicht abbilden. Deshalb:

- **twoThumb-Regime:** die Tastatur an der **vertikalen Mittellinie** in linke/rechte Hälfte
  splitten, **je eine eigene Reach-Fläche** (je ein Daumen-Pivot). Tasten auf der Mittelachse
  werden der jeweils näheren Hälfte zugeordnet.
- **Einhand-Regime (`oneThumbLeft`/`oneThumbRight`):** eine einzelne Fläche genügt. (Floating ist in
  v1 keine eigene Klasse, 3.1.)

**Ordnung (Entscheidung, revidierbar):** richtet sich nach der stützenden Tastenzahl —

- **Einhand (eine Fläche über ~9–12 Tasten):** **bilinear** `φ = [1, u, v, uv]` (4 Koeff.).
- **twoThumb (Split, je Hälfte nur ~4–5 Tasten):** **linear** `φ = [1, u, v]` (3 Koeff.). Eine
  bilineare Fläche (4 Koeff.) wäre über 4–5 Punkte grenzwertig/unterbestimmt; der Split trägt
  bereits die Nicht-Monotonie über die Breite, die Rest-Krümmung je Hälfte ist gering genug für
  linear.

Höhere Ordnung (bilinear je Hälfte / quadratisch) nur, wenn Residuen Krümmung nachweisen. Ridge
(`λ_ridge`, 4.2) hält den Fit auch bei knapper Datenlage stabil — das ist die Antwort auf den
Daten-Hunger des Splits: lieber niedrige Ordnung + Ridge als eine reich parametrisierte Fläche, die
über wenige Punkte überanpasst.

**Tastaturposition braucht keinen eigenen State:** Verschiebt sich die Tastatur, wandern die
Tasten im *Screen*-Raum, aber die Fläche lebt im *tastaturlokalen* `[0,1]²`-Raum — der
Daumen-Pivot wandert mit der Tastatur mit, der Bias relativ zur Tastatur bleibt stabil. (Falls
die absolute Bildschirmhöhe der Tastatur den Reach messbar verändert, ist das ein v2-Thema, kein
v1-State.)

### 3.3 Modellformel (v1)

Konzeptionell ist die Korrektur eine Summe aus gepoolter Fläche und Per-Tasten-Abweichung; der
konstante Term der Fläche **ist** der globale Offset (ein separater `global`-Term wäre kollinear/
nicht identifizierbar). **Gespeichert wird aber nicht diese Zerlegung**, sondern pro Taste der rohe
Running-Mean `m_k` des Gesamt-Offsets; die Fläche wird daraus *abgeleitet*, die Per-Tasten-
Abweichung ist *implizit* (siehe Algorithmus 4.2):

```
# Gespeichert pro (Regime R, Taste K, Achse):  m_k (Gesamt-Offset-Mittel), n_k, s_k
# Abgeleitet:   reachSurface[R][H] = Ridge-WLS-Fit über die m_k   (H = Hälfte, nur twoThumb)
# Angewandt:    Korrektur(K) = prior_k + (m_k − prior_k)·n_k/(n_k+κ),   prior_k = surface(pos_K)
```

Es gibt also **keine separat persistierte `keyResidual`-Map** — die „Ebene" ist eine Sichtweise,
kein Speicher. Die finale Korrektur wird in Punkte zurückgerechnet (× Tastenpitch) und geclampt
(4.3). Per-Geste-Residuum: v2.

### 3.4 Hierarchisches Shrinkage

Die angewandte Per-Tasten-Abweichung `(m_k − prior_k)·n_k/(n_k+κ)` wird über den Faktor
`n_k/(n_k+κ)` zur Flächen-Vorhersage gezogen: wenig Daten ⇒ Abweichung ≈ 0, es greift nur die
(gepoolte, datenreiche) Fläche; viele Daten ⇒ die Taste folgt **unverzerrt** ihrem eigenen `m_k`.
Das sichert den **Cold-Start** (ohne Daten ist die Fläche flach ≈ 0 ⇒ neutral) und löst
Datenknappheit auf Tastenebene. Formal ist es **Empirical Bayes**: die Fläche (Hyperprior) wird aus
denselben `m_k` geschätzt, zu denen dann geschrumpft wird — bei ~9 Tasten unkritisch (Standard-EB).

### 3.5 Warum Größe/Aspect in v1 wegfällt (Vereinfachung aus Review)

Auf *einem* Gerät ist in *einem* Regime die Tastengeometrie nahezu konstant. Die reale
Größen-/Aspect-Variation entsteht fast nur durch Einhand (und Floating, v2) — und das ist **bereits
ein eigenes Regime**. Damit ist die „stetig-in-der-Geometrie"-Maschinerie (normalisierte
Cross-Size-Einheiten, Interpolation über Größen) in der Praxis selten gefordert und für v1
unnötiges Risiko. v1 speichert `m_k` weiterhin in **Tastenpitch-Anteilen** (billiger
Schutz gegen kleine Größenänderungen), aber ohne explizite Interpolation über mehrere Größen.
Diese kommt in v2, falls Bedarf nachgewiesen wird.

### 3.6 Geltungsbereich des Modells (Sprachen & Modi)

Der Offset ist **physisch** (Daumen-/Finger-Biomechanik), nicht buchstabenabhängig. Daher:

- **Verankert an der Slot-Position (`keyId`), nicht am Buchstaben** — `keyId`s sind stabile Slot-Ids
  (gleiche Position über alle Sprachen, vgl. `accessibilityIdentifier`).
- **Geteilt über Sprachen** (de/en/…) und über die **Alpha-Modi** (Buchstaben-Layouts) — maximiert
  Datendichte; der physische Bias ist sprachunabhängig.
- **Numerische/Symbol-Modi separat:** andere Tasten-Anordnung/Trefferflächen → eigenes Modell (oder
  bei identischem Grid teilbar; Default: separat, geringe Kosten).
- Damit ist der vollständige Modell-Schlüssel: `(Orientierung, postureClass, Arrangement-Familie)` —
  **nicht** Sprache. Regime-Schlüssel (3.1) bleibt `(Orientierung, postureClass)`; die
  Arrangement-Familie (alpha vs. numerisch) ist die dritte Dimension.

## 4. Lernen

### 4.1 Lernsignal (v1: Self-Labeling auf konfidenten Taps) — inkl. Zensierungs-Bias

Offset = `roher Touchdown − wahres Zentrum der beabsichtigten Taste`. Da die beabsichtigte Taste
nicht direkt bekannt ist, wird sie per **Self-Labeling** zugeordnet — das ist der
literatur-belegte SOTA-Ansatz (Yin & Partridge, CHI 2013: „probabilistically assigning a key to
each of the user touch points, without relying on the hidden identity of the true intended key").
v1 nutzt die **degradierte, LM-freie Variante**: bei den großen Grid-Tasten ist der weitaus
größte Teil der Taps eindeutig, daher:

> Landet ein **akzeptierter** Tap (kein sofortiges Löschen/Ersetzen) eindeutig in Taste K, gilt K
> als beabsichtigt und `roher Touchdown − center(K)` wird als Sample gelernt.

Das ist Self-Labeling, beschränkt auf konfidente (interiore) Taps — kein naives
„Acceptance-only", sondern dessen LM-freie Spielart.

**Operationalisierung von „konfident/interior" (`m_interior`):** Ein akzeptierter Tap zählt nur
fürs Lernen, wenn der rohe Touchdown **mehr als `m_interior`** (Anteil des Tastenpitchs) vom
nächsten Tastenrand entfernt liegt — grenznahe Taps werden vom *Lernen* ausgeschlossen (korrigiert
werden trotzdem alle). `m_interior` ist **der zentrale Bias-Varianz-Knopf** (Tuning-Parameter §10):
- **groß** (streng interior) → kaum Mislabeling, aber **maximaler Zensierungs-Bias** (die
  informativen Grenzfälle fehlen) → stärkere Unterkorrektur.
- **klein** (auch grenznahe Taps) → weniger Bias, aber Risiko, falsch zugeordnete Grenz-Taps zu
  lernen.

**Default v1: moderat** — bewusst Richtung „streng" (konsistent mit „Unterkorrektur ist sicher",
§1); am Gerät kalibrieren.

**Welche Gesten lernen?** Nur **Taps** liefern in v1 Samples. Richtungs-/Return-Swipes liefern
**kein** `m_k`-Sample (ihr Startpunkt ist absichtlich versetzt → würde verzerren).
**Slide-Gesten** (Space-Cursor, Delete) lernen nie und werden nie korrigiert (kein Tastenzentrum
gemeint). Per-Geste-Lernen ist v2.

**Welche Tasten?** **Alle Nicht-Slide-Tasten** nehmen teil — Lernen, Resizing *und* Flächen-Fit
(über ihren sichtbaren Mittelpunkt, 5.2). Das schließt Utility-Tasten (Shift, Mode-Switch, Globe,
Return-Tap) ein; sie werden selten getippt → niedriges `n_k` → ohnehin stark zur Fläche geschrumpft
(selbstregulierend, kein Sonderfall). **Slide-Tasten** (Space, Delete) sind komplett ausgenommen.

**Acceptance-Filter (Mechanismus, Code-verifiziert §11.5, literatur-fundiert §«Korrekturverhalten» im
Research-Doc):** „kein sofortiges Löschen/Ersetzen" wird so umgesetzt: ein kleiner **Ring-Puffer
zuletzt committeter Taps** (`keyId`, Touchdown) wird geführt; eine **Backspace-Sequenz** vetoed
**alle dadurch gelöschten Taps** (nicht gelernt). Fenster über **Aktions-Zählung**, nicht über eine
Uhr — die Literatur parametrisiert Korrektur durchweg über Edit-Struktur, nicht über ms (Baldwin
2012; Gboard „Undo: before any other key"); eine ms-Latenz-Verteilung existiert nicht.
- **Burst statt Einzel-Veto (Korrektur aus Literatur):** Bei *verzögerter* Korrektur löscht der
  Nutzer **durch korrekte Zeichen hindurch** bis zum Fehler (`peeple<<<<ople`). Nur den jüngsten Tap
  zu vetoen träfe oft einen korrekten statt des Mis-Hits → **alle vom Burst gelöschten Taps**
  ausschließen. Ausschluss schadet nie (kostet nur Recall), Relabeln wäre riskant (→ v3).
- **Tap↔Zeichen-Alignment (nicht 1:1!):** Compose/Telex committen/ersetzen mehrere Zeichen pro Tap,
  also gilt **nicht** „k Backspaces = k Taps". Lösung: der Ring-Puffer merkt pro Tap die **netto
  erzeugte Zeichen-Spanne** (Länge des `insertText` minus etwaiger interner Ersetzungen). Ein
  Nutzer-Burst entfernt L Zeichen vom Dokumentende → **vetoe jeden Tap, dessen Spanne (ganz oder
  teilweise) in diesen L Zeichen liegt**. Über-Ausschluss (teilweise getroffene Taps) ist sicher.
- **Edit ≠ Fehlerkorrektur:** lange Bursts, die ganze Wörter/Sätze entfernen, sind Umformulierungen
  (Baldwin: 43,1 % der Edits sind so) → kein Mis-Hit-Signal; Burst-Länge deckeln, darüber ignorieren.
- **Fallstrick (wichtig):** Es muss auf die **`.deleteBackward`-`KeyAction` in der `ActionPipeline`**
  getriggert werden (= Nutzer hat die Löschtaste benutzt), **nicht** auf `TextInputTarget.delete­Backward()`
  — denn `ComposeMiddleware`/`TelexMiddleware` rufen das Target im *Normalbetrieb* intern auf
  (Akzent/Digraph ersetzen). Diese internen Deletes umgehen die Pipeline; eine Lern-Middleware in
  der Pipeline sieht daher sauber nur Nutzer-Aktionen. Der **Slide-basierte Delete** (`handleSlide`)
  ist ein separater Pfad und muss ebenfalls als Korrektur zählen.

**Zensierungs-Bias (literatur-bestätigt, bewusst akzeptiert):** Baldwin (2012) dokumentiert, dass
Lernen ohne wahres Label zu Fehlerfällen verzerrt; unser konfidentes Self-Labeling sieht nur Taps
*in* der Taste, die Grenz-Mis-Hits fehlen → der Offset wird **systematisch zu klein** geschätzt
(Regression zur Mitte). Das ist konsistent mit „Unterkorrektur ist sicher" (1) und in v1 **bewusst
in Kauf genommen**. Der SOTA umgeht den Bias *nicht* per Acceptance-only, sondern per
LM-/Decoder-Self-Labeling — das haben wir nicht. **Beruhigend (Literatur):** der Rausch-Beitrag
unkorrigiert akzeptierter Mis-Hits ist klein — unkorrigierte Fehler sind selten (~2,3 % bei Palin
2019; „conscientiousness" 0,61–0,78 bei Soukoreff/MacKenzie 2003), und Baldwins „Character-Level"-
Strategie (allen nicht-editierten Taps vertrauen) erreicht trotzdem **98,2 % Precision**. Die
unverzerrte Korrektur erfordert ein **Negativ-Signal** und ist auf v3 terminiert, mit Baldwins
konkreter Methode (siehe §9). Dokumentiert, damit später niemand die Unterkorrektur für einen Bug
hält.

**Entkopplung von Messung und Anwendung (verhindert Degeneration — zentral bei Key-Target-Resizing):**
Mit verschobenen Hit-Zellen (§5) droht eine konkrete Feedback-Schleife: eine vergrößerte Zelle fängt
grenznahe Taps ein, die — gegen das *wahre* Zentrum gemessen — großen Offset haben; würden die
gelernt, bliese sich `m_k` weiter auf → Zelle wächst → Drift. Bruch der Schleife, dreifach:
- **`m_interior` gegen die *wahre* Geometrie:** gelernt wird nur aus Taps **interior zur echten
  (unverschobenen) Zelle** (`m_interior` vom *wahren* Tastenrand). Genau die aufgeblähten Grenz-Taps
  fallen damit raus → speisen die Schleife nicht. (`m_interior` ist doppelt load-bearing:
  Zensierungs-Bias *und* Anti-Drift.)
- **Messung gegen feste Geometrie:** stets `roher Touchdown − wahres center(K)`, nie gegen das
  verschobene Zentrum.
- **Clamp** (§4.3) deckelt die Grenzverschiebung hart → selbst Restdrift bleibt begrenzt.
Damit ist der Fixpunkt der echte User-Bias, nicht das Auswahl-Ergebnis ⇒ keine Selbstverstärkung.

### 4.2 Lern-Algorithmus: Empirical-Bayes-Shrinkage mit bounded-influence Running-Mean

Der Algorithmus nutzt aus, dass es **pro Regime nur eine Handvoll Tasten** gibt (3×3-Grid ≈ 9
Buchstaben-Positionen + Utility) und die Reach-Fläche nur 3–4 Koeffizienten hat. Damit ist die
Flächenschätzung ein **winziger Closed-Form-Solve**, der bei Bedarf (Lesen/Persistieren) aus den
Per-Tasten-Statistiken neu gerechnet wird — **kein** Online-RLS, **kein** Backfitting, **keine**
zwei Zeitskalen. Das Lernen zerfällt in drei entkoppelte, je triviale Teile. Alle Achsen (x, y)
werden **unabhängig** behandelt (Kovarianz ignoriert — für den *Mittel*-Offset ausreichend, da der
Mittelwert separabel ist); alle Größen in **Tastenpitch-Anteilen**.

**State pro (Regime, Taste k, Achse):** `n_k` (effektive Sample-Zahl, gedeckelt bei `n_max`),
`m_k` (bounded-influence Running-Mean), `s_k` (robuste Streuung, EW-MAD).
**Initialzustand:** `m_k = 0`, `n_k = 0`, `s_k = s_prior ≈ 0,10 Pitch` (≈ FFitts `σ_a`).

**Schritt 1 — Per-Tasten-Update (online, je akzeptiertem Tap).** `e = rohTouchdown − center(k)`,
*nach* dem absoluten **Dwell-Gate** (Kontaktradius/Multitouch entfallen, 4.3/11.4):

```
if n_k ≥ warmup and |e − m_k| > k_gate · s_k:   skip      # Outlier-Gate (erst nach Warm-up)
δ   = clip(e − m_k, ±c · s_k)                              # Huber: gekappter Einfluss
n_k = min(n_k + 1, n_max)
m_k = m_k + δ / n_k                                        # Running-Mean (unverzerrt)
s_k = s_k + β · (|e − m_k| − s_k)                          # robuste Streuung
```

Der **Huber-Clip** ist der zentrale Ausreißer-/Wasser-Schutz: ein einzelnes Sample bewegt `m_k`
nie um mehr als `c · s_k / n_k` (bounded influence), bleibt für saubere Daten aber unverzerrt —
ersetzt einen teuren Online-Median fast gratis.

**Schritt 2 — Reach-Fläche (Closed-Form, gecacht).** Pro Regime (beim `twoThumb`-Regime je Hälfte,
3.2) aus den Tasten als gewichtete Punkte. Basis **je nach Regime** (3.2): `φ = [1, u, v, uv]`
(bilinear, Einhand) bzw. `φ = [1, u, v]` (linear, twoThumb-Hälften); `W = diag(n_k)`,
Ridge → 0:

```
β_surface = (Φᵀ W Φ + λ_ridge · I)⁻¹ Φᵀ W m              # gewichtetes Ridge-LS, m = Vektor der m_k
surface(pos) = φ(pos) · β_surface
```

`β_surface` wird **gecacht** und nur bei `m_k`/`n_k`-Änderungen invalidiert (nicht pro Tap neu
gelöst); Schritt 3 liest aus dem Cache. **Rang-Defizit-Guard:** solange weniger Tasten Daten haben
als die Basis Koeffizienten hat (z. B. <3 je linearer Hälfte), ist `ΦᵀWΦ` singulär — `λ_ridge·I`
macht den Solve wohldefiniert und zieht die Fläche ≈ 0 (≈ gewichteter Mittel-Offset), bis genug
Tasten belegt sind. So sichert Ridge zugleich Cold-Start und Daten-Hunger des Splits. Der
Konstanten-Term von `β_surface` ist der „globale" Offset (3.3).

**Schritt 3 — Angewandte Korrektur (Shrinkage zum Flächen-Prior).**

```
prior_k = surface(pos_k)
r_k     = prior_k + (m_k − prior_k) · n_k / (n_k + κ)     # Partial Pooling / James-Stein (je Achse)
offset_k = clamp_betrag((r_kx, r_ky), ≤ 0,35 · pitch)    # euklid. Betrag des 2D-Vektors, in Punkte (4.3)
#          → speist als Grenzverschiebung das Key-Target-Resizing (§5, §4.4)
```

`n_k / (n_k + κ)` ist die **stufenlose Variante des reife-gegateten Backoffs** (Yin & Partridge,
CHI 2013): junge/sparse Tasten hängen am Flächen-Prior, gut belegte konvergieren **unverzerrt**
auf ihren eigenen Mittelwert. Das ersetzt die ursprüngliche EMA, deren konstantes Decay einen
permanenten Schrumpf-Bias `α/(α+λ)·μ` hatte.

**Warum diese Wahl (statt Alternativen):**

| Wahl | statt | Grund |
|---|---|---|
| Running-Mean | konstante EMA | unverzerrt; EMA hatte permanenten Schrumpf-Bias |
| count-gewichtetes Shrinkage (`κ`) | hartes Reife-Backoff | gleicher Effekt, aber stufenlos → kein Flackern an der Schwelle |
| Closed-Form-WLS-Refit der Fläche | Backfitting / Online-RLS | nur ~9 Punkte → trivialer Solve; eliminiert Zwei-Zeitskalen-Tanz |
| Huber-Clip | reiner Mittelwert / Online-Median | bounded influence gegen Ausreißer, fast gratis, unverzerrt für saubere Daten |
| `n_max`-Deckel | konstantes Decay | trennt Plastizität/Selbstheilung sauber von Shrinkage (`κ`) |

**Plastizität / Selbstheilung:** der Deckel `n_max` macht aus dem Running-Mean ab `n_max` eine EMA
mit `α = 1/n_max` → neue (gute) Samples überschreiben einen verkorksten Zustand in begrenzter Zeit.
`κ` (Pooling/Konfidenz) und `n_max` (Recency) sind bewusst getrennt einstellbar. **Default v1:**
großzügiges `n_max` (langsame Plastizität); aggressiver nur bei beobachtetem Drift.

**Kalman pro Taste/Achse** wurde bewusst *nicht* gewählt: eleganter (Konfidenz + Recency for free),
aber das Prozessrauschen ist nur ein verkapptes Forgetting — mehr Tuning/State ohne Mehrwert für
v1. Klare v2-Option, falls adaptives Drift-Tracking nötig wird.

`n_k`/`s_k` steuern außerdem Anzeige-Deckkraft (UI) und das Apply-Gate (4.4).

### 4.3 Robustheit & Degenerations-Schutz

Gestaffelte Verteidigungslinien:

- **Messung ↔ Anwendung entkoppelt** (4.1) — struktureller Schutz gegen Feedback-Drift.
- **Hierarchisches Shrinkage** (3.4) — sparse Tasten bleiben an der gepoolten Fläche.
- **Begrenzung (Clamp):** der **Betrag des 2D-Korrekturvektors** `(r_kx, r_ky)` (Fläche schon
  eingefaltet, 4.2) hart deckeln (z. B. ≤ 35 % des Tastenpitchs). Eine Taste kann nie mehr als
  „halb daneben" verschoben werden — Worst Case bleibt benutzbar.
- **count-gewichtetes Shrinkage** (4.2) — sparse/junge Tasten bleiben nahe der gepoolten Fläche;
  zugleich das literatur-belegte reife-gegatete Backoff.
- **Selbstheilung über das Plastizitäts-Fenster** (4.2) — durch das gedeckelte `n_max`
  überschreiben neue (gute) Samples einen alten verkorksten Zustand in begrenzter Zeit; plus
  manueller Reset (6.4).
- **Plausibilitäts-Gate vor dem Lernen:** Sample nur verwenden bei
  - normaler **Dwell-Zeit** (aus `DragGesture.Value.time`, Dauer onChanged→onEnded; lange/
    erratische Berührung → raus),
  - (nach Warm-up) Abweichung < `k_gate · s_k` vom aktuellen Schätzwert (zusammen mit Huber-Clip).
  - ⚠️ **Kontaktradius & Multitouch entfallen (Code verifiziert, 11.4):** der Touchpfad ist
    SwiftUI `DragGesture` → **kein** `UITouch.majorRadius`, keine Touch-Zahl. Der geplante
    Kontaktradius-Gate gegen Wasser/Handballen ist mit der aktuellen Architektur nicht umsetzbar.
- **Streuung definiert & Cold-Start-Policy (aus Review):** `s_k` ist eine robuste
  Online-Größe (EW-MAD, 4.2) mit breitem Prior. Das varianzbasierte Outlier-Gate greift erst
  **nach `warmup` Samples**; davor schützen ausschließlich das *absolute* Dwell-Gate plus der
  Clamp. So gibt es kein „kein Schätzwert → kein Schutz"-Loch beim Start.
- **Regularisierung der Reach-Koeffizienten:** niedrige Ordnung (bilinear/linear), L2 → 0.

> **Ehrliche Einordnung (Literatur-Review + Code-Check):** Konfidenz-/Reife-Gating und
> Backoff/Shrinkage sind literatur-belegt (Yin & Partridge). Die Mechanismen gegen **transiente
> Störungen** (Clamp, Dwell-/Outlier-Gate, robuste Streuung) sind eigene Erweiterungen ohne externe
> Validierung. Mit dem Wegfall des Kontaktradius (11.4) ruht die Wasser-Verteidigung in v1 auf
> **Dwell-Gate + Outlier-Gate/Huber-Clip + Clamp + Plastizitäts-Heilung + manuellem Reset** —
> schwächer als ursprünglich geplant, aber das Modell kann nicht *nachhaltig* degenerieren.

### 4.4 Anwendung & Apply-Gate

- Die Korrektur wirkt als **Verschiebung der Hit-Zellgrenzen** (Key-Target-Resizing, §5), nicht als
  Punkt-Translation. Sie ändert damit ausschließlich die **Tastenauswahl** an Grenzen; die
  Innerhalb-Tasten-Klassifikation (Tap/Swipe-Richtung/Return) bleibt unberührt.
- **Apply-Gate mit Hysterese (auf Regime-Ebene, 11.5):** die Korrektur eines Regimes wird erst
  angewandt, wenn **Flächen-Rang erfüllt UND `Σ n_k ≥ apply_on`**; sie wird erst wieder ausgesetzt,
  wenn `Σ n_k < apply_off` (`< apply_on`). Per-Taste ist kein hartes Gate nötig — niedriges `n_k`
  regelt das Shrinkage (4.2) bereits stufenlos. Hysterese verhindert Flackern.

### 4.5 Wasser-Szenario (explizit)

Wasser ⇒ erratische Touches mit untypischen Dwell-Zeiten und großer Streuung. Da Kontaktradius/
Multitouch **nicht** verfügbar sind (11.4), greift das **Dwell-Gate** als einziger absoluter Filter;
der Rest wird über das **Outlier-Gate/Huber-Clip** abgefangen (erratische Punkte liegen weit vom
`m_k` → gekappt/verworfen). Was durchrutscht, ist durch **Clamp** begrenzt und wird bei normaler
Nutzung über das **Plastizitäts-Fenster** (`n_max`, 4.2) überschrieben; zusätzlich **manueller
Reset** (6.4). Schwächer als mit Kontaktradius, aber: das Modell kann nicht *nachhaltig* kippen.

## 5. Architektur & Integration

- **Anwendung — Key-Target-Resizing in `KeyboardGridLayout.cellFrames` (Code-verifiziert, 11.6):**
  *Nicht* den Touchdown-Punkt verschieben — das geht in der Per-KeyView-Architektur nicht (die
  Tastenzuordnung fällt bei SwiftUIs Hit-Testing, *bevor* ein Handler den Punkt sieht). Stattdessen
  die **Hit-Zellgrenzen** verschieben: `cellFrames` ist die zentrale, reine, bereits unit-getestete
  Funktion, die jeder Taste ihren Touch-Frame zuteilt. Der gelernte Per-Tasten-Offset verschiebt die
  **gemeinsame Grenze** zweier Nachbartasten (≈ um `(offset_A+offset_B)/2`) → ein grenznaher Tap
  landet in der vergrößerten Zelle der intendierten Taste. Das ist das literatur-kanonische
  **Key-Target-Resizing** (Gunawardana 2010) und macht §1 wörtlich wahr.
  - **Sichtbar ≠ Touch (passt schon):** Die Architektur trennt bereits **Touch-Frame** (`cellFrames`)
    vom **sichtbaren** Key (per `visualInset` zurückgesetzt). Wir verschieben nur den Touch-Frame; der
    sichtbare Tastatur-Eindruck bleibt stabil — genau das unsichtbare Resizing wie bei Apple/Gboard.
  - **Innerhalb-Tasten-Gesten unberührt:** `KeyGestureRecognizer` arbeitet in Translation-Koordinaten
    relativ zum Touchdown → Tap/Swipe-Richtung/Return sind vom Offset **nachweislich unbeeinflusst**
    (löst die Sorge aus 11.3).
- **Modell:** neue Komponente `TouchOffsetModel` (pro Regime: Per-Taste `{m_k, n_k, s_k}`; die
  Reach-Fläche[n] werden daraus **abgeleitet/gecacht**, nicht separat als „keyResidual" persistiert
  — 3.3/4.2). Vom Preprocessor zur Korrektur konsultiert, aus Feedback aktualisiert.
- **Lern-Feedback:** schlanke **Lern-Middleware am Pipeline-Ende** beobachtet `.commitText` (Tap)
  und `.deleteBackward` (Nutzer-Korrektur → Acceptance-Veto, 4.1) und sieht so sauber nur
  Nutzer-Aktionen.
- **⚠️ Touchdown-Plumbing (Haupt-Integrationsposten, Code-verifiziert):** Der rohe Touchdown wird
  heute **nirgends durchgereicht** — `KeyGestureRecognizer` verwirft die absolute `startLocation`
  (nur `translation` wird intern genutzt), und `ActionContext` trägt weder `keyId` noch Punkt. Für
  `e = Touchdown − center(K)` muss der **key-lokale Touchdown** neu durchgefädelt werden:
  `KeyGestureRecognizer` (erfasst `value.startLocation`) → `onGesture`-Callback (`KeyView`) →
  `handleGesture` (kennt bereits `keyId`) → Lern-Middleware. Praktisch: `keyId` + Touchdown in den
  `ActionContext` aufnehmen (oder einen separaten Lern-Sink aus `handleGesture` speisen). Das ändert
  die Gesten-API-Signatur — überschaubar, aber der größte einzelne Eingriff.
- **Regime-Kontext:** Regime-Schlüssel + Geometrie sind zur Laufzeit aus
  `KeyboardViewController`/View-State verfügbar (Posture-Klasse abgeleitet, 11.1).
- **Persistenz:** `SharedDefaults` (App-Group), versioniertes Schema; `keyId`s sind stabile
  Slot-Ids, daher bei Layout-Änderung **partielle** Invalidierung (nur entfallene Keys), nicht
  alles wegwerfen.

### 5.1 Prozessgrenze (Gotcha)

Settings-Unterseite läuft in der **Host-App**, das Modell entsteht in der **Extension** (eigener
Prozess). Die Settings-Viz zeichnet nur den **`SharedDefaults`-Snapshot** (mit „zuletzt
aktualisiert") — kein Live-Mittippen, da in der Host-App nicht die eigene Extension als Eingabe
aktiv ist. Echtes Live gehört in ein Debug-Overlay *in der Extension* (6.6).

### 5.2 Koordinatensystem (eindeutig festlegen)

- **Touchdown & Tastenzentren:** im **Tastatur-View-Koordinatenraum** (Punkte, Ursprung oben
  links der Tastatur-View, in der *aktuellen* Orientierung — Rotation hat das View-System bereits
  aufgelöst). **`center(K)`** = geometrischer Mittelpunkt des **sichtbaren** Keys (nicht der
  Touch-Zelle); spannende Tasten nutzen den Mittelpunkt ihres vollen sichtbaren Rechtecks.
- **Reach-Flächen-Eingabe:** Tastenposition in diesem Raum, normiert auf `[0,1]²`
  (`posInKeyboard`). Bei der **twoThumb-Split-Fläche** ist `u` **halb-lokal** auf `[0,1]` je Hälfte
  normiert (jede Hälfte spannt ihren eigenen `[0,1]²`-Raum auf, ein Pivot pro Hälfte).
- **`m_k`, Korrektur-Offsets & Clamp:** in **Tastenpitch-Anteilen** (dx/Breite, dy/Höhe), erst bei
  der Anwendung mit dem aktuellen Pitch in Punkte zurückgerechnet.

### 5.3 Wechselwirkung mit lückenloser Kachelung / Totzonen (#198)

Key-Target-Resizing (§5) verschiebt **gemeinsame Zellgrenzen** in `cellFrames`. Kritisch: die
Kachelung muss **lückenlos UND überlappungsfrei** bleiben (#198) — eine verschobene Grenze muss die
Nachbarzelle exakt gegengleich nachführen (**eine Kante = ein Wert**, von beiden Zellen geteilt),
sonst entstehen Totzonen oder Doppelzuordnungen. Die Grenzverschiebung ist zu clampen, damit eine
Zelle nie ihre Nachbarn „überrennt". `cellFrames` ist rein → in
`KeyboardGridLayoutTouchCoverageTests` direkt testbar: nach Resizing weiterhin **vollständige,
disjunkte** Überdeckung.

### 5.4 Resizing-Geometrie (exakt) — Korrektur: separables Linien-Verschieben

> **Korrektur (durch Implementierungs-Test gefunden):** Die ursprüngliche Idee, *jede Zelle ihre
> vier Kanten unabhängig* verschieben zu lassen (`Kante += (o_A+o_B)/2`), **kachelt bei *2D*-Offsets
> nicht**: verschiebt eine Zelle gleichzeitig horizontal *und* vertikal, klafft an ihren Ecken eine
> Lücke/Überlappung zum **Diagonalnachbarn**, der die Verschiebung nicht mitmacht. Auf einem
> Rechteck-Gitter ist eine gültige, achsparallele Partition nur über **gemeinsame Gitterlinien**
> möglich (Eckpunkte müssen von allen vier angrenzenden Zellen geteilt werden).

Korrektes Verfahren — **separable Perturbation der Gitterlinien**:

- Jede **innere vertikale Linie** (zwischen Spalte c−1 und c) verschiebt sich um **einen** Wert
  `δ_x[c]`; jede **innere horizontale Linie** um `δ_y[r]`. **Äußere Linien bleiben fix** (Außengrenze).
- Eine Linie ist von *allen* Zellen entlang ihr geteilt → die per-Tasten-Offsets links/rechts (bzw.
  oben/unten) der Linie werden **auf die Linie gemittelt**:
  `δ_x[c] = mittel_r ( (ox(r,c−1) + ox(r,c)) / 2 ) · Spaltenbreite`.
- Jede Zelle = `[xLinie[col], xLinie[col+span]] × [yLinie[row], yLinie[row+span]]` → **immer** eine
  disjunkte, lückenlose Partition (Teleskopsumme der Intervalle = feste Außenbreite), auch in 2D.
- **Konsequenz/Trade-off:** Der **glatte Reach-Bias** (Hauptsignal, §3.2) wird voll abgebildet; reine
  **Per-Tasten-Residuen** werden durch die Linien-Mittelung nur *teilweise* realisiert. Das ist der
  Preis einer achsparallelen Rechteck-Partition (eine pro-Zelle-exakte Lösung bräuchte
  nicht-rechteckige Zellen, die SwiftUI nicht platzieren kann).
- **Nicht-Degeneriertheit:** Bei Clamp ≤ 0,35 Pitch bewegt sich jede Linie ≤ 0,35 Spaltenbreite;
  benachbarte Spalten behalten Breite ≥ 0,3 → nie invertiert.
- **Spannende Tasten:** spannen einfach mehrere Linien-Intervalle; keine Sonderbehandlung nötig.

(Implementiert in `KeyboardGridLayout.lineShifts`; verifiziert in `KeyboardGridResizingTests` —
2D-Offsets erhalten die exakte Kachelung.)

### 5.5 Faktische Umsetzung / Routing

**Die Tastenzuordnung schreiben *wir* nicht — SwiftUI hit-testet gegen die platzierten Frames.**
Jede `KeyView` wird vom `KeyboardGridLayout` an einem Frame platziert (`.contentShape(Rectangle())`);
SwiftUI liefert die Geste an die KeyView, deren Frame den Touchdown enthält. Wir steuern **nur die
Frames** — es gibt keine eigene „Koordinate → Taste"-Logik.

**Touch-Frame ≠ sichtbarer Key (das ist der Kern):** Die Touch-Zellen kacheln die *gesamte*
Oberfläche lückenlos → jeder Punkt liegt in **genau einer** Zelle. Der sichtbare Key ist per
`visualInset` nach innen gezeichnet. Folge — und Auflösung des „der Touch ist gar nicht auf der
Taste"-Einwands:

> Der Touchdown liegt **immer in genau einer Touch-Zelle**, darf aber **außerhalb des gezeichneten
> Keys** liegen (im Spalt / optisch über dem Nachbarn). Das ist das *unsichtbare* Resizing: der
> Nutzer sieht eine stabile Tastatur, die Trefferzonen verschieben sich darunter.

**Minimaler Eingriff — gespiegelte Frames offset-bewusst machen:** Heute leiten sich `cellFrames`
(Touch-Frame, gewachsen) und `visualInset` (zieht den Key zurück) aus **derselben** `gapInsets`-
Quelle ab und spiegeln sich. Key-Target-Resizing erweitert genau diese geteilte Rechnung:
- Touch-Frame-Grenze verschiebt sich nach §5.4.
- `visualInset` kompensiert um **denselben Betrag pro Kante** (jetzt **asymmetrisch**) → der
  gezeichnete Key bleibt **exakt** an seiner Stelle.
- Da „eine Kante = ein Wert", bleibt die Kachelung **disjunkt** → genau eine Taste pro Punkt, kein
  Overlap/Z-Order-Problem.

**Keine Per-Touch-Korrektur-Rechnung:** Der Offset ist in die Layout-Frames „eingebacken". Beim
Tippen passiert *null* Zusatzarbeit; SwiftUI routet gegen die ohnehin platzierten Frames. Re-Layout
nur bei (seltener) Offset-Änderung. Die Offsets fließen pro **aktivem Regime** (3.1) aus dem
`TouchOffsetModel` in den `KeyboardGridLayout`-Konstruktor.

**Lern-Koordinate (getrennt von der Zuordnung):** `value.startLocation` ist **lokal zum
(verschobenen) KeyView-Frame** → plus Frame-Origin ergibt den **absoluten** Touchdown im
Tastatur-Raum; dann `e = absoluter Touchdown − wahres center(K)` (5.2). So wird gegen die *feste*
Geometrie gemessen, obwohl das Routing über verschobene Frames lief — die §4.1-Entkopplung konkret.

**Verworfene Alternative:** Eine **einzelne** keyboard-weite Geste, die selbst „korrigierter Punkt →
nächstes effektives Zentrum" rechnet. Funktional äquivalent, aber größerer Architektureingriff und
überflüssig, da das Frame-Verschieben in der zentralen, reinen `cellFrames` dasselbe liefert und
SwiftUIs Hit-Testing die Zuordnung gratis macht.

## 6. UI

### 6.1 Settings-Toggle

- **Ein Schalter** fürs gesamte Feature: **Aus** = weder lernen noch anwenden (Default);
  **An** = lernen *und* anwenden.
- **Kurzerklärung** + **Datenschutz-Hinweis** (alles bleibt lokal auf dem Gerät).
- **Status-Zeile:** „lernt noch / genug Daten", mit Sample-Anzahl.

### 6.2 Visualisierung (Settings-Unterseite)

Rendert die Tastatur (Wiederverwendung der daten-getriebenen Darstellung,
`KeyboardGridView`/Showcase), Offsets als Overlay; Quelle: `SharedDefaults`-Snapshot mit
„zuletzt aktualisiert".

- **Wahres Zentrum (Fadenkreuz) → gelernter Punkt (roter Punkt), verbunden durch Pfeil** —
  Richtung *und* Betrag.
- **Konfidenz über Deckkraft/Größe** (wenig Samples → blass). Farbe nur Akzent.

### 6.3 Posture-Wahl (kritisch, Entscheidung statt Ansicht)

Die Posture-Klasse ist **keine Ansicht, die man umschaltet, sondern eine Entscheidung mit
Konsequenz**: Sie wählt das aktive Lern-Regime *und* das angewandte Modell (3.1). Deshalb eine
klar als Entscheidung gerahmte **Auswahl-Liste** („Wie tippst du?"), nicht ein beiläufiger
Segmented-Filter:

- Optionen in der Reihenfolge **rechts → links → beide**
  (`oneThumbRight` / `oneThumbLeft` / `twoThumb`), Default `oneThumbRight` (Einhand ist der
  Normalfall). Persistiert als `touchOffsetPosture`; die Extension liest sie pro Geste frisch.
- Footer erklärt die Konsequenz: separates Profil je Haltung, falsche Wahl kann Tasten in die
  *falsche* Richtung schieben — daher **bewusst wählen, nicht auto-detektieren**.
- Die Offset-Karte darunter zeigt genau das gewählte (= aktive) Regime, ist also für den
  Normalfall nicht leer und wirkt nicht „kaputt".

### 6.4 Reset

- **„Gelernte Korrektur zurücksetzen"** — Pflicht (Wasser-Notausgang).
- Zwei Stufen: **alles** *und* **nur das aktuell angezeigte Regime**.

### 6.5 User-View vs. Debug-View

- **User:** schlicht — Pfeile + Konfidenz, „so passe ich mich an dich an".
- **Debug** (hinter Debug-Toggle/versteckter Geste): rohes **Touch-Sample-Streufeld** pro Taste,
  **Reach-Vektorfeld** (je Hälfte beim twoThumb-Regime), rohe Zahlen (max. Korrektur, `n_k`,
  `s_k`), Per-Regime-Reset.
- **Gesten-Diagnose** (Zukunfts-Track §13): Feature-Cluster-Kerne, Randdichte und Korrekturraten je
  Gestenklasse (Tap/Swipe/Return/Circle) — reine Anzeige, hilft beim Default-Schwellen-Tuning.

### 6.6 Live-Debug-Overlay (Extension, v2)

Echtes Live nur in der Extension möglich. Hinter Debug-Flag. **Speicher-Vorsicht**
(jetsam-kritischer Prozess). Nicht in v1.

## 7. Datenmodell / Persistenz

- `SharedDefaults` (App-Group), versioniertes Schema.
- Pro Regime: Per-Taste `{m_k, n_k, s_k}` (Gesamt-Offset-Mittel, Sample-Zahl, Streuung; je Achse).
  Die Reach-Flächen-Koeffizienten sind **abgeleitet** (Cache, kein Pflicht-Persist — beim Laden aus
  den `m_k` rekonstruierbar). **Keine** separate `keyResidual`-Map (3.3).
- `m_k` in **Tastenpitch-Anteilen**; Reach-Eingabe in `[0,1]²` (5.2).
- Schema-Version + stabile `keyId`s → partielle Invalidierung bei Layout-Änderung.
- **Footprint:** ~12 Tasten × ~5 Floats + Flächenkoeff., × ~6 reale Regime ≈ **wenige KB** — im
  jetsam-kritischen Extension-Prozess unkritisch.
- **Schreib-Kadenz:** **nicht pro Tap** (Perf). Debounced/periodisch — z. B. alle N Taps und bei
  `viewWillDisappear`/Background — damit der Settings-Snapshot (5.1) hinreichend frisch bleibt.
- **Datenschutz:** Rohpunkte werden **nicht** dauerhaft gespeichert — nur aggregierte Schätzer.
  `PRIVACY.md` ist entsprechend zu ergänzen (Feature zeichnet Touch-Positionen lokal aus,
  verlässt das Gerät nie).

## 8. Validierung & Abnahme

- **Proxy-Metrik rein lokal** mitloggen — verlässt das Gerät nicht, dient nur
  Debug/Selbstkontrolle.
- **Kontrafaktische Nutzen-Metrik (primär, self-populating).** Ein toggle-basiertes A/B
  („Feature an vs. aus über je N Sitzungen") füllt in der Praxis nie die Aus-Gruppe — niemand
  schaltet die Korrektur freiwillig ab. Stattdessen wird der Nutzen **kontrafaktisch** aus der
  Geometrie bestimmt: Bei eingeschaltetem Feature kennen wir pro Tap sowohl die zugewiesene
  Taste (`K_on`) als auch die, die der rohe Touchdown **unverschoben** getroffen hätte (`K_off`).
  Der unkorrigierte Punkt ist `p = touchdown + offset` (Touchdown normalisiert in der verschobenen
  Zelle); verlässt `p` je Achse `[0,1]`, hat die Korrektur die Taste **umgebogen** (ein „Flip").
  Über dasselbe Akzeptanz-Veto-Fenster wie das Lernen (§4.1):
  - Flip akzeptiert (kein Backspace) → **caught** (wahrscheinlich abgefangener Fehler),
  - Flip verworfen (Backspace) → **caused** (wahrscheinlich verursachter Fehler),
  - kein Flip → korrektur-irrelevant (kein Signal, korrekt ignoriert).
- **Relative Fehlerraten (primäre Anzeige).** Aus denselben Zählern folgen beide Backspace-Raten
  über die Gesamt-Taps `n` und die beobachteten Löschungen `d` (pro Regime):
  - **mit** Korrektur (beobachtet): `d / n`,
  - **ohne** Korrektur (kontrafaktisch): `(d + caught − caused) / n` — caught-Flips wären Fehler
    gewesen, caused-Flips nicht. Beide Raten ∈ [0,1] (caught/Löschungen disjunkt).
  „Net = caught − caused" = absolute Fehler-Differenz. Selbst-etikettiert (Akzeptanz ≠ Ground
  Truth, gleiche Annahme wie das Lernen); Näherung: eigener Tasten-Offset für beide Zellkanten
  (glattes Reach-Feld dominiert).
- **Abnahmekriterium v1:** Rate **mit** < Rate **ohne** deutlich über die Regime, **ohne** dass die
  per-Klasse-Korrekturrate (§13) in irgendeinem Regime steigt. Solange nicht belegt: Default-aus.
- Debug-View zeigt Samples/Regime, max. Korrektur, `s_k` zur Plausibilisierung.

## 9. Phasierung

**v1 (schlank geschnitten)**
- Regime: Orientierung × `touchOffsetPosture` — Orientierung deterministisch vom Controller,
  Posture explizit vom Nutzer gewählt (11.1).
- Modell: Per-Taste `{m_k,n_k,s_k}`; Reach-Fläche abgeleitet (bilinear Einhand, linear je
  Hälfte bei twoThumb; Konstanten-Term = global). Keine separate `keyResidual`-Persistenz.
- Lernsignal: Self-Labeling auf konfidenten Taps (LM-frei, Interior-Margin `m_interior`), **nur Taps**.
- Update (4.2): Empirical-Bayes-Shrinkage — bounded-influence Running-Mean pro Taste (Huber-Clip),
  Closed-Form-WLS-Refit der bilinearen Reach-Fläche, count-gewichtetes Shrinkage zum Flächen-Prior;
  Outlier-Gate nach Warm-up, absolute Gates + Clamp + Apply-Hysterese.
- Persistenz pro Regime; partielle Invalidierung.
- **Gestenparameter-Telemetrie (nur Erhebung + Debug-Diagnose, KEINE Adaption, §13):** akzeptierte
  Gesten → Feature-Aggregate je Klasse + Korrektur-Zähler. Bewusst mitgenommen, da die Stats-Infra
  ohnehin entsteht; verhindert späteres Retrofitting.
- UI: Toggle (+ Datenschutz, Status), Settings-Viz (Snapshot, Vektoren, Konfidenz),
  Regime-Selektor, Reset (alles + pro Regime), User/Debug-Trennung.

**v2**
- Per-Geste-Residuum (per-Geste *räumlicher* Offset). Setzt voraus, dass v1 dafür Samples sammelt —
  tut es **nicht** (v1 lernt nur aus Taps, §4.1). Also erst, wenn v1 auf Swipe-Start-Sampling
  erweitert ist und dieses einen Gesten-spezifischen Bias belegt. (Nicht zu verwechseln mit der
  §13-Telemetrie, die *Klassifikations-Features* sammelt, nicht räumliche Offsets.)
- Stetige Größen-/Aspect-Anpassung + Interpolation (falls Bedarf belegt).
- Live-Debug-Overlay in der Extension.
- Cold-Start eines leeren Regimes via **gespiegelter Gegenhand** (Einhand-links ≈ -rechts
  gespiegelt).
- Ggf. quadratische Reach-Fläche, falls Residuen Krümmung belegen.

**v3**
- Negativ-Signal (Korrektur-Attribution via Backspace) → behebt den Zensierungs-Bias (4.1),
  ermöglicht volle statt konservativer Korrektur. **Konkrete Methode (Baldwin 2012, „Conservative"):**
  die nach der Löschung neu getippten Zeichen mit den gelöschten **alignen**; nur **relabeln**, wenn
  das Alignment eine reine **Nachbartasten-Substitution** ist (Mis-Hit-Touchdown → intendierter Key
  als positives Sample), sonst verwerfen. Aggressives Verwerfen ist Standard (43,1 % der Edits
  uneindeutig); Baldwin: Recall ~12 %, Fehler <1 % — Genauigkeit vor Datenmenge.

## 10. Offene Hyperparameter (empirisch zu tunen)

Alle Symbole referenzieren den Algorithmus in 4.2:

- `κ` — Shrinkage-Stärke (Prior-Pseudo-Counts); wie schnell eine Taste vom Flächen-Prior auf den
  eigenen Mittelwert übergeht.
- `n_max` — Plastizitäts-Deckel; Recency/Selbstheilung (ab hier wirkt der Running-Mean wie EMA mit
  `α = 1/n_max`).
- `c` — Huber-Clip-Faktor (gekappter Sample-Einfluss, in `s_k`-Einheiten).
- `k_gate`, `β`, `warmup` — Outlier-Gate-Schwelle, EW-MAD-Rate der Streuung, Warm-up vor Gate-Start.
- `m_interior` — Interior-Margin fürs Lernen (Bias-Varianz-Knopf, 4.1); groß = streng = mehr
  Unterkorrektur.
- `apply_on` / `apply_off` — Apply-Gate mit Hysterese auf **Regime-Reife** (4.4, 11.5).
- `λ_ridge` — Ridge-Regularisierung der Reach-Fläche (Schritt 2).
- Clamp-Grenze (% Pitch) — max. Betrag des Korrekturvektors (Default ≤ 0,35).
- Dwell-Max — einziger absoluter Plausibilitäts-Filter (Kontaktradius entfällt, 11.4); am Gerät
  messen (Tap-Dauer-Verteilung, ~150–200 ms).
  (Posture-Schwellen/Hysterese entfallen — Posture wird gewählt, nicht klassifiziert, 3.1/11.1.)

Am Gerät kalibrieren.

## 11. Offene Risiken — zuerst verifizieren

### 11.1 Regime-Erkennbarkeit — GEKLÄRT (Posture wird gewählt, nicht erkannt)

Per Codebase-Untersuchung aufgelöst; das ursprünglich vermutete Show-Stopper-Risiko existiert
nicht. Befunde:

- **Es gibt keinen zu *erratenden* Handhaltungs-State.** iOS bietet Dritt-Tastaturen keinen
  Einhand-Modus (System-Keyboard-only) und meldet einer Custom-Extension keine Floating-/
  Posture-Info. Die ursprüngliche Annahme zielte auf einen nicht existenten Sensor.
- **Orientierung** kommt zuverlässig vom Controller (`detectIsLandscape()` →
  `viewModel.isLandscape`); aus den Keyboard-Bounds allein ginge es nicht (dokumentiert im Code).
- **Die Posture wird nicht abgeleitet, sondern vom Nutzer gewählt.** Ein früher Ansatz leitete sie
  aus `keyboardScale`/`keyboardHorizontalPosition` ab; ein Praxistest zeigte die Fehlklassifikation
  (rechts-einhändig → fälschlich `twoThumb`), und weil ein falsches Split-Modell **aktiv falsch**
  korrigiert (3.2), ist eine stille Heuristik hier schädlicher als eine bewusste Wahl. Die Posture
  ist daher eine explizite Einstellung `touchOffsetPosture` (3.1/6.3).

Konsequenz: Regime-Schlüssel `(Orientierung, touchOffsetPosture)` ist vollständig ohne Detektion
bestimmbar — Orientierung deterministisch vom Controller, Posture direkt vom Nutzer. Kein Spike,
keine zu kalibrierenden Schwellen, kein Regime-Flackern (Hysterese entfällt).

### 11.2 Datenarmut seltener Regime

Einhand-Regime (und v2: Floating) werden selten genutzt → bleiben evtl. dauerhaft kalt. Das ist
**akzeptabel** (sie bleiben neutral = Status quo), aber bewusst so dokumentiert; kein Versuch,
sie künstlich zu füllen (außer optionalem Spiegeln in v2).

### 11.3 Übertragbarkeit auf Gesten-Grid-Keyboards (Evidenzlücke, nicht Show-Stopper)

Der Literatur-Review ergab: **es gibt keine peer-reviewte Arbeit zu Grid-/Gesten-/
Swipe-Keyboards** mit gelernter Offset-Korrektur. Alle Evidenz (Gauß-Modelle, Backoff,
systematischer Offset, Varianz-Boden) stammt von **QWERTY-Tap** und diskreter Zielauswahl. Die
biomechanischen Grundlagen sind layout-unabhängig → **plausibel übertragbar, aber nicht belegt.**

- **Konkretes Risiko:** Könnte die Korrektur die **8-Richtungs-Swipe-Klassifikation** stören? Per
  Design *nein* — die Korrektur ist reines Key-Target-Resizing (Zellgrenzen, §5/11.6); der
  `KeyGestureRecognizer` arbeitet in Translation-Koordinaten und wird **gar nicht** angefasst. Nur
  der *Tasten-Besitz* verschiebt sich, was gewollt ist. Trotzdem als Validierungspunkt führen.
- **Aktion:** Das v1-Abnahmekriterium (§8) ist der eigentliche Beleg der Übertragbarkeit — bis das
  A/B die Übertragung bestätigt, bleibt das Feature Default-aus.

### 11.4 Kontaktradius/Multitouch im Gesten-Stack — GEKLÄRT (Einschränkung, kein Show-Stopper)

Per Code-Check aufgelöst: `KeyGestureRecognizer` ist ein SwiftUI-`ViewModifier` auf Basis von
`DragGesture(minimumDistance: 0)` (`onChanged`/`onEnded`). `DragGesture.Value` liefert nur
`location`, `startLocation`, `translation`, `velocity`, `time` — **kein `UITouch.majorRadius`,
keine Touch-Anzahl**.

- **Folge:** Der geplante Kontaktradius-Gate (Hauptverteidigung gegen Wasser/Handballen) entfällt in
  v1 (4.3/4.5). Wasser-Schutz ruht auf Dwell-Gate + Outlier-Gate/Huber-Clip + Clamp + Heilung +
  Reset.
- **Implementierungs-Hinweis:** Der Recognizer behält aktuell nur `value.translation` und verwirft
  die absolute `value.startLocation`. Fürs Lernen brauchen wir den **absoluten Touchdown relativ
  zum Tastenrahmen** — `startLocation` ist verfügbar, muss aber zusätzlich erfasst werden.
- **Wenn der Kontaktradius später doch gewünscht ist:** Touch-Eingabe auf einen UIKit-
  `UIGestureRecognizer`/`touchesBegan` (mit `UITouch.majorRadius`) umstellen — größerer
  Architektureingriff, für v1 nicht vorgesehen.

### 11.5 Verbleibend offen (Klärungsweg dokumentiert)

- **Apply-Gate-Ebene (entschieden):** **Regime-/Flächen-Reife-Gate** statt hartem Per-Tasten-Gate —
  konsistent mit dem submodell-Reife-Backoff (Yin & Partridge); per-Taste regelt ohnehin schon das
  Shrinkage. `apply_on/off` gaten damit die *Regime*-Reife.
- **Acceptance-Fenster (#4) — GEKLÄRT (Code):** Detektion über die `.deleteBackward`-`KeyAction` in
  der `ActionPipeline` (= Nutzer-Löschung); Ring-Puffer zuletzt committeter Taps, Veto des jüngsten
  bei Folge-Löschung, Fenster über Aktions-Zählung (Mechanismus in 4.1). **Fallstrick:** *nicht*
  `TextInputTarget.deleteBackward()` beobachten — Compose/Telex rufen es im Normalbetrieb intern auf;
  die Pipeline-Action ist der saubere Nutzer-Signal-Pfad. Slide-Delete (`handleSlide`) zusätzlich
  abdecken. Einzige Restarbeit ist das Touchdown-Plumbing (§5), das v1 ohnehin braucht.
- **Posture-Wahl (#5):** explizite Nutzer-Einstellung `touchOffsetPosture` statt Ableitung —
  Praxistest zeigte, dass die scale/position-Heuristik fehlklassifiziert (3.1/6.3/11.1).
- **A/B-Harness (#7):** Eval-Protokoll aus Gboard/Weir adaptieren (gegenbalancierte Sessions, CER/
  Backspace-Rate als Metrik).

### 11.6 Wirkmechanismus: Punkt-Translation vs. Key-Target-Resizing — GEKLÄRT (Redirect)

Per Code-Check (`KeyView` + `KeyboardGridLayout`) aufgelöst. Befund: jede `KeyView` trägt ihre
**eigene** `DragGesture` (`.contentShape(Rectangle())`); SwiftUIs Hit-Testing entscheidet die
Tastenzuordnung **vor** jedem Handler, und `KeyGestureRecognizer` arbeitet nur in
Translation-Koordinaten. Ein Touchdown-„Verschieben" im `GesturePreprocessor` kann die Tastenauswahl
daher **nicht** ändern — der ursprünglich in der Spec angenommene Wirkmechanismus war falsch.

**Redirect (kein Blocker, eher Vereinfachung):** Die Korrektur gehört ins zentrale, reine
`KeyboardGridLayout.cellFrames` als **Key-Target-Resizing** (Grenzen verschieben, §5). Vorteile:
- zentral & rein (eine Funktion besitzt alle Touch-Frames; bereits unit-getestet),
- **Touch-Frame schon vom sichtbaren Key getrennt** (`visualInset`) → unsichtbares Resizing „for free",
- literatur-kanonisch (Key-Target-Resizing, Gunawardana 2010), macht §1 wörtlich wahr,
- `KeyGestureRecognizer`/Innerhalb-Tasten-Gesten unberührt → Swipe-Klassifikation nachweislich
  unbeeinflusst (11.3).

Restarbeit unverändert: Touchdown-Plumbing fürs *Lernen* (§5) + Anti-Drift via `m_interior` gegen
wahre Geometrie (§4.1).

## 12. Test-Ansatz

- Unit-Tests (Swift `Testing`, Mock-`TextInputTarget`):
  - Korrektur-Anwendung im `GesturePreprocessor` (Punkt rein → korrigierter Punkt raus, Clamp).
  - Schätzer (4.2): Running-Mean konvergiert **unverzerrt** auf konstanten Bias (kein
    Schrumpf-Bias bei hoher `n_k`); Huber-Clip kappt Einzel-Sample-Einfluss; count-gewichtetes
    Shrinkage zieht sparse Tasten zum Flächen-Prior; Plastizitäts-Deckel `n_max` überschreibt
    alten Zustand in begrenzter Zeit.
  - Reach-Fläche: Closed-Form-WLS-Refit aus Per-Tasten-Statistiken bildet linearen Trend ab,
    Ridge → 0 bei wenigen Datenpunkten; Zwei-Hälften-Split beim `twoThumb`-Regime.
  - Outlier-Gate inkl. Cold-Start (absolute Gates schützen vor Warm-up); `s_k`-Schätzung.
  - Regime-Trennung: Samples eines Regimes beeinflussen andere nicht; Posture-Setting-Mapping
    (`PostureClass(settingValue:)`, Default/Fallback).
  - Persistenz: Round-Trip durch `SharedDefaults`, Schema-Version, partielle Invalidierung.
  - Hit-Testing-Wechselwirkung mit lückenloser Kachelung (#198).
- Robustheits-/Degenerations-Szenarien als Tests:
  - „Wasser": Flut erratischer Samples (großer Kontaktradius/Multitouch) ändert das Modell nicht
    nachhaltig (absolute Gates + Clamp + Plastizitäts-Fenster).
  - Feedback-Schleife: wiederholte Anwendung treibt den Schätzer nicht (Messung gegen feste
    Geometrie, Attribution über rohen Punkt).
  - Zensierungs-Bias: Schätzer unterschätzt erwartungsgemäß (dokumentiert, nicht „korrigiert").

## 13. Zukunfts-Track: Adaptive Gestenparameter (Daten *jetzt* erheben)

**Entscheidung:** Die *Adaption* der Gesten-Schwellen ist ein **separater, späterer Track** — nicht
v1/v2. Aber da v1 ohnehin eine Statistik-/Lern-Infrastruktur baut (Lern-Middleware,
SharedDefaults-Aggregate), werden die **dafür nötigen Daten gleich mit erhoben**, um späteres
Retrofitting zu vermeiden. v1-Scope hier = **reine Erhebung + Debug-Diagnose, keine Anwendung.**

### Hintergrund (aus der Designdiskussion)
Die 4 Gestenklassen — **Tap / Swipe / Swipe-Return / Circle** — werden über schwellenbasierte
Features getrennt; die Defaults sind aktuell **geraten**, nicht datenkalibriert. Aus **akzeptierten
(unkorrigierten)** Gesten lassen sich die **Cluster-Kerne** je Klasse robust schätzen → spätere
**kern-verankerte** Anpassung (Konvergenz-Garant; Grenz-/„Tal"-Fitting wäre durch Randzensur
instabil). Zwei bekannte Grenzen: (a) **Klassen-Zensur** — eine systematisch versagende Klasse hat
~0 akzeptierte Beispiele und ist aus Positiven nicht heilbar; (b) **Datenarmut** seltener Klassen
(v. a. Circle). Beides macht die *Diagnose* nötig, bevor man Adaption baut. Der per-Richtung
**Winkel-Offset** ist der sauberste erste Kandidat (direkt analog zum Spatial-Offset, §3).

### Was erhoben wird (nur Aggregate, nur aus akzeptierten Gesten)
Pro `(Regime, Gestenklasse[, Richtung])` Running-Stats `{n, mean, M2→Streuung}` (Welford) der
**diskriminierenden Features** — Namen wie in `GestureClassificationThresholds`:
- `maxDisplacement` (Tap ↔ Swipe)
- `returnRatio` (Swipe ↔ Swipe-Return)
- `circularity`, `angularSpan`, `turnConsistency`, `orientedCompactness`, `pathSeparation` (Circle)
- `dominantAngle` **pro Richtung** (für den späteren Winkel-Offset)

**Erfassungs-Scope (≠ Offset-Lernen):** Die Telemetrie ist ein **separater Konsument** derselben
Lern-Middleware. Anders als das Offset-Lernen (**nur Taps**, §4.1) erfasst sie **alle 4 Klassen**
(sonst keine Swipe-/Return-/Circle-Cluster). Sie nutzt **dieselbe Acceptance-Bestimmung**
(Ring-Puffer + Delete-Veto, §4.1); das Klassen-Label ist die Klassifikator-Ausgabe.

**Einheiten (kritisch für spätere Nutzbarkeit):** Features werden in der **nativen
Klassifikator-Einheit** abgelegt (Preprocessor-Raum, per `aspectRatio` normiert) — **identisch zu
den Schwellen** (`minSwipeLength` etc.). Nur so sind die Aggregate später direkt mit den Schwellen
vergleichbar. Die Partition nach **Regime** hält die Geometrie ohnehin konstant.

**Richtungs-Sub-Key:** `[Richtung]` gilt nur für **Swipe** (8 Richtungen) und **Circle** (CW/CCW);
**Tap** und **Swipe-Return** werden ohne Richtungs-Sub-Key geführt.

**Gating:** Erhebung läuft **hinter demselben Feature-Toggle/Debug-Flag** wie die Offset-Korrektur
(Datenschutz-Konsistenz — keine stille Hintergrund-Erfassung).

Zusätzlich:
- **grobe Histogramme** des Primärfeatures je Klasse (wenige feste Bins) — für die Randdichte-
  Diagnose („schneidet die Schwelle ins Cluster?"). *Bin-Range/-Anzahl: bei Implementierung
  festlegen* (z. B. um die jeweilige Default-Schwelle zentriert).
- **Pro-Klasse-Korrektur-Zähler** (wie oft jede Klasse korrigiert wird) — sehr billig, macht die
  **Klassen-Zensur** sichtbar (versagende Klasse = hohe Korrekturrate + wenig Positive).

### Wo / Wie
- **Quelle:** dieselbe **Lern-Middleware** (kennt Klassifikationsergebnis + Accepted/Corrected, §5).
- **Plumbing:** der Klassifikator muss den **Feature-Vektor mitliefern** (heute gibt
  `GestureClassification` nur `gesture` + `isReturn` zurück) — kleiner Eingriff, analog zum
  Touchdown-Plumbing (§5).
- **Speicher/Datenschutz:** nur Aggregate in `SharedDefaults`, versioniert, **lokal** (§7) — keine
  rohen Trajektorien. Footprint vernachlässigbar (4 Klassen × wenige Features × `{n,mean,M2}` + Bins);
  Schreibkadenz wie beim Offset-Modell (debounced/periodisch, §7).

### Nutzen *jetzt* (auch ohne Adaption)
- **Diagnose im Debug-View** (6.5): Cluster-Kerne, Randdichte, Korrekturraten je Klasse.
- Hilft, die **statischen** Default-Schwellen zu tunen (die ohnehin offene Schuld aus §10).
- Zeigt **empirisch**, ob Per-Nutzer-Adaption lohnt und ob seltene Klassen (Circle) überhaupt genug
  Daten haben — *bevor* der Adaptions-Track gebaut wird.

### Scope-Grenze (klar)
v1: **erheben + anzeigen**. **Keine** Schwellen-/Feature-Anpassung zur Laufzeit. Adaption (kern-
verankert, geclampt, reversibel, default-aus; Winkel-Offset zuerst) ist ein eigener späterer Track.

## 14. Swipe-Sektor-Bias-Korrektur (Winkel-Offset pro Richtung)

**Status:** implementiert als Folge-Feature der Tap-Offset-Korrektur — der in §13 als „sauberster
erster Kandidat" benannte per-Richtung-Winkel-Offset, jetzt mit *Anwendung* (nicht nur Erhebung).
Eigener Toggle (`swipeBiasEnabled`, default aus), eigener Store, eigene Reset-Semantik.

### 14.1 Lernen (Self-Labeling, analog §4.1)

Die 8 Swipe-Sektoren sind 45°-Keile um die Mittelwinkel `i·45°` (Koordinaten wie `atan2`, y nach
unten; `KeyGestureRecognizer.angleToGestureType`). Ein **akzeptierter** Swipe (nicht im Veto-Fenster
gelöscht) liefert:

```
Label   = final klassifizierter Sektor S (Intent unter Self-Labeling)
Sample  = Δθ = wrap(maxDisplacementAngle_roh − Mittelwinkel(S))   ∈ (−π, π]
```

Das Residual wird **immer gegen den rohen Messwinkel** gebildet — auch während eine Korrektur
aktiv ist —, damit das gelernte Mittel den *unkorrigierten* Bias schätzt (kein Feedback-Drift).
Return-Swipes nutzen dieselbe Winkel→Sektor-Abbildung und werden mitgelernt.

**Gemeinsames Acceptance-Fenster:** Taps (§4.1) und Swipes teilen sich *ein* Veto-Fenster
(`AcceptanceTracker<PendingSample>`), damit ein Delete den *jüngsten Commit* vetot, egal welcher
Art — ein Delete nach Tap-dann-Swipe darf nicht den unschuldigen Tap treffen.

**Zensur:** Fehlklassifizierte Swipes werden gelöscht/vetoed und fehlen im Sample — die Verteilung
ist bei ±22,5° trunkiert, das Mittel unterschätzt den Bias betragsmäßig. Gleiches Argument wie bei
Taps (§4.1): das Vorzeichen stimmt, die Korrektur konvergiert iterativ.

### 14.2 Schätzer & Shrinkage

Pro `(Regime, Sektor)` ein `RunningOffset` (derselbe robuste Schätzer wie §4.2 Step 1: Huber-Clip,
EW-MAD-Gate, `nMax`-Plastizität — Einheiten hier Radiant, `spreadPrior ≈ 12°`). Empirical-Bayes-
Shrinkage gegen den **zählungsgewichteten Regime-Globalbias** g (statt einer Reach-Surface — der
Bias ist primär biomechanisch pro Richtung, 8 Zellen sind klein genug):

```
b_S = clamp(g + (m_S − g)·n_S/(n_S + κ),  ±clampRadians)
```

Residuen leben in (−22,5°, 22,5°] plus geclampter Korrektur — weit weg vom ±180°-Wrap, daher sind
gewöhnliche (nicht-zirkuläre) Mittel exakt.

### 14.3 Anwendung

Rein numerisch im View-Model (`handleGesture`), **vor** Resolver und Telemetrie — kein Frame-
Resizing, keine Invisible Compensation:

```
S_roh   = angleToGestureType(θ)
S_final = angleToGestureType(θ − b_{S_roh})
```

Ein Lookup-Schritt genügt, weil `clampRadians` (15°) deutlich unter der halben Sektorbreite
(22,5°) liegt. Gate: Toggle an **und** Regime-Reife `Σ n_S ≥ applyOn`.

### 14.4 Persistenz / UI / Reset

- Eigener Store (`swipeBias.snapshot`, eigene Schema-Version), nur Aggregate `{m_S, n_S, s_S}` —
  keine Rohwinkel (§7-Datenschutz). Lernen ist inert, solange der Toggle aus ist.
- Settings: Toggle „Correct my swipes" auf der Touch-Correction-Seite; beide Reset-Pfade
  (Posture/alles) löschen auch den Swipe-Store.

### 14.5 Telemetrie / Diagnose

`sectorResidual` (Radiant) als zusätzliches Feature-Stat pro Gestenklasse in der P6-Telemetrie:
Mittel deutlich ≠ 0 ⇒ systematischer Bias (Rotation hilft); Mittel ≈ 0 bei hoher Streuung ⇒ die
Misses sind Varianz (dann wären Hysterese/Sektor-Gewichtung das Mittel, nicht Rotation).

**Offen (Folge-Track):** Counterfactual-Metrik für Swipes (analog §8: „hat die Rotation den Sektor
geflippt, und wurde das Ergebnis behalten?"); per-Key-Verfeinerung des Bias, falls die Daten sie
hergeben; Tap↔Swipe-Schwellen-Adaption bleibt §13.
