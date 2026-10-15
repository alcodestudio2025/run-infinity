# Kai — scheda tecnica canonica (candidato)

| Field | Value |
|-------|-------|
| Milestone | M6.1-E.2 |
| Base | PR #25 |
| Status | **CANDIDATO ARTISTICO — non approvato per produzione** |
| Live sprites | **Non modificati** (nessun resize di massa) |
| CharacterVisual / fisica / collisioni | **Non toccati** |
| Nova | **Fuori scope** |

Anteprime: [`docs/previews/m6-1-e2/`](../previews/m6-1-e2/)

---

## 1. Tre sorgenti a confronto

| Sorgente | Ruolo | Formato tipico |
|----------|-------|----------------|
| **Approved ref** | Direttiva di brand originale (`approved-character-ref.jpg`) | Illustrazione hero + pose icone |
| **Live** | Kai in gioco oggi (`kai/frames/*`, SpriteFrames) | 64×96 sheet-extract |
| **Experimental Frame 00** | Candidato stilistico (`_experimental/.../00.png`) | 128×192 cutout prototipo |

**Decisione proposta per approvazione:** adottare il **design sperimentale** come *direzione artistica* per i futuri frame Kai, **senza** sostituire ancora il ciclo live e **senza** dichiarare GO produzione finché non esistono 6 pose RUN coerenti + gate.

---

## 2. Scheda tecnica — modello candidato (sperimentale)

### Identità

| Voce | Specifica candidato |
|------|---------------------|
| Nome | Kai — Eroe Atletico |
| Facing | Destra |
| Lettura | Chibi-lite, testa grande, silhouette runner leggibile a ~112×168 px (`DISPLAY_SCALE` 1.75) |

### Proporzioni (misurate su Frame 00)

| Metrica | 128×192 source | 64×96 preview |
|---------|----------------:|--------------:|
| BBox | 116×170 | 58×85 |
| Fill altezza canvas | **88.5%** | **88.5%** |
| Head/body opaque ratio | ~0.76 | ~0.75 |

Live a confronto (`run_00`): bbox **60×72**, fill **75%**, head/body ~0.51 → il candidato **occupa più canvas** e ha massa testa relativa più alta.

### Pivot / ancoraggio (produzione futura)

| Voce | Specifica |
|------|-----------|
| Canvas gioco | **64×96** (invariato rispetto a `CharacterVisual.CANONICAL_SIZE`) |
| Authoring consigliato | **128×192** whole-canvas (pipeline M6.1-D.1, no auto-trim) |
| Anchor RUN | `ground_contact` — piedi sulla fascia inferiore; pad bottom target **2 px** su 64×96 |
| Godot (invariato) | `centered` + `offset=(0,-48)`; scala visuale 1.75 — **non cambiare ora** |
| Foot-x Frame 00 | ~41.6 su 64×96 (live run_00 ~25.3) — da riallineare nei frame 01–05 |

### Abbigliamento candidato (Frame 00)

| Parte | Descrizione |
|-------|-------------|
| Capelli | Bianchi/spiky, volume alto, fascia/headband scura |
| Top | Felpa/hoodie giallo saturo, zip, bordi scuri |
| Mani | Guanti/bande scure; mano anteriore semplificata |
| Bottom | Pantaloni/shorts scuri + **ginocchiera/calza rossa** evidenziata |
| Scarpe | Sneaker giallo/arancio/bianco, suola chiara |

### Palette candidato (swatch da Frame 00)

Vedi `00_candidate_palette_strip.png`. Cluster principali (RGB approx):

| Ruolo | RGB |
|-------|-----|
| Accent caldo / scarpa | `184, 61, 18` |
| Mezzitoni carnagione/ombra | `164, 116, 133` |
| Giallo jersey | `244, 161, 5` |
| Highlight arancio | `249, 146, 85` |
| Carnagione chiara | `212, 177, 183` → `246, 228, 225` |

