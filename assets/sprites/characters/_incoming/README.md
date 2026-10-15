# M6.1-D — Incoming independent PNG drops

Drop **authored** RGBA PNGs here. Do **not** re-run sheet extraction for rework anims.

## Layout

```
_incoming/
  REWORK_SPEC.json          ← frame counts, FPS, gate thresholds
  kai/run/*.png
  kai/grapple/*.png
  nova/grapple/*.png
  nova/slide/*.png
  nova/land/*.png
  nova/fall/*.png
```

## Naming

Prefer zero-padded sequence: `00.png`, `01.png`, … matching `frame_count` in `REWORK_SPEC.json`.

Also accepted: `run_00.png`, `frame_00.png` (sorted naturally).

## Rules

1. Exact frame count — **no** duplicates to pad.
2. RGBA, real alpha (no matte plate).
3. Source size: **128×192 preferred**; also 64×96 or 256×384.
4. Facing **right**; feet near bottom; body readable at game canvas 64×96.
5. Import tool places/scales onto 64×96 with feet bottom-center — do not invent inbetweens in tooling.

## Import

```bash
python3 scripts/tools/import_m6_character_frames.py          # apply drops that are complete
python3 scripts/tools/import_m6_character_frames.py --status  # list pending slots
godot --headless --path . --import --quit
godot --headless --path . -s res://scripts/ci/m6_1_b_build_sprite_frames.gd
python3 scripts/tools/m6_1_d_quality_gate.py
```

Until every rework slot has verified PNGs and the gate passes, milestone status stays **ASSETS_PENDING**.
