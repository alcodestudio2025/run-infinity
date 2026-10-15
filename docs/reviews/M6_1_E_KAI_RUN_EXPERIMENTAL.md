# M6.1-E — Kai RUN experimental (Frame 00 only)

| Field | Value |
|-------|-------|
| Base | PR #23 @ `a754d99e576d606c0fcc7d3af9c72873b1e62513` |
| Package | `Kai_RUN_Frame00_QA.zip` → `_experimental/kai/run_frame00/package/` |
| Status | **EXPERIMENTAL PREVIEW ONLY** |
| Canon (M6.1-F) | **Not canonical** — Option A = approved sheet |
| Quality gate | **NOT PASSED** (`correction_complete` remains false) |
| Gameplay Kai RUN | **Unchanged** (6-frame cycle preserved) |
| Nova | **Untouched** |

---

## 1. Package verification

| File | Result |
|------|--------|
| `00.png` | **128×192** RGBA — PASS size contract |
| Transparency | Real alpha; opaque ≈29.4%; black-matte ≈0%; fringe ≈6.5%; no edge clip |
| `README_QA.json` | `TECHNICAL_PROTOTYPE_NOT_ANIMATION_QA_APPROVED` — segmentation cutout |
| Frame count | **1** only — must **not** pad to 6 |

Author note (from package): manual edge review needed; not approved for production import.

---

## 2. Integration choice

Because only Frame 00 exists:

1. **Do not** duplicate `00.png` to fake a RUN cycle.
2. **Do not** write into `assets/sprites/characters/kai/frames/run_*.png`.
3. **Do not** place a single file under `_incoming/kai/run/` (import requires exactly 6).
4. Store under `_experimental/` + generate whole-canvas `preview_64x96.png` for Godot stills.
5. Keep live SpriteFrames RUN cycle as-is.

Rollback manifest: `assets/sprites/characters/_experimental/kai/run_frame00/ROLLBACK.json` (SHA-256 of all live `run_00..05`).

---

## 3. Godot captures (real OpenGL)

| Capture | Path |
|---------|------|
| Live vs experimental side-by-side | [`docs/previews/m6-1-e/kai_run_live_vs_experimental.png`](../previews/m6-1-e/kai_run_live_vs_experimental.png) |
| Experimental solo (64×96 ×4) | [`docs/previews/m6-1-e/kai_run_experimental_frame00.png`](../previews/m6-1-e/kai_run_experimental_frame00.png) |
| Experimental 128×192 loaded in Godot | [`docs/previews/m6-1-e/kai_run_experimental_frame00_128.png`](../previews/m6-1-e/kai_run_experimental_frame00_128.png) |

Recorder: `scripts/ci/m6_1_e_kai_run_static_preview.gd`

```bash
DISPLAY=:1 godot --path . --fixed-fps 30 \
  -s res://scripts/ci/m6_1_e_kai_run_static_preview.gd
```

---

## 4. Residual art debt (not gate-passing)

| ID | Severity | Debt |
|----|----------|------|
| E1 | High | Only **1/6** RUN frames — cannot replace gameplay cycle |
| E2 | Medium | Cutout from concept art (segmentation); soft/fringe edges need manual cleanup |
| E3 | Medium | Costume delta vs approved sheet / live sprites (e.g. long black pants + red kneepad vs prior shorts look) |
| E4 | Low | Hand silhouette simplified / stubby on lead arm |
| E5 | Low | Thin shoe outlines may alias at `DISPLAY_SCALE` 1.75 |
| E6 | Info | Package self-status: not animation-QA approved |
| E7 | Medium | Side-by-side Godot compare: experimental fill reads **larger** / feet not on same ground line as live `run_00` (pivot/scale debt before any cycle swap) |
| E8 | Low | Soft dark halo / fringe on cutout; tiny stray warm pixels near limbs (visible in 128×192 Godot still) |

**Do not** call M6.1-D quality gate complete. Experimental preview ≠ verified rework.

---

## 5. Rollback

To discard the experiment, delete `_experimental/kai/run_frame00/` and `docs/previews/m6-1-e/` + this doc. Live hashes in `ROLLBACK.json` must still match `kai/frames/run_*.png`.

Verify:

```bash
python3 - <<'PY'
import json, hashlib
from pathlib import Path
r=json.loads(Path('assets/sprites/characters/_experimental/kai/run_frame00/ROLLBACK.json').read_text())
for name, expect in r['live_run_frames_sha256'].items():
    data=Path('assets/sprites/characters/kai/frames', name).read_bytes()
    got=hashlib.sha256(data).hexdigest()
    assert got==expect, (name, got, expect)
print('ROLLBACK OK — live Kai RUN intact')
PY
```

---

## 6. Next steps (after ChatGPT)

1. Deliver remaining Kai RUN frames **01–05** as distinct authored poses (no clones of 00).
2. Drop full set into `_incoming/kai/run/` → import → provenance → quality gate.
3. Only then consider replacing live SpriteFrames.

No merge · no APK · no physics · no M6.2 · no Nova changes.
