# M6.1-D — Exact asset list (authored PNGs)

> **SUSPENDED (M6.1-F):** Do not produce Kai RUN 01–05 or the other rework PNGs below until Option A cutout part-plate feasibility clears. See [`M6_1_F_KAI_SKELETAL_POC.md`](M6_1_F_KAI_SKELETAL_POC.md). Checklist retained for when production resumes.

Drop into `assets/sprites/characters/_incoming/...`.  
After import, gameplay paths become `assets/sprites/characters/{id}/frames/{anim}_NN.png`.

**Total: 30 RGBA PNGs** (when production resumes). Do not deliver duplicates or sheet crops presented as new art.

## Naming in `_incoming`

Zero-padded `00.png` … preferred. Any `*.png` sorted naturally is accepted if count matches.

---

## P0 — must have

### Kai `run` — 6 frames @ 10 FPS (loop)

| # | Incoming | After import | Intent |
|---|----------|--------------|--------|
| 0 | `_incoming/kai/run/00.png` | `kai/frames/run_00.png` | Contact R |
| 1 | `_incoming/kai/run/01.png` | `kai/frames/run_01.png` | Pass |
| 2 | `_incoming/kai/run/02.png` | `kai/frames/run_02.png` | Flight |
| 3 | `_incoming/kai/run/03.png` | `kai/frames/run_03.png` | Contact L |
| 4 | `_incoming/kai/run/04.png` | `kai/frames/run_04.png` | Pass |
| 5 | `_incoming/kai/run/05.png` | `kai/frames/run_05.png` | Flight → loop to 0 |

Gate: foot-x drift ≤ 8 px.

### Kai `grapple` — 6 frames @ 8 FPS (loop)

| # | Incoming | After import | Intent |
|---|----------|--------------|--------|
| 0 | `_incoming/kai/grapple/00.png` | `kai/frames/grapple_00.png` | Reach / latch |
| 1 | `_incoming/kai/grapple/01.png` | `kai/frames/grapple_01.png` | Pull-in |
| 2 | `_incoming/kai/grapple/02.png` | `kai/frames/grapple_02.png` | Peak hang |
| 3 | `_incoming/kai/grapple/03.png` | `kai/frames/grapple_03.png` | Swing through |
| 4 | `_incoming/kai/grapple/04.png` | `kai/frames/grapple_04.png` | Opposite arc |
| 5 | `_incoming/kai/grapple/05.png` | `kai/frames/grapple_05.png` | Settle → loop |

Gate: ≥6 distinct frames; readable rope; foot-x drift ≤ 10 px.

### Nova `grapple` — 6 frames @ 8 FPS (loop)

Same intents as Kai grapple; Nova identity (ponytail, goggles, pink/teal).

| # | Incoming | After import |
|---|----------|--------------|
| 0–5 | `_incoming/nova/grapple/0N.png` | `nova/frames/grapple_0N.png` |

---

## P1 — must have before GO

### Nova `slide` — 4 frames @ 8 FPS (loop)

| # | Incoming | After import | Intent |
|---|----------|--------------|--------|
| 0 | `_incoming/nova/slide/00.png` | `nova/frames/slide_00.png` | Enter low |
| 1 | `_incoming/nova/slide/01.png` | `nova/frames/slide_01.png` | Deep slide |
| 2 | `_incoming/nova/slide/02.png` | `nova/frames/slide_02.png` | Weight shift |
| 3 | `_incoming/nova/slide/03.png` | `nova/frames/slide_03.png` | Hold → loop |

Gate: foot-x drift ≤ 8 px; no ground-kiss.

### Nova `land` — 4 frames @ 10 FPS (one-shot)

| # | Incoming | After import | Intent |
|---|----------|--------------|--------|
| 0 | `_incoming/nova/land/00.png` | `nova/frames/land_00.png` | Contact |
| 1 | `_incoming/nova/land/01.png` | `nova/frames/land_01.png` | Squash |
| 2 | `_incoming/nova/land/02.png` | `nova/frames/land_02.png` | Recover |
| 3 | `_incoming/nova/land/03.png` | `nova/frames/land_03.png` | Exit → run |

### Nova `fall` — 4 frames @ 8 FPS (loop)

| # | Incoming | After import | Intent |
|---|----------|--------------|--------|
| 0 | `_incoming/nova/fall/00.png` | `nova/frames/fall_00.png` | Enter fall |
| 1 | `_incoming/nova/fall/01.png` | `nova/frames/fall_01.png` | Mid |
| 2 | `_incoming/nova/fall/02.png` | `nova/frames/fall_02.png` | Deep |
| 3 | `_incoming/nova/fall/03.png` | `nova/frames/fall_03.png` | Loop |

---

## Keep (no new files)

| Char | Files remain as M6.1-B |
|------|------------------------|
| Kai | `idle_00–03`, `jump_00–02`, `fall_00–02`, `land_00–02`, `slide_00–02`, `hit_00–01` |
| Nova | `idle_00–03`, `run_00–05`, `jump_00–02`, `hit_00–01` |

---

## Source size checklist (per file)

- [ ] RGBA PNG
- [ ] 128×192 (preferred) or 64×96 / 256×384
- [ ] Facing right
- [ ] Distinct from every other frame in the same anim
- [ ] Matches approved character colors / silhouette
- [ ] Feet / mass placed for bottom-center pivot after import
