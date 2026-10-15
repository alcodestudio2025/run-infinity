# M6.1-C — Visual Animation QA (Kai / Nova)

| Field | Value |
|-------|-------|
| Role | Senior Godot Animation Engineer + Technical Artist + QA |
| Base | PR #21 (`cursor/m6-1-b-asset-integration-f957`) |
| Commit under test | `4b807af83a9bb9a8cca11578fa5a8cd18ee042d4` |
| Engine | Godot **4.7.2** OpenGL (captures **not** `--headless`) |
| Recorder | `scripts/ci/m6_1_c_anim_record.gd` |
| Media | `docs/previews/m6-1-c/` |
| Metrics | `docs/previews/m6-1-c/asset_metrics.json` |
| Approved ref | `docs/previews/m6-1/approved-character-ref.jpg` |
| In-game scale | `CharacterVisual.DISPLAY_SCALE = 1.75` on 64×96 canvas |
| Physics / APK / M6.2 | **Out of scope** — no changes |

**Verdict: NO-GO for M6.2** until listed animations are re-authored (or re-extracted from higher-quality source with correct foot pivots). Integration from M6.1-B loads correctly; **loading ≠ shippable animation quality**.

---

## Method

1. **Asset metrics** on every `assets/sprites/characters/{kai,nova}/frames/*.png`: canvas size, opaque %, black-matte residual, fringe (semi-α edge), foot-x centroid, bbox height span, Laplacian sharpness.
2. **Real playback** via `AnimatedSprite2D` + `SpriteFrames` in OpenGL; PNG sequences under `docs/previews/m6-1-c/raw/`; encoded to GIF + MP4 (ffmpeg, no AI interpolation).
3. **Visual review** of stills, ×4/×6 enlargements, strips, and full cycles against the approved character sheet.
4. **Non-destructive policy:** no sharpen filters, no synthetic inbetweens, no physics tweaks. Insufficient sheet frames are flagged for **new art**, not papered over.

Capture note: recorder uses integer `scale=3.0` for legibility. In-game `DISPLAY_SCALE=1.75` is non-integer and reads softer than these preview MP4s.

---

## 1. Asset verification (PNG)

### Transparency / matte

| Check | Kai | Nova |
|-------|-----|------|
| Canvas | 64×96 all frames | 64×96 all frames |
| Edge clip (`touch_edges`) | none | none |
| Max black-matte % | ≤1.38% (idle) | ≤0.34% (grapple) |
| Fringe (AA / soft edge) | ~4–6% | ~4–7% |

**Pass:** real alpha, no opaque rectangular plate, no obvious studio-background leftovers. Soft fringe is expected anti-alias from the painted sheet, not a white/black matte halo.

### Contours / crop / proportions

- No amputated limbs or missing silhouette chunks in idle/run strips.
- Idle height stable (bbox h span **0%** both).
- Action poses compress vertically as designed (slide / land / grapple): height span **23–34%** — intentional crouch/hang, not random scale flicker.
- Hair / gloves / sneakers readable at 64×96; details degrade under ×6 zoom (soft painted edges, not crisp 1px pixel art).

### Feet / pivot

Foot-x = horizontal centroid of the lowest opaque band (proxy for plant). Drift across frames of one anim:

| Anim | Kai foot-x drift (px) | Nova foot-x drift (px) |
|------|----------------------:|-----------------------:|
| idle | 2.2 | 4.7 |
| run | **35.7** | 9.2 |
| jump | 7.0 | 7.4 |
| fall | **13.6** | **16.9** |
| land | 7.2 | **19.7** |
| slide | 4.5 | **21.1** |
| grapple | 3.1 | 4.2 |
| hit | 3.4 | 7.7 |

Threshold used: **>12 px** = issue. Kai **run** is severe (~half canvas width); Nova **slide/land/fall** are elevated.

### Sharpness after enlarge

