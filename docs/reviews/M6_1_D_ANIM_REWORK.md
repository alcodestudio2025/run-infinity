# M6.1-D — Animation Rework (production brief)

| Field | Value |
|-------|-------|
| Role | Senior Technical Artist / Animation Director / Godot Developer |
| Base | PR #22 (`cursor/m6-1-c-visual-qa-f957` @ `4a38ed3`) |
| Upstream QA | [`M6_1_C_VISUAL_QA.md`](M6_1_C_VISUAL_QA.md) — **NO-GO** |
| Spec (machine) | `assets/sprites/characters/_incoming/REWORK_SPEC.json` |
| Asset checklist | [`M6_1_D_ASSET_LIST.md`](M6_1_D_ASSET_LIST.md) |
| Engine | Godot **4.7.2** |
| Status | **PIPELINE READY — ASSETS PENDING** |

**Hard stop:** correction is **not** complete until authored PNGs land, import runs, quality gate exits `0`, and OpenGL re-record passes. This milestone does **not** replace sprites and does **not** start M6.2.

---

## 1. Asset audit (what to replace / keep)

Source of truth: M6.1-C metrics + scorecard.

### Replace (P0 / P1)

| Char | Anim | Why | Current | Required |
|------|------|-----|--------:|---------:|
| Kai | `run` | Foot-x drift **35.7 px** (skate) | 6 | **6** re-authored |
| Kai | `grapple` | Only 2 frames; stub rope | 2 | **6** |
| Nova | `grapple` | Same | 2 | **6** |
| Nova | `slide` | Foot drift **21.1 px**; ground kiss | 3 | **4** |
| Nova | `land` | Foot drift **19.7 px** | 3 | **4** |
| Nova | `fall` | Foot drift **16.9 px** | 3 | **4** |

### Keep (do not overwrite)

| Char | Anims |
|------|-------|
| Kai | `idle`, `jump`, `fall`, `land`, `slide`, `hit` |
| Nova | `idle`, `run`, `jump`, `hit` |

Nova `run` is Conditional in M6.1-C but acceptable for this rework wave. Kai `fall` (13.6 px) stays unless art capacity remains after P0/P1.

### Non-goals

- No sheet re-extraction for rework slots (`extract_m6_character_frames.py` is **legacy** for those anims).
- No duplicate/padded frames to hit counts.
- No AI inbetweens presented as production art.
- No physics / collision / selection / save changes.

---

## 2. Artistic specifications

### Shared technical contract

| Item | Spec |
|------|------|
| Game canvas | **64×96** RGBA |
| Authoring size | **128×192** preferred (also 64×96 or 256×384) |
| Facing | Right |
| Pivot | Feet on bottom band; plant centroid ≈ **x=32**; Godot `centered` + `offset=(0,-48)` |
| Style | Match approved models — Kai white spikes / yellow kit; Nova magenta ponytail / goggles / pink-teal |
| Reference | `docs/previews/m6-1/approved-character-ref.jpg` (“Pose Principali”) |
| Alpha | Real transparency; black-matte ≤ **2%**; no plate |
| Continuity | Distinct poses; no identical adjacent frames; silhouette readable at `DISPLAY_SCALE` 1.75 |

### Per-animation direction

#### Kai — `run` (P0) — 6 frames @ 10 FPS, loop

- **Silhouette:** Forward lean, athletic chibi runner; yellow jersey readable.
- **Motion:** Full stride cycle (contact → pass → flight → opposite contact). Contact frames plant firmly; airborne frames clearly off ground.
- **Pivot:** Foot-x drift ≤ **8 px** across all 6. No horizontal skating vs hitchbox.
- **Continuity:** Frame 5 must loop cleanly into frame 0; head size stable; no limb pops.
- **Ref:** Approved CORSA pose + hero run energy.

#### Kai / Nova — `grapple` (P0) — 6 frames @ 8 FPS, loop

- **Silhouette:** Hang / swing arc matching approved GRAPPLE icons; rope cue **readable** (not a 2 px stub).
- **Motion:** Anticipation → peak hang → swing through → settle (loopable). Not a 2-pose blink.
- **Pivot:** Body mass stable under attachment feel; foot-x drift ≤ **10 px** (airborne OK to float above ground line).
- **Height span:** ≤ 35% (pose change allowed).
- **Continuity:** Rope direction coherent; hair/ponytail follow swing.
- **Ref:** Approved GRAPPLE pose icons for each character.

#### Nova — `slide` (P1) — 4 frames @ 8 FPS, loop

- **Silhouette:** Low profile (bbox height clearly shorter than idle); keep identity (goggles, ponytail).
- **Motion:** Enter low → hold slide → slight weight shift → hold (loop). Dust FX optional.
- **Pivot:** Foot/hip plant drift ≤ **8 px**; **no** pixels below logical ground (no ground-kiss).
- **Ref:** Approved SCIVOLATA.

