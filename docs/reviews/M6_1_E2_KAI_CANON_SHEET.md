# Kai — scheda tecnica canonica (Option A — LOCKED)

| Field | Value |
|-------|-------|
| Milestone | M6.1-E.2 → **locked by M6.1-F** |
| Base lock | PR #26 @ `64a4e37` + addendum M6.1-F |
| Status | **CANON LOCKED — Option A (approved sheet)** |
| Experimental Frame 00 | **Not canonical** (preview / style probe only) |
| Live sprites | **Non modificati** |
| CharacterVisual / fisica / collisioni | **Non toccati** |
| Nova | **Fuori scope** |

Anteprime E.2: [`docs/previews/m6-1-e2/`](../previews/m6-1-e2/)  
Skeletal feasibility: [`M6_1_F_KAI_SKELETAL_POC.md`](M6_1_F_KAI_SKELETAL_POC.md)

---

## 1. Decisione artistica (canonica)

**Opzione A.** Il riferimento ufficiale di Kai rimane il character sheet originale approvato:

- `docs/previews/m6-1/approved-character-ref.jpg`
- `assets/sprites/characters/_source/kai_nova_sheet_approved.png`

| Mantieni | Specifica |
|----------|-----------|
| Capelli | Bianchi appuntiti + fascia scura |
| Top | Giallo con pannelli/maniche nere **raglan** |
| Bottom | Shorts scuri su **leggings maroon** |
| Scarpe | Sportive giallo/bianche |
| Proporzioni | Coerenti con lo sheet approvato |

Il Frame 00 sperimentale **non** diventa il nuovo modello canonico (né costume, né fill/scala).

---

## 2. Tre sorgenti (ruoli aggiornati)

| Sorgente | Ruolo dopo il lock |
|----------|--------------------|
| **Approved ref** | **Canone ufficiale** |
| **Live** | Gameplay attuale (64×96) — invariato finché non arriva arte Option A gate-pass |
| **Experimental Frame 00** | Archivio `_experimental/` — non produzione, non canone |

---

## 3. Scheda tecnica — modello canonico (Option A)

### Identità

| Voce | Specifica |
|------|-----------|
| Nome | Kai — Eroe Atletico |
| Facing | Destra (gameplay) |
| Lettura | Silhouette runner leggibile a `DISPLAY_SCALE` 1.75 |

### Abbigliamento canonico

| Parte | Descrizione |
|-------|-------------|
| Capelli | Bianchi/spiky, fascia/headband scura |
| Top | Jersey/top giallo saturo con **maniche/pannelli neri raglan** |
| Mani | Guanti/bande scure |
| Bottom | Shorts scuri + **leggings maroon** mid-calf |
| Scarpe | High-top / sneaker giallo-bianco |

### Pivot / canvas (invariato)

| Voce | Specifica |
|------|-----------|
| Canvas gioco | **64×96** (`CharacterVisual.CANONICAL_SIZE`) |
| Authoring consigliato | **128×192** whole-canvas (pipeline M6.1-D.1) |
| Godot | `centered` + `offset=(0,-48)`; scala 1.75 — **non cambiare ora** |

---

## 4. Drift del candidato Frame 00 (perché non è canone)

| Tema | Approved (canone) | Frame 00 | Esito |
|------|-------------------|----------|-------|
| Top | Raglan nero | Hoodie giallo pieno | Costume drift |
| Bottom | Maroon leggings | Dark pants + red knee | Costume drift |
| Fill / head mass | Sheet proportions | Fill ~88.5%, head/body più alto | Proporzioni drift |

---

## 5. Produzione sospesa (M6.1-F)

- RUN 01–05 e altri PNG M6.1-D: **sospesi**.
- Prima del skeletal POC serve una **part plate** Option A (vedi M6.1-F).
- Nessun swap live, nessun M6.2.

---

## 6. Anteprime storiche E.2 (ancora utili come confronto)

| File | Contenuto |
|------|-----------|
| `00_three_source_compare.png` | Approved · Live · Candidate |
| `01_gameplay_size_live_vs_candidate.png` | Scala @ 1.75× |
| `02_candidate_pivot_canvas_guide.png` | Pivot guide |
| `00_candidate_palette_strip.png` | Swatch Frame 00 (non-canone) |