Laplacian “sharp” scores ~8–16 on 64×96. At ×6 and at in-game 1.75× the sprites look **soft / painterly**, not hard-edged pixel art. Acceptable for the approved painted style; **not** ideal for tiny Android landscape silhouettes if competitors use crisp outlines.

### Diff vs approved models

| Trait | Approved sheet | Integrated sprites |
|-------|----------------|--------------------|
| Kai: white spikes, yellow jersey, dark shorts, orange shoes | Match | Match |
| Nova: magenta ponytail, goggles, pink/teal athletic kit | Match | Match |
| Pose language (run / jump / slide / grapple) | Hero + 4 pose icons | Same family; **lower fidelity** than hero illustration |
| Grapple rope cue | Clear in pose icons | Present but **short / stubby** in 2-frame loops |
| Slide silhouette | Low, readable | Low; Kai slide OK; Nova slide plant drifts |

Identity is correct. Fidelity of secondary poses lags the approved hero art.

---

## 2. Real animation captures

All media are Godot viewport frames → ffmpeg. Paths relative to repo root.

### Kai

| Anim | Frames | GIF | MP4 | Cycle notes |
|------|-------:|-----|-----|-------------|
| IDLE | 4 | [kai_idle.gif](../previews/m6-1-c/kai_idle.gif) | [kai_idle.mp4](../previews/m6-1-c/kai_idle.mp4) | Breathing bob; stable plant |
| RUN | 6 | [kai_run.gif](../previews/m6-1-c/kai_run.gif) | [kai_run.mp4](../previews/m6-1-c/kai_run.mp4) | Readable stride; **horizontal weight skate** from foot pivot |
| JUMP | 3 | [kai_jump.gif](../previews/m6-1-c/kai_jump.gif) | [kai_jump.mp4](../previews/m6-1-c/kai_jump.mp4) | Short takeoff; OK for one-shot |
| FALL | 3 | [kai_fall.gif](../previews/m6-1-c/kai_fall.gif) | [kai_fall.mp4](../previews/m6-1-c/kai_fall.mp4) | Pose change large; mild foot drift |
| LAND | 3 | [kai_land.gif](../previews/m6-1-c/kai_land.gif) | [kai_land.mp4](../previews/m6-1-c/kai_land.mp4) | Squash readable; vertical span high |
| SLIDE | 3 | [kai_slide.gif](../previews/m6-1-c/kai_slide.gif) | [kai_slide.mp4](../previews/m6-1-c/kai_slide.mp4) | Low profile clear; dust FX present |
| GRAPPLE | 2 | [kai_grapple.gif](../previews/m6-1-c/kai_grapple.gif) | [kai_grapple.mp4](../previews/m6-1-c/kai_grapple.mp4) | **Too short**; rope stub; hang↔tuck pop |
| HIT | 2 | [kai_hit.gif](../previews/m6-1-c/kai_hit.gif) | [kai_hit.mp4](../previews/m6-1-c/kai_hit.mp4) | Readable reaction; brief |

Stills / strips: [still_kai_run.png](../previews/m6-1-c/still_kai_run.png), [still_kai_slide.png](../previews/m6-1-c/still_kai_slide.png), [kai_run_strip_x4.png](../previews/m6-1-c/kai_run_strip_x4.png), [kai_idle00_x6.png](../previews/m6-1-c/kai_idle00_x6.png).

### Nova