#### Nova — `land` (P1) — 4 frames @ 10 FPS, one-shot

- **Silhouette:** Impact squash → recover toward run-ready.
- **Motion:** Contact → deepest squash → recover → exit pose compatible with `run` frame 0.
- **Pivot:** Foot-x drift ≤ **8 px**; both feet readable on plant frames.
- **Continuity:** Must not pop into idle proportions mid-land.

#### Nova — `fall` (P1) — 4 frames @ 8 FPS, loop

- **Silhouette:** Airborne descent; limbs readable; ponytail up/back.
- **Motion:** Subtle tumble/loop without spinning off-model.
- **Pivot:** Foot-x drift ≤ **8 px**; keep mass centered for hitchbox.
- **Continuity:** Loops while airborne until land triggers.

### Exact file deliverables

See [`M6_1_D_ASSET_LIST.md`](M6_1_D_ASSET_LIST.md) — **30 authored PNGs** total (6+6+6+4+4+4).

---

## 3. Integration pipeline (no sheet extract)

### Drop zone

```
assets/sprites/characters/_incoming/
  REWORK_SPEC.json
  kai/run/*.png          (exactly 6)
  kai/grapple/*.png      (exactly 6)
  nova/grapple/*.png     (exactly 6)
  nova/slide/*.png       (exactly 4)
  nova/land/*.png        (exactly 4)
  nova/fall/*.png        (exactly 4)
```

### Tools

| Tool | Role |
|------|------|
| `scripts/tools/import_m6_character_frames.py` | Validate drops → write `frames/{anim}_NN.png` → patch `frames_manifest.json` **only for ready slots** |
| `scripts/ci/m6_1_b_build_sprite_frames.gd` | Rebuild `sprite_frames.tres` from manifests (unchanged FPS table; new counts appear automatically) |
| `scripts/tools/m6_1_d_quality_gate.py` | Metrics + thresholds; **exit 0 only when all rework slots PASS** |
| `scripts/ci/m6_1_c_anim_record.gd` | Real OpenGL cycle capture after gate |
| `scripts/ci/m6_1_d_pipeline_smoke.gd` | Headless: spec + tools present; SpriteFrames still load; does **not** claim art complete |

### Operator flow

```bash
# 1) Artists drop PNGs under _incoming/...
python3 scripts/tools/import_m6_character_frames.py --status

# 2) Import only complete slots (refuses padding)
python3 scripts/tools/import_m6_character_frames.py

# 3) Godot import + SpriteFrames
godot --headless --path . --import --quit
godot --headless --path . -s res://scripts/ci/m6_1_b_build_sprite_frames.gd

# 4) Quality gate (must exit 0)
python3 scripts/tools/m6_1_d_quality_gate.py \
  --json docs/previews/m6-1-d/gate_report.json

# 5) Real playback proof
DISPLAY=:1 godot --path . --fixed-fps 30 \
  -s res://scripts/ci/m6_1_c_anim_record.gd
```

### Preserved systems

- `CharacterCatalog` IDs / anim names
- `CharacterVisual` pivot + `DISPLAY_SCALE` (visual only)
- Player collision / movement / grapple physics
- Character select + `SaveManager` persistence
- Emergency proxy only if `sprite_frames.tres` incomplete

---

## 4. Quality gate (reproducible)

| Check | Pass criterion |
|-------|----------------|
| Count | Exact `frame_count` from spec; incoming present |
| Uniqueness | All frame SHA-256 distinct |
| Canvas | 64×96 after import |
| Pivot | `foot_x_drift` ≤ slot max (8 or 10 px) |
| Matte | `black_matte_pct` ≤ 2 |
| Fringe | ≤ 8% |
| Sharpness | Laplacian mean ≥ 8 |
| Clip | No left/right/top edge clips for run/slide/land |
| Height span | ≤ slot max |
| Godot play | OpenGL record shows full cycle without pops |
| Correction flag | `correction_complete=true` only if **all** slots PASS |

Exit codes: `0` all PASS · `2` still PENDING · `1` FAIL.

**Current expectation:** gate exits `2` (PENDING) until artists deliver PNGs.

---

## 5. Recommendation / stop line

1. Ship this pipeline Draft PR (docs + tools + empty `_incoming` slots).
2. Commission the **30** PNGs in the asset list.
3. Import → gate → OpenGL re-QA (M6.1-D′ / M6.1-C reprise).
4. Only then reconsider GO for M6.2.

No merge. No APK. No physics. No sprite substitution in this PR. **STOP before replacing sprites.**
