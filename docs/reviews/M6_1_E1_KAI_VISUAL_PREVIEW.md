# M6.1-E.1 — Kai RUN Frame 00 visual preview improvement

| Field | Value |
|-------|-------|
| Base | PR #24 @ `b312928397eb6cbe8fa0cc2986d5d1208815f8b4` |
| HTML | [`docs/previews/m6-1-e1/index.html`](../previews/m6-1-e1/index.html) |
| Boards | `docs/previews/m6-1-e1/*.png` (Godot OpenGL, nearest) |
| Metrics | `docs/previews/m6-1-e1/compare_metrics.json` |
| Live sprites | **Unchanged** |
| Nova | **Untouched** |
| Quality gate | **Still NOT passed** |

---

## What was produced

1. **Same-scale, feet-aligned** live vs experimental board (`01_…`).
2. **4×** dual and **8×** per-character nearest enlargements (`02_…`, `03a/b_…`).
3. **Light / dark / checker** backgrounds for halo audit (`04a–f_…`).
4. **Android landscape** 1920×1080 still at `DISPLAY_SCALE` 1.75 (`05_…`).
5. **128×192 ×4** experimental on checker (`06_…`).
6. **Interactive HTML** zoom + slider compare using **only** those Godot PNGs — no CSS beauty filters.

Recorder: `scripts/ci/m6_1_e1_kai_visual_board.gd`

```bash
DISPLAY=:1 godot --path . --fixed-fps 30 \
  -s res://scripts/ci/m6_1_e1_kai_visual_board.gd
# open docs/previews/m6-1-e1/index.html
```

---

## Synthetic findings

| Topic | Finding |
|-------|---------|
| **Scale** | Opaque bbox height 72 → **85** px (+18%) on shared 64×96 canvas. Experimental fills more of the cell. |
| **Pivot** | Bottom pad both **2 px** (feet can share a ground line). Foot-x **25.3 → 41.6** (Δ **16.3 px**) — plant contact / mass differs. |
| **Sharpness** | Laplacian 62.3 → 73.9; 8× nearest shows hard pixels **and** cutout residue. |
| **Halo / fringe** | Fringe **5.57% → 10.63%**; checker/light boards reveal soft edge + stray warm speckles. |
| **Costume** | Live: muted yellow + dark shorts. Exp: hotter yellow, long dark pants, **red kneepad**, different shoe read. |
| **Gameplay size** | At 1.75× → ≈**112×168** px on 1920×1080; exp still reads larger than live beside it. |

**Not a gate pass.** Frame 00 alone remains insufficient for RUN replacement; remaining art debt (E1–E8 in M6.1-E) still applies.

---

## Constraints honored

- No edits to `kai/frames/run_*.png` or Nova
- No physics / APK / merge / M6.2
- No defect-hiding filters on captures or HTML
