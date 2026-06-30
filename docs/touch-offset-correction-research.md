# Literaturrecherche: Touch-Offset-Korrektur für Soft-Keyboards

> Begleitdokument zu `touch-offset-correction.md`. Stand: Deep-Research-Lauf, 25 adversarial
> verifizierte Claims (3-Stimmen-Voting), 18 Primärquellen. Dient als Beleg-/Korrektur-Basis
> für die Designentscheidungen.

## Kernbefund

Die etablierte Methode (Forschung + Industrie) deckt sich **im Kern exakt** mit unserem Design:
Touch-Selektion wird als **bivariate Gauß-Verteilung pro Taste** modelliert; deren **Mittel** ist
der systematische Offset, online geschätzt als **laufender Mittelwert** mit **Reifezähler pro
Taste** und **hierarchischem Backoff** (global → Cluster/Posture → Taste), solange Daten/Konfidenz
fehlen. Das ist 1:1 unser globaler + per-Taste + Shrinkage-Design mit Konfidenz-Gating.

Drei Korrekturen am Detail (siehe unten): (1) Schätzer ist Running-Mean, nicht konstante EMA;
(2) Varianz-Boden ≠ Mittel-Offset; (3) positiv-only ist *nicht* State-of-the-Art — das ist
LM-gestütztes Self-Labeling.

## Was validiert ist

### 1. Modellklasse & Online-Schätzer
- **Gauß pro Taste, Running-Mean + Reifezähler + Backoff.** Yin & Partridge (CHI 2013, MIT+Google):
  „Updating the Gaussian model involves computing the running average of the (x, y) offsets from the
  center of the key … The counter for the number of points … so that we know when a particular
  Gaussian model is mature. When there are not enough data points, the system backs-off to a lower
  level model." → validiert Running-Mean + reife-gegatetes hierarchisches Shrinkage.
  [research.google.com/pubs/archive/41930.pdf]
- **Gboard „Spatial model personalization"** bestätigt dasselbe global/cluster/key-Backoff mit
  personalisierten Gauß-Offset-Mitteln + Kovarianzen. [arxiv.org/abs/2209.11311]
- **Hierarchical Spatial Backoff** (Yin/Ouyang/Partridge/Zhai): Submodell nur anwenden, wenn
  Posture mit Konfidenz erkannt **und** genug Nutzerdaten; sonst Rückfall, „conservative and biased
  towards the standard base model". → validiert Konfidenz-/Reife-Gating als Degenerationsschutz.
  [dl.acm.org/doi/10.1145/2470654.2481384]

### 2. Offsets sind systematisch, lernbar, per-User
- **Holz & Baudisch (CHI 2010), „Generalized Perceived Input Point":** „the perceived input point
  is a systematic effect. This allows compensating … by applying an inverse offset." Das
  generalisierte Modell erklärt **67 %** der zuvor dem „Fat Finger" zugeschriebenen Ungenauigkeit;
  signifikante Nutzer-Interaktionen → **Per-User schlägt global.**
- **Bi & Zhai (Bayesian Touch, UIST 2013):** Touches bivariat-gaußisch ums Ziel, Mittel nahe
  Zentrum mit **kleinem Bias je Handhaltung (Finger vs. Daumen) und Region**; >10 % der Touches
  fallen auf Phone-Größe neben die Zieltaste.

### 3. Positions-/Reach-Abhängigkeit (stützt die Reach-Fläche)
- **Henze et al. (MobileHCI 2011, ~120M Touches):** Touch-Positionen systematisch **nach
  unten-rechts** verschoben, konsistent über 4 Phones. Rein populationsbasierte Kompensation:
  **−7,79 %** Fehlerrate im Feld.
- **Park & Han (2010):** „accurate region" und Offset-Richtung hängen von **Tastengröße und -lage**
  ab; Daumen touchte **links** vom Zentrum, außer nahe der Handwurzel → Reach/Pivot-Effekt real.
- **Weir et al. (GPType, CHI 2014):** Offset-**Varianz** ist positionsabhängig — „in areas … where
  the offsets are more variable, the Gaussians are larger". → Reach-Fläche sollte Mittel *und*
  (später) Streuung modellieren.