### Sagoma

- Profilo runner con lean in avanti, gamba posteriore alzata.
- Su chiaro/scuro: silhouette leggibile; su scacchiera emergono fringe/speck (debito cutout).
- Contorno più “illustrato” del live pixel-soft sheet.

---

## 3. Incompatibilità vs design approvato e vs live

### vs Approved ref (brand sheet)

| Tema | Approved | Candidato Frame 00 | Impatto |
|------|----------|--------------------|---------|
| Top | Jersey giallo con **maniche/pannelli neri raglan** | Hoodie giallo pieno, meno contrasto nero laterale | **Costume drift** |
| Bottom | Shorts scuri su **leggings maroon** mid-calf | Dark pants + **red knee accent** | **Costume drift** |
| Scarpe | High-top giallo/bianco netti | Più arancio/complessi | Minore |
| Stile | Cell-shade hero illustration | Cutout prototipo da concept, AA morbida | Produzione richiede clean edges |
| Grapple/Slide icone | Pose sheet chiare | Non ancora presenti nel candidato | Da rifare nello stesso linguaggio |

### vs Live gameplay

| Tema | Live | Candidato | Impatto |
|------|------|-----------|---------|
| Altezza visibile | BBox H 72 / fill 75% | BBox H 85 / fill 88.5% (**+18%**) | Sostituzione diretta → pop di scala |
| Foot-x | 25.3 | 41.6 (Δ 16.3) | Skating / plant incoerente se mischiati |
| Fringe | ~5.6% | ~10.6% | Aloni su sfondi chiari |
| Palette media | Più cupa/sheet | Più saturata | Discoerenza se solo un frame nuovo |
| Pipeline | Sheet extract | 128×192 indipendente | OK se si usa M6.1-D.1 import |

**Conclusione incompatibilità:** il candidato è **coerente come direzione** con “Kai giallo + capelli bianchi”, ma **non è un drop-in** sul sheet approvato né sul live cycle. Serve un lock esplicito del costume (jersey vs hoodie; maroon leggings vs red knee) prima di commissionare i 5 frame rimanenti.

---

## 4. Regole per i futuri frame (senza toccare il live ora)

1. Non ridimensionare/auto-batch i PNG live esistenti.
2. Non alterare `CharacterVisual`, hitbox, fisica.
3. Nuovi frame: 128×192 RGBA, whole-canvas, facing right, piedi su guida inferiori.
4. RUN richiede **6 pose distinte** (no clone di 00); poi import `_incoming` + provenance + gate.
5. Solo dopo gate PASS si valuta lo swap SpriteFrames.

Template slot: `03_future_run_frame_template.png`, `00_authoring_slot_guide.png`.

---

## 5. Anteprime per approvazione

| File | Contenuto |
|------|-----------|
| `00_three_source_compare.png` | Approved crop · Live · Candidate (piedi su linea) |
| `01_gameplay_size_live_vs_candidate.png` | Godot 1920×1080 @ 1.75× |
| `02_candidate_pivot_canvas_guide.png` | 128 e 64 + pivot + box 64×96 |
| `03_future_run_frame_template.png` | Guida slot RUN 00–05 |
| `04/05_candidate_silhouette_*.png` | Sagoma chiaro/scuro |
| `00_candidate_palette_strip.png` | Swatch |

---

## 6. Richiesta di decisione (ChatGPT / art)

Scegliere **una** linea costume prima di produrre i frame 01–05:

- **A — Lock approved sheet:** jersey raglan nero + shorts + maroon leggings (candidato va riallineato).
- **B — Lock experimental Frame 00:** hoodie giallo + red knee accent (aggiornare il ref sheet di brand).
- **C — Hybrid esplicito:** elencare pezzi approved da tenere e pezzi Frame 00 da tenere.

Fino alla scelta: candidato = **preview only**; live resta il Kai di produzione.
