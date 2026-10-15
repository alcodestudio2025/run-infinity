# M6.1-G — Kai character part plate (art contract)

| Field | Value |
|-------|-------|
| Milestone | M6.1-G |
| Base | PR #27 @ `cab83b6d54e0850d77755646cfa4bee16a1cdcb9` |
| Branch | `cursor/m6-1-g-character-parts-3f40` |
| Canon | **Option A** (approved sheet) |
| Art PNGs | **Not delivered** — blocked on authored plates |
| Skeletal scene | **Not created** (gate still `NO_GO_QUALITY_PARTS`) |
| CharacterVisual / live frames | **Untouched** |
| M6.1-D 30-PNG production | **Still SUSPENDED** |
| Nova / M6.2 / APK / merge | **Out of scope** |

Machine contracts:

- [`PART_PLATE_SPEC.json`](../../assets/sprites/characters/_incoming/kai/cutout_parts/PART_PLATE_SPEC.json)
- [`PIVOT_SCHEMA.json`](../../assets/sprites/characters/_incoming/kai/cutout_parts/PIVOT_SCHEMA.json)
- [`ASSET_AUDIT.json`](../../assets/sprites/characters/_incoming/kai/cutout_parts/ASSET_AUDIT.json)

Previews: [`docs/previews/m6-1-g/`](../previews/m6-1-g/)

---

## 1. Verdict

```text
SPEC_READY_BLOCKED_ON_ART
```

M6.1-F proved existing assets cannot become quality cutouts. This milestone defines the **shortest path** to a modular Kai: one authored Option A part plate → gate GO → Skeleton2D POC in `scenes/dev/` only.

No credible artistic part PNGs were generated here (placeholders / auto-cuts / AI stand-ins rejected).

---

## 2. Art contract — minimum part package

### Costume lock (mandatory)

| Zone | Spec |
|------|------|
| Hair | White spiked + dark headband |
| Top | Yellow with black raglan panels/sleeves |
| Hands | Dark fingerless gloves (fuse into `forearm_*` for RUN POC) |
| Bottom | Dark shorts over maroon mid-calf leggings |
| Shoes | Yellow/white athletic |

### Required parts (12) — first RUN POC

| Part | Contents | Pivot joint |
|------|----------|-------------|
| `head.png` | Face + white spikes + dark band + neck stump | Neck |
| `torso.png` | Yellow jersey + black raglan + shorts top | Hips / waist |
| `upper_arm_l/r.png` | Raglan sleeve segment shoulder→elbow | Shoulder |
| `forearm_l/r.png` | Forearm + glove/fist | Elbow |
| `thigh_l/r.png` | Shorts underside paint + maroon thigh | Hip |
| `shin_l/r.png` | Maroon mid-calf shank | Knee |
| `shoe_l/r.png` | Yellow/white sneaker | Ankle |

### Hierarchy (Bone2D)

```text
hips (root)
├── torso
│   ├── head
│   ├── upper_arm_l → forearm_l
│   └── upper_arm_r → forearm_r
├── thigh_l → shin_l → shoe_l
└── thigh_r → shin_r → shoe_r
```

Default z-order (facing right, near arm in front):  
`shoe_l … forearm_l → torso → head → thigh_r … forearm_r`  
(see `z_order_front_facing_right` in the JSON spec).

### Overlaps

- Min joint pad **12 px** at authoring (≥ **20 px** preferred on 512×768 assemble).
- Paint hidden volumes where limbs rotate away (chest under arm, thigh under shorts, ankle under shin).
- Do **not** rely on soft sheet seams from band-cuts.

### Resolutions

| Level | Spec |
|-------|------|
| Master assemble (guide) | **512×768** (accept 384×576 … 640×960) |
| Per-part min edge | **≥ 64 px** (gate) |
| Preferred limb long edge | **≥ 128 px** (target **160 px**) |
| Live `CharacterVisual` | Still **64×96** — unchanged; POC is separate |

---

## 3. Asset audit