- **Bergström-Lehtovirta & Oulasvirta (CHI 2014):** Daumen-Funktionsfläche parametrisch aus
  Surface-Größe, Handgröße, Index-Finger-Position vorhersagbar — **aber Hand-/Fingergröße sind auf
  iOS nicht sensierbar.** → Reach-Fläche muss **gelernt**, nicht analytisch berechnet werden.

### 4. Quantifizierter Nutzen (Erwartungshaltung)
- Gboard/Yin (CHI 2013): Posture+User+Key-Adaption **−13,2 %** CER über nicht-adaptive Baseline
  (8,64 → 7,50 %, p=0,015); theoretische Obergrenze ~14 %.
- Weir GPType (CHI 2014): **−5 bis −7,6 %** über Baseline; **+~1–1,3 %** über SwiftKey. „GP Only"
  (nur gelernter Mittel-Offset, kein LM) **signifikant besser als Baseline** → **Offset-Korrektur
  allein wirkt.**
- Baldwin (2012): 10,4 % relativ. Henze (2011): −7,79 % im Feld.
- **Fazit:** real, aber **moderat** (~5–13 % über nicht-adaptiv; nur ~1 % über das beste
  kommerzielle Keyboard). Wurstfinger hat heute *keine* Adaption → wir spielen im 5–13 %-Regime,
  sofern es sich überträgt.

## Die drei Korrekturen

### A. Schätzer: Running-Mean, nicht konstante EMA
Die Quellen belegen einen **kumulativen Running-Average** (alle Samples gleich gewichtet) mit
count-basiertem Backoff — **keine** EMA mit konstantem Forgetting-Factor. Folge: ein Running-Mean
**konvergiert unverzerrt** auf den wahren Mittelwert; unsere ursprüngliche „EMA + konstantes Decay"
hatte einen permanenten Schrumpf-Bias (`α/(α+λ)·μ`), den der Running-Mean **nicht** hat.
→ **Design-Konsequenz:** Schätzer auf **count-gewichtetes Shrinkage** (Partial Pooling /
James-Stein: Pull-zum-Eltern ∝ Prior-Stärke/(Prior-Stärke+count)) umstellen. Das reduziert die
Schrumpfung automatisch mit wachsender Konfidenz (kein permanenter Bias) und bildet zugleich das
literatur-belegte reife-gegatete Backoff ab. Ein *kleines, separates* Forgetting nur, falls
Plastizität (Drift über Zeit) gewünscht ist — bewusst getrennt vom Shrinkage.

### B. Varianz-Boden ≠ Mittel-Offset (sauber trennen)
**FFitts (Bi/Li/Zhai, CHI 2013):** Endpunkt = Summe zweier Normalverteilungen,
`σ² = σ_r² + σ_a²`; **`σ_a ≈ 1,5 mm` ist irreduzibel** (absolute Fingerpräzision, distanz-/
größenunabhängig). Wichtig: `σ_a` rechtfertigt eine **Reach-/Toleranzfläche (Streuung)**, aber
**nicht** die Unterkorrektur des **Mittel-Offsets**. Beide Effekte dürfen im Design nicht vermengt
werden — der Varianz-Boden ist *kein* Argument für „lieber unterkorrigieren".
→ **Design-Konsequenz:** Die Leitlinie „Unterkorrektur ist sicher" (Spec §1) ausschließlich aus dem
**Zensierungs-Bias** begründen (Mittel), nicht aus dem Varianz-Boden. Der Varianz-Boden ist ein
separates Faktum: selbst perfekte Korrektur lässt irreduzibles Streurauschen → erklärt, warum der
Nutzen moderat bleibt, und motiviert (v2/v3) das Mitlernen der **Kovarianz** pro Taste.