| Anim | Frames | GIF | MP4 | Cycle notes |
|------|-------:|-----|-----|-------------|
| IDLE | 4 | [nova_idle.gif](../previews/m6-1-c/nova_idle.gif) | [nova_idle.mp4](../previews/m6-1-c/nova_idle.mp4) | Strong read; ponytail stable |
| RUN | 6 | [nova_run.gif](../previews/m6-1-c/nova_run.gif) | [nova_run.mp4](../previews/m6-1-c/nova_run.mp4) | Best of set; foot drift acceptable |
| JUMP | 3 | [nova_jump.gif](../previews/m6-1-c/nova_jump.gif) | [nova_jump.mp4](../previews/m6-1-c/nova_jump.mp4) | Clear launch |
| FALL | 3 | [nova_fall.gif](../previews/m6-1-c/nova_fall.gif) | [nova_fall.mp4](../previews/m6-1-c/nova_fall.mp4) | Large silhouette change + foot drift |
| LAND | 3 | [nova_land.gif](../previews/m6-1-c/nova_land.gif) | [nova_land.mp4](../previews/m6-1-c/nova_land.mp4) | Plant unstable across frames |
| SLIDE | 3 | [nova_slide.gif](../previews/m6-1-c/nova_slide.gif) | [nova_slide.mp4](../previews/m6-1-c/nova_slide.mp4) | Low; **21 px foot drift**; can kiss ground line |
| GRAPPLE | 2 | [nova_grapple.gif](../previews/m6-1-c/nova_grapple.gif) | [nova_grapple.mp4](../previews/m6-1-c/nova_grapple.mp4) | Same **2-frame** limitation as Kai |
| HIT | 2 | [nova_hit.gif](../previews/m6-1-c/nova_hit.gif) | [nova_hit.mp4](../previews/m6-1-c/nova_hit.mp4) | OK for one-shot |

Stills / strips: [still_nova_run.png](../previews/m6-1-c/still_nova_run.png), [still_nova_grapple.png](../previews/m6-1-c/still_nova_grapple.png), [nova_run_strip_x4.png](../previews/m6-1-c/nova_run_strip_x4.png), [nova_idle00_x6.png](../previews/m6-1-c/nova_idle00_x6.png).

---

## 3. Qualitative evaluation

### Fluidity / coherence / pops

| Topic | Finding |
|-------|---------|
| Run fluidity | Cycles loop without missing-limb pops. Kai run **visually skates** because body mass shifts ~36 px on the canvas while hitchbox stays fixed. Nova run is the cleanest loop. |
| Idle | Both pass; gentle sway, no pops. |
| Jump / Fall / Land | Readable state changes; land/fall height swings are large (sheet poses), so transitions feel **steppy** with only 3 frames. |
| Slide size | Correctly shorter silhouette (bbox h ~42–60 vs idle ~92). Gameplay squash is separate (`CharacterVisual`); art already crouches. |
| Grapple | With **2 frames**, loop is a blink between hang and tuck — not a swing cycle. Rope cue is truncated. |
| Hit | Acceptable flash reaction. |
| Duplicates | No identical adjacent frames detected in manifests; poses are distinct. |
| Android landscape read | At ~112×168 px on screen (64×96 × 1.75), silhouettes work for hero size; **soft edges + Kai run skate** hurt clarity on dense obstacle scenes. Prefer integer scale or sharper authored outlines later. |

### Per-anim scorecard

Legend: **P** = Pass · **C** = Conditional · **F** = Fail (needs new assets)

| Anim | Kai | Nova | Driver |
|------|:---:|:----:|--------|
| IDLE | P | P | Stable plant, identity clear |
| RUN | **F** | C | Kai foot drift 35.7 px; Nova OK-ish |
| JUMP | C | C | Short but usable one-shot |
| FALL | C | **F** | Nova foot drift 16.9 + large h-span |
| LAND | C | **F** | Nova foot drift 19.7 |
| SLIDE | C | **F** | Nova foot drift 21.1; slight ground kiss |
| GRAPPLE | **F** | **F** | Only 2 frames; not a playable swing loop |
| HIT | C | C | Brief; OK until polish pass |

---

## 4. Issues by severity

### High

| ID | Issue | Evidence |
|----|-------|----------|
| H1 | **Kai RUN foot-pivot drift 35.7 px** | `asset_metrics.json`; [kai_run_strip_x4.png](../previews/m6-1-c/kai_run_strip_x4.png); [kai_run.gif](../previews/m6-1-c/kai_run.gif) |
| H2 | **GRAPPLE both chars: only 2 frames** — insufficient for M6.2 presentation | manifests; [kai_grapple.gif](../previews/m6-1-c/kai_grapple.gif), [nova_grapple.gif](../previews/m6-1-c/nova_grapple.gif) |