| Source | Final part? |
|--------|-------------|
| Approved sheet / hero crop | **No** — reference only |
| Live Kai 64×96 | **No** — ~15 px limb bands |
| Experimental Frame 00 | **No** — wrong costume + one piece |
| `docs/previews/m6-1-f/auto_cut_parts/` | **No** — feasibility evidence only |
| `_incoming/kai/cutout_parts/*.png` | **None present** |

**Checklist:** 12/12 required = `MISSING_DRAW_NEW`.  
Optional polish (hands/hair/shorts overlay) and jump/slide/grapple alts = deferred.

Nova: reuse **hierarchy + pivot conventions + gate tooling only** — not Kai pixels.

---

## 4. Production plan

### P0 — indispensable for first RUN POC

1. Front-neutral + side/¾ run-contact turnaround (Option A).
2. Separate the 12 RGBA plates with painted overlaps.
3. Drop as `{part}.png` into `_incoming/kai/cutout_parts/`.
4. Pass `m6_1_f_skeletal_poc_scaffold.py` → `GO_PARTS_READY`.
5. Follow-up milestone emits Skeleton2D + RUN cycle in `scenes/dev/` only.

### P1 — jump / slide / grapple (after RUN POC reads)

| Need | Extra art |
|------|-----------|
| Jump | Wider thigh/shin angle coverage; optional torso stretch |
| Slide | Low silhouette thigh/shoe alts; deeper knee bend pads |
| Grapple | Reach forearm alts; stable shoulder/hand read on rope |

Do **not** restart the M6.1-D 30 full-body PNG track for this path.

### Nova reuse (later, out of scope now)

- Same bone template + UV pivot rules.
- New Nova plates (ponytail bone extra).
- Shared quality gate.

### Artist brief (commission-ready)

Deliver **one** Kai Option A cutout part plate:

- Costume exactly as costume lock above.
- 12 named PNGs matching `PART_PLATE_SPEC.json`.
- Pivots per `PIVOT_SCHEMA.json` (metadata only — no baked pivot dots).
- Style: match approved sheet readability (cel + soft shade), not Frame 00 hoodie.

**Block:** Until those PNGs exist, skeletal POC remains refused.

---

## 5. Integration (validate without touching live)

```bash
# 1) Status only — expect exit 2 until art lands
python3 scripts/tools/m6_1_f_skeletal_poc_scaffold.py --status

# 2) Pivot schema sanity (no scene write)
python3 scripts/tools/m6_1_g_part_plate_validate.py

# 3) After real PNGs land — full gate (still no CharacterVisual change)
python3 scripts/tools/m6_1_f_skeletal_poc_scaffold.py
```

| Rule | Detail |
|------|--------|
| Drop | `_incoming/kai/cutout_parts/{part}.png` |
| Gate | min edge, opaque %, anti-rect heuristic |
| Scene when GO | `scenes/dev/m6_1_f_kai_skeletal_poc.tscn` (emitter still future) |
| Forbidden | Edit `CharacterVisual`, live `kai/frames`, SpriteFrames, physics |
| Forbidden | Rectangles, auto-cut copies, Frame 00 promotion |

---

## 6. Minimal RUN POC plan (post-art)

1. Assemble rest pose from plates using `PIVOT_SCHEMA.json` master hints.
2. Animate hips root + thigh/shin/arm swing only (head slight bob).
3. Target: readable contact → pass → flight loop at ~10 FPS equivalent.
4. Compare silhouette to live Kai run at `DISPLAY_SCALE` 1.75 in a **dev** scene.
5. GO criteria: no joint cracks at angle limits; Option A costume reads at gameplay size.
6. Only then consider whether skeletal export or frame bake feeds M6.1-D — separate decision.

---

## 7. Explicit non-goals

- No merge, APK, gameplay balance, Nova art, M6.2.
- No reactivation of 30 PNG production.
- No fake Skeleton2D with colored rectangles.
- No AI/placeholder limbs presented as final.