### C. Positiv-only ist nicht SOTA — Self-Labeling ist es
**Baldwin (2012):** Lernen nur aus Korrektur-Events verzerrt zu Fehlerfällen
(„skewing the data towards erroneous cases") → der von uns vermutete Zensierungs-Bias ist
**dokumentiert bestätigt**. Aber deployte Systeme umgehen ihn **nicht** per Acceptance-only,
sondern per **Self-Labeling**: Yin & Partridge ordnen jedem Touch **probabilistisch die
wahrscheinlichste Taste** zu (via Spatial+Language-Model), „without relying on the hidden identity
of the true intended key". Ein echtes Negativ-Signal/EM wird im Gboard-Ansatz nicht genutzt.
→ **Design-Konsequenz:**
- Unser „positiv-only" präziser als **„Self-Labeling auf konfidenten (interioren) Taps"**
  reframen — bei großen Grid-Tasten sind die meisten Taps eindeutig, also *ist* das eine
  degradierte Self-Labeling-Variante. Die zensierten Fälle sind genau die Grenz-Taps.
- Ohne LM ist **konservative Unterkorrektur die robuste Wahl** — bewusst, mit bekanntem
  Trade-off (unterschätzt den Offset).
- **Konkreter Upgrade-Pfad (v3), literatur-belegt:** Baldwin nutzt Backspace als
  Supervised-Signal: „the three letters typed after the edit operation were the intended
  characters for the three characters that were deleted." → genau unser geplantes Negativ-Signal,
  mit Methode.

## Korrekturverhalten — Fundierung des Acceptance-Filters (2. Recherche)

Fokussierte Folge-Recherche speziell zum Fehler-Korrektur-Verhalten, zur Parametrisierung des
Acceptance-Filters (§4.1 der Spec).

- **Fenster = Event-/Keystroke-Zählung, nicht ms (belegt):** Alle ernsthaften Self-Labeling-Systeme
  parametrisieren über die **Edit-Struktur** (Baldwin 2012), nicht über eine ms-Schwelle. Das
  einzige explizite Zeitfenster ist Gboards Undo-Regel „**immediately, before any other key**" — ein
  einziger Event-Schritt. **Lücke:** keine peer-reviewte ms-Latenz-Verteilung „Mis-Hit → Backspace".
- **Korrektur-Modi (belegt):** *immediate* (1 Backspace + Retype) vs. *delayed* (mehrere Backspaces
  durch korrekte Zeichen bis zum Fehler). Mit Autokorrektur **dominieren immediate** Korrekturen
  massiv (2,10 vs. 0,47 pro Satz; Shi et al., CHI 2025, Aggregat aus Jiang 2020 / Palin 2019).
- **Mehrfach-Löschung ist real (belegt):** ~21,6 % aller Daten stecken in Edits (Baldwin); verzögerte
  Korrekturen löschen durch *korrekte* Zeichen mit (`peeple<<<<ople`). → **Burst-Veto** statt
  Einzel-Veto (Korrektur an §4.1).
- **Unkorrigierte Mis-Hits sind selten (belegt):** ~2,3 % unkorrigierte Fehlerrate (Palin et al.
  2019); „conscientiousness" 0,61–0,78 (Soukoreff/MacKenzie 2003). Baldwins „Character-Level"
  (allen nicht-editierten Taps vertrauen) erreicht **98,2 % Precision** → Zensierungs-Bias-Beitrag
  klein, Akzeptanz unkorrigierter Taps vertretbar.
- **Self-Labeling-Strategien (Baldwin 2012, belegt):** *Conservative* (nur Edits, Adjazenz-
  Substitution; Recall ~12 %, Fehler <1 %) vs. *Character-Level* (Recall 90,7 %, Precision 98,2 %)
  vs. *Word-Level* (OOV-Wörter verwerfen). **43,1 % der Edits werden verworfen** (Umformulierungen/
  uneindeutig) → aggressives Verwerfen ist Standard. Baldwin **relabelt** (Mis-Hit → intendierter
  Key); unser v1 **vetoed** nur (sicherer, exklusionsbasiert) — Relabeln ist v3.
- **Edit ≠ Fehlerkorrektur (belegt):** ein erheblicher Teil der Löschungen sind Umformulierungen/
  Restarts → lange Bursts (ganze Wörter) nicht als Mis-Hit-Signal behandeln.
- **Taxonomie (belegt):** Soukoreff & MacKenzie (CHI 2003) C/INF/IF/F; Corrected vs. Not-Corrected
  Error Rate.
- **Lücken (ehrlich):** Label-/Korrektur-Behandlung beim Trainingsdaten-Aufbau von Fowler (CHI 2015)
  und Yin (CHI 2013) **nicht** primär verifizierbar; die kursierende Sivek/Riley-2022-Formulierung
  „backspaced presses removed from training set" konnte **keiner Primärquelle** zugeordnet werden →
  unbestätigt.

Zusätzliche Quellen: Soukoreff & MacKenzie, *Metrics for text entry research* (CHI 2003,
yorku.ca/mack/chi03.html) · Baldwin, *Online Adaptation … Text Input Personalization* (PhD MSU 2012)
+ Baldwin & Chai (IUI 2012) · Fowler et al., *Effects of Language Modeling …* (CHI 2015) · Shi et
al., *Simulating Errors in Touchscreen Typing* (CHI 2025, arXiv:2502.03560) · Palin et al.,
*Typing37K* (MobileHCI 2019) · Gboard „Undo auto-correct on backspace" (support.google.com).

## Nicht von der Literatur gedeckt (eigene Engineering-Erweiterungen)
- **Schutz gegen transiente Störungen** (Wasser, Ausreißer-Clamp, robuste Schätzer/Median,
  Kontaktradius-Gating): in den verifizierten Quellen **nicht** adressiert — dort beschränkt sich
  Robustheit auf Backoff/Konservatismus/Reife-Gating. Unsere Clamp- und Gating-Mechanismen sind
  sinnvolle, aber **nicht belegte** Ergänzungen. Als solche kennzeichnen.

## Evidenzlücke (ehrlich)
Es gibt **praktisch keine** peer-reviewte Arbeit zu MessagEase-/Grid-/Gesten-/Swipe-Keyboards mit
gelernter Offset-Korrektur. Alle Evidenz stammt von **QWERTY-Tap** und diskreter Zielauswahl. Die
biomechanischen Grundlagen (systematischer, posture-/positionsabhängiger Offset; Varianz-Boden) sind
**layout-unabhängig** und gelten für den Touchdown jeder Geste → **plausibel übertragbar, aber nicht
belegt.** Offene Risiken: Könnte Offset-Korrektur die **8-Richtungs-Swipe-Klassifikation** stören?
(Unsere Translation am Touchdown lässt die Richtung — aus Deltas — invariant; sie verschiebt nur den
Tasten-Besitz, was gewollt ist. Trotzdem als Validierungspunkt führen.)

## Quellen (Primär, verifiziert)
- Yin, Ouyang, Partridge, Zhai — *Making Touchscreen Keyboards Adaptive … Hierarchical Spatial
  Backoff* (CHI 2013). research.google.com/pubs/archive/41930.pdf ·
  dl.acm.org/doi/10.1145/2470654.2481384
- Google/Sivek et al. — *Spatial model personalization* (Gboard, 2022). arxiv.org/abs/2209.11311
- Holz & Baudisch — *Generalized Perceived Input Point Model* (CHI 2010). christianholz.net
- Bi & Zhai — *Bayesian Touch* (UIST 2013) · *Dual Gaussian* (UIST 2016)
- Bi, Li, Zhai — *FFitts Law* (CHI 2013). www3.cs.stonybrook.edu/~xiaojun/pdf/FFitts.pdf
- Henze, Rukzio, Boll — *100,000,000 Taps* (MobileHCI 2011). nhenze.net
- Park & Han — *Touch key design … thumb input* (Int. J. Ind. Ergonomics 2010).
  sciencedirect.com/science/article/abs/pii/S0169814110000806
- Weir et al. — *Uncertain Text Entry / GPType* (CHI 2014). (darylweir.com abgelaufen; via ACM DL)
- Bergström-Lehtovirta & Oulasvirta — *Modeling the functional area of the thumb* (CHI 2014).
- Baldwin — *PhD Dissertation* (MSU 2012). cse.msu.edu/~jchai/Thesis/tyler-baldwin-dissertation-2012.pdf
- Gunawardana, Paek, Meek — *Usability-Guided Key-Target Resizing* (IUI 2010). microsoft.com/research

## Offene Fragen (aus dem Bericht)
1. Überträgt sich die Gauß-/Backoff-Methodik quantitativ auf Gesten-Grid-Keyboards (Touchdown
   besitzt Taste **und** bestimmt Swipe-Richtung)? Stört Korrektur die Richtungsklassifikation?
2. Existiert ein Online-Schätzer (Kalman/RLS/Bayes) mit explizitem Konfidenz-Decay, der unseren
   Ansatz über das binäre Reife-Gating hinaus validiert?
3. Welche evaluierten Schutzmechanismen gegen transiente Störungen nutzen Produktionssysteme, und
   wie viel bringen sie messbar?
4. Wie viel Zusatznutzen bringt die Per-Geste-Ebene über Per-Taste, ab welcher Datenmenge?
