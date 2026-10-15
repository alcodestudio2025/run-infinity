# M6.1-F — Kai skeletal 2D POC (Option A)

| Field | Value |
|-------|-------|
| Milestone | M6.1-F |
| Base | PR #26 @ `64a4e3716f49afeea20adc9539144297d606035b` |
| Canon lock | **Option A** — approved character sheet |
| Experimental Frame 00 | **Not canonical** |
| M6.1-D PNG production | **SUSPENDED** (RUN 01–05 + other rework PNGs) |
| Skeletal POC verdict | **`NO_GO_QUALITY_PARTS`** |
| Live sprites / CharacterVisual / physics | **Untouched** |
| Nova | **Out of scope** |
| M6.2 | **Not started** |

Previews: [`docs/previews/m6-1-f/`](../previews/m6-1-f/)

---

## 1. Artistic decision (canonical)

**Option A locked.** Official Kai reference remains the approved character sheet
(`docs/previews/m6-1/approved-character-ref.jpg` / `_source/kai_nova_sheet_approved.png`).

| Keep | Spec |
|------|------|
| Hair | White spiked + dark headband |
| Top | Yellow with black raglan panels/sleeves |
| Bottom | Dark shorts over **maroon leggings** |
| Shoes | Yellow/white athletic |
| Proportions | Match approved sheet (not Frame 00 fill/scale) |

The experimental RUN Frame 00 package stays under `_experimental/` as a style probe only.
It does **not** redefine costume, proportions, or production target.

Updated consistency sheet: [`M6_1_E2_KAI_CANON_SHEET.md`](M6_1_E2_KAI_CANON_SHEET.md).

---

## 2. Production suspension

Until a dedicated Option A **cutout part plate** exists and this gate can flip to GO:

- Do **not** author Kai RUN frames 01–05.
- Do **not** drop other M6.1-D rework PNGs into `_incoming/` for production import.
- Pipeline code (import / gate / self-test) remains; status is **SUSPENDED**.

Machine flag: `assets/sprites/characters/_incoming/REWORK_SPEC.json` →
`"status": "SUSPENDED_PENDING_OPTION_A_PART_PLATE"`.

---

## 3. Feasibility — can we build a quality skeletal POC from current assets?

### Sources inspected

| Source | Kind | Usable as limb plates? |
|--------|------|------------------------|
| Approved hero crop | Full-body illustration | **No** — overlaps, painted occlusion, no separated limbs |
| Live Kai frames (64×96) | Full-body sheet extracts | **No** — limb bands ≈14 px; soft AA |
| Experimental Frame 00 | Full-body cutout | **No** — not Option A costume; still one piece |

### Auto band-cut evidence (honest fail)

Script: `scripts/tools/m6_1_f_feasibility_parts.py`

| Artifact | Role |
|----------|------|
| `feasibility_source_body.png` | Option A body crop used for cuts |
| `feasibility_auto_cut_montage.png` | Horizontal band montage (labeled not-a-part-plate) |
| `auto_cut_parts/*.png` | head / torso / thigh / shin / arm_guess bands |
| `feasibility_report.json` | Machine verdict |

**Findings:**

1. Band cuts slice through hair, chest, fists, and legs — they are **not** articulation parts.
2. Arms remain fused into torso/hair crops; L/R limbs are not separable without reconstruction.
3. Occluded volumes (torso behind arm, thigh behind shorts, etc.) are missing paint.
4. Live 64×96 cannot meet the ≥64 px min-edge quality bar for authored parts.

### Quality bar (required before any Skeleton2D scene)

| Rule | Requirement |
|------|-------------|
| Authored parts | Separate RGBA plates, min edge **≥ 64 px** |
| Required set | head, torso, upper_arm_l/r, forearm_l/r, thigh_l/r, shin_l/r, shoe_l/r |
| Occlusions | Painted fill where limbs overlap in turnaround |
| Costume | Option A only (raglan + maroon leggings) |
| Placeholders | **Forbidden** — no colored rectangles, no soft sheet crops as “parts” |

### Verdict

```text
NO_GO_QUALITY_PARTS
```

Building a Skeleton2D / Bone2D rig on top of these cuts would **simulate** success.
Per addendum M6.1-F: that path is refused.

---

## 4. What was *not* built (on purpose)

| Item | Status |
|------|--------|
| `Skeleton2D` + `Bone2D` scene with rectangle/proxy limbs | **Not created** |
| Fake cutout from live 64×96 | **Not created** |
| Frame 00 promoted to canon / live swap | **Not done** |
| M6.1-D PNG import into gameplay | **Not done** |
| APK / merge / gameplay / M6.2 | **Not done** |

---

## 5. Scaffold waiting for a real part plate

Drop contract + refusal gate (no placeholders):

```bash
# Inspect / regenerate feasibility evidence
python3 scripts/tools/m6_1_f_feasibility_parts.py

# Attempt skeletal POC scaffold — exits non-zero until quality parts exist
python3 scripts/tools/m6_1_f_skeletal_poc_scaffold.py --status
python3 scripts/tools/m6_1_f_skeletal_poc_scaffold.py
```

Incoming slot (empty until art delivers):

```text
assets/sprites/characters/_incoming/kai/cutout_parts/
  PART_PLATE_SPEC.json
  README.md
  # then: head.png torso.png upper_arm_l.png ... (see required list)
```

When parts pass the gate, a follow-up milestone may generate the Godot Skeleton2D POC scene.
This PR only documents the block and the contract.

---

## 6. Next art ask (ChatGPT / artist)

Deliver **one** Kai Option A cutout part plate:

- Front + side (or front + ¾) turnaround.
- Separated limbs with painted overlaps.
- Costume lock: yellow/black raglan, dark shorts, maroon leggings, yellow/white shoes, white spikes + dark band.
- Prefer authoring ≥128 px on the longest limb edge (game can downscale).

Until then: skeletal POC remains **blocked**; M6.1-D PNG production remains **suspended**.
