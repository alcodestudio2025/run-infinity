# Kai cutout parts — Option A (M6.1-F)

Drop authored RGBA part plates here. Until they pass the scaffold gate, **no**
Skeleton2D POC scene is generated.

## Canon

- Approved sheet costume only (yellow/black raglan, maroon leggings).
- Experimental RUN Frame 00 is **not** the source of truth.

## Required files

See `PART_PLATE_SPEC.json` (`head.png`, `torso.png`, `upper_arm_l.png`, …).

## Gate

```bash
python3 scripts/tools/m6_1_f_skeletal_poc_scaffold.py --status
python3 scripts/tools/m6_1_f_skeletal_poc_scaffold.py
```

Exit `2` = `NO_GO_QUALITY_PARTS` (expected until art lands).

Do **not** copy `docs/previews/m6-1-f/auto_cut_parts/` into this folder.