### Medium

| ID | Issue | Evidence |
|----|-------|----------|
| M1 | Nova SLIDE foot drift 21.1 px + possible ground penetration | metrics; [nova_slide.gif](../previews/m6-1-c/nova_slide.gif) |
| M2 | Nova LAND foot drift 19.7 px | metrics; [nova_land.gif](../previews/m6-1-c/nova_land.gif) |
| M3 | Nova FALL foot drift 16.9 px | metrics; [nova_fall.gif](../previews/m6-1-c/nova_fall.gif) |
| M4 | Kai FALL foot drift 13.6 px | metrics |
| M5 | Soft 64×96 under non-integer `DISPLAY_SCALE` 1.75 (Android landscape) | [kai_idle00_x6.png](../previews/m6-1-c/kai_idle00_x6.png), [nova_idle00_x6.png](../previews/m6-1-c/nova_idle00_x6.png) |
| M6 | Grapple rope stub vs approved pose icons | [still_nova_grapple.png](../previews/m6-1-c/still_nova_grapple.png) vs approved ref |

### Low

| ID | Issue | Evidence |
|----|-------|----------|
| L1 | Jump/land/hit frame counts (2–3) feel steppy | manifests |
| L2 | Soft AA fringe ~5–7% (style, not matte) | metrics |
| L3 | Capture scale 3.0 looks sharper than in-game 1.75 — previews slightly flattering | recorder vs `CharacterVisual.gd` |

---

## 5. Corrections applied this milestone

**None to sprite pixels.** Sheet-extracted frames that fail pivot / frame-count bars must not be “fixed” with blur, sharpen, or AI inbetweens.

Delivered supporting files only:

- `scripts/ci/m6_1_c_anim_record.gd` — reproducible OpenGL recorder
- `docs/previews/m6-1-c/**` — real cycles + metrics
- this review

### Animations that need **new assets** (do not ship M6.2 on current frames)

| Priority | Anim | Characters | Ask |
|----------|------|------------|-----|
| P0 | `run` | Kai | Re-author 6+ frames with locked foot pivot (foot-x drift ≤8 px) |
| P0 | `grapple` | Kai + Nova | ≥4–6 frames swing cycle; clearer rope / hang silhouette matching approved icons |
| P1 | `slide` | Nova | Re-plant feet; keep low bbox; no ground kiss |
| P1 | `land`, `fall` | Nova (Kai fall nice-to-have) | Stabilize plant / silhouette continuity |
| P2 | `jump`, `hit` | both | Optional extra inbetweens for less steppy one-shots |
| P2 | Outline / export | both | Optional sharper silhouette pass if Android read stays soft at 1.75× |

---

## 6. Comparison with approved reference

Approved: `docs/previews/m6-1/approved-character-ref.jpg`.

- **Design match:** colors, hair, kits, and four primary poses are recognizably the same characters.
- **Fidelity gap:** sheet cell extractions are smaller and softer than the hero illustrations; secondary poses (especially grapple) do not yet match the clarity of the “Pose Principali” icons.
- **Not a wrong-character problem** — it is a **production-resolution / pivot / frame-budget** problem.

---

## 7. Recommendation

### **NO-GO for M6.2**

M6.1-B integration is functionally complete (SpriteFrames present, 8 anim names, no proxy fallback required). M6.1-C quality bar is **not** met:

1. Kai run plant is not production-stable.
2. Grapple loops are placeholder-length (2 frames) for both heroes.
3. Nova slide/land/fall need re-plants before content milestone polish.

**Do not start M6.2** on these frames. Next step after ChatGPT review: art delta for P0/P1 rows above, then a short M6.1-C′ re-record (same recorder) before any GO.

No merge. No APK. No physics changes in this PR.
