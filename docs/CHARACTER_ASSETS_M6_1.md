# M6.1 / M6.1-B / M6.1-D — Character asset pipeline

Gameplay collision stays on `Player/CollisionShape2D` and never reads sprite bounds.

## Approved source

| Item | Path |
|------|------|
| Approved design ref | `docs/previews/m6-1/approved-character-ref.jpg` |
| Legacy sheet (RGBA) | `assets/sprites/characters/_source/kai_nova_sheet_approved.png` |
| Legacy extractor | `scripts/tools/extract_m6_character_frames.py` (**do not use for M6.1-D rework slots**) |
| M6.1-D incoming drops | `assets/sprites/characters/_incoming/` + `REWORK_SPEC.json` |
| M6.1-D importer | `scripts/tools/import_m6_character_frames.py` |
| M6.1-D quality gate | `scripts/tools/m6_1_d_quality_gate.py` |
| SpriteFrames builder | `scripts/ci/m6_1_b_build_sprite_frames.gd` |

**M6.1-B:** Kai and Nova gameplay sprites are integrated. Colored proxies remain **emergency fallback only** when `sprite_frames.tres` is missing or incomplete.

**M6.1-D:** Rework anims (Kai `run`/`grapple`; Nova `grapple`/`slide`/`land`/`fall`) must be replaced with **independent authored PNGs** via `_incoming/`. Sheet extraction is frozen for those slots. See `docs/reviews/M6_1_D_ANIM_REWORK.md`.

## Stable IDs

| ID | Display | Tagline |
|----|---------|---------|
| `kai` | Kai | Eroe Atletico |
| `nova` | Nova | Esploratrice |

## Folder layout

```
assets/sprites/characters/
  _source/kai_nova_sheet_approved.png
  kai/
    frames/*.png          ← 64×96 RGBA, feet at bottom-center
    frames_manifest.json
    sprite_frames.tres
  nova/
    frames/*.png
    frames_manifest.json
    sprite_frames.tres
```

## SpriteFrames contract

Exact animation names (see `CharacterCatalog`):

| Anim | Loop | Notes |
|------|------|-------|
| `idle` | yes | |
| `run` | yes | |
| `jump` | no | |
| `fall` | yes | |
| `land` | no | brief |
| `slide` | yes | |
| `grapple` | yes | |
| `hit` | no | |

### Pivot / scale

- Canvas **64×96** matches `CharacterVisual.CANONICAL_SIZE`.
- Feet at bottom-center; `AnimatedSprite2D.centered` + `offset=(0,-48)`.
- Do **not** change hitboxes for art.

## Rebuild

### Legacy (full sheet extract — avoid for rework slots)

```bash
python3 scripts/tools/extract_m6_character_frames.py
godot --headless --path . --import --quit
godot --headless --path . -s res://scripts/ci/m6_1_b_build_sprite_frames.gd
```

### M6.1-D rework (independent PNGs)

```bash
python3 scripts/tools/import_m6_character_frames.py --status
python3 scripts/tools/import_m6_character_frames.py
godot --headless --path . --import --quit
godot --headless --path . -s res://scripts/ci/m6_1_b_build_sprite_frames.gd
python3 scripts/tools/m6_1_d_quality_gate.py --json docs/previews/m6-1-d/gate_report.json
```

## Out of scope

- Per-character physics
- M6.2 content / APK
- Declaring rework complete without gate exit code `0`
